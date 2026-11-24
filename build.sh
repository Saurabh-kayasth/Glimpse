#!/bin/zsh
# Builds Glimpse and installs it to ~/Applications/Glimpse.app (P1.1; signing from P3.2; installing from P3.1,
# docs/rollout/P3.1-launch-at-login.md).
#   ./build.sh                build in release mode, wrap and sign in build/, then install to ~/Applications
#   ./build.sh --run          the same, then quit any running Glimpse and start the installed one
#   ./build.sh --reset-grant  also clear Glimpse's Accessibility entry so macOS asks again (combine with --run)
#
# Signing: with the "Glimpse Local" certificate in your login keychain (made once by tools/make-signing-cert.sh), every
# build is the same app to macOS, so Accessibility and Desktop-folder access stay granted across rebuilds.
# Without it, the build is signed ad hoc: each build is a new app to macOS, so the old Accessibility entry is cleared
# here (it would stay listed but silently stop working) and macOS asks again.
set -euo pipefail
cd "$(dirname "$0")"

RUN=0; RESET=0
for arg in "$@"; do
  case "$arg" in
    --run) RUN=1 ;;
    --reset-grant) RESET=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

swift build -c release
BIN="$(swift build -c release --show-bin-path)/Glimpse"

APP=build/Glimpse.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Support/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"   # made by tools/make-icon.swift
# A build number per build (UTC time), shown in the log's launch line, so you can tell builds apart.
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(date -u +%Y%m%d.%H%M%S)" "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/Glimpse"

IDENTITY="Glimpse Local"
if security find-identity -p codesigning 2>/dev/null | grep -q "\"$IDENTITY\""; then
  codesign --force --sign "$IDENTITY" --timestamp=none "$APP"
  echo "signed with \"$IDENTITY\" (grants survive rebuilds)"
else
  codesign --force --sign - "$APP"
  RESET=1
  echo "signed ad hoc: \"$IDENTITY\" not found (run tools/make-signing-cert.sh once); Accessibility must be granted again"
fi
if (( RESET )); then
  tccutil reset Accessibility local.glimpse.app >/dev/null 2>&1 || true
  echo "cleared Glimpse's Accessibility entry"
fi
# Install: one copy, at a fixed place, so "Launch at Login" keeps pointing at it across rebuilds. The staging copy in
# build/ is removed so there's never a second Glimpse to start by mistake.
DEST="$HOME/Applications/Glimpse.app"
mkdir -p "$HOME/Applications"
rm -rf "$DEST"
ditto "$APP" "$DEST"
rm -rf "$APP"
echo "installed $DEST"

if (( RUN )); then
  pkill -x Glimpse 2>/dev/null && sleep 1 || true
  open "$DEST"
  echo "started; log: ~/Library/Logs/Glimpse.log"
fi
