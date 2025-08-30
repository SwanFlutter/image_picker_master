import 'image_picker_master_platform_interface.dart';
import 'src/tools/file_picker_options.dart';
import 'src/tools/file_type.dart';
import 'src/tools/picked_file.dart';

export 'src/tools/file_picker_options.dart';
export 'src/tools/file_type.dart';
export 'src/tools/picked_file.dart';

/// A powerful and versatile file picker plugin for Flutter that supports
/// multiple file types including images, videos, audio files, and documents
/// across all platforms (Android, iOS, Windows, macOS, Linux, Web).
///
/// This plugin provides a unified API for file selection with features like:
/// - Multiple file selection
/// - File type filtering
/// - Image compression
/// - Cross-platform compatibility
/// - Support for 170+ file formats
class ImagePickerMaster {
  static ImagePickerMaster? _instance;

  /// Gets the singleton instance of [ImagePickerMaster].
  static ImagePickerMaster get instance => _instance ??= ImagePickerMaster._();

  ImagePickerMaster._();

  /// Returns the platform version string.
  ///
  /// This method is primarily used for debugging and testing purposes.
  ///
  /// Example:
  /// ```dart
  /// final version = await ImagePickerMaster.instance.getPlatformVersion();
  /// print('Platform version: $version');
  /// ```
  Future<String?> getPlatformVersion() {
    return ImagePickerMasterPlatform.instance.getPlatformVersion();
  }

  /// Picks files from the device storage with customizable options.
  ///
  /// [type] specifies the type of files to pick (all, image, video, audio, document, custom).
  /// [allowMultiple] allows selecting multiple files when set to true.
  /// [allowedExtensions] restricts file selection to specific extensions (only works with FileType.custom).
  /// [withData] includes file bytes in the result when set to true.
  /// [allowCompression] enables image compression for image files.
  /// [compressionQuality] sets the compression quality (0-100) when compression is enabled.
  ///
  /// Returns a list of [PickedFile] objects or null if no files were selected.
  ///
  /// Example:
  /// ```dart
  /// final files = await ImagePickerMaster.instance.pickFiles(
  ///   type: FileType.image,
  ///   allowMultiple: true,
  ///   allowCompression: true,
  ///   compressionQuality: 80,
  /// );
  /// ```
  Future<List<PickedFile>?> pickFiles({
    FileType type = FileType.all,
    bool allowMultiple = false,
    List<String>? allowedExtensions,
    bool withData = false,
    bool allowCompression = false,
    int? compressionQuality,
  }) async {
    final options = FilePickerOptions(
      type: type,
      allowMultiple: allowMultiple,
      allowedExtensions: allowedExtensions,
      withData: withData,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
    );

    return ImagePickerMasterPlatform.instance.pickFiles(options);
  }

