#!/usr/bin/env bash

# utils.sh - Utility functions and reusable components

# String utilities
_kcm_str_contains() {
    local string="$1"
    local substring="$2"
    
    [[ "$string" == *"$substring"* ]]
}

_kcm_str_starts_with() {
    local string="$1"
    local prefix="$2"
    
    [[ "$string" == "$prefix"* ]]
}

_kcm_str_ends_with() {
    local string="$1"
    local suffix="$2"
    
    [[ "$string" == *"$suffix" ]]
}

_kcm_str_trim() {
    local string="$1"
    # Remove leading/trailing whitespace
    string="${string#"${string%%[![:space:]]*}"}"
    string="${string%"${string##*[![:space:]]}"}"
    echo "$string"
}

_kcm_str_to_lower() {
    local string="$1"
    echo "${string,,}"
}

_kcm_str_to_upper() {
    local string="$1"
    echo "${string^^}"
}

_kcm_str_escape_regex() {
    local string="$1"
    # Escape special regex characters
    echo "$string" | sed 's/[]\/$*.^[]/\\&/g'
}

# Array utilities
_kcm_array_contains() {
    local needle="$1"
    shift
    local haystack=("$@")
    
    for item in "${haystack[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

_kcm_array_join() {
    local delimiter="$1"
    shift
    local items=("$@")
    
    if [[ ${#items[@]} -eq 0 ]]; then
        return 0
    fi
    
    local result="${items[0]}"
    for ((i=1; i<${#items[@]}; i++)); do
        result+="$delimiter${items[$i]}"
    done
    echo "$result"
}

_kcm_array_unique() {
    local items=("$@")
    local unique_items=()
    
    for item in "${items[@]}"; do
        if ! _kcm_array_contains "$item" "${unique_items[@]}"; then
            unique_items+=("$item")
        fi
    done
    
    printf '%s\n' "${unique_items[@]}"
}

_kcm_array_sort() {
    local items=("$@")
    printf '%s\n' "${items[@]}" | sort
}

# File utilities
_kcm_file_exists() {
    local file="$1"
    [[ -f "$file" ]]
}

_kcm_dir_exists() {
    local dir="$1"
    [[ -d "$dir" ]]
}

_kcm_file_readable() {
    local file="$1"
    [[ -r "$file" ]]
}

_kcm_file_writable() {
    local file="$1"
    [[ -w "$file" ]]
}

_kcm_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

_kcm_file_age() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local current_time
        current_time=$(date +%s)
        local file_time
        file_time=$(stat -c%Y "$file" 2>/dev/null || stat -f%m "$file" 2>/dev/null)
        echo $((current_time - file_time))
    else
        echo "0"
    fi
}

# Number utilities
_kcm_is_number() {
    local value="$1"
    [[ "$value" =~ ^-?[0-9]+$ ]]
}

_kcm_is_float() {
    local value="$1"
    [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]]
}

_kcm_min() {
    local a="$1"
    local b="$2"
    
    if [[ $a -lt $b ]]; then
        echo "$a"
    else
        echo "$b"
    fi
}

_kcm_max() {
    local a="$1"
    local b="$2"
    
    if [[ $a -gt $b ]]; then
        echo "$a"
    else
        echo "$b"
    fi
}

_kclamp() {
    local value="$1"
    local min="$2"
    local max="$3"
    
    if _kcm_is_number "$value" && _kcm_is_number "$min" && _kcm_is_number "$max"; then
        if [[ $value -lt $min ]]; then
            echo "$min"
        elif [[ $value -gt $max ]]; then
            echo "$max"
        else
            echo "$value"
        fi
    else
        echo "$value"
    fi
}

# Time utilities
_kcm_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

_kcm_timestamp_unix() {
    date +%s
}

_kcm_duration_format() {
    local seconds="$1"
    
    if ! _kcm_is_number "$seconds"; then
        echo "0s"
        return
    fi
    
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    
    local result=""
    
    [[ $days -gt 0 ]] && result+="${days}d "
    [[ $hours -gt 0 ]] && result+="${hours}h "
    [[ $minutes -gt 0 ]] && result+="${minutes}m "
    result+="${secs}s"
    
    echo "$result"
}

# Color utilities
_kcm_color_code() {
    local color="$1"
    echo "${KCM_COLORS[$color]:-}"
}

_kcm_colorize() {
    local color="$1"
    shift
    local text="$*"
    
    local color_code
    color_code=$(_kcm_color_code "$color")
    
    if [[ -n "$color_code" ]]; then
        echo -e "${color_code}${text}${KCM_COLORS[NC]}"
    else
        echo "$text"
    fi
}

_kcm_colorize_status() {
    local status="$1"
    local text="$2"
    
    case "$status" in
        "success"|"ok"|"healthy")
            _kcm_colorize "GREEN" "$text"
            ;;
        "warning"|"warn"|"degraded")
            _kcm_colorize "YELLOW" "$text"
            ;;
        "error"|"fail"|"unhealthy"|"critical")
            _kcm_colorize "RED" "$text"
            ;;
        "info"|"default")
            _kcm_colorize "BLUE" "$text"
            ;;
        *)
            echo "$text"
            ;;
    esac
}

# Progress utilities
_kcm_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local char="${4:-█}"
    local empty_char="${5:-░}"
    
    if ! _kcm_is_number "$current" || ! _kcm_is_number "$total" || [[ $total -eq 0 ]]; then
        return
    fi
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar
    bar=$(printf "%*s" "$filled" | tr ' ' "$char")
    local empty_bar
    empty_bar=$(printf "%*s" "$empty" | tr ' ' "$empty_char")
    
    printf "[%s%s] %d%% (%d/%d)" "$bar" "$empty_bar" "$percentage" "$current" "$total"
}

