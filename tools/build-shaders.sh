#!/bin/bash
# Rebuild rain.frag.qsb from rain.frag. Qt 6's ShaderEffect only loads shaders
# precompiled by qsb, so the .qsb is committed; run this after editing
# rain.frag, and anyone can run it to check the committed file matches.
# An optional argument writes the result there instead, for comparing:
#   tools/build-shaders.sh /tmp/rain.frag.qsb && cmp /tmp/rain.frag.qsb rain.frag.qsb
#
# Needs qt6-shadertools (qsb). CI (.github/workflows/shader-provenance.yml)
# does the same comparison on every push with a pinned qsb.

set -euo pipefail
out=$(realpath -m -- "${1:-rain.frag.qsb}")
cd "$(dirname "$0")/.."
QSB=$(command -v qsb || echo /usr/lib/qt6/bin/qsb)
[[ -x $QSB ]] || { echo "qsb not found; install qt6-shadertools" >&2; exit 1; }
"$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$out" rain.frag
echo "wrote $out"
