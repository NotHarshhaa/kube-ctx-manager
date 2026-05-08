#!/usr/bin/env bash

# diff.sh - Context comparison and diff utilities

# Compare two contexts
_kcm_diff_contexts() {
    local context1="$1"
    local context2="$2"
    
    if [[ -z "$context1" ]] || [[ -z "$context2" ]]; then
        _kcm_error "Two context names required"
        return 1
    fi
    
    # Check if contexts exist
    if ! kubectl config get-contexts "$context1" >/dev/null 2>&1; then
        _kcm_error "Context does not exist: $context1"
        return 1
    fi
    
    if ! kubectl config get-contexts "$context2" >/dev/null 2>&1; then
        _kcm_error "Context does not exist: $context2"
        return 1
    fi
    
    echo "Comparing contexts: $context1 vs $context2"
    echo "========================================"
    echo ""
    
    # Get context details
    local ctx1_cluster ctx1_user ctx1_namespace
    local ctx2_cluster ctx2_user ctx2_namespace
    
    ctx1_cluster=$(kubectl config get-contexts "$context1" -o jsonpath='{.context.cluster}')
    ctx1_user=$(kubectl config get-contexts "$context1" -o jsonpath='{.context.user}')
    ctx1_namespace=$(kubectl config get-contexts "$context1" -o jsonpath='{.context.namespace}')
    
    ctx2_cluster=$(kubectl config get-contexts "$context2" -o jsonpath='{.context.cluster}')
    ctx2_user=$(kubectl config get-contexts "$context2" -o jsonpath='{.context.user}')
    ctx2_namespace=$(kubectl config get-contexts "$context2" -o jsonpath='{.context.namespace}')
    
    # Display comparison
    echo "Cluster:"
    if [[ "$ctx1_cluster" == "$ctx2_cluster" ]]; then
        echo "  ✓ Same: $ctx1_cluster"
    else
        echo "  ✗ Different:"
        echo "    $context1: $ctx1_cluster"
        echo "    $context2: $ctx2_cluster"
    fi
    
    echo ""
    echo "User:"
    if [[ "$ctx1_user" == "$ctx2_user" ]]; then
        echo "  ✓ Same: $ctx1_user"
    else
        echo "  ✗ Different:"
        echo "    $context1: $ctx1_user"
        echo "    $context2: $ctx2_user"
    fi
    
    echo ""
    echo "Namespace:"
    if [[ "$ctx1_namespace" == "$ctx2_namespace" ]]; then
        echo "  ✓ Same: ${ctx1_namespace:-<default>}"
    else
        echo "  ✗ Different:"
        echo "    $context1: ${ctx1_namespace:-<default>}"
        echo "    $context2: ${ctx2_namespace:-<default>}"
    fi
    
    echo ""
    echo "Server:"
    local ctx1_server ctx2_server
    ctx1_server=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$ctx1_cluster\")].cluster.server}")
    ctx2_server=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$ctx2_cluster\")].cluster.server}")
    
    if [[ "$ctx1_server" == "$ctx2_server" ]]; then
        echo "  ✓ Same: $ctx1_server"
    else
        echo "  ✗ Different:"
        echo "    $context1: $ctx1_server"
        echo "    $context2: $ctx2_server"
    fi
}

# Show context details
_kcm_context_info() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        context=$(_kcm_get_current_context)
    fi
    
    if ! kubectl config get-contexts "$context" >/dev/null 2>&1; then
        _kcm_error "Context does not exist: $context"
        return 1
    fi
    
    echo "Context: $context"
    echo "================"
    echo ""
    
    local cluster user namespace
    cluster=$(kubectl config get-contexts "$context" -o jsonpath='{.context.cluster}')
    user=$(kubectl config get-contexts "$context" -o jsonpath='{.context.user}')
    namespace=$(kubectl config get-contexts "$context" -o jsonpath='{.context.namespace}')
    
    echo "Cluster: $cluster"
    echo "User: $user"
    echo "Namespace: ${namespace:-<default>}"
    echo ""
    
    # Get cluster server
    local server
    server=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$cluster\")].cluster.server}")
    echo "Server: $server"
    
    # Check if prod
    if echo "$context" | grep -qiE "$KCM_PROD_PATTERN"; then
        echo "Environment: ⚠️  PRODUCTION"
    else
        echo "Environment: Non-production"
    fi
    
    # Check if favorite
    if grep -q "^$context:" "$KCM_FAVORITES_FILE" 2>/dev/null; then
        echo "Favorite: ⭐ Yes"
    else
        echo "Favorite: No"
    fi
    
    echo ""
    
    # Test connectivity
    echo "Testing connectivity..."
    if kubectl cluster-info --request-timeout=5 >/dev/null 2>&1; then
        echo "  ✓ Cluster is reachable"
    else
        echo "  ✗ Cluster is not reachable"
    fi
}

# Compare current context with another
_kcm_diff_current() {
    local context="$1"
    
    if [[ -z "$context" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    local current
    current=$(_kcm_get_current_context)
    _kcm_diff_contexts "$current" "$context"
}

# User commands for context diff
kdiff() {
    local context1="$1"
    local context2="$2"
    
    if [[ -z "$context2" ]]; then
        if [[ -z "$context1" ]]; then
            _kcm_context_info
        else
            _kcm_diff_current "$context1"
        fi
    else
        _kcm_diff_contexts "$context1" "$context2"
    fi
}

kinfo() {
    local context="$1"
    _kcm_context_info "$context"
}
