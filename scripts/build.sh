#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "ERROR: this build script is intended for Linux." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${GST_PLUGINS_GOOD_SRC:-"$ROOT_DIR/../gst-plugins-good1.0-1.20.3"}"
SYSROOT_DIR="${GST_LOCAL_SYSROOT:-"$ROOT_DIR/../local-sysroot"}"
BUILD_DIR="$ROOT_DIR/build"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: missing required command: $1" >&2
    echo "Install build dependencies, for example:" >&2
    echo "  sudo apt install build-essential pkg-config libglib2.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev" >&2
    exit 1
  fi
}

need_cmd cc

if [[ ! -d "$SRC_DIR/gst/flv" ]]; then
  echo "ERROR: GStreamer source tree not found at: $SRC_DIR" >&2
  echo "Set GST_PLUGINS_GOOD_SRC=/path/to/gst-plugins-good1.0-1.20.3 if needed." >&2
  exit 1
fi

if ! grep -q 'video/x-h265' "$SRC_DIR/gst/flv/gstflvdemux.c"; then
  echo "ERROR: source tree does not look patched for Pocket 4 H.265 FLV." >&2
  echo "Apply patches/pocket4-flvdemux-hevc-codec12.patch from the source root first." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

COMMON_CFLAGS=(
  -fPIC
  -DPIC
  -O2
  -pthread
  -DVERSION=\"1.20.3\"
  -DPACKAGE_VERSION=\"1.20.3\"
  -DPACKAGE=\"gst-plugins-good\"
  -DGST_PACKAGE_NAME=\"GStreamerGoodPluginsPocket4\"
  -DGST_PACKAGE_ORIGIN=\"local-belabox-pocket4\"
  -I"$SRC_DIR"
  -I"$SRC_DIR/gst/flv"
)

PKGS=(
  gstreamer-1.0
  gstreamer-base-1.0
  gstreamer-pbutils-1.0
  gstreamer-video-1.0
  gstreamer-tag-1.0
  gstreamer-audio-1.0
)

GST_CFLAGS=()
GST_LIBS=()

if command -v pkg-config >/dev/null 2>&1; then
  missing_pkg=0
  for pkg in "${PKGS[@]}"; do
    if ! pkg-config --exists "$pkg"; then
      echo "Missing pkg-config dependency: $pkg" >&2
      missing_pkg=1
    fi
  done

  if [[ "$missing_pkg" -eq 0 ]]; then
    read -r -a GST_CFLAGS <<< "$(pkg-config --cflags "${PKGS[@]}")"
    read -r -a GST_LIBS <<< "$(pkg-config --libs "${PKGS[@]}")"
  fi
fi

if [[ "${#GST_CFLAGS[@]}" -eq 0 ]]; then
  if [[ -d "$SYSROOT_DIR/usr/include/gstreamer-1.0" &&
        -d "$SYSROOT_DIR/usr/include/glib-2.0" &&
        -f "$SYSROOT_DIR/usr/lib/aarch64-linux-gnu/glib-2.0/include/glibconfig.h" &&
        -f "$SYSROOT_DIR/usr/lib/aarch64-linux-gnu/libgstreamer-1.0.so" ]]; then
    echo "pkg-config dependencies not available; using local sysroot: $SYSROOT_DIR"
    GST_CFLAGS=(
      -I"$SYSROOT_DIR/usr/include/gstreamer-1.0"
      -I"$SYSROOT_DIR/usr/include/glib-2.0"
      -I"$SYSROOT_DIR/usr/lib/aarch64-linux-gnu/glib-2.0/include"
      -I"$SYSROOT_DIR/usr/include/orc-0.4"
      -I"$SYSROOT_DIR/usr/include/aarch64-linux-gnu"
    )
    GST_LIBS=(
      -L"$SYSROOT_DIR/usr/lib/aarch64-linux-gnu"
      -Wl,-rpath-link,"$SYSROOT_DIR/usr/lib/aarch64-linux-gnu"
      -lgstpbutils-1.0
      -lgstvideo-1.0
      -lgsttag-1.0
      -lgstaudio-1.0
      -lgstbase-1.0
      -lgstreamer-1.0
      -lgobject-2.0
      -lglib-2.0
    )
  else
    echo "ERROR: missing GStreamer development dependencies." >&2
    echo "Install build dependencies, for example:" >&2
    echo "  sudo apt install build-essential pkg-config libglib2.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev" >&2
    echo "Or set GST_LOCAL_SYSROOT=/path/to/local-sysroot with GStreamer headers and libs." >&2
    exit 1
  fi
fi

echo "Building isolated libgstflv.so from: $SRC_DIR"

cc "${COMMON_CFLAGS[@]}" "${GST_CFLAGS[@]}" \
  -c "$SRC_DIR/gst/flv/gstflvdemux.c" \
  -o "$BUILD_DIR/gstflvdemux.o"

cc "${COMMON_CFLAGS[@]}" "${GST_CFLAGS[@]}" \
  -c "$SRC_DIR/gst/flv/gstflvelement.c" \
  -o "$BUILD_DIR/gstflvelement.o"

cc "${COMMON_CFLAGS[@]}" "${GST_CFLAGS[@]}" \
  -c "$SRC_DIR/gst/flv/gstflvmux.c" \
  -o "$BUILD_DIR/gstflvmux.o"

cc "${COMMON_CFLAGS[@]}" "${GST_CFLAGS[@]}" \
  -c "$SRC_DIR/gst/flv/gstflvplugin.c" \
  -o "$BUILD_DIR/gstflvplugin.o"

cc -shared -o "$BUILD_DIR/libgstflv.so" \
  "$BUILD_DIR/gstflvdemux.o" \
  "$BUILD_DIR/gstflvelement.o" \
  "$BUILD_DIR/gstflvmux.o" \
  "$BUILD_DIR/gstflvplugin.o" \
  "${GST_LIBS[@]}"

echo "Built: $BUILD_DIR/libgstflv.so"
