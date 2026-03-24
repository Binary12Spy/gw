#!/usr/bin/env bash

set -euo pipefail

INSTALL_BIN_DIR="${INSTALL_BIN_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_BIN_DIR/gw"
SHELL_BLOCK_START="# >>> gw shell magic >>>"
SHELL_BLOCK_END="# <<< gw shell magic <<<"

remove_shell_block() {
    local rc_file="$1"

    if [[ ! -f "$rc_file" ]]; then
        return 0
    fi

    if ! grep -qF "$SHELL_BLOCK_START" "$rc_file"; then
        echo "No gw shell helper block found in $rc_file"
        return 0
    fi

    local tmp
    tmp="$(mktemp)"

    awk -v start="$SHELL_BLOCK_START" -v end="$SHELL_BLOCK_END" '
        $0 == start { skip=1; next }
        $0 == end { skip=0; next }
        !skip { print }
    ' "$rc_file" > "$tmp"

    mv "$tmp" "$rc_file"
    echo "Removed gw shell helper block from $rc_file"
}

if [[ -f "$TARGET" ]]; then
    rm -f "$TARGET"
    echo "Removed $TARGET"
else
    echo "No installed gw binary at $TARGET"
fi

remove_shell_block "$HOME/.bashrc"
remove_shell_block "$HOME/.zshrc"

echo
echo "Uninstall complete."
echo "Reload your shell config: source ~/.bashrc or source ~/.zshrc"
