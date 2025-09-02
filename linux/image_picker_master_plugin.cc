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

// Helper function declarations
static std::string encode_base64(const std::vector<uint8_t>& data);
static std::vector<uint8_t> read_file_bytes(const std::string& file_path);
static bool is_image_file(const std::string& file_path);
static std::string get_file_extension(const std::string& file_path);
static std::string create_temp_file_path(const std::string& extension);
static bool compress_image(const std::string& input_path, const std::string& output_path, int quality);
static void cleanup_temp_files(ImagePickerMasterPlugin* self);
static FlMethodResponse* create_error_response(const std::string& code, const std::string& message);

// Method handlers
static FlMethodResponse* handle_pick_files(FlValue* arguments);
static FlMethodResponse* handle_capture_photo(FlValue* arguments);
static void show_file_picker(
    const std::string& file_type,
    bool allow_multiple,
    const std::vector<std::string>& allowed_extensions,
    bool with_data,
    bool allow_compression,
    int compression_quality,
    FlMethodCall* method_call);

// Called when a method call is received from Flutter.
static void image_picker_master_plugin_handle_method_call(
    ImagePickerMasterPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* arguments = fl_method_call_get_args(method_call);

  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "pickFiles") == 0) {
    response = handle_pick_files(arguments);
  } else if (strcmp(method, "capturePhoto") == 0) {
    response = handle_capture_photo(arguments);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

FlMethodResponse* get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  g_autofree gchar *version = g_strdup_printf("Linux %s", uname_data.version);
  g_autoptr(FlValue) result = fl_value_new_string(version);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse* handle_pick_files(FlValue* arguments) {
  if (fl_value_get_type(arguments) != FL_VALUE_TYPE_MAP) {
    return create_error_response("invalid_arguments", "Arguments must be a map");
  }

  // Parse arguments
  FlValue* file_type_value = fl_value_lookup_string(arguments, "type");
  FlValue* allow_multiple_value = fl_value_lookup_string(arguments, "allowMultiple");
  FlValue* allowed_extensions_value = fl_value_lookup_string(arguments, "allowedExtensions");
  FlValue* with_data_value = fl_value_lookup_string(arguments, "withData");
  FlValue* allow_compression_value = fl_value_lookup_string(arguments, "allowCompression");
  FlValue* compression_quality_value = fl_value_lookup_string(arguments, "compressionQuality");

  std::string file_type = "any";
  if (file_type_value && fl_value_get_type(file_type_value) == FL_VALUE_TYPE_STRING) {
    file_type = fl_value_get_string(file_type_value);
  }

  bool allow_multiple = false;
  if (allow_multiple_value && fl_value_get_type(allow_multiple_value) == FL_VALUE_TYPE_BOOL) {
    allow_multiple = fl_value_get_bool(allow_multiple_value);
  }

  std::vector<std::string> allowed_extensions;
  if (allowed_extensions_value && fl_value_get_type(allowed_extensions_value) == FL_VALUE_TYPE_LIST) {
    size_t length = fl_value_get_length(allowed_extensions_value);
    for (size_t i = 0; i < length; i++) {
      FlValue* ext_value = fl_value_get_list_value(allowed_extensions_value, i);
      if (fl_value_get_type(ext_value) == FL_VALUE_TYPE_STRING) {
        allowed_extensions.push_back(fl_value_get_string(ext_value));
      }
    }
  }

  bool with_data = false;
  if (with_data_value && fl_value_get_type(with_data_value) == FL_VALUE_TYPE_BOOL) {
    with_data = fl_value_get_bool(with_data_value);
  }

  bool allow_compression = true;
  if (allow_compression_value && fl_value_get_type(allow_compression_value) == FL_VALUE_TYPE_BOOL) {
    allow_compression = fl_value_get_bool(allow_compression_value);
  }

  int compression_quality = 85;
  if (compression_quality_value && fl_value_get_type(compression_quality_value) == FL_VALUE_TYPE_INT) {
    compression_quality = fl_value_get_int(compression_quality_value);
  }

  // Create file chooser dialog
  GtkWidget* dialog = gtk_file_chooser_dialog_new(
      "Select Files",
      nullptr,
      allow_multiple ? GTK_FILE_CHOOSER_ACTION_OPEN : GTK_FILE_CHOOSER_ACTION_OPEN,
      "_Cancel", GTK_RESPONSE_CANCEL,
      "_Open", GTK_RESPONSE_ACCEPT,
      nullptr);

  gtk_file_chooser_set_select_multiple(GTK_FILE_CHOOSER(dialog), allow_multiple);

  // Set file filters
  if (file_type == "image") {
    GtkFileFilter* filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Images");
    gtk_file_filter_add_mime_type(filter, "image/*");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
  } else if (file_type == "video") {
    GtkFileFilter* filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Videos");
    gtk_file_filter_add_mime_type(filter, "video/*");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
  } else if (file_type == "audio") {
    GtkFileFilter* filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Audio");
    gtk_file_filter_add_mime_type(filter, "audio/*");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
  } else if (file_type == "document") {
    GtkFileFilter* filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Documents");
    // PDF
    gtk_file_filter_add_pattern(filter, "*.pdf");
    // Microsoft Office
    gtk_file_filter_add_pattern(filter, "*.doc");
    gtk_file_filter_add_pattern(filter, "*.docx");
    gtk_file_filter_add_pattern(filter, "*.xls");
    gtk_file_filter_add_pattern(filter, "*.xlsx");
    gtk_file_filter_add_pattern(filter, "*.ppt");
    gtk_file_filter_add_pattern(filter, "*.pptx");
    // Text files
    gtk_file_filter_add_pattern(filter, "*.txt");
    gtk_file_filter_add_pattern(filter, "*.rtf");
    gtk_file_filter_add_pattern(filter, "*.md");
    gtk_file_filter_add_pattern(filter, "*.markdown");
    // OpenDocument
    gtk_file_filter_add_pattern(filter, "*.odt");
    gtk_file_filter_add_pattern(filter, "*.ods");
    gtk_file_filter_add_pattern(filter, "*.odp");
    // Web files
    gtk_file_filter_add_pattern(filter, "*.html");
    gtk_file_filter_add_pattern(filter, "*.htm");
    gtk_file_filter_add_pattern(filter, "*.css");
    gtk_file_filter_add_pattern(filter, "*.js");
    gtk_file_filter_add_pattern(filter, "*.json");
    gtk_file_filter_add_pattern(filter, "*.xml");
    gtk_file_filter_add_pattern(filter, "*.csv");
    gtk_file_filter_add_pattern(filter, "*.yaml");
    gtk_file_filter_add_pattern(filter, "*.yml");
    // Code files
    gtk_file_filter_add_pattern(filter, "*.php");
    gtk_file_filter_add_pattern(filter, "*.py");
    gtk_file_filter_add_pattern(filter, "*.c");
    gtk_file_filter_add_pattern(filter, "*.cpp");
    gtk_file_filter_add_pattern(filter, "*.java");
    gtk_file_filter_add_pattern(filter, "*.sh");
    gtk_file_filter_add_pattern(filter, "*.pl");
    gtk_file_filter_add_pattern(filter, "*.rb");
    gtk_file_filter_add_pattern(filter, "*.lua");
    // Archives
    gtk_file_filter_add_pattern(filter, "*.zip");
    gtk_file_filter_add_pattern(filter, "*.rar");
    gtk_file_filter_add_pattern(filter, "*.7z");
    gtk_file_filter_add_pattern(filter, "*.tar");
    gtk_file_filter_add_pattern(filter, "*.gz");
    gtk_file_filter_add_pattern(filter, "*.bz2");
    // Fonts
    gtk_file_filter_add_pattern(filter, "*.ttf");
    gtk_file_filter_add_pattern(filter, "*.otf");
    gtk_file_filter_add_pattern(filter, "*.woff");
    gtk_file_filter_add_pattern(filter, "*.woff2");
    // Other
    gtk_file_filter_add_pattern(filter, "*.epub");
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
  } else if (!allowed_extensions.empty()) {
    GtkFileFilter* filter = gtk_file_filter_new();
    gtk_file_filter_set_name(filter, "Allowed Files");
    for (const auto& ext : allowed_extensions) {
      std::string pattern = "*." + ext;
      gtk_file_filter_add_pattern(filter, pattern.c_str());
    }
    gtk_file_chooser_add_filter(GTK_FILE_CHOOSER(dialog), filter);
  }

  gint result = gtk_dialog_run(GTK_DIALOG(dialog));
  
  if (result == GTK_RESPONSE_ACCEPT) {
    GSList* filenames = gtk_file_chooser_get_filenames(GTK_FILE_CHOOSER(dialog));
    
    g_autoptr(FlValue) files_list = fl_value_new_list();
    
    for (GSList* l = filenames; l != nullptr; l = l->next) {
      gchar* filename = static_cast<gchar*>(l->data);
      std::string file_path(filename);
      
      g_autoptr(FlValue) file_map = fl_value_new_map();
      
      // Add path
      fl_value_set_string_take(file_map, "path", fl_value_new_string(file_path.c_str()));
      
      // Add name
      std::filesystem::path path(file_path);
      std::string name = path.filename().string();
      fl_value_set_string_take(file_map, "name", fl_value_new_string(name.c_str()));
      
      // Add size
      try {
        auto file_size = std::filesystem::file_size(file_path);
        fl_value_set_string_take(file_map, "size", fl_value_new_int(static_cast<int64_t>(file_size)));
      } catch (...) {
        fl_value_set_string_take(file_map, "size", fl_value_new_int(0));
      }
      
      // Add extension
      std::string extension = get_file_extension(file_path);
      fl_value_set_string_take(file_map, "extension", fl_value_new_string(extension.c_str()));
      
      // Handle compression and data if requested
      std::string final_path = file_path;
      if (allow_compression && is_image_file(file_path) && compression_quality < 100) {
        std::string temp_path = create_temp_file_path("jpg");
        if (compress_image(file_path, temp_path, compression_quality)) {
          final_path = temp_path;
        }
      }
      
      if (with_data) {
        try {
          std::vector<uint8_t> file_data = read_file_bytes(final_path);
          std::string base64_data = encode_base64(file_data);
          fl_value_set_string_take(file_map, "bytes", fl_value_new_string(base64_data.c_str()));
        } catch (...) {
          fl_value_set_string_take(file_map, "bytes", fl_value_new_null());
        }
      }
      
      fl_value_append_take(files_list, file_map);
      g_free(filename);
    }
    
    g_slist_free(filenames);
    gtk_widget_destroy(dialog);
    
    return FL_METHOD_RESPONSE(fl_method_success_response_new(files_list));
  } else {
    gtk_widget_destroy(dialog);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
  }
}

// Helper function implementations
static std::string encode_base64(const std::vector<uint8_t>& data) {
  gchar* encoded = g_base64_encode(data.data(), data.size());
  std::string result(encoded);
  g_free(encoded);
  return result;
}

static std::vector<uint8_t> read_file_bytes(const std::string& file_path) {
  std::ifstream file(file_path, std::ios::binary);
  if (!file) {
    throw std::runtime_error("Cannot open file");
  }
  
  file.seekg(0, std::ios::end);
  size_t size = file.tellg();
  file.seekg(0, std::ios::beg);
  
  std::vector<uint8_t> data(size);
  file.read(reinterpret_cast<char*>(data.data()), size);
  
  return data;
}

static bool is_image_file(const std::string& file_path) {
  std::string ext = get_file_extension(file_path);
  std::transform(ext.begin(), ext.end(), ext.begin(), ::tolower);
  
  return ext == "jpg" || ext == "jpeg" || ext == "png" || 
         ext == "gif" || ext == "bmp" || ext == "webp" ||
         ext == "tiff" || ext == "tif";
}

static std::string get_file_extension(const std::string& file_path) {
  size_t dot_pos = file_path.find_last_of('.');
  if (dot_pos == std::string::npos) {
    return "";
  }
  return file_path.substr(dot_pos + 1);
}

static std::string create_temp_file_path(const std::string& extension) {
  gchar* temp_dir = g_get_tmp_dir();
  gchar* temp_file = g_strdup_printf("%s/flutter_image_picker_%d.%s", 
                                     temp_dir, g_random_int(), extension.c_str());
  std::string result(temp_file);
  g_free(temp_file);
  return result;
}

static bool compress_image(const std::string& input_path, const std::string& output_path, int quality) {
  GError* error = nullptr;
  
  // Load the image
  GdkPixbuf* pixbuf = gdk_pixbuf_new_from_file(input_path.c_str(), &error);
  if (!pixbuf) {
    if (error) {
      g_error_free(error);
    }
    return false;
  }
  
  // Save as JPEG with compression
  gchar* quality_str = g_strdup_printf("%d", quality);
  gboolean success = gdk_pixbuf_save(pixbuf, output_path.c_str(), "jpeg", &error,
                                     "quality", quality_str, nullptr);
  
  g_free(quality_str);
  g_object_unref(pixbuf);
  
  if (error) {
    g_error_free(error);
    return false;
  }
  
  return success;
}

static void cleanup_temp_files(ImagePickerMasterPlugin* self) {
  if (self->temporary_files) {
    for (const auto& file_path : *self->temporary_files) {
      std::filesystem::remove(file_path);
    }
    self->temporary_files->clear();
  }
}

static FlMethodResponse* create_error_response(const std::string& code, const std::string& message) {
  g_autoptr(FlValue) error_details = fl_value_new_map();
  fl_value_set_string_take(error_details, "code", fl_value_new_string(code.c_str()));
  fl_value_set_string_take(error_details, "message", fl_value_new_string(message.c_str()));
  
  return FL_METHOD_RESPONSE(fl_method_error_response_new(code.c_str(), message.c_str(), error_details));
}

static FlMethodResponse* handle_capture_photo(FlValue* arguments) {
  // For Linux, camera capture requires additional dependencies like GStreamer or V4L2
  // This is a simplified implementation that returns an error indicating camera capture
  // is not directly supported without additional system dependencies
  
  return create_error_response("CAMERA_NOT_SUPPORTED", 
                              "Camera capture is not directly supported on Linux without additional dependencies. Please use file picker to select images.");
}

static void image_picker_master_plugin_dispose(GObject* object) {
  ImagePickerMasterPlugin* self = IMAGE_PICKER_MASTER_PLUGIN(object);
  
  cleanup_temp_files(self);
  
  if (self->temporary_files) {
    delete self->temporary_files;
    self->temporary_files = nullptr;
  }
  
  G_OBJECT_CLASS(image_picker_master_plugin_parent_class)->dispose(object);
}

static void image_picker_master_plugin_class_init(ImagePickerMasterPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = image_picker_master_plugin_dispose;
}

static void image_picker_master_plugin_init(ImagePickerMasterPlugin* self) {
  self->temporary_files = new std::vector<std::string>();
}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  ImagePickerMasterPlugin* plugin = IMAGE_PICKER_MASTER_PLUGIN(user_data);
  image_picker_master_plugin_handle_method_call(plugin, method_call);
}

void image_picker_master_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  ImagePickerMasterPlugin* plugin = IMAGE_PICKER_MASTER_PLUGIN(
      g_object_new(image_picker_master_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "image_picker_master",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}