import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Opens Life's storage encrypted (AES-256) with a key kept in the
/// Android Keystore, and converts existing plain data once, safely: a raw
/// copy of each box is kept until its encrypted version is fully written,
/// so an interrupted conversion is redone on the next start.
class SecureBoxes {
  SecureBoxes._();

  // resetOnError: false so a Keystore hiccup never silently throws away
  // the key (which would make the data unreadable).
  static const _storage = FlutterSecureStorage(aOptions: AndroidOptions(resetOnError: false));
  static const _keyName = 'life_hive_key_v1';
  static const _version = 'v1';

  static Future<HiveAesCipher> _cipher() async {
    var encoded = await _storage.read(key: _keyName);
    if (encoded == null) {
      encoded = base64Encode(Hive.generateSecureKey());
      await _storage.write(key: _keyName, value: encoded);
    }
    return HiveAesCipher(base64Decode(encoded));
  }

  static Future<void> openAll(List<String> names) async {
    final cipher = await _cipher();
    final dir = (await getApplicationDocumentsDirectory()).path;
    for (final name in names) {
      await openBox(name, dir: dir, cipher: cipher, read: (k) => _storage.read(key: k), write: (k, v) => _storage.write(key: k, value: v));
    }
  }

  /// Opens one box encrypted, converting plain data first if needed.
  /// [read]/[write] store the per-box "converted" marker (the Keystore in
  /// the app, a map in tests).
  static Future<void> openBox(
    String name, {
    required String dir,
    required HiveAesCipher cipher,
    required Future<String?> Function(String key) read,
    required Future<void> Function(String key, String value) write,
  }) async {
    final marker = 'enc_$name';
    final file = File('$dir/${name.toLowerCase()}.hive');
    final bak = File('${file.path}.premigration');

    if (await read(marker) == _version) {
      // Converted already; remove any leftover plain copy.
      if (bak.existsSync()) await bak.delete();
      await Hive.openBox(name, encryptionCipher: cipher);
      return;
    }

    // A previous conversion was interrupted: start again from the copy.
    if (bak.existsSync()) {
      if (file.existsSync()) await file.delete();
      await bak.copy(file.path);
    }

    var data = <dynamic, dynamic>{};
    if (file.existsSync()) {
      await file.copy(bak.path);
      final plain = await Hive.openBox(name);
      data = Map<dynamic, dynamic>.of(plain.toMap());
      await plain.close();
      await Hive.deleteBoxFromDisk(name);
    }
    final box = await Hive.openBox(name, encryptionCipher: cipher);
    if (data.isNotEmpty) await box.putAll(data);
    await box.flush();
    await write(marker, _version);
    if (bak.existsSync()) await bak.delete();
  }
}
