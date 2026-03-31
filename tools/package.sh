#!/bin/bash

set -euo pipefail

CAPS_NAV_TEMP_DIR=""
CAPS_NAV_ATTACHED_DEVICE=""
MODE="dev"
OUTPUT_DIR=""
DERIVED_DATA_PATH=""
GENERATE_SHA256=1
SIGNING_IDENTITY=""
TEAM_ID=""
NOTARY_PROFILE=""
ARCHIVE_PATH=""
EXPORT_PATH=""
EXPORT_OPTIONS_PLIST_PATH=""
APP_BUNDLE_PATH=""
APP_BINARY_PATH=""
INFO_PLIST_PATH=""
DMG_PATH=""
SHA256_PATH=""
MARKETING_VERSION=""
BUILD_NUMBER=""
ARTIFACT_BASENAME=""
DMG_OUTPUT_BASE=""
ATTACHED_MOUNT_POINT=""

caps_nav_usage() {
  cat <<'EOF_USAGE'
用法：
  ./tools/package.sh [--mode <dev|release>] [--output-dir <path>] [--derived-data <path>] [--skip-sha256]
  ./tools/package.sh --mode release --signing-identity <name> --team-id <id> --notary-profile <profile>

说明：
  生成 Caps Nav 的 macOS 分发包。
  - dev：本地打包，输出 Release 通用版 App 与 DMG
  - release：正式发布，额外执行 Developer ID 签名、Apple notarization 与票据贴附

选项：
  --mode <dev|release>        打包模式，默认 dev
  --output-dir <path>         产物输出目录，默认是仓库根目录下的 artifacts/<mode>/
  --derived-data <path>       构建产物目录，默认是仓库根目录下的 .build/ReleasePackaging
  --signing-identity <name>   release 模式的 Developer ID Application 签名身份
  --team-id <id>              release 模式的 Apple Developer Team ID
  --notary-profile <profile>  release 模式的 notarytool keychain profile
  --skip-sha256               跳过 DMG 的 SHA-256 摘要文件生成
  --help                      显示帮助

环境变量：
  CAPS_NAV_OUTPUT_DIR
  CAPS_NAV_DERIVED_DATA
  CAPS_NAV_SIGNING_IDENTITY
  CAPS_NAV_TEAM_ID
  CAPS_NAV_NOTARY_PROFILE
EOF_USAGE
}

caps_nav_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

caps_nav_repo_root() {
  cd "$(caps_nav_script_dir)/.." && pwd
}

caps_nav_artifact_name() {
  local marketing_version="$1"
  local build_number="$2"
  echo "Caps-Nav-${marketing_version}-${build_number}-macOS-universal"
}

caps_nav_volume_name() {
  local marketing_version="$1"
  echo "Caps Nav ${marketing_version}"
}

caps_nav_background_relative_path() {
  echo ".background/Caps Nav Installer Background.png"
}

caps_nav_background_basename() {
  basename "$(caps_nav_background_relative_path)"
}

caps_nav_require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "缺少依赖命令：$command_name" >&2
    exit 1
  fi
}

caps_nav_require_file() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    echo "缺少必需文件：$file_path" >&2
    exit 1
  fi
}

caps_nav_log() {
  local message="$1"
  echo "[Caps Nav Release] $message"
}

caps_nav_fail_with_context() {
  local description="$1"
  local details="${2:-}"

  if [[ -n "$details" ]]; then
    echo "$details" >&2
  fi

  if [[ "$details" == *"app is sandboxed"* || "$details" == *"设备未配置"* ]]; then
    echo "当前环境无法完成 DMG 设备操作，通常是因为运行在受限沙箱中。请在你自己的 macOS 终端直接执行 ./tools/package.sh。" >&2
  fi

  echo "步骤失败：$description" >&2
  exit 1
}

caps_nav_cleanup_temp_resources() {
  if [[ -n "${CAPS_NAV_ATTACHED_DEVICE:-}" ]]; then
    hdiutil detach -force "$CAPS_NAV_ATTACHED_DEVICE" >/dev/null 2>&1 || true
    CAPS_NAV_ATTACHED_DEVICE=""
  fi

  if [[ -n "${CAPS_NAV_TEMP_DIR:-}" && -d "$CAPS_NAV_TEMP_DIR" ]]; then
    rm -rf "$CAPS_NAV_TEMP_DIR"
    CAPS_NAV_TEMP_DIR=""
  fi
}

