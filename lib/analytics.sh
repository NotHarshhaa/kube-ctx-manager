#!/usr/bin/env bash

# analytics.sh - Command history and analytics functionality

# Analytics data files
export KCM_ANALYTICS_DIR="$HOME/.kube-analytics"
export KCM_COMMAND_HISTORY="$KCM_ANALYTICS_DIR/command_history.log"
export KCM_CONTEXT_STATS="$KCM_ANALYTICS_DIR/context_stats.json"
export KCM_ANALYTICS_REPORT="$KCM_ANALYTICS_DIR/reports"

# Initialize analytics
_kcm_init_analytics() {
    mkdir -p "$KCM_ANALYTICS_DIR"
    mkdir -p "$KCM_ANALYTICS_REPORT"
    
    # Create command history file if it doesn't exist
    if [[ ! -f "$KCM_COMMAND_HISTORY" ]]; then
        echo "# kube-ctx-manager command history" > "$KCM_COMMAND_HISTORY"
        echo "# Format: timestamp:context:namespace:command:duration:exit_code" >> "$KCM_COMMAND_HISTORY"
    fi
}

# Log command execution
_kcm_log_command() {
    local context="$1"
    local namespace="$2"
    local command="$3"
    local duration="$4"
    local exit_code="$5"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "${timestamp}:${context}:${namespace}:${command}:${duration}:${exit_code}" >> "$KCM_COMMAND_HISTORY"
}

# Get command statistics
kanalytics-stats() {
    local days="${1:-30}"
    local context_filter="$2"
    
    _kcm_init_analytics
    
    if [[ ! -f "$KCM_COMMAND_HISTORY" ]]; then
        echo "No command history found"
        return 1
    fi
    
    echo "Command Analytics (Last $days days)"
    echo "=================================="
    
    if [[ -n "$context_filter" ]]; then
        echo "Context filter: $context_filter"
        echo ""
    fi
    
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" '+%Y-%m-%d' 2>/dev/null || date -v-${days}d '+%Y-%m-%d' 2>/dev/null)
    
    # Filter commands by date and context
    local filtered_commands
    filtered_commands=$(grep "^\\[" "$KCM_COMMAND_HISTORY" | while read -r line; do
        local cmd_date
        cmd_date=$(echo "$line" | cut -d: -f1 | cut -d' ' -f1)
        local cmd_context
        cmd_context=$(echo "$line" | cut -d: -f2)
        
        if [[ "$cmd_date" > "$cutoff_date" ]]; then
            if [[ -z "$context_filter" || "$cmd_context" =~ $context_filter ]]; then
                echo "$line"
            fi
        fi
    done)
    
    if [[ -z "$filtered_commands" ]]; then
        echo "No commands found in the specified period"
        return 0
    fi
    
    # Total commands
    local total_commands
    total_commands=$(echo "$filtered_commands" | wc -l)
    echo "Total commands: $total_commands"
    
    # Commands by context
    echo ""
    echo "Commands by context:"
    echo "$filtered_commands" | cut -d: -f2 | sort | uniq -c | sort -nr | head -10
    
    # Commands by type
    echo ""
    echo "Commands by type:"
    echo "$filtered_commands" | cut -d: -f4 | awk '{print $1}' | sort | uniq -c | sort -nr | head -10
    
    # Most frequent full commands
    echo ""
    echo "Most frequent commands:"
    echo "$filtered_commands" | cut -d: -f4 | sort | uniq -c | sort -nr | head -10
    
    # Success rate
    echo ""
    echo "Success rate:"
    local successful_commands
    successful_commands=$(echo "$filtered_commands" | cut -d: -f6 | grep -c "0")
    local success_rate
    success_rate=$((successful_commands * 100 / total_commands))
    echo "Successful: $successful_commands/$total_commands ($success_rate%)"
    
    # Average duration
    echo ""
    echo "Performance:"
    local total_duration
    total_duration=$(echo "$filtered_commands" | cut -d: -f5 | awk '{sum+=$1} END {print sum}')
    local avg_duration
    avg_duration=$(echo "$total_duration $total_commands" | awk '{printf "%.2f", $1/$2}')
    echo "Average duration: ${avg_duration}s"
    
    # Daily activity
    echo ""
    echo "Daily activity:"
    echo "$filtered_commands" | cut -d: -f1 | cut -d' ' -f1 | sort | uniq -c | sort -nr | head -7
}

