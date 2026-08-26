#!/bin/bash
# One-command install: build, put the app in /Applications, run it at login.
#   ./install.sh            # install
#   ./install.sh uninstall  # remove app + login item (leaves your configs alone)

set -euo pipefail
cd "$(dirname "$0")"

# ~/Applications when /Applications isn't writable (non-admin account).
# GAM_DEST overrides for testing; ~/Applications when /Applications is read-only.
DEST="${GAM_DEST:-/Applications}"
[[ -w "$DEST" ]] || DEST="$HOME/Applications"
APP="$DEST/GAMSessions.app"

if [[ "${1:-install}" == "uninstall" ]]; then
  GAM_APP="$APP" ./install-startup.sh uninstall
  # Trash, not rm: never silently destroy something a user might want back.
  [[ -e "$APP" ]] && osascript -e "tell application \"Finder\" to delete POSIX file \"$APP\"" >/dev/null
  echo "Removed $APP. Your company configs in ~/.gam-companies are untouched."
  exit 0
fi

# Three ways to get an app: build it, use the prebuilt one shipped in the
# release zip, or tell the user where to get one.
if command -v swiftc >/dev/null; then
  ./build.sh
elif [[ -d GAMSessions.app ]]; then
  echo "No swiftc — using the prebuilt GAMSessions.app next to this script."
else
  echo "Nothing to install." >&2
  echo "Either install the Xcode command line tools and build from source:" >&2
  echo "  xcode-select --install" >&2
  echo "or download the prebuilt zip from this project's releases page:" >&2
  origin=$(git config --get remote.origin.url 2>/dev/null || true)
  [[ -n "$origin" ]] && echo "  ${origin%.git}/releases/latest" >&2
  exit 1
fi

mkdir -p "$DEST"
rm -rf "$APP"
cp -R GAMSessions.app "$APP"
# A zip fetched by a browser carries a quarantine flag, and this app is only
# ad-hoc signed, so Gatekeeper refuses it outright ("damaged") rather than
# offering an override. Clearing it is what the user would otherwise do by hand.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
GAM_APP="$APP" ./install-startup.sh

echo
echo "Installed to $APP"
echo "Look for the G in your menu bar. If you cannot see it, it may be behind"
echo "the notch -- Cmd-drag the menu bar icons to move it."
