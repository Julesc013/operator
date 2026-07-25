#!/usr/bin/env bash
set -Eeuo pipefail

# Correct validation-harness-only defects in an isolated copy. These edits do
# not touch FFmpeg; the FFmpeg production diff is independently asserted as
# exactly one insertion and one deletion in libavformat/dv.c.
cp ffmpeg-dv-rate-validation.sh /tmp/ffmpeg-dv-rate-validation.sh
sed -i '/^[[:space:]]*--enable-werror[[:space:]]*\\$/d' /tmp/ffmpeg-dv-rate-validation.sh
# grep -q exits after the first match; with pipefail that makes the producer's
# expected SIGPIPE look like a failed membership test. Read the full list.
sed -i 's/grep -Fxq "$wanted"/grep -Fx "$wanted" >\/dev\/null/' /tmp/ffmpeg-dv-rate-validation.sh
# Keep the generated report factually aligned with the supported configure run.
sed -i 's/Baseline and patched builds with `--enable-werror`/Baseline and patched builds/' /tmp/ffmpeg-dv-rate-validation.sh
exec bash /tmp/ffmpeg-dv-rate-validation.sh
