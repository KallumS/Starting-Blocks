#!/usr/bin/env bash
# Builds the VST3 and CLAP plugins into plugin/out/. On a Mac they hold both
# Apple Silicon and Intel; elsewhere they are for the machine building them
# (which is how they are compile-checked on Linux).
#
#   plugin/build.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
D="$HERE/deps"
mkdir -p "$D"

fetch() {   # fetch <dir> <url> <tag>
  if [ ! -f "$D/$1/.tag-$3" ]; then
    rm -rf "${D:?}/$1"
    git clone -q --depth 1 --branch "$3" --recurse-submodules --shallow-submodules "$2" "$D/$1"
    touch "$D/$1/.tag-$3"
  fi
}
fetch JUCE https://github.com/juce-framework/JUCE 8.0.6
fetch lua https://github.com/lua/lua v5.4.7
fetch imgui https://github.com/ocornut/imgui v1.91.9b
fetch clap-juce-extensions https://github.com/free-audio/clap-juce-extensions main

cmake -S "$HERE" -B "$HERE/build" -DCMAKE_BUILD_TYPE=Release ${CMAKE_ARGS:-}
cmake --build "$HERE/build" --config Release -j"$(sysctl -n hw.ncpu 2>/dev/null || nproc)" \
  --target StartingBlocks_VST3 StartingBlocks_CLAP ${EXTRA_TARGETS:-}
rm -rf "$HERE/out"; mkdir -p "$HERE/out"
find "$HERE/build" -path '*_artefacts*' \( -name '*.vst3' -o -name '*.clap' \) -prune \
  -exec cp -R {} "$HERE/out/" \;
ls "$HERE/out"
