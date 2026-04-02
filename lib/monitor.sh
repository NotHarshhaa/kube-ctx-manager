#!/usr/bin/env bash

# monitor.sh - Cluster resource monitoring and metrics

# Monitoring cache
export KCM_MONITOR_CACHE="$HOME/.kube-monitor-cache"
export KCM_MONITOR_CACHE_TTL=60  # 1 minute

# Get cluster resource summary
_kcm_get_cluster_resources() {
    local context="$1"
    local namespace="${2:-all}"
    local use_cache="${3:-1}"
    
    local cache_key="${context}:${namespace}"
    local cache_file="$KCM_MONITOR_CACHE/${cache_key}"
    
    # Check cache first
    if [[ "$use_cache" == "1" && -f "$cache_file" ]]; then
        local cache_time
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        local current_time
        current_time=$(date +%s)
        
        if [[ $((current_time - cache_time)) -lt $KCM_MONITOR_CACHE_TTL ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    # Fetch fresh data
    mkdir -p "$KCM_MONITOR_CACHE"
    
    local output=""
    local kubectl_cmd="kubectl --context=$context"
    
    if [[ "$namespace" != "all" ]]; then
        kubectl_cmd="$kubectl_cmd --namespace=$namespace"
    fi
    
    # Get node information
    local node_info
    node_info=$($kubectl_cmd get nodes --no-headers 2>/dev/null)
    if [[ -n "$node_info" ]]; then
        local total_nodes
        total_nodes=$(echo "$node_info" | wc -l)
        local ready_nodes
        ready_nodes=$(echo "$node_info" | grep -c "Ready")
        output="${output}nodes_total:$total_nodes\n"
        output="${output}nodes_ready:$ready_nodes\n"
    fi
    
    # Get pod information
    local pod_info
    pod_info=$($kubectl_cmd get pods --no-headers 2>/dev/null)
    if [[ -n "$pod_info" ]]; then
        local total_pods
        total_pods=$(echo "$pod_info" | wc -l)
        local running_pods
        running_pods=$(echo "$pod_info" | grep -c "Running")
        local pending_pods
        pending_pods=$(echo "$pod_info" | grep -c "Pending")
        local failed_pods
        failed_pods=$(echo "$pod_info" | grep -c -E "(Failed|Error|CrashLoopBackOff)")
        
        output="${output}pods_total:$total_pods\n"
        output="${output}pods_running:$running_pods\n"
        output="${output}pods_pending:$pending_pods\n"
        output="${output}pods_failed:$failed_pods\n"
    fi
    
    # Get namespace count (if not scoped to specific namespace)
    if [[ "$namespace" == "all" ]]; then
        local ns_count
        ns_count=$($kubectl_cmd get namespaces --no-headers 2>/dev/null | wc -l)
        output="${output}namespaces_total:$ns_count\n"
    fi
    
    # Get service count
    local svc_count
    svc_count=$($kubectl_cmd get services --no-headers 2>/dev/null | wc -l)
    output="${output}services_total:$svc_count\n"
    
    # Get deployment count
    local deploy_count
    deploy_count=$($kubectl_cmd get deployments --no-headers 2>/dev/null | wc -l)
    output="${output}deployments_total:$deploy_count\n"
    
    # Cache the result
    echo -e "$output" > "$cache_file"
    echo -e "$output"
}

# Show cluster overview
kmonitor() {
    local context="${1:-$(kubectl config current-context 2>/dev/null)}"
    local namespace="${2:-all}"
    
    if [[ -z "$context" ]]; then
        echo "No context specified and no current context found"
        return 1
    fi
    
    echo "Cluster Overview: $context"
    echo "=========================="
    
    if [[ "$namespace" != "all" ]]; then
        echo "Namespace: $namespace"
    fi
    echo ""
    
    # Get resource information
    local resources
    resources=$(_kcm_get_cluster_resources "$context" "$namespace")
    
    if [[ -z "$resources" ]]; then
        echo "❌ Unable to connect to cluster"
        return 1
    fi
    
    echo "Resources:"
    echo "----------"
    
    # Parse and display resources
    while IFS=: read -r metric value; do
        case "$metric" in
            "nodes_total")
                echo "Nodes: $value"
                ;;
            "nodes_ready")
                local total_nodes
                total_nodes=$(echo "$resources" | grep "nodes_total:" | cut -d: -f2)
                local percentage
                percentage=$((value * 100 / total_nodes))
                echo "  Ready: $value/$total_nodes ($percentage%)"
                ;;
            "pods_total")
                echo "Pods: $value"
                ;;
            "pods_running")
                echo "  Running: $value"
                ;;
            "pods_pending")
                if [[ $value -gt 0 ]]; then
                    echo "  Pending: $value ⚠️"
                fi
                ;;
            "pods_failed")
                if [[ $value -gt 0 ]]; then
                    echo "  Failed: $value ❌"
                fi
                ;;
            "namespaces_total")
                echo "Namespaces: $value"
                ;;
            "services_total")
                echo "Services: $value"
                ;;
            "deployments_total")
                echo "Deployments: $value"
                ;;
        esac
    done <<< "$resources"
    
    echo ""
    
    # Show cluster version
    echo "Cluster Info:"
    echo "-------------"
    kubectl --context="$context" version --short 2>/dev/null | head -1
    
    echo ""
    
    # Show top resource consumers
    echo "Top Resource Consumers:"
    echo "--------------------"
    
    local kubectl_cmd="kubectl --context=$context"
    if [[ "$namespace" != "all" ]]; then
        kubectl_cmd="$kubectl_cmd --namespace=$namespace"
    fi
    
    # Top pods by CPU
    echo "Top Pods by CPU:"
    $kubectl_cmd top pods --sort-by=cpu --no-headers 2>/dev/null | head -3 | while read -r line; do
        local pod_name
        pod_name=$(echo "$line" | awk '{print $1}')
        local cpu
        cpu=$(echo "$line" | awk '{print $2}')
        local memory
        memory=$(echo "$line" | awk '{print $3}')
        printf "  %-30s %8s %8s\n" "$pod_name" "$cpu" "$memory"
    done || echo "  Metrics server not available"
    
    echo ""
    
    # Show recent events
    echo "Recent Events (last 5):"
    echo "-----------------------"
    $kubectl_cmd get events --sort-by='.lastTimestamp' --no-headers 2>/dev/null | tail -5 | while read -r line; do
        local event_type
        event_type=$(echo "$line" | awk '{print $2}')
        local reason
        reason=$(echo "$line" | awk '{print $3}')
        local object
        object=$(echo "$line" | awk '{print $4}')
        local message
        message=$(echo "$line" | cut -d' ' -f5-)
        
        local icon="ℹ️"
        case "$event_type" in
            "Warning") icon="⚠️" ;;
            "Normal") icon="✅" ;;
        esac
        
        printf "%s %-10s %-20s %s\n" "$icon" "$reason" "$object" "$message"
    done || echo "  No events found"
}

