import 'package:flutter/foundation.dart';

/// Web stand-in for the offline Pashto voice model (phones only).
class PashtoVoice {
  PashtoVoice._();

  static const sizeLabel = '175 MB';
  static bool get supported => false;
  static final level = ValueNotifier<double>(0);
  static VoidCallback? onSilence;
  static Future<void> warmUp() async {}

  static Future<bool> isDownloaded() async => false;
  static Future<void> download(void Function(double) onProgress, {bool Function()? cancelled}) async => throw UnsupportedError('Pashto voice works on the phone app.');
  static Future<void> deleteModel() async {}
  static Future<bool> hasMicPermission() async => false;
  static Future<void> startRecording() async {}
  static Future<void> cancelRecording() async {}
  static Future<String> stopAndTranscribe({String? hints, void Function(int percent)? onProgress}) async => '';
}
