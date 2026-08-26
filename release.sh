#!/bin/bash
# Build a universal app and publish it as a GitHub release, so people without
# the Xcode command line tools can install without compiling.
#   ./release.sh v1.0.0
set -euo pipefail
cd "$(dirname "$0")"

TAG="${1:-}"
[[ -n "$TAG" ]] || { echo "Usage: ./release.sh v1.0.0" >&2; exit 1; }
# Derived, not hardcoded, so a fork releases to itself.
REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner)}"
ZIP="GAMSessions-$TAG.zip"

./build.sh
ARCHS=$(lipo -archs GAMSessions.app/Contents/MacOS/GAMSessions)
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || {
  echo "Refusing to release a $ARCHS-only build — it would fail on other Macs." >&2
  exit 1
}

# Stage the app with the installer, so the zip is self-sufficient: no clone,
# no Xcode, no git.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
mkdir -p "$STAGE/GAMSessions"
cp -R GAMSessions.app "$STAGE/GAMSessions/"
cp install.sh install-startup.sh "$STAGE/GAMSessions/"
cat > "$STAGE/GAMSessions/README.txt" <<'TXT'
GAM Sessions
============

Menu-bar app for running GAM against several Google Workspace tenants, each
with its own isolated config.

To install, open Terminal, drag this folder onto the window after typing
"cd " (with the space), press Return, then run:

    ./install.sh

That copies the app to /Applications and starts it at login. A G appears in
your menu bar.

To remove it:

    ./install.sh uninstall

Your GAM configs in ~/.gam-companies are never touched by either.

Note: this app is not notarized by Apple, so macOS quarantines it after
download. install.sh clears that flag for you. If you install it by dragging
the app to /Applications by hand instead, clear it yourself:

    xattr -dr com.apple.quarantine /Applications/GAMSessions.app

Docs: https://github.com/__REPO__
TXT

sed -i '' "s|__REPO__|$REPO|" "$STAGE/GAMSessions/README.txt"

(cd "$STAGE" && zip -qr "$ZIP" GAMSessions)

gh release create "$TAG" "$STAGE/$ZIP" --repo "$REPO" \
  --title "GAM Sessions $TAG" \
  --notes "Universal build ($ARCHS) for macOS 13+. No Xcode needed.

Download \`$ZIP\`, unzip, and run \`./install.sh\` from the unzipped folder.
It copies the app to /Applications, clears the download quarantine flag, and
registers it to start at login.

Not notarized, so macOS quarantines the download — \`install.sh\` handles that.
Installing by hand instead needs \`xattr -dr com.apple.quarantine /Applications/GAMSessions.app\`."

echo "Released $TAG: https://github.com/$REPO/releases/tag/$TAG"
