## 0.0.6

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
