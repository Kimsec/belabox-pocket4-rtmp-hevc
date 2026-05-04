#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: rollback.sh is intended for Linux." >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "ERROR: rollback.sh must be run as root. Use: sudo bash scripts/rollback.sh" >&2
  exit 1
fi

DROPIN_FILE="/etc/systemd/system/belaUI.service.d/10-pocket4-gst-plugin.conf"
PIPELINE_DIR="/usr/share/belacoder/pipelines/custom"
REGISTRY_FILE="/tmp/gst-registry-pocket4-belaui.bin"

rm -f "$DROPIN_FILE"
rm -f "$PIPELINE_DIR"/h265_pocket4_rtmp_localhost_publish_live_25fps
rm -f "$PIPELINE_DIR"/h265_pocket4_rtmp_localhost_publish_live_30fps
rm -f "$REGISTRY_FILE"

systemctl daemon-reload
systemctl restart belaUI.service

echo "Pocket 4 systemd drop-in and custom pipelines removed."
echo "The original system GStreamer plugin was not touched."
echo "Isolated plugin may remain at /opt/belabox-pocket4-rtmp-hevc/libgstflv.so but is no longer loaded by belaUI."
