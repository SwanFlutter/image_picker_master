// lib/image_picker_master_web.dart
// ignore_for_file: unreachable_switch_default, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/file_type.dart';
import 'src/tools/picked_file.dart';

/// A web implementation of [ImagePickerMasterPlatform] that uses HTML file input elements.
///
/// This implementation provides file picking functionality for web platforms
/// using the browser's native file selection dialog.
class ImagePickerMasterWeb extends ImagePickerMasterPlatform {
  /// Creates a new instance of [ImagePickerMasterWeb].
  ImagePickerMasterWeb();

  /// Registers this class as the default instance of [ImagePickerMasterPlatform].
  static void registerWith(Registrar registrar) {
    ImagePickerMasterPlatform.instance = ImagePickerMasterWeb();
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = web.window.navigator.userAgent;
    return version;
  }

  @override
  Future<List<PickedFile>?> pickFiles(FilePickerOptions options) async {
    final completer = Completer<List<PickedFile>?>();

    try {
      final input = html.FileUploadInputElement();
      input.style.display = 'none';

      // Set accept attribute based on file type
      input.accept = _getAcceptString(options.type, options.allowedExtensions);

      // Set multiple selection
      input.multiple = options.allowMultiple;

      // Add to DOM
      html.document.body?.append(input);

      // Set up event listeners
      input.onChange.listen((event) async {
        final files = input.files;
        if (files != null && files.isNotEmpty) {
          final pickedFiles = <PickedFile>[];

          for (final file in files) {
            try {
              final pickedFile = await _processWebFile(file, options);
              if (pickedFile != null) {
                pickedFiles.add(pickedFile);
              }
            } catch (e) {
              debugPrint('Error processing file ${file.name}: $e');
            }
          }

          // Remove input from DOM
          input.remove();
          completer.complete(pickedFiles.isEmpty ? null : pickedFiles);
        } else {
          input.remove();
          completer.complete(null);
        }
      });

      input.onError.listen((event) {
        input.remove();
        completer.complete(null);
      });

      // Handle cancel (when user closes dialog without selecting)
      final cancelTimer = Timer(const Duration(minutes: 5), () {
        if (!completer.isCompleted) {
          input.remove();
          completer.complete(null);
        }
      });

      // Detect window focus to handle cancel
      html.window.onFocus.listen((event) {
        Timer(const Duration(milliseconds: 500), () {
          if (!completer.isCompleted && (input.files?.isEmpty ?? true)) {
            cancelTimer.cancel();
            input.remove();
            completer.complete(null);
          }
        });
      });

      // Trigger file picker
      input.click();
    } catch (e) {
      completer.complete(null);
    }

    return completer.future;
  }

  @override
  Future<void> clearTemporaryFiles() async {
    // Web doesn't need temporary file cleanup as files are handled in memory
    return;
  }

  @override
  Future<PickedFile?> capturePhoto({
    required bool allowCompression,
    required int compressionQuality,
    required bool withData,
  }) async {
    try {
      // Check if getUserMedia is supported
      if (!_isGetUserMediaSupported()) {
        throw PlatformException(
          code: 'CAMERA_NOT_SUPPORTED',
          message: 'Camera access is not supported in this browser.',
        );
      }

      // Request camera access
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': true,
      });

      if (stream == null) {
        throw PlatformException(
          code: 'CAMERA_ACCESS_DENIED',
          message: 'Camera access was denied.',
        );
      }

      // Create video element to display camera feed
      final video = html.VideoElement()
        ..srcObject = stream
        ..autoplay = true
        ..muted = true
        ..style.width = '100%'
        ..style.height = '100%';

      // Create canvas for capturing
      final canvas = html.CanvasElement();
      final context = canvas.context2D;

      // Create capture UI
      final result = await _showCameraDialog(video, canvas, context, stream);

      if (result != null) {
        // Process the captured image
        Uint8List imageBytes = result;

        if (allowCompression) {
          imageBytes = await _compressImage(imageBytes, compressionQuality);
        }

        // Generate a filename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'captured_photo_$timestamp.jpg';

        // Create object URL for the captured image
        final blob = html.Blob([imageBytes], 'image/jpeg');
        final objectUrl = html.Url.createObjectUrlFromBlob(blob);

        return PickedFile(
          path: objectUrl,
          name: filename,
          size: imageBytes.length,
          mimeType: 'image/jpeg',
          bytes: withData ? imageBytes : null,
        );
      }

