import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

/// Challenge reels are Mixkit clips (free licence). They're downloaded the
/// first time they're played and kept on the phone, so the app stays small
/// and later plays work offline.
class ReelCache {
  ReelCache._();

  static String url(int id) => 'https://assets.mixkit.co/videos/$id/$id-720.mp4';

  static Future<File> _file(int id) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/reels');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return File('${dir.path}/$id.mp4');
  }

  /// A ready-to-initialise controller: the saved copy if there is one,
  /// otherwise the clip is streamed now and saved in the background.
  static Future<VideoPlayerController> controller(int id) async {
    if (kIsWeb) return VideoPlayerController.networkUrl(Uri.parse(url(id)));
    final file = await _file(id);
    if (file.existsSync() && file.lengthSync() > 0) return VideoPlayerController.file(file);
    _download(id, file);
    return VideoPlayerController.networkUrl(Uri.parse(url(id)));
  }

  static final Set<int> _inFlight = {};

  static Future<void> _download(int id, File file) async {
    if (!_inFlight.add(id)) return;
    final tmp = File('${file.path}.part');
    try {
      final client = HttpClient();
      final response = await (await client.getUrl(Uri.parse(url(id)))).close();
      if (response.statusCode == 200) {
        await response.pipe(tmp.openWrite());
        await tmp.rename(file.path);
      }
      client.close();
    } catch (e) {
      debugPrint('Reel download failed: $e');
      if (tmp.existsSync()) tmp.deleteSync();
    } finally {
      _inFlight.remove(id);
    }
  }
}
