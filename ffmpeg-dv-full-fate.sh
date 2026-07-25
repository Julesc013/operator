#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C TZ=UTC
REF="${FFMPEG_REF:?}"
LABEL="${FFMPEG_LABEL:?}"
ROOT="$(pwd)"
WORK="$ROOT/full-work-$LABEL"
ART="$ROOT/artifacts/full-$LABEL"
SRC="$WORK/ffmpeg"
mkdir -p "$WORK" "$ART"
exec > >(tee "$ART/run.log") 2>&1

git clone --filter=blob:none https://github.com/FFmpeg/FFmpeg.git "$SRC"
git -C "$SRC" checkout --detach "$REF"
cd "$SRC"
git log -1 --format='%H%n%ad%n%s' --date=iso-strict > "$ART/source.txt"
./configure --disable-doc --disable-debug --disable-network --disable-autodetect --disable-x86asm
make -j"$(nproc)" ffmpeg ffprobe
make -s fate-list | wc -l | tee "$ART/fate-test-count.txt"
make -j"$(nproc)" fate | tee "$ART/fate-baseline.log"
make fate-clear-reports
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
git diff --numstat | tee "$ART/diff-numstat.txt"
[[ "$(cat "$ART/diff-numstat.txt")" == $'1\t1\tlibavformat/dv.c' ]]
git diff > "$ART/patch.diff"
./tools/patcheck "$ART/patch.diff" > "$ART/patcheck.txt"
make -j"$(nproc)" ffmpeg ffprobe
make fate-clear-reports
make -j"$(nproc)" fate | tee "$ART/fate-patched.log"
make fate-clear-reports
printf 'PASS\n' > "$ART/result.txt"
