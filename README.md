[![pub package](https://img.shields.io/pub/v/image_picker_master.svg)](https://pub.dev/packages/image_picker_master)
[![Pub Points](https://img.shields.io/pub/points/image_picker_master)](https://pub.dev/packages/image_picker_master/score)
[![Popularity](https://img.shields.io/pub/popularity/image_picker_master)](https://pub.dev/packages/image_picker_master)
[![Pub Likes](https://img.shields.io/pub/likes/image_picker_master)](https://pub.dev/packages/image_picker_master)
[![GitHub issues](https://img.shields.io/github/issues/SwanFlutter/image_picker_master)](https://github.com/SwanFlutter/image_picker_master/issues)
[![GitHub forks](https://img.shields.io/github/forks/SwanFlutter/image_picker_master)](https://github.com/SwanFlutter/image_picker_master/network/members)
[![GitHub stars](https://img.shields.io/github/stars/SwanFlutter/image_picker_master?style=social)](https://github.com/SwanFlutter/image_picker_master/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter Platform](https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20macos%20%7C%20linux%20%7C%20windows%20%7C%20web-lightgrey)](https://pub.dev/packages/image_picker_master)

# Image Picker Master

A comprehensive Flutter plugin for picking images, videos, audio files, documents, and any file type — with multiple selection, compression, Unicode filename support, and camera capture — across all platforms.

---

## Platform Support

| Platform | Pick Files | Camera Capture | Multiple Select | Compression |
|----------|:----------:|:--------------:|:---------------:|:-----------:|
| Android  | ✅ | ✅ | ✅ | ✅ |
| iOS      | ✅ | ✅ | ✅ | ✅ |
| macOS    | ✅ | ✅ | ✅ | ✅ |
| Windows  | ✅ | ✅ | ✅ | ✅ |
| Linux    | ✅ | ✅ | ✅ | ✅ |
| Web      | ✅ | ✅ | ✅ | ✅ |

---

## Features

- ✅ **Cross-platform** — Android, iOS, macOS, Windows, Linux, Web
- ✅ **All file types** — Images, videos, audio, documents, archives, fonts, code files
- ✅ **Camera capture** — Take photos directly from the camera on all platforms
- ✅ **Multiple selection** — Pick several files at once
- ✅ **Image compression** — Quality control from 0 to 100
- ✅ **File bytes** — Optionally load raw bytes into memory (`withData: true`)
- ✅ **MIME type detection** — Automatic detection for all file types
- ✅ **Unicode filenames** — Full support for Persian/Farsi, Arabic, Chinese, and all Unicode scripts
- ✅ **Temporary file cleanup** — Built-in `clearTemporaryFiles()` to free disk space
- ✅ **Custom extensions** — Filter picker to any file extension you choose
- ✅ **Runtime permissions** — Camera and storage permissions requested automatically (Android/iOS)

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  image_picker_master: ^0.1.2

Then run:

```bash
flutter pub get
```

---

## Setup

### Android

No manual setup required. The plugin automatically requests `CAMERA` and storage permissions at runtime.

The following are declared in the plugin's `AndroidManifest.xml` — you do **not** need to add them to your app:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

### iOS

Add these keys to your `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to capture photos and videos.</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app accesses your photo library to pick images and videos.</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>This app saves captured photos to your photo library.</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app uses the microphone to record video audio.</string>
```

> **Note:** If you use the plugin's podspec `script_phase` (included by default), these keys are injected automatically at build time when missing.

### macOS

Add to your `macos/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to capture photos.</string>

<key>NSMicrophoneUsageDescription</key>
<string>This app uses the microphone.</string>
```

And to your `macos/Runner/DebugProfile.entitlements` and `macos/Runner/Release.entitlements`:

```xml
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

> **Note:** The plugin's podspec `script_phase` injects these automatically when missing.

---

## Quick Start

```dart
import 'package:image_picker_master/image_picker_master.dart';

// Pick a single image
final image = await ImagePickerMaster.instance.pickImage();

// Pick multiple images
final images = await ImagePickerMaster.instance.pickImages();

// Capture a photo
final photo = await ImagePickerMaster.instance.capturePhoto();

// Pick a PDF/Word document
final doc = await ImagePickerMaster.instance.pickDocument();

// Pick any file type
final files = await ImagePickerMaster.instance.pickFiles(
  type: FileType.all,
  allowMultiple: true,
);
```

---

## Usage Guide

### 1. `pickFiles()` — Pick any file type

```dart
// Pick all file types
final files = await ImagePickerMaster.instance.pickFiles(
  type: FileType.all,
  allowMultiple: true,
);

// Pick images with compression
final images = await ImagePickerMaster.instance.pickFiles(
  type: FileType.image,
  allowMultiple: true,
  allowCompression: true,
  compressionQuality: 75,
  withData: true,
);

// Pick only specific extensions
final custom = await ImagePickerMaster.instance.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['pdf', 'docx', 'xlsx'],
  allowMultiple: true,
);

if (files != null) {
  for (final file in files) {
    print('${file.name} — ${file.size} bytes — ${file.mimeType}');
  }
}
```

### 2. `pickImage()` / `pickImages()` — Images

```dart
// Single image
final image = await ImagePickerMaster.instance.pickImage(
  allowCompression: true,
  compressionQuality: 80,
  withData: true,
);

if (image != null) {
  print('Path: ${image.path}');
  print('Size: ${(image.size / 1024).toStringAsFixed(1)} KB');
  if (image.bytes != null) {
    // Use raw bytes directly — e.g. Image.memory(image.bytes!)
  }
}

// Multiple images
final images = await ImagePickerMaster.instance.pickImages(
  allowMultiple: true,
  allowCompression: true,
  compressionQuality: 85,
);
```

### 3. `pickVideo()` / `pickVideos()` — Videos

```dart
final video = await ImagePickerMaster.instance.pickVideo();
if (video != null) {
  print('${video.name} — ${(video.size / 1024 / 1024).toStringAsFixed(2)} MB');
}

final videos = await ImagePickerMaster.instance.pickVideos(allowMultiple: true);
```

### 4. `pickAudio()` / `pickAudios()` — Audio

```dart
final audio = await ImagePickerMaster.instance.pickAudio(withData: true);
if (audio != null && audio.bytes != null) {
  print('Audio bytes loaded: ${audio.bytes!.length}');
}

final audios = await ImagePickerMaster.instance.pickAudios();
```

### 5. `pickDocument()` / `pickDocuments()` — Documents

```dart
// Single document
final doc = await ImagePickerMaster.instance.pickDocument(
  allowedExtensions: ['pdf', 'docx', 'txt'],
  withData: true,
);

// Multiple documents
final docs = await ImagePickerMaster.instance.pickDocuments(
  allowMultiple: true,
);

if (docs != null) {
  for (final doc in docs) {
    final ext = doc.name.split('.').last.toLowerCase();
    print('[$ext] ${doc.name} — ${(doc.size / 1024).toStringAsFixed(1)} KB');
  }
}
```

### 6. `capturePhoto()` — Camera

```dart
// Basic capture
final photo = await ImagePickerMaster.instance.capturePhoto();

// Compressed capture ready for upload
final photo = await ImagePickerMaster.instance.capturePhoto(
  allowCompression: true,
  compressionQuality: 70,
  withData: true,
);

if (photo != null) {
  print('Captured: ${photo.name}');
  print('Size: ${(photo.size / 1024).toStringAsFixed(1)} KB');
  // photo.bytes contains raw JPEG data when withData: true
}
```

### 7. `clearTemporaryFiles()` — Cleanup

Call this to free disk space used by the plugin's temp copies:

```dart
// In State.dispose()
@override
void dispose() {
  ImagePickerMaster.instance.clearTemporaryFiles();
  super.dispose();
}

// Or on app lifecycle changes
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.paused) {
    ImagePickerMaster.instance.clearTemporaryFiles();
  }
}
```

### 8. `resizeImageForCropper()` — Fast native preview

Resize a picked image for use as a cropper preview. Uses platform-native decoders
(`BitmapFactory.inSampleSize` on Android, `CGImageSourceCreateThumbnailAtIndex` on
iOS/macOS, GDI+ on Windows, gdk-pixbuf on Linux, Canvas 2D on Web) — ~50–150 ms
vs ~10 s for pure-Dart decode on a 2 MB JPEG.

```dart
final previewPath = await ImagePickerMaster.instance.resizeImageForCropper(
  path: pickedFile.path,
  maxSize: 1024,   // max edge length in pixels (default 1024)
);
// previewPath is never null — falls back to original path on error
```

### 9. `cropImageNative()` — Native crop + encode (~115 ms)

Performs the full decode → rotate → crop → encode pipeline natively on a background
thread. Replaces a Dart `compute()` isolate that typically takes ~3,700 ms.

```dart
final croppedPath = await ImagePickerMaster.instance.cropImageNative(
  path: pickedFile.path,          // source image path / blob URL
  cropX: cropRect.left,           // crop rect in container coordinates
  cropY: cropRect.top,
  cropW: cropRect.width,
  cropH: cropRect.height,
  containerW: containerSize.width,   // Flutter widget size that displayed the image
  containerH: containerSize.height,
  rotation: 90,                   // clockwise degrees (0, 90, 180, 270)
  quality: 85,                    // 0-100, ignored for PNG
  format: 'webp_lossy',           // "jpeg" | "png" | "webp_lossy" | "webp_lossless"
  maxSize: 1200,                  // max decode edge before crop (default 1200)
);

if (croppedPath != null) {
  // Use File(croppedPath) on mobile/desktop or load as blob URL on web
}
```

**Output format support by platform:**

| Format | Android | iOS | macOS | Windows | Linux | Web |
|--------|:-------:|:---:|:-----:|:-------:|:-----:|:---:|
| `jpeg` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `png` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| `webp_lossy` | ✅ (API 30+ native, older→WEBP) | JPEG fallback | JPEG fallback | JPEG fallback | JPEG fallback | ✅ |
| `webp_lossless` | ✅ (API 30+ native, older→WEBP) | JPEG fallback | JPEG fallback | JPEG fallback | JPEG fallback | ✅ |

---

## PickedFile Object

Every pick operation returns `PickedFile` (or `List<PickedFile>`):

```dart
class PickedFile {
  final String     path;      // Absolute path to the temp copy
  final String     name;      // Filename including extension (Unicode safe)
  final int        size;      // File size in bytes
  final String?    mimeType;  // e.g. "image/jpeg", "application/pdf"
  final Uint8List? bytes;     // Raw bytes — only when withData: true
}
```

### Common patterns with PickedFile

```dart
// Show image from bytes
if (file.bytes != null) {
  Image.memory(file.bytes!)
}

// Show image from path (mobile/desktop)
Image.file(File(file.path))

// Format size
String formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}

// Get extension
final ext = file.name.split('.').last.toLowerCase();

// Categorize files
bool isImage = file.mimeType?.startsWith('image/') ?? false;
bool isVideo = file.mimeType?.startsWith('video/') ?? false;
bool isAudio = file.mimeType?.startsWith('audio/') ?? false;
```

---

## API Reference

### Methods

| Method | Returns | Description |
|--------|---------|-------------|
| `getPlatformVersion()` | `Future<String?>` | Platform OS version string |
| `pickFiles({...})` | `Future<List<PickedFile>?>` | Pick one or more files of any type |
| `pickImage({...})` | `Future<PickedFile?>` | Pick a single image |
| `pickImages({...})` | `Future<List<PickedFile>?>` | Pick multiple images |
| `pickVideo({...})` | `Future<PickedFile?>` | Pick a single video |
| `pickVideos({...})` | `Future<List<PickedFile>?>` | Pick multiple videos |
| `pickAudio({...})` | `Future<PickedFile?>` | Pick a single audio file |
| `pickAudios({...})` | `Future<List<PickedFile>?>` | Pick multiple audio files |
| `pickDocument({...})` | `Future<PickedFile?>` | Pick a single document |
| `pickDocuments({...})` | `Future<List<PickedFile>?>` | Pick multiple documents |
| `capturePhoto({...})` | `Future<PickedFile?>` | Capture photo from camera |
| `clearTemporaryFiles()` | `Future<void>` | Delete all plugin temp files |
| `resizeImageForCropper({required path, maxSize})` | `Future<String?>` | Native resize for cropper preview (~50–150 ms vs ~10 s in Dart) |
| `cropImageNative({required path, cropX, cropY, cropW, cropH, containerW, containerH, ...})` | `Future<String?>` | Full native crop+encode (~115 ms vs ~3,700 ms Dart isolate) |

### `pickFiles` Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | `FileType` | `FileType.all` | File category filter |
| `allowMultiple` | `bool` | `false` | Allow selecting multiple files |
| `allowedExtensions` | `List<String>?` | `null` | Required when `type` is `FileType.custom` |
| `withData` | `bool` | `false` | Load file bytes into memory |
| `allowCompression` | `bool` | `false` | Compress images before returning |
| `compressionQuality` | `int?` | `80` | JPEG quality 0–100 (100 = lossless) |

### `FileType` Enum

```dart
enum FileType {
  all,       // No filter — all files visible
  image,     // JPEG, PNG, GIF, BMP, WebP, HEIC, AVIF, SVG, ICO, TIFF
  video,     // MP4, MOV, AVI, MKV, WMV, FLV, WebM, 3GP, M4V
  audio,     // MP3, WAV, M4A, FLAC, OGG, AAC, WMA, AIFF
  document,  // PDF, Word, Excel, PowerPoint, TXT, ODT, EPUB, HTML, ZIP, and more
  custom,    // Filtered by allowedExtensions list
}
```

### `cropImageNative` Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `path` | `String` | required | Absolute path or blob URL of the source image |
| `cropX` | `double` | required | Left edge of the crop rect in container coordinates |
| `cropY` | `double` | required | Top edge of the crop rect in container coordinates |
| `cropW` | `double` | required | Width of the crop rect in container coordinates |
| `cropH` | `double` | required | Height of the crop rect in container coordinates |
| `containerW` | `double` | required | Width of the Flutter widget that displayed the image |
| `containerH` | `double` | required | Height of the Flutter widget that displayed the image |
| `rotation` | `int` | `0` | Clockwise rotation in degrees: 0, 90, 180, or 270 |
| `quality` | `int` | `85` | Encode quality 0–100 (ignored for PNG) |
| `format` | `String` | `"jpeg"` | Output format: `"jpeg"` \| `"png"` \| `"webp_lossy"` \| `"webp_lossless"` |
| `maxSize` | `int` | `1200` | Max edge length when decoding source image (prevents OOM on huge files) |

---

## Supported Formats

<details>
<summary><b>Images</b> (click to expand)</summary>

JPEG, PNG, GIF, BMP, TIFF, WebP, HEIC, HEIF, AVIF, SVG, ICO

</details>

<details>
<summary><b>Videos</b> (click to expand)</summary>

MP4, AVI, MOV, MKV, WMV, FLV, WebM, 3GP, M4V

</details>

<details>
<summary><b>Audio</b> (click to expand)</summary>

MP3, WAV, M4A, FLAC, OGG, AAC, WMA, AIFF

</details>

<details>
<summary><b>Documents</b> (click to expand)</summary>

PDF, DOC/DOCX, XLS/XLSX, PPT/PPTX, TXT, RTF, Markdown, ODT/ODS/ODP, Pages/Numbers/Keynote, EPUB, HTML, CSS, JS, JSON, XML, CSV, YAML, ZIP, RAR, 7Z, TAR, GZ, TTF, OTF, WOFF

</details>

---

## Unicode Support

Full support for non-Latin filenames:

```dart
// These all work correctly
// Persian:  فاکتور.pdf    تصویر.jpg
// Arabic:   ملف.docx      صورة.png
// Chinese:  文档.txt      图片.jpeg
// Japanese: 写真.heic
// Korean:   파일.mp4
```

---

## Example App

See the [`example/`](example/) directory for a complete working demo of all features.

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full version history.

---

## Contributing

Pull requests and issues are welcome at [github.com/SwanFlutter/image_picker_master](https://github.com/SwanFlutter/image_picker_master).

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Contact

For questions or feedback: [swan.dev1993@gmail.com](mailto:swan.dev1993@gmail.com)
