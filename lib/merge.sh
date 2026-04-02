#!/usr/bin/env bash

# merge.sh - Kubeconfig merging and management utilities

# Backup directory for merged configs
export KCM_MERGE_BACKUP_DIR="$HOME/.kube-merge-backups"

# Create backup of current kubeconfig
_kcm_backup_kubeconfig() {
    local backup_name="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_file="$KCM_MERGE_BACKUP_DIR/kubeconfig_${backup_name}_${timestamp}.yaml"
    
    mkdir -p "$KCM_MERGE_BACKUP_DIR"
    
    if [[ -f "$HOME/.kube/config" ]]; then
        cp "$HOME/.kube/config" "$backup_file"
        echo "$backup_file"
    else
        echo "No kubeconfig found to backup"
        return 1
    fi
}

# Validate kubeconfig file
_kcm_validate_kubeconfig() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Kubeconfig file not found: $config_file"
        return 1
    fi
    
    # Check if it's valid YAML
    if command -v yq >/dev/null 2>&1; then
        if ! yq eval '.' "$config_file" >/dev/null 2>&1; then
            echo "Invalid YAML in kubeconfig: $config_file"
            return 1
        fi
    elif command -v python >/dev/null 2>&1; then
        if ! python -c "import yaml; yaml.safe_load(open('$config_file'))" 2>/dev/null; then
            echo "Invalid YAML in kubeconfig: $config_file"
            return 1
        fi
    else
        # Basic validation - check for required keys
        if ! grep -q "apiVersion: v1" "$config_file" || ! grep -q "kind: Config" "$config_file"; then
            echo "Invalid kubeconfig format: $config_file"
            return 1
        fi
    fi
    
    return 0
}

