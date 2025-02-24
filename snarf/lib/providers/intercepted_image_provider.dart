import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class InterceptedImageProvider extends ImageProvider<InterceptedImageProvider> {
  final ImageProvider originalProvider;
  final bool hideImages;

  InterceptedImageProvider({
    required this.originalProvider,
    required this.hideImages,
  });

  @override
  Future<InterceptedImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<InterceptedImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      InterceptedImageProvider key, ImageDecoderCallback decode) {
    if (hideImages) {
      return OneFrameImageStreamCompleter(
        Future.value(ImageInfo(image: _generateBlockedImage())),
      );
    }
    return originalProvider.loadImage(key.originalProvider, decode);
  }

  ui.Image _generateBlockedImage() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.grey;
    canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), paint);
    final picture = recorder.endRecording();
    return picture.toImageSync(100, 100);
  }
}
