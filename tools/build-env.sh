#!/usr/bin/env bash
project_env_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -z "${DOPE_NOTES_GITHUB_CLIENT_ID:-}" && -f "$project_env_root/.env" ]]; then
    while IFS= read -r project_env_line || [[ -n "$project_env_line" ]]; do
        if [[ "$project_env_line" =~ ^[[:space:]]*DOPE_NOTES_GITHUB_CLIENT_ID[[:space:]]*=(.*)$ ]]; then
            project_env_value="${BASH_REMATCH[1]}"
            project_env_value="${project_env_value%%#*}"
            project_env_value="${project_env_value//\"/}"
            project_env_value="${project_env_value//\'/}"
            project_env_value="${project_env_value//[[:space:]]/}"
            export DOPE_NOTES_GITHUB_CLIENT_ID="$project_env_value"
        fi
    done < "$project_env_root/.env"
fi
if [[ ! "${DOPE_NOTES_GITHUB_CLIENT_ID:-}" =~ ^[A-Za-z0-9_]*$ ]]; then
    echo 'DOPE_NOTES_GITHUB_CLIENT_ID must be the public OAuth Client ID, not a secret.' >&2
    return 1
fi
