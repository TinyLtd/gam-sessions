#!/bin/bash
# Run GAMSessions at login (and uninstall it again).
#   ./install-startup.sh            # install + start now
#   ./install-startup.sh uninstall  # stop + remove
#
# A LaunchAgent, not a System Events login item: `make new login item` needs
# Automation/assistive-access approval and fails headless with -1719. launchd
# needs no permission grant and survives reboots on its own.

set -euo pipefail
cd "$(dirname "$0")"

LABEL="local.gam.sessions"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# install.sh points this at /Applications; standalone it uses the built copy.
APP="${GAM_APP:-$PWD/GAMSessions.app}"
BIN="$APP/Contents/MacOS/GAMSessions"
DOMAIN="gui/$(id -u)"

# Already-loaded agents must go before a rewrite, or launchd keeps the old path.
unload() { launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true; }

if [[ "${1:-install}" == "uninstall" ]]; then
  unload
  rm -f "$PLIST"
  echo "Removed $LABEL from login items."
  exit 0
fi

[[ -x "$BIN" ]] || { echo "No app at $APP. Run ./install.sh (or ./build.sh) first." >&2; exit 1; }

mkdir -p "$(dirname "$PLIST")"
cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$BIN</string>
  </array>
  <key>RunAtLoad</key><true/>
</dict>
</plist>
PLISTEOF

plutil -lint "$PLIST" >/dev/null || { echo "Generated a bad plist — aborting." >&2; exit 1; }

unload
launchctl bootstrap "$DOMAIN" "$PLIST"
echo "Installed. GAMSessions starts at login and is running now."
# install.sh sets GAM_APP and prints its own hint; do not contradict it.
[[ -n "${GAM_APP:-}" ]] || echo "Remove with: ./install-startup.sh uninstall"