# Monitor specific resource type
kmonitor-resource() {
    local resource_type="$1"
    local context="${2:-$(kubectl config current-context 2>/dev/null)}"
    local namespace="${3:-default}"
    
    if [[ -z "$resource_type" ]]; then
        echo "Usage: kmonitor-resource <resource-type> [context] [namespace]"
        echo "Resource types: pods, nodes, services, deployments, configmaps, secrets"
        return 1
    fi
    
    echo "Monitoring $resource_type in $context/$namespace"
    echo "============================================="
    
    local kubectl_cmd="kubectl --context=$context --namespace=$namespace"
    
    case "$resource_type" in
        "pods")
            echo "Pod Status Summary:"
            $kubectl_cmd get pods --no-headers | awk '{status[$2]++} END {for (s in status) printf "  %s: %d\n", s, status[s]}'
            echo ""
            echo "Pod Details:"
            $kubectl_cmd get pods
            ;;
        "nodes")
            echo "Node Status Summary:"
            kubectl --context="$context" get nodes --no-headers | awk '{status[$2]++} END {for (s in status) printf "  %s: %d\n", s, status[s]}'
            echo ""
            echo "Node Details:"
            kubectl --context="$context" get nodes
            ;;
        "services")
            echo "Service Details:"
            $kubectl_cmd get services
            ;;
        "deployments")
            echo "Deployment Status:"
            $kubectl_cmd get deployments
            echo ""
            echo "Replica Sets:"
            $kubectl_cmd get replicasets
            ;;
        "configmaps")
            echo "ConfigMaps:"
            $kubectl_cmd get configmaps
            ;;
        "secrets")
            echo "Secrets:"
            $kubectl_cmd get secrets --field-selector type!=kubernetes.io/service-account-token
            ;;
        *)
            echo "Unknown resource type: $resource_type"
            return 1
            ;;
    esac
}

