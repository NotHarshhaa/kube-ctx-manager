#!/usr/bin/env bash

# resource.sh - Resource management utilities

# Resource quota viewer
_kcm_resource_quota() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    
    echo "Resource Quotas for namespace: $namespace"
    echo "========================================="
    kubectl get resourcequota -n "$namespace" -o custom-columns=NAME:.metadata.name,HARD:.spec.hard,USED:.status.used 2>/dev/null || echo "No resource quotas found"
}

# Limit range viewer
_kcm_limit_range() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    
    echo "Limit Ranges for namespace: $namespace"
    echo "======================================"
    kubectl get limitrange -n "$namespace" -o wide 2>/dev/null || echo "No limit ranges found"
}

# Pod resource usage summary
_kcm_pod_resources() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    
    echo "Pod Resource Usage for namespace: $namespace"
    echo "============================================"
    
    # Get pods with resource requests/limits
    kubectl get pods -n "$namespace" -o custom-columns=NAME:.metadata.name,CPU_REQUEST:.spec.containers[*].resources.requests.cpu,CPU_LIMIT:.spec.containers[*].resources.limits.cpu,MEM_REQUEST:.spec.containers[*].resources.requests.memory,MEM_LIMIT:.spec.containers[*].resources.limits.memory 2>/dev/null
}

# Node resource summary
_kcm_node_resources() {
    echo "Node Resource Summary"
    echo "======================"
    kubectl top nodes 2>/dev/null || echo "Metrics server not available"
    echo ""
    kubectl describe nodes | grep -A 3 "Allocated resources"
}

# PVC usage summary
_kcm_pvc_usage() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    
    echo "PVC Usage for namespace: $namespace"
    echo "=================================="
    kubectl get pvc -n "$namespace" -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CAPACITY:.status.capacity.storage,ACCESS:.spec.accessModes[0] 2>/dev/null || echo "No PVCs found"
}

# Resource cleanup - identify unused resources
_kcm_resource_cleanup() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    local dry_run="${2:-true}"
    
    echo "Resource Cleanup Analysis for namespace: $namespace"
    echo "=================================================="
    
    # Find completed jobs
    echo ""
    echo "Completed Jobs (older than 24h):"
    kubectl get jobs -n "$namespace" --field-selector=status.successful=1 -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v '^$'
    
    # Find failed pods
    echo ""
    echo "Failed Pods:"
    kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -v '^$'
    
    # Find evicted pods
    echo ""
    echo "Evicted Pods:"
    kubectl get pods -n "$namespace" --field-selector=status.phase=Failed -o jsonpath='{range .items[?(@.status.message==\"Evicted\")]}{.metadata.name}{"\n"}{end}' 2>/dev/null
    
    if [[ "$dry_run" == "false" ]]; then
        echo ""
        if _kcm_confirm_action "Clean up completed jobs and failed pods?" "n"; then
            kubectl delete jobs -n "$namespace" --field-selector=status.successful=1
            kubectl delete pods -n "$namespace" --field-selector=status.phase=Failed
            _kcm_success "Cleanup completed"
        fi
    else
        echo ""
        echo "Dry-run mode. Use 'kcleanup $namespace false' to actually clean up."
    fi
}

# Resource events viewer
_kcm_resource_events() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    local resource_type="${2:-}"
    local resource_name="${3:-}"
    
    if [[ -n "$resource_type" ]] && [[ -n "$resource_name" ]]; then
        kubectl get events -n "$namespace" --field-selector=involvedObject.kind=$resource_type,involvedObject.name=$resource_name --sort-by='.lastTimestamp'
    else
        kubectl get events -n "$namespace" --sort-by='.lastTimestamp'
    fi
}

# Image pull policy analyzer
_kcm_image_analysis() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    
    echo "Image Analysis for namespace: $namespace"
    echo "========================================="
    
    kubectl get pods -n "$namespace" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' 2>/dev/null | sort -u
}

# Security context analyzer
_kcm_security_analysis() {
    local namespace="${1:-$(_kcm_get_current_namespace)}"
    
    echo "Security Context Analysis for namespace: $namespace"
    echo "=================================================="
    
    echo ""
    echo "Pods running as root:"
    kubectl get pods -n "$namespace" -o jsonpath='{range .items[?(@.spec.containers[*].securityContext.runAsRoot==true)]}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "None found"
    
    echo ""
    echo "Pods with privileged containers:"
    kubectl get pods -n "$namespace" -o jsonpath='{range .items[?(@.spec.containers[*].securityContext.privileged==true)]}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "None found"
    
    echo ""
    echo "Pods with hostPath volumes:"
    kubectl get pods -n "$namespace" -o jsonpath='{range .items[?(@.spec.volumes[*].hostPath)]}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "None found"
}

# User commands for resource management
kquota() {
    local namespace="${1:-}"
    _kcm_resource_quota "$namespace"
}

klimits() {
    local namespace="${1:-}"
    _kcm_limit_range "$namespace"
}

kpod-res() {
    local namespace="${1:-}"
    _kcm_pod_resources "$namespace"
}

knode-res() {
    _kcm_node_resources
}

kpvc() {
    local namespace="${1:-}"
    _kcm_pvc_usage "$namespace"
}

kcleanup() {
    local namespace="${1:-}"
    local dry_run="${2:-true}"
    _kcm_resource_cleanup "$namespace" "$dry_run"
}

kres-events() {
    local namespace="${1:-}"
    local resource_type="${2:-}"
    local resource_name="${3:-}"
    _kcm_resource_events "$namespace" "$resource_type" "$resource_name"
}

kimages() {
    local namespace="${1:-}"
    _kcm_image_analysis "$namespace"
}

ksec-analysis() {
    local namespace="${1:-}"
    _kcm_security_analysis "$namespace"
}
