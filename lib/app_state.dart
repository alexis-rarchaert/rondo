import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'storage.dart';
import 'tournee_file.dart';

String todayKey([DateTime? d]) {
  final date = d ?? DateTime.now();
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class LatLng {
  final double lat;
  final double lng;
  const LatLng(this.lat, this.lng);
}

class AppState extends ChangeNotifier {
  AppData data = AppData.empty();
  String currentDay = todayKey();

  LatLng? lastPos;
  double? lastAccuracy;
  double? lastHeading;
  String? currentStreet;
  String? gpsError;
  StreamSubscription<Position>? _posSub;

  bool recording = false;
  DateTime? recStartTs;
  double recDistance = 0;
  Timer? _recTicker;

  bool loaded = false;

  Future<void> init() async {
    data = await Storage.load();
    recDistance = _computeDistance(data.route.points);
    ensureDay(currentDay);
    loaded = true;
    notifyListeners();
    await _initLocation();
  }

  Future<void> _persist() => Storage.save(data);

  DayData ensureDay(String key) {
    var day = data.days[key];
    if (day == null) {
      day = DayData(
        checklist: data.checklistTemplate.map((l) => ChecklistItem(label: l)).toList(),
        notes: [],
        visited: List.filled(data.route.stops.length, false),
      );
      data.days[key] = day;
    }
    while (day.visited.length < data.route.stops.length) {
      day.visited.add(false);
    }
    return day;
  }

  void setDay(String key) {
    currentDay = key;
    ensureDay(key);
    notifyListeners();
  }

  // ---------------- Location ----------------

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      gpsError = 'Active la localisation (GPS) dans les réglages du téléphone';
      notifyListeners();
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      gpsError = 'Localisation refusée — autorise l\'accès à la position';
      notifyListeners();
      return;
    }
    if (permission == LocationPermission.deniedForever) {
      gpsError = 'Autorise la localisation dans les réglages de l\'app';
      notifyListeners();
      return;
    }
    _posSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(),
    ).listen(_onPosition, onError: (_) {
      gpsError = 'Signal GPS indisponible, réessaie en extérieur';
      notifyListeners();
    });
  }

  // Garde le suivi GPS actif quand l'app est mise en arrière-plan : service
  // foreground + wake lock sur Android, mode background location sur iOS
  // (nécessite la permission "Toujours" pour continuer au-delà de quelques minutes).
  LocationSettings _locationSettings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 3),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Ma Tournée',
          notificationText: 'Le suivi de ta tournée est actif',
          enableWakeLock: true,
        ),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
  }

  void _onPosition(Position pos) {
    lastPos = LatLng(pos.latitude, pos.longitude);
    lastAccuracy = pos.accuracy;
    if (pos.heading >= 0 && pos.speed > 0.6) {
      lastHeading = pos.heading;
    }
    gpsError = null;
    if (recording) {
      _appendTrackPoint(lastPos!);
      _checkAutoStop(lastPos!);
      _persist();
    }
    unawaited(_maybeReverseGeocode(lastPos!));
    notifyListeners();
  }

  // Point du tracé ajouté au minimum toutes les 30s (voir _recTicker), même
  // sans déplacement de 3m détecté par le flux GPS, pour garder un
  // itinéraire correct pendant les arrêts ou les déplacements très lents.
  DateTime? _lastPointTs;

  void _appendTrackPoint(LatLng pos) {
    data.route.points.add(RoutePoint(
      lat: pos.lat,
      lng: pos.lng,
      ts: DateTime.now().millisecondsSinceEpoch,
    ));
    _lastPointTs = DateTime.now();
    recDistance = _computeDistance(data.route.points);
  }

  // ---------------- Nom de la rue (reverse-geocoding) ----------------
  // Utilise Nominatim (OpenStreetMap) ; throttlé pour rester largement sous
  // la limite d'1 requête/seconde de leur politique d'usage, et pour ne pas
  // consommer de réseau/batterie inutilement quand on est presque immobile.
  LatLng? _lastGeocodedPos;
  DateTime? _lastGeocodeAt;
  bool _geocoding = false;

  Future<void> _maybeReverseGeocode(LatLng pos) async {
    if (_geocoding) return;
    final last = _lastGeocodedPos;
    final lastAt = _lastGeocodeAt;
    final now = DateTime.now();
    if (last != null &&
        lastAt != null &&
        Geolocator.distanceBetween(last.lat, last.lng, pos.lat, pos.lng) < 30 &&
        now.difference(lastAt) < const Duration(seconds: 12)) {
      return;
    }

    _geocoding = true;
    _lastGeocodedPos = pos;
    _lastGeocodeAt = now;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '${pos.lat}',
        'lon': '${pos.lng}',
        'zoom': '17',
        'addressdetails': '1',
      });
      final res = await http
          .get(uri, headers: {'User-Agent': 'ma_tournee (usage personnel, non-commercial)'})
          .timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = json['address'] as Map<String, dynamic>?;
        final street = (addr?['road'] ?? addr?['pedestrian'] ?? addr?['footway'] ?? addr?['residential']) as String?;
        if (street != null && street.isNotEmpty) {
          currentStreet = street;
          notifyListeners();
        }
      }
    } catch (_) {
      // Pas de réseau ou service indisponible : on garde le dernier nom connu.
    } finally {
      _geocoding = false;
    }
  }

  // ---------------- Détection automatique des arrêts ----------------
  // Le flux GPS n'émet plus d'évènement une fois immobile (distanceFilter),
  // donc le calcul d'arrêt tourne aussi sur le ticker de la seconde
  // (_recTicker) pour détecter l'écoulement du délai même sans nouvelle
  // position.
  static const double _dwellRadius = 15; // mètres
  static const Duration _dwellDuration = Duration(seconds: 10);

  LatLng? _dwellCenter;
  DateTime? _dwellStart;
  bool _dwellStopCreated = false;

  void _checkAutoStop(LatLng pos) {
    final center = _dwellCenter;
    if (center == null || Geolocator.distanceBetween(center.lat, center.lng, pos.lat, pos.lng) > _dwellRadius) {
      _dwellCenter = pos;
      _dwellStart = DateTime.now();
      _dwellStopCreated = false;
      return;
    }
    if (_dwellStopCreated) return;
    if (DateTime.now().difference(_dwellStart!) < _dwellDuration) return;

    _dwellStopCreated = true;
    final alreadyCovered = data.route.stops.any(
      (s) => Geolocator.distanceBetween(s.lat, s.lng, center.lat, center.lng) < _dwellRadius,
    );
    if (!alreadyCovered) markStop('');
  }

  double _computeDistance(List<RoutePoint> pts) {
    double d = 0;
    for (var i = 1; i < pts.length; i++) {
      d += Geolocator.distanceBetween(pts[i - 1].lat, pts[i - 1].lng, pts[i].lat, pts[i].lng);
    }
    return d;
  }

  double distanceTo(Stop s) {
    if (lastPos == null) return double.infinity;
    return Geolocator.distanceBetween(lastPos!.lat, lastPos!.lng, s.lat, s.lng);
  }

  // Index du point du tracé enregistré le plus proche d'une position donnée.
  int? _nearestTrackIndex(double lat, double lng) {
    final pts = data.route.points;
    if (pts.isEmpty) return null;
    var bestIdx = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < pts.length; i++) {
      final d = Geolocator.distanceBetween(lat, lng, pts[i].lat, pts[i].lng);
      if (d < bestDist) {
        bestDist = d;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  // Distance jusqu'à un arrêt en suivant le tracé enregistré (plutôt qu'à vol
  // d'oiseau) : on se projette sur le point du tracé le plus proche de la
  // position actuelle et de l'arrêt, puis on additionne les segments entre
  // les deux. Retombe sur la distance à vol d'oiseau si aucun tracé n'existe.
  double distanceAlongTrackTo(Stop s) {
    if (lastPos == null) return double.infinity;
    final fromIdx = _nearestTrackIndex(lastPos!.lat, lastPos!.lng);
    final toIdx = _nearestTrackIndex(s.lat, s.lng);
    if (fromIdx == null || toIdx == null) return distanceTo(s);
    final points = data.route.points;
    final lo = fromIdx < toIdx ? fromIdx : toIdx;
    final hi = fromIdx < toIdx ? toIdx : fromIdx;
    var d = 0.0;
    for (var i = lo; i < hi; i++) {
      d += Geolocator.distanceBetween(
          points[i].lat, points[i].lng, points[i + 1].lat, points[i + 1].lng);
    }
    return d;
  }

  // Guidage "tour par tour" façon vrai GPS : détecte le prochain virage à
  // venir en comparant le cap du tracé enregistré à intervalles réguliers
  // devant la position actuelle, et renvoie une consigne du style "Dans 15 m,
  // tourne à droite" ou "Continue tout droit". Se base uniquement sur le
  // tracé déjà enregistré (pas de calcul d'itinéraire routier).
  static const double _turnStepMeters = 8;
  static const double _turnThresholdDeg = 28;
  static const double _turnLookaheadMeters = 250;

  String? get nextTurnInstruction {
    if (lastPos == null) return null;
    final points = data.route.points;
    if (points.length < 2) return null;

    final startIdx = _nearestTrackIndex(lastPos!.lat, lastPos!.lng);
    if (startIdx == null || startIdx >= points.length - 1) return null;

    final refBearing = Geolocator.bearingBetween(
      points[startIdx].lat,
      points[startIdx].lng,
      points[startIdx + 1].lat,
      points[startIdx + 1].lng,
    );

    var cumulative = 0.0;
    var lastSampleDist = 0.0;
    for (var i = startIdx + 1; i < points.length; i++) {
      cumulative += Geolocator.distanceBetween(
        points[i - 1].lat,
        points[i - 1].lng,
        points[i].lat,
        points[i].lng,
      );
      if (cumulative - lastSampleDist < _turnStepMeters) continue;
      lastSampleDist = cumulative;

      final bearingHere = Geolocator.bearingBetween(
        points[i - 1].lat,
        points[i - 1].lng,
        points[i].lat,
        points[i].lng,
      );
      final delta = ((bearingHere - refBearing + 180) % 360) - 180;

      if (delta.abs() >= _turnThresholdDeg) {
        final dist = cumulative.round();
        final direction = delta > 0 ? 'à droite' : 'à gauche';
        return dist <= 15 ? 'Tourne $direction' : 'Dans $dist m, tourne $direction';
      }
      if (cumulative >= _turnLookaheadMeters) break;
    }
    return 'Continue tout droit';
  }

  // ---------------- Recording ----------------

  static const Duration _minPointInterval = Duration(seconds: 30);

  void toggleRecording() {
    recording = !recording;
    if (recording) {
      recStartTs = DateTime.now();
      _dwellCenter = null;
      _dwellStart = null;
      _dwellStopCreated = false;
      _lastPointTs = null;
      _recTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        final pos = lastPos;
        if (pos != null) {
          _checkAutoStop(pos);
          if (_lastPointTs == null || DateTime.now().difference(_lastPointTs!) >= _minPointInterval) {
            _appendTrackPoint(pos);
            _persist();
          }
        }
        notifyListeners();
      });
    } else {
      _recTicker?.cancel();
    }
    notifyListeners();
  }

  Duration get recElapsed =>
      recStartTs == null ? Duration.zero : DateTime.now().difference(recStartTs!);

  void markStop(String note) {
    if (lastPos == null) return;
    final n = data.route.stops.length + 1;
    data.route.stops.add(Stop(lat: lastPos!.lat, lng: lastPos!.lng, label: 'Arrêt $n', note: note));
    for (final day in data.days.values) {
      day.visited.add(false);
    }
    _persist();
    notifyListeners();
  }

  // Réordonne les arrêts par plus proche voisin (heuristique simple), en
  // partant du premier arrêt enregistré. Remappe aussi les cases "visité"
  // de chaque journée pour qu'elles restent alignées sur le nouvel ordre.
  void optimizeStops() {
    final stops = data.route.stops;
    final n = stops.length;
    if (n < 3) return;

    final remainingIdx = List<int>.generate(n, (i) => i)..removeAt(0);
    final order = <int>[0];
    var currentIdx = 0;
    while (remainingIdx.isNotEmpty) {
      final cur = stops[currentIdx];
      remainingIdx.sort((a, b) => Geolocator.distanceBetween(cur.lat, cur.lng, stops[a].lat, stops[a].lng)
          .compareTo(Geolocator.distanceBetween(cur.lat, cur.lng, stops[b].lat, stops[b].lng)));
      currentIdx = remainingIdx.removeAt(0);
      order.add(currentIdx);
    }

    data.route.stops = order.map((i) => stops[i]).toList();
    for (final day in data.days.values) {
      if (day.visited.length == n) {
        day.visited = order.map((i) => day.visited[i]).toList();
      }
    }
    _persist();
    notifyListeners();
  }

  // Insère des arrêts scannés (OCR) et retrie TOUS les arrêts (existants +
  // nouveaux) selon leur position le long du tracé enregistré — donc les
  // colis scannés dans le désordre se retrouvent rangés dans l'ordre réel
  // de la tournée. Retombe sur un simple ajout en fin de liste si aucun
  // tracé n'a été enregistré (rien à trier par rapport à).
  void addScannedStops(List<Stop> newStops) {
    if (newStops.isEmpty) return;
    final stops = data.route.stops;
    stops.addAll(newStops);

    for (final day in data.days.values) {
      while (day.visited.length < stops.length) {
        day.visited.add(false);
      }
    }

    if (data.route.points.isNotEmpty) {
      final n = stops.length;
      final trackIdx = List<int>.generate(
        n,
        (i) => _nearestTrackIndex(stops[i].lat, stops[i].lng) ?? 1 << 30,
      );
      final order = List<int>.generate(n, (i) => i)..sort((a, b) => trackIdx[a].compareTo(trackIdx[b]));
      data.route.stops = order.map((i) => stops[i]).toList();
      for (final day in data.days.values) {
        if (day.visited.length == n) {
          day.visited = order.map((i) => day.visited[i]).toList();
        }
      }
    }
    _persist();
    notifyListeners();
  }

  void deleteStop(int index) {
    data.route.stops.removeAt(index);
    for (final day in data.days.values) {
      if (index < day.visited.length) day.visited.removeAt(index);
    }
    _persist();
    notifyListeners();
  }

  // Déplace manuellement un arrêt (glisser-déposer dans l'écran Paramètres).
  // Remappe les cases "visité" de chaque journée pour rester alignées.
  void reorderStop(int oldIndex, int newIndex) {
    final stops = data.route.stops;
    if (newIndex > oldIndex) newIndex -= 1;
    final stop = stops.removeAt(oldIndex);
    stops.insert(newIndex, stop);
    for (final day in data.days.values) {
      if (day.visited.length == stops.length) {
        final v = day.visited.removeAt(oldIndex);
        day.visited.insert(newIndex, v);
      }
    }
    _persist();
    notifyListeners();
  }

  // ---------------- Paramètres ----------------

  void renameTournee(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    data.tourneeName = trimmed;
    _persist();
    notifyListeners();
  }

  // Checklist par défaut (modèle appliqué à chaque nouvelle journée créée
  // par ensureDay). Distincte de la checklist du jour affichée dans l'onglet
  // Tournée, qui reste une copie de travail propre à chaque journée.
  void addTemplateChecklistItem(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    data.checklistTemplate.add(trimmed);
    _persist();
    notifyListeners();
  }

  void renameTemplateChecklistItem(int index, String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return;
    data.checklistTemplate[index] = trimmed;
    _persist();
    notifyListeners();
  }

  void removeTemplateChecklistItem(int index) {
    data.checklistTemplate.removeAt(index);
    _persist();
    notifyListeners();
  }

  void reorderTemplateChecklistItem(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = data.checklistTemplate.removeAt(oldIndex);
    data.checklistTemplate.insert(newIndex, item);
    _persist();
    notifyListeners();
  }

  // Encode la tournée actuelle au format .tournee (voir tournee_file.dart).
  String exportTournee() => TourneeFile.encode(data);

  // Remplace toutes les données par celles d'un fichier .tournee importé.
  // Laisse remonter la [FormatException] de TourneeFile.decode si le
  // fichier n'est pas valide, à charge de l'UI de l'afficher.
  Future<void> importTournee(String fileContent) async {
    final imported = TourneeFile.decode(fileContent);
    recording = false;
    _recTicker?.cancel();
    recStartTs = null;
    recDistance = 0;
    _dwellCenter = null;
    _dwellStart = null;
    _dwellStopCreated = false;
    _lastPointTs = null;
    data = imported;
    currentDay = todayKey();
    ensureDay(currentDay);
    await _persist();
    notifyListeners();
  }

  // Efface toutes les données locales (tracé, arrêts, checklists, notes) et
  // repart d'une tournée vierge. Action irréversible, à confirmer côté UI.
  Future<void> resetAll() async {
    recording = false;
    _recTicker?.cancel();
    recStartTs = null;
    recDistance = 0;
    _dwellCenter = null;
    _dwellStart = null;
    _dwellStopCreated = false;
    _lastPointTs = null;
    data = AppData.empty();
    ensureDay(currentDay);
    await _persist();
    notifyListeners();
  }

  // ---------------- Follow ----------------

  void toggleVisited(int index) {
    final day = ensureDay(currentDay);
    day.visited[index] = !day.visited[index];
    _persist();
    notifyListeners();
  }

  void autoVisit(int index) {
    final day = ensureDay(currentDay);
    if (!day.visited[index]) {
      day.visited[index] = true;
      _persist();
      notifyListeners();
    }
  }

  void resetFollow() {
    final day = ensureDay(currentDay);
    day.visited = List.filled(data.route.stops.length, false);
    _persist();
    notifyListeners();
  }

  // ---------------- Checklist ----------------

  void toggleChecklist(int index) {
    final day = ensureDay(currentDay);
    day.checklist[index].done = !day.checklist[index].done;
    _persist();
    notifyListeners();
  }

  void addChecklistItem(String label) {
    if (label.trim().isEmpty) return;
    final day = ensureDay(currentDay);
    day.checklist.add(ChecklistItem(label: label.trim()));
    data.checklistTemplate.add(label.trim());
    _persist();
    notifyListeners();
  }

  void deleteChecklistItem(int index) {
    final day = ensureDay(currentDay);
    day.checklist.removeAt(index);
    _persist();
    notifyListeners();
  }

  void resetChecklist() {
    final day = ensureDay(currentDay);
    for (final item in day.checklist) {
      item.done = false;
    }
    _persist();
    notifyListeners();
  }

  // ---------------- Notes ----------------

  void addNote(String text) {
    if (text.trim().isEmpty) return;
    final day = ensureDay(currentDay);
    day.notes.add(NoteEntry(text: text.trim(), ts: DateTime.now().millisecondsSinceEpoch));
    _persist();
    notifyListeners();
  }

  void deleteNote(int index) {
    final day = ensureDay(currentDay);
    day.notes.removeAt(index);
    _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _recTicker?.cancel();
    super.dispose();
  }
}