# Merge multiple kubeconfig files
kube-merge() {
    local output_file="${1:-$HOME/.kube/config}"
    local backup_name="before_merge_$(date +%s)"
    shift
    
    if [[ $# -eq 0 ]]; then
        echo "Usage: kube-merge <output-file> <config1> <config2> ..."
        echo "Example: kube-merge ~/.kube/merged-config.yaml config1.yaml config2.yaml"
        echo "Example: kube-merge ~/.kube/config (uses KUBECONFIG env var)"
        return 1
    fi
    
    # Create backup
    local backup_file
    backup_file=$(_kcm_backup_kubeconfig "$backup_name")
    echo "Created backup: $backup_file"
    
    # Validate all input files
    echo "Validating kubeconfig files..."
    for config_file in "$@"; do
        if ! _kcm_validate_kubeconfig "$config_file"; then
            echo "❌ Validation failed for: $config_file"
            return 1
        fi
        echo "✓ Valid: $config_file"
    done
    
    # Create temporary merged config
    local temp_merged
    temp_merged=$(mktemp)
    
    # Initialize with first file
    cp "$1" "$temp_merged"
    shift
    
    # Merge remaining files
    for config_file in "$@"; do
        echo "Merging: $config_file"
        
        if command -v yq >/dev/null 2>&1; then
            # Use yq for proper merging
            yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' "$temp_merged" "$config_file" > "${temp_merged}.new"
            mv "${temp_merged}.new" "$temp_merged"
        else
            # Fallback to simple concatenation (less reliable)
            echo "Warning: yq not found, using simple concatenation"
            echo "---" >> "$temp_merged"
            cat "$config_file" >> "$temp_merged"
        fi
    done
    
    # Validate merged config
    if ! _kcm_validate_kubeconfig "$temp_merged"; then
        echo "❌ Merged config validation failed"
        rm -f "$temp_merged"
        return 1
    fi
    
    # Apply merged config
    mv "$temp_merged" "$output_file"
    echo "✓ Merged config written to: $output_file"
    
    # Show merge summary
    echo ""
    echo "Merge Summary:"
    echo "============="
    echo "Contexts in merged config:"
    kubectl --kubeconfig="$output_file" config get-contexts -o name
    
    echo ""
    echo "Clusters in merged config:"
    kubectl --kubeconfig="$output_file" config get-clusters -o name
    
    echo ""
    echo "Users in merged config:"
    kubectl --kubeconfig="$output_file" config get-users -o name
}

# Merge from KUBECONFIG environment variable
kube-merge-env() {
    local output_file="${1:-$HOME/.kube/config}"
    
    if [[ -z "$KUBECONFIG" ]]; then
        echo "KUBECONFIG environment variable not set"
        echo "Usage: export KUBECONFIG=~/.kube/config1:~/.kube/config2:... && kube-merge-env"
        return 1
    fi
    
    echo "Merging from KUBECONFIG: $KUBECONFIG"
    
    # Split KUBECONFIG and merge
    local configs
    IFS=':' read -ra configs <<< "$KUBECONFIG"
    
    kube-merge "$output_file" "${configs[@]}"
}

# Extract contexts from kubeconfig
kube-extract() {
    local source_config="${1:-$HOME/.kube/config}"
    local context_pattern="$2"
    local output_file="$3"
    
    if [[ -z "$context_pattern" || -z "$output_file" ]]; then
        echo "Usage: kube-extract <source-config> <context-pattern> <output-file>"
        echo "Example: kube-extract ~/.kube/config 'prod.*' ~/.kube/prod-config.yaml"
        return 1
    fi
    
    if ! _kcm_validate_kubeconfig "$source_config"; then
        return 1
    fi
    
    echo "Extracting contexts matching: $context_pattern"
    
    # Get matching contexts
    local matching_contexts
    matching_contexts=$(kubectl --kubeconfig="$source_config" config get-contexts -o name | grep "$context_pattern" | sed 's/^.*\///')
    
    if [[ -z "$matching_contexts" ]]; then
        echo "No contexts found matching pattern: $context_pattern"
        return 1
    fi
    
    echo "Found contexts:"
    echo "$matching_contexts"
    echo ""
    
    # Extract using kubectl config view
    if command -v yq >/dev/null 2>&1; then
        echo "Extracting with yq..."
        yq eval "
          .contexts |= map(select(.name | test(\"$context_pattern\"))) |
          .clusters |= map(select(.name | test(\"$context_pattern\"))) |
          .users |= map(select(.name | test(\"$context_pattern\"))) |
          .\"current-context\" = (.contexts[0].name // \"\")
        " "$source_config" > "$output_file"
    else
        echo "yq not found, using kubectl config view..."
        # Fallback method
        KUBECONFIG="$source_config" kubectl config view --raw > "$output_file"
    fi
    
    if _kcm_validate_kubeconfig "$output_file"; then
        echo "✓ Extracted config written to: $output_file"
    else
        echo "❌ Failed to create valid extracted config"
        return 1
    fi
}

# Split kubeconfig by context patterns
kube-split() {
    local source_config="${1:-$HOME/.kube/config}"
    local output_dir="${2:-$HOME/.kube/split}"
    
    if ! _kcm_validate_kubeconfig "$source_config"; then
        return 1
    fi
    
    mkdir -p "$output_dir"
    
    echo "Splitting kubeconfig by environment..."
    
    # Common patterns
    local patterns=("prod" "staging" "dev" "test")
    
    for pattern in "${patterns[@]}"; do
        local output_file="$output_dir/${pattern}-config.yaml"
        echo "Extracting $pattern contexts..."
        
        if kube-extract "$source_config" "$pattern" "$output_file"; then
            local context_count
            context_count=$(kubectl --kubeconfig="$output_file" config get-contexts --no-headers | wc -l)
            echo "✓ Created $output_file ($context_count contexts)"
        else
            echo "No $pattern contexts found"
        fi
    done
    
    echo ""
    echo "Split configs created in: $output_dir"
}

# Clean merge backups
kube-merge-clean() {
    local days="${1:-30}"
    
    if [[ ! -d "$KCM_MERGE_BACKUP_DIR" ]]; then
        echo "No backup directory found"
        return 1
    fi
    
    echo "Cleaning backups older than $days days..."
    
    local deleted_count
    deleted_count=$(find "$KCM_MERGE_BACKUP_DIR" -name "kubeconfig_*.yaml" -mtime +$days -delete -print | wc -l)
    
    echo "✓ Deleted $deleted_count old backup files"
}

# List merge backups
kube-merge-list() {
    if [[ ! -d "$KCM_MERGE_BACKUP_DIR" ]]; then
        echo "No backup directory found"
        return 1
    fi
    
    echo "Available kubeconfig backups:"
    echo "============================"
    
    find "$KCM_MERGE_BACKUP_DIR" -name "kubeconfig_*.yaml" -ls | while read -r line; do
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

# Restore from backup
kube-merge-restore() {
    local backup_pattern="$1"
    local target_file="${2:-$HOME/.kube/config}"
    
    if [[ -z "$backup_pattern" ]]; then
        echo "Usage: kube-merge-restore <backup-pattern> [target-file]"
        echo "Example: kube-merge-restore before_merge_1234567890"
        echo "Example: kube-merge-restore '.*prod.*' ~/.kube/prod-config.yaml"
        return 1
    fi
    
    local backup_file
    backup_file=$(find "$KCM_MERGE_BACKUP_DIR" -name "kubeconfig_${backup_pattern}*.yaml" | head -1)
    
    if [[ -z "$backup_file" ]]; then
        echo "No backup found matching pattern: $backup_pattern"
        return 1
    fi
    
    echo "Restoring from: $backup_file"
    echo "Target: $target_file"
    
    # Create backup of current config before restoring
    if [[ -f "$target_file" ]]; then
        local restore_backup
        restore_backup=$(_kcm_backup_kubeconfig "before_restore_$(date +%s)")
        echo "Created backup: $restore_backup"
    fi
    
    cp "$backup_file" "$target_file"
    echo "✓ Restored kubeconfig"
    
    # Show restored contexts
    echo ""
    echo "Restored contexts:"
    kubectl --kubeconfig="$target_file" config get-contexts
}
