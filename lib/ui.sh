#!/usr/bin/env bash

# ui.sh - Enhanced user interface and experience

# UI Configuration
export KCM_UI_COLORS_ENABLED="${KCM_UI_COLORS_ENABLED:-true}"
export KCM_UI_ICONS_ENABLED="${KCM_UI_ICONS_ENABLED:-true}"
export KCM_UI_PROGRESS_ENABLED="${KCM_UI_PROGRESS_ENABLED:-true}"
export KCM_UI_ANIMATIONS_ENABLED="${KCM_UI_ANIMATIONS_ENABLED:-true}"

# UI Icons
declare -A KCM_ICONS=(
    ["success"]="✅"
    ["error"]="❌"
    ["warning"]="⚠️"
    ["info"]="ℹ️"
    ["loading"]="⏳"
    ["spinner"]="⠋"
    ["arrow"]="→"
    ["bullet"]="•"
    ["star"]="⭐"
    ["lock"]="🔒"
    ["unlock"]="🔓"
    ["check"]="✔"
    ["cross"]="✖"
    ["gear"]="⚙️"
    ["rocket"]="🚀"
    ["fire"]="🔥"
    ["zap"]="⚡"
    ["shield"]="🛡️"
    ["database"]="💾"
    ["search"]="🔍"
    ["bookmark"]="🔖"
    ["cloud"]="☁️"
    ["cluster"]="🏗️"
    ["health"]="💚"
    ["unhealthy"]="❤️"
    ["unknown"]="❓"
)

# Spinner characters for animations
declare -a KCM_SPINNER_CHARS=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')

# Enhanced message output
_kcm_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%H:%M:%S')
    
    local icon=""
    local color=""
    
    if [[ "$KCM_UI_ICONS_ENABLED" == "true" ]]; then
        case "$level" in
            "success") icon="${KCM_ICONS[success]}" ;;
            "error") icon="${KCM_ICONS[error]}" ;;
            "warning") icon="${KCM_ICONS[warning]}" ;;
            "info") icon="${KCM_ICONS[info]}" ;;
            "loading") icon="${KCM_ICONS[loading]}" ;;
        esac
    fi
    
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        case "$level" in
            "success") color="${KCM_COLORS[GREEN]}" ;;
            "error") color="${KCM_COLORS[RED]}" ;;
            "warning") color="${KCM_COLORS[YELLOW]}" ;;
            "info") color="${KCM_COLORS[BLUE]}" ;;
            "loading") color="${KCM_COLORS[CYAN]}" ;;
        esac
    fi
    
    # Build message
    local formatted_message=""
    if [[ -n "$timestamp" ]]; then
        formatted_message="[$timestamp] "
    fi
    if [[ -n "$icon" ]]; then
        formatted_message+="$icon "
    fi
    formatted_message+="$message"
    
    # Apply color and output
    if [[ -n "$color" ]]; then
        echo -e "${color}${formatted_message}${KCM_COLORS[NC]}"
    else
        echo "$formatted_message"
    fi
}

# Success message
_kcm_success() {
    _kcm_message "success" "$@"
}

# Error message
_kcm_error() {
    _kcm_message "error" "$@" >&2
}

# Warning message
_kcm_warning() {
    _kcm_message "warning" "$@" >&2
}

# Info message
_kcm_info() {
    _kcm_message "info" "$@"
}

# Loading message
_kcm_loading() {
    _kcm_message "loading" "$@"
}

