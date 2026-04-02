#!/usr/bin/env bash

# search.sh - Context search and filtering functionality

# Search cache
export KCM_SEARCH_CACHE="$HOME/.kube-search-cache"
export KCM_SEARCH_CACHE_TTL=300  # 5 minutes

# Enhanced context listing with metadata
_kcm_list_contexts_detailed() {
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null)
    
    kubectl config get-contexts --no-headers | while read -r line; do
        local context_name
        context_name=$(echo "$line" | awk '{print $1}')
        local cluster
        cluster=$(echo "$line" | awk '{print $2}')
        local user
        user=$(echo "$line" | awk '{print $3}')
        local namespace
        namespace=$(echo "$line" | awk '{print $4}')
        
        local current_marker=""
        if [[ "$context_name" == "$current_context" ]]; then
            current_marker="*"
        fi
        
        printf "%s %-30s %-20s %-15s %s\n" "$current_marker" "$context_name" "$cluster" "$user" "$namespace"
    done
}

# Search contexts by name, cluster, or user
ksearch() {
    local pattern="$1"
    local search_type="${2:-all}"  # all, name, cluster, user
    local detailed="${3:-no}"
    
    if [[ -z "$pattern" ]]; then
        echo "Usage: ksearch <pattern> [search-type] [detailed]"
        echo "Search types: all, name, cluster, user"
        echo "Example: ksearch prod all detailed"
        echo "Example: ksearch eks cluster"
        return 1
    fi
    
    echo "Searching contexts for pattern: $pattern"
    echo ""
    
    if [[ "$detailed" == "detailed" ]]; then
        echo "CURRENT  CONTEXT                        CLUSTER              USER            NAMESPACE"
        echo "------- ------------------------------ -------------------- --------------- ---------"
        _kcm_list_contexts_detailed | grep -i "$pattern" | while IFS= read -r line; do
            # Highlight matches
            echo "$line" | grep -i --color=auto "$pattern"
        done
    else
        echo "Matching contexts:"
        kubectl config get-contexts -o name | grep -i "$pattern" | sed 's/^.*\///'
    fi
    
    echo ""
    
    # Show count of matches
    local match_count
    match_count=$(kubectl config get-contexts -o name | grep -i "$pattern" | wc -l)
    echo "Found $match_count matching context(s)"
}

# Advanced search with multiple filters
ksearch-advanced() {
    local name_pattern="$1"
    local cluster_pattern="$2"
    local user_pattern="$3"
    local namespace_pattern="$4"
    
    echo "Advanced context search:"
    echo "Name pattern: ${name_pattern:-*}"
    echo "Cluster pattern: ${cluster_pattern:-*}"
    echo "User pattern: ${user_pattern:-*}"
    echo "Namespace pattern: ${namespace_pattern:-*}"
    echo ""
    
    echo "CURRENT  CONTEXT                        CLUSTER              USER            NAMESPACE"
    echo "------- ------------------------------ -------------------- --------------- ---------"
    
    local found=0
    
    kubectl config get-contexts --no-headers | while read -r line; do
        local context_name
        context_name=$(echo "$line" | awk '{print $1}')
        local cluster
        cluster=$(echo "$line" | awk '{print $2}')
        local user
        user=$(echo "$line" | awk '{print $3}')
        local namespace
        namespace=$(echo "$line" | awk '{print $4}')
        
        local match=1
        
        # Check each pattern
        if [[ -n "$name_pattern" && ! "$context_name" =~ $name_pattern ]]; then
            match=0
        fi
        
        if [[ -n "$cluster_pattern" && ! "$cluster" =~ $cluster_pattern ]]; then
            match=0
        fi
        
        if [[ -n "$user_pattern" && ! "$user" =~ $user_pattern ]]; then
            match=0
        fi
        
        if [[ -n "$namespace_pattern" && ! "$namespace" =~ $namespace_pattern ]]; then
            match=0
        fi
        
        if [[ $match -eq 1 ]]; then
            local current_context
            current_context=$(kubectl config current-context 2>/dev/null)
            local current_marker=""
            if [[ "$context_name" == "$current_context" ]]; then
                current_marker="*"
            fi
            
            printf "%s %-30s %-20s %-15s %s\n" "$current_marker" "$context_name" "$cluster" "$user" "$namespace"
            ((found++))
        fi
    done
    
    echo ""
    echo "Search completed"
}

