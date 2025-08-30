#ifndef FLUTTER_PLUGIN_IMAGE_PICKER_MASTER_PLUGIN_PRIVATE_H_
#define FLUTTER_PLUGIN_IMAGE_PICKER_MASTER_PLUGIN_PRIVATE_H_

#include <flutter_linux/flutter_linux.h>

#include "include/image_picker_master/image_picker_master_plugin.h"

// This file exposes some plugin internals for unit testing. See
// https://github.com/flutter/flutter/issues/88724 for current limitations
// in the unit-testable API.

// Handles the getPlatformVersion method call.
FlMethodResponse *get_platform_version();

// Handles the pickFiles method call.
FlMethodResponse *handle_pick_files(FlValue* arguments);

#endif  // FLUTTER_PLUGIN_IMAGE_PICKER_MASTER_PLUGIN_PRIVATE_H_