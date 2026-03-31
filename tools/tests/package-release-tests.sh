#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_PATH="$ROOT_DIR/tools/package.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [[ ! -f "$SCRIPT_PATH" ]]; then
  fail "missing script: $SCRIPT_PATH"
fi

# shellcheck source=/dev/null
source "$SCRIPT_PATH"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [[ "$expected" != "$actual" ]]; then
    fail "$message (expected: $expected, actual: $actual)"
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="$3"

  if [[ "$haystack" != *"$needle"* ]]; then
    fail "$message (missing: $needle)"
  fi
}

artifact_name="$(caps_nav_artifact_name "1.2.3" "45")"
assert_eq "Caps-Nav-1.2.3-45-macOS-universal" "$artifact_name" "artifact name should include version, build and universal suffix"

volume_name="$(caps_nav_volume_name "1.2.3")"
assert_eq "Caps Nav 1.2.3" "$volume_name" "volume name should include app name and version"

background_relative_path="$(caps_nav_background_relative_path)"
assert_eq ".background/Caps Nav Installer Background.png" "$background_relative_path" "background path should use the hidden Finder background folder"

usage_output="$(caps_nav_usage)"
assert_contains "$usage_output" "./tools/package.sh" "usage should mention the direct execution command"
assert_contains "$usage_output" "--mode <dev|release>" "usage should describe the mode selector"
assert_contains "$usage_output" "--output-dir" "usage should describe output directory option"
assert_contains "$usage_output" "--headless-dmg" "usage should describe the headless dmg option"

xcodebuild() {
  printf '%s\n' "$@"
}

MODE="dev"
PROJECT_PATH="$ROOT_DIR/Caps Nav.xcodeproj"
SCHEME_NAME="CapsNav"
CONFIGURATION_NAME="Release"
DERIVED_DATA_PATH="/tmp/CapsNavDerivedData"
DEV_DISABLE_SIGNING=1
unsigned_dev_build_output="$(caps_nav_build_app_dev)"
assert_contains "$unsigned_dev_build_output" "CODE_SIGNING_ALLOWED=NO" "unsigned dev mode should disable code signing"
assert_contains "$unsigned_dev_build_output" "CODE_SIGNING_REQUIRED=NO" "unsigned dev mode should disable required code signing"
assert_contains "$unsigned_dev_build_output" "CODE_SIGN_IDENTITY=" "unsigned dev mode should clear the signing identity"

HEADLESS_DMG=0
if ! caps_nav_should_customize_dmg_layout; then
  fail "visual dmg layout should stay enabled by default"
fi

HEADLESS_DMG=1
if caps_nav_should_customize_dmg_layout; then
  fail "headless dmg mode should skip Finder layout customization"
fi

MODE="dev"
OUTPUT_DIR=""
DERIVED_DATA_PATH=""
caps_nav_resolve_defaults
assert_eq "$ROOT_DIR/artifacts/dev" "$OUTPUT_DIR" "dev mode should default output to artifacts/dev"

MODE="release"
OUTPUT_DIR=""
DERIVED_DATA_PATH=""
caps_nav_resolve_defaults
assert_eq "$ROOT_DIR/artifacts/release" "$OUTPUT_DIR" "release mode should default output to artifacts/release"

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/caps-nav-release-tests.XXXXXX")"
script_path="$tmpdir/finder-layout.applescript"
caps_nav_write_finder_script "$script_path" "Caps Nav 1.2.3"
script_output="$(cat "$script_path")"

assert_contains "$script_output" 'set current view of container window to icon view' "finder script should switch to icon view"
assert_contains "$script_output" 'set background picture of opts to file ".background:Caps Nav Installer Background.png"' "finder script should apply the background image"
assert_contains "$script_output" 'set position of item "Caps Nav.app" of container window to {500, 300}' "finder script should place the app icon lower in the install area"
assert_contains "$script_output" 'set position of item "Applications" of container window to {785, 300}' "finder script should place the Applications shortcut lower and farther right"
rm -rf "$tmpdir"

sample_pixel_rgb() {
  local image_path="$1"
  local x="$2"
  local y="$3"

  swift - "$image_path" "$x" "$y" <<'SWIFT'
import AppKit
import Foundation

let imagePath = CommandLine.arguments[1]
let x = Int(CommandLine.arguments[2])!
let y = Int(CommandLine.arguments[3])!

guard
    let image = NSImage(contentsOfFile: imagePath),
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)
else {
    fputs("Unable to sample image pixel\n", stderr)
    exit(1)
}

let red = Int((color.redComponent * 255.0).rounded())
let green = Int((color.greenComponent * 255.0).rounded())
let blue = Int((color.blueComponent * 255.0).rounded())
print("\(red) \(green) \(blue)")
SWIFT
}

