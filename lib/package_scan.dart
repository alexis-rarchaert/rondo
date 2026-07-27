import 'dart:convert';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;

class GeoPoint {
  final double lat;
  final double lng;
  const GeoPoint(this.lat, this.lng);
}

// Un colis en cours de traitement : photo prise, texte OCR brut, adresse
// devinée (modifiable par l'utilisateur avant confirmation) et résultat du
// géocodage une fois trouvé.
class ScannedPackage {
  final String imagePath;
  String addressGuess;
  bool processing;
  String? error;
  GeoPoint? point;

  ScannedPackage({
    required this.imagePath,
    this.addressGuess = '',
    this.processing = true,
    this.error,
    this.point,
  });

  bool get geocoded => point != null;
}

class PackageScanner {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  static final _postalCodeRe = RegExp(r'\b\d{5}\b');

  Future<String> extractText(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    return result.text;
  }

  // Heuristique : sur une étiquette colis, l'adresse se termine en général
  // par une ligne "code postal + ville". On récupère cette ligne et les 1-2
  // lignes juste au-dessus (numéro + nom de rue). Sans code postal détecté,
  // on retombe sur les 3 premières lignes du texte reconnu.
  String guessAddress(String ocrText) {
    final lines = ocrText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    for (var i = 0; i < lines.length; i++) {
      if (_postalCodeRe.hasMatch(lines[i])) {
        final start = (i - 2).clamp(0, lines.length);
        return lines.sublist(start, i + 1).join(', ');
      }
    }
    return lines.take(3).join(', ');
  }

  // Géocodage direct via Nominatim (OpenStreetMap), restreint à la France.
  // Respecte leur politique d'usage (max 1 requête/seconde) : voir le délai
  // imposé entre deux appels côté appelant (PackageScanScreen).
  Future<GeoPoint?> geocode(String address) async {
    if (address.trim().isEmpty) return null;
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'q': address,
      'countrycodes': 'fr',
      'limit': '1',
    });
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'ma_tournee (usage personnel, non-commercial)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body) as List;
      if (list.isEmpty) return null;
      final item = list.first as Map<String, dynamic>;
      final lat = double.tryParse(item['lat'] as String);
      final lng = double.tryParse(item['lon'] as String);
      if (lat == null || lng == null) return null;
      return GeoPoint(lat, lng);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _recognizer.close();
  }
}
