#!/usr/bin/env bash

# context.sh - Context and namespace switching logic

# Store previous context for quick switching
export KCM_PREV_CONTEXT=""

# Get current context
_kcm_get_current_context() {
    kubectl config current-context 2>/dev/null || echo "none"
}

# Get current context safe
_kcm_get_current_context_safe() {
    kubectl config current-context 2>/dev/null || echo "none"
}

# Get current namespace
_kcm_get_current_namespace() {
    kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default"
}

# List all available contexts
_kcm_list_contexts() {
    kubectl config get-contexts -o name | sed 's/^.*\///'
}

# List namespaces in current context
_kcm_list_namespaces() {
    kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null
}

# Switch context
_kcm_switch_context() {
    local context="$1"
    local prev_context="$(_kcm_get_current_context_safe)"
    
    # Validate input
    if ! _kcm_validate_context "$context" "true"; then
        return 1
    fi
    
    _kcm_debug_trace_in "$context"
    
    if [[ "$context" == "-" ]]; then
        if [[ -n "$KCM_PREV_CONTEXT" ]]; then
            context="$KCM_PREV_CONTEXT"
        else
            _kcm_error "No previous context to switch to"
            _kcm_debug_trace_out 1
            return 1
        fi
    fi
    
    # Perform context switch with timeout
    local result
    if result=$(_kcm_safe_execute "$KCM_TIMEOUT" "kubectl config use-context '$context'"); then
        export KCM_PREV_CONTEXT="$prev_context"
        _kcm_history_add "$context"
        _kcm_success "Switched to context: $context"
        _kcm_debug_log "INFO" "Context switched: $prev_context -> $context"
        _kcm_debug_trace_out 0
        return 0
    else
        _kcm_error "Failed to switch to context: $context"
        _kcm_debug_trace_out 1
        return 1
    fi
}

# Switch namespace
_kcm_switch_namespace() {
    local namespace="$1"
    local context="$(_kcm_get_current_context)"
    
    if kubectl config set-context "$context" --namespace="$namespace" >/dev/null 2>&1; then
        echo "Switched to namespace: $namespace"
        return 0
    else
        echo "Failed to switch to namespace: $namespace" >&2
        return 1
    fi
}

# Enhanced context preview for fzf
_kcm_context_preview() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        echo "No context selected"
        return
    fi
    
    # Get context details
    local context_json
    context_json=$(kubectl config view --minify --context="$context" --output=json 2>/dev/null)
    
    if [[ -z "$context_json" ]]; then
        echo "Unable to fetch context details"
        return
    fi
    
    # Extract information
    local cluster user namespace
    cluster=$(echo "$context_json" | jq -r '.contexts[0].context.cluster // "N/A"' 2>/dev/null)
    user=$(echo "$context_json" | jq -r '.contexts[0].context.user // "N/A"' 2>/dev/null)
    namespace=$(echo "$context_json" | jq -r '.contexts[0].context.namespace // "default"' 2>/dev/null)
    
    # Check if it's a prod context
    local is_prod="No"
    if echo "$context" | grep -qE "$KCM_PROD_PATTERN"; then
        is_prod="Yes ⚠️"
    fi
    
    # Check if it's a favorite
    local is_fav="No"
    if grep -q "^$context:" "$KCM_FAVORITES_FILE" 2>/dev/null; then
        is_fav="Yes ⭐"
    fi
    
    # Display preview
    echo -e "\033[1;36mContext: $context\033[0m"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Cluster:     $cluster"
    echo "User:        $user"
    echo "Namespace:   $namespace"
    echo "Production:  $is_prod"
    echo "Favorite:    $is_fav"
    
    # Try to get cluster health if possible
    if command -v kubectl >/dev/null 2>&1; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Cluster Status:"
        if timeout 3 kubectl cluster-info --context="$context" >/dev/null 2>&1; then
            echo -e "  \033[32m✓ Connected\033[0m"
        else
            echo -e "  \033[31m✗ Unreachable\033[0m"
        fi
    fi
}

# Enhanced namespace preview for fzf
_kcm_namespace_preview() {
    local namespace="$1"
    local current_context
    current_context=$(_kcm_get_current_context)
    
    if [[ -z "$namespace" ]]; then
        echo "No namespace selected"
        return
    fi
    
    echo -e "\033[1;36mNamespace: $namespace\033[0m"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get resource counts
    local pod_count svc_count deploy_count
    pod_count=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    svc_count=$(kubectl get svc -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    deploy_count=$(kubectl get deployments -n "$namespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    echo "Pods:        $pod_count"
    echo "Services:    $svc_count"
    echo "Deployments: $deploy_count"
    
    # Show labels if available
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Labels:"
    kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null | jq -r 'to_entries | .[] | "  \(.key): \(.value)"' 2>/dev/null || echo "  No labels"
}

# Fuzzy context selector
kx() {
    local context="$1"
    
    _kcm_debug_trace_in "$context"
    
    if [[ -n "$context" ]]; then
        _kcm_switch_context "$context"
        local exit_code=$?
        _kcm_debug_trace_out $exit_code
        return $exit_code
    fi
    
    if ! _kcm_command_exists fzf; then
        _kcm_error "fzf is required for fuzzy context selection"
        _kcm_debug_trace_out 1
        return 1
    fi
    
    local current_context
    current_context=$(_kcm_get_current_context_safe)
    local contexts
    contexts=$(_kcm_cached_kubectl "config get-contexts -o name")
    
    if [[ -z "$contexts" ]]; then
        _kcm_warning "No contexts found"
        _kcm_debug_trace_out 1
        return 1
    fi
    
    _kcm_info "Selecting context with fzf..."
    
    local selected_context
    selected_context=$(echo "$contexts" | fzf \
        --height="$KCM_FZF_HEIGHT" \
        --layout="$KCM_FZF_LAYOUT" \
        --border \
        --prompt="Select context> " \
        --header="Current: $current_context | Use ↑↓ to navigate, Enter to select" \
        --preview-window="right:50%" \
        --preview="_kcm_context_preview {}")
    
    if [[ -n "$selected_context" ]]; then
        _kcm_switch_context "$selected_context"
        local exit_code=$?
        _kcm_debug_trace_out $exit_code
        return $exit_code
    else
        _kcm_info "No context selected"
        _kcm_debug_trace_out 0
        return 0
    fi
}

# Fuzzy namespace selector
kns() {
    local namespace="$1"
    
    if [[ -n "$namespace" ]]; then
        _kcm_switch_namespace "$namespace"
        return $?
    fi
    
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for fuzzy namespace selection" >&2
        return 1
    fi
    
    local current_namespace="$(_kcm_get_current_namespace)"
    local current_context
    current_context=$(_kcm_get_current_context)
    local selected_namespace
    
    selected_namespace=$(_kcm_list_namespaces | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Select namespace> " \
        --header="Context: $current_context | Current: $current_namespace" \
        --preview-window="right:50%" \
        --preview="_kcm_namespace_preview {}")
    
    if [[ -n "$selected_namespace" ]]; then
        _kcm_switch_namespace "$selected_namespace"
    fi
}