# Show command timeline
kanalytics-timeline() {
    local hours="${1:-24}"
    local context_filter="$2"
    
    _kcm_init_analytics
    
    if [[ ! -f "$KCM_COMMAND_HISTORY" ]]; then
        echo "No command history found"
        return 1
    fi
    
    echo "Command Timeline (Last $hours hours)"
    echo "==================================="
    
    local cutoff_time
    cutoff_time=$(date -d "$hours hours ago" '+%Y-%m-%d %H:' 2>/dev/null || date -v-${hours}H '+%Y-%m-%d %H:' 2>/dev/null)
    
    grep "^\\[" "$KCM_COMMAND_HISTORY" | while read -r line; do
        local timestamp
        timestamp=$(echo "$line" | cut -d: -f1-2 | tr ':' ' ')
        local context
        context=$(echo "$line" | cut -d: -f3)
        local command
        command=$(echo "$line" | cut -d: -f5)
        local exit_code
        exit_code=$(echo "$line" | cut -d: -f7)
        
        if [[ "$timestamp" > "$cutoff_time" ]]; then
            if [[ -z "$context_filter" || "$context" =~ $context_filter ]]; then
                local status_icon="✅"
                [[ "$exit_code" != "0" ]] && status_icon="❌"
                
                printf "%-20s %-15s %s %s\n" "$(echo "$line" | cut -d: -f1-2)" "$context" "$status_icon" "$command"
            fi
        fi
    done
}

# Generate analytics report
kanalytics-report() {
    local report_type="${1:-summary}"
    local output_file="$2"
    local days="${3:-30}"
    
    _kcm_init_analytics
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local report_file
    if [[ -n "$output_file" ]]; then
        report_file="$output_file"
    else
        report_file="$KCM_ANALYTICS_REPORT/report_${report_type}_${timestamp}.txt"
    fi
    
    echo "Generating $report_type report..."
    
    case "$report_type" in
        "summary")
            _kcm_generate_summary_report "$report_file" "$days"
            ;;
        "detailed")
            _kcm_generate_detailed_report "$report_file" "$days"
            ;;
        "context")
            _kcm_generate_context_report "$report_file" "$days"
            ;;
        "performance")
            _kcm_generate_performance_report "$report_file" "$days"
            ;;
        *)
            echo "Unknown report type: $report_type"
            echo "Available types: summary, detailed, context, performance"
            return 1
            ;;
    esac
    
    echo "✓ Report generated: $report_file"
}

# Generate summary report
_kcm_generate_summary_report() {
    local report_file="$1"
    local days="$2"
    
    cat > "$report_file" << EOF
kube-ctx-manager Analytics Summary Report
==========================================
Generated: $(date)
Period: Last $days days

EOF
    
    # Add statistics
    kanalytics-stats "$days" >> "$report_file"
    
    # Add top contexts
    echo "" >> "$report_file"
    echo "Top Contexts:" >> "$report_file"
    echo "============" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f2 | sort | uniq -c | sort -nr | head -5 >> "$report_file"
    
    # Add recommendations
    echo "" >> "$report_file"
    echo "Recommendations:" >> "$report_file"
    echo "================" >> "$report_file"
    
    # Analyze patterns and provide recommendations
    local most_used_context
    most_used_context=$(grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f2 | sort | uniq -c | sort -nr | head -1 | awk '{print $2}')
    echo "- Most used context: $most_used_context" >> "$report_file"
    echo "- Consider bookmarking frequently used contexts for quick access" >> "$report_file"
    echo "- Set up aliases for frequently used commands" >> "$report_file"
}

# Generate detailed report
_kcm_generate_detailed_report() {
    local report_file="$1"
    local days="$2"
    
    cat > "$report_file" << EOF
kube-ctx-manager Detailed Analytics Report
=========================================
Generated: $(date)
Period: Last $days days

EOF
    
    # Command frequency analysis
    echo "Command Frequency Analysis:" >> "$report_file"
    echo "===========================" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f5 | sort | uniq -c | sort -nr >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Context Usage Patterns:" >> "$report_file"
    echo "=======================" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f2 | sort | uniq -c | sort -nr >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Namespace Usage:" >> "$report_file"
    echo "===============" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f4 | grep -o '\-n [^[:space:]]*' | sort | uniq -c | sort -nr >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Error Analysis:" >> "$report_file"
    echo "===============" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f7 | grep -v "0" | wc -l | xargs echo "Failed commands:" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f7 | grep -v "0" | cut -d: -f5 | sort | uniq -c | sort -nr | head -10 >> "$report_file"
}

# Generate context-specific report
_kcm_generate_context_report() {
    local report_file="$1"
    local days="$2"
    
    cat > "$report_file" << EOF
kube-ctx-manager Context Analytics Report
=========================================
Generated: $(date)
Period: Last $days days

EOF
    
    # Get all contexts
    local contexts
    contexts=$(grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f2 | sort -u)
    
    for context in $contexts; do
        echo "Context: $context" >> "$report_file"
        echo "-----------" >> "$report_file"
        
        local context_commands
        context_commands=$(grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f2 | grep "^$context$" | wc -l)
        echo "Commands executed: $context_commands" >> "$report_file"
        
        echo "Top commands:" >> "$report_file"
        grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f2 | grep "^$context$" | cut -d: -f4 | sort | uniq -c | sort -nr | head -5 >> "$report_file"
        
        echo "" >> "$report_file"
    done
}

