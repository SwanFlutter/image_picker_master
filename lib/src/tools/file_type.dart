/// Enumeration of supported file types for file picking operations.
///
/// This enum defines the different categories of files that can be
/// selected using the ImagePickerMaster plugin.
enum FileType {
  /// All file types are allowed.
  all,

  /// Only image files (JPEG, PNG, GIF, BMP, TIFF, WebP, HEIC, HEIF, AVIF, SVG, ICO).
  image,

  /// Only video files (MP4, AVI, MOV, MKV, WMV, FLV, WebM, 3GP, M4V).
  video,

  /// Only audio files (MP3, WAV, M4A, FLAC, OGG, AAC, WMA, AIFF).
  audio,

  /// Only document files (PDF, Word, Excel, PowerPoint, Text, RTF, Markdown, etc.).
  document,

  /// Custom file types based on allowedExtensions parameter.
  custom,
}
