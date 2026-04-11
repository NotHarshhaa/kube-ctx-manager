#!/usr/bin/env bash

# kube-ctx-manager.bash
# Main entry point for Bash

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
export KCM_DIR="$(dirname "${BASH_SOURCE[0]}")"

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
source "$KCM_DIR/lib/history.sh"
source "$KCM_DIR/lib/quick.sh"
source "$KCM_DIR/lib/groups.sh"
source "$KCM_DIR/lib/templates.sh"

# Initialize suggester tracking
_kcm_suggester_init

# Initialize history system
_kcm_history_init

# Initialize groups system
_kcm_groups_init

# Initialize templates system
_kcm_templates_init

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
alias kube-suggest-apply="_kcm_apply_suggested_aliases"