# Enhanced progress bar with animation
_kcm_progress_bar_enhanced() {
    local current="$1"
    local total="$2"
    local width="${3:-50}"
    local message="${4:-Processing}"
    local show_percentage="${5:-true}"
    local show_eta="${6:-true}"
    
    if [[ "$KCM_UI_PROGRESS_ENABLED" != "true" ]]; then
        echo "$message: $current/$total"
        return
    fi
    
    if ! _kcm_is_number "$current" || ! _kcm_is_number "$total" || [[ $total -eq 0 ]]; then
        return
    fi
    
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    # Create progress bar
    local bar=""
    local i
    for ((i=0; i<filled; i++)); do
        bar+="█"
    done
    for ((i=0; i<empty; i++)); do
        bar+="░"
    done
    
    # Build output
    local output=""
    output+="$message: ["
    
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        if [[ $percentage -ge 80 ]]; then
            output+="${KCM_COLORS[GREEN]}$bar${KCM_COLORS[NC]}"
        elif [[ $percentage -ge 50 ]]; then
            output+="${KCM_COLORS[YELLOW]}$bar${KCM_COLORS[NC]}"
        else
            output+="${KCM_COLORS[RED]}$bar${KCM_COLORS[NC]}"
        fi
    else
        output+="$bar"
    fi
    
    output+="]"
    
    if [[ "$show_percentage" == "true" ]]; then
        output+=" $percentage%"
    fi
    
    output+=" ($current/$total)"
    
    # Add ETA if requested and we have progress
    if [[ "$show_eta" == "true" && $current -gt 0 ]]; then
        local start_time="${KCM_PROGRESS_START_TIME:-$(date +%s)}"
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        local rate=$((current / elapsed))
        
        if [[ $rate -gt 0 ]]; then
            local remaining=$((total - current))
            local eta=$((remaining / rate))
            local eta_formatted
            eta_formatted=$(_kcm_duration_format "$eta")
            output+=" ETA: $eta_formatted"
        fi
    fi
    
    # Output with carriage return for overwriting
    printf "\r%s" "$output"
    
    # New line when complete
    if [[ $current -eq $total ]]; then
        echo ""
        unset KCM_PROGRESS_START_TIME
    elif [[ -z "${KCM_PROGRESS_START_TIME:-}" ]]; then
        export KCM_PROGRESS_START_TIME=$(date +%s)
    fi
}

# Animated spinner
_kcm_spinner() {
    local message="$1"
    local pid="$2"
    local delay="${3:-0.1}"
    
    if [[ "$KCM_UI_ANIMATIONS_ENABLED" != "true" ]]; then
        echo "$message..."
        return
    fi
    
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        local char="${KCM_SPINNER_CHARS[$i]}"
        printf "\r%s %s" "$message" "$char"
        i=$(((i + 1) % 10))
        sleep "$delay"
    done
    printf "\r%s %s\n" "$message" "${KCM_ICONS[success]}"
}

# Interactive menu with enhanced UI
_kcm_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    if [[ ${#options[@]} -eq 0 ]]; then
        return 1
    fi
    
    echo ""
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        echo -e "${KCM_COLORS[BOLD]}${KCM_COLORS[BLUE]}$title${KCM_COLORS[NC]}"
    else
        echo "$title"
    fi
    echo "$(printf '=%.0s' {1..40})"
    
    for i in "${!options[@]}"; do
        local option="${options[$i]}"
        local number=$((i + 1))
        
        if [[ "$KCM_UI_ICONS_ENABLED" == "true" ]]; then
            printf "  ${KCM_ICONS[bullet]} %d) %s\n" "$number" "$option"
        else
            printf "  %d) %s\n" "$number" "$option"
        fi
    done
    
    echo ""
    
    while true; do
        if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
            echo -n -e "${KCM_COLORS[CYAN]}Select option (1-${#options[@]}): ${KCM_COLORS[NC]}"
        else
            echo -n "Select option (1-${#options[@]}): "
        fi
        
        read -r selection
        
        if _kcm_is_number "$selection" && [[ $selection -ge 1 && $selection -le ${#options[@]} ]]; then
            echo "${options[$((selection - 1))]}"
            return 0
        else
            _kcm_error "Invalid selection. Please enter a number between 1 and ${#options[@]}"
        fi
    done
}

# Confirmation dialog with enhanced UI
_kcm_confirm_enhanced() {
    local message="$1"
    local default="${2:-n}"
    local timeout="${3:-0}"
    local show_warning="${4:-false}"
    
    echo ""
    
    if [[ "$show_warning" == "true" ]]; then
        if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
            echo -e "${KCM_COLORS[YELLOW]}${KCM_ICONS[warning]} Warning: $message${KCM_COLORS[NC]}"
        else
            echo "${KCM_ICONS[warning]} Warning: $message"
        fi
    else
        if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
            echo -e "${KCM_COLORS[BLUE]}${KCM_ICONS[info]} $message${KCM_COLORS[NC]}"
        else
            echo "${KCM_ICONS[info]} $message"
        fi
    fi
    
    local prompt_suffix="[y/N]"
    if [[ "$default" == "y" ]]; then
        prompt_suffix="[Y/n]"
    fi
    
    if [[ $timeout -gt 0 ]]; then
        prompt_suffix="$prompt_suffix (timeout: ${timeout}s)"
    fi
    
    echo ""
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        echo -n -e "${KCM_COLORS[YELLOW]}$prompt_suffix: ${KCM_COLORS[NC]}"
    else
        echo -n "$prompt_suffix: "
    fi
    
    local answer
    if [[ $timeout -gt 0 ]]; then
        if read -t "$timeout" -r answer; then
            case "$answer" in
                [yY]|[yY][eE][sS])
                    echo ""
                    return 0
                    ;;
                *)
                    echo ""
                    return 1
                    ;;
            esac
        else
            echo ""
            _kcm_warning "Timeout, defaulting to: $default"
            [[ "$default" == "y" ]] && return 0 || return 1
        fi
    else
        if read -r answer; then
            case "$answer" in
                [yY]|[yY][eE][sS])
                    echo ""
                    return 0
                    ;;
                *)
                    echo ""
                    return 1
                    ;;
            esac
        fi
    fi
}

# Status display with icons
_kcm_show_status() {
    local status="$1"
    local message="$2"
    local details="$3"
    
    local icon=""
    local color=""
    
    case "$status" in
        "success"|"healthy"|"ok")
            icon="${KCM_ICONS[success]}"
            color="${KCM_COLORS[GREEN]}"
            ;;
        "warning"|"degraded"|"pending")
            icon="${KCM_ICONS[warning]}"
            color="${KCM_COLORS[YELLOW]}"
            ;;
        "error"|"failed"|"unhealthy"|"critical")
            icon="${KCM_ICONS[error]}"
            color="${KCM_COLORS[RED]}"
            ;;
        "info"|"default"|"unknown")
            icon="${KCM_ICONS[info]}"
            color="${KCM_COLORS[BLUE]}"
            ;;
        "loading"|"processing")
            icon="${KCM_ICONS[loading]}"
            color="${KCM_COLORS[CYAN]}"
            ;;
    esac
    
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" && -n "$color" ]]; then
        echo -e "${color}${icon} $message${KCM_COLORS[NC]}"
    else
        echo "$icon $message"
    fi
    
    if [[ -n "$details" ]]; then
        echo "  $details"
    fi
}