# Search contexts by environment type
ksearch-env() {
    local env_type="$1"
    
    if [[ -z "$env_type" ]]; then
        echo "Usage: ksearch-env <environment-type>"
        echo "Common types: prod, staging, dev, test, qa"
        return 1
    fi
    
    echo "Searching for $env_type environments..."
    echo ""
    
    # Common patterns for environment detection
    local patterns=(
        "$env_type"
        "${env_type}-"
        "-${env_type}"
        "${env_type}_"
        "_${env_type}"
        "${env_type^^}"  # Uppercase version
    )
    
    local found_contexts=()
    
    for pattern in "${patterns[@]}"; do
        local matches
        matches=$(kubectl config get-contexts -o name | grep -i "$pattern" | sed 's/^.*\///')
        if [[ -n "$matches" ]]; then
            found_contexts+=($matches)
        fi
    done
    
    if [[ ${#found_contexts[@]} -eq 0 ]]; then
        echo "No $env_type contexts found"
        return 1
    fi
    
    echo "Found ${#found_contexts[@]} $env_type context(s):"
    printf '%s\n' "${found_contexts[@]}" | sort -u
}

# Search contexts by cluster provider
ksearch-provider() {
    local provider="$1"
    
    if [[ -z "$provider" ]]; then
        echo "Usage: ksearch-provider <provider>"
        echo "Common providers: eks, gke, aks, do, digitalocean, rancher"
        return 1
    fi
    
    echo "Searching for $provider clusters..."
    echo ""
    
    kubectl config get-contexts --no-headers | while read -r line; do
        local context_name
        context_name=$(echo "$line" | awk '{print $1}')
        local cluster
        cluster=$(echo "$line" | awk '{print $2}')
        
        # Check cluster name for provider patterns
        if [[ "$cluster" =~ $provider || "$context_name" =~ $provider ]]; then
            local current_context
            current_context=$(kubectl config current-context 2>/dev/null)
            local current_marker=""
            if [[ "$context_name" == "$current_context" ]]; then
                current_marker="*"
            fi
            
            printf "%s %-30s %-20s\n" "$current_marker" "$context_name" "$cluster"
        fi
    done
}

# Search contexts by region/location
ksearch-region() {
    local region="$1"
    
    if [[ -z "$region" ]]; then
        echo "Usage: ksearch-region <region>"
        echo "Examples: us-east-1, eu-west-2, ap-south-1"
        return 1
    fi
    
    echo "Searching for contexts in region: $region"
    echo ""
    
    kubectl config get-contexts --no-headers | while read -r line; do
        local context_name
        context_name=$(echo "$line" | awk '{print $1}')
        local cluster
        cluster=$(echo "$line" | awk '{print $2}')
        
        # Check for region patterns
        if [[ "$context_name" =~ $region || "$cluster" =~ $region ]]; then
            local current_context
            current_context=$(kubectl config current-context 2>/dev/null)
            local current_marker=""
            if [[ "$context_name" == "$current_context" ]]; then
                current_marker="*"
            fi
            
            printf "%s %-30s %-20s\n" "$current_marker" "$context_name" "$cluster"
        fi
    done
}

# Interactive search with fzf
ksearch-interactive() {
    local search_type="${1:-all}"
    
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for interactive search"
        return 1
    fi
    
    echo "Interactive context search (type to filter, Enter to select, Esc to cancel)"
    echo ""
    
    local selected_context
    case "$search_type" in
        "all")
            selected_context=$(kubectl config get-contexts --no-headers | fzf \
                --height=40% \
                --layout=reverse \
                --border \
                --prompt="Search contexts> " \
                --header="Use arrow keys to navigate, Enter to switch context" \
                --preview="kubectl config view --minify --context={1} --output=json 2>/dev/null | jq -r '.contexts[0].context | \"Cluster: \\(.cluster)\\nUser: \\(.user)\\nNamespace: \\(.namespace // \"default\")\"' 2>/dev/null || echo 'No details available'" \
                --expect=ctrl-o,ctrl-i)
            ;;
        "name")
            selected_context=$(kubectl config get-contexts -o name | fzf \
                --height=40% \
                --layout=reverse \
                --border \
                --prompt="Search by name> ")
            ;;
        "cluster")
            selected_context=$(kubectl config get-contexts --no-headers | awk '{print $2 " " $1}' | sort -u | fzf \
                --height=40% \
                --layout=reverse \
                --border \
                --prompt="Search by cluster> " \
                --preview="echo {2}")
            ;;
        *)
            echo "Invalid search type: $search_type (use all, name, cluster)"
            return 1
            ;;
    esac
    
    if [[ -n "$selected_context" ]]; then
        # Extract context name from selection
        local context_to_switch
        if [[ "$search_type" == "all" ]]; then
            context_to_switch=$(echo "$selected_context" | awk '{print $1}')
        elif [[ "$search_type" == "cluster" ]]; then
            context_to_switch=$(echo "$selected_context" | awk '{print $2}')
        else
            context_to_switch=$(echo "$selected_context" | sed 's/^.*\///')
        fi
        
        if [[ -n "$context_to_switch" ]]; then
            echo "Switching to context: $context_to_switch"
            kx "$context_to_switch"
        fi
    else
        echo "No context selected"
    fi
}

