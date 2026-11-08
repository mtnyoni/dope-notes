#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$project_dir/build"
package_dir="$build_dir/packages"
source_dir="$build_dir/sources"
odin_version="dev-2026-07a"
odin_archive="Odin-$odin_version.tar.gz"
odin_url="https://github.com/odin-lang/Odin/archive/$odin_version/$odin_archive"
odin_sha256="8f4f02fd9a3426b441cd0dfbe0aca1b95fd93c95d86940fcb4417ef6044c83cd"

source_only=false
if [[ "${1:-}" == "--source-only" ]]; then
	source_only=true
	shift
fi

if (( $# != 1 )); then
	echo "usage: $0 [--source-only] VERSION-RELEASE" >&2
	echo "example: $0 --source-only 0.1.2-1" >&2
	exit 2
fi

package_version="$1"

if [[ ! "$package_version" =~ ^([0-9]+([.][0-9]+)*)-([0-9]+)$ ]]; then
	echo "error: version must use version-release format, for example 0.1.0-1" >&2
	exit 2
fi
version="${BASH_REMATCH[1]}"
release="${BASH_REMATCH[3]}"

if [[ "$(uname -m)" != "x86_64" ]]; then
	echo "error: the packaged Odin toolchain currently supports x86_64 only" >&2
	exit 1
fi

for command_name in curl git rpmbuild sha256sum tar; do
	if ! command -v "$command_name" >/dev/null 2>&1; then
		echo "error: $command_name is required" >&2
		exit 1
	fi
done

if ! $source_only && ! command -v desktop-file-validate >/dev/null 2>&1; then
	echo "error: desktop-file-validate is required for a local binary build" >&2
	exit 1
fi

mkdir -p "$build_dir" "$package_dir" "$source_dir"

odin_path="$source_dir/$odin_archive"
if [[ ! -f "$odin_path" ]] || ! printf '%s  %s\n' "$odin_sha256" "$odin_path" | sha256sum --check --status; then
	download_path="$odin_path.download"
	curl --fail --location --output "$download_path" "$odin_url"
	printf '%s  %s\n' "$odin_sha256" "$download_path" | sha256sum --check --status
	mv -f "$download_path" "$odin_path"
fi

source_archive="$source_dir/dope-notes-$version.tar.gz"
source_date_epoch="$(git -C "$project_dir" log -1 --format=%ct 2>/dev/null || date +%s)"
git -C "$project_dir" ls-files -z | tar \
	--directory="$project_dir" \
	--null \
	--files-from=- \
	--sort=name \
	--mtime="@$source_date_epoch" \
	--owner=0 \
	--group=0 \
	--numeric-owner \
	--transform="s,^,dope-notes-$version/," \
	--create \
	--gzip \
	--file="$source_archive"

rpm_topdir="$(mktemp -d "$build_dir/rpmbuild.XXXXXX")"
trap 'rm -rf -- "$rpm_topdir"' EXIT

mkdir -p \
	"$rpm_topdir/BUILD" \
	"$rpm_topdir/BUILDROOT" \
	"$rpm_topdir/RPMS" \
	"$rpm_topdir/SOURCES" \
	"$rpm_topdir/SPECS" \
	"$rpm_topdir/SRPMS"

install -m0644 "$source_archive" "$rpm_topdir/SOURCES/"
install -m0644 "$odin_path" "$rpm_topdir/SOURCES/"
install -m0644 "$project_dir/packaging/dope-notes.spec" "$rpm_topdir/SPECS/dope-notes.spec"
sed -i \
	-e "s/^%{!?dope-notes_version:.*$/%global dope-notes_version $version/" \
	-e "s/^%{!?dope-notes_release:.*$/%global dope-notes_release $release/" \
	"$rpm_topdir/SPECS/dope-notes.spec"
changelog_date="$(LC_ALL=C date --utc --date="@$source_date_epoch" '+%a %b %d %Y')"
printf '\n%%changelog\n* %s Tawanda M Nyoni <noreply@example.invalid> - %s-%s\n- Build release %s-%s\n' \
	"$changelog_date" "$version" "$release" "$version" "$release" \
	>> "$rpm_topdir/SPECS/dope-notes.spec"

rpmbuild_mode="-ba"
if $source_only; then
	rpmbuild_mode="-bs"
fi

rpmbuild \
	--define "_topdir $rpm_topdir" \
	--define "dope-notes_version $version" \
	--define "dope-notes_release $release" \
	"$rpmbuild_mode" "$rpm_topdir/SPECS/dope-notes.spec"

mapfile -t built_packages < <(
	find "$rpm_topdir/RPMS" "$rpm_topdir/SRPMS" \
		-type f -name 'dope-notes-*.rpm' -print | sort
)
if (( ${#built_packages[@]} == 0 )); then
	echo "error: rpmbuild completed without producing an RPM" >&2
	exit 1
fi

for package in "${built_packages[@]}"; do
	output="$package_dir/$(basename -- "$package")"
	install -m0644 "$package" "$output"
	echo "built $output"
done
