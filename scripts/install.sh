#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: install.sh is intended for Linux." >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: install.sh must be run as root. Use: sudo bash scripts/install.sh" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_SRC="$ROOT_DIR/build/libgstflv.so"
PLUGIN_DIR="/opt/belabox-pocket4-rtmp-hevc"
PIPELINE_DIR="/usr/share/belacoder/pipelines/custom"
DROPIN_DIR="/etc/systemd/system/belaUI.service.d"
DROPIN_FILE="$DROPIN_DIR/10-pocket4-gst-plugin.conf"
REGISTRY_FILE="/tmp/gst-registry-pocket4-belaui.bin"

if [[ ! -f "$PLUGIN_SRC" ]]; then
  echo "ERROR: built plugin not found: $PLUGIN_SRC" >&2
  echo "Run: bash scripts/build.sh" >&2
  exit 1
fi

install -d -m 0755 "$PLUGIN_DIR"
install -m 0644 "$PLUGIN_SRC" "$PLUGIN_DIR/libgstflv.so"

install -d -m 0775 "$PIPELINE_DIR"
install -m 0664 "$ROOT_DIR"/pipelines/h265_pocket4_rtmp_localhost_publish_live_* "$PIPELINE_DIR"/

install -d -m 0755 "$DROPIN_DIR"
cat > "$DROPIN_FILE" <<'EOF'
[Service]
Environment=GST_PLUGIN_PATH=/opt/belabox-pocket4-rtmp-hevc
Environment=GST_REGISTRY=/tmp/gst-registry-pocket4-belaui.bin
EOF

rm -f "$REGISTRY_FILE"
systemctl daemon-reload
systemctl restart belaUI.service

echo "Pocket 4 patched flvdemux is enabled for belaUI/belacoder."
echo
echo "Verify plugin selection:"
echo "  bash $ROOT_DIR/scripts/test-inspect.sh"
echo
echo "Test live decode while Pocket 4 is publishing:"
echo "  bash $ROOT_DIR/scripts/test-live-decode.sh"
echo
echo "Test live decode + re-encode:"
echo "  bash $ROOT_DIR/scripts/test-live-reencode.sh"

