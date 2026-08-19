#include "include/image_picker_master/image_picker_master_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>
#include <glib.h>
#include <gio/gio.h>
#include <gdk-pixbuf/gdk-pixbuf.h>

#include <cstring>
#include <memory>
#include <vector>
#include <string>
#include <fstream>
#include <sstream>
#include <iostream>
#include <algorithm>
#include <filesystem>

#include "image_picker_master_plugin_private.h"

#define IMAGE_PICKER_MASTER_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), image_picker_master_plugin_get_type(), \
                              ImagePickerMasterPlugin))

struct _ImagePickerMasterPlugin {
  GObject parent_instance;
  std::vector<std::string>* temporary_files;
};

G_DEFINE_TYPE(ImagePickerMasterPlugin, image_picker_master_plugin, g_object_get_type())

// ─── Forward declarations ──────────────────────────────────────────────────

static std::vector<uint8_t> read_file_bytes(const std::string& file_path);
static bool is_image_file(const std::string& file_path);
static std::string get_file_extension(const std::string& file_path);
static std::string create_temp_file_path(const std::string& extension);
static bool compress_image(const std::string& input_path,
                           const std::string& output_path,
                           int quality);
static void cleanup_temp_files(ImagePickerMasterPlugin* self);
static FlMethodResponse* create_error_response(const std::string& code,
                                               const std::string& message);
static std::string get_mime_type(const std::string& file_path);
static FlValue* build_file_map(const std::string& file_path,
                               bool with_data,
                               bool allow_compression,
                               int compression_quality,
                               ImagePickerMasterPlugin* self);

// Method handlers
static FlMethodResponse* handle_pick_files(FlValue* arguments,
                                           ImagePickerMasterPlugin* self);
static FlMethodResponse* handle_capture_photo(FlValue* arguments,
                                              ImagePickerMasterPlugin* self);
static FlMethodResponse* handle_clear_temporary_files(ImagePickerMasterPlugin* self);
static FlMethodResponse* handle_resize_image_for_cropper(FlValue* arguments,
                                                         ImagePickerMasterPlugin* self);
static FlMethodResponse* handle_crop_image_native(FlValue* arguments,
                                                   ImagePickerMasterPlugin* self);

// ─── Method dispatch ───────────────────────────────────────────────────────