# Watch resources in real-time
kmonitor-watch() {
    local resource_type="${1:-pods}"
    local context="${2:-$(kubectl config current-context 2>/dev/null)}"
    local namespace="${3:-default}"
    local interval="${4:-5}"
    
    if [[ -z "$context" ]]; then
        echo "No context specified and no current context found"
        return 1
    fi
    
    echo "Watching $resource_type in $context/$namespace (interval: ${interval}s)"
    echo "Press Ctrl+C to stop"
    echo ""
    
    local kubectl_cmd="kubectl --context=$context --namespace=$namespace"
    
    while true; do
        clear
        echo "Watching $resource_type in $context/$namespace"
        echo "Last updated: $(date)"
        echo "=========================================="
        
        case "$resource_type" in
            "pods")
                $kubectl_cmd get pods
                ;;
            "nodes")
                kubectl --context="$context" get nodes
                ;;
            "services")
                $kubectl_cmd get services
                ;;
            "deployments")
                $kubectl_cmd get deployments
                ;;
            *)
                echo "Unknown resource type: $resource_type"
                return 1
                ;;
        esac
        
        sleep "$interval"
    done
}

# Show resource usage metrics
kmonitor-metrics() {
    local context="${1:-$(kubectl config current-context 2>/dev/null)}"
    local namespace="${2:-default}"
    
    if [[ -z "$context" ]]; then
        echo "No context specified and no current context found"
        return 1
    fi
    
    echo "Resource Metrics: $context/$namespace"
    echo "===================================="
    
    local kubectl_cmd="kubectl --context=$context --namespace=$namespace"
    
    # Node metrics
    echo "Node Resource Usage:"
    echo "-------------------"
    $kubectl_cmd top nodes 2>/dev/null || echo "  Metrics server not available"
    
    echo ""
    
    # Pod metrics
    echo "Pod Resource Usage:"
    echo "------------------"
    $kubectl_cmd top pods 2>/dev/null || echo "  Metrics server not available"
    
    echo ""
    
    # Resource requests and limits
    echo "Resource Requests & Limits:"
    echo "---------------------------"
    
    # Calculate total requests and limits
    local cpu_requests
    local cpu_limits
    local memory_requests
    local memory_limits
    
    if command -v jq >/dev/null 2>&1; then
        cpu_requests=$($kubectl_cmd get pods -o json 2>/dev/null | jq '.items[] | .spec.containers[] | .resources.requests.cpu // "0" | select(. != null)' | sed 's/m//' | awk '{sum+=$1} END {print sum "m"}')
        cpu_limits=$($kubectl_cmd get pods -o json 2>/dev/null | jq '.items[] | .spec.containers[] | .resources.limits.cpu // "0" | select(. != null)' | sed 's/m//' | awk '{sum+=$1} END {print sum "m"}')
        
        memory_requests=$($kubectl_cmd get pods -o json 2>/dev/null | jq '.items[] | .spec.containers[] | .resources.requests.memory // "0" | select(. != null)' | sed 's/Mi//g' | sed 's/Gi//g' | awk '{sum+=$1} END {print sum "Mi"}')
        memory_limits=$($kubectl_cmd get pods -o json 2>/dev/null | jq '.items[] | .spec.containers[] | .resources.limits.memory // "0" | select(. != null)' | sed 's/Mi//g' | sed 's/Gi//g' | awk '{sum+=$1} END {print sum "Mi"}')
        
        echo "CPU Requests: $cpu_requests"
        echo "CPU Limits: $cpu_limits"
        echo "Memory Requests: $memory_requests"
        echo "Memory Limits: $memory_limits"
    else
        echo "Install jq for detailed resource analysis"
    fi
}

