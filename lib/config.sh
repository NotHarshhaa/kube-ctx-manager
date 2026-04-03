#!/usr/bin/env bash

# config.sh - Configuration management and validation

# Configuration file locations
export KCM_CONFIG_FILE="$HOME/.kube-ctx-manager.conf"
export KCM_CONFIG_DIR="$HOME/.kube-ctx-manager"

# Default configuration values
declare -A KCM_DEFAULTS=(
    ["KCM_PROD_PATTERN"]="prod|production|live|prd"
    ["KCM_SUGGEST_THRESHOLD"]="3"
    ["KCM_AUDIT_LOG"]="$HOME/.kube/audit.log"
    ["KCM_PROMPT"]="1"
    ["KCM_PROMPT_STYLE"]="full"
    ["KCM_DEBUG"]="0"
    ["KCM_LOG_LEVEL"]="INFO"
    ["KCM_CACHE_DEFAULT_TTL"]="300"
    ["KCM_CACHE_MAX_SIZE"]="10485760"
    ["KCM_HEALTH_CACHE_TTL"]="300"
    ["KCM_MONITOR_CACHE_TTL"]="60"
    ["KCM_ANALYTICS_DAYS"]="30"
    ["KCM_BACKUP_DAYS"]="30"
    ["KCM_BACKUP_FORMAT"]="yaml"
    ["KCM_SEARCH_CASE_SENSITIVE"]="0"
    ["KCM_FZF_HEIGHT"]="40%"
    ["KCM_FZF_LAYOUT"]="reverse"
    ["KCM_TIMEOUT"]="30"
    ["KCM_PARALLEL_JOBS"]="4"
)

# Current configuration (will be populated from defaults and user config)
declare -A KCM_CONFIG

# Initialize configuration system
_kcm_init_config() {
    # Create config directory
    mkdir -p "$KCM_CONFIG_DIR"
    
    # Load defaults
    for key in "${!KCM_DEFAULTS[@]}"; do
        KCM_CONFIG[$key]="${KCM_DEFAULTS[$key]}"
    done
    
    # Load user configuration if exists
    if [[ -f "$KCM_CONFIG_FILE" ]]; then
        _kcm_load_config
    fi
    
    # Override with environment variables
    _kcm_load_env_overrides
    
    # Validate configuration
    _kcm_validate_config
    
    # Export configuration variables
    _kcm_export_config
}

# Load configuration from file
_kcm_load_config() {
    _kcm_log "DEBUG" "Loading configuration from: $KCM_CONFIG_FILE"
    
    # Source the config file safely
    if bash -n "$KCM_CONFIG_FILE" 2>/dev/null; then
        # Read config line by line to avoid security issues
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ $key =~ ^[[:space:]]*# ]] && continue
            [[ -z $key ]] && continue
            
            # Remove quotes and spaces
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | sed 's/^["'\'']//' | sed 's/["'\'']$//' | xargs)
            
            # Set configuration value
            if [[ -n "$key" && -n "$value" ]]; then
                KCM_CONFIG[$key]="$value"
                _kcm_log "DEBUG" "Config loaded: $key=$value"
            fi
        done < "$KCM_CONFIG_FILE"
    else
        _kcm_log "WARN" "Configuration file has syntax errors: $KCM_CONFIG_FILE"
    fi
}

# Load environment variable overrides
_kcm_load_env_overrides() {
    _kcm_log "DEBUG" "Loading environment variable overrides"
    
    for key in "${!KCM_DEFAULTS[@]}"; do
        if [[ -n "${!key+x}" ]]; then
            local env_value="${!key}"
            KCM_CONFIG[$key]="$env_value"
            _kcm_log "DEBUG" "Env override: $key=$env_value"
        fi
    done
}

