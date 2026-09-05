#!/bin/bash
#
# macOS bootstrap script for Congruens.
#
# Automates macOS machine setup:
# 1. Check prerequisites (bash, curl)
# 2. Install Homebrew if not present
# 3. Install PowerShell 7
# 4. Read tool definitions from tools/*.json
# 5. Install each tool using Homebrew
# 6. Wire PowerShell $PROFILE to source repo profile
# 7. Configure oh-my-posh
# 8. Install Nerd Font
# 9. Install Hungarian keyboard layout
# 10. Create local config from defaults
#
# Usage:
#   ./macos.sh           # Run the full bootstrap process
#   ./macos.sh --skip-tools    # Skip tool installation
#   ./macos.sh --skip-profile  # Skip profile configuration
#

set -e

# ============================================================================
# Configuration
# ============================================================================

SKIP_TOOLS=false
SKIP_PROFILE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-tools)
            SKIP_TOOLS=true
            shift
            ;;
        --skip-profile)
            SKIP_PROFILE=true
            shift
            ;;
    esac
done

# ============================================================================
# Output Helpers
# ============================================================================

print_step() {
    echo -e "\n\033[36m>> $1\033[0m"
}

print_success() {
    echo -e "   \033[32m[OK]\033[0m $1"
}

print_warning() {
    echo -e "   \033[33m[!]\033[0m $1"
}

print_failure() {
    echo -e "   \033[31m[X]\033[0m $1"
}

print_info() {
    echo -e "   \033[90m$1\033[0m"
}

# ============================================================================
# Prerequisites Check
# ============================================================================

print_step "Checking prerequisites..."

# Check macOS
if [[ "$(uname)" != "Darwin" ]]; then
    print_failure "This script is for macOS only"
    exit 1
fi
print_success "Running on macOS $(sw_vers -productVersion)"

# Check for curl
if ! command -v curl &> /dev/null; then
    print_failure "curl is required but not installed"
    exit 1
fi
print_success "curl is available"

# ============================================================================
# Homebrew Setup
# ============================================================================

print_step "Setting up Homebrew..."

if command -v brew &> /dev/null; then
    print_success "Homebrew is already installed"
else
    print_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    print_success "Homebrew installed"
fi

# Update Homebrew
print_info "Updating Homebrew..."
brew update --quiet

# ============================================================================
# PowerShell 7 Installation
# ============================================================================

print_step "Setting up PowerShell 7..."

if command -v pwsh &> /dev/null; then
    PWSH_VERSION=$(pwsh --version | head -1)
    print_success "PowerShell is already installed: $PWSH_VERSION"
else
    print_info "Installing PowerShell from GitHub releases..."

    # Follow the GitHub "latest" redirect to discover the latest stable tag.
    # This reliably resolves to e.g. .../releases/tag/v7.5.4
    RELEASE_URL=$(curl -sIL -o /dev/null -w '%{url_effective}' "https://github.com/PowerShell/PowerShell/releases/latest")

    if [[ -z "$RELEASE_URL" ]]; then
        print_failure "Could not resolve PowerShell release URL"
        exit 1
    fi

    # Extract the version tag from the URL (e.g. "v7.5.4" from ".../tag/v7.5.4")
    PS_TAG="${RELEASE_URL##*/}"
    PS_VERSION="${PS_TAG#v}"
    print_info "Latest stable release: $PS_TAG"

    # Determine architecture
    ARCH=$(uname -m)
    if [[ "$ARCH" == "arm64" ]]; then
        PKG_ARCH="osx-arm64"
    else
        PKG_ARCH="osx-x64"
    fi

    PKG_NAME="powershell-${PS_VERSION}-${PKG_ARCH}.pkg"
    DOWNLOAD_URL="https://github.com/PowerShell/PowerShell/releases/download/${PS_TAG}/${PKG_NAME}"

    print_info "Downloading $PKG_NAME..."
    TEMP_PKG="$(mktemp -d)/${PKG_NAME}"
    if ! curl -fSL -o "$TEMP_PKG" "$DOWNLOAD_URL"; then
        print_failure "Failed to download $DOWNLOAD_URL"
        rm -f "$TEMP_PKG"
        exit 1
    fi

    print_info "Installing PowerShell (may require sudo)..."
    if sudo installer -pkg "$TEMP_PKG" -target /; then
        print_success "PowerShell $PS_VERSION installed"
    else
        print_failure "PowerShell installation failed"
        rm -f "$TEMP_PKG"
        exit 1
    fi

    rm -f "$TEMP_PKG"
