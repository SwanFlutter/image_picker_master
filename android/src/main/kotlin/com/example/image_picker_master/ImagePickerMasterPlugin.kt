package com.example.image_picker_master

import android.Manifest
import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.*
import java.text.SimpleDateFormat
import java.util.*

class ImagePickerMasterPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener,
    PluginRegistry.RequestPermissionsResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null

    // Single pending result — null when no call is in flight.
    // Using a wrapper so we can guard against double-reply.
    private var pendingResult: SingleUseResult? = null

    private var allowMultiple = false
    private var fileType = "all"
    private var allowedExtensions: List<String>? = null
    private var withData = false
    private var allowCompression = false
    private var compressionQuality = 80
    private val temporaryFiles = mutableListOf<File>()
    private var photoUri: Uri? = null

    companion object {
        private const val TAG = "ImagePickerMaster"
        private const val REQUEST_CODE_PICK_FILE     = 1001
        private const val REQUEST_CODE_CAPTURE_IMAGE = 1003
        private const val REQUEST_CODE_CAMERA_PERM   = 2001
    }

    // ─── Single-use result wrapper ─────────────────────────────────────────
    // Prevents "Reply already submitted" crashes when multiple code paths
    // could call success/error on the same Result object.

    private class SingleUseResult(private val result: Result) {
        private var consumed = false

        fun success(value: Any?) {
            if (consumed) return
            consumed = true
            result.success(value)
        }

        fun error(code: String, message: String?, details: Any?) {
            if (consumed) return
            consumed = true
            result.error(code, message, details)
        }

        fun notImplemented() {
            if (consumed) return
            consumed = true
            result.notImplemented()
        }
    }

    // ─── FlutterPlugin ─────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "image_picker_master")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        clearTemporaryFiles()
    }

    // ─── MethodCallHandler ─────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        Log.d(TAG, "Method called: ${call.method}")
        pendingResult = SingleUseResult(result)

        when (call.method) {
            "getPlatformVersion" -> {
                pendingResult?.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "pickFiles" -> {
                val arguments = call.arguments as? Map<*, *> ?: run {
                    pendingResult?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                    return
                }
                pickFiles(arguments)
            }
            "capturePhoto" -> {
                val arguments = call.arguments as? Map<*, *> ?: run {
                    pendingResult?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                    return
                }
                capturePhoto(arguments)
            }
            "clearTemporaryFiles" -> {
                clearTemporaryFiles()
                pendingResult?.success(null)
            }
            "resizeImageForCropper" -> {
                val arguments = call.arguments as? Map<*, *> ?: run {
                    pendingResult?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                    return
                }
                resizeImageForCropper(arguments)
            }
            "cropImageNative" -> {
                val arguments = call.arguments as? Map<*, *> ?: run {
                    pendingResult?.error("INVALID_ARGUMENTS", "Arguments must be a map", null)
                    return
                }
                cropImageNative(arguments)
            }
            else -> {
                pendingResult?.notImplemented()
            }
        }
    }

    // ─── capturePhoto ──────────────────────────────────────────────────────

    private fun capturePhoto(arguments: Map<*, *>) {
        Log.d(TAG, "capturePhoto called with arguments: $arguments")

        val act = activity ?: run {
            pendingResult?.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        allowCompression   = arguments["allowCompression"]   as? Boolean ?: false
        compressionQuality = arguments["compressionQuality"] as? Int     ?: 80
        withData           = arguments["withData"]           as? Boolean ?: false

        // Check / request CAMERA permission at runtime
        if (ContextCompat.checkSelfPermission(act, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "CAMERA permission not granted — requesting")
            ActivityCompat.requestPermissions(
                act,
                arrayOf(Manifest.permission.CAMERA),
                REQUEST_CODE_CAMERA_PERM
            )
            // Result will arrive in onRequestPermissionsResult
            return
        }

        launchCamera(act)
    }

    private fun launchCamera(act: Activity) {
        val photoFile = createImageFile()
        photoUri = FileProvider.getUriForFile(
            act,
            "${act.packageName}.fileprovider",
            photoFile
        )

        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
            putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
        }

        if (intent.resolveActivity(act.packageManager) != null) {
            try {
                act.startActivityForResult(intent, REQUEST_CODE_CAPTURE_IMAGE)
                Log.d(TAG, "Camera activity started")
            } catch (e: Exception) {
                Log.e(TAG, "Error starting camera: ${e.message}")
                pendingResult?.error("CAMERA_ERROR", "Cannot start camera: ${e.message}", null)
            }
        } else {
            Log.e(TAG, "No camera app available")
            pendingResult?.error("NO_CAMERA", "No camera app available on this device", null)
        }
    }

    // ─── pickFiles ─────────────────────────────────────────────────────────

    private fun pickFiles(arguments: Map<*, *>) {
        val act = activity ?: run {
            pendingResult?.error("NO_ACTIVITY", "Activity is not available", null)
            return
        }

        fileType           = arguments["type"]               as? String  ?: "all"
        allowMultiple      = arguments["allowMultiple"]      as? Boolean ?: false
        allowedExtensions  = (arguments["allowedExtensions"] as? List<*>)?.filterIsInstance<String>()
        withData           = arguments["withData"]           as? Boolean ?: false
        allowCompression   = arguments["allowCompression"]   as? Boolean ?: false
        compressionQuality = arguments["compressionQuality"] as? Int     ?: 80

        val intent = buildPickIntent()
        try {
            act.startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
        } catch (e: Exception) {
            pendingResult?.error("INTENT_ERROR", "Cannot open file picker: ${e.message}", null)
        }
    }

    private fun buildPickIntent(): Intent {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            if (allowMultiple) putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }

        when (fileType) {
            "image"    -> intent.type = "image/*"
            "video"    -> intent.type = "video/*"
            "audio"    -> intent.type = "audio/*"
            "document" -> {
                intent.type = "*/*"
                intent.putExtra(Intent.EXTRA_MIME_TYPES, documentMimeTypes())
            }
            "custom" -> {
                val mimeTypes = allowedExtensions
                    ?.mapNotNull { MimeTypeMap.getSingleton().getMimeTypeFromExtension(it.lowercase()) }
                    ?.toTypedArray()
                intent.type = "*/*"
                if (!mimeTypes.isNullOrEmpty()) {
                    intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
                }
            }
            else -> intent.type = "*/*"   // "all"
        }

        return Intent.createChooser(intent, "Select File")
    }

    // ─── ActivityResultListener ────────────────────────────────────────────

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            REQUEST_CODE_PICK_FILE -> {
                handlePickFileResult(resultCode, data)
                true
            }
            REQUEST_CODE_CAPTURE_IMAGE -> {
                handleCaptureImageResult(resultCode)
                true
            }
            else -> false
        }
    }

    private fun handlePickFileResult(resultCode: Int, data: Intent?) {
        if (resultCode != Activity.RESULT_OK || data == null) {
            pendingResult?.success(null)
            return
        }

        try {
            val selectedFiles = mutableListOf<Map<String, Any?>>()

            val clipData = data.clipData
            if (clipData != null) {
                for (i in 0 until clipData.itemCount) {
                    processSelectedFile(clipData.getItemAt(i).uri)?.let { selectedFiles.add(it) }
                }
            } else {
                data.data?.let { uri ->
                    processSelectedFile(uri)?.let { selectedFiles.add(it) }
                }
            }

            pendingResult?.success(if (selectedFiles.isEmpty()) null else selectedFiles)
        } catch (e: Exception) {
            pendingResult?.error("PROCESSING_ERROR", "Error processing selected files: ${e.message}", null)
        }
    }

    private fun handleCaptureImageResult(resultCode: Int) {
        val uri = photoUri
        photoUri = null

        if (resultCode != Activity.RESULT_OK || uri == null) {
            pendingResult?.success(null)
            return
        }

        try {
            val fileData = processSelectedFile(uri)
            if (fileData != null) {
                // capturePhoto returns a single Map, not a List
                pendingResult?.success(fileData)
            } else {
                pendingResult?.error("PROCESSING_ERROR", "Error processing captured image", null)
            }
        } catch (e: Exception) {
            pendingResult?.error("PROCESSING_ERROR", "Error processing captured image: ${e.message}", null)
        }
    }

    // ─── RequestPermissionsResultListener ─────────────────────────────────

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_CAMERA_PERM) return false

        val act = activity
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            Log.d(TAG, "CAMERA permission granted — launching camera")
            if (act != null) {
                launchCamera(act)
            } else {
                pendingResult?.error("NO_ACTIVITY", "Activity is not available after permission grant", null)
            }
        } else {
            Log.w(TAG, "CAMERA permission denied by user")
            pendingResult?.error(
                "CAMERA_PERMISSION_DENIED",
                "Camera permission was denied by the user",
                null
            )
        }
        return true
    }

    // ─── File processing helpers ───────────────────────────────────────────

    private fun processSelectedFile(uri: Uri): Map<String, Any?>? {
        return try {
            val cr        = activity?.contentResolver ?: return null
            val fileName  = getFileName(cr, uri)
            val fileSize  = getFileSize(cr, uri)
            val mimeType  = cr.getType(uri)
            val tempFile  = copyToTempFile(fileName, uri)

            val map = mutableMapOf<String, Any?>(
                "path"     to tempFile.absolutePath,
                "name"     to fileName,
                "size"     to fileSize,
                "mimeType" to mimeType,
                "bytes"    to null
            )

            if (withData) {
                var bytes = cr.openInputStream(uri)?.use { it.readBytes() } ?: byteArrayOf()
                if (allowCompression && mimeType?.startsWith("image/") == true) {
                    bytes = compressImageBytes(bytes, compressionQuality)
                }
                map["bytes"] = bytes
            }

            map
        } catch (e: Exception) {
            Log.e(TAG, "processSelectedFile error: ${e.message}")
            null
        }
    }

    private fun copyToTempFile(fileName: String, uri: Uri): File {
        val tempDir = File(activity!!.cacheDir, "file_picker").also { it.mkdirs() }
        val tempFile = File(tempDir, "${UUID.randomUUID()}_$fileName")
        temporaryFiles.add(tempFile)

        activity!!.contentResolver.openInputStream(uri)?.use { input ->
            tempFile.outputStream().use { output -> input.copyTo(output) }
        }
        return tempFile
    }

    private fun createImageFile(): File {
        val timeStamp = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())
        val storageDir = File(activity!!.cacheDir, "images").also { it.mkdirs() }
        return File.createTempFile("JPEG_${timeStamp}_", ".jpg", storageDir)
            .also { temporaryFiles.add(it) }
    }

    private fun getFileName(cr: ContentResolver, uri: Uri): String {
        cr.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx != -1) return cursor.getString(idx) ?: "unknown"
            }
        }
        return uri.lastPathSegment ?: "unknown"
    }

    private fun getFileSize(cr: ContentResolver, uri: Uri): Long {
        cr.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (idx != -1) return cursor.getLong(idx)
            }
        }
        return 0L
    }

    private fun compressImageBytes(original: ByteArray, quality: Int): ByteArray {
        return try {
            val bitmap = BitmapFactory.decodeByteArray(original, 0, original.size)
            ByteArrayOutputStream().also { out ->
                bitmap.compress(Bitmap.CompressFormat.JPEG, quality, out)
            }.toByteArray()
        } catch (e: Exception) {
            original
        }
    }

    // ─── resizeImageForCropper ─────────────────────────────────────────────
    // Decodes only 1/sampleSize² of the pixels using inSampleSize — the same
    // work that took Dart ~10 s takes ~50–150 ms here in native C++.

    private fun resizeImageForCropper(arguments: Map<*, *>) {
        val filePath = arguments["path"] as? String ?: run {
            pendingResult?.error("INVALID_ARGUMENTS", "path is required", null)
            return
        }
        val maxSize = arguments["maxSize"] as? Int ?: 1024

        Thread {
            try {
                // ── Step 1: read dimensions only (no pixel decode) ────────
                val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(filePath, boundsOpts)

                val origW = boundsOpts.outWidth
                val origH = boundsOpts.outHeight

                // Image already fits — return original path immediately
                if (origW <= maxSize && origH <= maxSize) {
                    activity?.runOnUiThread { pendingResult?.success(filePath) }
                    return@Thread
                }

                // ── Step 2: calculate inSampleSize ────────────────────────
                var sampleSize = 1
                var halfW = origW / 2
                var halfH = origH / 2
                while (halfW / sampleSize >= maxSize && halfH / sampleSize >= maxSize) {
                    sampleSize *= 2
                }

                // ── Step 3: decode with inSampleSize (very fast) ──────────
                val decodeOpts = BitmapFactory.Options().apply {
                    inSampleSize = sampleSize
                    inPreferredConfig = Bitmap.Config.RGB_565 // 2 bytes/px instead of 4
                }
                val sampled = BitmapFactory.decodeFile(filePath, decodeOpts) ?: run {
                    // Decode failed — fall back to original path
                    activity?.runOnUiThread { pendingResult?.success(filePath) }
                    return@Thread
                }

                // ── Step 4: fine-tune resize if still over maxSize ────────
                val scale = maxSize.toFloat() / maxOf(sampled.width, sampled.height)
                val finalBitmap = if (scale < 1f) {
                    val newW = (sampled.width  * scale).toInt()
                    val newH = (sampled.height * scale).toInt()
                    val scaled = Bitmap.createScaledBitmap(sampled, newW, newH, true)
                    sampled.recycle()
                    scaled
                } else {
                    sampled
                }

                // ── Step 5: write to cache ────────────────────────────────
                val outDir  = File(activity!!.cacheDir, "cropper_preview").also { it.mkdirs() }
                val outFile = File(outDir, "preview_${UUID.randomUUID()}.jpg")
                temporaryFiles.add(outFile)

                FileOutputStream(outFile).use { out ->
                    finalBitmap.compress(Bitmap.CompressFormat.JPEG, 85, out)
                }
                finalBitmap.recycle()

                activity?.runOnUiThread { pendingResult?.success(outFile.absolutePath) }

            } catch (e: Exception) {
                Log.e(TAG, "resizeImageForCropper error: ${e.message}")
                // On any error fall back to the original path so the cropper still works
                activity?.runOnUiThread { pendingResult?.success(filePath) }
            }
        }.start()
    }

    private fun clearTemporaryFiles() {
        temporaryFiles.forEach { runCatching { it.delete() } }
        temporaryFiles.clear()
    }

    // ─── cropImageNative ───────────────────────────────────────────────────
    // Full native crop+encode pipeline. Replaces the Dart compute() isolate.
    // Runs on a background Thread — never blocks the UI.
    //
    // Arguments:
    //   path        : String  — absolute path to source image
    //   cropX/Y     : Double  — top-left of crop rect in container coordinates
    //   cropW/H     : Double  — size of crop rect in container coordinates
    //   containerW/H: Double  — displayed container size (matches Flutter widget)
    //   rotation    : Int     — clockwise degrees (0, 90, 180, 270)
    //   quality     : Int     — 0-100 (default 85, ignored for PNG)
    //   format      : String  — "jpeg" | "png" | "webp_lossy" | "webp_lossless"
    //   maxSize     : Int     — max decode edge in px (default 1200)

    @Suppress("NAME_SHADOWING")
    private fun cropImageNative(arguments: Map<*, *>) {
        val srcPath    = arguments["path"]       as? String  ?: run { pendingResult?.error("INVALID_ARGUMENTS", "path required", null); return }
        val cropX      = (arguments["cropX"]      as? Number)?.toFloat() ?: 0f
        val cropY      = (arguments["cropY"]      as? Number)?.toFloat() ?: 0f
        val cropW      = (arguments["cropW"]      as? Number)?.toFloat() ?: 1f
        val cropH      = (arguments["cropH"]      as? Number)?.toFloat() ?: 1f
        val containerW = (arguments["containerW"] as? Number)?.toFloat() ?: 1f
        val containerH = (arguments["containerH"] as? Number)?.toFloat() ?: 1f
        val rotation   = arguments["rotation"]    as? Int    ?: 0
        val quality    = arguments["quality"]     as? Int    ?: 85
        val formatStr  = (arguments["format"]     as? String ?: "jpeg").lowercase()
        val maxSize    = arguments["maxSize"]      as? Int   ?: 1200

        val outputFormat = when (formatStr) {
            "png"             -> OutputFormat.PNG
            "webp_lossy"      -> OutputFormat.WEBP_LOSSY
            "webp_lossless"   -> OutputFormat.WEBP_LOSSLESS
            else              -> OutputFormat.JPEG
        }

        Thread {
            try {
                // ── Step 1: read dimensions only ─────────────────────────
                val boundsOpts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(srcPath, boundsOpts)
                val origW = boundsOpts.outWidth
                val origH = boundsOpts.outHeight

                // ── Step 2: inSampleSize — stay near maxSize ──────────────
                var sampleSize = 1
                var hw = origW / 2; var hh = origH / 2
                while (hw / sampleSize >= maxSize && hh / sampleSize >= maxSize) sampleSize *= 2

                val config = if (outputFormat == OutputFormat.PNG ||
                                 outputFormat == OutputFormat.WEBP_LOSSLESS)
                    Bitmap.Config.ARGB_8888 else Bitmap.Config.RGB_565
                val decodeOpts = BitmapFactory.Options().apply {
                    inSampleSize = sampleSize; inPreferredConfig = config
                }
                var bmp = BitmapFactory.decodeFile(srcPath, decodeOpts)
                    ?: run { activity?.runOnUiThread { pendingResult?.error("DECODE_FAILED", "Cannot decode image", null) }; return@Thread }

                // ── Step 3: rotation ──────────────────────────────────────
                if (rotation != 0) {
                    val matrix = android.graphics.Matrix().apply { postRotate(rotation.toFloat()) }
                    val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
                    bmp.recycle(); bmp = rotated
                }

                // ── Step 4: map crop rect from container coords → pixel coords
                val imgAspect  = bmp.width.toFloat() / bmp.height.toFloat()
                val contAspect = containerW / containerH
                val displayedW: Float; val displayedH: Float
                val offsetX: Float;    val offsetY: Float
                if (imgAspect > contAspect) {
                    displayedW = containerW; displayedH = containerW / imgAspect
                    offsetX = 0f;            offsetY = (containerH - displayedH) / 2f
                } else {
                    displayedH = containerH; displayedW = containerH * imgAspect
                    offsetX = (containerW - displayedW) / 2f; offsetY = 0f
                }
                val scaleX = bmp.width  / displayedW
                val scaleY = bmp.height / displayedH
                val sx = ((cropX - offsetX) * scaleX).toInt().coerceIn(0, bmp.width  - 1)
                val sy = ((cropY - offsetY) * scaleY).toInt().coerceIn(0, bmp.height - 1)
                val sw = (cropW * scaleX).toInt().coerceIn(1, bmp.width  - sx)
                val sh = (cropH * scaleY).toInt().coerceIn(1, bmp.height - sy)

                // ── Step 5: crop ──────────────────────────────────────────
                val cropped = Bitmap.createBitmap(bmp, sx, sy, sw, sh)
                bmp.recycle()

                // ── Step 6: encode to chosen format ───────────────────────
                val ext = when (outputFormat) {
                    OutputFormat.PNG                               -> "png"
                    OutputFormat.WEBP_LOSSY, OutputFormat.WEBP_LOSSLESS -> "webp"
                    else                                          -> "jpg"
                }
                val outDir  = File(activity!!.cacheDir, "cropper_output").also { it.mkdirs() }
                val outFile = File(outDir, "crop_${UUID.randomUUID()}.$ext")
                temporaryFiles.add(outFile)

                FileOutputStream(outFile).use { fos ->
                    val compressFormat = when (outputFormat) {
                        OutputFormat.PNG           -> Bitmap.CompressFormat.PNG
                        OutputFormat.WEBP_LOSSY    ->
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R)
                                Bitmap.CompressFormat.WEBP_LOSSY
                            else @Suppress("DEPRECATION") Bitmap.CompressFormat.WEBP
                        OutputFormat.WEBP_LOSSLESS ->
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R)
                                Bitmap.CompressFormat.WEBP_LOSSLESS
                            else @Suppress("DEPRECATION") Bitmap.CompressFormat.WEBP
                        else                       -> Bitmap.CompressFormat.JPEG
                    }
                    cropped.compress(compressFormat, quality, fos)
                }
                cropped.recycle()

                activity?.runOnUiThread { pendingResult?.success(outFile.absolutePath) }

            } catch (e: Exception) {
                Log.e(TAG, "cropImageNative error: ${e.message}")
                activity?.runOnUiThread { pendingResult?.error("CROP_FAILED", e.message, null) }
            }
        }.start()
    }

    // ─── ActivityAware ─────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    // ─── Document MIME types ───────────────────────────────────────────────

    private fun documentMimeTypes() = arrayOf(
        // PDF
        "application/pdf",
        // Word
        "application/msword",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        // Excel
        "application/vnd.ms-excel",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        // PowerPoint
        "application/vnd.ms-powerpoint",
        "application/vnd.openxmlformats-officedocument.presentationml.presentation",
        // Text / markup
        "text/plain", "text/rtf", "application/rtf",
        "text/markdown", "text/x-markdown",
        // OpenDocument
        "application/vnd.oasis.opendocument.text",
        "application/vnd.oasis.opendocument.spreadsheet",
        "application/vnd.oasis.opendocument.presentation",
        // eBook / other
        "application/epub+zip",
        "application/vnd.apple.pages",
        "application/vnd.apple.numbers",
        "application/vnd.apple.keynote",
        // Archives
        "application/zip", "application/x-zip-compressed",
        "application/x-rar-compressed", "application/x-7z-compressed",
        "application/x-tar", "application/gzip",
        // Web / data
        "text/html", "text/css",
        "text/javascript", "application/javascript",
        "application/json", "application/xml", "text/xml",
        "text/csv", "text/yaml", "application/x-yaml",
        // Code
        "application/x-httpd-php", "text/x-python",
        "text/x-c", "text/x-c++", "text/x-java-source",
        "text/x-shellscript", "application/x-sh",
        "application/x-perl", "text/x-ruby",
        // Images
        "image/jpeg", "image/png", "image/gif", "image/bmp",
        "image/tiff", "image/svg+xml", "image/webp",
        "image/heic", "image/heif", "image/avif",
        // Audio
        "audio/mpeg", "audio/wav", "audio/ogg",
        "audio/aac", "audio/x-aiff", "audio/flac",
        // Video
        "video/mp4", "video/mpeg", "video/webm",
        "video/ogg", "video/quicktime", "video/x-msvideo",
        // Fonts
        "font/otf", "font/ttf", "font/woff", "font/woff2",
        // Generic
        "application/octet-stream"
    )
}

// ─── Extension: output format enum ────────────────────────────────────────
// Mirrors the Dart CropOutputFormat enum sent as a String argument.
private enum class OutputFormat { JPEG, PNG, WEBP_LOSSY, WEBP_LOSSLESS }
