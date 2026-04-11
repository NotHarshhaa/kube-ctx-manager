#!/usr/bin/env bash

# suggester.sh - Command usage tracking and alias suggestions

# Tracking file for command usage
export KCM_USAGE_FILE="$HOME/.kube-usage"
export KCM_ALIASES_FILE="$HOME/.kube-aliases"

# Initialize suggester
_kcm_suggester_init() {
    # Check if usage tracking is enabled
    if [[ "${KCM_ENABLE_USAGE_TRACKING:-1}" != "1" ]]; then
        return 0
    fi
    
    # Create usage file if it doesn't exist with secure permissions
    touch "$KCM_USAGE_FILE"
    chmod 600 "$KCM_USAGE_FILE"
    
    # Hook into command execution if supported
    if [[ -n "$BASH_VERSION" ]]; then
        _kcm_setup_bash_hook
    elif [[ -n "$ZSH_VERSION" ]]; then
        _kcm_setup_zsh_hook
    fi
}

# Setup Bash hook for command tracking
_kcm_setup_bash_hook() {
    # Check if usage tracking is enabled
    if [[ "${KCM_ENABLE_USAGE_TRACKING:-1}" != "1" ]]; then
        return 0
    fi
    
    # Use DEBUG trap to track commands
    _kcm_track_command() {
        local cmd="$1"
        # Only track kubectl commands
        if [[ "$cmd" =~ ^kubectl[[:space:]] ]]; then
            # Redact sensitive data before tracking
            local redacted_cmd
            redacted_cmd=$(_kcm_redact_sensitive_data "$cmd")
            echo "$(date '+%s'):$redacted_cmd" >> "$KCM_USAGE_FILE"
        fi
    }
    
    # Set up the trap
    trap '_kcm_track_command "$BASH_COMMAND"' DEBUG
}

# Setup Zsh hook for command tracking
_kcm_setup_zsh_hook() {
    # Check if usage tracking is enabled
    if [[ "${KCM_ENABLE_USAGE_TRACKING:-1}" != "1" ]]; then
        return 0
    fi
    
    # Use preexec hook in Zsh
    _kcm_track_command() {
        local cmd="$1"
        # Only track kubectl commands
        if [[ "$cmd" =~ ^kubectl[[:space:]] ]]; then
            # Redact sensitive data before tracking
            local redacted_cmd
            redacted_cmd=$(_kcm_redact_sensitive_data "$cmd")
            echo "$(date '+%s'):$redacted_cmd" >> "$KCM_USAGE_FILE"
        fi
    }
    
    # Set up the hook
    autoload -U add-zsh-hook
    add-zsh-hook preexec _kcm_track_command
}

# Analyze usage patterns and suggest aliases
_kcm_suggest_aliases() {
    local apply="$1"
    local temp_usage_file
    temp_usage_file=$(mktemp)
    
    # Sort and count commands (ignore timestamps)
    cut -d: -f2- "$KCM_USAGE_FILE" | sort | uniq -c | sort -nr > "$temp_usage_file"
    
    echo "Analyzing your kubectl usage patterns..."
    echo ""
    
    local suggestions=0
    while read -r count cmd; do
        # Skip commands below threshold
        if [[ $count -lt $KCM_SUGGEST_THRESHOLD ]]; then
            continue
        fi
        
        # Skip simple commands that don't need aliases
        if [[ "$cmd" =~ ^kubectl[[:space:]]+(get|describe|logs|apply|delete)[[:space:]]+[a-zA-Z]+[[:space:]]*$ ]]; then
            continue
        fi
        
        # Generate alias suggestion
        local alias_name
        alias_name=$(_kcm_generate_alias_name "$cmd")
        
        # Check if alias already exists
        if alias | grep -q "^alias $alias_name="; then
            continue
        fi
        
        echo "You've run this $count times:"
        echo "  $cmd"
        echo ""
        echo "Suggested alias:"
        echo "  alias $alias_name='$cmd'"
        echo ""
        
        if [[ "$apply" == "--apply" ]]; then
            echo "alias $alias_name='$cmd'" >> "$KCM_ALIASES_FILE"
        fi
        
        ((suggestions++))
        
        # Limit suggestions to avoid overwhelming output
        if [[ $suggestions -ge 5 ]]; then
            break
        fi
    done < "$temp_usage_file"
    
    rm -f "$temp_usage_file"
    
    if [[ $suggestions -eq 0 ]]; then
        echo "No alias suggestions found. You need to run commands at least $KCM_SUGGEST_THRESHOLD times."
        return 0
    fi
    
    if [[ "$apply" == "--apply" ]]; then
        echo ""
        echo "Aliases applied to $KCM_ALIASES_FILE"
        echo "Run 'source $KCM_ALIASES_FILE' to load them, or restart your shell."
    else
        echo "Run 'kube-suggest --apply' to add these aliases."
    fi
}

# Generate a meaningful alias name
_kcm_generate_alias_name() {
    local cmd="$1"
    local alias_name="k"
    
    # Extract key parts of the command
    local parts
    parts=($cmd)
    
    # Skip 'kubectl' and build alias from remaining parts
    for ((i=1; i<${#parts[@]}; i++)); do
        local part="${parts[$i]}"
        
        # Handle common patterns
        case "$part" in
            get)
                alias_name="${alias_name}g"
                ;;
            describe)
                alias_name="${alias_name}d"
                ;;
            logs)
                alias_name="${alias_name}l"
                ;;
            apply)
                alias_name="${alias_name}a"
                ;;
            delete)
                alias_name="${alias_name}d"
                ;;
            -n|--namespace)
                # Next part is namespace name
                if [[ $((i+1)) -lt ${#parts[@]} ]]; then
                    local ns="${parts[$((i+1))]}"
                    alias_name="${alias_name}n${ns:0:3}"
                    ((i++)) # Skip the namespace name
                fi
                ;;
            -f|--filename)
                alias_name="${alias_name}f"
                ;;
            -o|--output)
                alias_name="${alias_name}o"
                ;;
            -w|--watch)
                alias_name="${alias_name}w"
                ;;
            -l|--selector)
                alias_name="${alias_name}l"
                ;;
            --sort-by)
                alias_name="${alias_name}s"
                ;;
            -*)
                # Skip other flags
                ;;
            *)
                # For resource types and names, take first 2-3 characters
                if [[ ${#part} -gt 2 ]]; then
                    alias_name="${alias_name}${part:0:3}"
                else
                    alias_name="${alias_name}${part}"
                fi
                ;;
        esac
    done
    
    echo "$alias_name"
}

# Apply suggested aliases
_kcm_apply_suggested_aliases() {
    _kcm_suggest_aliases --apply
    
    # Source the aliases file
    if [[ -f "$KCM_ALIASES_FILE" ]]; then
        source "$KCM_ALIASES_FILE"
    fi
}
