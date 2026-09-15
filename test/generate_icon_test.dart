import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Generate Icon', (WidgetTester tester) async {
    // We need to load the Material font first.
    // However, in test environment, Material icons are sometimes placeholders if not loaded.
    // Wait, flutter test uses a placeholder font by default unless we load it.
    // Let's just draw the canvas.
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(1024, 1024);

    // Draw background gradient
    final gradient = ui.Gradient.linear(
      Offset.zero,
      Offset(1024, 1024),
      [Color(0xFFE53935), Color(0xFFFF6B6B)],
    );
    final paint = Paint()..shader = gradient;
    canvas.drawRect(Rect.fromLTWH(0, 0, 1024, 1024), paint);

    // Draw phone icon.
    // Instead of risking the font not loading, we can draw a simplified phone or use a known icon.
    // Or we can just use the Material font since this is a Flutter project.
    // To ensure the font is loaded in tests:

    // Actually, flutter_test doesn't load MaterialIcons by default.
    // But we can just use a TextPainter with the icon codepoint!
    TextSpan span = TextSpan(
      text: String.fromCharCode(Icons.phone_in_talk_rounded.codePoint),
      style: TextStyle(
        fontSize: 600,
        color: Colors.white,
        fontFamily: Icons.phone_in_talk_rounded.fontFamily,
        package: Icons.phone_in_talk_rounded.fontPackage,
      ),
    );
    
    TextPainter tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas, 
      Offset(
        (size.width - tp.width) / 2, 
        (size.height - tp.height) / 2
      )
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(1024, 1024);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    File('assets/app_icon.png').writeAsBytesSync(buffer);
    debugPrint('Successfully generated assets/app_icon.png');
  });
}
