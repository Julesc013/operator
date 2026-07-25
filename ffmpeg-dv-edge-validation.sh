#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C TZ=UTC
REF="${FFMPEG_REF:?}"
LABEL="${FFMPEG_LABEL:?}"
ROOT="$(pwd)"
WORK="$ROOT/edge-work-$LABEL"
ART="$ROOT/artifacts/edge-$LABEL"
SRC="$WORK/ffmpeg"
BIN="$WORK/bin"
MEDIA="$WORK/media"
mkdir -p "$WORK" "$ART" "$BIN" "$MEDIA"
exec > >(tee "$ART/run.log") 2>&1

fail() { echo "FAIL: $*" >&2; exit 1; }

git clone --filter=blob:none https://github.com/FFmpeg/FFmpeg.git "$SRC"
git -C "$SRC" checkout --detach "$REF"
cd "$SRC"
./configure --disable-doc --disable-debug --disable-network --disable-autodetect --disable-x86asm
make -j"$(nproc)" ffmpeg ffprobe
cp ffmpeg "$BIN/ffmpeg-baseline"
cp ffprobe "$BIN/ffprobe-baseline"
cp libavformat/libavformat.a "$BIN/libavformat-baseline.a"

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
[[ "$(git diff --numstat)" == $'1\t1\tlibavformat/dv.c' ]] || fail "unexpected production diff"
git diff > "$ART/patch.diff"
./tools/patcheck "$ART/patch.diff" > "$ART/patcheck.txt"
make -j"$(nproc)" ffmpeg ffprobe
cp ffmpeg "$BIN/ffmpeg-patched"
cp ffprobe "$BIN/ffprobe-patched"
cp libavformat/libavformat.a "$BIN/libavformat-patched.a"
cd "$ROOT"

BASE_FFMPEG="$BIN/ffmpeg-baseline"
BASE_PROBE="$BIN/ffprobe-baseline"
PATCH_FFMPEG="$BIN/ffmpeg-patched"
PATCH_PROBE="$BIN/ffprobe-patched"

for variant in baseline patched; do
  nm -g --defined-only "$BIN/libavformat-$variant.a" | \
    awk 'NF >= 2 { print $(NF-1), $NF }' | sort -u > "$ART/libavformat-$variant.symbols"
done
cmp "$ART/libavformat-baseline.symbols" "$ART/libavformat-patched.symbols"

# Exercise the tenth static DV profile: IEC 61883-5 625/50, stype 1.
"$BASE_FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=720x576:rate=25' -frames:v 6 \
  -c:v dvvideo -pix_fmt yuv420p -f dv "$MEDIA/pal-standard.dv"
