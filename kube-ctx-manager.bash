#!/usr/bin/env bash

# kube-ctx-manager.bash
# Main entry point for Bash

# Ensure we're not already loaded
[[ -n "$KCM_LOADED" ]] && return
export KCM_LOADED=1

# Default configuration
export KCM_PROD_PATTERN="${KCM_PROD_PATTERN:-prod|production|live|prd}"
export KCM_SUGGEST_THRESHOLD="${KCM_SUGGEST_THRESHOLD:-3}"
export KCM_AUDIT_LOG="${KCM_AUDIT_LOG:-$HOME/.kube/audit.log}"
export KCM_PROMPT="${KCM_PROMPT:-1}"
export KCM_PROMPT_STYLE="${KCM_PROMPT_STYLE:-full}"
export KCM_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source library modules
source "$KCM_DIR/lib/context.sh"
source "$KCM_DIR/lib/safeguard.sh"
source "$KCM_DIR/lib/suggester.sh"
source "$KCM_DIR/lib/prompt.sh"
source "$KCM_DIR/lib/audit.sh"

# Initialize suggester tracking
_kcm_suggester_init

# Setup prompt if enabled
if [[ "$KCM_PROMPT" == "1" ]]; then
    _kcm_setup_prompt
fi

# Setup kubectl wrapper for safeguarding
_kcm_setup_safeguard

# Bash completion
if command -v kubectl >/dev/null 2>&1 && command -v complete >/dev/null 2>&1; then
    complete -o default -F _kubectl kx
    complete -o default -F _kubectl kns
fi

# Aliases
alias kube-suggest="_kcm_suggest_aliases"
alias kube-suggest-apply="_kcm_apply_suggested_aliases"
