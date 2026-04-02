#!/usr/bin/env bash

# health.sh - Context health checking and monitoring

# Health check cache file
export KCM_HEALTH_CACHE="$HOME/.kube-health-cache"
export KCM_HEALTH_CACHE_TTL=300  # 5 minutes

# Check if context is healthy/accessible
_kcm_check_context_health() {
    local context="$1"
    local timeout="${2:-10}"
    local use_cache="${3:-1}"
    
    # Check cache first
    if [[ "$use_cache" == "1" ]]; then
        local cache_entry
        cache_entry=$(grep "^${context}:" "$KCM_HEALTH_CACHE" 2>/dev/null | tail -1)
        
        if [[ -n "$cache_entry" ]]; then
            local cache_time
            cache_time=$(echo "$cache_entry" | cut -d: -f2)
            local cache_status
            cache_status=$(echo "$cache_entry" | cut -d: -f3)
            local current_time
            current_time=$(date +%s)
            
            if [[ $((current_time - cache_time)) -lt $KCM_HEALTH_CACHE_TTL ]]; then
                echo "$cache_status"
                return 0
            fi
        fi
    fi
    
    # Perform health check
    local start_time
    start_time=$(date +%s)
    
    if timeout "$timeout" kubectl --context="$context" cluster-info >/dev/null 2>&1; then
        local end_time
        end_time=$(date +%s)
        local response_time=$((end_time - start_time))
        
        # Cache the result
        echo "${context}:$(date +%s):healthy:${response_time}" >> "$KCM_HEALTH_CACHE"
        echo "healthy:${response_time}"
        return 0
    else
        # Cache the failure
        echo "${context}:$(date +%s):unhealthy:0" >> "$KCM_HEALTH_CACHE"
        echo "unhealthy:0"
        return 1
    fi
}

# Get detailed health information for a context
_kcm_get_context_details() {
    local context="$1"
    
    echo "Context: $context"
    echo "-------------------"
    
    # Basic cluster info
    echo "Cluster Info:"
    kubectl --context="$context" cluster-info 2>/dev/null || echo "  ❌ Unable to connect"
    
    # Server version
    echo ""
    echo "Server Version:"
    kubectl --context="$context" version --short 2>/dev/null | head -1 || echo "  ❌ Version check failed"
    
    # Node status
    echo ""
    echo "Node Status:"
    local node_count
    node_count=$(kubectl --context="$context" get nodes --no-headers 2>/dev/null | wc -l)
    if [[ "$node_count" -gt 0 ]]; then
        echo "  Total nodes: $node_count"
        local ready_nodes
        ready_nodes=$(kubectl --context="$context" get nodes --no-headers 2>/dev/null | grep -c "Ready")
        echo "  Ready nodes: $ready_nodes"
    else
        echo "  ❌ Unable to get node information"
    fi
    
    # Namespace count
    echo ""
    echo "Namespaces:"
    local ns_count
    ns_count=$(kubectl --context="$context" get namespaces --no-headers 2>/dev/null | wc -l)
    echo "  Total namespaces: $ns_count"
    
    # Recent activity (if audit log exists)
    if [[ -f "$KCM_AUDIT_LOG" ]]; then
        echo ""
        echo "Recent Activity (last 24h):"
        local recent_count
        recent_count=$(grep "$(date '+%Y-%m-%d')" "$KCM_AUDIT_LOG" 2>/dev/null | grep "context=$context" | wc -l)
        echo "  Commands executed: $recent_count"
    fi
}

