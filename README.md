# Image Picker Master

A comprehensive Flutter plugin for picking files from device storage with full Unicode support, including Persian/Farsi filenames.

## Features

- ✅ **Multi-platform Support**: Windows, Android, iOS, macOS, Linux, Web
- ✅ **Multiple File Types**: Images, videos, audio, documents, and custom files
- ✅ **Unicode Support**: Full support for Persian/Farsi and other Unicode filenames
- ✅ **Flexible Selection**: Single or multiple file selection
- ✅ **File Compression**: Optional image compression with quality control
- ✅ **MIME Type Detection**: Automatic file type detection
- ✅ **Memory Efficient**: Optimized file handling without unnecessary copying

## Supported File Types

### Images
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- BMP (.bmp)
- TIFF (.tiff)
- WebP (.webp)

### Videos
- MP4 (.mp4)
- AVI (.avi)
- MOV (.mov)
- MKV (.mkv)
- WMV (.wmv)
- FLV (.flv)

### Audio
- MP3 (.mp3)
- WAV (.wav)
- M4A (.m4a)
- FLAC (.flac)
- OGG (.ogg)

### Documents
- PDF (.pdf)
- Word (.doc, .docx)
- Excel (.xls, .xlsx)
- PowerPoint (.ppt, .pptx)
- Text (.txt)
- RTF (.rtf)
- Markdown (.md, .markdown)
- OpenDocument Text (.odt)
- OpenDocument Spreadsheet (.ods)
- OpenDocument Presentation (.odp)
- Google Docs/Sheets/Slides
- iWork Pages/Numbers/Keynote
- EPUB (.epub)
- HTML (.html, .htm)
- CSS (.css)
- JavaScript (.js)
- JSON (.json)
- XML (.xml)
- CSV (.csv)
- Archive files (.zip, .rar, .7z, .tar, .gz)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  image_picker_master: ^0.0.3
```

Then run:

```bash
flutter pub get
```

## Usage

### Basic Usage

```dart
import 'package:image_picker_master/image_picker_master.dart';

final picker = ImagePickerMaster.instance;

// Pick a single image
final image = await picker.pickImage();
if (image != null) {
  print('Selected image: ${image.name}');
  print('File size: ${image.size} bytes');
  print('MIME type: ${image.mimeType}');
}

// Pick multiple images
final images = await picker.pickImages(allowMultiple: true);
if (images != null && images.isNotEmpty) {
  for (final image in images) {
    print('Image: ${image.name}');
  }
}
```

### Advanced Usage

```dart
// Pick documents with specific extensions
final documents = await picker.pickDocuments(
  allowMultiple: true,
  allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
);

// Pick any files
final files = await picker.pickFiles(
  type: FileType.all,
  allowMultiple: true,
);

// Pick with compression
final compressedImage = await picker.pickImage(
  allowCompression: true,
  compressionQuality: 80,
);

// Pick with file data
final imageWithData = await picker.pickImage(
  withData: true,
);
if (imageWithData != null && imageWithData.bytes != null) {
  // Use the file bytes directly
  final bytes = imageWithData.bytes!;
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
| `pickImage()` | Pick a single image | `allowCompression`, `compressionQuality`, `withData` |
| `pickImages()` | Pick multiple images | `allowMultiple`, `allowCompression`, `compressionQuality`, `withData` |
| `pickVideo()` | Pick a single video | `withData` |
| `pickVideos()` | Pick multiple videos | `allowMultiple`, `withData` |
| `pickAudio()` | Pick a single audio file | `withData` |
| `pickAudios()` | Pick multiple audio files | `allowMultiple`, `withData` |
| `pickDocument()` | Pick a single document | `allowedExtensions`, `withData` |
| `pickDocuments()` | Pick multiple documents | `allowMultiple`, `allowedExtensions`, `withData` |
| `pickFiles()` | Pick any files | `type`, `allowMultiple`, `allowedExtensions`, `withData`, `allowCompression`, `compressionQuality` |
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
