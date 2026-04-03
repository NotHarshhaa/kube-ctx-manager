#!/usr/bin/env bash

# validation.sh - Comprehensive input validation and sanitization

# Validation patterns
declare -A KCM_VALIDATION_PATTERNS=(
    ["context_name"]="^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]$"
    ["namespace"]="^[a-z0-9][a-z0-9-]*[a-z0-9]$"
    ["bookmark_name"]="^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]$"
    ["tag"]="^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$"
    ["cluster_name"]="^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]$"
    ["user_name"]="^[a-zA-Z0-9][a-zA-Z0-9._-]*[a-zA-Z0-9]$"
    ["file_path"]="^[^\\s]+$"
    ["number"]="^[0-9]+$"
    ["positive_number"]="^[1-9][0-9]*$"
    ["port"]="^[1-9][0-9]{0,4}$"
    ["url"]="^https?://[a-zA-Z0-9.-]+[a-zA-Z0-9._/-]*$"
    ["email"]="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    ["yaml_file"]="^.+\\.ya?ml$"
    ["json_file"]="^.+\\.json$"
    ["backup_name"]="^[a-zA-Z0-9][a-zA-Z0-9_-]*[a-zA-Z0-9]$"
    ["log_level"]="^(DEBUG|INFO|WARN|ERROR|FATAL)$"
    ["prompt_style"]="^(minimal|full)$"
    ["backup_format"]="^(yaml|json|tar\\.gz)$"
)

# Validation error messages
declare -A KCM_VALIDATION_MESSAGES=(
    ["context_name"]="Context name must contain only letters, numbers, dots, hyphens, and underscores"
    ["namespace"]="Namespace must contain only lowercase letters, numbers, and hyphens"
    ["bookmark_name"]="Bookmark name must contain only letters, numbers, dots, hyphens, and underscores"
    ["tag"]="Tag must contain only letters, numbers, hyphens, and underscores"
    ["cluster_name"]="Cluster name must contain only letters, numbers, dots, hyphens, and underscores"
    ["user_name"]="User name must contain only letters, numbers, dots, hyphens, and underscores"
    ["file_path"]="File path cannot contain whitespace"
    ["number"]="Value must be a non-negative integer"
    ["positive_number"]="Value must be a positive integer"
    ["port"]="Port must be between 1 and 65535"
    ["url"]="URL must start with http:// or https://"
    ["email"]="Email address is not valid"
    ["yaml_file"]="File must have .yaml or .yml extension"
    ["json_file"]="File must have .json extension"
    ["backup_name"]="Backup name must contain only letters, numbers, hyphens, and underscores"
    ["log_level"]="Log level must be one of: DEBUG, INFO, WARN, ERROR, FATAL"
    ["prompt_style"]="Prompt style must be either 'minimal' or 'full'"
    ["backup_format"]="Backup format must be one of: yaml, json, tar.gz"
)

# Main validation function
_kcm_validate() {
    local value="$1"
    local pattern_type="$2"
    local field_name="${3:-Value}"
    local allow_empty="${4:-false}"
    
    # Check if empty values are allowed
    if [[ -z "$value" ]]; then
        if [[ "$allow_empty" == "true" ]]; then
            return 0
        else
            echo "❌ $field_name cannot be empty" >&2
            return 1
        fi
    fi
    
    # Get validation pattern
    local pattern="${KCM_VALIDATION_PATTERNS[$pattern_type]}"
    local message="${KCM_VALIDATION_MESSAGES[$pattern_type]}"
    
    if [[ -z "$pattern" ]]; then
        _kcm_log "ERROR" "Unknown validation pattern: $pattern_type"
        echo "❌ Internal error: Unknown validation pattern for $field_name" >&2
        return 1
    fi
    
    # Perform validation
    if [[ "$value" =~ $pattern ]]; then
        return 0
    else
        echo "❌ $field_name is invalid: $message" >&2
        return 1
    fi
}

# Context validation
_kcm_validate_context() {
    local context="$1"
    local check_exists="${2:-true}"
    
    # Validate format
    if ! _kcm_validate "$context" "context_name" "Context name"; then
        return 1
    fi
    
    # Check if context exists (optional)
    if [[ "$check_exists" == "true" ]]; then
        if ! _kcm_kubectl_context_exists "$context"; then
            echo "❌ Context does not exist: $context" >&2
            echo "Available contexts:" >&2
            kubectl config get-contexts -o name | sed 's/^.*\///' | head -5 | sed 's/^/  /' >&2
            return 1
        fi
    fi
    
    return 0
}

