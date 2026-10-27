#!/usr/bin/env bash
# Ставит Godot (версия из .godot-version) в ~/godot; с аргументом "templates" — ещё и шаблоны экспорта.
set -euo pipefail
cd "$(dirname "$0")/.."
VER="$(cat .godot-version)"                 # 4.7.2-stable
DIR_VER="${VER/-/.}"                         # 4.7.2.stable
BASE="https://github.com/godotengine/godot/releases/download/${VER}"
mkdir -p ~/godot
if [ ! -x ~/godot/godot ]; then
  curl -sSLf -o /tmp/godot.zip "${BASE}/Godot_v${VER}_linux.x86_64.zip"
  unzip -qo /tmp/godot.zip -d ~/godot
  mv ~/godot/Godot_v${VER}_linux.x86_64 ~/godot/godot
fi
if [ "${1:-}" = "templates" ]; then
  T=~/.local/share/godot/export_templates/${DIR_VER}
  if [ ! -f "$T/version.txt" ]; then
    curl -sSLf -o /tmp/tpl.tpz "${BASE}/Godot_v${VER}_export_templates.tpz"
    mkdir -p "$T"
    unzip -qo /tmp/tpl.tpz -d /tmp/tpl
    mv /tmp/tpl/templates/* "$T/"
  fi
fi
~/godot/godot --version
