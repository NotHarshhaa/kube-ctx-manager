#!/usr/bin/env bash

# history.sh - Context history and favorites management

# History and favorites files
export KCM_HISTORY_FILE="$HOME/.kube-context-history"
export KCM_FAVORITES_FILE="$HOME/.kube-context-favorites"
export KCM_HISTORY_MAX="${KCM_HISTORY_MAX:-20}"
export KCM_FAVORITES_MAX="${KCM_FAVORITES_MAX:-10}"

# Initialize history system
_kcm_history_init() {
    # Create history file if it doesn't exist
    if [[ ! -f "$KCM_HISTORY_FILE" ]]; then
        touch "$KCM_HISTORY_FILE"
        chmod 600 "$KCM_HISTORY_FILE"
    fi
    
    # Create favorites file if it doesn't exist
    if [[ ! -f "$KCM_FAVORITES_FILE" ]]; then
        touch "$KCM_FAVORITES_FILE"
        chmod 600 "$KCM_FAVORITES_FILE"
    fi
}

# Add context to history
_kcm_history_add() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        return 1
    fi
    
    # Remove if already exists (to move to top)
    if [[ -f "$KCM_HISTORY_FILE" ]]; then
        grep -v "^$context$" "$KCM_HISTORY_FILE" > "${KCM_HISTORY_FILE}.tmp"
        mv "${KCM_HISTORY_FILE}.tmp" "$KCM_HISTORY_FILE"
    fi
    
    # Add to top
    echo "$context" > "${KCM_HISTORY_FILE}.tmp"
    cat "$KCM_HISTORY_FILE" >> "${KCM_HISTORY_FILE}.tmp"
    mv "${KCM_HISTORY_FILE}.tmp" "$KCM_HISTORY_FILE"
    
    # Trim to max size
    if [[ $(wc -l < "$KCM_HISTORY_FILE") -gt $KCM_HISTORY_MAX ]]; then
        head -n "$KCM_HISTORY_MAX" "$KCM_HISTORY_FILE" > "${KCM_HISTORY_FILE}.tmp"
        mv "${KCM_HISTORY_FILE}.tmp" "$KCM_HISTORY_FILE"
    fi
}

# Get context history
_kcm_history_get() {
    if [[ -f "$KCM_HISTORY_FILE" ]]; then
        cat "$KCM_HISTORY_FILE"
    fi
}

# Clear context history
_kcm_history_clear() {
    > "$KCM_HISTORY_FILE"
    _kcm_success "Context history cleared"
}

# Add context to favorites
_kcm_favorites_add() {
    local context="$1"
    local description="${2:-}"
    
    if [[ -z "$context" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    # Check if already exists
    if grep -q "^$context:" "$KCM_FAVORITES_FILE" 2>/dev/null; then
        _kcm_warning "Context already in favorites"
        return 0
    fi
    
    # Add to favorites
    echo "$context:$description" >> "$KCM_FAVORITES_FILE"
    _kcm_success "Added '$context' to favorites"
}

# Remove context from favorites
_kcm_favorites_remove() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    if grep -q "^$context:" "$KCM_FAVORITES_FILE" 2>/dev/null; then
        grep -v "^$context:" "$KCM_FAVORITES_FILE" > "${KCM_FAVORITES_FILE}.tmp"
        mv "${KCM_FAVORITES_FILE}.tmp" "$KCM_FAVORITES_FILE"
        _kcm_success "Removed '$context' from favorites"
    else
        _kcm_warning "Context not in favorites"
    fi
}

# List favorites
_kcm_favorites_list() {
    if [[ ! -f "$KCM_FAVORITES_FILE" ]] || [[ ! -s "$KCM_FAVORITES_FILE" ]]; then
        echo "No favorites yet. Add one with: kfav-add <context>"
        return 0
    fi
    
    echo "Context Favorites:"
    echo "=================="
    while IFS=: read -r context description; do
        if [[ -n "$description" ]]; then
            echo "  ⭐ $context - $description"
        else
            echo "  ⭐ $context"
        fi
    done < "$KCM_FAVORITES_FILE"
}

# Get favorites list
_kcm_favorites_get() {
    if [[ -f "$KCM_FAVORITES_FILE" ]]; then
        cut -d: -f1 "$KCM_FAVORITES_FILE"
    fi
}

# Switch to favorite context
_kcm_favorites_switch() {
    local favorite="$1"
    
    if [[ -z "$favorite" ]]; then
        # Show interactive selection
        if ! command -v fzf >/dev/null 2>&1; then
            _kcm_favorites_list
            return 0
        fi
        
        local selected
        selected=$(_kcm_favorites_get | fzf \
            --height=40% \
            --layout=reverse \
            --border \
            --prompt="Select favorite> " \
            --header="Context Favorites")
        
        if [[ -n "$selected" ]]; then
            _kcm_switch_context "$selected"
        fi
    else
        # Switch directly
        if grep -q "^$favorite:" "$KCM_FAVORITES_FILE" 2>/dev/null; then
            _kcm_switch_context "$favorite"
        else
            _kcm_error "Favorite not found: $favorite"
            return 1
        fi
    fi
}

# Show context stats
_kcm_context_stats() {
    local current_context
    current_context=$(_kcm_get_current_context)
    
    echo "Context Statistics:"
    echo "==================="
    echo "Current: $current_context"
    echo "History size: $(wc -l < "$KCM_HISTORY_FILE" 2>/dev/null || echo 0)"
    echo "Favorites size: $(wc -l < "$KCM_FAVORITES_FILE" 2>/dev/null || echo 0)"
    echo ""
    echo "Recent contexts:"
    _kcm_history_get | head -5 | while read -r ctx; do
        if [[ "$ctx" == "$current_context" ]]; then
            echo "  → $ctx (current)"
        else
            echo "    $ctx"
        fi
    done
}

# User commands for history and favorites
khist() {
    local action="$1"
    shift
    
    _kcm_history_init
    
    case "$action" in
        list|show)
            _kcm_history_get
            ;;
        clear)
            _kcm_history_clear
            ;;
        *)
            echo "Usage: khist <action>"
            echo ""
            echo "Actions:"
            echo "  list|show  - Show context history"
            echo "  clear      - Clear context history"
            ;;
    esac
}

kfav-add() {
    _kcm_history_init
    local context="$1"
    local description="${2:-}"
    _kcm_favorites_add "$context" "$description"
}

kfav-remove() {
    _kcm_history_init
    local context="$1"
    _kcm_favorites_remove "$context"
}

kfav-list() {
    _kcm_history_init
    _kcm_favorites_list
}

kfav() {
    _kcm_history_init
    local favorite="$1"
    _kcm_favorites_switch "$favorite"
}

kstats() {
    _kcm_history_init
    _kcm_context_stats
}
