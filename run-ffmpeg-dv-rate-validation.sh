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
# Bash expands a same-statement local initializer before assigning earlier
# names. Split the Type 1 AVI temporary path onto its own declaration.
python3 - <<'PY'
from pathlib import Path
p = Path('/tmp/ffmpeg-dv-rate-validation.sh')
s = p.read_text()
old = '  local source="$1" output="$2" temp="$output.video-only.avi"'
new = '  local source="$1" output="$2"\n  local temp="$output.video-only.avi"'
if s.count(old) != 1:
    raise SystemExit('Type 1 helper declaration not found exactly once')
p.write_text(s.replace(old, new, 1))
PY
# Keep the generated report factually aligned with the supported configure run.
sed -i 's/Baseline and patched builds with `--enable-werror`/Baseline and patched builds/' /tmp/ffmpeg-dv-rate-validation.sh
exec bash /tmp/ffmpeg-dv-rate-validation.sh