# Namespace validation
_kcm_validate_namespace() {
    local namespace="$1"
    local context="${2:-$(kubectl config current-context 2>/dev/null)}"
    local check_exists="${3:-true}"
    
    # Validate format
    if ! _kcm_validate "$namespace" "namespace" "Namespace"; then
        return 1
    fi
    
    # Check if namespace exists (optional)
    if [[ "$check_exists" == "true" && -n "$context" ]]; then
        if ! _kcm_kubectl_namespace_exists "$namespace" "$context"; then
            echo "❌ Namespace does not exist: $namespace" >&2
            echo "Available namespaces:" >&2
            kubectl --context="$context" get namespaces -o name | sed 's/^.*\///' | head -5 | sed 's/^/  /' >&2
            return 1
        fi
    fi
    
    return 0
}

# Bookmark validation
_kcm_validate_bookmark() {
    local bookmark_name="$1"
    local context="$2"
    local description="$3"
    local tags="$4"
    
    # Validate bookmark name
    if ! _kcm_validate "$bookmark_name" "bookmark_name" "Bookmark name"; then
        return 1
    fi
    
    # Check if bookmark already exists
    if grep -q "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE" 2>/dev/null; then
        echo "❌ Bookmark already exists: $bookmark_name" >&2
        return 1
    fi
    
    # Validate context
    if ! _kcm_validate_context "$context" "true"; then
        return 1
    fi
    
    # Validate tags (if provided)
    if [[ -n "$tags" ]]; then
        IFS=',' read -ra tag_array <<< "$tags"
        for tag in "${tag_array[@]}"; do
            tag=$(_kcm_str_trim "$tag")
            if ! _kcm_validate "$tag" "tag" "Tag"; then
                return 1
            fi
        done
    fi
    
    return 0
}

# File validation
_kcm_validate_file() {
    local file_path="$1"
    local file_type="${2:-any}"
    local check_readable="${3:-true}"
    local check_writable="${4:-false}"
    
    # Validate path format
    if ! _kcm_validate "$file_path" "file_path" "File path"; then
        return 1
    fi
    
    # Check if file exists
    if [[ ! -f "$file_path" ]]; then
        echo "❌ File does not exist: $file_path" >&2
        return 1
    fi
    
    # Check readability
    if [[ "$check_readable" == "true" && ! -r "$file_path" ]]; then
        echo "❌ File is not readable: $file_path" >&2
        return 1
    fi
    
    # Check writability
    if [[ "$check_writable" == "true" && ! -w "$file_path" ]]; then
        echo "❌ File is not writable: $file_path" >&2
        return 1
    fi
    
    # Validate file type
    case "$file_type" in
        "yaml")
            if ! _kcm_validate "$file_path" "yaml_file" "File"; then
                return 1
            fi
            ;;
        "json")
            if ! _kcm_validate "$file_path" "json_file" "File"; then
                return 1
            fi
            ;;
    esac
    
    return 0
}

# Number validation
_kcm_validate_number() {
    local value="$1"
    local min="${2:-}"
    local max="${3:-}"
    local field_name="${4:-Number}"
    
    # Validate numeric format
    if ! _kcm_validate "$value" "number" "$field_name"; then
        return 1
    fi
    
    # Validate range
    if [[ -n "$min" ]] && ! _kcm_validate_range "$value" "$min" "" "$field_name (minimum: $min)"; then
        return 1
    fi
    
    if [[ -n "$max" ]] && ! _kcm_validate_range "$value" "" "$max" "$field_name (maximum: $max)"; then
        return 1
    fi
    
    return 0
}

# Port validation
_kcm_validate_port() {
    local port="$1"
    local field_name="${2:-Port}"
    
    # Validate port format
    if ! _kcm_validate "$port" "port" "$field_name"; then
        return 1
    fi
    
    # Validate port range
    if [[ $port -lt 1 || $port -gt 65535 ]]; then
        echo "❌ $field_name must be between 1 and 65535: $port" >&2
        return 1
    fi
    
    return 0
}

