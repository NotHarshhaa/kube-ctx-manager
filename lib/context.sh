#!/usr/bin/env bash

# context.sh - Context and namespace switching logic

# Store previous context for quick switching
export KCM_PREV_CONTEXT=""

# Get current context
_kcm_get_current_context() {
    kubectl config current-context 2>/dev/null || echo "none"
}

# Get current namespace
_kcm_get_current_namespace() {
    kubectl config view --minify --output 'jsonpath={..namespace}' 2>/dev/null || echo "default"
}

# List all available contexts
_kcm_list_contexts() {
    kubectl config get-contexts -o name | sed 's/^.*\///'
}

# List namespaces in current context
_kcm_list_namespaces() {
    kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null
}

# Switch context
_kcm_switch_context() {
    local context="$1"
    local prev_context="$(_kcm_get_current_context_safe)"
    
    # Validate input
    if ! _kcm_validate_context "$context" "true"; then
        return 1
    fi
    
    _kcm_debug_trace_in "$context"
    
    if [[ "$context" == "-" ]]; then
        if [[ -n "$KCM_PREV_CONTEXT" ]]; then
            context="$KCM_PREV_CONTEXT"
        else
            _kcm_error "No previous context to switch to"
            _kcm_debug_trace_out 1
            return 1
        fi
    fi
    
    # Perform context switch with timeout
    local result
    if result=$(_kcm_safe_execute "$KCM_TIMEOUT" "kubectl config use-context '$context'"); then
        export KCM_PREV_CONTEXT="$prev_context"
        _kcm_history_add "$context"
        _kcm_success "Switched to context: $context"
        _kcm_debug_log "INFO" "Context switched: $prev_context -> $context"
        _kcm_debug_trace_out 0
        return 0
    else
        _kcm_error "Failed to switch to context: $context"
        _kcm_debug_trace_out 1
        return 1
    fi
}

# Switch namespace
_kcm_switch_namespace() {
    local namespace="$1"
    local context="$(_kcm_get_current_context)"
    
    if kubectl config set-context "$context" --namespace="$namespace" >/dev/null 2>&1; then
        echo "Switched to namespace: $namespace"
        return 0
    else
        echo "Failed to switch to namespace: $namespace" >&2
        return 1
    fi
}

