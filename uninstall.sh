#!/usr/bin/env bash

# uninstall.sh - Uninstallation script for kube-ctx-manager

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
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

# Detect shell and config file
detect_shell() {
    if [[ -n "$BASH_VERSION" ]]; then
        SHELL_TYPE="bash"
        SHELL_RC="$HOME/.bashrc"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            SHELL_RC="$HOME/.bash_profile"
        fi
    elif [[ -n "$ZSH_VERSION" ]]; then
        SHELL_TYPE="zsh"
        SHELL_RC="$HOME/.zshrc"
    else
        print_error "Unsupported shell: $SHELL"
        exit 1
    fi
}

# Remove source line from shell config
remove_from_shell_config() {
    print_info "Removing kube-ctx-manager from $SHELL_RC..."
    
    if [[ ! -f "$SHELL_RC" ]]; then
        print_warning "$SHELL_RC not found"
        return
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    # Remove kube-ctx-manager lines
    grep -v "# kube-ctx-manager" "$SHELL_RC" | grep -v "kube-ctx-manager" > "$temp_file"
    
    if [[ -s "$temp_file" ]]; then
        mv "$temp_file" "$SHELL_RC"
        print_success "Removed kube-ctx-manager from $SHELL_RC"
    else
        rm "$temp_file"
        print_warning "$SHELL_RC would be empty, keeping original"
    fi
}

# Remove installation directory
remove_installation() {
    print_info "Removing installation directory..."
    
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        print_success "Removed $INSTALL_DIR"
    else
        print_warning "Installation directory not found: $INSTALL_DIR"
    fi
}

# Clean up user data files
cleanup_user_data() {
    print_info "Cleaning up user data files..."
    
    local files=(
        "$HOME/.kube-usage"
        "$HOME/.kube-aliases"
        "$HOME/.kube/audit.log"
    )
    
    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            read -p "Remove $file? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm "$file"
                print_success "Removed $file"
            else
                print_warning "Kept $file"
            fi
        fi
    done
}

# Unset functions and variables
cleanup_shell_environment() {
    print_info "Cleaning up shell environment..."
    
    # Unset functions
    local functions=(
        "kx"
        "kns"
        "kube-suggest"
        "kube-suggest-apply"
        "kube-audit"
        "kube-audit-search"
        "kube-audit-stats"
        "_kcm_get_current_context"
        "_kcm_get_current_namespace"
        "_kcm_list_contexts"
        "_kcm_list_namespaces"
        "_kcm_switch_context"
        "_kcm_switch_namespace"
        "_kcm_is_prod_context"
        "_kcm_is_destructive_command"
        "_kcm_prompt_confirmation"
        "_kcm_audit_command"
        "_kcm_setup_safeguard"
        "_kcm_kubectl_wrapper"
        "_kcm_suggester_init"
        "_kcm_setup_bash_hook"
        "_kcm_setup_zsh_hook"
        "_kcm_track_command"
        "_kcm_suggest_aliases"
        "_kcm_generate_alias_name"
        "_kcm_apply_suggested_aliases"
        "_kcm_setup_prompt"
        "_kcm_setup_bash_prompt"
        "_kcm_setup_zsh_prompt"
        "_kcm_build_prompt"
        "_kcm_build_zsh_prompt"
        "_kcm_get_prompt_info"
        "_kcm_init_audit_log"
        "_kcm_audit_command_detailed"
    )
    
    for func in "${functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            unset -f "$func"
        fi
    done
    
    # Unset variables
    local variables=(
        "KCM_LOADED"
        "KCM_PROD_PATTERN"
        "KCM_SUGGEST_THRESHOLD"
        "KCM_AUDIT_LOG"
        "KCM_PROMPT"
        "KCM_PROMPT_STYLE"
        "KCM_DIR"
        "KCM_USAGE_FILE"
        "KCM_ALIASES_FILE"
        "KCM_PREV_CONTEXT"
        "KCM_ORIGINAL_PS1"
        "KCM_ORIGINAL_PROMPT"
        "KCM_ORIGINAL_RPROMPT"
    )
    
    for var in "${variables[@]}"; do
        if [[ -n "${!var+x}" ]]; then
            unset "$var"
        fi
    done
    
    # Remove kubectl alias
    if alias kubectl 2>/dev/null | grep -q "_kcm_kubectl_wrapper"; then
        unalias kubectl
        print_success "Removed kubectl wrapper"
    fi
    
    print_success "Cleaned up shell environment"
}

# Print post-uninstall instructions
print_post_uninstall() {
    echo ""
    print_success "Uninstallation complete!"
    echo ""
    print_info "To complete the removal:"
    echo "1. Restart your terminal to clear all functions and variables"
    echo "2. Or run: exec $SHELL"
    echo ""
    print_info "Note: Your kubeconfig files and kubectl installation were not modified."
}

# Main uninstallation flow
main() {
    echo "kube-ctx-manager Uninstallation"
    echo "==============================="
    echo ""
    
    detect_shell
    
    print_warning "This will remove kube-ctx-manager from your system."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstallation cancelled"
        exit 0
    fi
    
    remove_from_shell_config
    cleanup_shell_environment
    remove_installation
    cleanup_user_data
    print_post_uninstall
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --clean       Also remove user data files (usage, aliases, audit log)"
        echo ""
        echo "This script uninstalls kube-ctx-manager from your system."
        exit 0
        ;;
    --clean)
        print_info "Running with --clean option"
        main
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
