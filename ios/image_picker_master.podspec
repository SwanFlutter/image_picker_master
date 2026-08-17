#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint image_picker_master.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'image_picker_master'
  s.version          = '0.0.1'
  s.summary          = 'A comprehensive Flutter plugin for picking images, videos, audio files, documents, and any file type, multiple selection, and file categorization.'
  s.description      = <<-DESC
A comprehensive Flutter plugin for picking images, videos, audio files, documents, and any file type, multiple selection, and file categorization.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'image_picker_master/Sources/image_picker_master/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest describing camera, photo library, and file access usage
  s.resource_bundles = {'image_picker_master_privacy' => ['image_picker_master/Sources/image_picker_master/PrivacyInfo.xcprivacy']}

  # Automatically inject required permission descriptions into the host app's Info.plist
  # so users of this plugin don't need to add them manually.
  s.script_phases = [
    {
      :name => 'ImagePickerMaster - Inject Permissions',
      :script => <<-SCRIPT
        set -e
        PLIST="$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
        if [ -z "$PLIST" ] || [ ! -f "$PLIST" ]; then
          PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
        fi
        if [ ! -f "$PLIST" ]; then
          echo "warning: [ImagePickerMaster] Info.plist not found at $PLIST — skipping permission injection."
          exit 0
        fi

        inject_key() {
          local KEY="$1"
          local VALUE="$2"
          if ! /usr/libexec/PlistBuddy -c "Print :$KEY" "$PLIST" > /dev/null 2>&1; then
            /usr/libexec/PlistBuddy -c "Add :$KEY string $VALUE" "$PLIST"
            echo "note: [ImagePickerMaster] Added $KEY to Info.plist"
          else
            echo "note: [ImagePickerMaster] $KEY already exists — skipping."
          fi
        }

        inject_key "NSCameraUsageDescription" "This app uses the camera to capture photos and videos."
        inject_key "NSPhotoLibraryUsageDescription" "This app accesses your photo library to let you pick images and videos."
        inject_key "NSPhotoLibraryAddUsageDescription" "This app saves captured photos to your photo library."
        inject_key "NSMicrophoneUsageDescription" "This app uses the microphone to record audio with videos."
      SCRIPT
      :execution_position => :before_compile,
      :shell_path => '/bin/sh',
      :show_env_vars_in_log => '0'
    }
  ]
end
