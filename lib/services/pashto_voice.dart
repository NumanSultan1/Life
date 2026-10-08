// The Pashto model runs through native code (dart:ffi), which the web
// build can't use; there it's a stub that reports "not supported".
export 'pashto_voice_stub.dart' if (dart.library.ffi) 'pashto_voice_io.dart';
