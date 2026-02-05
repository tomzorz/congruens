#!/usr/bin/env bash
#
# Install agent configurations by creating symlinks from standard tool locations
# to the shared config in ~/dotfiles/agents/
#
# Usage: ./install.sh [--dry-run] [--force]
#

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
AGENTS_DIR="$DOTFILES_DIR/agents"

DRY_RUN=false
FORCE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --force)
            FORCE=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--force]"
            echo ""
            echo "Options:"
            echo "  --dry-run  Show what would be done without making changes"
            echo "  --force    Remove existing files/dirs before creating symlinks"
            exit 0
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create a symlink, handling existing files
create_symlink() {
    local source="$1"
    local target="$2"
    local target_dir
    target_dir=$(dirname "$target")

    # Create parent directory if needed
    if [[ ! -d "$target_dir" ]]; then
        if $DRY_RUN; then
            log_info "Would create directory: $target_dir"
        else
            mkdir -p "$target_dir"
            log_info "Created directory: $target_dir"
        fi
    fi

    # Handle existing target
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" ]]; then
            local existing_target
            existing_target=$(readlink "$target")
            if [[ "$existing_target" == "$source" ]]; then
                log_success "Already linked: $target -> $source"
                return 0
            fi
        fi

        if $FORCE; then
            if $DRY_RUN; then
                log_info "Would remove existing: $target"
            else
                rm -rf "$target"
                log_warn "Removed existing: $target"
            fi
        else
            log_warn "Skipping (exists): $target (use --force to override)"
            return 1
        fi
    fi

    # Create symlink
    if $DRY_RUN; then
        log_info "Would link: $target -> $source"
    else
        ln -s "$source" "$target"
        log_success "Linked: $target -> $source"
    fi
}

# Main installation
main() {
    echo ""
    echo "Agent Configuration Installer"
    echo "=============================="
    echo ""

    if $DRY_RUN; then
        log_info "Dry run mode - no changes will be made"
        echo ""
    fi

    # Check source exists
    if [[ ! -d "$AGENTS_DIR" ]]; then
        log_error "Agents directory not found: $AGENTS_DIR"
        exit 1
    fi

    log_info "Source: $AGENTS_DIR"
    echo ""

    # Claude Code symlinks
    echo "Claude Code:"
    create_symlink "$AGENTS_DIR/skills" "$HOME/.claude/skills" || true
    create_symlink "$AGENTS_DIR/subagents" "$HOME/.claude/agents" || true
    # CLAUDE.md is the Claude Code equivalent of AGENTS.md
    create_symlink "$DOTFILES_DIR/AGENTS.md" "$HOME/.claude/CLAUDE.md" || true
    echo ""

    # OpenCode symlinks
    echo "OpenCode:"
    create_symlink "$AGENTS_DIR/skills" "$HOME/.opencode/skills" || true
    create_symlink "$AGENTS_DIR/subagents" "$HOME/.opencode/agents" || true
    create_symlink "$DOTFILES_DIR/AGENTS.md" "$HOME/.opencode/AGENTS.md" || true
    echo ""

    # Agent Skills standard symlinks
    echo "Agent Skills Standard:"
    create_symlink "$AGENTS_DIR/skills" "$HOME/.agents/skills" || true
    create_symlink "$DOTFILES_DIR/AGENTS.md" "$HOME/.agents/AGENTS.md" || true
    echo ""

    echo "=============================="
    if $DRY_RUN; then
        log_info "Dry run complete. Run without --dry-run to apply changes."
    else
        log_success "Installation complete!"
    fi
    echo ""
}

main "$@"
