#!/usr/bin/env bash
set -Eeuo pipefail
export LC_ALL=C TZ=UTC
REF="${FFMPEG_REF:?}"
LABEL="${FFMPEG_LABEL:?}"
ROOT="$(pwd)"
WORK="$ROOT/upstream-test-work-$LABEL"
ART="$ROOT/artifacts/upstream-test-$LABEL"
SRC="$WORK/ffmpeg"
mkdir -p "$WORK" "$ART"
exec > >(tee "$ART/run.log") 2>&1

fail() { echo "FAIL: $*" >&2; exit 1; }

git clone --filter=blob:none https://github.com/FFmpeg/FFmpeg.git "$SRC"
git -C "$SRC" checkout --detach "$REF"
cd "$SRC"
./configure --disable-doc --disable-debug --disable-network --disable-autodetect --disable-x86asm
make -j"$(nproc)" ffmpeg ffprobe

# Add two zero-new-sample FATE assertions to the already-generated PAL and NTSC
# raw-DV fixtures. They verify that avg_frame_rate is the profile rate while
# time_base remains the intentionally stable 1/60000 timestamp grid.
python3 - <<'PY'
from pathlib import Path

p=Path('tests/fate-run.sh')
s=p.read_text()
old='''    test "$3" = "disable_crc" ||\n        do_avconv_crc $file -auto_conversion_filters $DEC_OPTS -i $target_path/$file $3\n}'''
new='''    test "$3" = "disable_crc" ||\n        do_avconv_crc $file -auto_conversion_filters $DEC_OPTS -i $target_path/$file $3\n    test -z "$4" ||\n        run ffprobe${PROGSUF}${EXECSUF} -bitexact -threads $threads $4 $target_path/$file || return\n}'''
if s.count(old)!=1: raise SystemExit('lavf_container helper target not found exactly once')
p.write_text(s.replace(old,new,1))

p=Path('tests/fate/lavf-container.mak')
s=p.read_text()
old='''fate-lavf-dv_pal:  CMD = lavf_container_timecode_nodrop "-af aresample=48000:tsf=s16p -r 25 -s pal -ac 2 -f dv"\nfate-lavf-dv_ntsc:  CMD = lavf_container_timecode_drop "-af aresample=48000:tsf=s16p -pix_fmt yuv411p -s ntsc -ac 2 -f dv"'''
probe='-v error -select_streams v:0 -show_entries stream=r_frame_rate,avg_frame_rate,time_base -of default=noprint_wrappers=1'
new=f'''fate-lavf-dv_pal:  CMD = lavf_container "" "-af aresample=48000:tsf=s16p -r 25 -s pal -ac 2 -f dv -timecode 02:56:14:13" "" "{probe}"\nfate-lavf-dv_ntsc:  CMD = lavf_container "" "-af aresample=48000:tsf=s16p -pix_fmt yuv411p -s ntsc -ac 2 -f dv -timecode 02:56:14.13 -r 30000/1001" "" "{probe}"\nfate-lavf-dv_pal fate-lavf-dv_ntsc: ffprobe$(PROGSSUF)$(EXESUF)'''
if s.count(old)!=1: raise SystemExit('DV lavf command pair not found exactly once')
p.write_text(s.replace(old,new,1))

refs={
 'tests/ref/lavf/dv_pal':'r_frame_rate=25/1\navg_frame_rate=25/1\ntime_base=1/60000\n',
 'tests/ref/lavf/dv_ntsc':'r_frame_rate=30000/1001\navg_frame_rate=30000/1001\ntime_base=1/60000\n',
}
for name,extra in refs.items():
    p=Path(name)
    text=p.read_text()
    if 'avg_frame_rate=' in text: raise SystemExit(f'{name} already has rate assertions')
    p.write_text(text+extra)
PY

git diff --check
git diff -- tests/fate-run.sh tests/fate/lavf-container.mak tests/ref/lavf/dv_pal tests/ref/lavf/dv_ntsc > "$ART/test-only.patch"

# Prove the regression test fails against the unmodified production source.
make fate-clear-reports
set +e
make -j"$(nproc)" fate-lavf-dv_pal fate-lavf-dv_ntsc > "$ART/unpatched-test.log" 2>&1
unpatched_status=$?
set -e
printf '%s\n' "$unpatched_status" > "$ART/unpatched-test.status"
[[ "$unpatched_status" -ne 0 ]] || fail "regression test unexpectedly passed without production fix"
make -s fate-list-failing | sort -u > "$ART/unpatched-test.failures"
grep -Fx 'fate-lavf-dv_pal' "$ART/unpatched-test.failures" >/dev/null
grep -Fx 'fate-lavf-dv_ntsc' "$ART/unpatched-test.failures" >/dev/null
cp tests/data/fate/lavf-dv_pal.diff "$ART/unpatched-pal.diff"
cp tests/data/fate/lavf-dv_ntsc.diff "$ART/unpatched-ntsc.diff"

# Apply the single production-line correction and prove the tests now pass.
python3 - <<'PY'
from pathlib import Path
p=Path('libavformat/dv.c')
s=p.read_text()
o='    c->vst->avg_frame_rate = av_inv_q(c->vst->time_base);'
n='    c->vst->avg_frame_rate = av_inv_q(c->sys->time_base);'
if s.count(o)!=1: raise SystemExit('production target not found exactly once')
p.write_text(s.replace(o,n,1))
PY
git diff --check
make -j"$(nproc)" ffmpeg ffprobe
make fate-clear-reports
make -j"$(nproc)" fate-lavf-dv_pal fate-lavf-dv_ntsc | tee "$ART/patched-test.log"
[[ -z "$(make -s fate-list-failing)" ]] || fail "patched regression tests reported failures"

git diff --numstat > "$ART/full-diff-numstat.txt"
git diff > "$ART/0001-avformat-dv-derive-avg-frame-rate-from-profile.patch"
./tools/patcheck "$ART/0001-avformat-dv-derive-avg-frame-rate-from-profile.patch" > "$ART/patcheck.txt"

cat > "$ART/summary.md" <<EOF
# Upstream regression-test validation: $LABEL

- New media fixtures: 0
- Existing generated PAL and NTSC DV fixtures reused: yes
- Test-only patch against buggy source: FAIL as expected
- Failing tests without fix: fate-lavf-dv_pal, fate-lavf-dv_ntsc
- Same tests after one-line production fix: PASS
- Corrected PAL invariant: r=25/1, avg=25/1, time_base=1/60000
- Corrected NTSC invariant: r=30000/1001, avg=30000/1001, time_base=1/60000
- git diff --check: PASS
- tools/patcheck: completed
EOF
printf 'PASS\n' > "$ART/result.txt"
cat "$ART/summary.md"
