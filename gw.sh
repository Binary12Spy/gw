#!/usr/bin/env bash
# gw - git worktree manager
# Manages worktrees mirroring branch paths as directory structure

set -euo pipefail

# Helpers

GW_USE_COLOR=0
GW_USE_UNICODE=0
SYM_INFO="->"
SYM_OK="[ok]"
SYM_WARN="[!]"
SYM_LEFT="<-"
TREE_MID="|--"
TREE_END='`--'

setup_ui() {
    local locale
    locale="${LC_ALL:-${LC_CTYPE:-${LANG:-}}}"

    if [[ "${GW_NO_COLOR:-}" == "1" ]]; then
        GW_USE_COLOR=0
    elif [[ -t 2 && "${TERM:-}" != "dumb" && -z "${NO_COLOR:-}" ]]; then
        GW_USE_COLOR=1
    fi

    if [[ "${GW_FORCE_ASCII:-}" == "1" ]]; then
        GW_USE_UNICODE=0
    elif [[ "$locale" =~ [Uu][Tt][Ff]-?8 ]]; then
        GW_USE_UNICODE=1
    fi

    if (( GW_USE_UNICODE )); then
        SYM_INFO="→"
        SYM_OK="✓"
        SYM_WARN="⚠"
        SYM_LEFT="←"
        TREE_MID="├──"
        TREE_END="└──"
    fi
}

color_print() {
    local color_code="$1"
    shift

    if (( GW_USE_COLOR )); then
        printf '\033[%sm%s\033[0m\n' "$color_code" "$*"
    else
        printf '%s\n' "$*"
    fi
}

red()    { color_print '0;31' "$*"; }
green()  { color_print '0;32' "$*"; }
yellow() { color_print '0;33' "$*"; }
blue()   { color_print '0;34' "$*"; }

die()  { red "Error: $*" >&2; exit 1; }
info() { blue "$SYM_INFO $*" >&2; }
ok()   { green "$SYM_OK $*" >&2; }
warn() { yellow "$SYM_WARN $*" >&2; }

usage() {
    cat <<EOF
$(blue "gw - git worktree manager")

Usage: gw <command> [args]

Commands:
  init   <repo-url> [dir]      Clone repo into managed structure
  add    <branch> [--new|-n]   Add worktree for branch (--new to create branch)
  remove <branch>              Remove worktree for branch
  list                         List all worktrees
  switch <branch>              Print worktree path (auto-creates if missing)
  clean                        Remove worktrees for deleted local branches

Shell function (add to .bashrc / .zshrc):
  gws() { local p; p=\$(gw switch "\$@") && cd "\$p"; }

EOF
}

# Repository root helpers

find_repo_root() {
    local current
    current="$(pwd)"

    while [[ "$current" != "/" ]]; do
        if [[ -f "$current/.gwroot" ]]; then
            echo "$current"
            return 0
        fi
        current="$(dirname "$current")"
    done

    die "Not inside a gw-managed repository (no .gwroot found). Run 'gw init' first."
}

assert_in_repo() {
    command -v git >/dev/null 2>&1 \
        || die "Required command not found: git"

    git rev-parse --git-dir &>/dev/null \
        || die "Not inside a git repository"

    find_repo_root >/dev/null
}

# Branch/path helpers

branch_to_path() {
    local branch="$1"
    echo "${branch#/}"
}

worktree_path() {
    local branch="$1"
    local repo_root
    repo_root="$(find_repo_root)"
    local rel_path
    rel_path="$(branch_to_path "$branch")"
    echo "$repo_root/$rel_path"
}

# Command implementations

