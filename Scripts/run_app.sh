#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="RightClickWriter"
APP_PATH="$ROOT_DIR/${APP_NAME}.app"
CONTENTS_PATH="$APP_PATH/Contents"
MACOS_PATH="$CONTENTS_PATH/MacOS"
INFO_PLIST="$CONTENTS_PATH/Info.plist"
TEMPLATE_PLIST="$ROOT_DIR/Sources/RightClickWriter/Resources/Info.plist.template"
BUILD_BIN="$ROOT_DIR/.build/debug/$APP_NAME"
BUNDLE_ID="io.rightclickwriter.RightClickWriter"

swift build --package-path "$ROOT_DIR"

mkdir -p "$MACOS_PATH"
cp "$BUILD_BIN" "$MACOS_PATH/$APP_NAME"
chmod +x "$MACOS_PATH/$APP_NAME"

# Keep app metadata in sync with the template on every run.
cp "$TEMPLATE_PLIST" "$INFO_PLIST"

# Keep a stable app identity so Accessibility permission survives rebuilds.
codesign --force --deep --sign - --identifier "$BUNDLE_ID" "$APP_PATH"

# Refresh service registration so "Services" picks up latest app metadata.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_PATH" >/dev/null 2>&1 || true
/System/Library/CoreServices/pbs -flush >/dev/null 2>&1 || true

killall "$APP_NAME" >/dev/null 2>&1 || true
if ! open -n -a "$APP_PATH" >/dev/null 2>&1; then
  "$APP_PATH/Contents/MacOS/$APP_NAME" >/tmp/${APP_NAME}.log 2>&1 &
fi

sleep 0.8
if ! pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  echo "Failed to launch $APP_NAME. See /tmp/${APP_NAME}.log"
  exit 1
fi

echo "Launched $APP_PATH"
echo "Bundle identifier: $BUNDLE_ID"
echo "If this is the first signed launch, grant Accessibility once in System Settings."
