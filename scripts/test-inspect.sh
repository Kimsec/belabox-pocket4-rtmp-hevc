#!/usr/bin/env bash
set -euo pipefail

PLUGIN_DIR="/opt/belabox-pocket4-rtmp-hevc"
REGISTRY_FILE="/tmp/gst-registry-pocket4-inspect.bin"

if [[ ! -f "$PLUGIN_DIR/libgstflv.so" ]]; then
  echo "ERROR: patched plugin not installed at $PLUGIN_DIR/libgstflv.so" >&2
  echo "Run: sudo bash scripts/install.sh" >&2
  exit 1
fi

OUTPUT="$(
  GST_PLUGIN_PATH="$PLUGIN_DIR" \
  GST_REGISTRY="$REGISTRY_FILE" \
  gst-inspect-1.0 flvdemux
)"

echo "$OUTPUT" | grep -q "Filename.*$PLUGIN_DIR/libgstflv.so" || {
  echo "ERROR: flvdemux did not load from $PLUGIN_DIR/libgstflv.so" >&2
  echo "$OUTPUT" | sed -n '/Filename/,+5p' >&2
  exit 1
}

echo "$OUTPUT" | grep -q "video/x-h265" || {
  echo "ERROR: flvdemux does not advertise video/x-h265" >&2
  exit 1
}

echo "$OUTPUT" | sed -n '/Filename/,+35p'
echo
echo "OK: patched flvdemux is installed and advertises video/x-h265."

