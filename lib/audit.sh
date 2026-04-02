#!/usr/bin/env bash

# audit.sh - Audit logging functionality

# Initialize audit log
_kcm_init_audit_log() {
    # Create audit directory if it doesn't exist
    local audit_dir
    audit_dir=$(dirname "$KCM_AUDIT_LOG")
    mkdir -p "$audit_dir"
    
    # Create audit log if it doesn't exist
    touch "$KCM_AUDIT_LOG"
    
    # Add header if file is empty
    if [[ ! -s "$KCM_AUDIT_LOG" ]]; then
        echo "# kube-ctx-manager audit log" > "$KCM_AUDIT_LOG"
        echo "# Format: [timestamp] context=<context> namespace=<namespace> command=<command>" >> "$KCM_AUDIT_LOG"
        echo "" >> "$KCM_AUDIT_LOG"
    fi
}

# Enhanced audit function with more details
_kcm_audit_command_detailed() {
    local context="$1"
    local namespace="$2"
    local cmd="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Get additional context
    local user
    local host
    user=$(whoami)
    host=$(hostname)
    
    # Log with additional metadata
    echo "[$timestamp] user=$user host=$host context=$context namespace=$namespace command=$cmd" >> "$KCM_AUDIT_LOG"
}

# Show recent audit entries
kube-audit() {
    local lines="${1:-20}"
    
    if [[ ! -f "$KCM_AUDIT_LOG" ]]; then
        echo "Audit log not found: $KCM_AUDIT_LOG"
        return 1
    fi
    
    echo "Recent audit entries (last $lines lines):"
    echo ""
    tail -n "$lines" "$KCM_AUDIT_LOG" | grep -v '^#' | grep -v '^$'
}

# Search audit log
kube-audit-search() {
    local pattern="$1"
    
    if [[ -z "$pattern" ]]; then
        echo "Usage: kube-audit-search <pattern>"
        echo "Example: kube-audit-search 'delete'"
        echo "Example: kube-audit-search 'prod'"
        return 1
    fi
    
    if [[ ! -f "$KCM_AUDIT_LOG" ]]; then
        echo "Audit log not found: $KCM_AUDIT_LOG"
        return 1
    fi
    
    echo "Searching audit log for: $pattern"
    echo ""
    grep -i "$pattern" "$KCM_AUDIT_LOG" | grep -v '^#' | grep -v '^$'
}

# Get audit statistics
kube-audit-stats() {
    if [[ ! -f "$KCM_AUDIT_LOG" ]]; then
        echo "Audit log not found: $KCM_AUDIT_LOG"
        return 1
    fi
    
    echo "Audit Statistics:"
    echo ""
    
    # Total commands
    local total
    total=$(grep -c -v '^#' "$KCM_AUDIT_LOG" | grep -c -v '^$')
    echo "Total commands logged: $total"
    
    # Commands by context
    echo ""
    echo "Commands by context:"
    grep -o 'context=[^[:space:]]*' "$KCM_AUDIT_LOG" | sort | uniq -c | sort -nr
    
    # Commands by type
    echo ""
    echo "Commands by type:"
    grep -o 'command=kubectl[[:space:]]*[^[:space:]]*' "$KCM_AUDIT_LOG" | sort | uniq -c | sort -nr
    
    # Recent activity
    echo ""
    echo "Recent activity (last 24 hours):"
    local yesterday
    yesterday=$(date -d '1 day ago' '+%Y-%m-%d' 2>/dev/null || date -v-1d '+%Y-%m-%d' 2>/dev/null)
    grep "^\\[$yesterday" "$KCM_AUDIT_LOG" | wc -l | xargs echo "Commands:"
}

# Initialize audit log on load
_kcm_init_audit_log
