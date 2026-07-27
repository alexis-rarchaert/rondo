class RoutePoint {
  final double lat;
  final double lng;
  final int ts;

  RoutePoint({required this.lat, required this.lng, required this.ts});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'ts': ts};

  factory RoutePoint.fromJson(Map<String, dynamic> j) => RoutePoint(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        ts: j['ts'] as int,
      );
}

class Stop {
  double lat;
  double lng;
  String label;
  String note;

  Stop({required this.lat, required this.lng, required this.label, this.note = ''});

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng, 'label': label, 'note': note};

  factory Stop.fromJson(Map<String, dynamic> j) => Stop(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        label: j['label'] as String,
        note: (j['note'] as String?) ?? '',
      );
}

class ChecklistItem {
  String label;
  bool done;

  ChecklistItem({required this.label, this.done = false});

  Map<String, dynamic> toJson() => {'label': label, 'done': done};

  factory ChecklistItem.fromJson(Map<String, dynamic> j) =>
      ChecklistItem(label: j['label'] as String, done: (j['done'] as bool?) ?? false);
}

class NoteEntry {
  String text;
  int ts;

  NoteEntry({required this.text, required this.ts});

  Map<String, dynamic> toJson() => {'text': text, 'ts': ts};

  factory NoteEntry.fromJson(Map<String, dynamic> j) =>
      NoteEntry(text: j['text'] as String, ts: j['ts'] as int);
}

class DayData {
  List<ChecklistItem> checklist;
  List<NoteEntry> notes;
  List<bool> visited;

  DayData({required this.checklist, required this.notes, required this.visited});

  Map<String, dynamic> toJson() => {
        'checklist': checklist.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'visited': visited,
      };

  factory DayData.fromJson(Map<String, dynamic> j) => DayData(
        checklist: (j['checklist'] as List)
            .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        notes: (j['notes'] as List)
            .map((e) => NoteEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        visited: (j['visited'] as List).map((e) => e as bool).toList(),
      );
}

class RouteModel {
  List<RoutePoint> points;
  List<Stop> stops;

  RouteModel({required this.points, required this.stops});

  Map<String, dynamic> toJson() => {
        'points': points.map((e) => e.toJson()).toList(),
        'stops': stops.map((e) => e.toJson()).toList(),
      };

  factory RouteModel.fromJson(Map<String, dynamic> j) => RouteModel(
        points: (j['points'] as List)
            .map((e) => RoutePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        stops:
            (j['stops'] as List).map((e) => Stop.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

const List<String> defaultChecklist = [
  'Badge / clé véhicule',
  'Terminal (Facteo) chargé',
  'Casque / gants',
  'LRAR et avis de passage',
  'Bracelet / gilet haute visibilité',
  'Vérifier tri du jour complet',
];

class AppData {
  String tourneeName;
  Map<String, DayData> days;
  List<String> checklistTemplate;
  RouteModel route;

  AppData({
    required this.tourneeName,
    required this.days,
    required this.checklistTemplate,
    required this.route,
  });

  Map<String, dynamic> toJson() => {
        'tourneeName': tourneeName,
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
        'checklistTemplate': checklistTemplate,
        'route': route.toJson(),
      };

  factory AppData.fromJson(Map<String, dynamic> j) => AppData(
        tourneeName: (j['tourneeName'] as String?) ?? 'Ma tournée',
        days: (j['days'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, DayData.fromJson(v as Map<String, dynamic>))),
        checklistTemplate: (j['checklistTemplate'] as List).map((e) => e as String).toList(),
        route: RouteModel.fromJson(j['route'] as Map<String, dynamic>),
      );

  factory AppData.empty() => AppData(
        tourneeName: 'Ma tournée',
        days: {},
        checklistTemplate: List.of(defaultChecklist),
        route: RouteModel(points: [], stops: []),
      );
}
