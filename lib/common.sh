#!/usr/bin/env bash

# common.sh - Common utilities (simple working version)

# Colors
export KCM_RED='\033[0;31m'
export KCM_GREEN='\033[0;32m'
export KCM_YELLOW='\033[1;33m'
export KCM_BLUE='\033[0;34m'
export KCM_NC='\033[0m'

# Initialize
_kcm_init_common() {
    export KCM_TMP_DIR="${KCM_TMP_DIR:-/tmp/kube-ctx-manager}"
    mkdir -p "$KCM_TMP_DIR"
}

# Logging
_kcm_log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${KCM_GREEN}[INFO]${KCM_NC} [$timestamp] $message"
            ;;
        "WARN")
            echo -e "${KCM_YELLOW}[WARN]${KCM_NC} [$timestamp] $message" >&2
            ;;
        "ERROR")
            echo -e "${KCM_RED}[ERROR]${KCM_NC} [$timestamp] $message" >&2
            ;;
        "DEBUG")
            if [[ "${KCM_DEBUG:-0}" == "1" ]]; then
                echo -e "${KCM_BLUE}[DEBUG]${KCM_NC} [$timestamp] $message" >&2
            fi
            ;;
    esac
}

# Command check
_kcm_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Safe execute
_kcm_safe_execute() {
    local timeout="$1"
    shift
    local cmd="$*"
    
    timeout "$timeout" bash -c "$cmd" 2>/dev/null
}

# Get current context
_kcm_get_current_context_safe() {
    kubectl config current-context 2>/dev/null || echo "none"
}

# Context exists
_kcm_context_exists() {
    kubectl config get-contexts "$1" >/dev/null 2>&1
}

# Make temp file
_kcm_mktemp() {
    mktemp -t kcm.XXXXXX
}

# Progress bar
_kcm_show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"
    
    local percentage=$((current * 100 / total))
    printf "\r%s: %d%% (%d/%d)" "$message" "$percentage" "$current" "$total"
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# Success message
_kcm_success() {
    echo -e "${KCM_GREEN}✓ $*${KCM_NC}"
}

# Error message
_kcm_error() {
    echo -e "${KCM_RED}❌ $*${KCM_NC}" >&2
}

# Warning message
_kcm_warning() {
    echo -e "${KCM_YELLOW}⚠️  $*${KCM_NC}" >&2
}

# Info message
_kcm_info() {
    echo -e "${KCM_BLUE}ℹ️  $*${KCM_NC}"
}

# System info
_kcm_get_system_info() {
    echo "System Information:"
    echo "OS: $(uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Shell: $SHELL"
    echo "Bash version: $BASH_VERSION"
}

# Memory usage
_kcm_memory_usage() {
    ps aux | grep bash | awk '{sum += $6} END {print sum/1024 " MB"}' || echo "N/A"
}

# Initialize
_kcm_init_common