static void image_picker_master_plugin_handle_method_call(
    ImagePickerMasterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* arguments   = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "pickFiles") == 0) {
    response = handle_pick_files(arguments, self);
  } else if (strcmp(method, "capturePhoto") == 0) {
    response = handle_capture_photo(arguments, self);
  } else if (strcmp(method, "clearTemporaryFiles") == 0) {
    response = handle_clear_temporary_files(self);
  } else if (strcmp(method, "resizeImageForCropper") == 0) {
    response = handle_resize_image_for_cropper(arguments, self);
  } else if (strcmp(method, "cropImageNative") == 0) {
    response = handle_crop_image_native(arguments, self);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

// ─── getPlatformVersion ────────────────────────────────────────────────────

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar* version =
      g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

// ─── clearTemporaryFiles ───────────────────────────────────────────────────

static FlMethodResponse* handle_clear_temporary_files(ImagePickerMasterPlugin* self) {
  cleanup_temp_files(self);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
}

// ─── pickFiles ─────────────────────────────────────────────────────────────

static FlMethodResponse* handle_pick_files(FlValue* arguments,
                                           ImagePickerMasterPlugin* self) {
  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return create_error_response("INVALID_ARGUMENTS", "Arguments must be a map");
  }

  // ── Parse arguments ──
  FlValue* file_type_value        = fl_value_lookup_string(arguments, "type");
  FlValue* allow_multiple_value   = fl_value_lookup_string(arguments, "allowMultiple");
  FlValue* allowed_ext_value      = fl_value_lookup_string(arguments, "allowedExtensions");
  FlValue* with_data_value        = fl_value_lookup_string(arguments, "withData");
  FlValue* allow_comp_value       = fl_value_lookup_string(arguments, "allowCompression");
  FlValue* comp_quality_value     = fl_value_lookup_string(arguments, "compressionQuality");

  std::string file_type = "all";
  if (file_type_value &&
      fl_value_get_type(file_type_value) == FL_VALUE_TYPE_STRING) {
    file_type = fl_value_get_string(file_type_value);
  }

  bool allow_multiple = false;
  if (allow_multiple_value &&
      fl_value_get_type(allow_multiple_value) == FL_VALUE_TYPE_BOOL) {
    allow_multiple = fl_value_get_bool(allow_multiple_value);
  }

  std::vector<std::string> allowed_extensions;
  if (allowed_ext_value &&
      fl_value_get_type(allowed_ext_value) == FL_VALUE_TYPE_LIST) {
    size_t length = fl_value_get_length(allowed_ext_value);
    for (size_t i = 0; i < length; i++) {
      FlValue* ext = fl_value_get_list_value(allowed_ext_value, i);
      if (fl_value_get_type(ext) == FL_VALUE_TYPE_STRING) {
        allowed_extensions.push_back(fl_value_get_string(ext));
      }
    }
  }

  bool with_data = false;
  if (with_data_value &&
      fl_value_get_type(with_data_value) == FL_VALUE_TYPE_BOOL) {
    with_data = fl_value_get_bool(with_data_value);
  }

  bool allow_compression = false;
  if (allow_comp_value &&
      fl_value_get_type(allow_comp_value) == FL_VALUE_TYPE_BOOL) {
    allow_compression = fl_value_get_bool(allow_comp_value);
  }

  // Dart default is 80; align with that
  int compression_quality = 80;
  if (comp_quality_value &&
      fl_value_get_type(comp_quality_value) == FL_VALUE_TYPE_INT) {
    compression_quality = static_cast<int>(fl_value_get_int(comp_quality_value));
  }

  // ── Build GTK file-chooser ──
  GtkWidget* dialog = gtk_file_chooser_dialog_new(
      "Select Files",
      nullptr,
      GTK_FILE_CHOOSER_ACTION_OPEN,
      "_Cancel", GTK_RESPONSE_CANCEL,
      "_Open",   GTK_RESPONSE_ACCEPT,
      nullptr);

  gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(dialog), allow_multiple);

  // ── File filters ──
  auto add_mime_filter = [&](const gchar* label, const gchar* mime) {
    GtkFileFilter* f = gtk_file_filter_new();
    gtk_file_filter_set_name(f, label);
    gtk_file_filter_add_mime_type(f, mime);
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), f);
  };

  if (file_type == "image") {
    add_mime_filter("Images", "image/*");

  } else if (file_type == "video") {
    add_mime_filter("Videos", "video/*");

  } else if (file_type == "audio") {
    add_mime_filter("Audio", "audio/*");

  } else if (file_type == "document") {
    GtkFileFilter* f = gtk_file_filter_new();
    gtk_file_filter_set_name(f, "Documents");
    // PDF
    gtk_file_filter_add_pattern(f, "*.pdf");
    // Microsoft Office
    gtk_file_filter_add_pattern(f, "*.doc");
    gtk_file_filter_add_pattern(f, "*.docx");
    gtk_file_filter_add_pattern(f, "*.xls");
    gtk_file_filter_add_pattern(f, "*.xlsx");
    gtk_file_filter_add_pattern(f, "*.ppt");
    gtk_file_filter_add_pattern(f, "*.pptx");
    // Text / markup
    gtk_file_filter_add_pattern(f, "*.txt");
    gtk_file_filter_add_pattern(f, "*.rtf");
    gtk_file_filter_add_pattern(f, "*.md");
    gtk_file_filter_add_pattern(f, "*.markdown");
    // OpenDocument
    gtk_file_filter_add_pattern(f, "*.odt");
    gtk_file_filter_add_pattern(f, "*.ods");
    gtk_file_filter_add_pattern(f, "*.odp");
    // Web / data
    gtk_file_filter_add_pattern(f, "*.html");
    gtk_file_filter_add_pattern(f, "*.htm");
    gtk_file_filter_add_pattern(f, "*.css");
    gtk_file_filter_add_pattern(f, "*.js");
    gtk_file_filter_add_pattern(f, "*.json");
    gtk_file_filter_add_pattern(f, "*.xml");
    gtk_file_filter_add_pattern(f, "*.csv");
    gtk_file_filter_add_pattern(f, "*.yaml");
    gtk_file_filter_add_pattern(f, "*.yml");
    // Code
    gtk_file_filter_add_pattern(f, "*.php");
    gtk_file_filter_add_pattern(f, "*.py");
    gtk_file_filter_add_pattern(f, "*.c");
    gtk_file_filter_add_pattern(f, "*.cpp");
    gtk_file_filter_add_pattern(f, "*.java");
    gtk_file_filter_add_pattern(f, "*.sh");
    gtk_file_filter_add_pattern(f, "*.pl");
    gtk_file_filter_add_pattern(f, "*.rb");
    gtk_file_filter_add_pattern(f, "*.lua");
    // Archives
    gtk_file_filter_add_pattern(f, "*.zip");
    gtk_file_filter_add_pattern(f, "*.rar");
    gtk_file_filter_add_pattern(f, "*.7z");
    gtk_file_filter_add_pattern(f, "*.tar");
    gtk_file_filter_add_pattern(f, "*.gz");
    gtk_file_filter_add_pattern(f, "*.bz2");
    // Fonts
    gtk_file_filter_add_pattern(f, "*.ttf");
    gtk_file_filter_add_pattern(f, "*.otf");
    gtk_file_filter_add_pattern(f, "*.woff");
    gtk_file_filter_add_pattern(f, "*.woff2");
    // eBook
    gtk_file_filter_add_pattern(f, "*.epub");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), f);

  } else if (file_type == "custom") {
    if (allowed_extensions.empty()) {
      gtk_widget_destroy(dialog);
      return create_error_response(
          "INVALID_ARGUMENTS",
          "FileType.custom requires at least one allowedExtension");
    }
    GtkFileFilter* f = gtk_file_filter_new();
    gtk_file_filter_set_name(f, "Allowed Files");
    for (const auto& ext : allowed_extensions) {
      std::string pattern = "*." + ext;
      gtk_file_filter_add_pattern(f, pattern.c_str());
    }
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), f);

  }
  // "all" → no filter added; GTK shows every file by default

  // ── Run dialog ──
  gint run_result = gtk_dialog_run(GTK_DIALOG(dialog));

  if (run_result != GTK_RESPONSE_ACCEPT) {
    gtk_widget_destroy(dialog);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  GSList* filenames = gtk_file_chooser_get_filenames(GTK_FILE_CHOOSER(dialog));
  gtk_widget_destroy(dialog);

  g_autoptr(FlValue) files_list = fl_value_new_list();

  for (GSList* l = filenames; l != nullptr; l = l->next) {
    gchar* filename = static_cast<gchar*>(l->data);
    std::string file_path(filename);
    g_free(filename);

    FlValue* file_map = build_file_map(
        file_path, with_data, allow_compression, compression_quality, self);
    if (file_map) {
      fl_value_append_take(files_list, file_map);
    }
  }
  g_slist_free(filenames);

  // Return null if nothing was collected (e.g. all files failed to process)
  if (fl_value_get_length(files_list) == 0) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(files_list));
}

