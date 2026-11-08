#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
output_dir="$project_dir/build/fedora"
mode="${1:---release}"

if ! command -v odin >/dev/null 2>&1; then
	echo "error: Odin is not installed or is not on PATH" >&2
	exit 1
fi

if ! command -v pkg-config >/dev/null 2>&1; then
	echo "error: pkg-config is required (sudo dnf install pkgconf-pkg-config)" >&2
	exit 1
fi

if ! pkg-config --exists sdl3; then
	echo "error: SDL3 development package is missing" >&2
	echo "install them with: sudo dnf install SDL3-devel" >&2
	exit 1
fi

bash "$project_dir/font/build.sh"


mkdir -p "$output_dir"

case "$mode" in
	--debug)
		build_flags=(-debug)
		;;
	--release)
		build_flags=(-o:speed)
		;;
	*)
		echo "usage: $0 [--release|--debug]" >&2
		exit 2
		;;
esac

mkdir -p "$project_dir/odin_shared"
ln -sfnT ../shared/clay/bindings/odin/clay-odin "$project_dir/odin_shared/clay"

odin build "$project_dir" \
	"-collection:shared=$project_dir/odin_shared" \
	"-out:$output_dir/dope-notes" \
	-no-rpath \
	-reloc-mode:pic \
	'-extra-linker-flags:-pie' \
	"${build_flags[@]}"

echo "built $output_dir/dope-notes"
