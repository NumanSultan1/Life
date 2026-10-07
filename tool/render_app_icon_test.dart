// Renders the "life" logo into the app icon source images.
// Run with: flutter test tool/render_app_icon_test.dart
// then: dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vortextech_appdev_week4/widgets/life_logo.dart';

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

Future<void> _render(WidgetTester tester, Widget child, String outPath) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(size: Size(1024, 1024)),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'PlusJakartaSans'),
          child: Center(child: RepaintBoundary(key: key, child: SizedBox.square(dimension: 1024, child: child))),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File(outPath).writeAsBytesSync(png!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('render app icon images', (tester) async {
    tester.view.physicalSize = const Size(1024, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final flutterRoot = Platform.environment['FLUTTER_ROOT']!;
    await tester.runAsync(() async {
      await _loadFont('PlusJakartaSans', 'assets/google_fonts/PlusJakartaSans-ExtraBold.ttf');
      await _loadFont('MaterialIcons', '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    });

    // A calm brand gradient (no pink glow) so the pink runner stands out.
    final background = DecoratedBox(
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF3D72E6), Color(0xFF0B47C8), Color(0xFF051F82)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: RadialGradient(center: const Alignment(0.8, -0.8), radius: 0.9, colors: [const Color(0xFF6CB6F5).withValues(alpha: 0.7), const Color(0xFF6CB6F5).withValues(alpha: 0)])),
      ),
    );
    // Full icon (iOS and older Android launchers).
    await _render(tester, Stack(fit: StackFit.expand, children: [background, const Center(child: LifeLogo(fontSize: 300, onLiquid: true))]), 'assets/icon/icon.png');
    // Adaptive icon layers: logo kept inside the 66% safe zone.
    await _render(tester, background, 'assets/icon/icon_bg.png');
    await _render(tester, const Center(child: LifeLogo(fontSize: 210, onLiquid: true)), 'assets/icon/icon_fg.png');
  });
}
