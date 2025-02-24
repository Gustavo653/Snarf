import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class InterceptedImageProvider extends ImageProvider<InterceptedImageProvider> {
  final ImageProvider originalProvider;
  final bool hideImages;

  static final Map<ImageProvider, ImageInfo> _originalImageCache = {};
  static final Map<ImageProvider, ImageInfo> _blockedImageCache = {};

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
      if (!_blockedImageCache.containsKey(originalProvider)) {
        _blockedImageCache[originalProvider] = ImageInfo(
          image: _generateBlockedImage(),
          scale: 1.0,
        );
      }

      return OneFrameImageStreamCompleter(
        Future.value(_blockedImageCache[originalProvider]!.clone()),
      );
    }

    if (_originalImageCache.containsKey(originalProvider)) {
      return OneFrameImageStreamCompleter(
        Future.value(_originalImageCache[originalProvider]!.clone()),
      );
    }

    final completer = Completer<ImageInfo>();
    final stream = originalProvider.resolve(ImageConfiguration.empty);

    stream.addListener(
      ImageStreamListener((imageInfo, _) {
        _originalImageCache[originalProvider] = imageInfo;
        completer.complete(imageInfo.clone());
      }),
    );

    return OneFrameImageStreamCompleter(completer.future);
  }

  ui.Image _generateBlockedImage() {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = _getRandomColor();
    canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), paint);
    final picture = recorder.endRecording();
    return picture.toImageSync(100, 100);
  }

  Color _getRandomColor() {
    final random = Random();
    return Color.fromARGB(
      255,
      random.nextInt(256),
      random.nextInt(256),
      random.nextInt(256),
    );
  }
}