#!/usr/bin/env bash

# context.sh - Context and namespace switching logic

# Store previous context for quick switching
export KCM_PREV_CONTEXT=""

# Get current context
_kcm_get_current_context() {
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
    local prev_context="$(_kcm_get_current_context)"
    
    if [[ "$context" == "-" ]]; then
        if [[ -n "$KCM_PREV_CONTEXT" ]]; then
            context="$KCM_PREV_CONTEXT"
        else
            echo "No previous context to switch to" >&2
            return 1
        fi
    fi
    
    if kubectl config use-context "$context" >/dev/null 2>&1; then
        export KCM_PREV_CONTEXT="$prev_context"
        echo "Switched to context: $context"
        return 0
    else
        echo "Failed to switch to context: $context" >&2
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

# Fuzzy context selector
kx() {
    local context="$1"
    
    if [[ -n "$context" ]]; then
        _kcm_switch_context "$context"
        return $?
    fi
    
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for fuzzy context selection" >&2
        return 1
    fi
    
    local current_context="$(_kcm_get_current_context)"
    local selected_context
    
    selected_context=$(_kcm_list_contexts | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Select context> " \
        --header="Current: $current_context" \
        --preview="kubectl config view --minify --context={} --output=json | jq -r '.contexts[0].context | \"Cluster: \\(.cluster)\\nUser: \\(.user)\"' 2>/dev/null || echo 'No details available'")
    
    if [[ -n "$selected_context" ]]; then
        _kcm_switch_context "$selected_context"
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
    local selected_namespace
    
    selected_namespace=$(_kcm_list_namespaces | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Select namespace> " \
        --header="Current: $current_namespace")
    
    if [[ -n "$selected_namespace" ]]; then
        _kcm_switch_namespace "$selected_namespace"
    fi
}
