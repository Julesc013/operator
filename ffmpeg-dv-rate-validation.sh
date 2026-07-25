#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C TZ=UTC

FFMPEG_REF="${FFMPEG_REF:?FFMPEG_REF is required}"
FFMPEG_LABEL="${FFMPEG_LABEL:?FFMPEG_LABEL is required}"
ROOT="$(pwd)"
WORK="$ROOT/work-$FFMPEG_LABEL"
ART="$ROOT/artifacts/$FFMPEG_LABEL"
SRC="$WORK/ffmpeg"
BIN="$WORK/bin"
MEDIA="$WORK/media"
PROBES="$ART/probes"
CHECKS="$ART/checks"
mkdir -p "$WORK" "$ART" "$BIN" "$MEDIA" "$PROBES" "$CHECKS"
exec > >(tee "$ART/run.log") 2>&1

section() { printf '\n===== %s =====\n' "$*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

section "Clone and pin FFmpeg"
git clone --filter=blob:none https://github.com/FFmpeg/FFmpeg.git "$SRC"
git -C "$SRC" checkout --detach "$FFMPEG_REF"
FFMPEG_COMMIT="$(git -C "$SRC" rev-parse HEAD)"
git -C "$SRC" log -1 --format='%H%n%ad%n%s' --date=iso-strict | tee "$ART/source.txt"

section "Configure and build baseline"
cd "$SRC"
./configure \
  --disable-doc \
  --disable-debug \
  --disable-network \
  --disable-autodetect \
  --disable-x86asm \
  --enable-werror \
  --extra-cflags='-O2 -g -fno-omit-frame-pointer'
make -j"$(nproc)" ffmpeg ffprobe
cp ffmpeg "$BIN/ffmpeg-baseline"
cp ffprobe "$BIN/ffprobe-baseline"
"$BIN/ffmpeg-baseline" -version | head -n 6 | tee "$ART/baseline-version.txt"
ldd "$BIN/ffmpeg-baseline" | tee "$ART/baseline-ldd.txt"

FATE_WANTED=(
  fate-lavf-dv
  fate-lavf-dv_pal
  fate-lavf-dv_ntsc
  fate-vsynth1-dv
  fate-vsynth1-dv-411
  fate-vsynth1-dv-50
  fate-vsynth1-dv-hd
  fate-vsynth1-dv-fhd
)
mapfile -t FATE_AVAILABLE < <(make -s fate-list)
FATE_TARGETS=()
for wanted in "${FATE_WANTED[@]}"; do
  if printf '%s\n' "${FATE_AVAILABLE[@]}" | grep -Fxq "$wanted"; then
    FATE_TARGETS+=("$wanted")
  else
    fail "required FATE target is unavailable: $wanted"
  fi
done

section "Run baseline DV FATE tests"
make -j"$(nproc)" "${FATE_TARGETS[@]}" | tee "$ART/fate-baseline.log"

section "Apply exactly one production-line change"
python3 - <<'PY'
from pathlib import Path
p = Path('libavformat/dv.c')
s = p.read_text()
old = '    c->vst->avg_frame_rate = av_inv_q(c->vst->time_base);'
new = '    c->vst->avg_frame_rate = av_inv_q(c->sys->time_base);'
count = s.count(old)
if count != 1:
    raise SystemExit(f'expected exactly one target line, found {count}')
p.write_text(s.replace(old, new, 1))
PY
git diff --check
git diff -- libavformat/dv.c | tee "$ART/ffmpeg-dv-avg-frame-rate.patch"
[[ "$(git diff --numstat)" == $'1\t1\tlibavformat/dv.c' ]] || fail "production diff is not exactly 1 insertion/1 deletion in libavformat/dv.c"

section "Incrementally rebuild patched binaries"
make -j"$(nproc)" ffmpeg ffprobe
cp ffmpeg "$BIN/ffmpeg-patched"
cp ffprobe "$BIN/ffprobe-patched"
"$BIN/ffmpeg-patched" -version | head -n 6 | tee "$ART/patched-version.txt"

section "Run patched DV FATE tests"
make -j"$(nproc)" "${FATE_TARGETS[@]}" | tee "$ART/fate-patched.log"
cd "$ROOT"

BASE_FFMPEG="$BIN/ffmpeg-baseline"
BASE_FFPROBE="$BIN/ffprobe-baseline"
PATCH_FFMPEG="$BIN/ffmpeg-patched"
PATCH_FFPROBE="$BIN/ffprobe-patched"

section "Generate all FFmpeg DV/DVCPRO profiles"
gen_dv() {
  local name="$1" size="$2" rate="$3" pix_fmt="$4"
  "$BASE_FFMPEG" -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=size=${size}:rate=${rate}" \
    -frames:v 6 -c:v dvvideo -pix_fmt "$pix_fmt" -f dv "$MEDIA/$name.dv"
}
gen_dv ntsc_dv25          720x480   30000/1001 yuv411p
gen_dv pal_dv25           720x576   25         yuv420p
gen_dv pal_dv25_411       720x576   25         yuv411p
gen_dv ntsc_dvcpro50      720x480   30000/1001 yuv422p
gen_dv pal_dvcpro50       720x576   25         yuv422p
gen_dv dvcprohd_1080i5994 1280x1080 30000/1001 yuv422p
gen_dv dvcprohd_1080i50   1440x1080 25         yuv422p
gen_dv dvcprohd_720p5994  960x720   60000/1001 yuv422p
gen_dv dvcprohd_720p50    960x720   50         yuv422p

"$BASE_FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=720x480:rate=30000/1001' \
  -f lavfi -i 'sine=frequency=997:sample_rate=48000' \
  -frames:v 30 -shortest -map 0:v:0 -map 1:a:0 \
  -c:v dvvideo -pix_fmt yuv411p -c:a pcm_s16le -ar 48000 -ac 2 \
  -timecode '01:02:03;04' -f dv "$MEDIA/ntsc_av_timecode.dv"
"$BASE_FFMPEG" -hide_banner -loglevel error -y \
  -f lavfi -i 'testsrc2=size=720x576:rate=25' \
  -f lavfi -i 'sine=frequency=1009:sample_rate=48000' \
  -frames:v 25 -shortest -map 0:v:0 -map 1:a:0 \
  -c:v dvvideo -pix_fmt yuv420p -c:a pcm_s16le -ar 48000 -ac 2 \
  -timecode '02:03:04:05' -f dv "$MEDIA/pal_av_timecode.dv"

cat > "$WORK/profile-expectations.tsv" <<'EOF'
ntsc_dv25	30000/1001	2002	120000	720	480	yuv411p
pal_dv25	25/1	2400	144000	720	576	yuv420p
pal_dv25_411	25/1	2400	144000	720	576	yuv411p
ntsc_dvcpro50	30000/1001	2002	240000	720	480	yuv422p
pal_dvcpro50	25/1	2400	288000	720	576	yuv422p
dvcprohd_1080i5994	30000/1001	2002	480000	1280	1080	yuv422p
dvcprohd_1080i50	25/1	2400	576000	1440	1080	yuv422p
dvcprohd_720p5994	60000/1001	1001	240000	960	720	yuv422p
dvcprohd_720p50	50/1	1200	288000	960	720	yuv422p
EOF

probe_video() {
  "$1" -v error -select_streams v:0 -show_streams -show_packets -show_format -of json "$2" > "$3"
}
for file in "$MEDIA"/*.dv; do
  name="$(basename "$file" .dv)"
  probe_video "$BASE_FFPROBE" "$file" "$PROBES/$name.baseline.json"
  probe_video "$PATCH_FFPROBE" "$file" "$PROBES/$name.patched.json"
done

section "Assert metadata and packet invariants"
python3 - "$WORK/profile-expectations.tsv" "$PROBES" <<'PY'
import copy, json, pathlib, sys
expect_path, probes_path = map(pathlib.Path, sys.argv[1:])
expect = {}
for line in expect_path.read_text().splitlines():
    name, rate, duration, size, width, height, pix = line.split('\t')
    expect[name] = dict(rate=rate, duration=int(duration), size=int(size),
                        width=int(width), height=int(height), pix_fmt=pix)
def stream(obj):
    found = [s for s in obj['streams'] if s.get('codec_type') == 'video']
    assert len(found) == 1
    return found[0]
def normalise(obj):
    obj = copy.deepcopy(obj)
    for s in obj.get('streams', []):
        if s.get('codec_type') == 'video':
            s.pop('avg_frame_rate', None)
    return obj
rows=[]
for name,e in expect.items():
    b=json.loads((probes_path/f'{name}.baseline.json').read_text())
    p=json.loads((probes_path/f'{name}.patched.json').read_text())
    bs,ps=stream(b),stream(p)
    assert bs['avg_frame_rate']=='60000/1',(name,bs['avg_frame_rate'])
    assert ps['avg_frame_rate']==e['rate'],(name,ps['avg_frame_rate'])
    for s in (bs,ps):
        assert s['r_frame_rate']==e['rate'],(name,s['r_frame_rate'])
        assert s['time_base']=='1/60000',(name,s['time_base'])
        assert int(s['width'])==e['width'] and int(s['height'])==e['height']
        assert s['pix_fmt']==e['pix_fmt']
    assert b.get('packets',[])==p.get('packets',[]),f'{name}: packet metadata changed'
    packets=b.get('packets',[])
    assert len(packets)==6,(name,len(packets))
    for pkt in packets:
        assert int(pkt['duration'])==e['duration'],(name,pkt.get('duration'))
        assert int(pkt['size'])==e['size'],(name,pkt.get('size'))
    assert normalise(b)==normalise(p),f'{name}: change exceeded avg_frame_rate'
    rows.append((name,bs['avg_frame_rate'],ps['avg_frame_rate'],ps['time_base'],e['duration']))
out=['profile\tbaseline_avg\tpatched_avg\ttime_base\tpacket_duration']
out += ['\t'.join(map(str,row)) for row in rows]
(probes_path.parent/'profile-results.tsv').write_text('\n'.join(out)+'\n')
PY

section "Compare decoding, audio, timecode, and seeking"
for file in "$MEDIA"/*.dv; do
  name="$(basename "$file" .dv)"
  "$BASE_FFMPEG" -hide_banner -loglevel error -i "$file" -map 0:v:0 -f framecrc - > "$CHECKS/$name.video.baseline.framecrc"
  "$PATCH_FFMPEG" -hide_banner -loglevel error -i "$file" -map 0:v:0 -f framecrc - > "$CHECKS/$name.video.patched.framecrc"
  cmp "$CHECKS/$name.video.baseline.framecrc" "$CHECKS/$name.video.patched.framecrc"
  "$BASE_FFMPEG" -hide_banner -loglevel error -ss 0.04 -i "$file" -map 0:v:0 -frames:v 2 -f framecrc - > "$CHECKS/$name.seek.baseline.framecrc"
  "$PATCH_FFMPEG" -hide_banner -loglevel error -ss 0.04 -i "$file" -map 0:v:0 -frames:v 2 -f framecrc - > "$CHECKS/$name.seek.patched.framecrc"
  cmp "$CHECKS/$name.seek.baseline.framecrc" "$CHECKS/$name.seek.patched.framecrc"
done
for name in ntsc_av_timecode pal_av_timecode; do
  file="$MEDIA/$name.dv"
  "$BASE_FFMPEG" -hide_banner -loglevel error -i "$file" -map 0:a:0 -f framecrc - > "$CHECKS/$name.audio.baseline.framecrc"
  "$PATCH_FFMPEG" -hide_banner -loglevel error -i "$file" -map 0:a:0 -f framecrc - > "$CHECKS/$name.audio.patched.framecrc"
  cmp "$CHECKS/$name.audio.baseline.framecrc" "$CHECKS/$name.audio.patched.framecrc"
  "$BASE_FFPROBE" -v error -show_entries format_tags=timecode -of json "$file" > "$CHECKS/$name.timecode.baseline.json"
  "$PATCH_FFPROBE" -v error -show_entries format_tags=timecode -of json "$file" > "$CHECKS/$name.timecode.patched.json"
  cmp "$CHECKS/$name.timecode.baseline.json" "$CHECKS/$name.timecode.patched.json"
done

section "Construct and test AVI Type 1"
make_type1() {
  local source="$1" output="$2" temp="$output.video-only.avi"
  "$BASE_FFMPEG" -hide_banner -loglevel error -y -i "$source" \
    -map 0:v:0 -c:v copy -an -fflags +bitexact -flags +bitexact -map_metadata -1 -f avi "$temp"
  python3 - "$temp" "$output" <<'PY'
from pathlib import Path
import sys
src,dst=map(Path,sys.argv[1:])
data=bytearray(src.read_bytes())
pos=data.find(b'strh')
if pos<0 or data[pos+8:pos+12]!=b'vids': raise SystemExit('AVI video strh not found')
if data[pos+12:pos+16] not in (b'dvsd',b'dvhd',b'dvsl'): raise SystemExit('unexpected DV handler')
data[pos+8:pos+12]=b'iavs'
dst.write_bytes(data)
PY
  rm -f "$temp"
}
make_type1 "$MEDIA/ntsc_av_timecode.dv" "$MEDIA/ntsc_type1.avi"
make_type1 "$MEDIA/pal_av_timecode.dv" "$MEDIA/pal_type1.avi"
for name in ntsc_type1 pal_type1; do
  "$BASE_FFPROBE" -v error -show_streams -show_packets -show_format -of json "$MEDIA/$name.avi" > "$PROBES/$name.baseline.json"
  "$PATCH_FFPROBE" -v error -show_streams -show_packets -show_format -of json "$MEDIA/$name.avi" > "$PROBES/$name.patched.json"
  for kind in video audio; do
    maparg='0:v:0'; [[ "$kind" == audio ]] && maparg='0:a:0'
    "$BASE_FFMPEG" -hide_banner -loglevel error -i "$MEDIA/$name.avi" -map "$maparg" -f framecrc - > "$CHECKS/$name.$kind.baseline.framecrc"
    "$PATCH_FFMPEG" -hide_banner -loglevel error -i "$MEDIA/$name.avi" -map "$maparg" -f framecrc - > "$CHECKS/$name.$kind.patched.framecrc"
    cmp "$CHECKS/$name.$kind.baseline.framecrc" "$CHECKS/$name.$kind.patched.framecrc"
  done
done
python3 - "$PROBES" <<'PY'
import copy,json,pathlib,sys
root=pathlib.Path(sys.argv[1])
for name,rate in [('ntsc_type1','30000/1001'),('pal_type1','25/1')]:
    b=json.loads((root/f'{name}.baseline.json').read_text())
    p=json.loads((root/f'{name}.patched.json').read_text())
    bv=next(s for s in b['streams'] if s.get('codec_type')=='video')
    pv=next(s for s in p['streams'] if s.get('codec_type')=='video')
    assert bv['avg_frame_rate']=='60000/1'; assert pv['avg_frame_rate']==rate
    assert bv['r_frame_rate']==pv['r_frame_rate']==rate
    assert bv['time_base']==pv['time_base']=='1/60000'
    for obj in (b,p):
        for s in obj['streams']:
            if s.get('codec_type')=='video': s.pop('avg_frame_rate',None)
    assert b==p,f'{name}: change exceeded avg_frame_rate'
PY

section "Negative controls: Type 2 AVI, MOV, and MXF"
"$BASE_FFMPEG" -hide_banner -loglevel error -y -i "$MEDIA/ntsc_av_timecode.dv" -map 0:v:0 -map 0:a:0 -c copy -fflags +bitexact -flags +bitexact -map_metadata -1 "$MEDIA/ntsc_type2.avi"
"$BASE_FFMPEG" -hide_banner -loglevel error -y -i "$MEDIA/pal_av_timecode.dv" -map 0:v:0 -map 0:a:0 -c copy -fflags +bitexact -flags +bitexact -map_metadata -1 "$MEDIA/pal_dv.mov"
"$BASE_FFMPEG" -hide_banner -loglevel error -y -f lavfi -i 'testsrc2=size=720x576:rate=25' -frames:v 6 -vf 'setdar=16/9,setfield=bff' -c:v dvvideo -pix_fmt yuv422p -b:v 50000k -fflags +bitexact -flags +bitexact -map_metadata -1 -f mxf "$MEDIA/pal_dvcpro50.mxf"
for control in ntsc_type2.avi pal_dv.mov pal_dvcpro50.mxf; do
  safe="${control//./_}"
  "$BASE_FFPROBE" -v error -show_streams -show_packets -show_format -of json "$MEDIA/$control" > "$PROBES/$safe.baseline.json"
  "$PATCH_FFPROBE" -v error -show_streams -show_packets -show_format -of json "$MEDIA/$control" > "$PROBES/$safe.patched.json"
  cmp "$PROBES/$safe.baseline.json" "$PROBES/$safe.patched.json"
done

section "Differential stream-copy outputs"
for mux in avi mov matroska; do
  ext="$mux"; [[ "$mux" == matroska ]] && ext=mkv
  for variant in baseline patched; do
    ff="$BASE_FFMPEG"; [[ "$variant" == patched ]] && ff="$PATCH_FFMPEG"
    "$ff" -hide_banner -loglevel error -y -i "$MEDIA/ntsc_av_timecode.dv" \
      -map 0:v:0 -map 0:a:0 -c copy -fflags +bitexact -flags +bitexact -map_metadata -1 \
      -f "$mux" "$MEDIA/remux-$variant.$ext"
    "$PATCH_FFPROBE" -v error -show_streams -show_packets -show_format -of json "$MEDIA/remux-$variant.$ext" > "$PROBES/remux-$mux.$variant.json"
  done
  if cmp -s "$MEDIA/remux-baseline.$ext" "$MEDIA/remux-patched.$ext"; then
    echo "$mux: byte-identical" | tee -a "$ART/remux-results.txt"
  else
    echo "$mux: bytes differ; checking semantic and decoded equivalence" | tee -a "$ART/remux-results.txt"
  fi
  "$PATCH_FFMPEG" -hide_banner -loglevel error -i "$MEDIA/remux-baseline.$ext" -map 0:v:0 -f framecrc - > "$CHECKS/remux-$mux.baseline.framecrc"
  "$PATCH_FFMPEG" -hide_banner -loglevel error -i "$MEDIA/remux-patched.$ext" -map 0:v:0 -f framecrc - > "$CHECKS/remux-$mux.patched.framecrc"
  cmp "$CHECKS/remux-$mux.baseline.framecrc" "$CHECKS/remux-$mux.patched.framecrc"
  sha256sum "$MEDIA/remux-baseline.$ext" "$MEDIA/remux-patched.$ext" >> "$ART/remux-sha256.txt"
done

section "Truncation and corrupt-payload robustness"
python3 - "$MEDIA/ntsc_dv25.dv" "$MEDIA/ntsc_dv25-truncated.dv" "$MEDIA/ntsc_dv25-corrupt.dv" <<'PY'
from pathlib import Path
import sys
src,trunc,corrupt=map(Path,sys.argv[1:])
data=bytearray(src.read_bytes())
trunc.write_bytes(data[:-60000])
for off in range(13024,min(len(data),16096),113): data[off]^=0x5a
corrupt.write_bytes(data)
PY
for variant in truncated corrupt; do
  file="$MEDIA/ntsc_dv25-$variant.dv"
  set +e
  "$BASE_FFMPEG" -hide_banner -loglevel warning -i "$file" -map 0:v:0 -f framecrc - > "$CHECKS/$variant.baseline.framecrc" 2> "$CHECKS/$variant.baseline.stderr"; bs=$?
  "$PATCH_FFMPEG" -hide_banner -loglevel warning -i "$file" -map 0:v:0 -f framecrc - > "$CHECKS/$variant.patched.framecrc" 2> "$CHECKS/$variant.patched.stderr"; ps=$?
  set -e
  [[ "$bs" -eq "$ps" ]] || fail "$variant exit status changed: $bs -> $ps"
  cmp "$CHECKS/$variant.baseline.framecrc" "$CHECKS/$variant.patched.framecrc"
done

section "Final report"
sha256sum "$BIN/ffmpeg-baseline" "$BIN/ffmpeg-patched" "$BIN/ffprobe-baseline" "$BIN/ffprobe-patched" > "$ART/binary-sha256.txt"
cat > "$ART/summary.md" <<EOF
# FFmpeg DV average-frame-rate validation: $FFMPEG_LABEL

- Source ref: \`$FFMPEG_REF\`
- Source commit: \`$FFMPEG_COMMIT\`
- Production diff: exactly one insertion and one deletion in \`libavformat/dv.c\`
- Baseline and patched builds with \`--enable-werror\`: PASS
- Baseline and patched targeted DV FATE tests: PASS
- Nine DV/DVCPRO profile metadata and packet invariants: PASS
- Decoded video, audio, timecode, and seek equivalence: PASS
- AVI Type 1 behavior: PASS
- AVI Type 2, MOV, and MXF negative controls: PASS
- AVI/MOV/Matroska stream-copy decoded equivalence: PASS
- Truncated and corrupt-input equivalence: PASS

Only \`AVStream.avg_frame_rate\` changes for raw DV and AVI Type 1, from the 60,000-Hz timestamp scale to the detected DV profile frame rate. Stream time base, packet PTS/DTS/duration/size, decoding, audio, timecode, seeking, and unrelated wrapper paths remain unchanged.
EOF
cat "$ART/summary.md"
