#!/usr/bin/env bash

# nfav.sh - Namespace favorites management

# Namespace favorites file
export KCM_NS_FAVORITES_FILE="$HOME/.kube-namespace-favorites"
export KCM_NS_FAVORITES_MAX="${KCM_NS_FAVORITES_MAX:-10}"

# Initialize namespace favorites system
_kcm_nsfav_init() {
    if [[ ! -f "$KCM_NS_FAVORITES_FILE" ]]; then
        touch "$KCM_NS_FAVORITES_FILE"
        chmod 600 "$KCM_NS_FAVORITES_FILE"
    fi
}

# Add namespace to favorites
_kcm_nsfav_add() {
    local namespace="$1"
    local context="${2:-$(_kcm_get_current_context)}"
    local description="${3:-}"
    
    if [[ -z "$namespace" ]]; then
        _kcm_error "Namespace name required"
        return 1
    fi
    
    # Check if namespace exists in context
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        _kcm_error "Namespace does not exist: $namespace"
        return 1
    fi
    
    # Check if already exists
    if grep -q "^$context:$namespace:" "$KCM_NS_FAVORITES_FILE" 2>/dev/null; then
        _kcm_warning "Namespace already in favorites for this context"
        return 0
    fi
    
    # Add to favorites
    echo "$context:$namespace:$description" >> "$KCM_NS_FAVORITES_FILE"
    _kcm_success "Added '$namespace' to favorites (context: $context)"
}

# Remove namespace from favorites
_kcm_nsfav_remove() {
    local namespace="$1"
    local context="${2:-$(_kcm_get_current_context)}"
    
    if [[ -z "$namespace" ]]; then
        _kcm_error "Namespace name required"
        return 1
    fi
    
    if grep -q "^$context:$namespace:" "$KCM_NS_FAVORITES_FILE" 2>/dev/null; then
        grep -v "^$context:$namespace:" "$KCM_NS_FAVORITES_FILE" > "${KCM_NS_FAVORITES_FILE}.tmp"
        mv "${KCM_NS_FAVORITES_FILE}.tmp" "$KCM_NS_FAVORITES_FILE"
        _kcm_success "Removed '$namespace' from favorites"
    else
        _kcm_warning "Namespace not in favorites"
    fi
}

# List favorites
_kcm_nsfav_list() {
    local context="${1:-$(_kcm_get_current_context)}"
    
    if [[ ! -f "$KCM_NS_FAVORITES_FILE" ]] || [[ ! -s "$KCM_NS_FAVORITES_FILE" ]]; then
        echo "No namespace favorites yet. Add one with: kns-fav-add <namespace>"
        return 0
    fi
    
    echo "Namespace Favorites (context: $context):"
    echo "=========================================="
    grep "^$context:" "$KCM_NS_FAVORITES_FILE" 2>/dev/null | while IFS=: read -r ctx ns desc; do
        if [[ -n "$desc" ]]; then
            echo "  ⭐ $ns - $desc"
        else
            echo "  ⭐ $ns"
        fi
    done
}

# Get favorites list for current context
_kcm_nsfav_get() {
    local context="${1:-$(_kcm_get_current_context)}"
    
    if [[ -f "$KCM_NS_FAVORITES_FILE" ]]; then
        grep "^$context:" "$KCM_NS_FAVORITES_FILE" 2>/dev/null | cut -d: -f2
    fi
}

# Switch to favorite namespace
_kcm_nsfav_switch() {
    local namespace="$1"
    
    if [[ -z "$namespace" ]]; then
        # Show interactive selection
        if ! command -v fzf >/dev/null 2>&1; then
            _kcm_nsfav_list
            return 0
        fi
        
        local selected
        selected=$(_kcm_nsfav_get | fzf \
            --height=40% \
            --layout=reverse \
            --border \
            --prompt="Select namespace> " \
            --header="Favorite Namespaces")
        
        if [[ -n "$selected" ]]; then
            _kcm_set_namespace "$selected"
        fi
    else
        # Switch directly
        if grep -q "^$(_kcm_get_current_context):$namespace:" "$KCM_NS_FAVORITES_FILE" 2>/dev/null; then
            _kcm_set_namespace "$namespace"
        else
            _kcm_error "Namespace not in favorites: $namespace"
            return 1
        fi
    fi
}

# User commands for namespace favorites
kns-fav-add() {
    _kcm_nsfav_init
    local namespace="$1"
    local description="${2:-}"
    _kcm_nsfav_add "$namespace" "$(_kcm_get_current_context)" "$description"
}

kns-fav-remove() {
    _kcm_nsfav_init
    local namespace="$1"
    _kcm_nsfav_remove "$namespace" "$(_kcm_get_current_context)"
}

kns-fav-list() {
    _kcm_nsfav_init
    _kcm_nsfav_list "$(_kcm_get_current_context)"
}

kns-fav() {
    _kcm_nsfav_init
    local namespace="$1"
    _kcm_nsfav_switch "$namespace"
}