  /// Picks a single image file from the device storage.
  ///
  /// [allowCompression] enables image compression (default: true).
  /// [compressionQuality] sets the compression quality from 0-100 (default: 80).
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a [PickedFile] object or null if no image was selected.
  ///
  /// Supported formats: JPEG, PNG, GIF, BMP, TIFF, WebP, HEIC, HEIF, AVIF, SVG, ICO
  ///
  /// Example:
  /// ```dart
  /// final image = await ImagePickerMaster.instance.pickImage(
  ///   allowCompression: true,
  ///   compressionQuality: 70,
  /// );
  /// if (image != null) {
  ///   print('Selected image: ${image.name}');
  /// }
  /// ```
  Future<PickedFile?> pickImage({
    bool allowCompression = true,
    int compressionQuality = 80,
    bool withData = false,
  }) async {
    final result = await pickFiles(
      type: FileType.image,
      allowMultiple: false,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  /// Picks multiple image files from the device storage.
  ///
  /// [allowMultiple] allows selecting multiple images (default: true).
  /// [allowCompression] enables image compression (default: true).
  /// [compressionQuality] sets the compression quality from 0-100 (default: 80).
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a list of [PickedFile] objects or null if no images were selected.
  ///
  /// Example:
  /// ```dart
  /// final images = await ImagePickerMaster.instance.pickImages(
  ///   allowMultiple: true,
  ///   allowCompression: true,
  ///   compressionQuality: 85,
  /// );
  /// if (images != null) {
  ///   print('Selected ${images.length} images');
  /// }
  /// ```
  Future<List<PickedFile>?> pickImages({
    bool allowMultiple = true,
    bool allowCompression = true,
    int compressionQuality = 80,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.image,
      allowMultiple: allowMultiple,
      allowCompression: allowCompression,
      compressionQuality: compressionQuality,
      withData: withData,
    );
  }

  /// Picks a single video file from the device storage.
  ///
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a [PickedFile] object or null if no video was selected.
  ///
  /// Supported formats: MP4, AVI, MOV, MKV, WMV, FLV, WebM, 3GP, M4V
  ///
  /// Example:
  /// ```dart
  /// final video = await ImagePickerMaster.instance.pickVideo();
  /// if (video != null) {
  ///   print('Selected video: ${video.name} (${video.size} bytes)');
  /// }
  /// ```
  Future<PickedFile?> pickVideo({bool withData = false}) async {
    final result = await pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  /// Picks multiple video files from the device storage.
  ///
  /// [allowMultiple] allows selecting multiple videos (default: true).
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a list of [PickedFile] objects or null if no videos were selected.
  ///
  /// Example:
  /// ```dart
  /// final videos = await ImagePickerMaster.instance.pickVideos(
  ///   allowMultiple: true,
  /// );
  /// if (videos != null) {
  ///   for (var video in videos) {
  ///     print('Video: ${video.name}');
  ///   }
  /// }
  /// ```
  Future<List<PickedFile>?> pickVideos({
    bool allowMultiple = true,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.video,
      allowMultiple: allowMultiple,
      withData: withData,
    );
  }

  /// Picks a single audio file from the device storage.
  ///
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a [PickedFile] object or null if no audio file was selected.
  ///
  /// Supported formats: MP3, WAV, M4A, FLAC, OGG, AAC, WMA, AIFF
  ///
  /// Example:
  /// ```dart
  /// final audio = await ImagePickerMaster.instance.pickAudio();
  /// if (audio != null) {
  ///   print('Selected audio: ${audio.name}');
  ///   print('MIME type: ${audio.mimeType}');
  /// }
  /// ```
  Future<PickedFile?> pickAudio({bool withData = false}) async {
    final result = await pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  /// Picks multiple audio files from the device storage.
  ///
  /// [allowMultiple] allows selecting multiple audio files (default: true).
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a list of [PickedFile] objects or null if no audio files were selected.
  ///
  /// Example:
  /// ```dart
  /// final audios = await ImagePickerMaster.instance.pickAudios();
  /// if (audios != null) {
  ///   print('Selected ${audios.length} audio files');
  /// }
  /// ```
  Future<List<PickedFile>?> pickAudios({
    bool allowMultiple = true,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.audio,
      allowMultiple: allowMultiple,
      withData: withData,
    );
  }

  /// Picks a single document file from the device storage.
  ///
  /// [allowedExtensions] restricts document selection to specific extensions.
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a [PickedFile] object or null if no document was selected.
  ///
  /// Supported formats: PDF, Word, Excel, PowerPoint, Text, RTF, Markdown,
  /// OpenDocument, Google Docs/Sheets/Slides, iWork, EPUB, HTML, CSS, JavaScript,
  /// JSON, XML, CSV, Archive files (ZIP, RAR, 7Z, TAR, GZ)
  ///
  /// Example:
  /// ```dart
  /// final document = await ImagePickerMaster.instance.pickDocument(
  ///   allowedExtensions: ['pdf', 'doc', 'docx'],
  /// );
  /// if (document != null) {
  ///   print('Selected document: ${document.name}');
  /// }
  /// ```
  Future<PickedFile?> pickDocument({
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    final result = await pickFiles(
      type: FileType.document,
      allowMultiple: false,
      allowedExtensions: allowedExtensions,
      withData: withData,
    );

    return result?.isNotEmpty == true ? result!.first : null;
  }

  /// Picks multiple document files from the device storage.
  ///
  /// [allowMultiple] allows selecting multiple documents (default: true).
  /// [allowedExtensions] restricts document selection to specific extensions.
  /// [withData] includes file bytes in the result when set to true.
  ///
  /// Returns a list of [PickedFile] objects or null if no documents were selected.
  ///
  /// Example:
  /// ```dart
  /// final documents = await ImagePickerMaster.instance.pickDocuments(
  ///   allowedExtensions: ['pdf', 'txt', 'json'],
  ///   withData: true,
  /// );
  /// if (documents != null) {
  ///   for (var doc in documents) {
  ///     print('Document: ${doc.name} - Size: ${doc.size} bytes');
  ///   }
  /// }
  /// ```
  Future<List<PickedFile>?> pickDocuments({
    bool allowMultiple = true,
    List<String>? allowedExtensions,
    bool withData = false,
  }) async {
    return pickFiles(
      type: FileType.document,
      allowMultiple: allowMultiple,
      allowedExtensions: allowedExtensions,
      withData: withData,
    );
  }

  /// Clears all temporary files created by the plugin.
  ///
  /// This method should be called periodically to free up storage space
  /// used by temporary files created during file picking operations.
  ///
  /// It's recommended to call this method when your app is being disposed
  /// or when you no longer need the picked files.
  ///
  /// Example:
  /// ```dart
  /// // Clear temporary files when app is disposed
  /// @override
  /// void dispose() {
  ///   ImagePickerMaster.instance.clearTemporaryFiles();
  ///   super.dispose();
  /// }
  /// ```
  Future<void> clearTemporaryFiles() async {
    return ImagePickerMasterPlatform.instance.clearTemporaryFiles();
  }
}
