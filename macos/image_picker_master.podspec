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

  # Privacy manifest describing camera and file access usage
  s.resource_bundles = {'image_picker_master_privacy' => ['image_picker_master/Sources/image_picker_master/PrivacyInfo.xcprivacy']}

  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'

  # Automatically inject required permission descriptions into the host app's Info.plist
  # and camera entitlement into the app's entitlements file — no manual setup needed.
  s.script_phases = [
    {
      :name => 'ImagePickerMaster - Inject Permissions',
      :script => <<-SCRIPT
        set -e

        # ── 1. Info.plist permissions ──────────────────────────────────────────
        PLIST="$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
        if [ -z "$PLIST" ] || [ ! -f "$PLIST" ]; then
          PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
        fi

        if [ -f "$PLIST" ]; then
          inject_plist_key() {
            local KEY="$1"
            local VALUE="$2"
            if ! /usr/libexec/PlistBuddy -c "Print :$KEY" "$PLIST" > /dev/null 2>&1; then
              /usr/libexec/PlistBuddy -c "Add :$KEY string $VALUE" "$PLIST"
              echo "note: [ImagePickerMaster] Added $KEY to Info.plist"
            else
              echo "note: [ImagePickerMaster] $KEY already exists — skipping."
            fi
          }

          inject_plist_key "NSCameraUsageDescription" "This app uses the camera to capture photos."
          inject_plist_key "NSMicrophoneUsageDescription" "This app uses the microphone to record audio with videos."
        else
          echo "warning: [ImagePickerMaster] Info.plist not found — skipping permission injection."
        fi

        # ── 2. Entitlements: camera access ────────────────────────────────────
        # Find the entitlements file for the current target
        ENTITLEMENTS_FILE=""
        if [ -n "$CODE_SIGN_ENTITLEMENTS" ]; then
          # Resolve relative path against the project source root
          ENTITLEMENTS_FILE="$SRCROOT/$CODE_SIGN_ENTITLEMENTS"
        fi

        if [ -n "$ENTITLEMENTS_FILE" ] && [ -f "$ENTITLEMENTS_FILE" ]; then
          inject_entitlement_key() {
            local KEY="$1"
            if ! /usr/libexec/PlistBuddy -c "Print :$KEY" "$ENTITLEMENTS_FILE" > /dev/null 2>&1; then
              /usr/libexec/PlistBuddy -c "Add :$KEY bool true" "$ENTITLEMENTS_FILE"
              echo "note: [ImagePickerMaster] Added $KEY to entitlements."
            else
              echo "note: [ImagePickerMaster] $KEY already exists in entitlements — skipping."
            fi
          }

          inject_entitlement_key "com.apple.security.device.camera"
          inject_entitlement_key "com.apple.security.device.microphone"
        else
          echo "warning: [ImagePickerMaster] Entitlements file not found (CODE_SIGN_ENTITLEMENTS=$CODE_SIGN_ENTITLEMENTS) — skipping entitlement injection."
        fi
      SCRIPT
      :execution_position => :before_compile,
      :shell_path => '/bin/sh',
      :show_env_vars_in_log => '0'
    }
  ]
end
