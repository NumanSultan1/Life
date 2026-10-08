# Changes made for Life

Copy of [whisper_ggml 2.7.1](https://pub.dev/packages/whisper_ggml) (MIT licence, see LICENSE), with one change in
`android/src/whisper/main.cpp`:

- The `speed_up` request flag now sets whisper.cpp's `audio_ctx` to the clip's length (plus one second, at least 384
  frames). Whisper otherwise always encodes a full 30-second window, so a 5-second Pashto sentence took as long as a
  30-second one. On test Pashto clips the text was identical and transcription was about 3x faster.
- Removed the ffmpeg audio conversion (and the `ffmpeg_kit_flutter_new_min` dependency). Life records 16 kHz mono
  WAV, which whisper.cpp reads directly, so each transcription skips a conversion step and the APK is smaller.