# Search and show context details
ksearch-details() {
    local pattern="$1"
    
    if [[ -z "$pattern" ]]; then
        echo "Usage: ksearch-details <pattern>"
        return 1
    fi
    
    echo "Searching for contexts matching: $pattern"
    echo ""
    
    local found=0
    
    kubectl config get-contexts -o name | grep -i "$pattern" | while read -r context; do
        context=$(echo "$context" | sed 's/^.*\///')
        ((found++))
        
        echo "Context: $context"
        echo "----------------------------------------"
        
        # Get detailed information
        local context_info
        context_info=$(kubectl config view --minify --context="$context" --output=json 2>/dev/null)
        
        if [[ -n "$context_info" ]]; then
            if command -v jq >/dev/null 2>&1; then
                echo "Cluster: $(echo "$context_info" | jq -r '.contexts[0].context.cluster')"
                echo "User: $(echo "$context_info" | jq -r '.contexts[0].context.user')"
                echo "Namespace: $(echo "$context_info" | jq -r '.contexts[0].context.namespace // "default"')"
                
                # Get cluster details
                local cluster_name
                cluster_name=$(echo "$context_info" | jq -r '.contexts[0].context.cluster')
                local cluster_info
                cluster_info=$(echo "$context_info" | jq -r ".clusters[] | select(.name == \"$cluster_name\")")
                
                if [[ -n "$cluster_info" ]]; then
                    echo "Cluster Server: $(echo "$cluster_info" | jq -r '.cluster.server')"
                fi
            else
                kubectl config view --minify --context="$context"
            fi
        fi
        
        echo ""
    done
    
    if [[ $found -eq 0 ]]; then
        echo "No contexts found matching: $pattern"
    else
        echo "Found $found matching context(s)"
    fi
}

# Search contexts by usage (from audit log)
ksearch-recent() {
    local days="${1:-7}"
    
    if [[ ! -f "$KCM_AUDIT_LOG" ]]; then
        echo "No audit log found: $KCM_AUDIT_LOG"
        return 1
    fi
    
    echo "Searching recently used contexts (last $days days)"
    echo ""
    
    local cutoff_date
    cutoff_date=$(date -d "$days days ago" '+%Y-%m-%d' 2>/dev/null || date -v-${days}d '+%Y-%m-%d' 2>/dev/null)
    
    echo "Recently used contexts:"
    grep "^\\[" "$KCM_AUDIT_LOG" | grep "context=" | while read -r line; do
        local log_date
        log_date=$(echo "$line" | sed 's/\[\(.*\)].*/\1/' | cut -d' ' -f1)
        
        if [[ "$log_date" > "$cutoff_date" ]]; then
            local context
            context=$(echo "$line" | grep -o "context=[^[:space:]]*" | cut -d= -f2)
            local timestamp
            timestamp=$(echo "$line" | sed 's/\[\(.*\)].*/\1/')
            local command
            command=$(echo "$line" | grep -o "command=[^[:space:]]*" | cut -d= -f2-)
            
            printf "%-20s %-30s %s\n" "$timestamp" "$context" "$command"
        fi
    done | sort -r
    
    echo ""
    echo "Usage summary:"
    grep "^\\[" "$KCM_AUDIT_LOG" | grep "context=" | grep "context=[^[:space:]]*" | while read -r line; do
        local context
        context=$(echo "$line" | grep -o "context=[^[:space:]]*" | cut -d= -f2)
        echo "$context"
    done | sort | uniq -c | sort -nr | head -10
}
