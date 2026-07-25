#!/usr/bin/env bash
set -Eeuo pipefail

# The validation harness was initially written with a configure option that
# FFmpeg does not implement. Correct only that harness line in an isolated copy;
# the FFmpeg production diff remains independently asserted as exactly 1+/1-.
cp ffmpeg-dv-rate-validation.sh /tmp/ffmpeg-dv-rate-validation.sh
sed -i '/^[[:space:]]*--enable-werror[[:space:]]*\\$/d' /tmp/ffmpeg-dv-rate-validation.sh
exec bash /tmp/ffmpeg-dv-rate-validation.sh
