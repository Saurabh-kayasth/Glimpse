#!/bin/zsh
# Builds tools/ax-probe/build/GlimpseProbe.app, signs it ad hoc and clears any old Accessibility grant for it
# (an ad-hoc signed rebuild is a "new app" to macOS, so the old grant would silently stop working).
#   ./build.sh                 build only
#   ./build.sh --run [args]    build, then start it with `open` so the probe, not VS Code, asks for Accessibility
set -euo pipefail
cd "$(dirname "$0")"

APP=build/GlimpseProbe.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"
swiftc -O -swift-version 5 -o "$APP/Contents/MacOS/GlimpseProbe" main.swift
codesign --force --sign - "$APP"
tccutil reset Accessibility local.glimpse.probe >/dev/null 2>&1 || true
echo "built $PWD/$APP"

if [[ "${1:-}" == "--run" ]]; then
  shift
  pkill -x GlimpseProbe 2>/dev/null || true
  if (( $# )); then open "$APP" --args "$@"; else open "$APP"; fi
  echo "started; log: ~/Library/Logs/Glimpse-probe.log"
fi
