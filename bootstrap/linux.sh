#!/bin/bash
#
# Linux bootstrap script for Congruens.
#
# Automates Linux machine setup:
# 1. Detect Linux distribution and package manager
# 2. Install PowerShell 7
# 3. Read tool definitions from tools/*.json
# 4. Install each tool using native package manager (apt/dnf/pacman) or Homebrew
# 5. Wire PowerShell $PROFILE to source repo profile
# 6. Configure oh-my-posh
# 7. Create local config from defaults
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

# NixOS: packages are declared in the system flake, never installed
# imperatively — apt/dnf/pacman don't exist, Homebrew doesn't work, and
# downloaded binaries can't exec (no FHS loader). Tools and PowerShell
# come from the machine's NixOS configuration; only the profile/omp/config
# wiring steps below apply.
IS_NIXOS=false
if [[ "$DISTRO_ID" == "nixos" ]]; then
    IS_NIXOS=true
    SKIP_TOOLS=true
    print_warning "NixOS detected: skipping Homebrew and tool installation (declare them in the system flake)"
fi

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

if [[ "$IS_NIXOS" == true ]]; then
    print_info "NixOS: Homebrew skipped"
    HAS_BREW=false
elif command -v brew &> /dev/null; then
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
        nixos)
            print_failure "PowerShell not found. On NixOS add pkgs.powershell to the system configuration and rebuild."
            ;;
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
        # Update package manager cache
        if [[ -n "$PKG_MANAGER" ]]; then
            print_info "Updating package cache..."
            $PKG_UPDATE 2>/dev/null || true
        fi

        # Count tools
        TOOL_FILES=("$TOOLS_PATH"/*.json)
        TOTAL_TOOLS=${#TOOL_FILES[@]}
        CURRENT_TOOL=0
        HAS_SELF_MANAGED=false

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
                CARGO_PKG=$(jq -r '.install.linux.cargo // empty' "$TOOL_FILE")
                GITHUB_REPO=$(jq -r '.install.linux.github.repo // empty' "$TOOL_FILE")
            elif command -v python3 &> /dev/null; then
                TOOL_NAME=$(python3 -c "import json; print(json.load(open('$TOOL_FILE'))['name'])" 2>/dev/null || echo "unknown")
                VERIFY_CMD=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('verify', ''))" 2>/dev/null || echo "")
                APT_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('apt', ''))" 2>/dev/null || echo "")
                DNF_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('dnf', ''))" 2>/dev/null || echo "")
                PACMAN_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('pacman', ''))" 2>/dev/null || echo "")
                BREW_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('brew', ''))" 2>/dev/null || echo "")
                CARGO_PKG=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('cargo', ''))" 2>/dev/null || echo "")
                GITHUB_REPO=$(python3 -c "import json; d=json.load(open('$TOOL_FILE')); print(d.get('install', {}).get('linux', {}).get('github', {}).get('repo', ''))" 2>/dev/null || echo "")
            else
                print_warning "Neither jq nor python3 available for JSON parsing"
                continue
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

            # Fall back to cargo for Rust tools with no distro package
            if [[ "$INSTALLED" == false ]] && [[ -n "$CARGO_PKG" ]] && command -v cargo &> /dev/null; then
                if cargo install --quiet "$CARGO_PKG" 2>/dev/null; then
                    echo -e " \033[32mOK (cargo)\033[0m"
                    INSTALLED=true
                fi
            fi

            if [[ "$INSTALLED" == false ]]; then
                echo -e " \033[33mSKIP (no package available)\033[0m"
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
# rc files. Earlier congruens versions injected `exec pwsh` into ~/.bashrc /
# ~/.zshrc, which silently broke everything that expects the login shell to be
# a POSIX shell: terminal cwd tracking (shell integration, OSC 7), apps that
# launch terminals with a command to run, `$SHELL -c` callers, and every
# terminal not covered by the IDE guard list. The rc files now only get a
# small `pw` function to hop into PowerShell on demand; terminals we know how
# to configure (Ghostty) are pointed at pwsh directly, which keeps the
# launch-into-PowerShell experience without hijacking bash/zsh.

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

# Configure for bash (most common default on Linux)
configure_shell_rc "$HOME/.bashrc" "bash"

# Configure for zsh (if installed)
if command -v zsh &> /dev/null; then
    configure_shell_rc "$HOME/.zshrc" "zsh"
fi

# Ghostty: launch pwsh directly in new terminal windows. `ghostty -e <cmd>`
# still overrides this, so app-launched terminals with explicit commands keep
# working, and bash/zsh stays the login shell for everything else.
configure_ghostty() {
    local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/ghostty"
    local cfg="$cfg_dir/config"
    local pwsh_path
    pwsh_path="$(command -v pwsh || true)"
    [[ -n "$pwsh_path" ]] || return 0

    if ! command -v ghostty &> /dev/null; then
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

# Congruens: launch PowerShell in new terminals (delete these lines for bash/zsh)
command = $pwsh_path
GHOSTTY
    print_success "Configured Ghostty to launch PowerShell (command = $pwsh_path)"
    print_info "Reload Ghostty config (Ctrl+Shift+,) or restart Ghostty to apply"
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

CONFIG_PATH="$REPO_ROOT/config"
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
# Claude Code Notifications (peon-ping)
# ============================================================================

print_step "Setting up peon-ping (Claude Code notifications)..."

# peon-ping (https://github.com/PeonPing/peon-ping) plays Warcraft peon voice
# lines on Claude Code lifecycle events. Its installer registers hooks in
# ~/.claude/settings.json, so it must only run AFTER agents/install.sh has
# seeded that file - a hook-only settings.json created first would make the
# seed step skip, and the machine would silently miss the shared config.

PEON_HOOKS_DIR="$HOME/.claude/hooks/peon-ping"
PEON_CONFIG_SEED="$REPO_ROOT/agents/config/peon-ping.json"

if [[ -d "$PEON_HOOKS_DIR" ]]; then
    print_success "peon-ping already installed (re-run its installer to update)"
elif [[ ! -f "$HOME/.claude/settings.json" ]]; then
    print_warning "~/.claude/settings.json not seeded yet - run agents/install.sh first, then re-run this bootstrap to get peon-ping"
else
    PEON_INSTALLED=false
    if command -v brew &> /dev/null; then
        if brew install PeonPing/tap/peon-ping --quiet 2>/dev/null && peon-ping-setup; then
            PEON_INSTALLED=true
        fi
    fi
    # No Linuxbrew on this machine: fall back to the upstream install script,
    # which registers the hooks itself.
    if [[ "$PEON_INSTALLED" == false ]]; then
        if curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash; then
            PEON_INSTALLED=true
        fi
    fi
    if [[ "$PEON_INSTALLED" == true ]]; then
        print_success "peon-ping installed and hooks registered"
        # Seed the shared config over the installer's default on fresh
        # installs only, so per-machine tweaks survive later bootstrap runs.
        # The seed's "packs" field is congruens's own (peon-ping ignores it):
        # the shared roster of sound packs to pull onto every machine.
        if [[ -f "$PEON_CONFIG_SEED" ]]; then
            cp -f "$PEON_CONFIG_SEED" "$PEON_HOOKS_DIR/config.json"
            print_success "Seeded shared peon-ping config"
            PEON_PACKS=$(jq -r '(.packs // []) | join(",")' "$PEON_CONFIG_SEED" 2>/dev/null \
                || python3 -c "import json; print(','.join(json.load(open('$PEON_CONFIG_SEED')).get('packs', [])))" 2>/dev/null \
                || echo "")
            if [[ -n "$PEON_PACKS" ]]; then
                if command -v peon &> /dev/null; then
                    peon packs install "$PEON_PACKS" || print_warning "Some peon-ping packs failed to install"
                elif [[ -f "$PEON_HOOKS_DIR/peon.sh" ]]; then
                    bash "$PEON_HOOKS_DIR/peon.sh" packs install "$PEON_PACKS" || print_warning "Some peon-ping packs failed to install"
                else
                    print_warning "peon CLI not found - install packs later with: peon packs install $PEON_PACKS"
                fi
            fi
        fi
    else
        print_warning "peon-ping install failed - see https://github.com/PeonPing/peon-ping"
    fi
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
echo "  (deferred until just before the first prompt, so installer PATH"
echo "   exports written later in those files still take effect)"
echo "  To get a native bash/zsh shell, run: bash --norc  or  zsh --norcs"
echo ""
echo -e "\033[33mAvailable commands (in PowerShell):\033[0m"
echo "  mkcd <dir>     - Create directory and cd into it"
echo "  open [path]    - Open in file manager (xdg-open)"
echo "  which <cmd>    - Find command location"
echo "  path show      - Display PATH entries"
echo "  path add <dir> - Add to session PATH"
echo ""
