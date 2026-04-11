#!/usr/bin/env bash

# templates.sh - Command templates for common operations

# Templates file
export KCM_TEMPLATES_FILE="$HOME/.kube-templates"

# Initialize templates system
_kcm_templates_init() {
    if [[ ! -f "$KCM_TEMPLATES_FILE" ]]; then
        # Create default templates
        cat > "$KCM_TEMPLATES_FILE" << 'EOF'
# kube-ctx-manager command templates
# Format: template_name|description|command
# Use {context} for context, {namespace} for namespace, {name} for resource name

pod-logs|Get pod logs|kubectl logs {name} -n {namespace}
pod-logs-follow|Follow pod logs|kubectl logs {name} -n {namespace} -f
pod-shell|Get shell in pod|kubectl exec -it {name} -n {namespace} -- /bin/sh
pod-describe|Describe pod|kubectl describe pod {name} -n {namespace}
pod-delete|Delete pod|kubectl delete pod {name} -n {namespace}
deployment-scale|Scale deployment|kubectl scale deployment {name} -n {namespace} --replicas={replicas}
deployment-restart|Restart deployment|kubectl rollout restart deployment {name} -n {namespace}
deployment-status|Check deployment status|kubectl rollout status deployment {name} -n {namespace}
service-describe|Describe service|kubectl describe svc {name} -n {namespace}
configmap-get|Get configmap|kubectl get configmap {name} -n {namespace} -o yaml
secret-get|Get secret|kubectl get secret {name} -n {namespace} -o yaml
ingress-describe|Describe ingress|kubectl describe ingress {name} -n {namespace}
pvc-describe|Describe PVC|kubectl describe pvc {name} -n {namespace}
node-describe|Describe node|kubectl describe node {name}
namespace-create|Create namespace|kubectl create namespace {name}
namespace-delete|Delete namespace|kubectl delete namespace {name}
apply-file|Apply manifest file|kubectl apply -f {file}
apply-dryrun|Dry-run apply|kubectl apply -f {file} --dry-run=server
port-forward|Port forward to pod|kubectl port-forward {name} {local_port}:{remote_port} -n {namespace}
top-pods|Show pod resource usage|kubectl top pods -n {namespace}
top-nodes|Show node resource usage|kubectl top nodes
events-show|Show events|kubectl get events -n {namespace} --sort-by=.lastTimestamp
EOF
        chmod 600 "$KCM_TEMPLATES_FILE"
    fi
}

# List all templates
_kcm_templates_list() {
    if [[ ! -f "$KCM_TEMPLATES_FILE" ]]; then
        _kcm_error "Templates file not found"
        return 1
    fi
    
    echo "Available Templates:"
    echo "==================="
    grep -v "^#" "$KCM_TEMPLATES_FILE" | grep -v "^$" | while IFS='|' read -r name desc cmd; do
        printf "  %-20s %s\n" "$name" "$desc"
    done
}

# Get template command
_kcm_template_get() {
    local template_name="$1"
    
    if [[ -z "$template_name" ]]; then
        _kcm_error "Template name required"
        return 1
    fi
    
    local template
    template=$(grep "^$template_name|" "$KCM_TEMPLATES_FILE" 2>/dev/null)
    
    if [[ -z "$template" ]]; then
        _kcm_error "Template not found: $template_name"
        return 1
    fi
    
    echo "$template" | cut -d'|' -f3
}

# Execute a template with variable substitution
_kcm_template_execute() {
    local template_name="$1"
    shift
    local -n variables=$1
    
    local cmd
    cmd=$(_kcm_template_get "$template_name")
    
    if [[ -z "$cmd" ]]; then
        return 1
    fi
    
    # Get current context and namespace if not provided
    local context="${variables[context]:-$(_kcm_get_current_context)}"
    local namespace="${variables[namespace]:-$(_kcm_get_current_namespace)}"
    
    # Substitute variables
    cmd="${cmd//{context}/$context}"
    cmd="${cmd//{namespace}/$namespace}"
    
    for key in "${!variables[@]}"; do
        cmd="${cmd//{$key}/${variables[$key]}}"
    done
    
    _kcm_info "Executing: $cmd"
    eval "$cmd"
}