caps_nav_run_and_capture() {
  local description="$1"
  shift

  local output
  if ! output=$("$@" 2>&1); then
    caps_nav_fail_with_context "$description" "$output"
  fi

  printf '%s\n' "$output"
}

caps_nav_parse_args() {
  MODE="${CAPS_NAV_MODE:-dev}"
  OUTPUT_DIR="${CAPS_NAV_OUTPUT_DIR:-}"
  DERIVED_DATA_PATH="${CAPS_NAV_DERIVED_DATA:-}"
  SIGNING_IDENTITY="${CAPS_NAV_SIGNING_IDENTITY:-}"
  TEAM_ID="${CAPS_NAV_TEAM_ID:-}"
  NOTARY_PROFILE="${CAPS_NAV_NOTARY_PROFILE:-}"
  GENERATE_SHA256=1

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        [[ $# -ge 2 ]] || {
          echo "--mode 需要一个参数：dev 或 release" >&2
          exit 1
        }
        MODE="$2"
        shift 2
        ;;
      --output-dir)
        [[ $# -ge 2 ]] || {
          echo "--output-dir 需要一个路径参数" >&2
          exit 1
        }
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --derived-data)
        [[ $# -ge 2 ]] || {
          echo "--derived-data 需要一个路径参数" >&2
          exit 1
        }
        DERIVED_DATA_PATH="$2"
        shift 2
        ;;
      --signing-identity)
        [[ $# -ge 2 ]] || {
          echo "--signing-identity 需要一个签名身份参数" >&2
          exit 1
        }
        SIGNING_IDENTITY="$2"
        shift 2
        ;;
      --team-id)
        [[ $# -ge 2 ]] || {
          echo "--team-id 需要一个 Team ID 参数" >&2
          exit 1
        }
        TEAM_ID="$2"
        shift 2
        ;;
      --notary-profile)
        [[ $# -ge 2 ]] || {
          echo "--notary-profile 需要一个 profile 参数" >&2
          exit 1
        }
        NOTARY_PROFILE="$2"
        shift 2
        ;;
      --skip-sha256)
        GENERATE_SHA256=0
        shift
        ;;
      --help|-h)
        caps_nav_usage
        exit 0
        ;;
      *)
        echo "未知参数：$1" >&2
        echo >&2
        caps_nav_usage >&2
        exit 1
        ;;
    esac
  done
}

caps_nav_resolve_defaults() {
  REPO_ROOT="$(caps_nav_repo_root)"
  PROJECT_PATH="$REPO_ROOT/Caps Nav.xcodeproj"
  SCHEME_NAME="CapsNav"
  CONFIGURATION_NAME="Release"
  PRODUCT_APP_NAME="Caps Nav.app"
  PRODUCT_BINARY_NAME="Caps Nav"
  BACKGROUND_GENERATOR_PATH="$REPO_ROOT/tools/GenerateDMGBackground.swift"

  if [[ -z "$OUTPUT_DIR" ]]; then
    if [[ "$MODE" == "release" ]]; then
      OUTPUT_DIR="$REPO_ROOT/artifacts/release"
    else
      OUTPUT_DIR="$REPO_ROOT/artifacts/dev"
    fi
  fi

  if [[ -z "$DERIVED_DATA_PATH" ]]; then
    DERIVED_DATA_PATH="$REPO_ROOT/.build/ReleasePackaging"
  fi

  ARCHIVE_PATH="$DERIVED_DATA_PATH/Archives/Caps Nav.xcarchive"
  EXPORT_PATH="$DERIVED_DATA_PATH/ExportedRelease"
  EXPORT_OPTIONS_PLIST_PATH="$DERIVED_DATA_PATH/exportOptions.plist"

  caps_nav_set_app_paths "$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION_NAME/$PRODUCT_APP_NAME"
}

