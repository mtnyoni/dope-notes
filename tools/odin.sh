#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/build-env.sh"
if [[ -n "${DOPE_NOTES_GITHUB_CLIENT_ID:-}" ]]; then
    exec odin "$@" "-define:DOPE_NOTES_GITHUB_CLIENT_ID=$DOPE_NOTES_GITHUB_CLIENT_ID"
fi
exec odin "$@"