# Add a custom template
_kcm_template_add() {
    local name="$1"
    local description="$2"
    local command="$3"
    
    if [[ -z "$name" ]] || [[ -z "$description" ]] || [[ -z "$command" ]]; then
        _kcm_error "Name, description, and command required"
        return 1
    fi
    
    # Check if template already exists
    if grep -q "^$name|" "$KCM_TEMPLATES_FILE" 2>/dev/null; then
        _kcm_warning "Template already exists. Use ktemplate-edit to modify."
        return 1
    fi
    
    echo "$name|$description|$command" >> "$KCM_TEMPLATES_FILE"
    _kcm_success "Template added: $name"
}

# Remove a template
_kcm_template_remove() {
    local name="$1"
    
    if [[ -z "$name" ]]; then
        _kcm_error "Template name required"
        return 1
    fi
    
    if grep -q "^$name|" "$KCM_TEMPLATES_FILE" 2>/dev/null; then
        if _kcm_confirm_action "Remove template '$name'?" "n"; then
            grep -v "^$name|" "$KCM_TEMPLATES_FILE" > "${KCM_TEMPLATES_FILE}.tmp"
            mv "${KCM_TEMPLATES_FILE}.tmp" "$KCM_TEMPLATES_FILE"
            _kcm_success "Template removed: $name"
        fi
    else
        _kcm_error "Template not found: $name"
        return 1
    fi
}

# Interactive template execution
ktemplate() {
    _kcm_templates_init
    
    local template_name="$1"
    shift
    
    if [[ -z "$template_name" ]]; then
        # Interactive selection
        if ! command -v fzf >/dev/null 2>&1; then
            _kcm_templates_list
            return 0
        fi
        
        local selected
        selected=$(grep -v "^#" "$KCM_TEMPLATES_FILE" | grep -v "^$" | cut -d'|' -f1,2 | column -t -s '|' | \
            fzf --height=40% --layout=reverse --border \
                --prompt="Select template> " \
                --header="Command Templates" | awk '{print $1}')
        
        if [[ -z "$selected" ]]; then
            _kcm_info "No template selected"
            return 0
        fi
        
        template_name="$selected"
    fi
    
    # Get template command
    local template_cmd
    template_cmd=$(_kcm_template_get "$template_name")
    
    if [[ -z "$template_cmd" ]]; then
        return 1
    fi
    
    # Extract variables from template
    local variables=()
    while [[ "$template_cmd" =~ \{([^}]+)\} ]]; do
        local var="${BASH_REMATCH[1]}"
        if [[ ! " ${variables[@]} " =~ " ${var} " ]]; then
            variables+=("$var")
        fi
        template_cmd="${template_cmd/\{$var\}/}"
    done
    
    # Prompt for variable values
    local -A var_values
    for var in "${variables[@]}"; do
        if [[ "$var" == "context" ]]; then
            var_values[context]=$(_kcm_get_current_context)
        elif [[ "$var" == "namespace" ]]; then
            var_values[namespace]=$(_kcm_get_current_namespace)
        else
            echo -n "Enter value for $var: "
            read -r value
            var_values[$var]="$value"
        fi
    done
    
    # Execute template
    _kcm_template_execute "$template_name" var_values
}

ktemplate-list() {
    _kcm_templates_init
    _kcm_templates_list
}

ktemplate-add() {
    _kcm_templates_init
    local name="$1"
    local description="$2"
    local command="$3"
    _kcm_template_add "$name" "$description" "$command"
}

ktemplate-remove() {
    _kcm_templates_init
    local name="$1"
    _kcm_template_remove "$name"
}

ktemplate-show() {
    _kcm_templates_init
    local name="$1"
    
    if [[ -z "$name" ]]; then
        _kcm_error "Template name required"
        return 1
    fi
    
    local template
    template=$(grep "^$name|" "$KCM_TEMPLATES_FILE" 2>/dev/null)
    
    if [[ -z "$template" ]]; then
        _kcm_error "Template not found: $name"
        return 1
    fi
    
    IFS='|' read -r tname desc cmd <<< "$template"
    echo "Template: $tname"
    echo "Description: $desc"
    echo "Command: $cmd"
}
