#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
godot="${1:-godot}"
out="${SMOKE_OUTPUT_DIR:-$PWD/artifacts/scene-smoke}"
mkdir -p "$out"

check_log() {
  local logfile="$1"
  if grep -Ein '(^|[^[:alnum:]_])(SCRIPT ERROR|ERROR)(:|[[:space:]])|Failed loading resource|Resource file not found' "$logfile"; then
    echo "Godot reported an error in $logfile" >&2
    return 1
  fi
}

run_checked() {
  local log="$1"
  shift
  local status=0
  timeout 600 "$@" >"$log" 2>&1 || status=$?
  cat "$log"
  check_log "$log" || return 1
  if (( status != 0 )); then
    echo "Godot command exited $status" >&2
    return 1
  fi
}

run_checked "$out/import.log" "$godot" --headless --editor --import
for scene in match/match debug/debug_match; do
  log="$out/${scene//\//_}.log"
  run_checked "$log" "$godot" --headless --fixed-fps 30 -s tools/scene_smoke/scene_runner.gd -- \
    "--smoke-scene=res://scenes/$scene.tscn"
  grep -q 'SMOKE_OK ticks=1800 bot_acted=true' "$log"
done

for variant in hud no_hud; do
  args=("--smoke-scene=res://scenes/match/match.tscn")
  if [[ "$variant" == no_hud ]]; then args+=(--smoke-no-hud); fi
  run_checked "$out/$variant.log" xvfb-run -a -s '-screen 0 1280x720x24' \
    "$godot" --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 \
    --fixed-fps 30 --quit-after 302 --write-movie "$out/$variant.avi" \
    -s tools/scene_smoke/scene_runner.gd -- "${args[@]}"
  grep -q 'SMOKE_START.*bots=6' "$out/$variant.log"
  ffmpeg -hide_banner -loglevel error -y -i "$out/$variant.avi" \
    -vf 'select=eq(n\,300)' -frames:v 1 "$out/$variant.png"
done
python3 tools/scene_smoke/check_frame.py "$out/hud.png" "$out/no_hud.png"
