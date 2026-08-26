#!/bin/bash
# Compile main.swift into GAMSessions.app (menu-bar agent, no Dock icon).
# Universal by default so a release runs on Intel and Apple Silicon alike;
# set NATIVE_ONLY=1 for a quicker single-arch build while developing.
set -euo pipefail
cd "$(dirname "$0")"

APP="GAMSessions.app"
BIN="$APP/Contents/MacOS/GAMSessions"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

if [[ -n "${NATIVE_ONLY:-}" ]]; then
  swiftc -O main.swift -o "$BIN"
else
  # Both slices, then lipo. If a slice will not build (SDK missing an arch),
  # fall back to native rather than failing the whole build.
  ok=1
  for t in arm64-apple-macos13 x86_64-apple-macos13; do
    swiftc -O -target "$t" main.swift -o "/tmp/GAMSessions-$t" 2>/dev/null || ok=0
  done
  if [[ $ok == 1 ]]; then
    lipo -create -output "$BIN" /tmp/GAMSessions-arm64-apple-macos13 \
                                /tmp/GAMSessions-x86_64-apple-macos13
    rm -f /tmp/GAMSessions-arm64-apple-macos13 /tmp/GAMSessions-x86_64-apple-macos13
  else
    echo "Note: could not build both architectures — this build is $(uname -m) only." >&2
    swiftc -O main.swift -o "$BIN"
  fi
fi

cp icon.png "$APP/Contents/Resources/icon.png"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>GAMSessions</string>
  <key>CFBundleIdentifier</key><string>local.gam.sessions</string>
  <key>CFBundleExecutable</key><string>GAMSessions</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

echo "Built $APP ($(lipo -archs "$BIN"))"
