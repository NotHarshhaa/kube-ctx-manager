#!/usr/bin/env bash

# quick.sh - Quick resource actions for common kubectl operations

# Default container for pod operations
export KCM_DEFAULT_CONTAINER="${KCM_DEFAULT_CONTAINER:-}"

# Fuzzy select a pod
_kcm_select_pod() {
    local namespace="${1:-default}"
    
    if ! command -v fzf >/dev/null 2>&1; then
        _kcm_error "fzf is required for pod selection"
        return 1
    fi
    
    local selected_pod
    selected_pod=$(kubectl get pods -n "$namespace" --no-headers 2>/dev/null | \
        fzf --height=40% --layout=reverse --border \
            --prompt="Select pod> " \
            --header="Namespace: $namespace" \
            --preview="kubectl describe pod {1} -n $namespace 2>/dev/null | head -30" | \
        awk '{print $1}')
    
    echo "$selected_pod"
}

# Quick pod shell access
kshell() {
    local pod="$1"
    local namespace="${2:-}"
    local container="${3:-$KCM_DEFAULT_CONTAINER}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # Select pod if not specified
    if [[ -z "$pod" ]]; then
        pod=$(_kcm_select_pod "$namespace")
        if [[ -z "$pod" ]]; then
            _kcm_info "No pod selected"
            return 0
        fi
    fi
    
    # Build command
    local cmd="kubectl exec -it $pod -n $namespace"
    if [[ -n "$container" ]]; then
        cmd+=" -c $container"
    fi
    cmd+=" -- /bin/sh"
    
    _kcm_info "Starting shell in pod: $pod"
    eval "$cmd"
}

# Quick pod logs with fuzzy selection
klogs() {
    local pod="$1"
    local namespace="${2:-}"
    local follow="${3:-false}"
    local tail="${4:-100}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # Select pod if not specified
    if [[ -z "$pod" ]]; then
        pod=$(_kcm_select_pod "$namespace")
        if [[ -z "$pod" ]]; then
            _kcm_info "No pod selected"
            return 0
        fi
    fi
    
    # Build command
    local cmd="kubectl logs $pod -n $namespace --tail=$tail"
    if [[ "$follow" == "true" ]] || [[ "$follow" == "-f" ]] || [[ "$follow" == "--follow" ]]; then
        cmd+=" -f"
    fi
    
    _kcm_info "Showing logs for pod: $pod"
    eval "$cmd"
}

# Quick port-forward
kpf() {
    local pod="$1"
    local local_port="$2"
    local remote_port="${3:-$local_port}"
    local namespace="${4:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # Select pod if not specified
    if [[ -z "$pod" ]]; then
        pod=$(_kcm_select_pod "$namespace")
        if [[ -z "$pod" ]]; then
            _kcm_info "No pod selected"
            return 0
        fi
    fi
    
    # Prompt for port if not specified
    if [[ -z "$local_port" ]]; then
        echo -n "Enter local port: "
        read -r local_port
        remote_port="$local_port"
    fi
    
    _kcm_info "Port-forwarding $pod: localhost:$local_port -> $remote_port"
    kubectl port-forward "$pod" "$local_port:$remote_port" -n "$namespace"
}

# Quick describe resource
kdesc() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # If only one argument, treat as pod
    if [[ -z "$resource_name" ]]; then
        resource_name="$resource_type"
        resource_type="pod"
    fi
    
    kubectl describe "$resource_type" "$resource_name" -n "$namespace"
}

# Quick get with fuzzy selection
kget() {
    local resource_type="${1:-pod}"
    local namespace="${2:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    kubectl get "$resource_type" -n "$namespace"
}