# Generate performance report
_kcm_generate_performance_report() {
    local report_file="$1"
    local days="$2"
    
    cat > "$report_file" << EOF
kube-ctx-manager Performance Report
===================================
Generated: $(date)
Period: Last $days days

EOF
    
    echo "Command Performance Analysis:" >> "$report_file"
    echo "=============================" >> "$report_file"
    
    # Slow commands
    echo "Slowest commands (>10s):" >> "$report_file"
    grep "^\\[" "$KCM_COMMAND_HISTORY" | awk -F: '$5 > 10 {print $0}' | sort -t: -k5 -nr | head -10 >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Average command duration by type:" >> "$report_file"
    echo "====================================" >> "$report_file"
    
    # Group by command type and calculate averages
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f4,5 | awk -F: '
    {
        cmd = $1;
        dur = $2;
        count[cmd]++;
        total[cmd] += dur;
    }
    END {
        for (c in count) {
            avg = total[c] / count[c];
            printf "%-20s %.2fs (%d commands)\n", c, avg, count[c];
        }
    }' | sort -k2 -nr >> "$report_file"
}

# Export analytics data
kanalytics-export() {
    local format="${1:-csv}"
    local output_file="$2"
    local days="${3:-30}"
    
    _kcm_init_analytics
    
    if [[ -z "$output_file" ]]; then
        output_file="$KCM_ANALYTICS_DIR/export_$(date +%Y%m%d_%H%M%S).$format"
    fi
    
    echo "Exporting analytics data to $output_file..."
    
    case "$format" in
        "csv")
            echo "timestamp,context,namespace,command,duration,exit_code" > "$output_file"
            grep "^\\[" "$KCM_COMMAND_HISTORY" | tr ':' ',' >> "$output_file"
            ;;
        "json")
            if command -v jq >/dev/null 2>&1; then
                grep "^\\[" "$KCM_COMMAND_HISTORY" | while IFS=: read -r timestamp context namespace command duration exit_code; do
                    echo "{\"timestamp\":\"$timestamp\",\"context\":\"$context\",\"namespace\":\"$namespace\",\"command\":\"$command\",\"duration\":$duration,\"exit_code\":$exit_code}"
                done | jq -s '.' > "$output_file"
            else
                echo "jq required for JSON export"
                return 1
            fi
            ;;
        *)
            echo "Unsupported format: $format (use csv, json)"
            return 1
            ;;
    esac
    
    echo "✓ Data exported to: $output_file"
}

# Clean old analytics data
kanalytics-clean() {
    local days="${1:-90}"
    
    _kcm_init_analytics
    
    echo "Cleaning analytics data older than $days days..."
    
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" '+%Y-%m-%d' 2>/dev/null || date -v-${days}d '+%Y-%m-%d' 2>/dev/null)
    
    local temp_file
    temp_file=$(mktemp)
    
    # Keep recent entries
    grep "^\\[" "$KCM_COMMAND_HISTORY" | while read -r line; do
        local cmd_date
        cmd_date=$(echo "$line" | cut -d: -f1 | cut -d' ' -f1)
        if [[ "$cmd_date" > "$cutoff_date" ]]; then
            echo "$line"
        fi
    done > "$temp_file"
    
    # Preserve header
    head -2 "$KCM_COMMAND_HISTORY" > "$KCM_COMMAND_HISTORY"
    cat "$temp_file" >> "$KCM_COMMAND_HISTORY"
    rm -f "$temp_file"
    
    echo "✓ Old analytics data cleaned"
}

# Show command suggestions based on analytics
kanalytics-suggest() {
    local min_frequency="${1:-5}"
    
    _kcm_init_analytics
    
    if [[ ! -f "$KCM_COMMAND_HISTORY" ]]; then
        echo "No command history found"
        return 1
    fi
    
    echo "Command Suggestions (based on usage >= $min_frequency times)"
    echo "=========================================================="
    
    # Find frequently used commands that don't have aliases
    grep "^\\[" "$KCM_COMMAND_HISTORY" | cut -d: -f5 | sort | uniq -c | sort -nr | while read -r count command; do
        if [[ $count -ge $min_frequency ]]; then
            # Check if alias already exists
            local alias_name
            alias_name=$(_kcm_generate_alias_name "$command")
            
            if ! alias | grep -q "^alias $alias_name="; then
                echo "Used $count times:"
                echo "  $command"
                echo "Suggested alias:"
                echo "  alias $alias_name='$command'"
                echo ""
            fi
        fi
    done
}