# Table formatting
_kcm_table() {
    local -a headers=("$@")
    local -a rows=()
    local max_widths=()
    local i
    
    # Read rows from stdin
    while IFS= read -r line; do
        rows+=("$line")
    done
    
    # Calculate maximum width for each column
    for ((i=0; i<${#headers[@]}; i++)); do
        local max_width=${#headers[$i]}
        
        for row in "${rows[@]}"; do
            local -a cols
            IFS='|' read -ra cols <<< "$row"
            if [[ ${#cols[@]} -gt $i ]]; then
                local col_width=${#cols[$i]}
                if [[ $col_width -gt $max_width ]]; then
                    max_width=$col_width
                fi
            fi
        done
        
        max_widths+=($max_width)
    done
    
    # Print headers
    local header_line=""
    for ((i=0; i<${#headers[@]}; i++)); do
        local header="${headers[$i]}"
        local width=${max_widths[$i]}
        printf -v header "%-${width}s" "$header"
        header_line+="$header"
        if [[ $i -lt $((${#headers[@]} - 1)) ]]; then
            header_line+=" | "
        fi
    done
    
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        echo -e "${KCM_COLORS[BOLD]}${KCM_COLORS[BLUE]}$header_line${KCM_COLORS[NC]}"
    else
        echo "$header_line"
    fi
    
    # Print separator
    local separator=""
    for ((i=0; i<${#headers[@]}; i++)); do
        local width=${max_widths[$i]}
        separator+=$(printf '%*s' "$width" '' | tr ' ' '-')
        if [[ $i -lt $((${#headers[@]} - 1)) ]]; then
            separator+="-+-"
        fi
    done
    echo "$separator"
    
    # Print rows
    for row in "${rows[@]}"; do
        local -a cols
        IFS='|' read -ra cols <<< "$row"
        local row_line=""
        
        for ((i=0; i<${#headers[@]}; i++)); do
            local col="${cols[$i]:-}"
            local width=${max_widths[$i]}
            printf -v col "%-${width}s" "$col"
            row_line+="$col"
            if [[ $i -lt $((${#headers[@]} - 1)) ]]; then
                row_line+=" | "
            fi
        done
        
        echo "$row_line"
    done
}

# List with icons
_kcm_list() {
    local -a items=("$@")
    local icon_type="${1:-bullet}"
    
    for item in "${items[@]}"; do
        local icon="${KCM_ICONS[$icon_type]:-${KCM_ICONS[bullet]}}"
        echo "$icon $item"
    done
}

# Section header
_kcm_section() {
    local title="$1"
    local icon="${2:-${KCM_ICONS[info]}}"
    
    echo ""
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        echo -e "${KCM_COLORS[BOLD]}${KCM_COLORS[BLUE]}$icon $title${KCM_COLORS[NC]}"
    else
        echo "$icon $title"
    fi
    echo "$(printf '=%.0s' {1..50})"
}

# Subsection header
_kcm_subsection() {
    local title="$1"
    local icon="${2:-${KCM_ICONS[bullet]}}"
    
    echo ""
    echo "$icon $title"
    echo "$(printf '-%.0s' {1..30})"
}

# Highlight important text
_kcm_highlight() {
    local text="$1"
    local color="${2:-YELLOW}"
    
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        echo -e "${KCM_COLORS[$color]}${KCM_COLORS[BOLD]}$text${KCM_COLORS[NC]}"
    else
        echo "$text"
    fi
}

# Show command help with enhanced formatting
_kcm_show_help() {
    local command="$1"
    local description="$2"
    local usage="$3"
    local -a examples=("${@:4}")
    
    echo ""
    _kcm_section "$command" "${KCM_ICONS[rocket]}"
    echo "$description"
    echo ""
    
    _kcm_subsection "Usage"
    echo "$usage"
    echo ""
    
    if [[ ${#examples[@]} -gt 0 ]]; then
        _kcm_subsection "Examples"
        for example in "${examples[@]}"; do
            echo "  $example"
        done
        echo ""
    fi
}

# Animated welcome message
_kcm_welcome() {
    local message="kube-ctx-manager"
    local delay="0.1"
    
    if [[ "$KCM_UI_ANIMATIONS_ENABLED" != "true" ]]; then
        echo "$message"
        return
    fi
    
    echo -n ""
    for ((i=0; i<${#message}; i++)); do
        echo -n "${message:$i:1}"
        sleep "$delay"
    done
    echo ""
}

# Farewell message
_kcm_goodbye() {
    local message="Thank you for using kube-ctx-manager!"
    
    if [[ "$KCM_UI_COLORS_ENABLED" == "true" ]]; then
        echo -e "${KCM_COLORS[GREEN]}${KCM_ICONS[success]} $message${KCM_COLORS[NC]}"
    else
        echo "${KCM_ICONS[success]} $message"
    fi
}

# Initialize UI settings
_kcm_init_ui() {
    # Check if terminal supports colors
    if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
        # Test color support
        if command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
            KCM_UI_COLORS_ENABLED="true"
        fi
    fi
    
    # Disable animations in non-interactive environments
    if [[ ! -t 1 || -n "${CI:-}" ]]; then
        KCM_UI_ANIMATIONS_ENABLED="false"
        KCM_UI_ICONS_ENABLED="false"
    fi
    
    _kcm_log "DEBUG" "UI initialized: colors=$KCM_UI_COLORS_ENABLED, icons=$KCM_UI_ICONS_ENABLED, animations=$KCM_UI_ANIMATIONS_ENABLED"
}

# UI configuration command
kui() {
    local action="$1"
    shift
    
    case "$action" in
        "config")
            echo "UI Configuration:"
            echo "================"
            echo "Colors enabled: $KCM_UI_COLORS_ENABLED"
            echo "Icons enabled: $KCM_UI_ICONS_ENABLED"
            echo "Progress enabled: $KCM_UI_PROGRESS_ENABLED"
            echo "Animations enabled: $KCM_UI_ANIMATIONS_ENABLED"
            ;;
        "test")
            echo "UI Test:"
            echo "======="
            _kcm_success "This is a success message"
            _kcm_error "This is an error message"
            _kcm_warning "This is a warning message"
            _kcm_info "This is an info message"
            echo ""
            _kcm_progress_bar_enhanced 25 100 50 "Test progress"
            echo ""
            _kcm_show_status "success" "Component is healthy"
            _kcm_show_status "warning" "Component needs attention"
            _kcm_show_status "error" "Component failed"
            ;;
        "enable"|"disable")
            local feature="$2"
            if [[ -z "$feature" ]]; then
                echo "Usage: kui $action <feature>"
                echo "Features: colors, icons, progress, animations"
                return 1
            fi
            
            local var_name="KCM_UI_${feature^^}_ENABLED"
            if [[ "$action" == "enable" ]]; then
                export "$var_name"="true"
                _kcm_success "Enabled $feature"
            else
                export "$var_name"="false"
                _kcm_success "Disabled $feature"
            fi
            ;;
        *)
            echo "Usage: kui <action> [options]"
            echo ""
            echo "Actions:"
            echo "  config    - Show current UI configuration"
            echo "  test      - Test UI components"
            echo "  enable    - Enable a UI feature"
            echo "  disable   - Disable a UI feature"
            echo ""
            echo "Features: colors, icons, progress, animations"
            ;;
    esac
}

# Initialize UI when sourced
_kcm_init_ui