fi

# Verify PowerShell works
if ! command -v pwsh &> /dev/null; then
    print_failure "PowerShell installation failed"
    exit 1
fi

# ============================================================================
# Repo Root
# ============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================================
# Tool Installation
# ============================================================================

if [[ "$SKIP_TOOLS" == false ]]; then
    print_step "Installing tools..."

    TOOLS_PATH="$REPO_ROOT/tools"
    
    if [[ ! -d "$TOOLS_PATH" ]]; then
        print_warning "Tools directory not found at $TOOLS_PATH"
    else
        # Count tools
        TOOL_FILES=("$TOOLS_PATH"/*.json)
        TOTAL_TOOLS=${#TOOL_FILES[@]}
        CURRENT_TOOL=0
        HAS_SELF_MANAGED=false

        for TOOL_FILE in "${TOOL_FILES[@]}"; do
            ((CURRENT_TOOL++))
            
            # Parse JSON using Python (available on macOS by default) or jq if installed
            if command -v jq &> /dev/null; then
                TOOL_NAME=$(jq -r '.name' "$TOOL_FILE")
                VERIFY_CMD=$(jq -r '.verify // empty' "$TOOL_FILE")
                BREW_PKG=$(jq -r '.install.macos.brew // empty' "$TOOL_FILE")
                CARGO_PKG=$(jq -r '.install.macos.cargo // empty' "$TOOL_FILE")
                GITHUB_REPO=$(jq -r '.install.macos.github.repo // empty' "$TOOL_FILE")
            else
                # Fallback to Python
                TOOL_NAME=$(python3 -c "import json; print(json.load(open('$TOOL_FILE'))['name'])" 2>/dev/null || echo "unknown")
                VERIFY_CMD=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('verify', ''))" 2>/dev/null || echo "")
                BREW_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('macos', {}).get('brew', ''))" 2>/dev/null || echo "")
                CARGO_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('macos', {}).get('cargo', ''))" 2>/dev/null || echo "")
                GITHUB_REPO=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('macos', {}).get('github', {}).get('repo', ''))" 2>/dev/null || echo "")
            fi

            echo -n "   [$CURRENT_TOOL/$TOTAL_TOOLS] $TOOL_NAME..."

            # Self-managed tools are handled after this loop by the Congruens
            # module, so there is one implementation of the download/checksum
            # logic instead of one per platform bootstrap.
            if [[ -n "$GITHUB_REPO" ]]; then
                echo -e " \033[90mself-managed (handled below)\033[0m"
                HAS_SELF_MANAGED=true
                continue
            fi

            # Check if already installed
            if [[ -n "$VERIFY_CMD" ]]; then
                VERIFY_BIN=$(echo "$VERIFY_CMD" | awk '{print $1}')
                if command -v "$VERIFY_BIN" &> /dev/null; then
                    echo -e " \033[90malready installed\033[0m"
                    continue
                fi
            fi

            INSTALLED=false
            ATTEMPTED=false

            # Install via Homebrew (taps and casks both go through plain install)
            if [[ -n "$BREW_PKG" ]]; then
                ATTEMPTED=true
                if brew install "$BREW_PKG" --quiet 2>/dev/null; then
                    echo -e " \033[32mOK (brew)\033[0m"
                    INSTALLED=true
                fi
            fi

            # Fall back to cargo for Rust tools with no formula on this platform
            if [[ "$INSTALLED" == false ]] && [[ -n "$CARGO_PKG" ]] && command -v cargo &> /dev/null; then
                ATTEMPTED=true
                if cargo install --quiet "$CARGO_PKG" 2>/dev/null; then
                    echo -e " \033[32mOK (cargo)\033[0m"
                    INSTALLED=true
                fi
            fi

            if [[ "$INSTALLED" == false ]]; then
                if [[ "$ATTEMPTED" == true ]]; then
                    echo -e " \033[33mFAILED\033[0m"
                else
                    echo -e " \033[33mSKIP (no package available)\033[0m"
                fi
            fi
        done

        # Self-managed tools: delegate to the Congruens module so the download,
        # checksum and PATH logic lives in exactly one place.
        if [[ "$HAS_SELF_MANAGED" == true ]]; then
            print_info "Installing self-managed tools (GitHub releases)..."
            pwsh -NoProfile -Command "
                \$env:PSModulePath = '$REPO_ROOT/powershell' + [IO.Path]::PathSeparator + \$env:PSModulePath
                Import-Module Congruens -Force
                Install-CongruensTool -All
            " || print_warning "Self-managed tool install failed - run 'cgrtool -All' after restarting your shell"
        fi
    fi
fi

# ============================================================================
# PowerShell Profile Configuration
# ============================================================================

if [[ "$SKIP_PROFILE" == false ]]; then
    print_step "Configuring PowerShell profile..."

    # Get PowerShell profile path
    PWSH_PROFILE=$(pwsh -NoProfile -Command 'Write-Host $PROFILE')
    PWSH_PROFILE_DIR=$(dirname "$PWSH_PROFILE")

    # Create profile directory if it doesn't exist
    if [[ ! -d "$PWSH_PROFILE_DIR" ]]; then
        mkdir -p "$PWSH_PROFILE_DIR"
    fi

    PROFILE_CONTENT="# Congruens - Cross-platform CLI experience
# Source the congruens profile
. \"$REPO_ROOT/powershell/profile.ps1\""

    if [[ -f "$PWSH_PROFILE" ]]; then
        if grep -q "$REPO_ROOT/powershell/profile.ps1" "$PWSH_PROFILE"; then
            print_success "Profile already configured"
        else
            # Append to existing profile
            echo "" >> "$PWSH_PROFILE"
            echo "$PROFILE_CONTENT" >> "$PWSH_PROFILE"
            print_success "Appended to existing profile"
        fi
    else
        # Create new profile
        echo "$PROFILE_CONTENT" > "$PWSH_PROFILE"
        print_success "Created new profile"
    fi
fi

# ============================================================================
# Shell Integration Configuration
# ============================================================================

print_step "Configuring shell integration..."

# PowerShell auto-launch lives in the TERMINAL EMULATOR config, not the shell
# rc files. Earlier congruens versions injected `exec pwsh` into ~/.zshrc /
# ~/.bash_profile, which silently broke everything that expects the login
# shell to be a POSIX shell: terminal cwd tracking (shell integration, OSC 7),
# apps that launch terminals with a command to run, `$SHELL -c` callers, and
# every terminal not covered by the IDE guard list. The rc files now only get
# a small `pw` function to hop into PowerShell on demand; terminals we know
# how to configure (Ghostty) are pointed at pwsh directly, which keeps the
# launch-into-PowerShell experience without hijacking zsh/bash.

read -r -d '' PW_OPTIN_BLOCK <<'PWBLOCK' || true

# Congruens: pwsh opt-in
# Type `pw` to switch this shell to PowerShell. Automatic launch lives in the
# terminal emulator config (Ghostty `command`), not here - hijacking the rc
# breaks cwd tracking, app-launched terminals, and $SHELL -c callers.
pw() { exec pwsh "$@"; }
PWBLOCK

# Strip any previous congruens auto-launch block, whatever its vintage:
# the original bare `exec pwsh` guard (ends with `fi`), the hooked zsh shape
# (ends with the add-zsh-hook line), or the hooked bash shape (ends with the
# PROMPT_COMMAND line).
_strip_autolaunch() {
    local rc_file="$1"
    local tmp
    tmp="$(mktemp)"
    awk '
        /# Congruens: Auto-launch PowerShell/ { skipping = 1; next }
        skipping && (/^fi$/ || /^add-zsh-hook precmd _congruens_launch_pwsh$/ || /^PROMPT_COMMAND="_congruens_launch_pwsh/) { skipping = 0; next }
        !skipping { print }
    ' "$rc_file" > "$tmp" && mv "$tmp" "$rc_file"
}

configure_shell_rc() {
    local rc_file="$1"
    local shell_name="$2"

    if [[ -f "$rc_file" ]] && grep -q "Congruens: Auto-launch PowerShell" "$rc_file"; then
        _strip_autolaunch "$rc_file"
        print_info "Removed auto-launch block from $rc_file (launch moved to terminal config)"
    fi

    if [[ -f "$rc_file" ]] && grep -q "Congruens: pwsh opt-in" "$rc_file"; then
        print_success "$shell_name pw opt-in already present ($rc_file)"
        return
    fi

    printf '%s
' "$PW_OPTIN_BLOCK" >> "$rc_file"
    print_success "Added pw opt-in function for $shell_name ($rc_file)"
}

# On macOS, login bash shells (Terminal.app default) read ~/.bash_profile and
# do NOT source ~/.bashrc automatically. If other installers write exports to
# ~/.bashrc, they'd be invisible. Make .bash_profile source .bashrc so exports
# land in one file but apply to both shells.
ensure_bash_profile_sources_bashrc() {
    local profile="$HOME/.bash_profile"
    local marker="# Congruens: source ~/.bashrc"
    [[ -f "$profile" ]] || touch "$profile"
    if grep -q "$marker" "$profile"; then
        return
    fi
    cat >> "$profile" <<'BP'

# Congruens: source ~/.bashrc
# Login bash shells on macOS don't read .bashrc by default. Source it so env
# exports written by installers land in one place but apply everywhere.
if [[ -f "$HOME/.bashrc" ]]; then
    . "$HOME/.bashrc"
fi
BP
    print_success "Configured ~/.bash_profile to source ~/.bashrc"
}

# Configure for bash (default on older macOS)
ensure_bash_profile_sources_bashrc
configure_shell_rc "$HOME/.bash_profile" "bash"

# Configure for zsh (default on macOS Catalina+)
configure_shell_rc "$HOME/.zshrc" "zsh"

# Ghostty: launch pwsh directly in new terminal windows. `ghostty -e <cmd>`
# still overrides this, so app-launched terminals with explicit commands keep
# working, and zsh stays the login shell for everything else on the system.
configure_ghostty() {
    local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
    local cfg="$cfg_dir/config"
    local pwsh_path
    pwsh_path="$(command -v pwsh || true)"
    [[ -n "$pwsh_path" ]] || return 0

    if ! command -v ghostty &> /dev/null && [[ ! -d "/Applications/Ghostty.app" ]]; then
        return 0
    fi

    if grep -q "Congruens: launch PowerShell" "$cfg" 2>/dev/null; then
        print_success "Ghostty already configured to launch PowerShell"
        return 0
    fi
    if grep -Eq '^[[:space:]]*command[[:space:]]*=' "$cfg" 2>/dev/null; then
        print_warning "Ghostty config already sets 'command' - leaving it alone. Point it at $pwsh_path to launch PowerShell."
        return 0
    fi

    mkdir -p "$cfg_dir"
    cat >> "$cfg" <<GHOSTTY

# Congruens: launch PowerShell in new terminals (delete these lines for zsh)
command = $pwsh_path
GHOSTTY
    print_success "Configured Ghostty to launch PowerShell (command = $pwsh_path)"
    print_info "Reload Ghostty config (Cmd+Shift+,) or restart Ghostty to apply"
}

configure_ghostty

# ============================================================================
# oh-my-posh Configuration
# ============================================================================

print_step "Configuring oh-my-posh..."

if command -v oh-my-posh &> /dev/null; then
    print_success "oh-my-posh is installed"
    
    THEME_PATH="$REPO_ROOT/omp/congruens.omp.json"
    if [[ -f "$THEME_PATH" ]]; then
        print_success "Theme found at $THEME_PATH"
        print_info "Theme will be applied on next PowerShell startup"
    else
        print_warning "Theme not found at $THEME_PATH"
    fi
else
    print_warning "oh-my-posh not installed - run tools installation first"
fi

# ============================================================================
# Nerd Font Installation
# ============================================================================

print_step "Installing CaskaydiaCove Nerd Font..."

# Check if font is already installed
if fc-list 2>/dev/null | grep -qi "CaskaydiaCove\|Cascadia.*Nerd"; then
    print_success "CaskaydiaCove Nerd Font is already installed"
else
    # Add Homebrew cask-fonts tap if not present
    if ! brew tap | grep -q "homebrew/cask-fonts"; then
        print_info "Adding Homebrew fonts tap..."
        brew tap homebrew/cask-fonts 2>/dev/null || true
    fi
    
    print_info "Installing CaskaydiaCove Nerd Font via Homebrew..."
    if brew install --cask font-caskaydia-cove-nerd-font 2>/dev/null; then
        print_success "CaskaydiaCove Nerd Font installed"
    else
        # Fallback: try alternative package name
        if brew install --cask font-caskaydia-mono-nerd-font 2>/dev/null; then
            print_success "CaskaydiaMono Nerd Font installed"
        else
            print_warning "Could not install font via Homebrew"
            print_info "Install manually: brew install --cask font-caskaydia-cove-nerd-font"
        fi
    fi
fi

# ============================================================================
# Hungarian Keyboard Layout
# ============================================================================

print_step "Installing Hungarian (Windows-style) keyboard layout..."

KEYLAYOUT_DIR="/Library/Keyboard Layouts"
KEYLAYOUT_FILE="$KEYLAYOUT_DIR/Hungarian_Win.keylayout"
KEYLAYOUT_URL="https://raw.githubusercontent.com/zaki/mac-hun-keyboard/refs/heads/master/Hungarian_Win.keylayout"

if [[ -f "$KEYLAYOUT_FILE" ]]; then
    print_success "Hungarian_Win.keylayout is already installed"
else
    print_info "Downloading Hungarian_Win.keylayout..."
    TEMP_KEYLAYOUT="$(mktemp)"
    if curl -fSL -o "$TEMP_KEYLAYOUT" "$KEYLAYOUT_URL"; then
        print_info "Installing to $KEYLAYOUT_DIR (may require sudo)..."
        if sudo cp "$TEMP_KEYLAYOUT" "$KEYLAYOUT_FILE"; then
            print_success "Hungarian_Win.keylayout installed"
            print_info "Enable it via System Preferences > Language & Text > Input Sources"
        else
            print_failure "Failed to copy keylayout to $KEYLAYOUT_DIR"
        fi
        rm -f "$TEMP_KEYLAYOUT"
    else
        print_failure "Failed to download keylayout from $KEYLAYOUT_URL"
        rm -f "$TEMP_KEYLAYOUT"
    fi
fi

# ============================================================================
# Claude Code Notifications (peon-ping)
# ============================================================================

print_step "Setting up peon-ping (Claude Code notifications)..."

# peon-ping (https://github.com/PeonPing/peon-ping) plays Warcraft peon voice
# lines on Claude Code lifecycle events. Its installer registers hooks in
# ~/.claude/settings.json, so it must only run AFTER agents/install.sh has
# seeded that file - a hook-only settings.json created first would make the
# seed step skip, and the machine would silently miss the shared config.

PEON_HOOKS_DIR="$HOME/.claude/hooks/peon-ping"
PEON_CONFIG="$PEON_HOOKS_DIR/config.json"
PEON_CONFIG_SEED="$REPO_ROOT/agents/config/peon-ping.json"

# Put the shared config and the sound packs it names in place. Runs whether or
# not this bootstrap did the install, because the two drift apart: an install
# from before the seed existed, or a config someone deleted, would otherwise
# never be repaired - the old "hooks dir exists, skip everything" short-circuit
# meant a machine could have peon-ping and no shared config forever.
#
# $1 is "force": true right after a fresh install, so the shared config beats
# the default the installer just wrote; false on every later run, so
# per-machine tweaks survive and only a missing config gets restored.
seed_peon_config() {
    local force="$1"

    if [[ ! -d "$PEON_HOOKS_DIR" ]]; then
        print_warning "peon-ping hooks dir not found at $PEON_HOOKS_DIR - skipping config seed"
        return
    fi
    if [[ ! -f "$PEON_CONFIG_SEED" ]]; then
        print_warning "peon-ping config seed not found at $PEON_CONFIG_SEED"
        return
    fi

    if [[ -f "$PEON_CONFIG" && "$force" != true ]]; then
        print_success "peon-ping config already present"
    else
        cp -f "$PEON_CONFIG_SEED" "$PEON_CONFIG"
        print_success "Seeded shared peon-ping config"
    fi

    # The seed's "packs" field is congruens's own (peon-ping ignores it): the
    # shared roster of sound packs to pull onto every machine. Each pack is a
    # directory under packs/, so install only the ones that aren't there yet.
    local packs
    packs=$(jq -r '(.packs // [])[]' "$PEON_CONFIG_SEED" 2>/dev/null \
        || python3 -c "import json; print('\n'.join(json.load(open('$PEON_CONFIG_SEED')).get('packs', [])))" 2>/dev/null \
        || echo "")

    local missing=()
    local pack
    while IFS= read -r pack; do
        pack="${pack%$'\r'}"
        [[ -n "$pack" ]] || continue
        [[ -d "$PEON_HOOKS_DIR/packs/$pack" ]] || missing+=("$pack")
    done <<< "$packs"

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_success "peon-ping sound packs already installed"
        return
    fi

    local pack_list
    pack_list=$(IFS=','; echo "${missing[*]}")
    if command -v peon &> /dev/null; then
        peon packs install "$pack_list" || print_warning "Some peon-ping packs failed to install"
    elif [[ -f "$PEON_HOOKS_DIR/peon.sh" ]]; then
        bash "$PEON_HOOKS_DIR/peon.sh" packs install "$pack_list" || print_warning "Some peon-ping packs failed to install"
    else
        print_warning "peon CLI not found - install packs later with: peon packs install $pack_list"
    fi
}

if [[ -d "$PEON_HOOKS_DIR" ]]; then
    # Install-only by design: an existing peon-ping is never upgraded here.
    # Its config still gets checked.
    print_success "peon-ping already installed (re-run its installer to update)"
    seed_peon_config false
elif [[ ! -f "$HOME/.claude/settings.json" ]]; then
    print_warning "~/.claude/settings.json not seeded yet - run agents/install.sh first, then re-run this bootstrap to get peon-ping"
elif brew install PeonPing/tap/peon-ping --quiet 2>/dev/null && peon-ping-setup; then
    print_success "peon-ping installed and hooks registered"
    seed_peon_config true
else
    print_warning "peon-ping install failed - see https://github.com/PeonPing/peon-ping"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "\033[36m$(printf '=%.0s' {1..60})\033[0m"
echo -e "\033[32m Bootstrap Complete!\033[0m"
echo -e "\033[36m$(printf '=%.0s' {1..60})\033[0m"
echo ""
echo -e "\033[33mNext steps:\033[0m"
echo "  1. Restart your terminal - PowerShell will launch automatically"
echo ""
echo -e "\033[33m  2. Configure your terminal to use CaskaydiaCove Nerd Font:\033[0m"
echo ""
echo "     For iTerm2:"
echo "       - Open Preferences (Cmd+,)"
echo "       - Go to Profiles > Text"
echo "       - Click on Font and select: CaskaydiaCove Nerd Font"
echo ""
echo "     For Terminal.app:"
echo "       - Open Preferences (Cmd+,)"
echo "       - Go to Profiles > Text > Change Font"
echo "       - Select: CaskaydiaCove Nerd Font"
echo ""
echo "     For VS Code integrated terminal, add to settings.json:"
echo "       \"terminal.integrated.fontFamily\": \"CaskaydiaCove Nerd Font\""
echo ""
echo -e "\033[33mNote:\033[0m"
echo "  PowerShell auto-launches via ~/.zshrc and ~/.bash_profile"
echo "  (deferred until just before the first prompt, so installer PATH"
echo "   exports written later in those files still take effect)"
echo "  To get a native bash/zsh shell, run: bash --norc  or  zsh --norcs"
echo ""
echo -e "\033[33mAvailable commands (in PowerShell):\033[0m"
echo "  mkcd <dir>     - Create directory and cd into it"
echo "  open [path]    - Open in Finder"
echo "  which <cmd>    - Find command location"
echo "  path show      - Display PATH entries"
echo "  path add <dir> - Add to session PATH"
echo ""