cmd_init() {
    local repo_url="${1:-}"
    local target="${2:-}"
    local target_abs=""
    local target_name=""

    [[ -z "$repo_url" ]] && die "Usage: gw init <repo-url> [directory]"

    # Default directory name from repo url if not specified
    [[ -z "$target" ]] && target="$(basename "$repo_url" .git)"

    if [[ "$target" == /* ]]; then
        target_abs="$target"
    else
        target_abs="$(pwd)/$target"
    fi
    target_name="$(basename "$target_abs")"

    info "Initializing gw-managed repo at '$target_abs'"

    mkdir -p "$target_abs"

    # Bare clone
    git clone --bare "$repo_url" "$target_abs/.bare"

    # Point .git at the bare repo
    echo "gitdir: ./.bare" > "$target_abs/.git"

    # Fix remote fetch refs (common bare clone issue)
    git -C "$target_abs/.bare" config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    git -C "$target_abs/.bare" fetch --all

    # Place the marker file
    touch "$target_abs/.gwroot"

    # Detect default branch
    local default_branch
    default_branch=$(git -C "$target_abs/.bare" symbolic-ref --short HEAD 2>/dev/null || echo "main")

    # Create the main worktree
    git -C "$target_abs/.bare" worktree add "$target_abs/$default_branch" "$default_branch"

    ok "Repository ready!"
    cat <<EOF

$(green "Structure:")
  $target_name/
  ${TREE_MID} .bare/             ${SYM_LEFT} bare git repo
  ${TREE_MID} .git               ${SYM_LEFT} points to .bare
  ${TREE_MID} .gwroot            ${SYM_LEFT} gw marker file
  ${TREE_END} $default_branch/   ${SYM_LEFT} your main worktree

$(green "Next steps:")
  cd $target_abs/$default_branch
  gw add feature/my-feature
  gws feature/my-feature       ${SYM_LEFT} if you have the shell function

EOF
}

cmd_add() {
    assert_in_repo

    local branch=""
    local new_branch=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --new|-n) new_branch=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *)  branch="$1"; shift ;;
        esac
    done

    [[ -z "$branch" ]] && die "Usage: gw add <branch> [--new]"

    local wt_path
    wt_path="$(worktree_path "$branch")"

    if [[ -d "$wt_path" ]]; then
        warn "Worktree path already exists: $wt_path"
        if git worktree list | grep -qF "$wt_path"; then
            ok "Already a registered worktree, nothing to do"
            echo "$wt_path"
            return 0
        fi
    fi

    mkdir -p "$(dirname "$wt_path")"

    if $new_branch; then
        info "Creating new branch '$branch' and worktree at '$wt_path'"
        git worktree add -b "$branch" "$wt_path" >&2
    else
        info "Adding worktree for existing branch '$branch' at '$wt_path'"
        git worktree add "$wt_path" "$branch" >&2
    fi

    ok "Worktree ready at: $wt_path"
    echo "$wt_path"
}

cmd_remove() {
    assert_in_repo

    local branch="${1:-}"
    [[ -z "$branch" ]] && die "Usage: gw remove <branch>"

    local wt_path
    wt_path="$(worktree_path "$branch")"

    if ! git worktree list | grep -qF "$wt_path"; then
        die "No worktree found for branch: $branch"
    fi

    info "Removing worktree at '$wt_path'"
    git worktree remove "$wt_path" || {
        warn "Worktree has modifications."
        read -r -p "Force remove? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || die "Aborted"
        git worktree remove --force "$wt_path"
    }

    # Clean up empty parent directories
    local repo_root
    repo_root="$(find_repo_root)"
    local parent_dir
    parent_dir="$(dirname "$wt_path")"

    if [[ "$parent_dir" != "$repo_root" ]] \
        && [[ "$parent_dir" == "$repo_root"* ]] \
        && [[ -d "$parent_dir" ]] \
        && [[ -z "$(ls -A "$parent_dir")" ]]; then
        rmdir "$parent_dir"
        info "Removed empty directory: $parent_dir"
    fi

    ok "Worktree removed"
}

cmd_list() {
    assert_in_repo
    info "Worktrees:"
    git worktree list --porcelain | awk '
        /^worktree / { path=$2 }
        /^branch /   { branch=$2; sub("refs/heads/", "", branch); printf "  %-40s %s\n", branch, path }
        /^bare/      { printf "  %-40s %s\n", "(bare)", path }
    '
}

cmd_switch() {
    assert_in_repo

    local branch="${1:-}"
    [[ -z "$branch" ]] && die "Usage: gw switch <branch>"

    local wt_path
    local git_output=""
    wt_path="$(worktree_path "$branch")"

    if [[ ! -d "$wt_path" ]]; then
        info "Creating worktree for '$branch'"
        mkdir -p "$(dirname "$wt_path")"

        if ! git_output="$(git worktree add "$wt_path" "$branch" 2>&1 >/dev/null)"; then
            [[ -n "$git_output" ]] && printf '%s\n' "$git_output" >&2
            die "Failed to create worktree for branch: $branch"
        fi

        ok "Created '$branch'"
    fi

    echo "$wt_path"
}

cmd_clean() {
    assert_in_repo

    info "Pruning stale worktree metadata..."
    git worktree prune

    local pruned=0

    local wt_path=""
    local branch_ref=""
    while IFS= read -r line; do
        if [[ -z "$line" ]]; then
            if [[ -n "$wt_path" && -n "$branch_ref" ]]; then
                if ! git show-ref --verify --quiet "$branch_ref"; then
                    local branch
                    branch="${branch_ref#refs/heads/}"
                    warn "Branch '$branch' no longer exists. Removing worktree at $wt_path"
                    git worktree remove --force "$wt_path" 2>/dev/null || true
                    (( pruned++ )) || true
                fi
            fi

            wt_path=""
            branch_ref=""
            continue
        fi

        case "$line" in
            worktree\ *) wt_path="${line#worktree }" ;;
            branch\ refs/heads/*) branch_ref="${line#branch }" ;;
        esac
    done < <(git worktree list --porcelain; echo)

    ok "Cleaned $pruned stale worktree(s)"
}

# Main entrypoint

main() {
    setup_ui

    command -v git >/dev/null 2>&1 \
        || die "Required command not found: git"

    local cmd="${1:-}"
    [[ $# -gt 0 ]] && shift

    case "$cmd" in
        init)           cmd_init   "$@" ;;
        add)            cmd_add    "$@" ;;
        remove|rm)      cmd_remove "$@" ;;
        list|ls)        cmd_list   "$@" ;;
        switch)         cmd_switch "$@" ;;
        clean)          cmd_clean  "$@" ;;
        ""|help|--help|-h) usage   ;;
        *) die "Unknown command: $cmd. Run 'gw help' for usage." ;;
    esac
}

main "$@"
