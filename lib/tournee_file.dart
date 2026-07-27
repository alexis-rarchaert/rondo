import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'models.dart';

const String _magic = 'TOURNEE';

List<int> _xorWithKey(List<int> bytes, List<int> key) {
  return List<int>.generate(bytes.length, (i) => bytes[i] ^ key[i % key.length]);
}

// Format d'export/import ".tournee" : le JSON de la tournée est brouillé par
// XOR avec la clé "TOURNEE" (réversible) puis encodé en base64, empaqueté
// avec une empreinte SHA-256 du contenu d'origine pour détecter un fichier
// corrompu ou invalide à l'import.
class TourneeFile {
  static String encode(AppData data) {
    final jsonStr = jsonEncode(data.toJson());
    final keyBytes = utf8.encode(_magic);
    final payload = base64Encode(_xorWithKey(utf8.encode(jsonStr), keyBytes));
    final checksum = sha256.convert(utf8.encode(jsonStr)).toString();
    return jsonEncode({
      'magic': _magic,
      'version': 1,
      'checksum': checksum,
      'payload': payload,
    });
  }

  // Lève une [FormatException] explicite si le fichier n'est pas un export
  // ".tournee" valide ou a été altéré.
  static AppData decode(String fileContent) {
    final Map<String, dynamic> wrapper;
    try {
      wrapper = jsonDecode(fileContent) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException("Ce fichier n'est pas un export de tournée valide.");
    }

    if (wrapper['magic'] != _magic) {
      throw const FormatException("Ce fichier n'est pas un export de tournée valide.");
    }
    final payload = wrapper['payload'] as String?;
    final checksum = wrapper['checksum'] as String?;
    if (payload == null || checksum == null) {
      throw const FormatException('Fichier de tournée incomplet.');
    }

    final String jsonStr;
    try {
      final keyBytes = utf8.encode(_magic);
      jsonStr = utf8.decode(_xorWithKey(base64Decode(payload), keyBytes));
    } catch (_) {
      throw const FormatException('Fichier de tournée illisible.');
    }

    if (sha256.convert(utf8.encode(jsonStr)).toString() != checksum) {
      throw const FormatException('Fichier de tournée corrompu (empreinte invalide).');
    }

    return AppData.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }
}
