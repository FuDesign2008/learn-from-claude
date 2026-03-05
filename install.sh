#!/usr/bin/env bash
# install.sh — Install learn-from-claude skills into claude code and opencode
#
# What this script does:
#   1. Creates symlinks in ~/.claude/skills/        (claude code)
#   2. Creates symlinks in open-skills/skills/      (opencode, via existing symlink)
#
# Usage:
#   ./install.sh          # install all skills
#   ./install.sh --dry-run # preview without making changes
#   ./install.sh --uninstall # remove all symlinks

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"

CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
OPENCODE_SKILLS_DIR="$HOME/.config/opencode/open-skills/skills"

DRY_RUN=false
UNINSTALL=false

for arg in "$@"; do
    case $arg in
    --dry-run) DRY_RUN=true ;;
    --uninstall) UNINSTALL=true ;;
    esac
done

# ── helpers ──────────────────────────────────────────────────────────────────

green() { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
red() { echo -e "\033[31m$*\033[0m"; }
dim() { echo -e "\033[2m$*\033[0m"; }

run() {
    if $DRY_RUN; then
        dim "  [dry-run] $*"
    else
        eval "$@"
    fi
}

# ── skill list ────────────────────────────────────────────────────────────────

SKILLS=(
    task-router
    coding-workflow
    debug-workflow
    distill-session
)

# ── install ───────────────────────────────────────────────────────────────────

install_skill() {
    local skill="$1"
    local source="$SKILLS_DIR/$skill"
    local targets=()

    # claude code
    if [[ -d "$CLAUDE_SKILLS_DIR" ]]; then
        targets+=("$CLAUDE_SKILLS_DIR/$skill")
    else
        yellow "  ⚠ claude code skills dir not found: $CLAUDE_SKILLS_DIR (skipping)"
    fi

    # opencode
    if [[ -d "$OPENCODE_SKILLS_DIR" ]]; then
        targets+=("$OPENCODE_SKILLS_DIR/$skill")
    else
        yellow "  ⚠ opencode skills dir not found: $OPENCODE_SKILLS_DIR (skipping)"
    fi

    for target in "${targets[@]}"; do
        if [[ -L "$target" ]]; then
            dim "  already linked: $target"
        elif [[ -e "$target" ]]; then
            red "  conflict (not a symlink): $target — skipping"
        else
            run "ln -s \"$source\" \"$target\""
            green "  ✓ linked: $target → $source"
        fi
    done
}

uninstall_skill() {
    local skill="$1"
    local targets=(
        "$CLAUDE_SKILLS_DIR/$skill"
        "$OPENCODE_SKILLS_DIR/$skill"
    )
    for target in "${targets[@]}"; do
        if [[ -L "$target" ]]; then
            run "rm \"$target\""
            green "  ✓ removed: $target"
        else
            dim "  not found: $target"
        fi
    done
}

# ── main ──────────────────────────────────────────────────────────────────────

if $DRY_RUN; then
    yellow "DRY RUN — no changes will be made"
    echo
fi

if $UNINSTALL; then
    echo "Uninstalling learn-from-claude skills..."
    for skill in "${SKILLS[@]}"; do
        echo "  $skill"
        uninstall_skill "$skill"
    done
    green "Done."
    exit 0
fi

echo "Installing learn-from-claude skills..."
echo
for skill in "${SKILLS[@]}"; do
    echo "  $skill"
    install_skill "$skill"
done

echo
green "Installation complete."
echo
echo "Skills installed:"
for skill in "${SKILLS[@]}"; do
    echo "  • $skill"
done
echo
echo "To activate automatic triggering, ensure your CLAUDE.md contains:"
echo
cat <<'EOF'
  ## Auto-activated Skills
  The following skills are always active — no trigger word needed:
  - task-router: Classifies every task and injects the appropriate workflow
EOF
echo
echo "See README.md for full usage instructions."
