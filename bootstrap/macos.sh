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
# 6. Link dotfiles to ~/dotfiles
# 7. Wire PowerShell $PROFILE to source repo profile
# 8. Configure oh-my-posh
# 9. Install Nerd Font
# 10. Install Hungarian keyboard layout
# 11. Create local config from defaults
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

DOTFILES_PATH="$HOME/dotfiles"

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

    # Follow the stable release redirect to discover the latest version tag.
    # https://aka.ms/powershell-release?tag=stable redirects to the GitHub
    # releases page for the latest stable PowerShell version.
    RELEASE_URL=$(curl -sIL -o /dev/null -w '%{url_effective}' "https://aka.ms/powershell-release?tag=stable")

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
# Dotfiles Setup
# ============================================================================

print_step "Setting up dotfiles..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -d "$DOTFILES_PATH" ]]; then
    print_success "Dotfiles already exist at $DOTFILES_PATH"
else
    print_info "Linking dotfiles to $DOTFILES_PATH..."
    ln -s "$REPO_ROOT" "$DOTFILES_PATH"
    if [[ -L "$DOTFILES_PATH" ]]; then
        print_success "Linked dotfiles to $DOTFILES_PATH"
    else
        print_warning "Could not create symlink, copying instead..."
        cp -R "$REPO_ROOT" "$DOTFILES_PATH"
        print_success "Copied dotfiles to $DOTFILES_PATH"
    fi
fi

# ============================================================================
# Tool Installation
# ============================================================================

if [[ "$SKIP_TOOLS" == false ]]; then
    print_step "Installing tools..."

    TOOLS_PATH="$DOTFILES_PATH/tools"
    
    if [[ ! -d "$TOOLS_PATH" ]]; then
        print_warning "Tools directory not found at $TOOLS_PATH"
    else
        # Count tools
        TOOL_FILES=("$TOOLS_PATH"/*.json)
        TOTAL_TOOLS=${#TOOL_FILES[@]}
        CURRENT_TOOL=0

        for TOOL_FILE in "${TOOL_FILES[@]}"; do
            ((CURRENT_TOOL++))
            
            # Parse JSON using Python (available on macOS by default) or jq if installed
            if command -v jq &> /dev/null; then
                TOOL_NAME=$(jq -r '.name' "$TOOL_FILE")
                VERIFY_CMD=$(jq -r '.verify // empty' "$TOOL_FILE")
                BREW_PKG=$(jq -r '.install.macos.brew // empty' "$TOOL_FILE")
            else
                # Fallback to Python
                TOOL_NAME=$(python3 -c "import json; print(json.load(open('$TOOL_FILE'))['name'])" 2>/dev/null || echo "unknown")
                VERIFY_CMD=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('verify', ''))" 2>/dev/null || echo "")
                BREW_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('macos', {}).get('brew', ''))" 2>/dev/null || echo "")
            fi

            echo -n "   [$CURRENT_TOOL/$TOTAL_TOOLS] $TOOL_NAME..."

            # Check if already installed
            if [[ -n "$VERIFY_CMD" ]]; then
                VERIFY_BIN=$(echo "$VERIFY_CMD" | awk '{print $1}')
                if command -v "$VERIFY_BIN" &> /dev/null; then
                    echo -e " \033[90malready installed\033[0m"
                    continue
                fi
            fi

            # Install via Homebrew
            if [[ -n "$BREW_PKG" ]]; then
                # Check if it's a cask (contains /)
                if [[ "$BREW_PKG" == *"/"* ]] || brew info --cask "$BREW_PKG" &> /dev/null 2>&1; then
                    if brew install "$BREW_PKG" --quiet 2>/dev/null; then
                        echo -e " \033[32mOK (brew)\033[0m"
                    else
                        echo -e " \033[33mFAILED\033[0m"
                    fi
                else
                    if brew install "$BREW_PKG" --quiet 2>/dev/null; then
                        echo -e " \033[32mOK (brew)\033[0m"
                    else
                        echo -e " \033[33mFAILED\033[0m"
                    fi
                fi
            else
                echo -e " \033[33mSKIP (no brew package)\033[0m"
            fi
        done
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

    PROFILE_CONTENT='# Congruens - Cross-platform CLI experience
# Source the dotfiles profile
. "$HOME/dotfiles/powershell/profile.ps1"'

    if [[ -f "$PWSH_PROFILE" ]]; then
        if grep -q "dotfiles/powershell/profile.ps1" "$PWSH_PROFILE"; then
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
# Shell Auto-Launch Configuration
# ============================================================================

print_step "Configuring shell auto-launch..."

# Add PowerShell auto-launch to shell rc files
# This makes pwsh start automatically when opening a terminal

PWSH_LAUNCH_BLOCK='
# Congruens: Auto-launch PowerShell
# Only launch if this is an interactive shell and pwsh is available
if [[ $- == *i* ]] && command -v pwsh &> /dev/null; then
    exec pwsh
fi'

configure_shell_rc() {
    local rc_file="$1"
    local shell_name="$2"
    
    if [[ -f "$rc_file" ]]; then
        if grep -q "Congruens: Auto-launch PowerShell" "$rc_file"; then
            print_success "$shell_name already configured ($rc_file)"
            return
        fi
    fi
    
    # Append the auto-launch block
    echo "$PWSH_LAUNCH_BLOCK" >> "$rc_file"
    print_success "Configured $shell_name to auto-launch PowerShell ($rc_file)"
}

# Configure for bash (default on older macOS)
configure_shell_rc "$HOME/.bash_profile" "bash"

# Configure for zsh (default on macOS Catalina+)
configure_shell_rc "$HOME/.zshrc" "zsh"

# ============================================================================
# oh-my-posh Configuration
# ============================================================================

print_step "Configuring oh-my-posh..."

if command -v oh-my-posh &> /dev/null; then
    print_success "oh-my-posh is installed"
    
    THEME_PATH="$DOTFILES_PATH/omp/congruens.omp.json"
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
# Local Config Setup
# ============================================================================

print_step "Setting up configuration..."

CONFIG_PATH="$DOTFILES_PATH/config"
DEFAULTS_PATH="$CONFIG_PATH/congruens.defaults.json"
LOCAL_PATH="$CONFIG_PATH/congruens.local.json"

if [[ -f "$LOCAL_PATH" ]]; then
    print_success "Local config already exists"
elif [[ -f "$DEFAULTS_PATH" ]]; then
    cp "$DEFAULTS_PATH" "$LOCAL_PATH"
    print_success "Created local config from defaults"
else
    print_warning "Defaults config not found"
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
echo "  To get a native bash/zsh shell, run: bash --norc  or  zsh --norcs"
echo ""
echo -e "\033[33mAvailable commands (in PowerShell):\033[0m"
echo "  mkcd <dir>     - Create directory and cd into it"
echo "  open [path]    - Open in Finder"
echo "  which <cmd>    - Find command location"
echo "  path show      - Display PATH entries"
echo "  path add <dir> - Add to session PATH"
echo ""
