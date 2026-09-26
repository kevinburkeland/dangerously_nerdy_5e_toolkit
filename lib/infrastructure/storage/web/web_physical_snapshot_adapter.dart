import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:vtt_engine_core/storage/models/storage_snapshot_bundle.dart';
import 'package:vtt_engine_core/storage/ports/i_physical_snapshot_port.dart';

/// Web implementation of [IPhysicalSnapshotPort] using HTML Blob downloads and FileReader.
class PhysicalSnapshotAdapter implements IPhysicalSnapshotPort {
  const PhysicalSnapshotAdapter();

  @override
  Future<void> exportAtomicSnapshot({
    required String fileName,
    required StorageSnapshotBundle bundle,
  }) async {
    final bytes = bundle.toBytes();
    final jsBytes = bytes.toJS;
    final blob = web.Blob(
      [jsBytes].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );

    final url = web.URL.createObjectURL(blob);
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();

    scheduleMicrotask(() {
      web.URL.revokeObjectURL(url);
    });
  }

  @override
  Future<StorageSnapshotBundle?> importAtomicSnapshot() async {
    final completer = Completer<StorageSnapshotBundle?>();
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.accept = '.dndvault,.bin';
    input.style.display = 'none';

    web.document.body?.appendChild(input);

    input.onchange = (web.Event event) {
      final files = input.files;
      if (files == null || files.length == 0) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0);
      if (file == null) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final reader = web.FileReader();
      reader.onload = (web.Event _) {
        try {
          final result = reader.result;
          // ignore: sdk_version_since
          if (result != null && result.isA<JSArrayBuffer>()) {
            final buffer = result as JSArrayBuffer;
            final uint8List = buffer.toDart.asUint8List();
            final bundle = StorageSnapshotBundle.fromBytes(uint8List);
            input.remove();
            if (!completer.isCompleted) completer.complete(bundle);
          } else {
            input.remove();
            if (!completer.isCompleted) completer.complete(null);
          }
        } catch (_) {
          input.remove();
          if (!completer.isCompleted) completer.complete(null);
        }
      }.toJS;

      reader.onerror = (web.Event _) {
        input.remove();
        if (!completer.isCompleted) completer.complete(null);
      }.toJS;

      reader.readAsArrayBuffer(file);
    }.toJS;

    input.oncancel = (web.Event _) {
      input.remove();
      if (!completer.isCompleted) completer.complete(null);
    }.toJS;

    input.click();
    return completer.future;
  }
}