python3 - "$MEDIA/pal-standard.dv" "$MEDIA/pal-iec61883-stype1.dv" <<'PY'
from pathlib import Path
import sys
src,dst=map(Path,sys.argv[1:])
data=bytearray(src.read_bytes())
frame_size=144000
assert len(data)%frame_size==0
for i in range(len(data)//frame_size):
    off=i*frame_size+451
    data[off]=(data[off]&~0x1f)|1
    assert data[i*frame_size+3]&0x80
    assert data[off]&0x20
    assert data[off]&0x1f==1
dst.write_bytes(data)
PY
for variant in baseline patched; do
  probe="$BASE_PROBE"; ff="$BASE_FFMPEG"
  [[ "$variant" == patched ]] && probe="$PATCH_PROBE" && ff="$PATCH_FFMPEG"
  "$probe" -v error -select_streams v:0 -show_streams -show_packets -show_format -of json \
    "$MEDIA/pal-iec61883-stype1.dv" > "$ART/stype1-$variant.json"
  "$ff" -hide_banner -loglevel error -i "$MEDIA/pal-iec61883-stype1.dv" \
    -map 0:v:0 -f framecrc - > "$ART/stype1-$variant.framecrc"
done
cmp "$ART/stype1-baseline.framecrc" "$ART/stype1-patched.framecrc"
python3 - "$ART/stype1-baseline.json" "$ART/stype1-patched.json" <<'PY'
import json,sys
b,p=(json.load(open(x)) for x in sys.argv[1:])
def vs(o): return next(s for s in o['streams'] if s.get('codec_type')=='video')
bs,ps=vs(b),vs(p)
assert bs['avg_frame_rate']=='60000/1'
assert ps['avg_frame_rate']=='25/1'
for s in (bs,ps):
    assert s['r_frame_rate']=='25/1'
    assert s['time_base']=='1/60000'
    assert (int(s['width']),int(s['height']),s['pix_fmt'])==(720,576,'yuv420p')
assert [int(x['duration']) for x in b['packets']]==[2400]*6
assert b['packets']==p['packets']
for o in (b,p): vs(o).pop('avg_frame_rate',None)
assert b==p
PY

# Default-rate transcode and HandBrake-relevant deinterlace rates.
"$BASE_FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=720x480:rate=30000/1001' -frames:v 30 \
  -vf setfield=bff -c:v dvvideo -pix_fmt yuv411p -f dv "$MEDIA/ntsc-30.dv"
for variant in baseline patched; do
  ff="$BASE_FFMPEG"; probe="$BASE_PROBE"
  [[ "$variant" == patched ]] && ff="$PATCH_FFMPEG" && probe="$PATCH_PROBE"
  "$ff" -hide_banner -loglevel error -y -i "$MEDIA/ntsc-30.dv" \
    -map 0:v:0 -an -c:v ffv1 -level 3 "$MEDIA/default-$variant.mkv"
  "$probe" -v error -select_streams v:0 -count_frames \
    -show_entries stream=avg_frame_rate,r_frame_rate,time_base,nb_read_frames,duration \
    -show_entries packet=pts,dts,duration,size -of json "$MEDIA/default-$variant.mkv" \
    > "$ART/default-$variant.json"
  "$ff" -hide_banner -loglevel error -i "$MEDIA/default-$variant.mkv" \
    -map 0:v:0 -f framemd5 - > "$ART/default-$variant.framemd5"
  "$ff" -hide_banner -loglevel error -i "$MEDIA/ntsc-30.dv" \
    -map 0:v:0 -vf 'bwdif=mode=send_frame:parity=auto:deint=all' -f framecrc - \
    > "$ART/bwdif-frame-$variant.framecrc"
  "$ff" -hide_banner -loglevel error -i "$MEDIA/ntsc-30.dv" \
    -map 0:v:0 -vf 'bwdif=mode=send_field:parity=auto:deint=all' -f framecrc - \
    > "$ART/bwdif-field-$variant.framecrc"
done
cmp "$ART/default-baseline.framemd5" "$ART/default-patched.framemd5"
cmp "$ART/bwdif-frame-baseline.framecrc" "$ART/bwdif-frame-patched.framecrc"
cmp "$ART/bwdif-field-baseline.framecrc" "$ART/bwdif-field-patched.framecrc"
python3 - "$ART/default-baseline.json" "$ART/default-patched.json" <<'PY'
import json,sys
b,p=(json.load(open(x)) for x in sys.argv[1:])
assert b==p, 'default transcode packet/stream metadata changed'
s=b['streams'][0]
assert s['nb_read_frames']=='30'
assert s['avg_frame_rate']=='30000/1001'
assert s['r_frame_rate']=='30000/1001'
assert len(b['packets'])==30
PY

# Same-frame-size profile transition: 29.97-fps DVCPRO50 to 59.94-fps
# DVCPRO HD. Packet timing and decoder behavior must not regress.
"$BASE_FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=720x480:rate=30000/1001' -frames:v 3 \
  -c:v dvvideo -pix_fmt yuv422p -f dv "$MEDIA/dvcpro50-3.dv"
"$BASE_FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=960x720:rate=60000/1001' -frames:v 3 \
  -c:v dvvideo -pix_fmt yuv422p -f dv "$MEDIA/dvcprohd720-3.dv"
cat "$MEDIA/dvcpro50-3.dv" "$MEDIA/dvcprohd720-3.dv" > "$MEDIA/mixed-profile-240k.dv"
for variant in baseline patched; do
  probe="$BASE_PROBE"; ff="$BASE_FFMPEG"
  [[ "$variant" == patched ]] && probe="$PATCH_PROBE" && ff="$PATCH_FFMPEG"
  "$probe" -v error -select_streams v:0 -show_streams -show_packets -show_format -of json \
    "$MEDIA/mixed-profile-240k.dv" > "$ART/mixed-$variant.json"
  set +e
  "$ff" -hide_banner -loglevel warning -i "$MEDIA/mixed-profile-240k.dv" \
    -map 0:v:0 -f framecrc - > "$ART/mixed-$variant.framecrc" 2> "$ART/mixed-$variant.stderr"
  echo $? > "$ART/mixed-$variant.status"
  set -e
done
[[ "$(cat "$ART/mixed-baseline.status")" == "$(cat "$ART/mixed-patched.status")" ]]
cmp "$ART/mixed-baseline.framecrc" "$ART/mixed-patched.framecrc"
python3 - "$ART/mixed-baseline.json" "$ART/mixed-patched.json" <<'PY'
import json,sys
b,p=(json.load(open(x)) for x in sys.argv[1:])
def vs(o): return next(s for s in o['streams'] if s.get('codec_type')=='video')
bs,ps=vs(b),vs(p)
assert bs['avg_frame_rate']=='60000/1'
assert ps['avg_frame_rate'] in {'30000/1001','60000/1001'}, ps['avg_frame_rate']
assert bs['time_base']==ps['time_base']=='1/60000'
assert b['packets']==p['packets']
assert [int(x['duration']) for x in b['packets']]==[2002,2002,2002,1001,1001,1001]
for o in (b,p): vs(o).pop('avg_frame_rate',None)
assert b==p
PY

cat > "$ART/summary.md" <<EOF
# FFmpeg DV edge validation: $LABEL

- Exact one-line production diff: PASS
- Patcheck: PASS
- libavformat global symbol set unchanged: PASS
- Tenth DV profile (IEC 61883-5, 625/50 stype 1): PASS
- Default-rate FFV1 transcode: 30/30 frames, identical timing and pixels: PASS
- Single-rate and double-rate Bwdif outputs: identical: PASS
- Same-frame-size mixed-profile packet timing and behavior: unchanged: PASS
EOF
printf 'PASS\n' > "$ART/result.txt"
cat "$ART/summary.md"
