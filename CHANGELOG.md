## 0.0.9

* **iOS:** Added `resizeImageForCropper()` — uses `CGImageSourceCreateThumbnailAtIndex` (ImageIO framework) for native thumbnail decode with EXIF rotation support. Completes in ~50 ms vs ~10 s in pure Dart.
* **macOS:** Added `resizeImageForCropper()` — same ImageIO path as iOS; encodes via `NSBitmapImageRep` JPEG compression.
* **Windows:** Added `resizeImageForCropper()` — uses GDI+ `Bitmap::GetThumbnailImage` on a background `std::thread`. Output written to `%TEMP%\cropper_preview\`.
* **Linux:** Added `resizeImageForCropper()` — uses `gdk_pixbuf_scale_simple` with `GDK_INTERP_BILINEAR` (native C). Output written to `/tmp/cropper_preview/`.
* **Web:** Added `resizeImageForCropper()` — loads the blob URL into an `<img>`, draws it at target size via `CanvasRenderingContext2D.drawImage` (browser native compositor), returns a new JPEG blob URL.
* **Web stub:** Added matching `resizeImageForCropper()` override.



* **Android:** Added `resizeImageForCropper()` method — uses `BitmapFactory.inSampleSize` for native resize, reducing a ~10 s pure-Dart decode on a 2 MB JPEG to ~50–150 ms.
  - Reads image dimensions first with `inJustDecodeBounds` (zero pixel decode).
  - Calculates the optimal `inSampleSize` to fit within `maxSize` in one pass.
  - Fine-tunes with `createScaledBitmap` if needed.
  - Uses `RGB_565` config to halve memory usage during decode.
  - Writes result to `caches/cropper_preview/` and tracks it for `clearTemporaryFiles()`.
  - Falls back to the original path on any error so the cropper never crashes.
* **Dart:** Added `resizeImageForCropper({required String path, int maxSize = 1024})` to `ImagePickerMasterPlatform`, `MethodChannelImagePickerMaster`, and `ImagePickerMaster`.



* **Android:** Added `res/xml/file_paths.xml` resource required by `FileProvider` — fixes `AAPT: error: resource xml/file_paths not found` build failure in host apps.
* **Android:** Downgraded AGP from `9.0.1` → `8.7.3` and Gradle wrapper from `9.1.0` → `8.11.1` to resolve Kotlin daemon incremental cache corruption (`IllegalStateException: Storage already registered`).
* **Android:** Pinned Kotlin Gradle Plugin to `2.1.21` (replaced non-existent `2.3.20`).
* **Web:** Fixed `unawaited_futures` lint — added `await` to `loadCompleter.future` inside `_compressJpeg` so exceptions are properly caught by the surrounding `try/catch`.
* **Example:** Removed all `debugPrint` calls from `example/lib/main.dart`.
* **Example:** Translated camera error messages in `_getCameraErrorMessage` from Persian to English.



* **Web:** Replaced `dart:html` with `package:web` (`dart:js_interop`) for full WASM compatibility.
* **Web:** Rewrote file picker, camera capture, and image compression using `web.*` APIs — no breaking changes to the public API.
* **pubspec:** Bumped version to `0.0.6`.

## 0.0.5

* **Android:** Fixed `IllegalStateException: Reply already submitted` crash when camera permission is denied.
* **Android:** Added runtime `CAMERA` permission request — users are now prompted automatically.
* **Android:** Introduced `SingleUseResult` wrapper to prevent double-reply on all method calls.
* **Android:** Migrated to AGP 9.0 built-in Kotlin support; removed legacy `buildscript` KGP classpath.
* **iOS:** Fixed video picking hang on iOS 14+ caused by `UTType.movie` vs `kUTTypeMovie` identifier mismatch.
* **iOS:** Fixed `isCapturePhotoMode` not resetting on camera error paths.
* **iOS:** Fixed `compressionQuality` state bleeding between sequential calls.
* **iOS:** Fixed iPad `UIAlertController` popover outside-tap leaving Dart future unresolved.
* **iOS:** Fixed `UIDocumentPickerViewController` reading from original URL instead of copied temp file.
* **iOS:** Fixed `FileType.custom` ignoring `allowedExtensions` on iOS < 14.
* **iOS:** Refactored to per-call isolated state (`PendingCall`) — eliminates shared-state race conditions.
* **iOS/macOS:** Enabled `PrivacyInfo.xcprivacy` in both `Package.swift` and `.podspec`.
* **iOS:** Added `script_phase` to auto-inject camera and photo library permission descriptions into host app `Info.plist`.
* **macOS:** Added `script_phase` to auto-inject camera permission descriptions and entitlements into host app.
* **macOS:** Fixed `.podspec` platform version (`10.11` → `10.15`) to match `Package.swift`.
* **Linux:** Added missing `find_package(PkgConfig)`, `GDK_PIXBUF`, `GIO` declarations and `CXX_STANDARD 17` to `CMakeLists.txt`.
* **Linux:** Fixed `bytes` field sent as base64 `String` instead of `Uint8List`.
* **Linux:** Added `mimeType` detection via `g_content_type_guess`.
* **Linux:** Added `clearTemporaryFiles` method handler.
* **Linux:** Fixed `capturePhoto` to open an image file picker instead of returning an unsupported error.
* **Tests:** Fixed `ImagePickerMaster()` unnamed constructor error — updated all test files to use `ImagePickerMaster.instance`.
* **pubspec:** Fixed `homepage` URL (removed trailing `.git`) and added `repository` and `issue_tracker` fields.


## 0.0.4

* Fix pug for web.
* Edit README.md.
* Fix pug Android for camera.


## 0.0.3

* Add new method for picker camera.


## 0.0.2

* Fix pub point.
* Add document package.


## 0.0.1

* Initial release.
