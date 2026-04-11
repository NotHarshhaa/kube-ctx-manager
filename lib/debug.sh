#!/usr/bin/env bash

# debug.sh - Comprehensive debugging and troubleshooting tools (fixed version)

# Debug configuration
export KCM_DEBUG_ENABLED="${KCM_DEBUG_ENABLED:-false}"
export KCM_DEBUG_LOG="$HOME/.kube-debug.log"
export KCM_DEBUG_LEVEL="${KCM_DEBUG_LEVEL:-INFO}"
export KCM_DEBUG_TRACE="${KCM_DEBUG_TRACE:-false}"

# Debug levels
declare -A KCM_DEBUG_LEVELS=(
    ["TRACE"]=0
    ["DEBUG"]=1
    ["INFO"]=2
    ["WARN"]=3
    ["ERROR"]=4
    ["FATAL"]=5
)

# Initialize debug system
_kcm_init_debug() {
    # Create debug log directory with secure permissions
    mkdir -p "$(dirname "$KCM_DEBUG_LOG")"
    chmod 700 "$(dirname "$KCM_DEBUG_LOG")"
    
    # Set debug level from environment
    if [[ -n "${KCM_DEBUG+x}" ]]; then
        if [[ "$KCM_DEBUG" == "1" || "$KCM_DEBUG" == "true" ]]; then
            KCM_DEBUG_ENABLED="true"
            KCM_DEBUG_LEVEL="DEBUG"
        fi
    fi
    
    # Initialize debug log with secure permissions
    echo "# kube-ctx-manager debug log" > "$KCM_DEBUG_LOG"
    echo "# Started: $(date)" >> "$KCM_DEBUG_LOG"
    echo "# Debug level: $KCM_DEBUG_LEVEL" >> "$KCM_DEBUG_LOG"
    echo "# Trace enabled: $KCM_DEBUG_TRACE" >> "$KCM_DEBUG_LOG"
    echo "" >> "$KCM_DEBUG_LOG"
    chmod 600 "$KCM_DEBUG_LOG"
}

# Enhanced debug logging
_kcm_debug_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local script_name
    script_name=$(basename "${BASH_SOURCE[1]}" .sh)
    local line_number="${BASH_LINENO[0]}"
    local function_name="${FUNCNAME[1]}"
    
    # Check if we should log this level
    local current_level_num
    current_level_num=${KCM_DEBUG_LEVELS[$KCM_DEBUG_LEVEL]}
    local message_level_num
    message_level_num=${KCM_DEBUG_LEVELS[$level]}
    
    if [[ $message_level_num -lt $current_level_num ]]; then
        return 0
    fi
    
    # Redact sensitive data from debug messages
    local redacted_message
    redacted_message=$(_kcm_redact_sensitive_data "$message")
    
    # Format log entry
    local log_entry="[$timestamp] [$level] [$script_name:$line_number:$function_name] $redacted_message"
    
    # Write to debug log
    echo "$log_entry" >> "$KCM_DEBUG_LOG"
    
    # Output to console if debug is enabled
    if [[ "$KCM_DEBUG_ENABLED" == "true" ]]; then
        local color=""
        case "$level" in
            "TRACE") color="${KCM_COLORS[GRAY]}" ;;
            "DEBUG") color="${KCM_COLORS[CYAN]}" ;;
            "INFO") color="${KCM_COLORS[BLUE]}" ;;
            "WARN") color="${KCM_COLORS[YELLOW]}" ;;
            "ERROR") color="${KCM_COLORS[RED]}" ;;
            "FATAL") color="${KCM_COLORS[BOLD]}${KCM_COLORS[RED]}" ;;
        esac
        
        if [[ -n "$color" ]]; then
            echo -e "${color}[DEBUG] $log_entry${KCM_COLORS[NC]}" >&2
        else
            echo "[DEBUG] $log_entry" >&2
        fi
    fi
}

# Debug trace function entry
_kcm_debug_trace_in() {
    if [[ "$KCM_DEBUG_TRACE" == "true" ]]; then
        local func_name="${FUNCNAME[1]}"
        local args="$*"
        # Redact sensitive data from function arguments
        local redacted_args
        redacted_args=$(_kcm_redact_sensitive_data "$args")
        _kcm_debug_log "TRACE" "ENTER: $func_name($redacted_args)"
    fi
}

# Debug trace function exit
_kcm_debug_trace_out() {
    if [[ "$KCM_DEBUG_TRACE" == "true" ]]; then
        local func_name="${FUNCNAME[1]}"
        local exit_code="$1"
        _kcm_debug_log "TRACE" "EXIT: $func_name (code: $exit_code)"
    fi
}

# Debug variable dump
_kcm_debug_dump_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    
    _kcm_debug_log "DEBUG" "VAR: $var_name = $var_value"
}

# Debug command
kdebug() {
    local action="$1"
    shift
    
    case "$action" in
        "enable")
            export KCM_DEBUG_ENABLED="true"
            export KCM_DEBUG_LEVEL="DEBUG"
            echo "Debug enabled"
            ;;
        "disable")
            export KCM_DEBUG_ENABLED="false"
            echo "Debug disabled"
            ;;
        "level")
            local level="$1"
            if [[ -n "${KCM_DEBUG_LEVELS[$level]:-}" ]]; then
                export KCM_DEBUG_LEVEL="$level"
                echo "Debug level set to: $level"
            else
                echo "Invalid debug level: $level"
                echo "Valid levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL"
                return 1
            fi
            ;;
        "trace")
            if [[ "$KCM_DEBUG_TRACE" == "true" ]]; then
                export KCM_DEBUG_TRACE="false"
                echo "Function tracing disabled"
            else
                export KCM_DEBUG_TRACE="true"
                echo "Function tracing enabled"
            fi
            ;;
        "log")
            local lines="${1:-50}"
            if [[ -f "$KCM_DEBUG_LOG" ]]; then
                echo "Last $lines lines of debug log:"
                tail -n "$lines" "$KCM_DEBUG_LOG"
            else
                echo "Debug log not found: $KCM_DEBUG_LOG"
            fi
            ;;
        "clear")
            echo "# kube-ctx-manager debug log" > "$KCM_DEBUG_LOG"
            echo "# Cleared: $(date)" >> "$KCM_DEBUG_LOG"
            echo "Debug log cleared"
            ;;
        "status")
            echo "Debug Status:"
            echo "============"
            echo "Enabled: $KCM_DEBUG_ENABLED"
            echo "Level: $KCM_DEBUG_LEVEL"
            echo "Trace: $KCM_DEBUG_TRACE"
            echo "Log file: $KCM_DEBUG_LOG"
            ;;
        *)
            echo "Usage: kdebug <action> [options]"
            echo ""
            echo "Actions:"
            echo "  enable    - Enable debug mode"
            echo "  disable   - Disable debug mode"
            echo "  level     - Set debug level"
            echo "  trace     - Toggle function tracing"
            echo "  log       - Show debug log"
            echo "  clear     - Clear debug log"
            echo "  status    - Show debug status"
            echo ""
            echo "Debug levels: TRACE, DEBUG, INFO, WARN, ERROR, FATAL"
            ;;
    esac
}

# Initialize debug system when sourced
_kcm_init_debug
