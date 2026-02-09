#!/usr/bin/env bash
#
# Install agent configurations:
# - Sets OPENCODE_CONFIG_DIR env var for OpenCode (no symlinks needed)
# - Creates symlinks for Claude Code and Agent Skills standard
#
# Usage: ./install.sh [--dry-run]
#

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
AGENTS_DIR="$DOTFILES_DIR/agents"
CONFIG_DIR="$AGENTS_DIR/config"

DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run]"
            echo ""
            echo "Options:"
            echo "  --dry-run  Show what would be done without making changes"
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

        # Remove and re-create to keep things idempotent
        if $DRY_RUN; then
            log_info "Would replace existing: $target"
        else
            rm -rf "$target"
            log_warn "Replaced existing: $target"
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

# Add env var to shell profile
set_env_var() {
    local var_name="$1"
    local var_value="$2"
    local shell_rc

    # Determine which rc file to use
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi

    local export_line="export ${var_name}=\"${var_value}\""

    if grep -qF "$var_name" "$shell_rc" 2>/dev/null; then
        if grep -qF "$export_line" "$shell_rc" 2>/dev/null; then
            log_success "Already set in $shell_rc: $var_name"
            return 0
        fi
        # Update existing line
        if $DRY_RUN; then
            log_info "Would update $var_name in $shell_rc"
        else
            sed -i "s|^export ${var_name}=.*|${export_line}|" "$shell_rc"
            log_success "Updated $var_name in $shell_rc"
        fi
    else
        if $DRY_RUN; then
            log_info "Would add to $shell_rc: $export_line"
        else
            echo "" >> "$shell_rc"
            echo "# OpenCode config directory (added by congruens)" >> "$shell_rc"
            echo "$export_line" >> "$shell_rc"
            log_success "Added $var_name to $shell_rc"
        fi
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
    if [[ ! -d "$CONFIG_DIR" ]]; then
        log_error "Config directory not found: $CONFIG_DIR"
        exit 1
    fi

    log_info "Source: $CONFIG_DIR"
    echo ""

    # OpenCode: set OPENCODE_CONFIG_DIR env var (no symlinks needed)
    echo "OpenCode:"
    set_env_var "OPENCODE_CONFIG_DIR" "$CONFIG_DIR"
    echo ""

    # Claude Code symlinks
    echo "Claude Code:"
    create_symlink "$CONFIG_DIR/skills" "$HOME/.claude/skills" || true
    create_symlink "$CONFIG_DIR/agents" "$HOME/.claude/agents" || true
    create_symlink "$CONFIG_DIR/claude-settings.json" "$HOME/.claude/settings.json" || true
    # CLAUDE.md is the Claude Code equivalent of AGENTS.md
    if [[ -f "$DOTFILES_DIR/AGENTS.md" ]]; then
        create_symlink "$DOTFILES_DIR/AGENTS.md" "$HOME/.claude/CLAUDE.md" || true
    fi
    echo ""

    # Agent Skills standard symlinks
    echo "Agent Skills Standard:"
    create_symlink "$CONFIG_DIR/skills" "$HOME/.agents/skills" || true
    if [[ -f "$DOTFILES_DIR/AGENTS.md" ]]; then
        create_symlink "$DOTFILES_DIR/AGENTS.md" "$HOME/.agents/AGENTS.md" || true
    fi
    echo ""

    echo "=============================="
    if $DRY_RUN; then
        log_info "Dry run complete. Run without --dry-run to apply changes."
    else
        log_success "Installation complete!"
        log_info "Restart your shell or run: source ~/.bashrc (or ~/.zshrc)"
    fi
    echo ""
}

main "$@"