caps_nav_set_app_paths() {
  APP_BUNDLE_PATH="$1"
  APP_BINARY_PATH="$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_BINARY_NAME"
  INFO_PLIST_PATH="$APP_BUNDLE_PATH/Contents/Info.plist"
}

caps_nav_validate_mode_configuration() {
  if [[ "$MODE" != "dev" && "$MODE" != "release" ]]; then
    echo "--mode 只支持 dev 或 release，当前值：$MODE" >&2
    exit 1
  fi

  if [[ "$MODE" != "release" ]]; then
    return 0
  fi

  local missing=()

  [[ -n "$SIGNING_IDENTITY" ]] || missing+=("--signing-identity（或 CAPS_NAV_SIGNING_IDENTITY）")
  [[ -n "$TEAM_ID" ]] || missing+=("--team-id（或 CAPS_NAV_TEAM_ID）")
  [[ -n "$NOTARY_PROFILE" ]] || missing+=("--notary-profile（或 CAPS_NAV_NOTARY_PROFILE）")

  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'release 模式缺少必需参数：%s\n' "${missing[*]}" >&2
    exit 1
  fi
}

caps_nav_prepare_directories() {
  rm -rf "$DERIVED_DATA_PATH"
  mkdir -p "$OUTPUT_DIR"
}

caps_nav_build_app_dev() {
  caps_nav_log "开始构建 dev 模式 Release Universal App"

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION_NAME" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    build
}

caps_nav_archive_app_release() {
  caps_nav_log "开始构建 release 模式 Archive"

  rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration "$CONFIGURATION_NAME" \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    archive
}

caps_nav_write_export_options_plist() {
  local plist_path="$1"
  mkdir -p "$(dirname "$plist_path")"

  cat >"$plist_path" <<EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>manual</string>
  <key>signingCertificate</key>
  <string>$SIGNING_IDENTITY</string>
  <key>teamID</key>
  <string>$TEAM_ID</string>
</dict>
</plist>
EOF_PLIST
}

caps_nav_export_app_release() {
  caps_nav_log "导出 Developer ID 签名 App"
  caps_nav_write_export_options_plist "$EXPORT_OPTIONS_PLIST_PATH"

  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PLIST_PATH"

  caps_nav_set_app_paths "$EXPORT_PATH/$PRODUCT_APP_NAME"
}

caps_nav_verify_universal_app() {
  [[ -d "$APP_BUNDLE_PATH" ]] || {
    echo "未找到构建产物：$APP_BUNDLE_PATH" >&2
    exit 1
  }

  [[ -f "$APP_BINARY_PATH" ]] || {
    echo "未找到 App 可执行文件：$APP_BINARY_PATH" >&2
    exit 1
  }

  local arch_info
  arch_info="$(lipo -info "$APP_BINARY_PATH")"

  if [[ "$arch_info" != *"arm64"* || "$arch_info" != *"x86_64"* ]]; then
    echo "构建产物不是通用包：$arch_info" >&2
    exit 1
  fi

  caps_nav_log "架构校验通过：$arch_info"
}

caps_nav_verify_signed_app() {
  caps_nav_verify_universal_app
  caps_nav_log "校验签名后的 App"
  caps_nav_run_and_capture "校验 App 签名" codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE_PATH" >/dev/null
}

caps_nav_read_metadata() {
  MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST_PATH")"
  BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST_PATH")"
  ARTIFACT_BASENAME="$(caps_nav_artifact_name "$MARKETING_VERSION" "$BUILD_NUMBER")"
  DMG_OUTPUT_BASE="$OUTPUT_DIR/$ARTIFACT_BASENAME"
  DMG_PATH="$DMG_OUTPUT_BASE.dmg"
  SHA256_PATH="$DMG_PATH.sha256"
}

caps_nav_generate_background_asset() {
  local output_path="$1"
  mkdir -p "$(dirname "$output_path")"

  caps_nav_log "生成 DMG 背景图"
  caps_nav_run_and_capture "生成 DMG 背景图" swift "$BACKGROUND_GENERATOR_PATH" "$output_path" >/dev/null
}

