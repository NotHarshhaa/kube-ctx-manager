#!/usr/bin/env zsh

# kube-ctx-manager.plugin.zsh
# Main entry point for Zsh

# Security: Set restrictive umask for secure file creation
umask 077

# Ensure we're not already loaded
[[ -n "$KCM_LOADED" ]] && return
export KCM_LOADED=1

# Default configuration
export KCM_PROD_PATTERN="${KCM_PROD_PATTERN:-prod|production|live|prd}"
export KCM_SUGGEST_THRESHOLD="${KCM_SUGGEST_THRESHOLD:-3}"
export KCM_AUDIT_LOG="${KCM_AUDIT_LOG:-$HOME/.kube/audit.log}"
export KCM_PROMPT="${KCM_PROMPT:-1}"
export KCM_PROMPT_STYLE="${KCM_PROMPT_STYLE:-full}"
export KCM_DIR="${0:A:h}"

# Source library modules
source "$KCM_DIR/lib/common.sh"
source "$KCM_DIR/lib/config.sh"
source "$KCM_DIR/lib/cache.sh"
source "$KCM_DIR/lib/utils.sh"
source "$KCM_DIR/lib/validation.sh"
source "$KCM_DIR/lib/ui.sh"
source "$KCM_DIR/lib/debug.sh"
source "$KCM_DIR/lib/context.sh"
source "$KCM_DIR/lib/safeguard.sh"
source "$KCM_DIR/lib/suggester.sh"
source "$KCM_DIR/lib/prompt.sh"
source "$KCM_DIR/lib/audit.sh"
source "$KCM_DIR/lib/health.sh"
source "$KCM_DIR/lib/merge.sh"
source "$KCM_DIR/lib/backup.sh"
source "$KCM_DIR/lib/search.sh"
source "$KCM_DIR/lib/bookmarks.sh"
source "$KCM_DIR/lib/monitor.sh"
source "$KCM_DIR/lib/analytics.sh"

# Initialize suggester tracking
_kcm_suggester_init

# Setup prompt if enabled
if [[ "$KCM_PROMPT" == "1" ]]; then
    _kcm_setup_prompt
fi

# Setup kubectl wrapper for safeguarding
_kcm_setup_safeguard

# Zsh-specific completions
if command -v kubectl >/dev/null 2>&1; then
    compdef _kubectl kx
    compdef _kubectl kns
fi

# Aliases
alias kube-suggest="_kcm_suggest_aliases"
alias kube-suggest-apply="_kcm_apply_suggested_aliases"