// ─── capturePhoto ──────────────────────────────────────────────────────────
// Linux has no standard camera API. We fall back to a file-picker limited to
// images and return a single PickedFile map (not a list) to match the Dart
// capturePhoto() contract. This mirrors the macOS/Windows behaviour where
// camera capture is not always available.

static FlMethodResponse* handle_capture_photo(FlValue* arguments,
                                              ImagePickerMasterPlugin* self) {
  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return create_error_response("INVALID_ARGUMENTS", "Arguments must be a map");
  }

  FlValue* allow_comp_value   = fl_value_lookup_string(arguments, "allowCompression");
  FlValue* comp_quality_value = fl_value_lookup_string(arguments, "compressionQuality");
  FlValue* with_data_value    = fl_value_lookup_string(arguments, "withData");

  bool allow_compression = true;
  if (allow_comp_value &&
      fl_value_get_type(allow_comp_value) == FL_VALUE_TYPE_BOOL) {
    allow_compression = fl_value_get_bool(allow_comp_value);
  }

  int compression_quality = 80;
  if (comp_quality_value &&
      fl_value_get_type(comp_quality_value) == FL_VALUE_TYPE_INT) {
    compression_quality = static_cast<int>(fl_value_get_int(comp_quality_value));
  }

  bool with_data = false;
  if (with_data_value &&
      fl_value_get_type(with_data_value) == FL_VALUE_TYPE_BOOL) {
    with_data = fl_value_get_bool(with_data_value);
  }

  // Open image-only file picker as camera fallback
  GtkWidget* dialog = gtk_file_chooser_dialog_new(
      "Select a Photo",
      nullptr,
      GTK_FILE_CHOOSER_ACTION_OPEN,
      "_Cancel", GTK_RESPONSE_CANCEL,
      "_Open",   GTK_RESPONSE_ACCEPT,
      nullptr);

  gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(dialog), FALSE);

  GtkFileFilter* f = gtk_file_filter_new();
  gtk_file_filter_set_name(f, "Images");
  gtk_file_filter_add_mime_type(f, "image/*");
  gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), f);

  gint run_result = gtk_dialog_run(GTK_DIALOG(dialog));

  if (run_result != GTK_RESPONSE_ACCEPT) {
    gtk_widget_destroy(dialog);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  gchar* filename = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(dialog));
  gtk_widget_destroy(dialog);

  if (!filename) {
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }

  std::string file_path(filename);
  g_free(filename);

  // Build single map — capturePhoto returns Map, not List
  FlValue* file_map = build_file_map(
      file_path, with_data, allow_compression, compression_quality, self);
  if (!file_map) {
    return create_error_response("FILE_PROCESSING_ERROR",
                                 "Failed to process the selected file");
  }

  return FL_METHOD_RESPONSE(fl_method_success_response_new(file_map));
}