caps_nav_write_finder_script() {
  local script_path="$1"
  cat >"$script_path" <<EOF_FINDER
on run argv
  set volumeName to item 1 of argv

  tell application "Finder"
    tell disk volumeName
      open
      delay 0.4

      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {120, 120, 1040, 660}

      set opts to the icon view options of container window
      set arrangement of opts to not arranged
      set icon size of opts to 108
      set text size of opts to 14
      set background picture of opts to file ".background:$(caps_nav_background_basename)"

      set position of item "Caps Nav.app" of container window to {500, 300}
      set position of item "Applications" of container window to {785, 300}

      update without registering applications
      delay 0.4
      close
      open
      update without registering applications
      delay 0.8
    end tell
  end tell
end run
EOF_FINDER
}

caps_nav_attach_temp_dmg() {
  local dmg_path="$1"
  local attach_output

  attach_output="$(caps_nav_run_and_capture "挂载临时 DMG" hdiutil attach -readwrite -noverify -noautoopen "$dmg_path")"

  CAPS_NAV_ATTACHED_DEVICE="$(printf '%s\n' "$attach_output" | awk '$2 == "Apple_HFS" || $2 == "Apple_APFS" {print $1; exit}')"
  ATTACHED_MOUNT_POINT="$(printf '%s\n' "$attach_output" | awk '$2 == "Apple_HFS" || $2 == "Apple_APFS" {$1=""; $2=""; sub(/^[ \t]+/, ""); print; exit}')"

  if [[ -z "$CAPS_NAV_ATTACHED_DEVICE" || -z "$ATTACHED_MOUNT_POINT" ]]; then
    caps_nav_fail_with_context "解析挂载结果" "$attach_output"
  fi
}

caps_nav_detach_temp_dmg() {
  local device_path="$1"
  local attempt

  for attempt in 1 2 3; do
    if hdiutil detach "$device_path" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  caps_nav_run_and_capture "卸载临时 DMG" hdiutil detach -force "$device_path" >/dev/null
}

caps_nav_persist_finder_layout() {
  if [[ -n "$ATTACHED_MOUNT_POINT" ]]; then
    sync "$ATTACHED_MOUNT_POINT" >/dev/null 2>&1 || true
    sync >/dev/null 2>&1 || true
  fi

  sleep 2
}

caps_nav_create_dmg() {
  local temp_dir
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/caps-nav-release.XXXXXX")"
  CAPS_NAV_TEMP_DIR="$temp_dir"
  CAPS_NAV_ATTACHED_DEVICE=""
  trap caps_nav_cleanup_temp_resources EXIT

  local staging_dir="$temp_dir/dmg-root"
  local background_path="$staging_dir/$(caps_nav_background_relative_path)"
  local finder_script_path="$temp_dir/finder-layout.applescript"
  local temp_dmg_path="$temp_dir/$ARTIFACT_BASENAME-rw.dmg"
  local volume_name
  volume_name="$(caps_nav_volume_name "$MARKETING_VERSION")"

  mkdir -p "$staging_dir"

  caps_nav_log "准备 DMG 内容"
  ditto "$APP_BUNDLE_PATH" "$staging_dir/$PRODUCT_APP_NAME"
  ln -s /Applications "$staging_dir/Applications"
  caps_nav_generate_background_asset "$background_path"
  caps_nav_write_finder_script "$finder_script_path"

  rm -f "$DMG_PATH" "$SHA256_PATH"

  caps_nav_log "生成可编辑的临时 DMG"
  caps_nav_run_and_capture "创建临时 DMG" hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -ov \
    -fs HFS+ \
    -format UDRW \
    "$temp_dmg_path" >/dev/null

  caps_nav_attach_temp_dmg "$temp_dmg_path"

  caps_nav_log "应用 Finder 视觉布局"
  caps_nav_run_and_capture "设置 Finder 安装页布局" osascript "$finder_script_path" "$volume_name" >/dev/null
  caps_nav_log "持久化 Finder 布局"
  caps_nav_persist_finder_layout
  caps_nav_detach_temp_dmg "$CAPS_NAV_ATTACHED_DEVICE"
  CAPS_NAV_ATTACHED_DEVICE=""

  caps_nav_log "转换为最终 DMG：$DMG_PATH"
  caps_nav_run_and_capture "压缩最终 DMG" hdiutil convert "$temp_dmg_path" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_OUTPUT_BASE" >/dev/null
}

