# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.

# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Keep Flutter plugin classes
-keep class com.example.image_picker_master.** { *; }

# Keep method channel names
-keepclassmembers class com.example.image_picker_master.ImagePickerMasterPlugin {
    public *;
}

# Keep Android content resolver and file provider classes
-keep class androidx.core.content.FileProvider { *; }
-keep class android.provider.MediaStore { *; }
-keep class android.content.ContentResolver { *; }

# Keep bitmap and image processing classes
-keep class android.graphics.Bitmap { *; }
-keep class android.graphics.BitmapFactory { *; }
