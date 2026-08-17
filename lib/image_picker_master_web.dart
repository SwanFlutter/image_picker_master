// lib/image_picker_master_web.dart
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/file_type.dart';
import 'src/tools/picked_file.dart';

/// Web implementation of [ImagePickerMasterPlatform].
/// Uses package:web (WASM-compatible) instead of dart:html.
class ImagePickerMasterWeb extends ImagePickerMasterPlatform {
  ImagePickerMasterWeb();

  static void registerWith(Registrar registrar) {
    ImagePickerMasterPlatform.instance = ImagePickerMasterWeb();
  }

  // ─── getPlatformVersion ─────────────────────────────────────────────────

  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  // ─── pickFiles ──────────────────────────────────────────────────────────

  @override
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) async {
    final completer = Completer<List<PickedFile>?>();

    // Create a hidden <input type="file"> element
    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.style.display = 'none';
    input.accept = _acceptString(options.type, options.allowedExtensions);
    input.multiple = options.allowMultiple;

    web.document.body!.append(input);

    // ── onChange: user selected files ──
    input.addEventListener(
      'change',
      (web.Event _) async {
        final fileList = input.files;
        if (fileList == null || fileList.length == 0) {
          input.remove();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }

        final results = <PickedFile>[];
        for (var i = 0; i < fileList.length; i++) {
          final file = fileList.item(i);
          if (file == null) continue;
          final pf = await _processFile(file, options);
          if (pf != null) results.add(pf);
        }

        input.remove();
        if (!completer.isCompleted) {
          completer.complete(results.isEmpty ? null : results);
        }
      }.toJS,
    );

    // ── Window focus after dialog close → treat empty selection as cancel ──
    StreamSubscription<web.Event>? focusSub;
    focusSub = web.window.onFocus.listen((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!completer.isCompleted) {
          final fl = input.files;
          if (fl == null || fl.length == 0) {
            input.remove();
            focusSub?.cancel();
            completer.complete(null);
          }
        }
        focusSub?.cancel();
      });
    });

    // Safety timeout (5 min)
    Future.delayed(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        input.remove();
        focusSub?.cancel();
        completer.complete(null);
      }
    });

    input.click();
    return completer.future;
  }

  // ─── capturePhoto ────────────────────────────────────────────────────────

  @override
  Future<PickedFile?> capturePhoto({
    required bool allowCompression,
    required int compressionQuality,
    required bool withData,
  }) async {
    // Check getUserMedia support
    if (web.window.navigator.mediaDevices == null) {
      throw PlatformException(
        code: 'CAMERA_NOT_SUPPORTED',
        message: 'Camera is not supported in this browser.',
      );
    }

    web.MediaStream stream;
    try {
      final constraints = web.MediaStreamConstraints(video: true.toJS);
      stream = await web.window.navigator.mediaDevices!
          .getUserMedia(constraints)
          .toDart;
    } catch (_) {
      throw PlatformException(
        code: 'CAMERA_ACCESS_DENIED',
        message: 'Camera permission was denied.',
      );
    }

    final imageBytes = await _showCameraDialog(stream);

    // Stop all camera tracks
    final tracks = stream.getTracks();
    for (var i = 0; i < tracks.length; i++) {
      tracks.item(i)?.stop();
    }

    if (imageBytes == null) return null;

    Uint8List finalBytes = imageBytes;
    if (allowCompression) {
      finalBytes = await _compressJpeg(imageBytes, compressionQuality);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'captured_photo_$timestamp.jpg';

    // Create an object URL so the caller can reference the blob
    final blob = web.Blob(
      [finalBytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/jpeg'),
    );
    final objectUrl = web.URL.createObjectURL(blob);

    return PickedFile(
      path: objectUrl,
      name: fileName,
      size: finalBytes.length,
      mimeType: 'image/jpeg',
      bytes: withData ? finalBytes : null,
    );
  }

  // ─── clearTemporaryFiles ─────────────────────────────────────────────────

  @override
  Future<void> clearTemporaryFiles() async {
    // Web files are in-memory / object-URLs; no temp files to clean up.
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _acceptString(FileType type, List<String>? allowedExtensions) {
    switch (type) {
      case FileType.image:
        return 'image/*';
      case FileType.video:
        return 'video/*';
      case FileType.audio:
        return 'audio/*';
      case FileType.document:
        return '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.rtf,'
            '.odt,.ods,.odp,.epub,.html,.css,.js,.json,.xml,.csv,'
            '.zip,.rar,.7z,.tar,.gz';
      case FileType.custom:
        if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
          return allowedExtensions.map((e) => '.$e').join(',');
        }
        return '*/*';
      case FileType.all:
        return '*/*';
    }
  }

  Future<PickedFile?> _processFile(
    web.File file,
    FilePickerOptions options,
  ) async {
    try {
      // Read file bytes via FileReader
      final reader = web.FileReader();
      final loadCompleter = Completer<Uint8List?>();

      reader.addEventListener(
        'load',
        (web.Event _) {
          final result = reader.result;
          if (result == null) {
            loadCompleter.complete(null);
            return;
          }
          // result is a JS ArrayBuffer
          final jsBuffer = result as JSArrayBuffer;
          final dartBytes = jsBuffer.toDart.asUint8List();
          loadCompleter.complete(dartBytes);
        }.toJS,
      );

      reader.addEventListener(
        'error',
        (web.Event _) => loadCompleter.complete(null).toJS,
      );

      reader.readAsArrayBuffer(file);
      Uint8List? bytes = await loadCompleter.future;
      if (bytes == null) return null;

      // Compress images if requested
      if (options.allowCompression && file.type.startsWith('image/')) {
        bytes = await _compressJpeg(bytes, options.compressionQuality ?? 80);
      }

      // Object URL for path
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: file.type),
      );
      final objectUrl = web.URL.createObjectURL(blob);

      return PickedFile(
        path: objectUrl,
        name: file.name,
        size: file.size.toInt(),
        mimeType: file.type.isEmpty ? null : file.type,
        bytes: options.withData ? bytes : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Shows a modal camera preview and returns JPEG bytes on capture, or null on cancel.
  Future<Uint8List?> _showCameraDialog(web.MediaStream stream) async {
    final completer = Completer<Uint8List?>();

    // ── DOM elements ──
    final overlay = web.document.createElement('div') as web.HTMLDivElement;
    _applyStyles(overlay, {
      'position': 'fixed',
      'inset': '0',
      'background': 'rgba(0,0,0,.8)',
      'z-index': '99999',
      'display': 'flex',
      'align-items': 'center',
      'justify-content': 'center',
    });

    final dialog = web.document.createElement('div') as web.HTMLDivElement;
    _applyStyles(dialog, {
      'background': '#fff',
      'border-radius': '10px',
      'padding': '20px',
      'display': 'flex',
      'flex-direction': 'column',
      'align-items': 'center',
      'gap': '16px',
      'max-width': '90vw',
    });

    final video = web.document.createElement('video') as web.HTMLVideoElement;
    _applyStyles(video, {
      'width': '400px',
      'max-width': '80vw',
      'height': 'auto',
      'border-radius': '6px',
      'background': '#000',
    });
    video.autoplay = true;
    video.muted = true;
    video.srcObject = stream;

    final btnRow = web.document.createElement('div') as web.HTMLDivElement;
    _applyStyles(btnRow, {'display': 'flex', 'gap': '12px'});

    final captureBtn =
        web.document.createElement('button') as web.HTMLButtonElement;
    captureBtn.textContent = '📷  Capture';
    _applyStyles(captureBtn, {
      'padding': '10px 24px',
      'background': '#007bff',
      'color': '#fff',
      'border': 'none',
      'border-radius': '6px',
      'font-size': '16px',
      'cursor': 'pointer',
    });

    final cancelBtn =
        web.document.createElement('button') as web.HTMLButtonElement;
    cancelBtn.textContent = 'Cancel';
    _applyStyles(cancelBtn, {
      'padding': '10px 24px',
      'background': '#6c757d',
      'color': '#fff',
      'border': 'none',
      'border-radius': '6px',
      'font-size': '16px',
      'cursor': 'pointer',
    });

    btnRow.append(captureBtn);
    btnRow.append(cancelBtn);
    dialog.append(video);
    dialog.append(btnRow);
    overlay.append(dialog);
    web.document.body!.append(overlay);

    // ── Capture ──
    captureBtn.addEventListener(
      'click',
      (web.Event _) {
        try {
          final canvas =
              web.document.createElement('canvas') as web.HTMLCanvasElement;
          canvas.width = video.videoWidth;
          canvas.height = video.videoHeight;
          final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
          ctx.drawImage(video, 0, 0);

          final dataUrl = canvas.toDataURL('image/jpeg', (0.92).toJS);
          final base64 = dataUrl.split(',').last;
          final bytes = _base64ToBytes(base64);
          overlay.remove();
          if (!completer.isCompleted) completer.complete(bytes);
        } catch (_) {
          overlay.remove();
          if (!completer.isCompleted) completer.complete(null);
        }
      }.toJS,
    );

    // ── Cancel ──
    cancelBtn.addEventListener(
      'click',
      (web.Event _) {
        overlay.remove();
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
    );

    return completer.future;
  }

  /// Compress JPEG bytes using a canvas element.
  Future<Uint8List> _compressJpeg(Uint8List bytes, int quality) async {
    try {
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'image/jpeg'),
      );
      final url = web.URL.createObjectURL(blob);

      final img = web.document.createElement('img') as web.HTMLImageElement;
      final loadCompleter = Completer<Uint8List>();

      img.addEventListener(
        'load',
        (web.Event _) {
          try {
            final canvas =
                web.document.createElement('canvas') as web.HTMLCanvasElement;
            canvas.width = img.naturalWidth;
            canvas.height = img.naturalHeight;
            final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
            ctx.drawImage(img, 0, 0);
            final dataUrl = canvas.toDataURL(
              'image/jpeg',
              (quality / 100.0).toJS,
            );
            final base64 = dataUrl.split(',').last;
            web.URL.revokeObjectURL(url);
            loadCompleter.complete(_base64ToBytes(base64));
          } catch (_) {
            web.URL.revokeObjectURL(url);
            loadCompleter.complete(bytes);
          }
        }.toJS,
      );

      img.addEventListener(
        'error',
        (web.Event _) {
          web.URL.revokeObjectURL(url);
          loadCompleter.complete(bytes);
        }.toJS,
      );

      img.src = url;
      return loadCompleter.future;
    } catch (_) {
      return bytes;
    }
  }

  /// Convert a base64 string to [Uint8List] without dart:convert dependency on WASM.
  Uint8List _base64ToBytes(String base64) {
    // Use browser's atob for WASM-safe decoding
    final binary = web.window.atob(base64);
    final bytes = Uint8List(binary.length);
    for (var i = 0; i < binary.length; i++) {
      bytes[i] = binary.codeUnitAt(i);
    }
    return bytes;
  }

  void _applyStyles(web.HTMLElement el, Map<String, String> styles) {
    for (final entry in styles.entries) {
      el.style.setProperty(entry.key, entry.value);
    }
  }
}
