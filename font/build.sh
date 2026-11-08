#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
clang -O2 -c $(pkg-config --cflags freetype2) font.c -o font.o
ar rcs font.a font.o
