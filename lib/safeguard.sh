#!/usr/bin/env bash

# safeguard.sh - Production environment protection

# Destructive kubectl commands that require confirmation
_kcm_destructive_verbs="delete|drain|cordon|scale|rollout.*restart|rollout.*undo|rollout.*abort"

# Check if current context matches prod pattern
_kcm_is_prod_context() {
    local current_context="$(_kcm_get_current_context)"
    echo "$current_context" | grep -qE "$KCM_PROD_PATTERN"
}

# Check if command is destructive
_kcm_is_destructive_command() {
    local cmd="$1"
    echo "$cmd" | grep -qE "^kubectl[[:space:]]+($(_kcm_get_destructive_verbs))"
}

# Get destructive verbs (escaped for regex)
_kcm_get_destructive_verbs() {
    echo "$_kcm_destructive_verbs"
}

# Prompt for confirmation
_kcm_prompt_confirmation() {
    local context="$1"
    local cmd="$2"
    
    echo ""
    echo "⚠️  You are about to run a destructive command against context: $context"
    echo ""
    echo "  $cmd"
    echo ""
    echo -n "Type the context name to confirm: "
    
    read -r confirmation
    
    if [[ "$confirmation" != "$context" ]]; then
        echo "❌ Confirmation mismatch. Command blocked."
        return 1
    fi
    
    echo "✅ Confirmed. Executing command..."
    return 0
}

# Log audit entry
_kcm_audit_command() {
    local context="$1"
    local namespace="$2"
    local cmd="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] context=$context namespace=$namespace command=$cmd" >> "$KCM_AUDIT_LOG"
}

# Setup kubectl wrapper
_kcm_setup_safeguard() {
    # Check if kubectl exists
    if ! command -v kubectl >/dev/null 2>&1; then
        return
    fi
    
    # Create wrapper function
    _kcm_kubectl_wrapper() {
        local cmd="$*"
        local current_context="$(_kcm_get_current_context)"
        local current_namespace="$(_kcm_get_current_namespace)"
        
        # Check if this is a destructive command against prod
        if _kcm_is_prod_context && _kcm_is_destructive_command "$cmd"; then
            # Log the attempt
            _kcm_audit_command "$current_context" "$current_namespace" "$cmd"
            
            # Prompt for confirmation
            if _kcm_prompt_confirmation "$current_context" "$cmd"; then
                # Execute the real kubectl
                command kubectl "$@"
            else
                return 1
            fi
        else
            # Just execute normally
            command kubectl "$@"
        fi
    }
    
    # Override kubectl with our wrapper
    alias kubectl='_kcm_kubectl_wrapper'
}
