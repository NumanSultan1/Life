// Renders the "Life" logo into the app icon source images.
// Run with: flutter test tool/render_app_icon_test.dart
// then: flutter pub run flutter_launcher_icons
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

/// Renders [mark] scaled to fill a [px]-sized square (88% so it isn't clipped).
Future<void> _renderSized(WidgetTester tester, Widget mark, double px, String outPath) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox.square(dimension: px, child: Center(child: SizedBox(height: px * 0.88, child: FittedBox(child: mark)))),
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

    await tester.runAsync(() async {
      await _loadFont('PlusJakartaSans', 'assets/google_fonts/PlusJakartaSans-ExtraBold.ttf');
      await _loadFont('NunitoLogo', 'assets/fonts/Nunito-Variable.ttf');
    });

    // A clean white tile with a faint lavender wash, like the reference.
    const background = DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white, Color(0xFFF1EFFF)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
    );
    // Full icon (iOS and older Android launchers).
    await _render(tester, const Stack(fit: StackFit.expand, children: [background, Center(child: LifeLogo(fontSize: 380))]), 'assets/icon/icon.png');
    // Adaptive icon layers: logo kept inside the 66% safe zone.
    await _render(tester, background, 'assets/icon/icon_bg.png');
    await _render(tester, const Center(child: LifeLogo(fontSize: 255)), 'assets/icon/icon_fg.png');

    // Android status-bar icon: a white runner on transparent, per density.
    const densities = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96};
    for (final entry in densities.entries) {
      final dir = Directory('android/app/src/main/res/drawable-${entry.key}')..createSync(recursive: true);
      final px = entry.value.toDouble();
      await _renderSized(tester, const RunnerMark(height: 1, color: Colors.white), px, '${dir.path}/ic_stat_life.png');
    }
  });
}
