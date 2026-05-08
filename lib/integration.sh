#!/usr/bin/env bash

# integration.sh - Integration helpers for external tools (K9s, Helm, etc.)

# K9s integration
_kcm_k9s_switch() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    if ! command -v k9s >/dev/null 2>&1; then
        _kcm_error "k9s is not installed"
        return 1
    fi
    
    # Switch context first
    _kcm_switch_context "$context"
    
    # Launch k9s with the context
    _kcm_info "Launching k9s with context: $context"
    k9s --context "$context"
}

# K9s with namespace
_kcm_k9s_namespace() {
    local context="${1:-$(_kcm_get_current_context)}"
    local namespace="${2:-}"
    
    if ! command -v k9s >/dev/null 2>&1; then
        _kcm_error "k9s is not installed"
        return 1
    fi
    
    if [[ -n "$namespace" ]]; then
        k9s --context "$context" -n "$namespace"
    else
        k9s --context "$context"
    fi
}

# Helm integration
_kcm_helm_context() {
    local context="$1"
    shift
    local helm_args=("$@")
    
    if [[ -z "$context" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    if ! command -v helm >/dev/null 2>&1; then
        _kcm_error "helm is not installed"
        return 1
    fi
    
    # Switch context
    _kcm_switch_context "$context"
    
    # Run helm command
    if [[ ${#helm_args[@]} -gt 0 ]]; then
        helm "${helm_args[@]}"
    else
        _kcm_info "Context switched to $context. You can now run helm commands."
    fi
}

# Helm list releases in context
_kcm_helm_list() {
    local context="${1:-$(_kcm_get_current_context)}"
    local namespace="${2:-}"
    
    if ! command -v helm >/dev/null 2>&1; then
        _kcm_error "helm is not installed"
        return 1
    fi
    
    if [[ -n "$namespace" ]]; then
        helm list --context "$context" -n "$namespace"
    else
        helm list --context "$context" -A
    fi
}

# Stern integration (log tailing for multiple pods)
_kcm_stern_context() {
    local context="$1"
    shift
    local stern_args=("$@")
    
    if [[ -z "$context" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    if ! command -v stern >/dev/null 2>&1; then
        _kcm_error "stern is not installed"
        return 1
    fi
    
    # Switch context
    _kcm_switch_context "$context"
    
    # Run stern command
    if [[ ${#stern_args[@]} -gt 0 ]]; then
        stern "${stern_args[@]}"
    else
        _kcm_error "Pod pattern required for stern"
        return 1
    fi
}

# kubectx/kubens integration compatibility
_kcm_kubectx_compat() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        # List contexts (like kubectx)
        kubectl config get-contexts
    else
        # Switch context (like kubectx)
        _kcm_switch_context "$context"
    fi
}

_kcm_kubens_compat() {
    local namespace="$1"
    
    if [[ -z "$namespace" ]]; then
        # List namespaces (like kubens)
        kubectl get namespaces
    else
        # Switch namespace (like kubens)
        _kcm_set_namespace "$namespace"
    fi
}

# VS Code terminal integration
_kcm_vscode_set_title() {
    local context="${1:-$(_kcm_get_current_context)}"
    local namespace="${2:-$(_kcm_get_current_namespace)}"
    
    # Try to set VS Code terminal title
    if [[ -n "$VSCODE_PID" ]] || [[ -n "$TERM_PROGRAM" ]] && [[ "$TERM_PROGRAM" == "vscode" ]]; then
        local title="kube: $context"
        if [[ -n "$namespace" ]]; then
            title+=" ($namespace)"
        fi
        printf '\033]0;%s\007' "$title"
    fi
}

# User commands for integrations
kk9s() {
    local context="$1"
    local namespace="${2:-}"
    
    if [[ -z "$context" ]]; then
        # Launch k9s with current context
        local current
        current=$(_kcm_get_current_context)
        _kcm_k9s_namespace "$current" "$namespace"
    else
        _kcm_k9s_namespace "$context" "$namespace"
    fi
}

khelm() {
    local context="$1"
    shift
    _kcm_helm_context "$context" "$@"
}

khelm-list() {
    local context="${1:-}"
    local namespace="${2:-}"
    
    if [[ -n "$context" ]]; then
        _kcm_helm_list "$context" "$namespace"
    else
        _kcm_helm_list "$(_kcm_get_current_context)" "$namespace"
    fi
}

kstern() {
    local context="$1"
    shift
    _kcm_stern_context "$context" "$@"
}

ktitle() {
    local context="${1:-}"
    local namespace="${2:-}"
    _kcm_vscode_set_title "$context" "$namespace"
}
