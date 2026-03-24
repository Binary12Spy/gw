#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_SCRIPT="$SCRIPT_DIR/gw.sh"
INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_BIN_DIR/gw"

if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required but was not found in PATH." >&2
    exit 1
fi

if [[ ! -f "$SOURCE_SCRIPT" ]]; then
    echo "Error: gw.sh not found at $SOURCE_SCRIPT" >&2
    exit 1
fi

mkdir -p "$INSTALL_BIN_DIR"
cp "$SOURCE_SCRIPT" "$TARGET"
chmod +x "$TARGET"

echo "Installed gw to $TARGET"

SHELL_BLOCK_START="# >>> gw shell magic >>>"
SHELL_BLOCK_END="# <<< gw shell magic <<<"
SHELL_BLOCK="# >>> gw shell magic >>>
export PATH=\"$INSTALL_BIN_DIR:\$PATH\"
gws() {
    local p
    p=\"\$(gw switch \"\$@\")\" && cd \"\$p\"
}
# <<< gw shell magic <<<"

append_block_if_missing() {
    local rc_file="$1"

    if [[ ! -f "$rc_file" ]]; then
        touch "$rc_file"
    fi

    if grep -qF "$SHELL_BLOCK_START" "$rc_file"; then
        echo "Shell helper already present in $rc_file"
        return 0
    fi

    {
        echo
        echo "$SHELL_BLOCK"
    } >> "$rc_file"

    echo "Added gws helper to $rc_file"
}

append_block_if_missing "$HOME/.bashrc"
append_block_if_missing "$HOME/.zshrc"

if ! echo ":$PATH:" | grep -q ":$INSTALL_BIN_DIR:"; then
    echo
    echo "Note: $INSTALL_BIN_DIR has been added to PATH in your shell config."
    echo "Reload your shell config to apply it in this session."
fi

echo
echo "Next steps:"
echo "  1) Reload your shell config: source ~/.bashrc or source ~/.zshrc"
echo "  2) Verify install: gw --help"
echo "  3) Use helper: gws <branch>"