// ─── build_file_map ────────────────────────────────────────────────────────
// Constructs the map returned to Dart's PickedFile.fromMap().
// Keys: path, name, size, mimeType, bytes (Uint8List when withData=true).

static FlValue* build_file_map(const std::string& file_path,
                               bool with_data,
                               bool allow_compression,
                               int compression_quality,
                               ImagePickerMasterPlugin* self) {
  // Resolve the actual path to read from (may be a compressed copy)
  std::string read_path = file_path;

  if (allow_compression && is_image_file(file_path)) {
    std::string temp_path = create_temp_file_path("jpg");
    if (compress_image(file_path, temp_path, compression_quality)) {
      // Track the temp file for later cleanup
      self->temporary_files->push_back(temp_path);
      read_path = temp_path;
    }
  }

  // File name
  std::filesystem::path fs_path(read_path);
  std::string name = fs_path.filename().string();

  // File size
  int64_t file_size = 0;
  try {
    file_size = static_cast<int64_t>(std::filesystem::file_size(read_path));
  } catch (...) {
    file_size = 0;
  }

  // MIME type via GLib content-type detection
  std::string mime_type = get_mime_type(read_path);

  FlValue* file_map = fl_value_new_map();
  fl_value_set_string_take(file_map, "path",
      fl_value_new_string(read_path.c_str()));
  fl_value_set_string_take(file_map, "name",
      fl_value_new_string(name.c_str()));
  fl_value_set_string_take(file_map, "size",
      fl_value_new_int(file_size));
  fl_value_set_string_take(file_map, "mimeType",
      mime_type.empty()
          ? fl_value_new_null()
          : fl_value_new_string(mime_type.c_str()));

  if (with_data) {
    try {
      std::vector<uint8_t> bytes = read_file_bytes(read_path);
      // Send as Uint8List — Flutter StandardMethodCodec deserialises this
      // directly to Dart Uint8List, matching PickedFile.bytes type.
      fl_value_set_string_take(file_map, "bytes",
          fl_value_new_uint8_list(bytes.data(), bytes.size()));
    } catch (...) {
      fl_value_set_string_take(file_map, "bytes", fl_value_new_null());
    }
  } else {
    fl_value_set_string_take(file_map, "bytes", fl_value_new_null());
  }

  return file_map;
}

// ─── Helpers ───────────────────────────────────────────────────────────────

static std::string get_mime_type(const std::string& file_path) {
  gboolean uncertain = FALSE;
  gchar* content_type =
      g_content_type_guess(file_path.c_str(), nullptr, 0, &uncertain);
  if (!content_type) return "";

  gchar* mime = g_content_type_get_mime_type(content_type);
  g_free(content_type);

  if (!mime) return "";

  std::string result(mime);
  g_free(mime);
  return result;
}

static std::vector<uint8_t> read_file_bytes(const std::string& file_path) {
  std::ifstream file(file_path, std::ios::binary);
  if (!file) throw std::runtime_error("Cannot open file: " + file_path);

  file.seekg(0, std::ios::end);
  auto size = static_cast<size_t>(file.tellg());
  file.seekg(0, std::ios::beg);

  std::vector<uint8_t> data(size);
  file.read(reinterpret_cast<char*>(data.data()), static_cast<std::streamsize>(size));
  return data;
}