tmp_background_dir="$(mktemp -d "${TMPDIR:-/tmp}/caps-nav-dmg-test.XXXXXX")"
tmp_png="$tmp_background_dir/background.png"
swift "$ROOT_DIR/tools/GenerateDMGBackground.swift" "$tmp_png" >/dev/null

read -r install_r install_g install_b <<<"$(sample_pixel_rgb "$tmp_png" 650 320)"
read -r title_r title_g title_b <<<"$(sample_pixel_rgb "$tmp_png" 790 450)"

install_luma=$((install_r + install_g + install_b))
title_luma=$((title_r + title_g + title_b))

if (( install_luma <= title_luma + 120 )); then
  fail "install area should be noticeably brighter than the title band (install: $install_luma, title: $title_luma)"
fi

rm -rf "$tmp_background_dir"

MODE="release"
SIGNING_IDENTITY=""
TEAM_ID=""
NOTARY_PROFILE=""
SKIP_NOTARIZATION=0
if (caps_nav_validate_mode_configuration >/tmp/caps-nav-validate.out 2>/tmp/caps-nav-validate.err); then
  fail "release mode validation should fail when required parameters are missing"
fi
validation_error="$(cat /tmp/caps-nav-validate.err)"
assert_contains "$validation_error" "--signing-identity" "release mode should require a signing identity"
assert_contains "$validation_error" "--team-id" "release mode should require a team id"
assert_contains "$validation_error" "--notary-profile" "release mode should require a notary profile"
rm -f /tmp/caps-nav-validate.out /tmp/caps-nav-validate.err

SIGNING_IDENTITY="Developer ID Application: Example Corp (TEAM123456)"
TEAM_ID="TEAM123456"
NOTARY_PROFILE="caps-nav-company"
tmp_export_options="$tmpdir/exportOptions.plist"
caps_nav_write_export_options_plist "$tmp_export_options"
export_options_content="$(cat "$tmp_export_options")"
assert_contains "$export_options_content" "<string>developer-id</string>" "release export options should use developer-id method"
assert_contains "$export_options_content" "<string>manual</string>" "release export options should use manual signing"
assert_contains "$export_options_content" "<string>Developer ID Application: Example Corp (TEAM123456)</string>" "release export options should embed the signing identity"
assert_contains "$export_options_content" "<string>TEAM123456</string>" "release export options should embed the team id"

DMG_PATH="/tmp/Caps Nav Release.dmg"
dmg_sign_command="$(caps_nav_release_dmg_sign_command)"
assert_contains "$dmg_sign_command" 'codesign --force --sign "Developer ID Application: Example Corp (TEAM123456)" "/tmp/Caps Nav Release.dmg"' "release mode should sign the dmg with the Developer ID identity"

dmg_gatekeeper_command="$(caps_nav_release_dmg_gatekeeper_command)"
assert_contains "$dmg_gatekeeper_command" 'spctl -a -t open --context context:primary-signature -v "/tmp/Caps Nav Release.dmg"' "release mode should verify the dmg gatekeeper status"

APP_BUNDLE_PATH="/tmp/Caps Nav.app"
dev_bundle_sign_command="$(caps_nav_dev_bundle_sign_command)"
assert_contains "$dev_bundle_sign_command" 'codesign --force --deep --sign - "/tmp/Caps Nav.app"' "unsigned dev mode should apply ad-hoc bundle signing so system permissions can identify the app"

preferences_source="$(cat "$ROOT_DIR/Caps Nav/Features/Preferences/PreferencesRootView.swift")"
assert_contains "$preferences_source" "private struct SettingsMappingKeyMenu" "preferences view should still contain the trigger key menu"
assert_contains "$preferences_source" "private struct SettingsMappingActionMenu" "preferences view should still contain the action menu"
assert_contains "$preferences_source" "private struct SettingsShortcutKeyMenu" "preferences view should still contain the shortcut key menu"

if [[ "$preferences_source" == *"private struct SettingsMappingKeyMenu"* && "$preferences_source" == *$'private struct SettingsMappingKeyMenu: View {\n'* && "$preferences_source" == *$'Menu {\n            ForEach(SettingsTriggerKeySection.allCases) { section in\n                Section {'* ]]; then
  fail "settings trigger key menu should avoid Menu+Section to stay compatible with GitHub Xcode 16"
fi

if [[ "$preferences_source" == *$'Menu {\n            ForEach(SettingsActionSection.allCases) { section in\n                Section {'* ]]; then
  fail "settings action menu should avoid Menu+Section to stay compatible with GitHub Xcode 16"
fi

if [[ "$preferences_source" == *$'Menu {\n            ForEach(SettingsShortcutKeySection.allCases) { section in\n                Section {'* ]]; then
  fail "settings shortcut key menu should avoid Menu+Section to stay compatible with GitHub Xcode 16"
fi

echo "package-release shell tests passed"
