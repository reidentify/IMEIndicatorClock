#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="IMEIndicatorClock"
DERIVED_DATA="$PROJECT_DIR/build/DerivedData"
PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Release"
RELEASE_DIR="$PROJECT_DIR/build/Release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"

require_xcode() {
  local xcode_app="/Applications/Xcode.app/Contents/Developer"
  local dev_dir
  dev_dir="$(xcode-select -p 2>/dev/null || true)"

  if [[ -d "$xcode_app" && "$dev_dir" == *CommandLineTools* ]]; then
    export DEVELOPER_DIR="$xcode_app"
    echo "Using DEVELOPER_DIR=$DEVELOPER_DIR (xcode-select still points to Command Line Tools)."
    echo "Optional: sudo xcode-select -s $xcode_app"
  fi

  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "Error: Full Xcode is required (Command Line Tools alone are not enough)." >&2
    echo "Install Xcode from the App Store, then run:" >&2
    echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
    echo "  sudo xcodebuild -license accept" >&2
    exit 1
  fi

}

echo "Checking Xcode..."
require_xcode
xcodebuild -version

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"

BUILD_CONFIG="Release"
if ! xcodebuild \
  -project IMEIndicatorClock.xcodeproj \
  -scheme IMEIndicatorClock \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGN_IDENTITY=- \
  CODE_SIGNING_ALLOWED=YES \
  build; then
  echo "Release build failed; retrying Debug configuration..."
  BUILD_CONFIG="Debug"
  PRODUCTS_DIR="$DERIVED_DATA/Build/Products/Debug"
  xcodebuild \
    -project IMEIndicatorClock.xcodeproj \
    -scheme IMEIndicatorClock \
    -configuration Debug \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_ALLOWED=YES \
    build
fi

echo "Built with configuration: $BUILD_CONFIG"

if [[ ! -d "$PRODUCTS_DIR/$APP_NAME.app" ]]; then
  echo "Error: Expected app not found at $PRODUCTS_DIR/$APP_NAME.app" >&2
  exit 1
fi

echo "Copying app to $RELEASE_DIR..."
mkdir -p "$RELEASE_DIR"
rm -rf "$APP_BUNDLE"
cp -R "$PRODUCTS_DIR/$APP_NAME.app" "$APP_BUNDLE"

echo "Signing with ad-hoc signature..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Verifying signature..."
codesign -dv "$APP_BUNDLE" 2>&1

echo ""
echo "Build complete!"
echo "App bundle: $APP_BUNDLE"
echo ""
echo "Run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "Grant Accessibility in System Settings if prompted (IME monitoring)."