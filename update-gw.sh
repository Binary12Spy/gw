#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install-gw.sh"

if [[ ! -f "$INSTALL_SCRIPT" ]]; then
    echo "Error: install-gw.sh not found at $INSTALL_SCRIPT" >&2
    exit 1
fi

if [[ "${1:-}" == "--pull" ]]; then
    if ! command -v git >/dev/null 2>&1; then
        echo "Error: git is required for --pull" >&2
        exit 1
    fi

    if [[ ! -d "$SCRIPT_DIR/.git" ]]; then
        echo "Error: --pull requires this directory to be a git checkout" >&2
        exit 1
    fi

    echo "Updating local checkout..."
    git -C "$SCRIPT_DIR" pull --ff-only
fi

echo "Reinstalling gw from current checkout..."
bash "$INSTALL_SCRIPT"

echo
echo "Update complete."