# Quick delete with confirmation
kdel() {
    local resource_type="$1"
    local resource_name="$2"
    local namespace="${3:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # If only one argument, treat as pod and select with fzf
    if [[ -z "$resource_name" ]]; then
        resource_name="$resource_type"
        resource_type="pod"
        
        if command -v fzf >/dev/null 2>&1; then
            resource_name=$(kubectl get "$resource_type" -n "$namespace" --no-headers 2>/dev/null | \
                fzf --height=40% --layout=reverse --border \
                    --prompt="Select $resource_type to delete> " | \
                awk '{print $1}')
            
            if [[ -z "$resource_name" ]]; then
                _kcm_info "No resource selected"
                return 0
            fi
        else
            _kcm_error "Resource name required without fzf"
            return 1
        fi
    fi
    
    # Confirm deletion
    if _kcm_confirm_action "Delete $resource_type/$resource_name in namespace $namespace?" "n"; then
        kubectl delete "$resource_type" "$resource_name" -n "$namespace"
    else
        _kcm_info "Deletion cancelled"
    fi
}

# Quick apply with dry-run option
kapply() {
    local file="$1"
    local dry_run="${2:-false}"
    
    if [[ -z "$file" ]]; then
        _kcm_error "File path required"
        return 1
    fi
    
    if [[ ! -f "$file" ]]; then
        _kcm_error "File not found: $file"
        return 1
    fi
    
    local cmd="kubectl apply -f $file"
    if [[ "$dry_run" == "true" ]] || [[ "$dry_run" == "--dry-run" ]]; then
        cmd+=" --dry-run=server"
    fi
    
    _kcm_info "Applying: $file"
    eval "$cmd"
}

# Quick scale deployment
kscale() {
    local deployment="$1"
    local replicas="${2:-}"
    local namespace="${3:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # Select deployment if not specified
    if [[ -z "$deployment" ]]; then
        if command -v fzf >/dev/null 2>&1; then
            deployment=$(kubectl get deployments -n "$namespace" --no-headers 2>/dev/null | \
                fzf --height=40% --layout=reverse --border \
                    --prompt="Select deployment> " | \
                awk '{print $1}')
            
            if [[ -z "$deployment" ]]; then
                _kcm_info "No deployment selected"
                return 0
            fi
        else
            _kcm_error "Deployment name required without fzf"
            return 1
        fi
    fi
    
    # Prompt for replicas if not specified
    if [[ -z "$replicas" ]]; then
        echo -n "Enter number of replicas: "
        read -r replicas
    fi
    
    kubectl scale deployment "$deployment" --replicas="$replicas" -n "$namespace"
}

# Quick restart deployment
krestart() {
    local deployment="$1"
    local namespace="${2:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    # Select deployment if not specified
    if [[ -z "$deployment" ]]; then
        if command -v fzf >/dev/null 2>&1; then
            deployment=$(kubectl get deployments -n "$namespace" --no-headers 2>/dev/null | \
                fzf --height=40% --layout=reverse --border \
                    --prompt="Select deployment to restart> " | \
                awk '{print $1}')
            
            if [[ -z "$deployment" ]]; then
                _kcm_info "No deployment selected"
                return 0
            fi
        else
            _kcm_error "Deployment name required without fzf"
            return 1
        fi
    fi
    
    kubectl rollout restart deployment "$deployment" -n "$namespace"
}

# Quick events viewer
kevents() {
    local namespace="${1:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    kubectl get events -n "$namespace" --sort-by='.lastTimestamp'
}

# Quick top pods
ktop() {
    local resource_type="${1:-pod}"
    local namespace="${2:-}"
    
    # Get namespace if not specified
    if [[ -z "$namespace" ]]; then
        namespace=$(_kcm_get_current_namespace)
    fi
    
    kubectl top "$resource_type" -n "$namespace"
}

# Quick config view
kconfig() {
    local action="${1:-view}"
    
    case "$action" in
        view)
            kubectl config view
            ;;
        current)
            kubectl config current-context
            ;;
        contexts)
            kubectl config get-contexts
            ;;
        users)
            kubectl config view -o jsonpath='{.users[*].name}'
            ;;
        clusters)
            kubectl config view -o jsonpath='{.clusters[*].name}'
            ;;
        *)
            echo "Usage: kconfig <action>"
            echo ""
            echo "Actions:"
            echo "  view      - View full config"
            echo "  current   - Show current context"
            echo "  contexts  - List all contexts"
            echo "  users     - List all users"
            echo "  clusters  - List all clusters"
            ;;
    esac
}
