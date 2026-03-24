# gw

A small git worktree manager that mirrors branch names to directory paths.

`gw` keeps one bare repository and creates independent working trees as folders such as `feature/login`, `bugfix/ticket-123`, and so on.

## Requirements

- `bash` (script runtime)
- `git` (worktree operations)

## Install

### Option 1: Installer script (recommended)

From this repository root:

```bash
./install-gw.sh
```

What it does:

- Installs `gw` into `~/.local/bin/gw`
- Appends an idempotent `gws` shell-function block to `~/.bashrc` and `~/.zshrc`
- Prints reload instructions and PATH guidance if needed

### Option 2: Manual install

1. Put `gw.sh` somewhere on your `PATH` as `gw`:

```bash
mkdir -p ~/.local/bin
cp ./gw.sh ~/.local/bin/gw
chmod +x ~/.local/bin/gw
```

2. Add shell helper to your rc file (`~/.bashrc` or `~/.zshrc`):

```bash
gws() {
    local p
    p="$(gw switch "$@")" && cd "$p"
}
```

3. Reload your shell config:

```bash
source ~/.bashrc
# or
source ~/.zshrc
```

## Update

From this repository root:

```bash
bash ./update-gw.sh
```

Options:

- `bash ./update-gw.sh --pull`: first run `git pull --ff-only` in this checkout, then reinstall.

What it does:

- Re-runs the installer so `~/.local/bin/gw` is refreshed from the latest local script.
- Keeps shell helper setup idempotent.

## Uninstall

From this repository root:

```bash
bash ./uninstall-gw.sh
```

What it does:

- Removes installed binary at `~/.local/bin/gw` (or `INSTALL_BIN_DIR/gw` if overridden).
- Removes the managed `gws` helper block from `~/.bashrc` and `~/.zshrc`.

## Quick Start

```bash
# initialize managed repo from a remote/local URL
gw init <repo-url> [directory]

# enter first worktree
cd <directory>/<default-branch>

# create a new branch + worktree
gw add feature/login --new

# jump to branch worktree in your current shell
gws feature/login
```

## Commands

- `gw init <repo-url> [dir]`: Create `.bare`, `.git` pointer, `.gwroot`, and default branch worktree.
- `gw add <branch> [--new|-n]`: Add worktree for existing branch, or create branch with `--new`.
- `gw remove <branch>`: Remove branch worktree (with prompt if dirty).
- `gw list`: Show registered worktrees.
- `gw switch <branch>`: Print worktree path; auto-creates if missing.
- `gw clean`: Prune metadata and remove worktrees for local branches that no longer exist.

## Layout

```text
my_repo/
├── .gwroot
├── .bare/
├── .git
├── main/
└── feature/
    └── login/
```

## Notes

- `gws` is required to change directories in your current shell. Scripts cannot `cd` your parent shell.
- `gw switch` prints only the resulting path to stdout; status messages go to stderr so command substitution stays reliable.
- Set `GW_FORCE_ASCII=1` to force plain ASCII symbols in output.
- Set `GW_NO_COLOR=1` (or `NO_COLOR=1`) to disable ANSI colors.

## Troubleshooting

- `gw: command not found`: ensure `~/.local/bin` is in `PATH`.
- `Not inside a gw-managed repository`: run command from inside a tree containing `.gwroot`.
- `No worktree found for branch`: run `gw add <branch>` first, or use `gw switch <branch>` to auto-create.
