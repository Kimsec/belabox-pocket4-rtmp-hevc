# DJI Osmo Pocket 4 RTMP HEVC Fix for BELABOX/RK3588

A small `flvdemux` patch that lets BELABOX accept wireless RTMP HEVC from the DJI Osmo Pocket 4. The Pocket 4 sends HEVC inside FLV using legacy codec ID 12, which stock GStreamer 1.20.3 throws out as `unsupported video codec tag 12`.
This patch patches `flvdemux` to handle codec ID 12 as H.265 so the pipeline
reaches `h265parse`, Rockchip MPP decode and BELABOX encoding.

The original `gstreamer-1.0/libgstflv.so` is **never** touched.
The patched plugin lives in `/opt/belabox-pocket4-rtmp-hevc/`
and BELABOX picks it up through a `belaUI.service` systemd drop-in.

## Tested on

- BELABOX on RK3588 / Radxa ROCK 5B+
- Ubuntu Jammy base image, GStreamer 1.20.3, source `gst-plugins-good1.0 1.20.3-0ubuntu1.5`
- Pocket 4 stream: 1920x1080 @ 30 fps, HEVC Main, 8-bit, BT.709
- Pocket 4 publishing to `rtmp://<belabox-address>:1935/publish/live`

Main10 or other HEVC profiles may fail later in `mppvideodec` and have not
been tested.

---

## Step 1 - Back up first

Take a rollback point before anything else. The package is built to be easy to remove, but this is still live encoder pipeline work. A full board image is
best. 
At a minimum, keep a copy of your working BELABOX configuration.

## Step 2 - Download

Download this repo:

```bash
cd /home/user/
curl -L https://github.com/Kimsec/belabox-pocket4-rtmp-hevc/archive/refs/heads/main.tar.gz | tar xz
mv belabox-pocket4-rtmp-hevc-main belabox-pocket4-rtmp-hevc
```

Download the GStreamer source:

```bash
apt source gst-plugins-good1.0=1.20.3-0ubuntu1.5
```

You should now have this layout:
```text
/home/user/
  belabox-pocket4-rtmp-hevc/
  gst-plugins-good1.0-1.20.3/
```

## Step 3 - Apply the patch

```bash
cd /home/user/gst-plugins-good1.0-1.20.3
patch -p1 < ../belabox-pocket4-rtmp-hevc/patches/pocket4-flvdemux-hevc-codec12.patch
```

If the source tree is already patched, this command may say the patch was
previously applied.

## Step 4 - Install build dependencies

```bash
sudo apt update
sudo apt install build-essential pkg-config dpkg-dev patch \
  libglib2.0-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

## Step 5 - Build

```bash
cd /home/user/belabox-pocket4-rtmp-hevc
bash scripts/build.sh
```

Output: `build/libgstflv.so`.

## Step 6 - Install

```bash
sudo bash scripts/install.sh
```

The script:

- copies the patched plugin to `/opt/belabox-pocket4-rtmp-hevc/`
- drops the custom pipeline files in the BELABOX pipelines folder
- writes the `belaUI.service` systemd drop-in
- clears the GStreamer registry cache
- runs `daemon-reload` and restarts `belaUI.service`

No reboot needed.

## Step 7 - Verify the patched plugin is loaded

```bash
bash scripts/test-inspect.sh
```

You want to see:

- `Filename` pointing to `/opt/belabox-pocket4-rtmp-hevc/libgstflv.so`
- both `video/x-h265, stream-format=hvc1` and
  `video/x-h265, stream-format=byte-stream` in the caps

If `Filename` points back to `/usr/lib/aarch64-linux-gnu/...`, the drop-in is
not active.

## Step 8 - Test live decode

> [!WARNING]
> Start the Pocket 4 publishing to BELABOX first. 

This test reads from the live RTMP stream, so it will fail if nothing is being streamed in.

```bash
bash scripts/test-live-decode.sh
```

Healthy output:

- `video/x-h265, stream-format=byte-stream, alignment=au` reaching `mppvideodec`
- `video/x-raw, format=NV12` on the decoder's source pad
- pipeline going to `PREROLLED` then `PLAYING`

There is also `test-live-reencode.sh` which adds `mpph265enc` to confirm the
full decode-plus-encode chain. Both scripts run until you press `Ctrl+C`. MPP
device access often needs root, so they re-run themselves through `sudo` if
needed.

## Step 9 - Use it in the BELABOX UI

Pipeline files for 25 and 30 fps are installed automatically. Picking
the right one is still a manual step in the BELABOX UI.

A good real run shows:

- clean video and audio at the receiver
- no `unsupported video codec tag 12`
- no `Delayed linking failed`
- no `mppvideodec` errors
- bitrate control still working

---

## Rollback

```bash
cd /home/user/belabox-pocket4-rtmp-hevc
sudo bash scripts/rollback.sh
```

That removes the systemd drop-in and the custom pipeline files, clears the
registry cache, reloads systemd, and restarts `belaUI`. The original GStreamer
plugin was never replaced, so there is nothing to restore.

## What is in the package

- the patch
- build, install, rollback and test scripts
- BELABOX custom pipeline files for 25 and 30 fps

There is no prebuilt `libgstflv.so`.
You build the plugin yourself against the matching Ubuntu source.

The package does not change nginx or nginx-rtmp. The reason nginx comes up at
all is diagnostic: it may not cache/replay HEVC sequence headers for legacy
codec ID 12, so the fallback is handled on the GStreamer side instead.

## Technical notes

What the patch actually changes in `flvdemux`:

- maps FLV codec ID 12 to H.265
- adds `video/x-h265` to the source caps
- falls back to byte-stream mode if `nginx-rtmp` does not replay HEVC sequence.
- logs the fallback warning once per stream instead of once per packet
- leaves H.264 (codec ID 7) alone

## Caveats

- experimental - soak test for an hour or more before relying on it
- targets legacy codec ID 12, not Enhanced RTMP ExHeader HEVC
- byte-stream fallback assumes 4-byte length-prefixed HEVC NAL units: a different legacy variant from another camera is not tested.
- watch audio sync, bitrate behaviour, reconnect handling, temperature and
  memory through longer testing before recommending it to anyone else. All was
  fine while testing on my setup.
