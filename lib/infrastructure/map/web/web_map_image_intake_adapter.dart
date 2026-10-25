import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'package:vtt_engine_core/vtt_engine_core.dart';
import '../../../application/map/map_image_header.dart';
import '../../../application/map/map_image_intake_port.dart';

class WebMapImageSource implements MapImageSource {
  final web.File file;
  WebMapImageSource(this.file);

  @override
  String get name => file.name;

  @override
  int get byteSize => file.size;

  @override
  Future<Uint8List> readRange(int start, int end) async {
    final jsBuffer = await file.slice(start, end).arrayBuffer().toDart;
    return jsBuffer.toDart.asUint8List();
  }
}

class MapImageIntakeAdapter implements MapImageIntakePort {
  const MapImageIntakeAdapter();

  @override
  Future<MapImageSource?> pick() async {
    final completer = Completer<MapImageSource?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = 'image/png,image/jpeg,image/webp,image/avif';
    input.style.display = 'none';

    web.document.body?.appendChild(input);

    input.onchange = ((web.Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      final file = files.item(0);
      input.remove();
      if (file == null) {
        if (!completer.isCompleted) completer.complete(null);
      } else {
        if (!completer.isCompleted) completer.complete(WebMapImageSource(file));
      }
    }).toJS;

    input.oncancel = ((web.Event _) {
      input.remove();
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;

    input.click();
    return completer.future;
  }

  Future<web.Blob?> _toBlob(
    web.HTMLCanvasElement canvas,
    String type,
    double quality,
  ) {
    final completer = Completer<web.Blob?>();
    canvas.toBlob(
      ((web.Blob? b) {
        completer.complete(b);
      }).toJS,
      type,
      quality.toJS,
    );
    return completer.future;
  }

  Future<Uint8List> _readEncodedOutput(web.Blob blob) async {
    final jsBuffer = await blob.arrayBuffer().toDart;
    return jsBuffer.toDart.asUint8List();
  }

  @override
  Future<NormalizedMapImage> normalize(
    MapImageSource source, {
    required int targetWidth,
    required int targetHeight,
  }) async {
    final web.Blob inputBlob;
    if (source is WebMapImageSource) {
      inputBlob = source.file;
    } else {
      throw const MapIntakeRejected(MapRejectReason.undecodable);
    }

    // 1. Decode bitmap with resize options (resizeWidth only, imageOrientation from-image)
    web.ImageBitmap bitmap;
    try {
      bitmap = await web.window.createImageBitmap(
        inputBlob,
        web.ImageBitmapOptions(
          resizeWidth: targetWidth,
          resizeQuality: 'high',
          imageOrientation: 'from-image',
        ),
      ).toDart;
    } catch (_) {
      throw const MapIntakeRejected(MapRejectReason.undecodable);
    }

    final bitmapHeight = bitmap.height;
    if ((bitmapHeight - targetHeight).abs() > 1) {
      final bWidth = bitmap.width;
      bitmap.close();
      throw MapIntakeRejected(
        MapRejectReason.orientationMismatch,
        width: bWidth,
        height: bitmapHeight,
      );
    }

    // 2. Create an HTMLCanvasElement of exactly targetWidth x targetHeight, fill opaque white, draw bitmap
    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = targetWidth;
    canvas.height = targetHeight;
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.fillStyle = '#FFFFFF'.toJS;
    ctx.fillRect(0, 0, targetWidth, targetHeight);
    ctx.drawImage(bitmap, 0, 0, targetWidth, targetHeight);
    bitmap.close();

    void cleanupCanvas() {
      canvas.width = 0;
      canvas.height = 0;
    }

    // 3. canvas.toBlob(..., 'image/webp', 0.85). Fallback to 'image/jpeg'
    String selectedMime = 'image/webp';
    BlobFormat selectedFormat = BlobFormat.webp;

    web.Blob? encodedBlob = await _toBlob(canvas, 'image/webp', 0.85);
    if (encodedBlob == null || encodedBlob.type != 'image/webp') {
      selectedMime = 'image/jpeg';
      selectedFormat = BlobFormat.jpeg;
      encodedBlob = await _toBlob(canvas, 'image/jpeg', 0.85);
      if (encodedBlob == null || encodedBlob.type != 'image/jpeg') {
        cleanupCanvas();
        throw const MapIntakeRejected(MapRejectReason.encoderMismatch);
      }
    }

    // 4. If result is over BlobRef.maxByteSize, encode once more at quality 0.6
    if (encodedBlob.size > BlobRef.maxByteSize) {
      encodedBlob = await _toBlob(canvas, selectedMime, 0.6);
      if (encodedBlob == null || encodedBlob.type != selectedMime) {
        cleanupCanvas();
        throw const MapIntakeRejected(MapRejectReason.encoderMismatch);
      }
      if (encodedBlob.size > BlobRef.maxByteSize) {
        final badSize = encodedBlob.size;
        cleanupCanvas();
        throw MapIntakeRejected(MapRejectReason.outputTooLarge, byteSize: badSize);
      }
    }

    // 5. Read result into Dart, run readMapImageHeader on it
    final outBytes = await _readEncodedOutput(encodedBlob);
    cleanupCanvas();

    final header = await readMapImageHeader(
      (start, end) async => outBytes.sublist(start, end),
      outBytes.length,
    );

    final expectedFormat = selectedFormat == BlobFormat.webp
        ? MapInputFormat.webp
        : MapInputFormat.jpeg;
    if (header.format != expectedFormat ||
        header.width != targetWidth ||
        header.height != targetHeight) {
      throw const MapIntakeRejected(MapRejectReason.encoderMismatch);
    }

    return NormalizedMapImage(
      bytes: outBytes,
      width: targetWidth,
      height: targetHeight,
      format: selectedFormat,
    );
  }
}
