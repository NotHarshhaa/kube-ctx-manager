#!/usr/bin/env bash

# prompt.sh - Shell prompt customization

# Setup prompt modification
_kcm_setup_prompt() {
    if [[ -n "$BASH_VERSION" ]]; then
        _kcm_setup_bash_prompt
    elif [[ -n "$ZSH_VERSION" ]]; then
        _kcm_setup_zsh_prompt
    fi
}

# Setup Bash prompt
_kcm_setup_bash_prompt() {
    # Save original PS1 if not already saved
    if [[ -z "$KCM_ORIGINAL_PS1" ]]; then
        export KCM_ORIGINAL_PS1="$PS1"
    fi
    
    # Create prompt function
    _kcm_build_prompt() {
        local context_info
        context_info=$(_kcm_get_prompt_info)
        
        if [[ -n "$context_info" ]]; then
            PS1="$KCM_ORIGINAL_PS1 $context_info"
        else
            PS1="$KCM_ORIGINAL_PS1"
        fi
    }
    
    # Set up prompt command
    PROMPT_COMMAND="_kcm_build_prompt; $PROMPT_COMMAND"
}

# Setup Zsh prompt
_kcm_setup_zsh_prompt() {
    # Save original prompts if not already saved
    if [[ -z "$KCM_ORIGINAL_PROMPT" ]]; then
        export KCM_ORIGINAL_PROMPT="$PROMPT"
    fi
    if [[ -z "$KCM_ORIGINAL_RPROMPT" ]]; then
        export KCM_ORIGINAL_RPROMPT="$RPROMPT"
    fi
    
    # Create prompt function
    _kcm_build_zsh_prompt() {
        local context_info
        context_info=$(_kcm_get_prompt_info)
        
        if [[ -n "$context_info" ]]; then
            RPROMPT="$KCM_ORIGINAL_RPROMPT $context_info"
        else
            RPROMPT="$KCM_ORIGINAL_RPROMPT"
        fi
    }
    
    # Add to precmd functions
    autoload -U add-zsh-hook
    add-zsh-hook precmd _kcm_build_zsh_prompt
}

# Get prompt information based on style
_kcm_get_prompt_info() {
    local current_context="$(_kcm_get_current_context)"
    local current_namespace="$(_kcm_get_current_namespace)"
    
    # Don't show if no context or kubectl not available
    if [[ "$current_context" == "none" ]] || ! command -v kubectl >/dev/null 2>&1; then
        return
    fi
    
    local context_info
    case "$KCM_PROMPT_STYLE" in
        "minimal")
            context_info="$current_context"
            ;;
        "full"|*)
            if [[ "$current_namespace" != "default" ]]; then
                context_info="$current_context:$current_namespace"
            else
                context_info="$current_context"
            fi
            ;;
    esac
    
    # Color coding for prod environments
    if _kcm_is_prod_context; then
        context_info="\[\033[91m\]$context_info\[\033[0m\]"  # Red for prod
    else
        context_info="\[\033[36m\]$context_info\[\033[0m\]"  # Cyan for non-prod
    fi
    
    # Add brackets
    echo "[$context_info]"
}
