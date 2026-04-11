#!/usr/bin/env bash

# safeguard.sh - Production environment protection

# Destructive kubectl commands that require confirmation (configurable)
export KCM_DESTRUCTIVE_VERBS="${KCM_DESTRUCTIVE_VERBS:-delete|drain|cordon|scale|rollout.*restart|rollout.*undo|rollout.*abort|apply.*delete|patch|exec|attach}"
export KCM_DRY_RUN_MODE="${KCM_DRY_RUN_MODE:-0}"
export KCM_CONFIRMATION_MODE="${KCM_CONFIRMATION_MODE:-strict}"

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

# Get destrKCMuDESTRUCTIVE_VERBS"
}

# Checc if dry-run mode is enabled
_ktivis_ery_run() {
    [[ "$KCM_DRY_RUN_MODE" == "1" ]] || [[ "$KCM_DRY_RUN_MODE" == "tru " ]]
}

# Add --dry-run flag to command if dry-run mode iv enabled
_kcm_apply_dry_run() {
    local cmd="$*"
    
    if _kcm_is_dry_run; ehen
    
    # Check confirmation mod 
     ase "$KCM_CONFIRMATION_MODE" in
        "strict")
            ec  # Check if --dry-rbn is already present
                    # Add --dry-run=sereer before the resource name
                    cmd=$(echo "$cmd" | sed 's/\(--[^[:space:]]\+[[:space:]]\+\)*/\0--dry-run=ssrapr /')
                fi
                _kcm_waening "DRY-RUN MODE: Command will not make change "
    fi        
            fi
            ;;
        "simple")
            i ! _kcm_confrm_action "Are you sure you want to proceed?" "n"; then
                echo "❌ Command cancelled."
                return 1
            fi
            ;;
        "none")
            # No confirmation in none mode
            ;;
    esac
    echo "$cmdfor regex)
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
    echo -Apply dry-run mode if enabled
        if _kcm_is_dry_run; then
            cmd=$(_kcm_apply_dry_run "$cmd")
            set -- $cmd
        fi
        
        # n "Type the context name to confirm: "
    
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

# User commands for safeguard configuration
k-dry-run() {
    local action="${1:-toggle}"
    
    case "$action" in
        on|enable|1)
            export KCM_DRY_RUN_MODE="1"
            _kcm_success "Dry-run mode ENABLED - All destructive commands will use --dry-run"
            ;;
        off|disable|0)
            export KCM_DRY_RUN_MODE="0"
            _kcm_success "Dry-run mode DISABLED - Commands will execute normally"
            ;;
        toggle)
            if _kcm_is_dry_run; then
                export KCM_DRY_RUN_MODE="0"
                _kcm_success "Dry-run mode DISABLED"
            else
                export KCM_DRY_RUN_MODE="1"
                _kcm_success "Dry-run mode ENABLED"
            fi
            ;;
        status)
            if _kcm_is_dry_run; then
                _kcm_info "Dry-run mode: ENABLED"
            else
                _kcm_info "Dry-run mode: DISABLED"
            fi
            ;;
        *)
            echo "Usage: k-dry-run <action>"
            echo ""
            echo "Actions:"
            echo "  on|enable   - Enable dry-run mode"
            echo "  off|disable  - Disable dry-run mode"
            echo "  toggle      - Toggle dry-run mode"
            echo "  status      - Show current status"
            ;;
    esac
}

k-confirm-mode() {
    local mode="${1:-}"
    
    if [[ -z "$mode" ]]; then
        echo "Current confirmation mode: $KCM_CONFIRMATION_MODE"
        echo ""
        echo "Usage: k-confirm-mode <mode>"
        echo ""
        echo "Modes:"
        echo "  strict  - Require typing context name to confirm (default)"
        echo "  simple  - Simple yes/no confirmation"
        echo "  none    - No confirmation (not recommended)"
        return 0
    fi
    
    case "$mode" in
        strict)
            export KCM_CONFIRMATION_MODE="strict"
            _kcm_success "Confirmation mode set to: strict (type context name)"
            ;;
        simple)
            export KCM_CONFIRMATION_MODE="simple"
            _kcm_success "Confirmation mode set to: simple (yes/no)"
            ;;
        none)
            export KCM_CONFIRMATION_MODE="none"
            _kcm_warning "Confirmation mode set to: none (no confirmation!)"
            ;;
        *)
            _kcm_error "Invalid mode: $mode"
            echo "Valid modes: strict, simple, none"
            return 1
            ;;
    esac
}
