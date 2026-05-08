#!/usr/bin/env bash

# export.sh - Context export/import functionality for sharing contexts

# Export directory
export KCM_EXPORT_DIR="$HOME/.kube-exports"

# Initialize export system
_kcm_export_init() {
    mkdir -p "$KCM_EXPORT_DIR"
    chmod 700 "$KCM_EXPORT_DIR"
}

# Export a single context
_kcm_export_context() {
    local context_name="$1"
    local output_file="${2:-}"
    
    if [[ -z "$context_name" ]]; then
        _kcm_error "Context name required"
        return 1
    fi
    
    # Check if context exists
    if ! kubectl config get-contexts "$context_name" >/dev/null 2>&1; then
        _kcm_error "Context does not exist: $context_name"
        return 1
    fi
    
    _kcm_export_init
    
    # Generate output filename if not provided
    if [[ -z "$output_file" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        output_file="$KCM_EXPORT_DIR/${context_name}_${timestamp}.yaml"
    fi
    
    # Extract context using kubectl
    local temp_config
    temp_config=$(mktemp)
    
    KUBECONFIG="$HOME/.kube/config" kubectl config view --raw > "$temp_config"
    
    # Use yq if available for clean extraction
    if command -v yq >/dev/null 2>&1; then
        yq eval "
          .contexts |= map(select(.name == \"$context_name\")) |
          .clusters |= map(select(.name as \$ctx | .contexts[] | select(.name == \"$context_name\") | .context.cluster == \$ctx)) |
          .users |= map(select(.name as \$ctx | .contexts[] | select(.name == \"$context_name\") | .context.user == \$ctx)) |
          .\"current-context\" = \"$context_name\"
        " "$temp_config" > "$output_file"
    else
        # Fallback: copy entire config and set current-context
        cp "$temp_config" "$output_file"
        kubectl --kubeconfig="$output_file" config use-context "$context_name"
    fi
    
    rm -f "$temp_config"
    chmod 600 "$output_file"
    
    _kcm_success "Exported context '$context_name' to: $output_file"
}

# Export multiple contexts
_kcm_export_contexts() {
    local pattern="$1"
    local output_file="$2"
    
    _kcm_export_init
    
    # Get matching contexts
    local contexts
    contexts=$(kubectl config get-contexts -o name | grep "$pattern" | sed 's/^.*\///')
    
    if [[ -z "$contexts" ]]; then
        _kcm_error "No contexts matching pattern: $pattern"
        return 1
    fi
    
    echo "Found contexts:"
    echo "$contexts"
    echo ""
    
    # Generate output filename if not provided
    if [[ -z "$output_file" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        output_file="$KCM_EXPORT_DIR/contexts_${pattern}_${timestamp}.yaml"
    fi
    
    # Extract contexts
    if command -v yq >/dev/null 2>&1; then
        local temp_config
        temp_config=$(mktemp)
        KUBECONFIG="$HOME/.kube/config" kubectl config view --raw > "$temp_config"
        
        yq eval "
          .contexts |= map(select(.name | test(\"$pattern\"))) |
          .clusters |= map(select(.name as \$ctx | .contexts[] | select(.name | test(\"$pattern\")) | .context.cluster == \$ctx)) |
          .users |= map(select(.name as \$ctx | .contexts[] | select(.name | test(\"$pattern\")) | .context.user == \$ctx)) |
          .\"current-context\" = (.contexts[0].name // \"\")
        " "$temp_config" > "$output_file"
        
        rm -f "$temp_config"
    else
        _kcm_error "yq required for multi-context export"
        return 1
    fi
    
    chmod 600 "$output_file"
    _kcm_success "Exported $(echo "$contexts" | wc -l) contexts to: $output_file"
}

# Import a context from file
_kcm_import_context() {
    local import_file="$1"
    local merge="${2:-false}"
    
    if [[ ! -f "$import_file" ]]; then
        _kcm_error "File not found: $import_file"
        return 1
    fi
    
    # Validate the import file
    if ! _kcm_validate_kubeconfig "$import_file"; then
        _kcm_error "Invalid kubeconfig file: $import_file"
        return 1
    fi
    
    # Create backup
    local backup_file
    backup_file=$(_kcm_backup_kubeconfig "before_import_$(date +%s)")
    echo "Created backup: $backup_file"
    
    if [[ "$merge" == "true" ]]; then
        # Merge with existing config
        echo "Merging contexts from: $import_file"
        kube-merge "$HOME/.kube/config" "$HOME/.kube/config" "$import_file"
    else
        # Replace entire config
        echo "Importing from: $import_file"
        cp "$import_file" "$HOME/.kube/config"
        _kcm_success "Imported kubeconfig"
    fi
    
    # Show imported contexts
    echo ""
    echo "Available contexts:"
    kubectl config get-contexts
}

# List exported contexts
_kcm_export_list() {
    if [[ ! -d "$KCM_EXPORT_DIR" ]]; then
        echo "No exports directory found"
        return 0
    fi
    
    echo "Exported Contexts:"
    echo "================="
    
    find "$KCM_EXPORT_DIR" -name "*.yaml" -ls | while read -r line; do
        local file
        file=$(echo "$line" | awk '{print $NF}')
        local size
        size=$(echo "$line" | awk '{print $5}')
        local date
        date=$(echo "$line" | awk '{print $6, $7, $8}')
        local basename
        basename=$(basename "$file" .yaml)
        
        printf "%-40s %8s %s\n" "$basename" "${size}B" "$date"
    done
}

# User commands for export/import
kexport() {
    local action="$1"
    shift
    
    case "$action" in
        context)
            _kcm_export_context "$@"
            ;;
        contexts)
            _kcm_export_contexts "$@"
            ;;
        list|ls)
            _kcm_export_list
            ;;
        *)
            echo "Usage: kexport <action> [args]"
            echo ""
            echo "Actions:"
            echo "  context <name> [file]     - Export a single context"
            echo "  contexts <pattern> [file]  - Export contexts matching pattern"
            echo "  list|ls                   - List exported contexts"
            echo ""
            echo "Examples:"
            echo "  kexport context prod-cluster"
            echo "  kexport contexts 'prod.*' prod-config.yaml"
            echo "  kexport list"
            ;;
    esac
}

kimport() {
    local import_file="$1"
    local merge="${2:-false}"
    
    if [[ -z "$import_file" ]]; then
        echo "Usage: kimport <file> [--merge]"
        echo ""
        echo "Examples:"
        echo "  kimport ~/.kube-exports/prod-cluster_20240101.yaml"
        echo "  kimport ~/.kube-exports/contexts_prod_20240101.yaml --merge"
        return 1
    fi
    
    if [[ "$merge" == "--merge" ]]; then
        merge="true"
    fi
    
    _kcm_import_context "$import_file" "$merge"
}
