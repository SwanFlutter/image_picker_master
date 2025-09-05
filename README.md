
# Image Picker Master
A comprehensive Flutter plugin for selecting files from device storage with full Unicode support, including Persian/Farsi filenames.

---

## Features
- ✅ **Cross-platform support**: Windows, Android, iOS, macOS, Linux, Web
- ✅ **Multiple file types**: Images, videos, audio, documents, and custom files
- ✅ **Unicode support**: Full support for Persian/Farsi and other Unicode filenames
- ✅ **Flexible selection**: Single or multiple file selection
- ✅ **File compression**: Optional image compression with quality control
- ✅ **MIME type detection**: Automatic file type detection
- ✅ **Memory optimization**: Efficient file handling without unnecessary copies

---

## Supported File Types

### Images
- JPEG (.jpg, .jpeg) – Standard photo format
- PNG (.png) – Transparent background images
- GIF (.gif) – Animated images
- BMP (.bmp) – Bitmap images
- TIFF (.tiff) – Professional format
- WebP (.webp) – Modern web format
- HEIC/HEIF – Apple’s new format
- AVIF (.avif) – Next-gen format
- SVG (.svg) – Vector images
- ICO (.ico) – Icons

### Videos
- MP4 (.mp4) – Standard format
- AVI (.avi) – Classic format
- MOV (.mov) – QuickTime format
- MKV (.mkv) – Multimedia container
- WMV (.wmv) – Windows Media format
- FLV (.flv) – Flash Video format
- WebM (.webm) – Web format
- 3GP (.3gp) – Mobile format
- M4V (.m4v) – iTunes format

### Audio
- MP3 (.mp3) – Popular music format
- WAV (.wav) – Lossless format
- M4A (.m4a) – Apple AAC format
- FLAC (.flac) – Lossless format
- OGG (.ogg) – Open-source format
- AAC (.aac) – Advanced format
- WMA (.wma) – Windows Media format
- AIFF (.aiff) – Audio Interchange format

### Documents
- PDF (.pdf) – Portable documents
- Word (.doc, .docx) – Microsoft Word documents
- Excel (.xls, .xlsx) – Microsoft Excel spreadsheets
- PowerPoint (.ppt, .pptx) – Microsoft PowerPoint presentations
- Text (.txt) – Plain text
- RTF (.rtf) – Formatted text
- Markdown (.md, .markdown) – Markup text
- OpenDocument (.odt, .ods, .odp) – Open formats
- iWork (Pages, Numbers, Keynote) – Apple formats
- EPUB (.epub) – E-books
- HTML (.html, .htm) – Web pages
- CSS (.css) – Stylesheets
- JavaScript (.js) – JavaScript code
- JSON (.json) – Structured data
- XML (.xml) – Markup data
- CSV (.csv) – Tabular data
- Archive files (.zip, .rar, .7z, .tar, .gz)

---

## Installation
Add this line to your `pubspec.yaml` file:

```yaml
dependencies:
  image_picker_master: ^0.0.4
```

Then run:

```bash
flutter pub get
```

---

## Usage Guide

### Import the Package
```dart
import 'package:image_picker_master/image_picker_master.dart';
```

---

### Example Usage for Each Method

#### 1. `getPlatformVersion()` Method
```dart
// Example 1: Get platform version
void checkPlatformVersion() async {
  try {
    final version = await ImagePickerMaster.instance.getPlatformVersion();
    print('Platform version: $version');
  } catch (e) {
    print('Error getting platform version: $e');
  }
}

// Example 2: Display full diagnostic info
void showDiagnosticInfo() async {
  try {
    final version = await ImagePickerMaster.instance.getPlatformVersion();
    print('═══ Diagnostic Info ═══');
    print('Platform version: ${version ?? 'Unknown'}');
    print('Current platform: ${Platform.operatingSystem}');
    print('Web: ${kIsWeb ? 'Yes' : 'No'}');
    print('═══════════════════');
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 2. `pickFiles()` Method
```dart
// Example 1: Pick various files
void pickVariousFiles() async {
  try {
    final files = await ImagePickerMaster.instance.pickFiles(
      type: FileType.all,
      allowMultiple: true,
    );

    if (files != null && files.isNotEmpty) {
      print('${files.length} files selected:');
      for (var file in files) {
        print('- ${file.name} (${file.size} bytes)');
      }
    } else {
      print('No files selected');
    }
  } catch (e) {
    print('Error picking files: $e');
  }
}