      return null;
    } catch (e) {
      if (e is PlatformException) {
        rethrow;
      }
      throw PlatformException(
        code: 'CAMERA_ERROR',
        message: 'Failed to capture photo: $e',
      );
    }
  }

  String _getAcceptString(FileType type, List<String>? allowedExtensions) {
    switch (type) {
      case FileType.image:
        return 'image/*';
      case FileType.video:
        return 'video/*';
      case FileType.audio:
        return 'audio/*';
      case FileType.document:
        return '.pdf,.doc,.docx,.xls,.xlsx,.ppt,.pptx,.txt,.rtf';
      case FileType.custom:
        if (allowedExtensions != null && allowedExtensions.isNotEmpty) {
          return allowedExtensions.map((ext) => '.$ext').join(',');
        }
        return '*/*';
      case FileType.all:
      default:
        return '*/*';
    }
  }

  Future<PickedFile?> _processWebFile(
    html.File file,
    FilePickerOptions options,
  ) async {
    try {
      final reader = html.FileReader();
      final completer = Completer<Uint8List?>();

      reader.onLoad.listen((event) {
        final result = reader.result;
        if (result is Uint8List) {
          completer.complete(result);
        } else if (result is String) {
          // Handle base64 data URL
          final dataUrl = result;
          if (dataUrl.contains(',')) {
            final base64 = dataUrl.split(',')[1];
            completer.complete(base64Decode(base64));
          } else {
            completer.complete(null);
          }
        } else {
          completer.complete(null);
        }
      });

      reader.onError.listen((event) {
        completer.complete(null);
      });

      // Read file as array buffer for binary data
      reader.readAsArrayBuffer(file);

      Uint8List? fileBytes = await completer.future;

      if (fileBytes == null) {
        return null;
      }

      // Apply compression for images if requested
      if (options.allowCompression && _isImageFile(file.type)) {
        fileBytes = await _compressImage(
          fileBytes,
          options.compressionQuality ?? 80,
        );
      }

      // Create object URL for file path (web-specific)
      final objectUrl = html.Url.createObjectUrlFromBlob(file);

      return PickedFile(
        path: objectUrl,
        name: file.name,
        size: file.size,
        mimeType: file.type,
        bytes: options.withData ? fileBytes : null,
      );
    } catch (e) {
      debugPrint('Error processing file: $e');
      return null;
    }
  }

  bool _isImageFile(String mimeType) {
    return mimeType.startsWith('image/');
  }

  bool _isGetUserMediaSupported() {
    return html.window.navigator.mediaDevices != null;
  }

  Future<Uint8List?> _showCameraDialog(
    html.VideoElement video,
    html.CanvasElement canvas,
    html.CanvasRenderingContext2D context,
    html.MediaStream stream,
  ) async {
    final completer = Completer<Uint8List?>();

    // Create modal dialog
    final overlay = html.DivElement()
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.8)'
      ..style.zIndex = '9999'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center';

    final dialog = html.DivElement()
      ..style.backgroundColor = 'white'
      ..style.borderRadius = '8px'
      ..style.padding = '20px'
      ..style.maxWidth = '90%'
      ..style.maxHeight = '90%'
      ..style.display = 'flex'
      ..style.flexDirection = 'column'
      ..style.alignItems = 'center';

    final videoContainer = html.DivElement()
      ..style.width = '400px'
      ..style.height = '300px'
      ..style.marginBottom = '20px'
      ..style.border = '2px solid #ccc'
      ..style.borderRadius = '4px'
      ..style.overflow = 'hidden';

    final buttonContainer = html.DivElement()
      ..style.display = 'flex'
      ..style.gap = '10px';

    final captureButton = html.ButtonElement()
      ..text = 'Capture Photo'
      ..style.padding = '10px 20px'
      ..style.backgroundColor = '#007bff'
      ..style.color = 'white'
      ..style.border = 'none'
      ..style.borderRadius = '4px'
      ..style.cursor = 'pointer';

    final cancelButton = html.ButtonElement()
      ..text = 'Cancel'
      ..style.padding = '10px 20px'
      ..style.backgroundColor = '#6c757d'
      ..style.color = 'white'
      ..style.border = 'none'
      ..style.borderRadius = '4px'
      ..style.cursor = 'pointer';

    // Add elements to DOM
    videoContainer.append(video);
    buttonContainer.append(captureButton);
    buttonContainer.append(cancelButton);
    dialog.append(videoContainer);
    dialog.append(buttonContainer);
    overlay.append(dialog);
    html.document.body?.append(overlay);

    // Set up event listeners
    captureButton.onClick.listen((event) {
      try {
        // Set canvas size to video size
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;

        // Draw current video frame to canvas
        context.drawImage(video, 0, 0);

        // Convert canvas to data URL
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.8);

        if (dataUrl.contains(',')) {
          final base64 = dataUrl.split(',')[1];
          final imageBytes = base64Decode(base64);

          // Stop camera stream
          stream.getTracks().forEach((track) => track.stop());

          // Remove dialog
          overlay.remove();

          completer.complete(imageBytes);
        } else {
          completer.complete(null);
        }
      } catch (e) {
        completer.complete(null);
      }
    });

    cancelButton.onClick.listen((event) {
      // Stop camera stream
      stream.getTracks().forEach((track) => track.stop());

      // Remove dialog
      overlay.remove();

      completer.complete(null);
    });

    return completer.future;
  }

  Future<Uint8List> _compressImage(Uint8List imageBytes, int quality) async {
    try {
      // Create a canvas element for image manipulation
      final canvas = html.CanvasElement();
      final context = canvas.context2D;

      // Create an image element
      final img = html.ImageElement();
      final completer = Completer<Uint8List>();

      img.onLoad.listen((event) {
        try {
          // Set canvas size to image size
          canvas.width = img.naturalWidth;
          canvas.height = img.naturalHeight;

          // Draw image on canvas
          context.drawImage(img, 0, 0);

          // Convert to data URL with compression
          final dataUrl = canvas.toDataUrl('image/jpeg', quality / 100.0);

          if (dataUrl.contains(',')) {
            final base64 = dataUrl.split(',')[1];
            final compressedBytes = base64Decode(base64);
            completer.complete(compressedBytes);
          } else {
            completer.complete(imageBytes);
          }
        } catch (e) {
          completer.complete(imageBytes);
        }
      });

      img.onError.listen((event) {
        completer.complete(imageBytes);
      });

      // Create object URL from bytes
      final blob = html.Blob([imageBytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      img.src = url;

      final result = await completer.future;

      // Clean up the object URL
      html.Url.revokeObjectUrl(url);

      return result;
    } catch (e) {
      return imageBytes;
    }
  }
}
