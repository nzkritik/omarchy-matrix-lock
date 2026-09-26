#!/bin/bash
# Rebuild rain.frag.qsb from rain.frag. Qt 6's ShaderEffect only loads shaders
# precompiled by qsb, so the .qsb is committed; run this after editing
# rain.frag, and anyone can run it to check the committed file matches.
#
# Needs qt6-shadertools (qsb).

set -euo pipefail
cd "$(dirname "$0")/.."
QSB=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
[[ -x $QSB ]] || { echo "qsb not found; install qt6-shadertools" >&2; exit 1; }
"$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o rain.frag.qsb rain.frag
echo "wrote rain.frag.qsb"