// Example 2: Pick custom files with compression
void pickCustomFilesWithCompression() async {
  try {
    final files = await ImagePickerMaster.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'docx'],
      allowMultiple: true,
      allowCompression: true,
      compressionQuality: 75,
      withData: true,
    );

    if (files != null) {
      for (var file in files) {
        print('File: ${file.name}');
        print('Size: ${file.size} bytes');
        print('MIME Type: ${file.mimeType}');
        print('Data available: ${file.bytes != null}');
        print('---');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

// Example 3: Pick office files
void pickOfficeFiles() async {
  try {
    final files = await ImagePickerMaster.instance.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
      allowMultiple: true,
      withData: false,
    );

    if (files != null && files.isNotEmpty) {
      print('Office files selected:');

      // Categorize by type
      final categories = <String, List<PickedFile>>{
        'PDF': [],
        'Word': [],
        'Excel': [],
        'PowerPoint': [],
        'Other': [],
      };

      for (var file in files) {
        final ext = file.name.split('.').last.toLowerCase();
        if (ext == 'pdf') {
          categories['PDF']!.add(file);
        } else if (['doc', 'docx'].contains(ext)) {
          categories['Word']!.add(file);
        } else if (['xls', 'xlsx'].contains(ext)) {
          categories['Excel']!.add(file);
        } else if (['ppt', 'pptx'].contains(ext)) {
          categories['PowerPoint']!.add(file);
        } else {
          categories['Other']!.add(file);
        }
      }

      categories.forEach((category, fileList) {
        if (fileList.isNotEmpty) {
          print('\n$category (${fileList.length} files):');
          for (var file in fileList) {
            print('  • ${file.name}');
          }
        }
      });
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 3. `pickImage()` Method
```dart
// Example 1: Pick a single image
void pickSingleImage() async {
  try {
    final image = await ImagePickerMaster.instance.pickImage();

    if (image != null) {
      print('Selected image: ${image.name}');
      print('File size: ${image.size} bytes');
      print('MIME Type: ${image.mimeType}');
      print('File path: ${image.path}');
    } else {
      print('No image selected');
    }
  } catch (e) {
    print('Error picking image: $e');
  }
}

// Example 2: High-quality image with data
void pickHighQualityImageWithData() async {
  try {
    final image = await ImagePickerMaster.instance.pickImage(
      allowCompression: true,
      compressionQuality: 95,
      withData: true,
    );

    if (image != null) {
      print('High-quality image selected: ${image.name}');
      print('Original size: ${image.size} bytes');

      if (image.bytes != null) {
        print('Image data available: ${image.bytes!.length} bytes');
        // Now you can use image.bytes for immediate processing
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 4. `pickImages()` Method
```dart
// Example 1: Pick multiple images
void pickMultipleImages() async {
  try {
    final images = await ImagePickerMaster.instance.pickImages();

    if (images != null && images.isNotEmpty) {
      print('${images.length} images selected:');

      for (int i = 0; i < images.length; i++) {
        final image = images[i];
        print('${i + 1}. ${image.name}');
        print('   Size: ${(image.size / 1024).toStringAsFixed(1)} KB');
        print('   Type: ${image.mimeType}');
      }
    } else {
      print('No images selected');
    }
  } catch (e) {
    print('Error picking images: $e');
  }
}
```

#### 5. `pickVideo()` Method
```dart
// Example 1: Pick a single video
void pickSingleVideo() async {
  try {
    final video = await ImagePickerMaster.instance.pickVideo();

    if (video != null) {
      print('Selected video: ${video.name}');
      print('File size: ${(video.size / 1024 / 1024).toStringAsFixed(2)} MB');
      print('MIME Type: ${video.mimeType}');
      print('File path: ${video.path}');
    } else {
      print('No video selected');
    }
  } catch (e) {
    print('Error picking video: $e');
  }
}
```

#### 6. `pickVideos()` Method
```dart
// Example 1: Pick multiple videos
void pickMultipleVideos() async {
  try {
    final videos = await ImagePickerMaster.instance.pickVideos();

    if (videos != null && videos.isNotEmpty) {
      print('${videos.length} videos selected:');
      double totalSize = 0;

      for (int i = 0; i < videos.length; i++) {
        final video = videos[i];
        final sizeInMB = video.size / 1024 / 1024;
        totalSize += sizeInMB;

        print('${i + 1}. ${video.name}');
        print('   Size: ${sizeInMB.toStringAsFixed(2)} MB');
        print('   Path: ${video.path}');
      }

      print('\nTotal size: ${totalSize.toStringAsFixed(2)} MB');
    } else {
      print('No videos selected');
    }
  } catch (e) {
    print('Error picking videos: $e');
  }
}
```

#### 7. `pickAudio()` Method
```dart
// Example 1: Pick a single audio file
void pickSingleAudio() async {
  try {
    final audio = await ImagePickerMaster.instance.pickAudio();

    if (audio != null) {
      print('Selected audio: ${audio.name}');
      print('File size: ${(audio.size / 1024).toStringAsFixed(1)} KB');
      print('MIME Type: ${audio.mimeType}');
      print('File path: ${audio.path}');
    } else {
      print('No audio file selected');
    }
  } catch (e) {
    print('Error picking audio: $e');
  }
}

// Example 2: Pick audio with data
void pickAudioWithData() async {
  try {
    final audio = await ImagePickerMaster.instance.pickAudio(
      withData: true,
    );

    if (audio != null) {
      print('Audio file: ${audio.name}');
      print('Size: ${(audio.size / 1024).toStringAsFixed(1)} KB');
      
      if (audio.bytes != null) {
        print('Audio data available: ${audio.bytes!.length} bytes');
        // Process audio data here
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 8. `pickAudios()` Method
```dart
// Example 1: Pick multiple audio files
void pickMultipleAudios() async {
  try {
    final audios = await ImagePickerMaster.instance.pickAudios();

    if (audios != null && audios.isNotEmpty) {
      print('${audios.length} audio files selected:');
      
      // Categorize by format
      final formats = <String, List<PickedFile>>{};
      
      for (var audio in audios) {
        final ext = audio.name.split('.').last.toLowerCase();
        formats.putIfAbsent(ext.toUpperCase(), () => []).add(audio);
      }
      
      formats.forEach((format, files) {
        print('\n$format files (${files.length}):');
        for (var file in files) {
          final sizeKB = file.size / 1024;
          print('  • ${file.name} - ${sizeKB.toStringAsFixed(1)} KB');
        }
      });
    } else {
      print('No audio files selected');
    }
  } catch (e) {
    print('Error picking audios: $e');
  }
}
```

#### 9. `pickDocument()` Method
```dart
// Example 1: Pick a single document
void pickSingleDocument() async {
  try {
    final document = await ImagePickerMaster.instance.pickDocument();

    if (document != null) {
      print('Selected document: ${document.name}');
      print('File size: ${(document.size / 1024).toStringAsFixed(1)} KB');
      print('MIME Type: ${document.mimeType}');
      print('File path: ${document.path}');
    } else {
      print('No document selected');
    }
  } catch (e) {
    print('Error picking document: $e');
  }
}

// Example 2: Pick specific document types
void pickSpecificDocuments() async {
  try {
    final document = await ImagePickerMaster.instance.pickDocument(
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      withData: true,
    );

    if (document != null) {
      print('Document: ${document.name}');
      print('Type: ${document.mimeType}');
      print('Size: ${(document.size / 1024).toStringAsFixed(1)} KB');
      
      if (document.bytes != null) {
        print('Document data loaded: ${document.bytes!.length} bytes');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 10. `pickDocuments()` Method
```dart
// Example 1: Pick multiple documents
void pickMultipleDocuments() async {
  try {
    final documents = await ImagePickerMaster.instance.pickDocuments();

    if (documents != null && documents.isNotEmpty) {
      print('${documents.length} documents selected:');
      
      // Group by file type
      final categories = <String, List<PickedFile>>{
        'PDF': [],
        'Word': [],
        'Excel': [],
        'PowerPoint': [],
        'Text': [],
        'Other': [],
      };

      for (var doc in documents) {
        final ext = doc.name.split('.').last.toLowerCase();
        if (ext == 'pdf') {
          categories['PDF']!.add(doc);
        } else if (['doc', 'docx'].contains(ext)) {
          categories['Word']!.add(doc);
        } else if (['xls', 'xlsx'].contains(ext)) {
          categories['Excel']!.add(doc);
        } else if (['ppt', 'pptx'].contains(ext)) {
          categories['PowerPoint']!.add(doc);
        } else if (['txt', 'md', 'rtf'].contains(ext)) {
          categories['Text']!.add(doc);
        } else {
          categories['Other']!.add(doc);
        }
      }

      categories.forEach((category, fileList) {
        if (fileList.isNotEmpty) {
          print('\n$category Documents (${fileList.length}):');
          for (var file in fileList) {
            final sizeKB = file.size / 1024;
            print('  • ${file.name} - ${sizeKB.toStringAsFixed(1)} KB');
          }
        }
      });
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 11. `capturePhoto()` Method
```dart
// Example 1: Capture a photo with camera
void capturePhotoFromCamera() async {
  try {
    final photo = await ImagePickerMaster.instance.capturePhoto();

    if (photo != null) {
      print('Photo captured: ${photo.name}');
      print('File size: ${(photo.size / 1024).toStringAsFixed(1)} KB');
      print('File path: ${photo.path}');
      print('MIME Type: ${photo.mimeType}');
    } else {
      print('Photo capture cancelled');
    }
  } catch (e) {
    print('Error capturing photo: $e');
  }
}

// Example 2: Capture high-quality photo with data
void captureHighQualityPhoto() async {
  try {
    final photo = await ImagePickerMaster.instance.capturePhoto(
      allowCompression: true,
      compressionQuality: 95,
      withData: true,
    );

    if (photo != null) {
      print('High-quality photo captured: ${photo.name}');
      print('Original size: ${(photo.size / 1024).toStringAsFixed(1)} KB');
      
      if (photo.bytes != null) {
        print('Photo data available: ${photo.bytes!.length} bytes');
        // Process image data immediately
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}

// Example 3: Capture compressed photo for upload
void captureCompressedPhoto() async {
  try {
    final photo = await ImagePickerMaster.instance.capturePhoto(
      allowCompression: true,
      compressionQuality: 60, // Lower quality for smaller file size
      withData: true,
    );

    if (photo != null) {
      final sizeKB = photo.size / 1024;
      print('Compressed photo: ${photo.name}');
      print('Compressed size: ${sizeKB.toStringAsFixed(1)} KB');
      
      // Perfect for uploading to server
      if (photo.bytes != null && sizeKB < 500) {
        print('Photo ready for upload (under 500KB)');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
```

#### 12. `clearTemporaryFiles()` Method
```dart
// Example 1: Clear temporary files
void clearTempFiles() async {
  try {
    await ImagePickerMaster.instance.clearTemporaryFiles();
    print('Temporary files cleared successfully');
  } catch (e) {
    print('Error clearing temporary files: $e');
  }
}

// Example 2: Clear files in app lifecycle
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    // Clear temporary files when app is disposed
    ImagePickerMaster.instance.clearTemporaryFiles();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Clear temporary files when app goes to background
      ImagePickerMaster.instance.clearTemporaryFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(),
    );
  }
}

// Example 3: Periodic cleanup
void setupPeriodicCleanup() {
  Timer.periodic(Duration(hours: 1), (timer) async {
    try {
      await ImagePickerMaster.instance.clearTemporaryFiles();
      print('Hourly cleanup completed');
    } catch (e) {
      print('Cleanup error: $e');
    }
  });
}
```

### File Information

Each picked file returns a `PickedFile` object with:

```dart
class PickedFile {
  final String path;           // File path
  final String name;           // File name (Unicode supported)
  final int size;              // File size in bytes
  final String? mimeType;      // MIME type
  final List<int>? bytes;      // File bytes (if withData: true)
}
```

## API Reference

### ImagePickerMaster Methods

| Method | Description | Parameters |
|--------|-------------|------------|
| `getPlatformVersion()` | Get platform version string | None |
| `pickFiles()` | Pick any files | `type`, `allowMultiple`, `allowedExtensions`, `withData`, `allowCompression`, `compressionQuality` |
| `pickImage()` | Pick a single image | `allowCompression`, `compressionQuality`, `withData` |
| `pickImages()` | Pick multiple images | `allowMultiple`, `allowCompression`, `compressionQuality`, `withData` |
| `pickVideo()` | Pick a single video | `withData` |
| `pickVideos()` | Pick multiple videos | `allowMultiple`, `withData` |
| `pickAudio()` | Pick a single audio file | `withData` |
| `pickAudios()` | Pick multiple audio files | `allowMultiple`, `withData` |
| `pickDocument()` | Pick a single document | `allowedExtensions`, `withData` |
| `pickDocuments()` | Pick multiple documents | `allowMultiple`, `allowedExtensions`, `withData` |
| `capturePhoto()` | Capture photo with camera | `allowCompression`, `compressionQuality`, `withData` |
| `clearTemporaryFiles()` | Clear temporary files | None |

### FileType Enum

```dart
enum FileType {
  all,        // All file types
  image,      // Image files only
  video,      // Video files only
  audio,      // Audio files only
  document,   // Document files only
  custom      // Custom extensions only
}
```

## Unicode Support

This plugin fully supports Unicode filenames, including:
- Persian/Farsi: `فاکتور.pdf`, `تصویر.jpg`
- Arabic: `ملف.docx`, `صورة.png`
- Chinese: `文档.txt`, `图片.jpeg`
- And all other Unicode characters

## Platform Support

| Platform | Status |
|----------|--------|
| Windows  | ✅ Full support |
| Android  | ✅ Full support |
| iOS      | ✅ Full support |
| macOS    | ✅ Full support |
| Linux    | ✅ Full support |
| Web      | ✅ Full support |

## Example

See the [example](example/) directory for a complete sample application demonstrating all features.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.


## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history and updates.


## Additional information

If you have any issues, questions, or suggestions related to this package, please feel free to contact us at [swan.dev1993@gmail.com](mailto:swan.dev1993@gmail.com). We welcome your feedback and will do our best to address any problems or provide assistance.
For more information about this package, you can also visit our [GitHub repository](https://pub.dev/packages/image_picker_master) where you can find additional resources, contribute to the package's development, and file issues or bug reports. We appreciate your contributions and feedback, and we aim to make this package as useful as possible for our users.
Thank you for using our package, and we look forward to hearing from you!