caps_nav_notarize_dmg() {
  caps_nav_log "提交 Apple notarization"
  caps_nav_run_and_capture "提交 DMG 公证" xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait >/dev/null
}

caps_nav_release_dmg_sign_command() {
  printf 'codesign --force --sign "%s" "%s"' "$SIGNING_IDENTITY" "$DMG_PATH"
}

caps_nav_release_dmg_gatekeeper_command() {
  printf 'spctl -a -t open --context context:primary-signature -v "%s"' "$DMG_PATH"
}

caps_nav_sign_dmg() {
  caps_nav_log "签名最终 DMG"
  caps_nav_run_and_capture "对 DMG 执行 Developer ID 签名" codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH" >/dev/null
}

caps_nav_staple_dmg() {
  caps_nav_log "贴附公证票据"
  caps_nav_run_and_capture "对 DMG 贴附票据" xcrun stapler staple "$DMG_PATH" >/dev/null
}

caps_nav_verify_release_artifact() {
  caps_nav_log "验证正式发布 DMG"
  caps_nav_run_and_capture "校验 DMG 票据" xcrun stapler validate "$DMG_PATH" >/dev/null
  caps_nav_run_and_capture "校验 Gatekeeper 放行" spctl -a -t open --context context:primary-signature -v "$DMG_PATH" >/dev/null
}

caps_nav_generate_sha256() {
  if [[ "$GENERATE_SHA256" -eq 0 ]]; then
    caps_nav_log "已跳过 SHA-256 文件生成"
    return
  fi

  caps_nav_log "生成 SHA-256 摘要"
  shasum -a 256 "$DMG_PATH" > "$SHA256_PATH"
}

caps_nav_print_summary() {
  caps_nav_log "打包完成"
  echo
  echo "模式：$MODE"
  echo "产物："
  echo "  DMG: $DMG_PATH"
  if [[ "$GENERATE_SHA256" -eq 1 ]]; then
    echo "  SHA: $SHA256_PATH"
  fi
  echo
  echo "说明："
  echo "  1. 该 DMG 内是通用版 Caps Nav.app，同时支持 arm64 和 x86_64。"
  if [[ "$MODE" == "release" ]]; then
    echo "  2. 已完成 Developer ID 签名、Apple notarization 与 stapler。"
  else
    echo "  2. dev 模式不包含 Developer ID 签名与 Apple notarization。"
    echo "  3. 首次分发给其他用户时，macOS 可能仍会提示“无法验证开发者”或“无法检查恶意软件”。"
  fi
}

caps_nav_require_base_dependencies() {
  caps_nav_require_command xcodebuild
  caps_nav_require_command hdiutil
  caps_nav_require_command ditto
  caps_nav_require_command lipo
  caps_nav_require_command shasum
  caps_nav_require_command osascript
  caps_nav_require_command swift
  caps_nav_require_command /usr/libexec/PlistBuddy
  caps_nav_require_file "$BACKGROUND_GENERATOR_PATH"
}

caps_nav_require_release_dependencies() {
  caps_nav_require_command codesign
  caps_nav_require_command xcrun
  caps_nav_require_command spctl
}

caps_nav_main() {
  caps_nav_parse_args "$@"
  caps_nav_resolve_defaults
  caps_nav_validate_mode_configuration

  caps_nav_require_base_dependencies
  if [[ "$MODE" == "release" ]]; then
    caps_nav_require_release_dependencies
  fi

  caps_nav_prepare_directories

  if [[ "$MODE" == "release" ]]; then
    caps_nav_archive_app_release
    caps_nav_export_app_release
    caps_nav_verify_signed_app
  else
    caps_nav_build_app_dev
    caps_nav_verify_universal_app
  fi

  caps_nav_read_metadata
  caps_nav_create_dmg

  if [[ "$MODE" == "release" ]]; then
    caps_nav_sign_dmg
    caps_nav_notarize_dmg
    caps_nav_staple_dmg
    caps_nav_verify_release_artifact
  fi

  caps_nav_generate_sha256
  caps_nav_print_summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  caps_nav_main "$@"
fi
