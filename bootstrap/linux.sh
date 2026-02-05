#!/bin/bash
#
# Linux bootstrap script for Congruens.
#
# Automates Linux machine setup:
# 1. Detect Linux distribution and package manager
# 2. Install PowerShell 7
# 3. Read tool definitions from tools/*.json
# 4. Install each tool using native package manager (apt/dnf/pacman) or Homebrew
# 5. Link dotfiles to ~/dotfiles
# 6. Wire PowerShell $PROFILE to source repo profile
# 7. Configure oh-my-posh
# 8. Create local config from defaults
#
# Usage:
#   ./linux.sh           # Run the full bootstrap process
#   ./linux.sh --skip-tools    # Skip tool installation
#   ./linux.sh --skip-profile  # Skip profile configuration
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
# Detect Linux Distribution
# ============================================================================

detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="$ID"
        DISTRO_NAME="$NAME"
        DISTRO_VERSION="$VERSION_ID"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        DISTRO_ID="$DISTRIB_ID"
        DISTRO_NAME="$DISTRIB_DESCRIPTION"
        DISTRO_VERSION="$DISTRIB_RELEASE"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown Linux"
        DISTRO_VERSION=""
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt-get install -y"
        PKG_UPDATE="sudo apt-get update"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_INSTALL="sudo dnf install -y"
        PKG_UPDATE="sudo dnf check-update || true"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        PKG_UPDATE="sudo pacman -Sy"
    else
        PKG_MANAGER=""
    fi
}

# ============================================================================
# Prerequisites Check
# ============================================================================

print_step "Checking prerequisites..."

# Check Linux
if [[ "$(uname)" != "Linux" ]]; then
    print_failure "This script is for Linux only"
    exit 1
fi

# Detect distribution
detect_distro
print_success "Running on $DISTRO_NAME"

# Detect package manager
detect_package_manager
if [[ -n "$PKG_MANAGER" ]]; then
    print_success "Package manager: $PKG_MANAGER"
else
    print_warning "No supported package manager found (apt/dnf/pacman)"
fi

# Check for curl
if ! command -v curl &> /dev/null; then
    if [[ -n "$PKG_MANAGER" ]]; then
        print_info "Installing curl..."
        $PKG_UPDATE
        $PKG_INSTALL curl
    else
        print_failure "curl is required but not installed"
        exit 1
    fi
fi
print_success "curl is available"

# ============================================================================
# Homebrew Setup (Optional, for tools not in native repos)
# ============================================================================

print_step "Checking Homebrew (Linuxbrew)..."

if command -v brew &> /dev/null; then
    print_success "Homebrew is already installed"
    HAS_BREW=true
else
    print_info "Installing Homebrew (Linuxbrew)..."
    
    # Install build dependencies first
    if [[ "$PKG_MANAGER" == "apt" ]]; then
        $PKG_UPDATE
        $PKG_INSTALL build-essential procps curl file git
    elif [[ "$PKG_MANAGER" == "dnf" ]]; then
        $PKG_INSTALL procps-ng curl file git
        sudo dnf groupinstall -y 'Development Tools'
    elif [[ "$PKG_MANAGER" == "pacman" ]]; then
        $PKG_INSTALL base-devel procps-ng curl file git
    fi
    
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for this session
    if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    elif [[ -d "$HOME/.linuxbrew" ]]; then
        eval "$($HOME/.linuxbrew/bin/brew shellenv)"
    fi
    
    if command -v brew &> /dev/null; then
        print_success "Homebrew installed"
        HAS_BREW=true
    else
        print_warning "Homebrew installation may require shell restart"
        HAS_BREW=false
    fi
fi

# ============================================================================
# PowerShell 7 Installation
# ============================================================================

print_step "Setting up PowerShell 7..."

if command -v pwsh &> /dev/null; then
    PWSH_VERSION=$(pwsh --version | head -1)
    print_success "PowerShell is already installed: $PWSH_VERSION"