static bool is_image_file(const std::string& file_path) {
  std::string ext = get_file_extension(file_path);
  std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
  return ext == "jpg"  || ext == "jpeg" || ext == "png"  ||
         ext == "gif"  || ext == "bmp"  || ext == "webp" ||
         ext == "tiff" || ext == "tif"  || ext == "heic" ||
         ext == "heif" || ext == "avif";
}

static std::string get_file_extension(const std::string& file_path) {
  size_t dot = file_path.find_last_of('.');
  if (dot == std::string::npos) return "";
  std::string ext = file_path.substr(dot + 1);
  std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
  return ext;
}

// ─── resizeImageForCropper ─────────────────────────────────────────────────
// Uses gdk-pixbuf for fast native resize. gdk_pixbuf_scale_simple with
// GDK_INTERP_BILINEAR is implemented in C and orders of magnitude faster
// than pure-Dart decode. Result is written to /tmp/cropper_preview/.

static FlMethodResponse* handle_resize_image_for_cropper(
    FlValue* arguments,
    ImagePickerMasterPlugin* self) {

  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return create_error_response("INVALID_ARGUMENTS", "Arguments must be a map");
  }

  FlValue* path_value    = fl_value_lookup_string(arguments, "path");
  FlValue* maxsize_value = fl_value_lookup_string(arguments, "maxSize");

  if (!path_value || fl_value_get_type(path_value) != FL_VALUE_TYPE_STRING) {
    return create_error_response("INVALID_ARGUMENTS", "path is required");
  }

  std::string file_path = fl_value_get_string(path_value);
  int max_size = 1024;
  if (maxsize_value && fl_value_get_type(maxsize_value) == FL_VALUE_TYPE_INT) {
    max_size = static_cast<int>(fl_value_get_int(maxsize_value));
  }

  // ── Step 1: load source via gdk-pixbuf ────────────────────────────────
  GError* error = nullptr;
  GdkPixbuf* src = gdk_pixbuf_new_from_file(file_path.c_str(), &error);
  if (!src) {
    if (error) g_error_free(error);
    // Fallback — return original path so the cropper still works
    return FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(file_path.c_str())));
  }

  int orig_w = gdk_pixbuf_get_width(src);
  int orig_h = gdk_pixbuf_get_height(src);

  // Already fits — return original path immediately
  if (orig_w <= max_size && orig_h <= max_size) {
    g_object_unref(src);
    return FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(file_path.c_str())));
  }

  // ── Step 2: compute target size (preserve aspect ratio) ───────────────
  int larger = std::max(orig_w, orig_h);
  int new_w  = static_cast<int>(orig_w * static_cast<double>(max_size) / larger);
  int new_h  = static_cast<int>(orig_h * static_cast<double>(max_size) / larger);

  // ── Step 3: scale with bilinear interpolation (native C, fast) ────────
  GdkPixbuf* scaled = gdk_pixbuf_scale_simple(
      src, new_w, new_h, GDK_INTERP_BILINEAR);
  g_object_unref(src);

  if (!scaled) {
    return FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(file_path.c_str())));
  }

  // ── Step 4: write to /tmp/cropper_preview/ ────────────────────────────
  const gchar* tmp_dir = g_get_tmp_dir();
  g_autofree gchar* out_dir = g_strdup_printf("%s/cropper_preview", tmp_dir);
  g_mkdir_with_parents(out_dir, 0700);

  g_autofree gchar* out_path = g_strdup_printf(
      "%s/preview_%" G_GUINT32_FORMAT ".jpg", out_dir, g_random_int());

  g_autofree gchar* quality_str = g_strdup_printf("85");
  gboolean ok = gdk_pixbuf_save(
      scaled, out_path, "jpeg", &error, "quality", quality_str, nullptr);
  g_object_unref(scaled);

  if (!ok || error) {
    if (error) g_error_free(error);
    return FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(file_path.c_str())));
  }

  // Track for cleanup
  self->temporary_files->push_back(std::string(out_path));

  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_string(out_path)));
}

// ─── cropImageNative ──────────────────────────────────────────────────────
// Full native crop+encode using gdk-pixbuf.
// format: "jpeg" | "png" | "webp_lossy" | "webp_lossless"
// gdk-pixbuf has no WebP saver — webp_* fall back to JPEG.

