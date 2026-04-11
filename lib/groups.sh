#!/usr/bin/env bash

# groups.sh - Context groups for better organization

# Context groups file
export KCM_GROUPS_FILE="$HOME/.kube-context-groups"

# Initialize groups system
_kcm_groups_init() {
    if [[ ! -f "$KCM_GROUPS_FILE" ]]; then
        touch "$KCM_GROUPS_FILE"
        chmod 600 "$KCM_GROUPS_FILE"
    fi
}

# Add context to a group
_kcm_group_add() {
    local group="$1"
    local context="$2"
    
    if [[ -z "$group" ]] || [[ -z "$context" ]]; then
        _kcm_error "Group name and context name required"
        return 1
    fi
    
    # Check if context exists
    if ! kubectl config get-contexts "$context" >/dev/null 2>&1; then
        _kcm_error "Context does not exist: $context"
        return 1
    fi
    
    # Check if already in group
    if grep -q "^$group:$context$" "$KCM_GROUPS_FILE" 2>/dev/null; then
        _kcm_warning "Context already in group: $group"
        return 0
    fi
    
    echo "$group:$context" >> "$KCM_GROUPS_FILE"
    _kcm_success "Added '$context' to group '$group'"
}

# Remove context from a group
_kcm_group_remove() {
    local group="$1"
    local context="$2"
    
    if [[ -z "$group" ]] || [[ -z "$context" ]]; then
        _kcm_error "Group name and context name required"
        return 1
    fi
    
    if grep -q "^$group:$context$" "$KCM_GROUPS_FILE" 2>/dev/null; then
        grep -v "^$group:$context$" "$KCM_GROUPS_FILE" > "${KCM_GROUPS_FILE}.tmp"
        mv "${KCM_GROUPS_FILE}.tmp" "$KCM_GROUPS_FILE"
        _kcm_success "Removed '$context' from group '$group'"
    else
        _kcm_warning "Context not in group: $group"
    fi
}

# List all contexts in a group
_kcm_group_list() {
    local group="$1"
    
    if [[ -z "$group" ]]; then
        _kcm_error "Group name required"
        return 1
    fi
    
    local contexts
    contexts=$(grep "^$group:" "$KCM_GROUPS_FILE" 2>/dev/null | cut -d: -f2)
    
    if [[ -z "$contexts" ]]; then
        _kcm_info "No contexts in group: $group"
        return 0
    fi
    
    echo "Group: $group"
    echo "============"
    echo "$contexts"
}

# List all groups
_kcm_groups_list_all() {
    if [[ ! -f "$KCM_GROUPS_FILE" ]] || [[ ! -s "$KCM_GROUPS_FILE" ]]; then
        echo "No groups defined. Create one with: kgroup-add <group> <context>"
        return 0
    fi
    
    echo "Context Groups:"
    echo "==============="
    cut -d: -f1 "$KCM_GROUPS_FILE" | sort -u | while read -r group; do
        local count
        count=$(grep "^$group:" "$KCM_GROUPS_FILE" | wc -l | tr -d ' ')
        echo "  📁 $group ($count contexts)"
    done
}

# Switch to a context from a group
_kcm_group_switch() {
    local group="$1"
    local context="$2"
    
    if [[ -z "$group" ]]; then
        _kcm_error "Group name required"
        return 1
    fi
    
    local contexts
    contexts=$(grep "^$group:" "$KCM_GROUPS_FILE" 2>/dev/null | cut -d: -f2)
    
    if [[ -z "$contexts" ]]; then
        _kcm_error "No contexts in group: $group"
        return 1
    fi
    
    if [[ -n "$context" ]]; then
        # Switch directly to specified context
        if echo "$contexts" | grep -q "^$context$"; then
            _kcm_switch_context "$context"
        else
            _kcm_error "Context not in group: $context"
            return 1
        fi
    else
        # Interactive selection
        if ! command -v fzf >/dev/null 2>&1; then
            _kcm_group_list "$group"
            return 0
        fi
        
        local selected
        selected=$(echo "$contexts" | fzf \
            --height=40% \
            --layout=reverse \
            --border \
            --prompt="Select context> " \
            --header="Group: $group")
        
        if [[ -n "$selected" ]]; then
            _kcm_switch_context "$selected"
        fi
    fi
}

# Delete a group
_kcm_group_delete() {
    local group="$1"
    
    if [[ -z "$group" ]]; then
        _kcm_error "Group name required"
        return 1
    fi
    
    if grep -q "^$group:" "$KCM_GROUPS_FILE" 2>/dev/null; then
        if _kcm_confirm_action "Delete group '$group' and all its associations?" "n"; then
            grep -v "^$group:" "$KCM_GROUPS_FILE" > "${KCM_GROUPS_FILE}.tmp"
            mv "${KCM_GROUPS_FILE}.tmp" "$KCM_GROUPS_FILE"
            _kcm_success "Deleted group: $group"
        fi
    else
        _kcm_warning "Group not found: $group"
    fi
}

# Auto-group contexts by pattern
_kcm_group_auto() {
    local pattern="$1"
    local group_name="${2:-}"
    
    if [[ -z "$pattern" ]]; then
        _kcm_error "Pattern required"
        return 1
    fi
    
    if [[ -z "$group_name" ]]; then
        group_name="$pattern"
    fi
    
    local contexts
    contexts=$(kubectl config get-contexts -o name 2>/dev/null | grep "$pattern")
    
    if [[ -z "$contexts" ]]; then
        _kcm_info "No contexts matching pattern: $pattern"
        return 0
    fi
    
    echo "Found contexts matching '$pattern':"
    echo "$contexts"
    echo ""
    
    if _kcm_confirm_action "Add these to group '$group_name'?" "n"; then
        while IFS= read -r context; do
            _kcm_group_add "$group_name" "$context"
        done <<< "$contexts"
    fi
}

# User commands for groups
kgroup-add() {
    _kcm_groups_init
    local group="$1"
    local context="$2"
    _kcm_group_add "$group" "$context"
}

kgroup-remove() {
    _kcm_groups_init
    local group="$1"
    local context="$2"
    _kcm_group_remove "$group" "$context"
}

kgroup-list() {
    _kcm_groups_init
    local group="$1"
    
    if [[ -n "$group" ]]; then
        _kcm_group_list "$group"
    else
        _kcm_groups_list_all
    fi
}

kgroup() {
    _kcm_groups_init
    local group="$1"
    local context="$2"
    _kcm_group_switch "$group" "$context"
}

kgroup-delete() {
    _kcm_groups_init
    local group="$1"
    _kcm_group_delete "$group"
}

kgroup-auto() {
    _kcm_groups_init
    local pattern="$1"
    local group_name="${2:-}"
    _kcm_group_auto "$pattern" "$group_name"
}
