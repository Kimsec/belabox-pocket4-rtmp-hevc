#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -ne 0 && "${POCKET4_NO_SUDO:-0}" != "1" ]]; then
  echo "MPP decode/encode usually requires root on BELABOX; re-running with sudo..."
  exec sudo -E bash "$0" "$@"
fi

RTMP_URL="${RTMP_URL:-rtmp://127.0.0.1:1935/publish/live}"
PLUGIN_DIR="/opt/belabox-pocket4-rtmp-hevc"
REGISTRY_FILE="/tmp/gst-registry-pocket4-live-reencode.bin"

echo "Testing live decode + re-encode from: $RTMP_URL"

GST_PLUGIN_PATH="$PLUGIN_DIR" \
GST_REGISTRY="$REGISTRY_FILE" \
GST_DEBUG="${GST_DEBUG:-flvdemux:4,h265parse:3,mpp*:3}" \
gst-launch-1.0 -v \
  rtmpsrc location="$RTMP_URL" ! \
  flvdemux name=d \
  d.video ! queue ! h265parse ! video/x-h265,stream-format=byte-stream,alignment=au ! \
  mppvideodec ! videorate ! video/x-raw,framerate=30/1,format=NV12 ! \
  mpph265enc zero-copy-pkt=0 qp-max=51 gop=60 ! h265parse ! \
  fakesink sync=false

