#!/usr/bin/env bash
# Install Stremio's Android TV build from Stremio's own servers, matched to the TV's ABI.
# Many TVs have 64-bit chips but a 32-bit userland, so ask the TV instead of guessing.
#   tools/stremio-install.sh            download + install the APK
#   tools/stremio-install.sh --store    open Stremio's Play Store page on the TV instead (auto-updates)
# Newer builds: https://www.stremio.com/downloads (update VERSION and the file names below).
set -euo pipefail
cd "$(dirname "$0")/.."
PY="${PY:-tools/venv/bin/python}"

if [ "${1:-}" = "--store" ]; then
  echo "am start -a android.intent.action.VIEW -d market://details?id=com.stremio.one" \
    | "$PY" -I tools/tv.py --batch
  echo "Play Store opened on the TV. Press Install with the remote."
  exit 0
fi

VERSION=1.10.4
BASE="https://dl.strem.io/android/v$VERSION-androidTV"
abi=$("$PY" -I tools/tv.py getprop ro.product.cpu.abi | tr -d '\r')
case "$abi" in
  arm64-v8a)   f="com.stremio.one-$VERSION-33145732-arm64-v8a.apk" ;;
  armeabi-v7a) f="com.stremio.one-$VERSION-31048580-armeabi-v7a.apk" ;;
  x86_64)      f="com.stremio.one-$VERSION-34194308-x86_64.apk" ;;
  x86)         f="com.stremio.one-$VERSION-32097156-x86.apk" ;;
  *) echo "Unknown ABI '$abi'. Try tools/stremio-install.sh --store"; exit 1 ;;
esac
echo "TV ABI: $abi -> $f"

mkdir -p build
[ -f "build/$f" ] || curl -fL --progress-bar -o "build/$f" "$BASE/$f"
"$PY" -I tools/tv.py --push "build/$f" /data/local/tmp/stremio.apk
printf '%s\n' \
  "pm install -r /data/local/tmp/stremio.apk" \
  "rm -f /data/local/tmp/stremio.apk" \
  | "$PY" -I tools/tv.py --batch
echo "Stremio installed. Rebuild the launcher to pin it: launcher/build-and-install.sh"
