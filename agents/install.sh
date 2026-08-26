#!/usr/bin/env bash
#
# Install agent configurations:
# - Sets OPENCODE_CONFIG_DIR env var for OpenCode (no symlinks needed)
# - Creates symlinks for Claude Code and Agent Skills standard
#
# Usage: ./install.sh [--dry-run]
#

set -euo pipefail

# Resolve repo root from this script's location (agents/ -> repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="${DOTFILES_DIR:-$(dirname "$SCRIPT_DIR")}"
AGENTS_DIR="$DOTFILES_DIR/agents"
CONFIG_DIR="$AGENTS_DIR/config"

DRY_RUN=false
CHECK_SETTINGS_ONLY=false
APPLY_SETTINGS=false
BASELINE_SETTINGS=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            ;;
        --check-settings)
            CHECK_SETTINGS_ONLY=true
            ;;
        --apply-settings)
            APPLY_SETTINGS=true
            ;;
        --baseline-settings)
            BASELINE_SETTINGS=true
            ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--check-settings] [--apply-settings] [--baseline-settings]"
            echo ""
            echo "Options:"
            echo "  --dry-run            Show what would be done without making changes"
            echo "  --check-settings     Only report permission drift between the seed and"
            echo "                       this machine's ~/.claude/settings.json, then exit"
            echo "  --apply-settings     Overwrite this machine's command rules with the"
            echo "                       seed's, backing up settings.json first. Path and"
            echo "                       WebFetch rules are left alone"
            echo "  --baseline-settings  Record the current seed as this machine's baseline,"
            echo "                       silencing drift you have already decided about"
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

# Portable in-place sed (BSD sed on macOS requires -i '', GNU sed does not)
_sed_i() {
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
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
            _sed_i "s|^export ${var_name}=.*|${export_line}|" "$shell_rc"
            log_success "Updated $var_name in $shell_rc"
        fi
    else
        if $DRY_RUN; then
            log_info "Would add to $shell_rc: $export_line"
        else
            # Insert before the PowerShell auto-launch block if present.
            # The bootstrap scripts add an "exec pwsh" block that replaces the
            # shell, so any exports appended after it would never be evaluated.
            local insert_text="\n# OpenCode config directory (added by congruens)\n${export_line}"
            if grep -q "Congruens: Auto-launch PowerShell" "$shell_rc" 2>/dev/null; then
                _sed_i "/# Congruens: Auto-launch PowerShell/i\\${insert_text}" "$shell_rc"
                log_success "Added $var_name to $shell_rc (before PowerShell auto-launch)"
            else
                echo "" >> "$shell_rc"
                echo "# OpenCode config directory (added by congruens)" >> "$shell_rc"
                echo "$export_line" >> "$shell_rc"
                log_success "Added $var_name to $shell_rc"
            fi
        fi
    fi
}

# Run the shared drift checker. The JSON set logic lives in one Python script
# rather than twice in bash and PowerShell, because a three-way diff
# maintained in two languages is a diff waiting to disagree with itself.
run_drift_check() {
    local python_bin="" candidate
    # Not just command -v: on Windows, python3 on PATH is usually the Microsoft
    # Store's App Execution Alias, which exists, resolves, prints an ad for the
    # Store and exits 49. Only a binary that actually runs code counts.
    for candidate in python3 python py; do
        if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c "import sys" >/dev/null 2>&1; then
            python_bin="$candidate"
            break
        fi
    done
    if [[ -z "$python_bin" ]]; then
        log_warn "No working python3 on PATH, skipping settings drift check"
        return 2
    fi
    "$python_bin" "$AGENTS_DIR/check-settings-drift.py" \
        --seed "$CONFIG_DIR/claude-settings.json" \
        --live "$HOME/.claude/settings.json" \
        --snapshot "$HOME/.claude/.congruens-seed.json" \
        "$@"
}

# Report-only. settings.json is seeded once and never written again, so a
# permissions change in the repo has to be replayed by hand on every host.
# This is the part that tells you a host is behind.
check_settings_drift() {
    # Exit 1 just means drift was found; under set -e that would abort install.
    run_drift_check || true
}

# Main installation
main() {
    echo ""
    echo "Agent Configuration Installer"
    echo "=============================="
    echo ""

    # These are about settings.json only, so they run on their own and skip the
    # symlinking entirely. --apply-settings is never part of a normal install
    # run: writing settings.json is the one thing the seed-once design exists
    # to prevent, so it only ever happens because someone asked for it by name.
    if $APPLY_SETTINGS; then
        run_drift_check --apply
        exit $?
    fi
    if $BASELINE_SETTINGS; then
        run_drift_check --baseline
        exit $?
    fi
    if $CHECK_SETTINGS_ONLY; then
        run_drift_check && log_success "No permission drift against the congruens seed"
        exit $?
    fi

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
    # settings.json is per-machine: permissions and enabled plugins differ by host.
    # Seed it once as a real file, then never touch it again. Do NOT symlink -
    # create_symlink rm -rf's an existing target, which would silently destroy
    # a machine's local permission rules. (Mirrors install.ps1.)
    claude_settings="$HOME/.claude/settings.json"
    claude_baseline="$HOME/.claude/.congruens-seed.json"
    if [[ -e "$claude_settings" || -L "$claude_settings" ]]; then
        log_info "Kept existing: $claude_settings (per-machine, not managed by congruens)"
        check_settings_drift
    elif $DRY_RUN; then
        log_info "Would seed: $claude_settings (copy, not symlink)"
    else
        mkdir -p "$HOME/.claude"
        cp "$CONFIG_DIR/claude-settings.json" "$claude_settings"
        log_success "Seeded: $claude_settings (copy - edit locally, will not be overwritten)"
        # A machine seeded now starts reconciled, so record the baseline that
        # lets later runs tell an upstream change from a local edit.
        run_drift_check --baseline || true
    fi
    # CLAUDE.md is the Claude Code equivalent of AGENTS.md
    if [[ -f "$CONFIG_DIR/AGENTS.md" ]]; then
        create_symlink "$CONFIG_DIR/AGENTS.md" "$HOME/.claude/CLAUDE.md" || true
    fi
    echo ""

    # Agent Skills standard symlinks
    echo "Agent Skills Standard:"
    create_symlink "$CONFIG_DIR/skills" "$HOME/.agents/skills" || true
    if [[ -f "$CONFIG_DIR/AGENTS.md" ]]; then
        create_symlink "$CONFIG_DIR/AGENTS.md" "$HOME/.agents/AGENTS.md" || true
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