static FlMethodResponse* handle_crop_image_native(FlValue* arguments,
                                                   ImagePickerMasterPlugin* self) {
  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return create_error_response("INVALID_ARGUMENTS", "Arguments must be a map");
  }

  auto get_str = [&](const char* key, std::string def = "") -> std::string {
    FlValue* v = fl_value_lookup_string(arguments, key);
    if (v && fl_value_get_type(v) == FL_VALUE_TYPE_STRING) return fl_value_get_string(v);
    return def;
  };
  auto get_dbl = [&](const char* key, double def = 0.0) -> double {
    FlValue* v = fl_value_lookup_string(arguments, key);
    if (!v) return def;
    if (fl_value_get_type(v) == FL_VALUE_TYPE_FLOAT) return fl_value_get_float(v);
    if (fl_value_get_type(v) == FL_VALUE_TYPE_INT)   return static_cast<double>(fl_value_get_int(v));
    return def;
  };
  auto get_int = [&](const char* key, int def = 0) -> int {
    FlValue* v = fl_value_lookup_string(arguments, key);
    if (v && fl_value_get_type(v) == FL_VALUE_TYPE_INT) return static_cast<int>(fl_value_get_int(v));
    return def;
  };

  std::string file_path = get_str("path");
  if (file_path.empty())
    return create_error_response("INVALID_ARGUMENTS", "path is required");

  std::string format   = get_str("format", "jpeg");
  double crop_x        = get_dbl("cropX");
  double crop_y        = get_dbl("cropY");
  double crop_w        = get_dbl("cropW",  1);
  double crop_h        = get_dbl("cropH",  1);
  double container_w   = get_dbl("containerW", 1);
  double container_h   = get_dbl("containerH", 1);
  int    rotation      = get_int("rotation");
  int    quality       = get_int("quality", 85);
  int    max_size      = get_int("maxSize",  1200);

  // ── Step 1: load source ──────────────────────────────────────────────
  GError* err = nullptr;
  GdkPixbuf* src = gdk_pixbuf_new_from_file(file_path.c_str(), &err);
  if (!src) {
    if (err) g_error_free(err);
    return create_error_response("DECODE_FAILED", "Cannot decode image");
  }

  int origW = gdk_pixbuf_get_width(src);
  int origH = gdk_pixbuf_get_height(src);

  // ── Step 2: downscale to maxSize ────────────────────────────────────
  int larger = std::max(origW, origH);
  if (larger > max_size) {
    double scale = static_cast<double>(max_size) / larger;
    int nw = static_cast<int>(origW * scale);
    int nh = static_cast<int>(origH * scale);
    GdkPixbuf* scaled = gdk_pixbuf_scale_simple(src, nw, nh, GDK_INTERP_BILINEAR);
    g_object_unref(src);
    src   = scaled;
    origW = nw; origH = nh;
  }

  // ── Step 3: rotation ────────────────────────────────────────────────
  if (rotation != 0) {
    GdkPixbufRotation rot = GDK_PIXBUF_ROTATE_NONE;
    if (rotation == 90)  rot = GDK_PIXBUF_ROTATE_COUNTERCLOCKWISE; // gdk is CCW
    if (rotation == 180) rot = GDK_PIXBUF_ROTATE_UPSIDEDOWN;
    if (rotation == 270) rot = GDK_PIXBUF_ROTATE_CLOCKWISE;
    GdkPixbuf* rotated = gdk_pixbuf_rotate_simple(src, rot);
    g_object_unref(src);
    src   = rotated;
    origW = gdk_pixbuf_get_width(src);
    origH = gdk_pixbuf_get_height(src);
  }

  // ── Step 4: map crop rect → pixel coords ────────────────────────────
  double img_a = static_cast<double>(origW) / origH;
  double con_a = container_w / container_h;
  double dw, dh, ox, oy;
  if (img_a > con_a) { dw = container_w; dh = dw / img_a; ox = 0; oy = (container_h - dh) / 2; }
  else               { dh = container_h; dw = dh * img_a; oy = 0; ox = (container_w - dw) / 2; }
  int sx = static_cast<int>((crop_x - ox) * origW / dw);
  int sy = static_cast<int>((crop_y - oy) * origH / dh);
  int sw = static_cast<int>( crop_w       * origW / dw);
  int sh = static_cast<int>( crop_h       * origH / dh);
  sx = std::max(0, std::min(sx, origW - 1));
  sy = std::max(0, std::min(sy, origH - 1));
  sw = std::max(1, std::min(sw, origW - sx));
  sh = std::max(1, std::min(sh, origH - sy));

  // ── Step 5: crop ────────────────────────────────────────────────────
  GdkPixbuf* cropped = gdk_pixbuf_new_subpixbuf(src, sx, sy, sw, sh);
  g_object_unref(src);
  if (!cropped)
    return create_error_response("CROP_FAILED", "Subpixbuf failed");

  // ── Step 6: encode ───────────────────────────────────────────────────
  bool use_png = (format == "png");
  const gchar* saver = use_png ? "png" : "jpeg";
  std::string ext    = use_png ? "png" : "jpg";

  const gchar* tmp_dir = g_get_tmp_dir();
  g_autofree gchar* out_dir = g_strdup_printf("%s/cropper_output", tmp_dir);
  g_mkdir_with_parents(out_dir, 0700);
  g_autofree gchar* out_path = g_strdup_printf(
      "%s/crop_%" G_GUINT32_FORMAT ".%s", out_dir, g_random_int(), ext.c_str());

  gboolean ok;
  if (use_png) {
    ok = gdk_pixbuf_save(cropped, out_path, saver, &err, nullptr);
  } else {
    g_autofree gchar* q_str = g_strdup_printf("%d", quality);
    ok = gdk_pixbuf_save(cropped, out_path, saver, &err, "quality", q_str, nullptr);
  }
  g_object_unref(cropped);

  if (!ok || err) {
    if (err) g_error_free(err);
    return create_error_response("ENCODE_FAILED", "Failed to save cropped image");
  }

  self->temporary_files->push_back(std::string(out_path));
  return FL_METHOD_RESPONSE(
      fl_method_success_response_new(fl_value_new_string(out_path)));
}