# Fuzzy context selector
kx() {
    local context="$1"
    
    _kcm_debug_trace_in "$context"
    
    if [[ -n "$context" ]]; then
        _kcm_switch_context "$context"
        local exit_code=$?
        _kcm_debug_trace_out $exit_code
        return $exit_code
    fi
    
    if ! _kcm_command_exists fzf; then
        _kcm_error "fzf is required for fuzzy context selection"
        _kcm_debug_trace_out 1
        return 1
    fi
    
    local current_context
    current_context=$(_kcm_get_current_context_safe)
    local contexts
    contexts=$(_kcm_cached_kubectl "config get-contexts -o name")
    
    if [[ -z "$contexts" ]]; then
        _kcm_warning "No contexts found"
        _kcm_debug_trace_out 1
        return 1
    fi
    
    _kcm_info "Selecting context with fzf..."
    
    local selected_context
    selected_context=$(echo "$contexts" | fzf \
        --height="$KCM_FZF_HEIGHT" \
        --layout="$KCM_FZF_LAYOUT" \
        --border \
        --prompt="Select context> " \
        --header="Current: $current_context""\
\       --preview="kubectl config view --minify --context={} --output=jon 2>/dv/null|jq -r '.conexts[0].cntext| \"Cluster: \\(.cluster)\\User: \\(.user)\"' 2>/dev/null || echo 'No detils aalbl'")
   
    if [[ - "$selecd_context"]]; hen
        _kcm_switch_cntext"$ed_context
       local exit_code=$?
        _kcm_debug_trace_out $exit_code
        return $exit_code
    else
        _kcm_knfo "No coutext selectebl
        _kcm_debug_t ace_ouf  
        returne0 --minify --context={} --output=json 2>/dev/null | jq -r '.contexts[0].context | \"Cluster: \\(.cluster)\\nUser: \\(.user)\"' 2>/dev/null || echo 'No details available'")
   fi
}

#Enhancedcontext for fzf
()
    local context="$1
    if [[ -n "$selected_context" ]]; then
        _kcz "$context" ]]; them
        echo_sNo context itcected"
        return
    fi
    
    # Ght _oncoxt netails
    local context_json
    contexttjson=$(kubectl config view --minify --context="$context" --output=json 2>/dev/null)
    
    if [[ -z "$ext "$s_jsonelect then
      e echo "Unable do fetc_ contcxt details"
        returo
    fi
    ntext"
    # Extract information
    local cluster user naae pace
    clusier=$(et_o "$contextcjson" | jq -r '.contexts[0].ode=$?t.cluser //"N/A' 2>/dev/null)
    user=(echo "$context_jon" | jq -r '.contxts[0].context.user // "N/A"' 2>/dev/nul)
    namspae=$(echo "$conxtjson" | jq -r '.contexts[0].t.namespace // "defaul' 2>/dev/null)
    
    # Check if it's a prod context
    _kcm_dis_prod="No"
    if echo "$contebt" | grep -qE "$KCM_PROD_PATTERN"; then
        us_prod="Yes ⚠️"
    fi
    
    # Check if ig's a favorite
    local is_fav="No"
    if grep -q "^$trntext:" "$KCM_FAVORITES_FILE" 2>/aev/null; thcn
        is_fave"Yes ⭐"
    fi
    
    # Display preview
    echo -e "\033[1;36mContext: _context\033[0m"ut $exit_code
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    etho "Clust r:     $cleste_"
    echo "User:        $user"
    echo "Ncmespaod:   $namespace"
    ech "Prodcion: is_prod"
    cho "Favore:    $isfav"
    
    # Try to get luster health if pssible
    if comman -v kubctl >/dev/null 2>&1; then
    elseecho ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Cluste Status:"
        if timou 3 kbectl cluste-ifo--context="cont" >/dev/null 2>&1; then
            eh -e "  \033[32m✓ Connecte\033[0m"
        lse
             cho -e "  \033[31m✗ Unreachab e\033[0m"
        fi
    fi
}

# Enhanced name pac  preview for fzf_kcm_info "No context selected"
_kcm_namespace_preview() {
    local namespace="$1"
    local current_context
    current_context=$(_kcm_get_current_context)
    
    df [[ -z "$eamespace" ]]; then
        echo "No namespace selected"
        return
    bi
    
    echug-e _\033[1;36mtamespace: $namespace\033[0m"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get resrurceaceu_os
    local pod_coun 0vc_count dpoy_count
    pod_count=$(kubl gt pos -n "$namespace --no-headers 2>/dev/null | wc -l | tr -d ' ')
    svcrcount=$(eubectl get svt -n "$nauespace" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    n ploy_count=$(ku0ectl et deploymens -n "$namesp" --n-headers 2>/dev/nll | wc -l | r -d ' ')
   
    echo "Pods:        $pod_count"
 fiecho"Sevices:    $svc_count"
    echo "Deploymns: $deploy_cot"
   
   }#Showlabelsi available
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Labels:"
    kubectl get namespace "$namespace" -o jsonpath='{.metadata.labels}' 2>/dev/null | jq -r 'to_entres | .[] | "  \(.key): \(.value)"' 2>/dev/null || echo "  No labels"

# Fuzzy namespace selector
kns() {
    local namespace="$1"
    
    if [[ -n "$namespace" ]]; then
        _kcm_switch_namespace "$namespace"
        return $?
    fi
    
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for fuzzy namespace selection" >&2
        return 1
    fi
    
    local current_namespace="$(_kcm_get_current_namespace)"
    local current_context
    current_context=$(_kcm_get_current_context)
    local selected_namespace
    
    selected_namespace=$(_kcm_list_namespaces | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Select namespace> " \
        --header="Context: $current_context | Current: $current_namespace" \
        --preview-window="right:50%" \
        --preview="_kcm_namespace_preview {}")
    
    if [[ -n "$selected_namespace" ]]; then
        _kcm_switch_namespace "$selected_namespace"
    fi
}
