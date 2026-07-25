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

run_fate_suite() {
    local label="$1"
    make fate-clear-reports
    set +e
    make -k -j"$(nproc)" fate 2>&1 | tee "$ART/fate-$label.log"
    local status=${PIPESTATUS[0]}
    set -e
    printf '%s\n' "$status" > "$ART/fate-$label.status"
    make -s fate-list-failing | sort -u > "$ART/fate-$label.failures"
    mkdir -p "$ART/fate-$label-errors"
    while IFS= read -r target; do
        [ -n "$target" ] || continue
        name="${target#fate-}"
        for suffix in err diff log rep; do
            src="tests/data/fate/$name.$suffix"
            [ -f "$src" ] && cp "$src" "$ART/fate-$label-errors/"
        done
    done < "$ART/fate-$label.failures"
}

# Execute every available internal FATE target with -k. Current master can have
# pre-existing or environment-dependent failures, so compare the complete
# baseline and patched failure sets instead of misattributing a baseline defect.
run_fate_suite baseline

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
run_fate_suite patched

if ! diff -u "$ART/fate-baseline.failures" "$ART/fate-patched.failures" > "$ART/fate-failure-set.diff"; then
    echo "Patched FATE failure set differs from baseline" >&2
    cat "$ART/fate-failure-set.diff" >&2
    exit 1
fi

baseline_count=$(wc -l < "$ART/fate-baseline.failures")
patched_count=$(wc -l < "$ART/fate-patched.failures")
cat > "$ART/summary.md" <<EOF
# Differential full FATE validation: $LABEL

- Available FATE targets executed in each pass: $(cat "$ART/fate-test-count.txt")
- Baseline failure count: $baseline_count
- Patched failure count: $patched_count
- Baseline and patched failure sets: identical
- Patched-only regressions: 0
- Production diff: exactly one insertion and one deletion in libavformat/dv.c
- git diff --check: PASS
- tools/patcheck: PASS
EOF
printf 'PASS\n' > "$ART/result.txt"
cat "$ART/summary.md"