# Validate configuration values
_kcm_validate_config() {
    _kcm_log "DEBUG" "Validating configuration"
    
    local validation_errors=()
    
    # Validate numeric values
    local numeric_keys=(
        "KCM_SUGGEST_THRESHOLD"
        "KCM_DEBUG"
        "KCM_CACHE_DEFAULT_TTL"
        "KCM_CACHE_MAX_SIZE"
        "KCM_HEALTH_CACHE_TTL"
        "KCM_MONITOR_CACHE_TTL"
        "KCM_ANALYTICS_DAYS"
        "KCM_BACKUP_DAYS"
        "KCM_SEARCH_CASE_SENSITIVE"
        "KCM_TIMEOUT"
        "KCM_PARALLEL_JOBS"
    )
    
    for key in "${numeric_keys[@]}"; do
        local value="${KCM_CONFIG[$key]}"
        if [[ -n "$value" && ! "$value" =~ ^[0-9]+$ ]]; then
            validation_errors+=("$key must be a positive integer, got: $value")
        fi
    done
    
    # Validate boolean values
    local boolean_keys=(
        "KCM_PROMPT"
        "KCM_DEBUG"
        "KCM_SEARCH_CASE_SENSITIVE"
    )
    
    for key in "${boolean_keys[@]}"; do
        local value="${KCM_CONFIG[$key]}"
        if [[ -n "$value" && ! "$value" =~ ^(0|1|true|false|yes|no)$ ]]; then
            validation_errors+=("$key must be 0/1, true/false, or yes/no, got: $value")
        fi
    done
    
    # Validate log level
    local valid_log_levels=("DEBUG" "INFO" "WARN" "ERROR" "FATAL")
    local log_level="${KCM_CONFIG[KCM_LOG_LEVEL]}"
    if [[ -n "$log_level" ]]; then
        local level_valid=false
        for level in "${valid_log_levels[@]}"; do
            if [[ "$log_level" == "$level" ]]; then
                level_valid=true
                break
            fi
        done
        if [[ "$level_valid" == false ]]; then
            validation_errors+=("KCM_LOG_LEVEL must be one of: ${valid_log_levels[*]}, got: $log_level")
        fi
    fi
    
    # Validate prompt style
    local valid_prompt_styles=("minimal" "full")
    local prompt_style="${KCM_CONFIG[KCM_PROMPT_STYLE]}"
    if [[ -n "$prompt_style" ]]; then
        local style_valid=false
        for style in "${valid_prompt_styles[@]}"; do
            if [[ "$prompt_style" == "$style" ]]; then
                style_valid=true
                break
            fi
        done
        if [[ "$style_valid" == false ]]; then
            validation_errors+=("KCM_PROMPT_STYLE must be one of: ${valid_prompt_styles[*]}, got: $prompt_style")
        fi
    fi
    
    # Validate backup format
    local valid_backup_formats=("yaml" "json" "tar.gz")
    local backup_format="${KCM_CONFIG[KCM_BACKUP_FORMAT]}"
    if [[ -n "$backup_format" ]]; then
        local format_valid=false
        for format in "${valid_backup_formats[@]}"; do
            if [[ "$backup_format" == "$format" ]]; then
                format_valid=true
                break
            fi
        done
        if [[ "$format_valid" == false ]]; then
            validation_errors+=("KCM_BACKUP_FORMAT must be one of: ${valid_backup_formats[*]}, got: $backup_format")
        fi
    fi
    
    # Validate file paths
    local file_keys=(
        "KCM_AUDIT_LOG"
        "KCM_CONFIG_FILE"
    )
    
    for key in "${file_keys[@]}"; do
        local value="${KCM_CONFIG[$key]}"
        if [[ -n "$value" ]]; then
            local dir
            dir=$(dirname "$value")
            if [[ ! -d "$dir" ]]; then
                validation_errors+=("Directory does not exist for $key: $dir")
            fi
        fi
    done
    
    # Report validation errors
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        _kcm_log "ERROR" "Configuration validation failed:"
        for error in "${validation_errors[@]}"; do
            _kcm_log "ERROR" "  - $error"
        done
        echo "❌ Configuration validation failed:" >&2
        for error in "${validation_errors[@]}"; do
            echo "  - $error" >&2
        done
        return 1
    fi
    
    _kcm_log "DEBUG" "Configuration validation passed"
    return 0
}

# Export configuration variables
_kcm_export_config() {
    _kcm_log "DEBUG" "Exporting configuration variables"
    
    for key in "${!KCM_CONFIG[@]}"; do
        export "$key"="${KCM_CONFIG[$key]}"
    done
}

# Get configuration value
_kcm_get_config() {
    local key="$1"
    local default_value="$2"
    
    local value="${KCM_CONFIG[$key]:-$default_value}"
    echo "$value"
}

# Set configuration value
_kcm_set_config() {
    local key="$1"
    local value="$2"
    local persist="${3:-false}"
    
    # Validate key
    if [[ -z "${KCM_DEFAULTS[$key]+x}" ]]; then
        _kcm_log "ERROR" "Unknown configuration key: $key"
        echo "❌ Unknown configuration key: $key" >&2
        return 1
    fi
    
    # Set in current config
    KCM_CONFIG[$key]="$value"
    export "$key"="$value"
    
    _kcm_log "DEBUG" "Configuration set: $key=$value"
    
    # Persist to file if requested
    if [[ "$persist" == "true" ]]; then
        _kcm_save_config
    fi
}