# Cluster health check
kmonitor-health() {
    local context="${1:-$(kubectl config current-context 2>/dev/null)}"
    
    if [[ -z "$context" ]]; then
        echo "No context specified and no current context found"
        return 1
    fi
    
    echo "Cluster Health Check: $context"
    echo "==========================="
    
    local health_score=0
    local max_score=100
    
    # 1. Cluster connectivity (30 points)
    echo "1. Cluster Connectivity:"
    if kubectl --context="$context" cluster-info >/dev/null 2>&1; then
        echo "   ✅ Connected (30/30)"
        ((health_score += 30))
    else
        echo "   ❌ Not connected (0/30)"
    fi
    
    # 2. Node health (25 points)
    echo ""
    echo "2. Node Health:"
    local node_info
    node_info=$(kubectl --context="$context" get nodes --no-headers 2>/dev/null)
    if [[ -n "$node_info" ]]; then
        local total_nodes
        total_nodes=$(echo "$node_info" | wc -l)
        local ready_nodes
        ready_nodes=$(echo "$node_info" | grep -c "Ready")
        local node_percentage
        node_percentage=$((ready_nodes * 25 / total_nodes))
        
        echo "   Ready nodes: $ready_nodes/$total_nodes"
        echo "   Score: $node_percentage/25"
        ((health_score += node_percentage))
    else
        echo "   ❌ Unable to get node info (0/25)"
    fi
    
    # 3. Pod health (25 points)
    echo ""
    echo "3. Pod Health:"
    local pod_info
    pod_info=$(kubectl --context="$context" get pods --all-namespaces --no-headers 2>/dev/null)
    if [[ -n "$pod_info" ]]; then
        local total_pods
        total_pods=$(echo "$pod_info" | wc -l)
        local healthy_pods
        healthy_pods=$(echo "$pod_info" | grep -c -E "(Running|Succeeded)")
        local pod_percentage
        pod_percentage=$((healthy_pods * 25 / total_pods))
        
        echo "   Healthy pods: $healthy_pods/$total_pods"
        echo "   Score: $pod_percentage/25"
        ((health_score += pod_percentage))
    else
        echo "   ❌ Unable to get pod info (0/25)"
    fi
    
    # 4. System pods (20 points)
    echo ""
    echo "4. System Pods:"
    local system_pods
    system_pods=$(kubectl --context="$context" get pods --namespace=kube-system --no-headers 2>/dev/null)
    if [[ -n "$system_pods" ]]; then
        local total_system_pods
        total_system_pods=$(echo "$system_pods" | wc -l)
        local healthy_system_pods
        healthy_system_pods=$(echo "$system_pods" | grep -c -E "(Running|Succeeded)")
        local system_percentage
        system_percentage=$((healthy_system_pods * 20 / total_system_pods))
        
        echo "   Healthy system pods: $healthy_system_pods/$total_system_pods"
        echo "   Score: $system_percentage/20"
        ((health_score += system_percentage))
    else
        echo "   ❌ Unable to get system pod info (0/20)"
    fi
    
    # Overall health
    echo ""
    echo "Overall Health Score: $health_score/$max_score"
    
    local health_status="🟢"
    local health_text="Healthy"
    
    if [[ $health_score -lt 50 ]]; then
        health_status="🔴"
        health_text="Unhealthy"
    elif [[ $health_score -lt 75 ]]; then
        health_status="🟡"
        health_text="Degraded"
    fi
    
    echo "Status: $health_status $health_text"
    
    # Recommendations
    echo ""
    echo "Recommendations:"
    if [[ $health_score -lt 75 ]]; then
        echo "- Check node status and resource utilization"
        echo "- Review pod logs for failing pods"
        echo "- Verify system components are running"
    else
        echo "- Cluster appears healthy"
        echo "- Continue monitoring resource usage"
    fi
}

# Clean monitoring cache
kmonitor-clean() {
    echo "Cleaning monitoring cache..."
    rm -rf "$KCM_MONITOR_CACHE"
    echo "✓ Cache cleared"
}
