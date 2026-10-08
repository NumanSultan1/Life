import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

/// Offline Pashto voice typing. Google has no Pashto speech model, so Life
/// downloads a Pashto-trained Whisper model once (Adnan666/
/// whisper-small-pashto-stage2-v2, Apache-2.0, converted to whisper.cpp
/// q5_0) and runs it on the phone. Audio never leaves the device.
class PashtoVoice {
  PashtoVoice._();

  static const modelUrl = 'https://github.com/NumanSultan1/vortex-tech-appdev-week4/releases/download/pashto-voice-v1/ggml-pashto-small-q5_0.bin';
  static const modelBytes = 175209680;
  static const modelSha256 = '56ede336fa6541141b9c7ff2691edb54859f122d95bbd87aea812dd08ed12b91';
  static const sizeLabel = '175 MB';

  static bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static final _recorder = AudioRecorder();
  static String? _recordingPath;
  static Timer? _meter;
  static double _loudest = -160;
  static DateTime _lastSpeech = DateTime.now();
  static Timer? _releaseTimer;
  static bool _warm = false;

  /// Called when the user stops talking (about 1.5 s of quiet after
  /// speech), so recording can end without tapping stop.
  static VoidCallback? onSilence;

  /// Live loudness (0..1) while recording, for the mic animation.
  static final level = ValueNotifier<double>(0);

  static Future<String> _modelPath() async => '${(await getApplicationSupportDirectory()).path}/models/ggml-pashto-small-q5_0.bin';

  static Future<bool> isDownloaded() async {
    if (!supported) return false;
    final f = File(await _modelPath());
    return f.existsSync() && f.lengthSync() == modelBytes;
  }

  /// Downloads the model; [onProgress] gets 0..1. Throws on failure.
  static Future<void> download(void Function(double) onProgress, {bool Function()? cancelled}) async {
    final path = await _modelPath();
    final part = File('$path.part');
    await part.parent.create(recursive: true);
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(modelUrl)));
      if (res.statusCode != 200) throw Exception('Download failed (${res.statusCode})');
      final sink = part.openWrite();
      var received = 0;
      try {
        await for (final chunk in res.stream) {
          if (cancelled?.call() == true) throw const _Cancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress(received / modelBytes);
        }
      } finally {
        await sink.close();
      }
      if (part.lengthSync() != modelBytes) throw Exception('The download was incomplete. Please try again.');
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString() != modelSha256) throw Exception('The download was damaged. Please try again.');
      await part.rename(path);
    } catch (e) {
      if (part.existsSync()) await part.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Loads the model in the background so the first sentence is quick.
  static Future<void> warmUp() async {
    if (_warm || !await isDownloaded()) return;
    _warm = true;
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/pashto_warmup.wav');
      if (!f.existsSync()) await f.writeAsBytes(_silentWav(16000));
      await _transcribe(f.path);
    } catch (_) {
      _warm = false;
    }
  }

  /// One second of silence as a 16 kHz mono WAV.
  static List<int> _silentWav(int samples) {
    final data = samples * 2;
    final b = BytesBuilder();
    void str(String s) => b.add(s.codeUnits);
    void u32(int v) => b.add([v & 0xff, (v >> 8) & 0xff, (v >> 16) & 0xff, (v >> 24) & 0xff]);
    void u16(int v) => b.add([v & 0xff, (v >> 8) & 0xff]);
    str('RIFF');
    u32(36 + data);
    str('WAVEfmt ');
    u32(16);
    u16(1);
    u16(1);
    u32(16000);
    u32(32000);
    u16(2);
    u16(16);
    str('data');
    u32(data);
    b.add(List.filled(data, 0));
    return b.toBytes();
  }

  static Future<void> deleteModel() async {
    final f = File(await _modelPath());
    if (f.existsSync()) await f.delete();
  }

  static Future<bool> hasMicPermission() => _recorder.hasPermission();

  static Future<void> startRecording() async {
    final dir = await getTemporaryDirectory();
    _recordingPath = '${dir.path}/pashto_${DateTime.now().millisecondsSinceEpoch}.wav';
    _loudest = -160;
    _lastSpeech = DateTime.now();
    final started = DateTime.now();
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: _recordingPath!);
    _meter = Timer.periodic(const Duration(milliseconds: 150), (_) async {
      final a = await _recorder.getAmplitude();
      if (a.current > _loudest) _loudest = a.current;
      if (a.current > -42) _lastSpeech = DateTime.now();
      level.value = ((a.current + 50) / 50).clamp(0.0, 1.0);
      final quiet = DateTime.now().difference(_lastSpeech);
      if (_loudest > -40 && quiet > const Duration(milliseconds: 1200) && DateTime.now().difference(started) > const Duration(seconds: 1)) {
        onSilence?.call();
      }
    });
  }

  static void _stopMeter() {
    _meter?.cancel();
    _meter = null;
    level.value = 0;
  }

  static Future<void> cancelRecording() async {
    _stopMeter();
    await _recorder.cancel();
    _recordingPath = null;
  }

  /// Stops recording and turns the speech into Pashto text.
  static Future<String> stopAndTranscribe({String? hints, void Function(int percent)? onProgress}) async {
    _stopMeter();
    final path = await _recorder.stop() ?? _recordingPath;
    _recordingPath = null;
    if (path == null) return '';
    // Whisper invents sentences from silence, so skip quiet recordings.
    if (_loudest < -40) {
      final f = File(path);
      if (f.existsSync()) await f.delete();
      return '';
    }
    try {
      return (await _transcribe(path, hints: hints, onProgress: onProgress)).trim();
    } finally {
      for (final p in [path, '$path.wav']) {
        final f = File(p);
        if (f.existsSync()) await f.delete();
      }
    }
  }
}

/// Shared settings for speed: the model stays loaded between uses, the
/// encoder only processes the recorded length ("speed_up", see
/// packages/whisper_ggml/LIFE_CHANGES.md), and 4 threads use the fast cores.
Future<String> _transcribe(String path, {String? hints, void Function(int percent)? onProgress}) {
  // One at a time: the native model isn't safe to use concurrently
  // (e.g. the warm-up still running when the user speaks).
  final run = _queue.then((_) => _transcribeNow(path, hints: hints, onProgress: onProgress));
  _queue = run.then((_) {}, onError: (_) {});
  return run;
}

Future<void> _queue = Future.value();

Future<String> _transcribeNow(String path, {String? hints, void Function(int percent)? onProgress}) async {
  PashtoVoice._releaseTimer?.cancel();
  final res = await const Whisper(model: WhisperModel.small).transcribe(
    transcribeRequest: TranscribeRequest(
      audio: path,
      language: 'ps',
      isNoTimestamps: true,
      threads: Platform.numberOfProcessors.clamp(2, 4),
      speedUp: true,
      keepModelLoaded: true,
      // Nudges decoding toward Pashto script and punctuation.
      initialPrompt: 'زه نن ښه یم. دا زما ورځنۍ لیکنه ده.${hints == null || hints.isEmpty ? '' : ' $hints'}',
      suppressNonSpeechTokens: true,
    ),
    modelPath: await PashtoVoice._modelPath(),
    onProgress: onProgress,
  );
  PashtoVoice._warm = true;
  // Free the memory if Pashto voice isn't used for a while.
  PashtoVoice._releaseTimer = Timer(const Duration(minutes: 5), () {
    PashtoVoice._warm = false;
    const Whisper(model: WhisperModel.small).releaseModel();
  });
  return res.text;
}

class _Cancelled implements Exception {
  const _Cancelled();
  @override
  String toString() => 'Download cancelled';
}
