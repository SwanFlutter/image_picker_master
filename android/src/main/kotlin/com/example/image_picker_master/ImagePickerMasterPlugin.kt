package com.example.image_picker_master

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
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
import java.util.*

class ImagePickerMasterPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var result: Result? = null
    private var allowMultiple = false
    private var fileType = "all"
    private var allowedExtensions: List<String>? = null
    private var withData = false
    private var allowCompression = false
    private var compressionQuality = 80
    private val temporaryFiles = mutableListOf<File>()

    companion object {
        private const val REQUEST_CODE_PICK_FILE = 1001
        private const val REQUEST_CODE_PICK_IMAGE = 1002
        private const val REQUEST_CODE_CAPTURE_IMAGE = 1003
        private const val REQUEST_CODE_CAPTURE_VIDEO = 1004
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "image_picker_master")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        this.result = result

        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "pickFiles" -> {
                val arguments = call.arguments as Map<*, *>
                pickFiles(arguments)
            }
            "clearTemporaryFiles" -> {
                clearTemporaryFiles()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun pickFiles(arguments: Map<*, *>) {
        if (activity == null) {
            result?.error("NO_ACTIVITY", "Activity is null", null)
            return
        }

        fileType = arguments["type"] as? String ?: "all"
        allowMultiple = arguments["allowMultiple"] as? Boolean ?: false
        allowedExtensions = (arguments["allowedExtensions"] as? List<*>)?.filterIsInstance<String>()
        withData = arguments["withData"] as? Boolean ?: false
        allowCompression = arguments["allowCompression"] as? Boolean ?: false
        compressionQuality = arguments["compressionQuality"] as? Int ?: 80

        val intent = createPickIntent()

        try {
            activity?.startActivityForResult(intent, REQUEST_CODE_PICK_FILE)
        } catch (e: Exception) {
            result?.error("INTENT_ERROR", "Cannot start file picker: ${e.message}", null)
        }
    }

    private fun createPickIntent(): Intent {
        val intent = Intent(Intent.ACTION_GET_CONTENT)
        intent.addCategory(Intent.CATEGORY_OPENABLE)

        if (allowMultiple) {
            intent.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }

        when (fileType) {
            "image" -> {
                intent.type = "image/*"
            }
            "video" -> {
                intent.type = "video/*"
            }
            "audio" -> {
                intent.type = "audio/*"
            }
            "document" -> {
                intent.type = "*/*"
                val mimeTypes = arrayOf(
// PDF
"application/pdf",
// Microsoft Office - Word
"application/msword",
"application/vnd.openxmlformats-officedocument.wordprocessingml.document",
"application/vnd.ms-word.document.macroEnabled.12",
"application/vnd.ms-word.template.macroEnabled.12",
// Microsoft Office - Excel
"application/vnd.ms-excel",
"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
"application/vnd.ms-excel.sheet.macroEnabled.12",
"application/vnd.ms-excel.template.macroEnabled.12",
"application/vnd.ms-excel.addin.macroEnabled.12",
"application/vnd.ms-excel.sheet.binary.macroEnabled.12",
// Microsoft Office - PowerPoint
"application/vnd.ms-powerpoint",
"application/vnd.openxmlformats-officedocument.presentationml.presentation",
"application/vnd.ms-powerpoint.presentation.macroEnabled.12",
"application/vnd.ms-powerpoint.template.macroEnabled.12",
"application/vnd.ms-powerpoint.slideshow.macroEnabled.12",
"application/vnd.ms-powerpoint.addin.macroEnabled.12",
// Text files
"text/plain",
"text/rtf",
"application/rtf",
"text/markdown",
"text/x-markdown",
"text/x-log",
"text/x-script",
// OpenDocument formats
"application/vnd.oasis.opendocument.text",
"application/vnd.oasis.opendocument.spreadsheet",
"application/vnd.oasis.opendocument.presentation",
"application/vnd.oasis.opendocument.graphics",
"application/vnd.oasis.opendocument.formula",
// Other document formats
"application/vnd.google-apps.document",
"application/vnd.google-apps.spreadsheet",
"application/vnd.google-apps.presentation",
"application/epub+zip",
"application/x-iwork-pages-sffpages",
"application/x-iwork-numbers-sffnumbers",
"application/x-iwork-keynote-sffkey",
"application/vnd.lotus-wordpro",
"application/vnd.lotus-organizer",
"application/vnd.lotus-screencam",
"application/vnd.lotus-approach",
"application/vnd.apple.pages",
"application/vnd.apple.numbers",
"application/vnd.apple.keynote",
"application/x-abiword",
// Archive formats
"application/zip",
"application/x-zip-compressed",
"application/x-rar-compressed",
"application/x-7z-compressed",
"application/x-tar",
"application/gzip",
"application/x-gzip",
"application/x-bzip",
"application/x-bzip2",
"application/x-freearc",
"application/x-lzip",
"application/x-lzma",
"application/x-xz",
"application/x-compress",
"application/x-apple-diskimage",
// Code files
"text/html",
"text/css",
"text/javascript",
"application/javascript",
"application/json",
"application/xml",
"text/xml",
"text/csv",
"application/x-httpd-php",
"text/x-python",
"application/x-python-code",
"text/x-c",
"text/x-c++",
"text/x-java-source",
"application/ecmascript",
"text/x-shellscript",
"application/x-sh",
"application/x-perl",
"text/x-ruby",
"application/x-ruby",
"text/x-lua",
"application/x-lua",
"text/yaml",
"application/x-yaml",
// Image formats
"image/jpeg",
"image/png",
"image/gif",
"image/bmp",
"image/tiff",
"image/svg+xml",
"image/webp",
"image/x-icon",
"image/vnd.microsoft.icon",
"image/heic",
"image/heif",
"image/avif",
"image/apng",
"image/x-xbitmap",
"image/x-portable-bitmap",
"image/x-portable-graymap",
"image/x-portable-pixmap",
// Audio formats
"audio/mpeg",
"audio/wav",
"audio/x-wav",
"audio/ogg",
"audio/aac",
"audio/midi",
"audio/x-midi",
"audio/webm",
"audio/opus",
"audio/x-aiff",
"audio/basic",
// Video formats
"video/mp4",
"video/mpeg",
"video/webm",
"video/ogg",
"video/quicktime",
"video/x-msvideo",
"video/x-flv",
"video/x-m4v",
"video/x-ms-wmv",
"video/x-ms-asf",
"video/3gpp",
"video/3gpp2",
// Font formats
"font/otf",
"font/ttf",
"font/woff",
"font/woff2",
"application/vnd.ms-fontobject",
"application/font-woff",
// Other common formats
"application/octet-stream",
"application/x-shockwave-flash",
"application/x-www-form-urlencoded",
"multipart/form-data",
"application/x-msdownload",
"application/x-font-ttf",
"application/x-font-otf",
"application/x-font-woff",
"application/vnd.amazon.ebook",
"application/vnd.apple.installer+xml",
"application/vnd.mozilla.xul+xml",
"application/x-x509-ca-cert",
"application/pkix-cert",
"application/x-pkcs12",
"application/x-pkcs7-certificates",
"application/x-silverlight-app",
"application/x-director",
"application/x-dvi",
"application/x-latex",
"application/x-tex",
"application/x-troff",
"application/x-troff-man",
"application/x-troff-me",
"application/x-troff-ms",
"application/x-www-form-urlencoded",
"message/rfc822",
"model/gltf+json",
"model/gltf-binary",
"model/obj",
"model/stl"
)
                intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
            }
            "custom" -> {
                if (!allowedExtensions.isNullOrEmpty()) {
                    val mimeTypes = allowedExtensions?.mapNotNull { ext ->
                        MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext.lowercase())
                    }?.toTypedArray()

                    if (!mimeTypes.isNullOrEmpty()) {
                        intent.type = "*/*"
                        intent.putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
                    } else {
                        intent.type = "*/*"
                    }
                } else {
                    intent.type = "*/*"
                }
            }
            else -> {
                intent.type = "*/*"
            }
        }

        return Intent.createChooser(intent, "Select File")
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_FILE || resultCode != Activity.RESULT_OK || data == null) {
            result?.success(null)
            return true
        }

        try {
            val selectedFiles = mutableListOf<Map<String, Any?>>()

            if (data.clipData != null) {
                // Multiple files selected
                for (i in 0 until data.clipData!!.itemCount) {
                    val uri = data.clipData!!.getItemAt(i).uri
                    processSelectedFile(uri)?.let { selectedFiles.add(it) }
                }
            } else if (data.data != null) {
                // Single file selected
                processSelectedFile(data.data!!)?.let { selectedFiles.add(it) }
            }

            result?.success(selectedFiles)
        } catch (e: Exception) {
            result?.error("PROCESSING_ERROR", "Error processing selected files: ${e.message}", null)
        }

        return true
    }

    private fun processSelectedFile(uri: Uri): Map<String, Any?>? {
        return try {
            val contentResolver = activity?.contentResolver ?: return null
            val fileName = getFileName(contentResolver, uri)
            val fileSize = getFileSize(contentResolver, uri)
            val mimeType = contentResolver.getType(uri)

            // Copy file to temporary location
            val tempFile = createTempFile(fileName, uri)
            val filePath = tempFile.absolutePath

            val fileData = mutableMapOf<String, Any?>()
            fileData["path"] = filePath
            fileData["name"] = fileName
            fileData["size"] = fileSize
            fileData["mimeType"] = mimeType

            if (withData) {
                var bytes = getFileBytes(contentResolver, uri)

                // Apply compression if needed for images
                if (allowCompression && mimeType?.startsWith("image/") == true) {
                    bytes = compressImageBytes(bytes, compressionQuality)
                }

                fileData["bytes"] = bytes
            }

            fileData
        } catch (e: Exception) {
            null
        }
    }

    private fun createTempFile(fileName: String, uri: Uri): File {
        val tempDir = File(activity?.cacheDir, "file_picker")
        if (!tempDir.exists()) {
            tempDir.mkdirs()
        }

        val tempFile = File(tempDir, "${UUID.randomUUID()}_$fileName")
        temporaryFiles.add(tempFile)

        activity?.contentResolver?.openInputStream(uri)?.use { input ->
            tempFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }

        return tempFile
    }

    private fun getFileName(contentResolver: ContentResolver, uri: Uri): String {
        var fileName = "unknown"

        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val displayNameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (displayNameIndex != -1) {
                    fileName = cursor.getString(displayNameIndex) ?: "unknown"
                }
            }
        }

        return fileName
    }

    private fun getFileSize(contentResolver: ContentResolver, uri: Uri): Long {
        var fileSize = 0L

        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex != -1) {
                    fileSize = cursor.getLong(sizeIndex)
                }
            }
        }

        return fileSize
    }

    private fun getFileBytes(contentResolver: ContentResolver, uri: Uri): ByteArray {
        return contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: byteArrayOf()
    }

    private fun compressImageBytes(originalBytes: ByteArray, quality: Int): ByteArray {
        return try {
            val bitmap = BitmapFactory.decodeByteArray(originalBytes, 0, originalBytes.size)
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, quality, outputStream)
            outputStream.toByteArray()
        } catch (e: Exception) {
            originalBytes
        }
    }

    private fun clearTemporaryFiles() {
        temporaryFiles.forEach { file ->
            try {
                if (file.exists()) {
                    file.delete()
                }
            } catch (e: Exception) {
                // Ignore deletion errors
            }
        }
        temporaryFiles.clear()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        clearTemporaryFiles()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }
}
