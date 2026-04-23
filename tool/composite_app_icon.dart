// Composites the white brand logo onto a solid gold canvas and writes
// `assets/icons/icon.png` — the full-bleed launcher tile used by
// `flutter_launcher_icons` for iOS and legacy (pre-adaptive) Android.
//
// Matches the app's primary colour (#F59E0B) so the icon reads as one
// visual family with the splash background.
//
// Run:
//   dart run tool/composite_app_icon.dart
//   dart run flutter_launcher_icons

import 'dart:io';

import 'package:image/image.dart' as img;

const int _canvasSize = 1024;
// Centred inside the canvas. 800 leaves ~112 px of gold padding on each
// side — clear of iOS's ~180 px corner radius and Android's launcher mask
// while giving the wordmark real presence.
const int _logoSize = 800;

// #F59E0B — ThemeData primary, matches the splash gold.
final _goldBg = img.ColorRgb8(245, 158, 11);

void main() {
  final wordmarkBytes = File('assets/icons/arraf.png').readAsBytesSync();
  final wordmark = img.decodePng(wordmarkBytes);
  if (wordmark == null) {
    // ignore: avoid_print
    stderr.writeln('Could not decode assets/icons/arraf.png');
    exit(1);
  }

  // Square, max inner dimension; preserve aspect ratio just in case.
  final resized = img.copyResize(
    wordmark,
    width: _logoSize,
    height: _logoSize,
    interpolation: img.Interpolation.cubic,
  );

  final canvas = img.Image(
    width: _canvasSize,
    height: _canvasSize,
    numChannels: 4,
  );
  img.fill(canvas, color: _goldBg);

  // Centre the wordmark.
  final dx = (_canvasSize - resized.width) ~/ 2;
  final dy = (_canvasSize - resized.height) ~/ 2;
  img.compositeImage(canvas, resized, dstX: dx, dstY: dy);

  File(
    'assets/icons/icon.png',
  ).writeAsBytesSync(img.encodePng(canvas));

  // ignore: avoid_print
  print(
    '✓ Wrote assets/icons/icon.png (gold bg + arraf wordmark). '
    'Next: `dart run flutter_launcher_icons`.',
  );
}
