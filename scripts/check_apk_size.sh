#!/bin/bash
set -e

ORIG_DIR=$(pwd)
echo "Building blank Flutter app baseline..."
# Create a temp blank project to get the baseline Flutter engine size
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
flutter create --no-pub blank_apk_baseline >/dev/null
cd blank_apk_baseline
flutter pub get >/dev/null
flutter build apk --release >/dev/null

BASELINE_APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [[ "$OSTYPE" == "darwin"* ]]; then
    BASELINE_SIZE=$(stat -f%z "$BASELINE_APK_PATH")
else
    BASELINE_SIZE=$(stat -c%s "$BASELINE_APK_PATH")
fi
echo "Baseline APK Size: $BASELINE_SIZE bytes"

cd "$ORIG_DIR"

echo "Building SDK example app in release mode..."
cd qrpay_sdk/example
flutter build apk --release --split-per-abi >/dev/null || true

APK_PATH="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ ! -f "$APK_PATH" ]; then
    # Fallback if no splits
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    if [ ! -f "$APK_PATH" ]; then
        echo "Error: APK not found"
        exit 1
    fi
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
    SDK_SIZE=$(stat -f%z "$APK_PATH")
else
    SDK_SIZE=$(stat -c%s "$APK_PATH")
fi

echo "SDK Example APK Size: $SDK_SIZE bytes"

# Calculate overhead
OVERHEAD=$((SDK_SIZE - BASELINE_SIZE))
BUDGET=2097152 # 2 MB

echo "SDK Overhead: $OVERHEAD bytes"
echo "Budget: $BUDGET bytes"

if [ "$OVERHEAD" -gt "$BUDGET" ]; then
    echo "FAIL: SDK size overhead ($OVERHEAD bytes) exceeds the 2MB budget ($BUDGET bytes)."
    exit 1
else
    echo "PASS: SDK size overhead ($OVERHEAD bytes) is within the 2MB budget."
    exit 0
fi