# Configuration validation
_kcm_validate_config_value() {
    local key="$1"
    local value="$2"
    
    case "$key" in
        "KCM_SUGGEST_THRESHOLD"|"KCM_ANALYTICS_DAYS"|"KCM_BACKUP_DAYS")
            _kcm_validate_number "$value" "1" "365" "$key"
            ;;
        "KCM_DEBUG"|"KCM_PROMPT"|"KCM_SEARCH_CASE_SENSITIVE")
            if [[ "$value" =~ ^(0|1|true|false|yes|no)$ ]]; then
                return 0
            else
                echo "❌ $key must be 0/1, true/false, or yes/no: $value" >&2
                return 1
            fi
            ;;
        "KCM_LOG_LEVEL")
            _kcm_validate "$value" "log_level" "$key"
            ;;
        "KCM_PROMPT_STYLE")
            _kcm_validate "$value" "prompt_style" "$key"
            ;;
        "KCM_BACKUP_FORMAT")
            _kcm_validate "$value" "backup_format" "$key"
            ;;
        "KCM_PROD_PATTERN")
            if [[ -n "$value" ]]; then
                # Test regex pattern
                if [[ "test" =~ $value ]] 2>/dev/null; then
                    return 0
                else
                    echo "❌ $key contains invalid regex pattern: $value" >&2
                    return 1
                fi
            fi
            ;;
        *)
            echo "❌ Unknown configuration key: $key" >&2
            return 1
            ;;
    esac
}

# Search pattern validation
_kcm_validate_search_pattern() {
    local pattern="$1"
    local search_type="${2:-all}"
    
    if [[ -z "$pattern" ]]; then
        echo "❌ Search pattern cannot be empty" >&2
        return 1
    fi
    
    # Check for potentially dangerous regex patterns
    if [[ "$pattern" =~ \*\* ]]; then
        echo "⚠️  Pattern contains '**', this may be slow" >&2
    fi
    
    # Validate based on search type
    case "$search_type" in
        "regex")
            # Test if pattern is valid regex
            if [[ "test" =~ $pattern ]] 2>/dev/null; then
                return 0
            else
                echo "❌ Invalid regular expression: $pattern" >&2
                return 1
            fi
            ;;
        "glob")
            # Basic glob pattern validation
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

