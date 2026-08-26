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

command -v swiftc >/dev/null || {
  echo "swiftc not found. Install the Xcode command line tools:" >&2
  echo "  xcode-select --install" >&2
  exit 1
}

./build.sh

mkdir -p "$DEST"
rm -rf "$APP"
cp -R GAMSessions.app "$APP"
GAM_APP="$APP" ./install-startup.sh

echo
echo "Installed to $APP"
echo "Look for the G in your menu bar. If you cannot see it, it may be behind"
echo "the notch -- Cmd-drag the menu bar icons to move it."