static std::string create_temp_file_path(const std::string& extension) {
  const gchar* temp_dir = g_get_tmp_dir();
  g_autofree gchar* temp_file = g_strdup_printf(
      "%s/flutter_image_picker_%" G_GUINT32_FORMAT ".%s",
      temp_dir, g_random_int(), extension.c_str());
  return std::string(temp_file);
}

static bool compress_image(const std::string& input_path,
                           const std::string& output_path,
                           int quality) {
  GError* error = nullptr;
  GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file(input_path.c_str(), &error);
  if (!pixbuf) {
    if (error) g_error_free(error);
    return false;
  }

  g_autofree gchar* quality_str = g_strdup_printf("%d", quality);
  gboolean ok = gdk_pixbuf_save(
      pixbuf, output_path.c_str(), "jpeg", &error,
      "quality", quality_str, nullptr);

  g_object_unref(pixbuf);
  if (error) g_error_free(error);
  return ok == TRUE;
}

static void cleanup_temp_files(ImagePickerMasterPlugin* self) {
  if (!self->temporary_files) return;
  for (const auto& path : *self->temporary_files) {
    std::error_code ec;
    std::filesystem::remove(path, ec);  // ignore errors
  }
  self->temporary_files->clear();
}

static FlMethodResponse* create_error_response(const std::string& code,
                                               const std::string& message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code.c_str(), message.c_str(), nullptr));
}

// ─── GObject boilerplate ───────────────────────────────────────────────────

static void image_picker_master_plugin_dispose(GObject* object) {
  ImagePickerMasterPlugin* self = IMAGE_PICKER_MASTER_PLUGIN(object);
  cleanup_temp_files(self);
  delete self->temporary_files;
  self->temporary_files = nullptr;
  G_OBJECT_CLASS(image_picker_master_plugin_parent_class)->dispose(object);
}

static void image_picker_master_plugin_class_init(
    ImagePickerMasterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = image_picker_master_plugin_dispose;
}

static void image_picker_master_plugin_init(ImagePickerMasterPlugin* self) {
  self->temporary_files = new std::vector<std::string>();
}

static void method_call_cb(FlMethodChannel* channel,
                           FlMethodCall* method_call,
                           gpointer user_data) {
  ImagePickerMasterPlugin* plugin = IMAGE_PICKER_MASTER_PLUGIN(user_data);
  image_picker_master_plugin_handle_method_call(plugin, method_call);
}

void image_picker_master_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  ImagePickerMasterPlugin* plugin = IMAGE_PICKER_MASTER_PLUGIN(
      g_object_new(image_picker_master_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "image_picker_master",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);
  g_object_unref(plugin);
}
