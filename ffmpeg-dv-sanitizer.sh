#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C TZ=UTC
export ASAN_OPTIONS='abort_on_error=1:halt_on_error=1:detect_leaks=1:strict_string_checks=1'
export UBSAN_OPTIONS='halt_on_error=1:print_stacktrace=1'
REF="${FFMPEG_REF:?}"
LABEL="${FFMPEG_LABEL:?}"
ROOT="$(pwd)"
WORK="$ROOT/san-work-$LABEL"
ART="$ROOT/artifacts/sanitizer-$LABEL"
SRC="$WORK/ffmpeg"
MEDIA="$WORK/media"
mkdir -p "$WORK" "$ART" "$MEDIA"
exec > >(tee "$ART/run.log") 2>&1

git clone --filter=blob:none https://github.com/FFmpeg/FFmpeg.git "$SRC"
git -C "$SRC" checkout --detach "$REF"
cd "$SRC"
./configure --toolchain=clang-asan-ubsan --disable-doc --disable-network --disable-autodetect --disable-x86asm
make -j"$(nproc)" ffmpeg ffprobe
python3 - <<'PY'
from pathlib import Path
p=Path('libavformat/dv.c')
s=p.read_text()
o='    c->vst->avg_frame_rate = av_inv_q(c->vst->time_base);'
n='    c->vst->avg_frame_rate = av_inv_q(c->sys->time_base);'
assert s.count(o)==1
p.write_text(s.replace(o,n,1))
PY
git diff --check
make -j"$(nproc)" ffmpeg ffprobe

make -j"$(nproc)" \
  fate-lavf-dv fate-lavf-dv_pal fate-lavf-dv_ntsc \
  fate-vsynth1-dv fate-vsynth1-dv-411 fate-vsynth1-dv-50 \
  fate-vsynth1-dv-hd fate-vsynth1-dv-fhd | tee "$ART/fate.log"

gen() {
  local name="$1" size="$2" rate="$3" pix="$4"
  ./ffmpeg -hide_banner -loglevel error -y -f lavfi -i "testsrc2=size=$size:rate=$rate" \
    -frames:v 6 -c:v dvvideo -pix_fmt "$pix" -f dv "$MEDIA/$name.dv"
  ./ffprobe -v error -show_streams -show_packets -of json "$MEDIA/$name.dv" > "$ART/$name.json"
  ./ffmpeg -hide_banner -loglevel error -i "$MEDIA/$name.dv" -map 0:v:0 -f framecrc - > "$ART/$name.framecrc"
  ./ffmpeg -hide_banner -loglevel error -ss 0.04 -i "$MEDIA/$name.dv" -map 0:v:0 -frames:v 2 -f null -
}
gen ntsc_dv25 720x480 30000/1001 yuv411p
gen pal_dv25 720x576 25 yuv420p
gen pal_dv25_411 720x576 25 yuv411p
gen ntsc_dvcpro50 720x480 30000/1001 yuv422p
gen pal_dvcpro50 720x576 25 yuv422p
gen dvcprohd_1080i5994 1280x1080 30000/1001 yuv422p
gen dvcprohd_1080i50 1440x1080 25 yuv422p
gen dvcprohd_720p5994 960x720 60000/1001 yuv422p
gen dvcprohd_720p50 960x720 50 yuv422p
printf 'PASS\n' > "$ART/result.txt"
