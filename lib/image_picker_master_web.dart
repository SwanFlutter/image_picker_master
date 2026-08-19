// lib/image_picker_master_web.dart

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
/// Uses package:web (WASM-compatible) — dart:html is not used.
class ImagePickerMasterWeb extends ImagePickerMasterPlatform {
  ImagePickerMasterWeb();

  static void registerWith(Registrar registrar) {
    ImagePickerMasterPlatform.instance = ImagePickerMasterWeb();
  }

  // ─── getPlatformVersion ──────────────────────────────────────────────────

  @override
  Future<String?> getPlatformVersion() async {
    return web.window.navigator.userAgent;
  }

  // ─── pickFiles ───────────────────────────────────────────────────────────

  @override
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) async {
    final completer = Completer<List<PickedFile>?>();

    final input = web.document.createElement('input') as web.HTMLInputElement;
    input.type = 'file';
    input.style.display = 'none';
    input.accept = _acceptString(options.type, options.allowedExtensions);
    input.multiple = options.allowMultiple;
    web.document.body!.append(input);

    // onChange — user confirmed a selection.
    // The handler must be synchronous (void, not Future) for dart:js_interop.
    // We schedule the async work via unawaited to keep the signature valid.
    input.addEventListener(
      'change',
      (web.Event _) {
        _handleFileInputChange(input, options, completer);
      }.toJS,
    );

    // Window focus after dialog close → cancel if nothing was selected
    // Use addEventListener directly because web.Window has no onFocus stream.
    web.window.addEventListener(
      'focus',
      (web.Event _) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!completer.isCompleted) {
            final fl = input.files;
            if (fl == null || fl.length == 0) {
              input.remove();
              completer.complete(null);
            }
          }
        });
      }.toJS,
    );

    // Safety timeout
    Future.delayed(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        input.remove();
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
    // mediaDevices is non-nullable in package:web but may be unavailable
    web.MediaStream stream;
    try {
      final constraints = web.MediaStreamConstraints(video: true.toJS);
      stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
    } catch (_) {
      throw PlatformException(
        code: 'CAMERA_ACCESS_DENIED',
        message: 'Camera permission was denied or camera is unavailable.',
      );
    }

    final imageBytes = await _showCameraDialog(stream);

    // Stop all camera tracks
    final tracks = stream.getTracks();
    for (var i = 0; i < tracks.length; i++) {
      final track = tracks[i] as web.MediaStreamTrack?;
      track?.stop();
    }

    if (imageBytes == null) return null;

    Uint8List finalBytes = imageBytes;
    if (allowCompression) {
      finalBytes = await _compressJpeg(imageBytes, compressionQuality);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'captured_photo_$timestamp.jpg';

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
    // Web uses in-memory object URLs — nothing to clean up.
  }

  // ─── resizeImageForCropper ──────────────────────────────────────────────── We load it into an <img>,
  // draw it onto a <canvas> at the target size, and export as JPEG.
  // The Canvas 2D API downscale runs in the browser's native C++ compositor,
  // so it is far faster than pure-Dart pixel manipulation.

  @override
  Future<String?> resizeImageForCropper({
    required String path,
    int maxSize = 1024,
  }) async {
    try {
      // ── Step 1: load the image from the object URL ─────────────────────
      final img = web.document.createElement('img') as web.HTMLImageElement;
      final loadCompleter = Completer<bool>();

      img.addEventListener(
        'load',
        (web.Event _) {
          loadCompleter.complete(true);
        }.toJS,
      );
      img.addEventListener(
        'error',
        (web.Event _) {
          loadCompleter.complete(false);
        }.toJS,
      );
      img.src = path;
      final loaded = await loadCompleter.future;
      if (!loaded) return path;

      final origW = img.naturalWidth;
      final origH = img.naturalHeight;

      // Already fits — return original path
      if (origW <= maxSize && origH <= maxSize) return path;

      // ── Step 2: compute target dimensions (preserve aspect ratio) ──────
      final larger = origW > origH ? origW : origH;
      final scale = maxSize / larger;
      final newW = (origW * scale).round();
      final newH = (origH * scale).round();

      // ── Step 3: draw at target size on a canvas (native browser path) ──
      final canvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      canvas.width = newW;
      canvas.height = newH;
      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      // drawImage with sx/sy/sw/sh/dx/dy/dw/dh triggers the browser's native
      // bilinear/bicubic downscale — no JS pixel loop required.
      ctx.drawImage(
        img,
        0,
        0,
        origW.toDouble(),
        origH.toDouble(),
        0,
        0,
        newW.toDouble(),
        newH.toDouble(),
      );

      // ── Step 4: export as JPEG object URL ──────────────────────────────
      final dataUrl = canvas.toDataURL('image/jpeg', (0.85).toJS);
      final base64 = dataUrl.split(',').last;
      final bytes = _base64ToBytes(base64);
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'image/jpeg'),
      );
      return web.URL.createObjectURL(blob);
    } catch (_) {
      return path;
    }
  }

  // ─── cropImageNative ─────────────────────────────────────────────────────
  // On web, performs crop+encode fully in the browser compositor via Canvas 2D.
  // format: "jpeg" | "png" | "webp_lossy" | "webp_lossless"
  // Browser WebP support is near-universal (Chrome/Edge/Firefox/Safari 14+).

  @override
  Future<String?> cropImageNative({
    required String path,
    required double cropX,
    required double cropY,
    required double cropW,
    required double cropH,
    required double containerW,
    required double containerH,
    int rotation = 0,
    int quality = 85,
    String format = 'jpeg',
    int maxSize = 1200,
  }) async {
    try {
      // ── Step 1: load the source blob URL ─────────────────────────────
      final img = web.document.createElement('img') as web.HTMLImageElement;
      final loadCompleter = Completer<bool>();
      img.addEventListener(
        'load',
        (web.Event _) {
          loadCompleter.complete(true);
        }.toJS,
      );
      img.addEventListener(
        'error',
        (web.Event _) {
          loadCompleter.complete(false);
        }.toJS,
      );
      img.src = path;
      if (!await loadCompleter.future) return null;

      final origW = img.naturalWidth;
      final origH = img.naturalHeight;

      // ── Step 2: apply rotation to a temp canvas ───────────────────────
      final rotRad = rotation * 3.141592653589793 / 180.0;
      final bool swapped = rotation == 90 || rotation == 270;
      final rotW = swapped ? origH : origW;
      final rotH = swapped ? origW : origH;

      final rotCanvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      rotCanvas.width = rotW;
      rotCanvas.height = rotH;
      final rotCtx = rotCanvas.getContext('2d') as web.CanvasRenderingContext2D;
      rotCtx.translate((rotW / 2).toDouble(), (rotH / 2).toDouble());
      rotCtx.rotate(rotRad);
      rotCtx.drawImage(img, (-origW / 2).toDouble(), (-origH / 2).toDouble());

      final imgW = rotW.toDouble();
      final imgH = rotH.toDouble();

      // ── Step 3: map crop rect from container coords → image coords ────
      final imgAspect = imgW / imgH;
      final contAspect = containerW / containerH;
      final double displayedW, displayedH, offsetX, offsetY;
      if (imgAspect > contAspect) {
        displayedW = containerW;
        displayedH = containerW / imgAspect;
        offsetX = 0;
        offsetY = (containerH - displayedH) / 2;
      } else {
        displayedH = containerH;
        displayedW = containerH * imgAspect;
        offsetX = (containerW - displayedW) / 2;
        offsetY = 0;
      }
      final scaleX = imgW / displayedW;
      final scaleY = imgH / displayedH;
      final px = ((cropX - offsetX) * scaleX).clamp(0, imgW - 1);
      final py = ((cropY - offsetY) * scaleY).clamp(0, imgH - 1);
      final pw = (cropW * scaleX).clamp(1, imgW - px);
      final ph = (cropH * scaleY).clamp(1, imgH - py);

      // ── Step 4: draw cropped region onto output canvas ────────────────
      final outCanvas =
          web.document.createElement('canvas') as web.HTMLCanvasElement;
      outCanvas.width = pw.round();
      outCanvas.height = ph.round();
      final outCtx = outCanvas.getContext('2d') as web.CanvasRenderingContext2D;
      outCtx.drawImage(rotCanvas, px, py, pw, ph, 0, 0, pw, ph);

      // ── Step 5: encode to chosen format ──────────────────────────────
      final String mimeType;
      switch (format) {
        case 'png':
          mimeType = 'image/png';
          break;
        case 'webp_lossy':
        case 'webp_lossless':
          mimeType = 'image/webp';
          break;
        default:
          mimeType = 'image/jpeg';
      }
      final q = quality / 100.0;
      final dataUrl = outCanvas.toDataURL(mimeType, q.toJS);
      final base64 = dataUrl.split(',').last;
      final bytes = _base64ToBytes(base64);
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: mimeType),
      );
      return web.URL.createObjectURL(blob);
    } catch (_) {
      return null;
    }
  }

  // ─── _handleFileInputChange ──────────────────────────────────────────────
  // Async logic extracted from the onChange JS listener (which must be void).

  void _handleFileInputChange(
    web.HTMLInputElement input,
    FilePickerOptions options,
    Completer<List<PickedFile>?> completer,
  ) {
    Future(() async {
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
    });
  }

  // ─── _acceptString ───────────────────────────────────────────────────────

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

  // ─── _processFile ────────────────────────────────────────────────────────

  Future<PickedFile?> _processFile(
    web.File file,
    FilePickerOptions options,
  ) async {
    try {
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
          final jsBuffer = result as JSArrayBuffer;
          loadCompleter.complete(jsBuffer.toDart.asUint8List());
        }.toJS,
      );

      // error handler — must be JSFunction, not return void
      reader.addEventListener(
        'error',
        (web.Event _) {
          loadCompleter.complete(null);
        }.toJS,
      );

      reader.readAsArrayBuffer(file);
      Uint8List? bytes = await loadCompleter.future;
      if (bytes == null) return null;

      if (options.allowCompression && file.type.startsWith('image/')) {
        bytes = await _compressJpeg(bytes, options.compressionQuality ?? 80);
      }

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

  // ─── _showCameraDialog ───────────────────────────────────────────────────

  Future<Uint8List?> _showCameraDialog(web.MediaStream stream) async {
    final completer = Completer<Uint8List?>();

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

    cancelBtn.addEventListener(
      'click',
      (web.Event _) {
        overlay.remove();
        if (!completer.isCompleted) completer.complete(null);
      }.toJS,
    );

    return completer.future;
  }

  // ─── _compressJpeg ───────────────────────────────────────────────────────

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
      return await loadCompleter.future;
    } catch (_) {
      return bytes;
    }
  }

  // ─── _base64ToBytes ──────────────────────────────────────────────────────

  Uint8List _base64ToBytes(String base64) {
    final binary = web.window.atob(base64);
    final result = Uint8List(binary.length);
    for (var i = 0; i < binary.length; i++) {
      result[i] = binary.codeUnitAt(i);
    }
    return result;
  }

  // ─── _applyStyles ────────────────────────────────────────────────────────

  void _applyStyles(web.HTMLElement el, Map<String, String> styles) {
    for (final entry in styles.entries) {
      el.style.setProperty(entry.key, entry.value);
    }
  }
}