# Save configuration to file
_kcm_save_config() {
    _kcm_log "DEBUG" "Saving configuration to: $KCM_CONFIG_FILE"
    
    local temp_file
    temp_file=$(_kcm_mktemp config_save)
    
    {
        echo "# kube-ctx-manager configuration"
        echo "# Generated on: $(date)"
        echo ""
        
        # Write all configuration values that differ from defaults
        for key in "${!KCM_DEFAULTS[@]}"; do
            local default_value="${KCM_DEFAULTS[$key]}"
            local current_value="${KCM_CONFIG[$key]}"
            
            if [[ "$current_value" != "$default_value" ]]; then
                echo "$key=\"$current_value\""
            fi
        done
    } > "$temp_file"
    
    # Validate and move
    if bash -n "$temp_file" 2>/dev/null; then
        mv "$temp_file" "$KCM_CONFIG_FILE"
        _kcm_log "INFO" "Configuration saved successfully"
    else
        rm -f "$temp_file"
        _kcm_log "ERROR" "Failed to save configuration (syntax error)"
        echo "❌ Failed to save configuration (syntax error)" >&2
        return 1
    fi
}

# Reset configuration to defaults
_kcm_reset_config() {
    _kcm_log "INFO" "Resetting configuration to defaults"
    
    for key in "${!KCM_DEFAULTS[@]}"; do
        KCM_CONFIG[$key]="${KCM_DEFAULTS[$key]}"
        export "$key"="${KCM_DEFAULTS[$key]}"
    done
    
    # Remove config file
    rm -f "$KCM_CONFIG_FILE"
    
    _kcm_log "INFO" "Configuration reset to defaults"
}

# Show current configuration
_kcm_show_config() {
    echo "kube-ctx-manager Configuration:"
    echo "=============================="
    
    for key in "${!KCM_DEFAULTS[@]}"; do
        local default_value="${KCM_DEFAULTS[$key]}"
        local current_value="${KCM_CONFIG[$key]}"
        local source="default"
        
        if [[ "$current_value" != "$default_value" ]]; then
            source="custom"
        fi
        
        printf "%-25s = %-20s (%s)\n" "$key" "$current_value" "$source"
    done
}

# Configuration management commands
kconfig() {
    local action="$1"
    shift
    
    case "$action" in
        "show")
            _kcm_show_config
            ;;
        "get")
            local key="$1"
            if [[ -z "$key" ]]; then
                echo "Usage: kconfig get <key>"
                return 1
            fi
            _kcm_get_config "$key"
            ;;
        "set")
            local key="$1"
            local value="$2"
            local persist="${3:-false}"
            
            if [[ -z "$key" || -z "$value" ]]; then
                echo "Usage: kconfig set <key> <value> [--persist]"
                return 1
            fi
            
            if [[ "$value" == "--persist" ]]; then
                persist="true"
                value="$2"
            fi
            
            _kcm_set_config "$key" "$value" "$persist"
            ;;
        "save")
            _kcm_save_config
            ;;
        "reset")
            echo "This will reset all configuration to defaults. Continue? [y/N]"
            read -r response
            if [[ "$response" =~ ^[yY] ]]; then
                _kcm_reset_config
                echo "✓ Configuration reset to defaults"
            else
                echo "Reset cancelled"
            fi
            ;;
        "validate")
            if _kcm_validate_config; then
                echo "✓ Configuration is valid"
            else
                echo "❌ Configuration validation failed"
                return 1
            fi
            ;;
        *)
            echo "Usage: kconfig <action> [options]"
            echo ""
            echo "Actions:"
            echo "  show                    - Show current configuration"
            echo "  get <key>              - Get configuration value"
            echo "  set <key> <value>      - Set configuration value"
            echo "  save                    - Save configuration to file"
            echo "  reset                   - Reset to defaults"
            echo "  validate                - Validate configuration"
            echo ""
            echo "Examples:"
            echo "  kconfig show"
            echo "  kconfig set KCM_DEBUG 1 --persist"
            echo "  kconfig get KCM_PROD_PATTERN"
            ;;
    esac
}

# Initialize configuration system when sourced
_kcm_init_config
