#!/usr/bin/env bash

# install.sh - Installation script for kube-ctx-manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/your-username/kube-ctx-manager"
INSTALL_DIR="$HOME/.kube-ctx-manager"

# Helper functions
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "ℹ $1"
}

# Check dependencies
check_dependencies() {
    print_info "Checking dependencies..."
    
    # Check kubectl
    if ! command -v kubectl >/dev/null 2>&1; then
        print_error "kubectl is not installed or not in PATH"
        print_info "Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
        exit 1
    fi
    print_success "kubectl found: $(kubectl version --client --short 2>/dev/null | head -1 || kubectl version --client 2>/dev/null | head -1)"
    
    # Check fzf
    if ! command -v fzf >/dev/null 2>&1; then
        print_error "fzf is not installed or not in PATH"
        print_info "Please install fzf: https://github.com/junegunn/fzf"
        exit 1
    fi
    print_success "fzf found: $(fzf --version)"
    
    # Check shell
    if [[ -n "$BASH_VERSION" ]]; then
        SHELL_TYPE="bash"
        SHELL_RC="$HOME/.bashrc"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SHELL_RC="$HOME/.bash_profile"
        fi
        print_success "Bash detected"
    elif [[ -n "$ZSH_VERSION" ]]; then
        SHELL_TYPE="zsh"
        SHELL_RC="$HOME/.zshrc"
        print_success "Zsh detected"
    else
        print_error "Unsupported shell: $SHELL"
        print_info "This plugin supports Bash 4+ and Zsh 5+"
        exit 1
    fi
}

# Install files
install_files() {
    print_info "Installing files to $INSTALL_DIR..."
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Copy files
    cp -r lib "$INSTALL_DIR/"
    cp kube-ctx-manager.bash "$INSTALL_DIR/"
    cp kube-ctx-manager.plugin.zsh "$INSTALL_DIR/"
    
    # Make scripts executable
    chmod +x "$INSTALL_DIR/lib/"*.sh
    chmod +x "$INSTALL_DIR/"*.bash
    chmod +x "$INSTALL_DIR/"*.zsh
    
    print_success "Files installed to $INSTALL_DIR"
}

# Update shell configuration
update_shell_config() {
    print_info "Updating $SHELL_RC..."
    
    local source_line="source \"$INSTALL_DIR/kube-ctx-manager.$SHELL_TYPE\""
    
    # Check if already sourced
    if grep -q "$source_line" "$SHELL_RC" 2>/dev/null; then
        print_warning "kube-ctx-manager already sourced in $SHELL_RC"
        return
    fi
    
    # Add source line
    echo "" >> "$SHELL_RC"
    echo "# kube-ctx-manager" >> "$SHELL_RC"
    echo "$source_line" >> "$SHELL_RC"
    
    print_success "Added source line to $SHELL_RC"
}

# Verify installation
verify_installation() {
    print_info "Verifying installation..."
    
    # Source the plugin
    source "$INSTALL_DIR/kube-ctx-manager.$SHELL_TYPE"
    
    # Check if functions are available
    if command -v kx >/dev/null 2>&1; then
        print_success "kx function available"
    else
        print_error "kx function not found"
        return 1
    fi
    
    if command -v kns >/dev/null 2>&1; then
        print_success "kns function available"
    else
        print_error "kns function not found"
        return 1
    fi
    
    if command -v kube-suggest >/dev/null 2>&1; then
        print_success "kube-suggest function available"
    else
        print_error "kube-suggest function not found"
        return 1
    fi
    
    print_success "Installation verified successfully"
}

# Print post-installation instructions
print_post_install() {
    echo ""
    print_success "Installation complete!"
    echo ""
    print_info "Next steps:"
    echo "1. Restart your terminal or run: source $SHELL_RC"
    echo "2. Try the new commands:"
    echo "   - kx          # Fuzzy context switcher"
    echo "   - kns         # Fuzzy namespace switcher"
    echo "   - kube-suggest # Alias suggestions"
    echo ""
    print_info "Configuration options (set in $SHELL_RC before sourcing):"
    echo "   export KCM_PROD_PATTERN=\"prod|production|live|prd\""
    echo "   export KCM_SUGGEST_THRESHOLD=3"
    echo "   export KCM_PROMPT=1"
    echo "   export KCM_PROMPT_STYLE=\"full\""
    echo ""
    print_info "For more information, visit: $REPO_URL"
}

# Main installation flow
main() {
    echo "kube-ctx-manager Installation"
    echo "============================="
    echo ""
    
    check_dependencies
    install_files
    update_shell_config
    verify_installation
    print_post_install
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --uninstall   Uninstall kube-ctx-manager"
        echo ""
        echo "This script installs kube-ctx-manager to $INSTALL_DIR"
        exit 0
        ;;
    --uninstall)
        print_info "Uninstalling kube-ctx-manager..."
        if [[ -f "$INSTALL_DIR/uninstall.sh" ]]; then
            "$INSTALL_DIR/uninstall.sh"
        else
            print_error "Uninstall script not found"
            exit 1
        fi
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
