import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'hive_service.dart';

/// Saves everything that belongs to the current user to one JSON file and
/// brings it back. Records are stored under `<user>_...` keys in each box,
/// so a backup can be restored into any account.
class BackupService {
  static const _boxes = [
    HiveService.tasksBox,
    HiveService.habitsBox,
    HiveService.journalBox,
    HiveService.goalsBox,
    HiveService.settingsBox,
  ];

  static Object? _plain(Object? v) {
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), _plain(val)));
    if (v is List) return v.map(_plain).toList();
    if (v is DateTime) return v.toIso8601String();
    return v;
  }

  static Map<String, dynamic> export() {
    final user = HiveService.getCurrentUser();
    final prefix = '${user}_';
    final data = <String, dynamic>{};
    for (final name in _boxes) {
      final box = Hive.box(name);
      data[name] = {
        for (final k in box.keys)
          if (k.toString().startsWith(prefix)) k.toString().substring(prefix.length): _plain(box.get(k)),
      };
    }
    return {'app': 'Life', 'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'user': user, 'data': data};
  }

  // --- Password protection (AES-256-GCM, key from PBKDF2-HMAC-SHA256) ---

  static const _iterations = 120000;

  static Future<SecretKey> _deriveKey(String password, List<int> salt, int iterations) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  /// Wraps a backup so it can only be read with [password].
  static Future<Map<String, dynamic>> encrypt(Map<String, dynamic> backup, String password) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(password, salt, _iterations);
    final box = await AesGcm.with256bits().encrypt(utf8.encode(jsonEncode(backup)), secretKey: key);
    return {
      'app': 'Life',
      'version': 2,
      'encrypted': true,
      'kdf': 'pbkdf2-sha256',
      'iterations': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    };
  }

  static bool isEncrypted(Object? json) => json is Map && json['app'] == 'Life' && json['encrypted'] == true;

  /// Opens a password-protected backup. Throws [FormatException] if the
  /// password is wrong or the file was changed.
  static Future<Object?> decrypt(Map json, String password) async {
    try {
      final iterations = (json['iterations'] as num).toInt();
      if (iterations < 10000 || iterations > 5000000) throw const FormatException('Unsupported backup.');
      final key = await _deriveKey(password, base64Decode(json['salt'] as String), iterations);
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(base64Decode(json['data'] as String), nonce: base64Decode(json['nonce'] as String), mac: Mac(base64Decode(json['mac'] as String))),
        secretKey: key,
      );
      return jsonDecode(utf8.decode(clear));
    } on SecretBoxAuthenticationError {
      throw const FormatException('Wrong password, or the backup file was changed.');
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('This backup file is damaged.');
    }
  }

  /// Asks where to save; returns false if cancelled. With a [password]
  /// the file is encrypted.
  static Future<bool> saveToFile({String? password}) async {
    final content = password == null || password.isEmpty ? export() : await encrypt(export(), password);
    final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent(' ').convert(content)));
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save your Life backup',
      fileName: 'life-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    return path != null;
  }

  /// Lets the user pick a backup and replaces their data with it. Returns
  /// null if cancelled; throws [FormatException] for a file that isn't a
  /// Life backup.
  static Future<int?> pickAndRestore({required Future<String?> Function() askPassword}) async {
    final result = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['json'], withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return null;
    if (bytes.length > 50 * 1024 * 1024) throw const FormatException('This file is too large to be a Life backup.');
    Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('This file is not a Life backup.');
    }
    if (isEncrypted(json)) {
      final password = await askPassword();
      if (password == null) return null;
      json = await decrypt(json as Map, password);
    }
    return restore(json);
  }

  /// Only plain JSON values (no odd types) may come from a backup file.
  static bool _isPlainValue(Object? v, [int depth = 0]) {
    if (depth > 12) return false;
    if (v == null || v is String || v is num || v is bool) return true;
    if (v is List) return v.every((e) => _isPlainValue(e, depth + 1));
    if (v is Map) return v.keys.every((k) => k is String) && v.values.every((e) => _isPlainValue(e, depth + 1));
    return false;
  }

  /// Returns how many records were restored.
  static Future<int> restore(Object? json) async {
    if (json is! Map || json['app'] != 'Life' || json['data'] is! Map || !_isPlainValue(json['data'])) {
      throw const FormatException('This file is not a Life backup.');
    }
    final user = HiveService.getCurrentUser();
    final prefix = '${user}_';
    final data = json['data'] as Map;
    var count = 0;
    for (final name in _boxes) {
      final records = data[name];
      if (records is! Map) continue;
      final box = Hive.box(name);
      final mine = box.keys.where((k) => k.toString().startsWith(prefix)).toList();
      await box.deleteAll(mine);
      await box.putAll({for (final e in records.entries) '$prefix${e.key}': e.value});
      count += records.length;
    }
    return count;
  }
}