else
    print_info "Installing PowerShell..."
    
    case "$DISTRO_ID" in
        ubuntu|debian)
            # Install prerequisites
            $PKG_UPDATE
            $PKG_INSTALL wget apt-transport-https software-properties-common
            
            # Get Ubuntu/Debian version
            source /etc/os-release
            
            # Download and register Microsoft repository GPG keys
            wget -q "https://packages.microsoft.com/config/$ID/$VERSION_ID/packages-microsoft-prod.deb" -O /tmp/packages-microsoft-prod.deb
            sudo dpkg -i /tmp/packages-microsoft-prod.deb
            rm /tmp/packages-microsoft-prod.deb
            
            # Install PowerShell
            $PKG_UPDATE
            $PKG_INSTALL powershell
            ;;
        fedora)
            # Install Microsoft repository
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
            
            # Install PowerShell
            $PKG_INSTALL powershell
            ;;
        rhel|centos|rocky|almalinux)
            # Register Microsoft RedHat repository
            curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
            
            # Install PowerShell
            $PKG_INSTALL powershell
            ;;
        arch|manjaro|endeavouros)
            # PowerShell is available in AUR, use yay if available
            if command -v yay &> /dev/null; then
                yay -S --noconfirm powershell-bin
            elif command -v paru &> /dev/null; then
                paru -S --noconfirm powershell-bin
            else
                print_warning "Installing powershell-bin from AUR requires yay or paru"
                print_info "Install manually: yay -S powershell-bin"
                # Fallback to Homebrew if available
                if [[ "$HAS_BREW" == true ]]; then
                    brew install powershell/tap/powershell
                fi
            fi
            ;;
        opensuse*|sles)
            # Register Microsoft repository
            sudo zypper addrepo https://packages.microsoft.com/rhel/7/prod/ microsoft
            sudo zypper refresh
            sudo zypper install -y powershell
            ;;
        *)
            # Fallback: Try Homebrew
            if [[ "$HAS_BREW" == true ]]; then
                brew install powershell/tap/powershell
            else
                print_failure "Unsupported distribution: $DISTRO_ID"
                print_info "Please install PowerShell manually: https://docs.microsoft.com/powershell/scripting/install/installing-powershell-on-linux"
                exit 1
            fi
            ;;
    esac
    
    print_success "PowerShell installed"
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
        # Update package manager cache
        if [[ -n "$PKG_MANAGER" ]]; then
            print_info "Updating package cache..."
            $PKG_UPDATE 2>/dev/null || true
        fi

        # Count tools
        TOOL_FILES=("$TOOLS_PATH"/*.json)
        TOTAL_TOOLS=${#TOOL_FILES[@]}
        CURRENT_TOOL=0

        for TOOL_FILE in "${TOOL_FILES[@]}"; do
            ((CURRENT_TOOL++))
            
            # Parse JSON - try jq first, then python3
            if command -v jq &> /dev/null; then
                TOOL_NAME=$(jq -r '.name' "$TOOL_FILE")
                VERIFY_CMD=$(jq -r '.verify // empty' "$TOOL_FILE")
                APT_PKG=$(jq -r '.install.linux.apt // empty' "$TOOL_FILE")
                DNF_PKG=$(jq -r '.install.linux.dnf // empty' "$TOOL_FILE")
                PACMAN_PKG=$(jq -r '.install.linux.pacman // empty' "$TOOL_FILE")
                BREW_PKG=$(jq -r '.install.linux.brew // empty' "$TOOL_FILE")
            elif command -v python3 &> /dev/null; then
                TOOL_NAME=$(python3 -c "import json; print(json.load(open('$TOOL_FILE'))['name'])" 2>/dev/null || echo "unknown")
                VERIFY_CMD=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('verify', ''))" 2>/dev/null || echo "")
                APT_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('apt', ''))" 2>/dev/null || echo "")
                DNF_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('dnf', ''))" 2>/dev/null || echo "")
                PACMAN_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('pacman', ''))" 2>/dev/null || echo "")
                BREW_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('brew', ''))" 2>/dev/null || echo "")
            else
                print_warning "Neither jq nor python3 available for JSON parsing"
                continue
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

            INSTALLED=false

            # Try native package manager first
            case "$PKG_MANAGER" in
                apt)
                    if [[ -n "$APT_PKG" ]]; then
                        if $PKG_INSTALL "$APT_PKG" &> /dev/null; then
                            echo -e " \033[32mOK (apt)\033[0m"
                            INSTALLED=true
                        fi
                    fi
                    ;;
                dnf)
                    if [[ -n "$DNF_PKG" ]]; then
                        if $PKG_INSTALL "$DNF_PKG" &> /dev/null; then
                            echo -e " \033[32mOK (dnf)\033[0m"
                            INSTALLED=true
                        fi
                    fi
                    ;;
                pacman)
                    if [[ -n "$PACMAN_PKG" ]]; then
                        if $PKG_INSTALL "$PACMAN_PKG" &> /dev/null; then
                            echo -e " \033[32mOK (pacman)\033[0m"
                            INSTALLED=true
                        fi
                    fi
                    ;;
            esac

            # Fallback to Homebrew
            if [[ "$INSTALLED" == false ]] && [[ "$HAS_BREW" == true ]] && [[ -n "$BREW_PKG" ]]; then
                if brew install "$BREW_PKG" --quiet 2>/dev/null; then
                    echo -e " \033[32mOK (brew)\033[0m"
                    INSTALLED=true
                fi
            fi

            if [[ "$INSTALLED" == false ]]; then
                echo -e " \033[33mSKIP (no package available)\033[0m"
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

# Configure for bash (most common default on Linux)
configure_shell_rc "$HOME/.bashrc" "bash"

# Configure for zsh (if installed)
if command -v zsh &> /dev/null; then
    configure_shell_rc "$HOME/.zshrc" "zsh"
fi

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
    FONT_INSTALLED=false
    
    # Try package manager first
    case "$PKG_MANAGER" in
        pacman)
            # Check if yay or paru is available for AUR
            if command -v yay &> /dev/null; then
                print_info "Installing via yay (AUR)..."
                if yay -S --noconfirm ttf-cascadia-code-nerd 2>/dev/null; then
                    print_success "CaskaydiaCove Nerd Font installed via yay"
                    FONT_INSTALLED=true
                fi
            elif command -v paru &> /dev/null; then
                print_info "Installing via paru (AUR)..."
                if paru -S --noconfirm ttf-cascadia-code-nerd 2>/dev/null; then
                    print_success "CaskaydiaCove Nerd Font installed via paru"
                    FONT_INSTALLED=true
                fi
            fi
            ;;
        dnf)
            print_info "Installing via dnf..."
            if $PKG_INSTALL cascadia-code-nerd-fonts 2>/dev/null; then
                print_success "CaskaydiaCove Nerd Font installed via dnf"
                FONT_INSTALLED=true
            fi
            ;;
    esac
    
    # Fallback: Manual download and install
    if [[ "$FONT_INSTALLED" == false ]]; then
        print_info "Downloading CaskaydiaCove Nerd Font..."
        
        FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip"
        FONT_DIR="$HOME/.local/share/fonts/CaskaydiaCove"
        TEMP_ZIP="/tmp/CascadiaCode.zip"
        TEMP_DIR="/tmp/CascadiaCode"
        
        # Download
        if curl -fsSL "$FONT_URL" -o "$TEMP_ZIP"; then
            # Create font directory
            mkdir -p "$FONT_DIR"
            
            # Extract
            if command -v unzip &> /dev/null; then
                rm -rf "$TEMP_DIR"
                unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"
                
                # Copy only .ttf files (excluding Windows-specific variants)
                find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
                
                # Cleanup
                rm -f "$TEMP_ZIP"
                rm -rf "$TEMP_DIR"
                
                # Update font cache
                print_info "Updating font cache..."
                fc-cache -f "$FONT_DIR" 2>/dev/null
                
                print_success "CaskaydiaCove Nerd Font installed to $FONT_DIR"
                FONT_INSTALLED=true
            else
                print_warning "unzip not found - installing..."
                if [[ -n "$PKG_MANAGER" ]]; then
                    $PKG_INSTALL unzip
                    unzip -q "$TEMP_ZIP" -d "$TEMP_DIR"
                    find "$TEMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR/" \;
                    rm -f "$TEMP_ZIP"
                    rm -rf "$TEMP_DIR"
                    fc-cache -f "$FONT_DIR" 2>/dev/null
                    print_success "CaskaydiaCove Nerd Font installed to $FONT_DIR"
                    FONT_INSTALLED=true
                fi
            fi
        else
            print_warning "Failed to download font"
        fi
    fi
    
    if [[ "$FONT_INSTALLED" == false ]]; then
        print_warning "Could not install font automatically"
        print_info "Install manually from: https://www.nerdfonts.com/font-downloads"
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
echo "     For GNOME Terminal:"
echo "       - Open Preferences"
echo "       - Select your profile > Text"
echo "       - Enable Custom font and select: CaskaydiaCove Nerd Font"
echo ""
echo "     For Konsole:"
echo "       - Open Settings > Edit Current Profile > Appearance"
echo "       - Click Edit next to the font preview"
echo "       - Select: CaskaydiaCove Nerd Font"
echo ""
echo "     For VS Code integrated terminal, add to settings.json:"
echo "       \"terminal.integrated.fontFamily\": \"CaskaydiaCove Nerd Font\""
echo ""
echo -e "\033[33mNote:\033[0m"
echo "  PowerShell auto-launches via ~/.bashrc (and ~/.zshrc if zsh is installed)"
echo "  To get a native bash/zsh shell, run: bash --norc  or  zsh --norcs"
echo ""
echo -e "\033[33mAvailable commands (in PowerShell):\033[0m"
echo "  mkcd <dir>     - Create directory and cd into it"
echo "  open [path]    - Open in file manager (xdg-open)"
echo "  which <cmd>    - Find command location"
echo "  path show      - Display PATH entries"
echo "  path add <dir> - Add to session PATH"
echo ""