# Health check all contexts
khealth() {
    local context_filter="$1"
    local detailed="$2"
    
    echo "Checking Kubernetes context health..."
    echo ""
    
    local contexts
    if [[ -n "$context_filter" ]]; then
        contexts=$(kubectl config get-contexts -o name | grep "$context_filter" | sed 's/^.*\///')
    else
        contexts=$(kubectl config get-contexts -o name | sed 's/^.*\///')
    fi
    
    if [[ -z "$contexts" ]]; then
        echo "No contexts found"
        return 1
    fi
    
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null)
    
    echo "Context Health Status:"
    echo "====================="
    
    for context in $contexts; do
        local health_result
        health_result=$(_kcm_check_context_health "$context")
        local status
        status=$(echo "$health_result" | cut -d: -f1)
        local response_time
        response_time=$(echo "$health_result" | cut -d: -f2)
        
        local status_icon="❌"
        local status_color=""
        
        if [[ "$status" == "healthy" ]]; then
            status_icon="✅"
            if [[ "$response_time" -lt 5 ]]; then
                status_color="🟢"
            elif [[ "$response_time" -lt 10 ]]; then
                status_color="🟡"
            else
                status_color="🟠"
            fi
        fi
        
        local current_marker=""
        if [[ "$context" == "$current_context" ]]; then
            current_marker=" (current)"
        fi
        
        printf "%s %s %s %s%s (%ds)\n" "$status_icon" "$status_color" "$context" "$current_marker" "" "$response_time"
        
        if [[ "$detailed" == "--detailed" && "$status" == "healthy" ]]; then
            echo ""
            _kcm_get_context_details "$context"
            echo ""
        fi
    done
    
    echo ""
    echo "Legend: ✅ Healthy | ❌ Unhealthy | 🟢 Fast (<5s) | 🟡 Medium (5-10s) | 🟠 Slow (>10s)"
}

# Quick health check for current context
khealth-quick() {
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null)
    
    if [[ -z "$current_context" ]]; then
        echo "No current context set"
        return 1
    fi
    
    echo "Quick health check for: $current_context"
    
    local health_result
    health_result=$(_kcm_check_context_health "$current_context" 5 0)  # No cache, 5s timeout
    local status
    status=$(echo "$health_result" | cut -d: -f1)
    local response_time
    response_time=$(echo "$health_result" | cut -d: -f2)
    
    if [[ "$status" == "healthy" ]]; then
        echo "✅ Healthy (${response_time}s)"
        return 0
    else
        echo "❌ Unhealthy"
        return 1
    fi
}

# Monitor context health continuously
khealth-watch() {
    local context="${1:-$(kubectl config current-context 2>/dev/null)}"
    local interval="${2:-30}"
    
    if [[ -z "$context" ]]; then
        echo "No context specified and no current context found"
        return 1
    fi
    
    echo "Monitoring context: $context (interval: ${interval}s)"
    echo "Press Ctrl+C to stop"
    echo ""
    
    while true; do
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        local health_result
        health_result=$(_kcm_check_context_health "$context" 10 0)  # No cache
        local status
        status=$(echo "$health_result" | cut -d: -f1)
        local response_time
        response_time=$(echo "$health_result" | cut -d: -f2)
        
        printf "[%s] %s - %s (%ds)\n" "$timestamp" "$context" "$status" "$response_time"
        
        sleep "$interval"
    done
}

# Clean health cache
khealth-clean() {
    echo "Cleaning health cache..."
    rm -f "$KCM_HEALTH_CACHE"
    echo "✓ Cache cleared"
}

# Show health cache statistics
khealth-stats() {
    if [[ ! -f "$KCM_HEALTH_CACHE" ]]; then
        echo "No health cache found"
        return 1
    fi
    
    echo "Health Cache Statistics:"
    echo "======================"
    
    local total_entries
    total_entries=$(wc -l < "$KCM_HEALTH_CACHE")
    echo "Total entries: $total_entries"
    
    local healthy_count
    healthy_count=$(grep -c ":healthy:" "$KCM_HEALTH_CACHE")
    echo "Healthy entries: $healthy_count"
    
    local unhealthy_count
    unhealthy_count=$(grep -c ":unhealthy:" "$KCM_HEALTH_CACHE")
    echo "Unhealthy entries: $unhealthy_count"
    
    echo ""
    echo "Recent cache entries (last 10):"
    tail -10 "$KCM_HEALTH_CACHE" | while IFS=: read -r context timestamp status response_time; do
        local time_str
        time_str=$(date -d "@$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -r "$timestamp" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        printf "%s - %s: %s (%ds)\n" "$time_str" "$context" "$status" "$response_time"
    done
}