# Interactive utilities
_kcm_select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    if [[ ${#options[@]} -eq 0 ]]; then
        return 1
    fi
    
    echo "$prompt"
    for i in "${!options[@]}"; do
        echo "  $((i + 1))) ${options[$i]}"
    done
    
    while true; do
        echo -n "Select option (1-${#options[@]}): "
        read -r selection
        
        if _kcm_is_number "$selection" && [[ $selection -ge 1 && $selection -le ${#options[@]} ]]; then
            echo "${options[$((selection - 1))]}"
            return 0
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

_kcm_confirm_action() {
    local message="$1"
    local default="${2:-n}"
    local timeout="${3:-0}"
    
    local prompt_suffix="[y/N]"
    if [[ "$default" == "y" ]]; then
        prompt_suffix="[Y/n]"
    fi
    
    local full_message="$message $prompt_suffix"
    if [[ $timeout -gt 0 ]]; then
        full_message="$full_message (timeout: ${timeout}s)"
    fi
    
    echo -n "$full_message: "
    
    local answer
    if [[ $timeout -gt 0 ]]; then
        if read -t "$timeout" -r answer; then
            case "$answer" in
                [yY]|[yY][eE][sS])
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
        else
            echo ""
            echo "Timeout, defaulting to: $default"
            [[ "$default" == "y" ]] && return 0 || return 1
        fi
    else
        if read -r answer; then
            case "$answer" in
                [yY]|[yY][eE][sS])
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
        fi
    fi
}

# Validation utilities
_kcm_validate_regex() {
    local pattern="$1"
    local value="$2"
    local field_name="$3"
    
    if [[ -z "$value" ]]; then
        echo "❌ $field_name cannot be empty" >&2
        return 1
    fi
    
    if [[ ! "$value" =~ $pattern ]]; then
        echo "❌ $field_name is invalid: $value" >&2
        return 1
    fi
    
    return 0
}

_kcm_validate_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local field_name="$4"
    
    if ! _kcm_is_number "$value"; then
        echo "❌ $field_name must be a number: $value" >&2
        return 1
    fi
    
    if [[ $value -lt $min || $value -gt $max ]]; then
        echo "❌ $field_name must be between $min and $max: $value" >&2
        return 1
    fi
    
    return 0
}

_kcm_validate_file() {
    local file_path="$1"
    local field_name="$2"
    local check_readable="${3:-true}"
    local check_writable="${4:-false}"
    
    if [[ -z "$file_path" ]]; then
        echo "❌ $field_name cannot be empty" >&2
        return 1
    fi
    
    if [[ ! -f "$file_path" ]]; then
        echo "❌ $field_name does not exist: $file_path" >&2
        return 1
    fi
    
    if [[ "$check_readable" == "true" && ! -r "$file_path" ]]; then
        echo "❌ $field_name is not readable: $file_path" >&2
        return 1
    fi
    
    if [[ "$check_writable" == "true" && ! -w "$file_path" ]]; then
        echo "❌ $field_name is not writable: $file_path" >&2
        return 1
    fi
    
    return 0
}

# Network utilities
_kcm_url_encode() {
    local string="$1"
    printf '%s' "$string" | xxd -p | sed 's/\(..\)/%\1/g' | tr -d '\n'
}

_kcm_url_decode() {
    local string="$1"
    printf '%b' "${string//%/\\x}"
}

_kcm_port_open() {
    local host="$1"
    local port="$2"
    local timeout="${3:-5}"
    
    if command -v nc >/dev/null 2>&1; then
        nc -z -w "$timeout" "$host" "$port" 2>/dev/null
    elif command -v telnet >/dev/null 2>&1; then
        timeout "$timeout" telnet "$host" "$port" </dev/null >/dev/null 2>&1
    else
        return 1
    fi
}

# JSON utilities (if jq is available)
_kcm_json_get() {
    local json="$1"
    local key="$2"
    local default_value="$3"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -r "$key // \"$default_value\"" 2>/dev/null || echo "$default_value"
    else
        echo "$default_value"
    fi
}

_kcm_json_set() {
    local json="$1"
    local key="$2"
    local value="$3"
    
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq "$key = \"$value\"" 2>/dev/null
    else
        echo "$json"
    fi
}

# Kubernetes specific utilities
_kcm_kubectl_version() {
    kubectl version --client --short 2>/dev/null | head -1 || echo "Unknown"
}

_kcm_kubectl_context_exists() {
    local context="$1"
    kubectl config get-contexts "$context" >/dev/null 2>&1
}

_kcm_kubectl_namespace_exists() {
    local namespace="$1"
    local context="${2:-$(kubectl config current-context 2>/dev/null)}"
    
    kubectl --context="$context" get namespace "$namespace" >/dev/null 2>&1
}

_kcm_kubectl_get_resource_count() {
    local resource_type="$1"
    local namespace="${2:-default}"
    local context="${3:-$(kubectl config current-context 2>/dev/null)}"
    
    kubectl --context="$context" --namespace="$namespace" get "$resource_type" --no-headers 2>/dev/null | wc -l
}

# Debug utilities
_kcm_debug_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    
    echo "DEBUG: $var_name = '$var_value'"
}

_kcm_debug_function() {
    local func_name="$1"
    shift
    local args=("$@")
    
    echo "DEBUG: Calling $func_name with args: ${args[*]}"
}

_kcm_debug_backtrace() {
    echo "DEBUG: Function backtrace:"
    local frame=0
    while caller $frame; do
        ((frame++))
    done 2>/dev/null || true
}

# Performance utilities
_kcm_time_function() {
    local func_name="$1"
    shift
    
    local start_time
    start_time=$(date +%s.%N)
    
    "$@"
    local exit_code=$?
    
    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
    
    echo "PERF: $func_name took ${duration}s"
    return $exit_code
}

_kcm_memory_usage() {
    local process_name="$1"
    
    if command -v ps >/dev/null 2>&1; then
        ps aux | grep "$process_name" | grep -v grep | awk '{sum += $6} END {print sum/1024 " MB"}' || echo "0 MB"
    else
        echo "N/A"
    fi
}
