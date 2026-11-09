#!/usr/bin/env bash
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  '') install=true ;;
  --skip-install) install=false ;;
  *) echo "Usage: bash setup.sh [--skip-install]" >&2; exit 2 ;;
esac
if $install; then
  sudo_cmd=()
  if [[ "$EUID" != 0 ]]; then sudo_cmd=(sudo); fi
  if command -v dnf >/dev/null 2>&1; then
    "${sudo_cmd[@]}" dnf install -y git clang binutils pkgconf-pkg-config SDL3-devel SDL3_image-devel cmark-devel freetype-devel
  elif command -v apt-get >/dev/null 2>&1; then
    "${sudo_cmd[@]}" apt-get update
    "${sudo_cmd[@]}" apt-get install -y git build-essential clang pkg-config libfreetype6-dev libcmark-dev libsdl3-dev libsdl3-image-dev
  else
    echo 'Unsupported package manager. Install the README prerequisites, then rerun with --skip-install.' >&2
    exit 1
  fi
fi
for tool in git odin clang ar pkg-config; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing $tool on PATH. See README.md." >&2; exit 1; }
done
pkg-config --print-errors --exists freetype2 sdl3 SDL3_image libcmark
git -C "$root" submodule sync --recursive
git -C "$root" submodule update --init --recursive
mkdir -p "$root/shared/clay/bindings/odin/clay-odin/linux"
clang -x c -DCLAY_IMPLEMENTATION -O2 -fPIC -c "$root/shared/clay/clay.h" \
  -o "$root/shared/clay/bindings/odin/clay-odin/linux/clay.o"
ar rcs "$root/shared/clay/bindings/odin/clay-odin/linux/clay.a" \
  "$root/shared/clay/bindings/odin/clay-odin/linux/clay.o"
bash "$root/build.sh" --debug
echo "Setup complete. Run from the repository root: ./build/fedora/dope-notes"