# Command arguments validation
_kcm_validate_command_args() {
    local command="$1"
    shift
    local args=("$@")
    
    case "$command" in
        "kx")
            if [[ ${#args[@]} -gt 1 ]]; then
                echo "❌ kx accepts at most one argument (context name or '-')" >&2
                return 1
            fi
            if [[ ${#args[@]} -eq 1 && "${args[0]}" != "-" ]]; then
                _kcm_validate_context "${args[0]}" "true"
            fi
            ;;
        "kns")
            if [[ ${#args[@]} -gt 1 ]]; then
                echo "❌ kns accepts at most one argument (namespace name)" >&2
                return 1
            fi
            if [[ ${#args[@]} -eq 1 ]]; then
                _kcm_validate_namespace "${args[0]}"
            fi
            ;;
        "kbookmark-add")
            if [[ ${#args[@]} -lt 2 ]]; then
                echo "❌ kbookmark-add requires at least 2 arguments: <bookmark-name> <context>" >&2
                return 1
            fi
            _kcm_validate_bookmark "${args[0]}" "${args[1]}" "${args[2]:-}" "${args[3]:-}"
            ;;
        "kube-backup")
            if [[ ${#args[@]} -gt 2 ]]; then
                echo "❌ kube-backup accepts at most 2 arguments: [config-file] [backup-name]" >&2
                return 1
            fi
            if [[ ${#args[@]} -ge 1 ]]; then
                _kcm_validate_file "${args[0]}" "any" "true" "false"
            fi
            if [[ ${#args[@]} -eq 2 ]]; then
                _kcm_validate "${args[1]}" "backup_name" "Backup name"
            fi
            ;;
        "ksearch")
            if [[ ${#args[@]} -lt 1 ]]; then
                echo "❌ ksearch requires at least 1 argument: <pattern>" >&2
                return 1
            fi
            _kcm_validate_search_pattern "${args[0]}" "${args[1]:-all}"
            ;;
        *)
            # Unknown command, skip validation
            return 0
            ;;
    esac
}

# Batch validation
_kcm_validate_batch() {
    local -a validations=("$@")
    local errors=()
    
    for validation in "${validations[@]}"; do
        IFS='|' read -r type value field_name options <<< "$validation"
        
        case "$type" in
            "context")
                if ! _kcm_validate_context "$value" "true"; then
                    errors+=("Context validation failed: $value")
                fi
                ;;
            "namespace")
                if ! _kcm_validate_namespace "$value"; then
                    errors+=("Namespace validation failed: $value")
                fi
                ;;
            "file")
                if ! _kcm_validate_file "$value"; then
                    errors+=("File validation failed: $value")
                fi
                ;;
            "number")
                if ! _kcm_validate_number "$value"; then
                    errors+=("Number validation failed: $value")
                fi
                ;;
            "pattern")
                if ! _kcm_validate "$value" "pattern_name" "$field_name"; then
                    errors+=("Pattern validation failed: $field_name")
                fi
                ;;
        esac
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ Validation errors:" >&2
        for error in "${errors[@]}"; do
            echo "  - $error" >&2
        done
        return 1
    fi
    
    return 0
}

# Interactive validation with correction suggestions
_kcm_validate_interactive() {
    local value="$1"
    local pattern_type="$2"
    local field_name="${3:-Value}"
    
    while true; do
        if _kcm_validate "$value" "$pattern_type" "$field_name"; then
            echo "$value"
            return 0
        fi
        
        echo "Please enter a valid $field_name (or press Ctrl+C to cancel):"
        read -r new_value
        
        if [[ -z "$new_value" ]]; then
            echo "❌ $field_name cannot be empty" >&2
            continue
        fi
        
        value="$new_value"
    done
}

# Sanitize input
_kcm_sanitize() {
    local input="$1"
    local sanitize_type="${2:-basic}"
    
    case "$sanitize_type" in
        "basic")
            # Remove control characters
            echo "$input" | tr -d '\000-\010\013\014\016-\037\177-\377'
            ;;
        "filename")
            # Remove dangerous characters for filenames
            echo "$input" | sed 's/[\\/:"*?<>|]/_/g'
            ;;
        "shell")
            # Escape shell special characters
            printf '%q' "$input"
            ;;
        "regex")
            # Escape regex special characters
            echo "$input" | sed 's/[]\/$*.^[]/\\&/g'
            ;;
        *)
            echo "$input"
            ;;
    esac
}

# Validation report generator
_kcm_validation_report() {
    local target="${1:-all}"
    
    echo "Validation Report"
    echo "================"
    
    case "$target" in
        "contexts")
            echo "Validating all contexts..."
            local contexts
            contexts=$(kubectl config get-contexts -o name | sed 's/^.*\///')
            local valid_count=0
            local total_count=0
            
            while IFS= read -r context; do
                ((total_count++))
                if _kcm_validate_context "$context" "false"; then
                    ((valid_count++))
                    echo "✅ $context"
                else
                    echo "❌ $context"
                fi
            done <<< "$contexts"
            
            echo ""
            echo "Summary: $valid_count/$total_count contexts are valid"
            ;;
        "bookmarks")
            echo "Validating all bookmarks..."
            if [[ -f "$KCM_BOOKMARKS_FILE" ]]; then
                local valid_count=0
                local total_count=0
                
                while IFS=: read -r bookmark_name context description tags; do
                    [[ -z "$bookmark_name" || "$bookmark_name" =~ ^# ]] && continue
                    ((total_count++))
                    
                    if _kcm_validate_bookmark "$bookmark_name" "$context" "$description" "$tags" 2>/dev/null; then
                        ((valid_count++))
                        echo "✅ $bookmark_name"
                    else
                        echo "❌ $bookmark_name"
                    fi
                done < "$KCM_BOOKMARKS_FILE"
                
                echo ""
                echo "Summary: $valid_count/$total_count bookmarks are valid"
            else
                echo "No bookmarks file found"
            fi
            ;;
        "config")
            echo "Validating configuration..."
            if _kcm_validate_config; then
                echo "✅ Configuration is valid"
            else
                echo "❌ Configuration has errors"
            fi
            ;;
        "all")
            _kcm_validation_report "contexts"
            echo ""
            _kcm_validation_report "bookmarks"
            echo ""
            _kcm_validation_report "config"
            ;;
        *)
            echo "Usage: _kcm_validation_report <target>"
            echo "Targets: contexts, bookmarks, config, all"
            return 1
            ;;
    esac
}
