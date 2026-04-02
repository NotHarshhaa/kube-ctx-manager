#!/usr/bin/env bash

# backup.sh - Kubeconfig backup and restore functionality

# Backup configuration
export KCM_BACKUP_DIR="$HOME/.kube-backups"
export KCM_BACKUP_FORMAT="yaml"  # Can be yaml, json, or tar.gz

# Create backup directory
_kcm_ensure_backup_dir() {
    mkdir -p "$KCM_BACKUP_DIR"
}

# Generate backup filename with timestamp
_kcm_generate_backup_name() {
    local prefix="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local hostname
    hostname=$(hostname)
    echo "${prefix}_${hostname}_${timestamp}"
}

# Validate kubeconfig before backup
_kcm_validate_config_for_backup() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Config file not found: $config_file"
        return 1
    fi
    
    # Check if it's a valid kubeconfig
    if ! kubectl --kubeconfig="$config_file" config view --minimize >/dev/null 2>&1; then
        echo "Invalid kubeconfig: $config_file"
        return 1
    fi
    
    return 0
}

# Create backup of kubeconfig
kube-backup() {
    local config_file="${1:-$HOME/.kube/config}"
    local backup_name="$2"
    local format="${3:-$KCM_BACKUP_FORMAT}"
    
    _kcm_ensure_backup_dir
    
    if ! _kcm_validate_config_for_backup "$config_file"; then
        return 1
    fi
    
    # Generate backup name if not provided
    if [[ -z "$backup_name" ]]; then
        backup_name=$(_kcm_generate_backup_name "kubeconfig")
    fi
    
    local backup_file="$KCM_BACKUP_DIR/${backup_name}.${format}"
    
    echo "Creating backup: $backup_file"
    
    case "$format" in
        "yaml")
            cp "$config_file" "$backup_file"
            ;;
        "json")
            kubectl --kubeconfig="$config_file" config view --output=json > "$backup_file"
            ;;
        "tar.gz")
            local temp_dir
            temp_dir=$(mktemp -d)
            cp "$config_file" "$temp_dir/config.yaml"
            
            # Create metadata
            cat > "$temp_dir/metadata.json" << EOF
{
  "backup_name": "$backup_name",
  "timestamp": "$(date -Iseconds)",
  "hostname": "$(hostname)",
  "user": "$(whoami)",
  "contexts": $(kubectl --kubeconfig="$config_file" config get-contexts -o name | wc -l),
  "clusters": $(kubectl --kubeconfig="$config_file" config get-clusters -o name | wc -l),
  "users": $(kubectl --kubeconfig="$config_file" config get-users -o name | wc -l)
}
EOF
            
            tar -czf "$backup_file" -C "$temp_dir" .
            rm -rf "$temp_dir"
            ;;
        *)
            echo "Unsupported format: $format (use yaml, json, or tar.gz)"
            return 1
            ;;
    esac
    
    echo "✓ Backup created: $backup_file"
    
    # Show backup summary
    echo ""
    echo "Backup Summary:"
    echo "=============="
    echo "File: $backup_file"
    echo "Size: $(du -h "$backup_file" | cut -f1)"
    echo "Contexts: $(kubectl --kubeconfig="$config_file" config get-contexts --no-headers | wc -l)"
    echo "Clusters: $(kubectl --kubeconfig="$config_file" config get-clusters --no-headers | wc -l)"
    echo "Users: $(kubectl --kubeconfig="$config_file" config get-users --no-headers | wc -l)"
    
    # Show contexts
    echo ""
    echo "Contexts in backup:"
    kubectl --kubeconfig="$config_file" config get-contexts
}

# List available backups
kube-backup-list() {
    _kcm_ensure_backup_dir
    
    echo "Available kubeconfig backups:"
    echo "============================"
    
    local backup_count=0
    
    for backup_file in "$KCM_BACKUP_DIR"/*.{yaml,json,tar.gz}; do
        if [[ -f "$backup_file" ]]; then
            local basename
            basename=$(basename "$backup_file")
            local size
            size=$(du -h "$backup_file" | cut -f1)
            local date
            date=$(stat -c %y "$backup_file" 2>/dev/null || stat -f %Sm "$backup_file" 2>/dev/null)
            
            printf "%-40s %8s %s\n" "$basename" "$size" "$date"
            ((backup_count++))
        fi
    done
    
    if [[ $backup_count -eq 0 ]]; then
        echo "No backups found"
    else
        echo ""
        echo "Total backups: $backup_count"
        echo "Backup directory: $KCM_BACKUP_DIR"
    fi
}

# Restore from backup
kube-backup-restore() {
    local backup_name="$1"
    local target_file="${2:-$HOME/.kube/config}"
    local create_backup="${3:-yes}"
    
    if [[ -z "$backup_name" ]]; then
        echo "Usage: kube-backup-restore <backup-name> [target-file] [create-backup]"
        echo "Example: kube-backup-restore kubeconfig_myhost_20230402_120000"
        echo "Example: kube-backup-restore kubeconfig_prod_20230402_120000 ~/.kube/prod-config no"
        return 1
    fi
    
    # Find backup file
    local backup_file
    backup_file=$(find "$KCM_BACKUP_DIR" -name "${backup_name}.*" | head -1)
    
    if [[ -z "$backup_file" ]]; then
        echo "Backup not found: $backup_name"
        echo "Available backups:"
        kube-backup-list
        return 1
    fi
    
    echo "Restoring from: $backup_file"
    echo "Target: $target_file"
    
    # Create backup of current config before restoring
    if [[ "$create_backup" == "yes" && -f "$target_file" ]]; then
        local pre_restore_backup
        pre_restore_backup=$(_kcm_generate_backup_name "before_restore")
        echo "Creating pre-restore backup..."
        kube-backup "$target_file" "$pre_restore_backup"
    fi
    
    # Extract backup based on format
    local temp_file
    temp_file=$(mktemp)
    
    case "$backup_file" in
        *.tar.gz)
            echo "Extracting tar.gz backup..."
            tar -xzf "$backup_file" -C "$(dirname "$temp_file)" config.yaml 2>/dev/null || {
                echo "Failed to extract tar.gz backup"
                rm -f "$temp_file"
                return 1
            }
            mv "$(dirname "$temp_file")/config.yaml" "$temp_file"
            ;;
        *.json)
            echo "Converting JSON backup to YAML..."
            kubectl config --kubeconfig="$backup_file" view --output=yaml > "$temp_file"
            ;;
        *)
            cp "$backup_file" "$temp_file"
            ;;
    esac
    
    # Validate restored config
    if ! _kcm_validate_config_for_backup "$temp_file"; then
        echo "❌ Restored config validation failed"
        rm -f "$temp_file"
        return 1
    fi
    
    # Apply restored config
    mv "$temp_file" "$target_file"
    echo "✓ Kubeconfig restored successfully"
    
    # Show restored contexts
    echo ""
    echo "Restored contexts:"
    kubectl --kubeconfig="$target_file" config get-contexts
}

# Delete backup
kube-backup-delete() {
    local backup_pattern="$1"
    
    if [[ -z "$backup_pattern" ]]; then
        echo "Usage: kube-backup-delete <backup-pattern>"
        echo "Example: kube-backup-delete kubeconfig_prod_20230402_120000"
        echo "Example: kube-backup-delete '.*prod.*' (deletes all prod backups)"
        return 1
    fi
    
    _kcm_ensure_backup_dir
    
    local deleted_count=0
    local backup_files
    backup_files=$(find "$KCM_BACKUP_DIR" -name "${backup_pattern}.*")
    
    if [[ -z "$backup_files" ]]; then
        echo "No backups found matching pattern: $backup_pattern"
        return 1
    fi
    
    echo "Found backups to delete:"
    echo "$backup_files" | while read -r backup_file; do
        local basename
        basename=$(basename "$backup_file")
        echo "  $basename"
    done
    
    echo ""
    read -p "Delete these backups? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "$backup_files" | while read -r backup_file; do
            rm -f "$backup_file"
            echo "✓ Deleted: $(basename "$backup_file")"
            ((deleted_count++))
        done
        echo ""
        echo "Deleted $deleted_count backup files"
    else
        echo "Deletion cancelled"
    fi
}

# Clean old backups
kube-backup-clean() {
    local days="${1:-30}"
    local keep_count="${2:-10}"
    
    _kcm_ensure_backup_dir
    
    echo "Cleaning backups older than $days days (keeping at least $keep_count recent backups)..."
    
    # Delete backups older than specified days, but keep the most recent ones
    local total_backups
    total_backups=$(find "$KCM_BACKUP_DIR" -name "kubeconfig_*.*" | wc -l)
    
    if [[ $total_backups -le $keep_count ]]; then
        echo "Only $total_backups backups found (keeping all, minimum is $keep_count)"
        return 0
    fi
    
    # Find and delete old backups
    local deleted_count=0
    local backups_to_delete
    backups_to_delete=$(find "$KCM_BACKUP_DIR" -name "kubeconfig_*.*" -mtime +$days | sort -r | tail -n +$((keep_count + 1)))
    
    if [[ -n "$backups_to_delete" ]]; then
        echo "$backups_to_delete" | while read -r backup_file; do
            rm -f "$backup_file"
            echo "✓ Deleted: $(basename "$backup_file")"
            ((deleted_count++))
        done
        echo ""
        echo "Deleted $deleted_count old backup files"
    else
        echo "No backups older than $days days found"
    fi
}

# Compare two backups
kube-backup-diff() {
    local backup1="$1"
    local backup2="$2"
    
    if [[ -z "$backup1" || -z "$backup2" ]]; then
        echo "Usage: kube-backup-diff <backup1> <backup2>"
        echo "Example: kube-backup-diff kubeconfig_prod_20230402_120000 kubeconfig_staging_20230402_120000"
        return 1
    fi
    
    # Find backup files
    local file1
    local file2
    file1=$(find "$KCM_BACKUP_DIR" -name "${backup1}.*" | head -1)
    file2=$(find "$KCM_BACKUP_DIR" -name "${backup2}.*" | head -1)
    
    if [[ -z "$file1" || -z "$file2" ]]; then
        echo "One or both backups not found"
        return 1
    fi
    
    echo "Comparing backups:"
    echo "Backup 1: $(basename "$file1")"
    echo "Backup 2: $(basename "$file2")"
    echo ""
    
    # Extract if tar.gz
    local temp1
    local temp2
    temp1=$(mktemp)
    temp2=$(mktemp)
    
    case "$file1" in
        *.tar.gz) tar -xzf "$file1" -C "$(dirname "$temp1)" config.yaml 2>/dev/null && mv "$(dirname "$temp1")/config.yaml" "$temp1" ;;
        *.json) kubectl config --kubeconfig="$file1" view --output=yaml > "$temp1" ;;
        *) cp "$file1" "$temp1" ;;
    esac
    
    case "$file2" in
        *.tar.gz) tar -xzf "$file2" -C "$(dirname "$temp2)" config.yaml 2>/dev/null && mv "$(dirname "$temp2")/config.yaml" "$temp2" ;;
        *.json) kubectl config --kubeconfig="$file2" view --output=yaml > "$temp2" ;;
        *) cp "$file2" "$temp2" ;;
    esac
    
    # Compare contexts
    echo "Contexts comparison:"
    echo "=================="
    
    local contexts1
    local contexts2
    contexts1=$(kubectl --kubeconfig="$temp1" config get-contexts -o name | sort)
    contexts2=$(kubectl --kubeconfig="$temp2" config get-contexts -o name | sort)
    
    echo "Only in backup 1:"
    comm -23 <(echo "$contexts1") <(echo "$contexts2") | sed 's/^/  /'
    
    echo ""
    echo "Only in backup 2:"
    comm -13 <(echo "$contexts1") <(echo "$contexts2") | sed 's/^/  /'
    
    echo ""
    echo "Common contexts:"
    comm -12 <(echo "$contexts1") <(echo "$contexts2") | sed 's/^/  /'
    
    # Clean up
    rm -f "$temp1" "$temp2"
}

# Schedule automatic backups
kube-backup-schedule() {
    local interval="${1:-daily}"
    local max_backups="${2:-30}"
    
    echo "Setting up automatic kubeconfig backups..."
    
    # Create cron job
    local cron_entry
    case "$interval" in
        "hourly")
            cron_entry="0 * * * *"
            ;;
        "daily")
            cron_entry="0 2 * * *"
            ;;
        "weekly")
            cron_entry="0 2 * * 0"
            ;;
        "monthly")
            cron_entry="0 2 1 * *"
            ;;
        *)
            echo "Invalid interval: $interval (use hourly, daily, weekly, monthly)"
            return 1
            ;;
    esac
    
    cron_entry="$cron_entry KCM_BACKUP_DIR=$KCM_BACKUP_DIR /bin/bash -c 'source ~/.kube-ctx-manager/kube-ctx-manager.bash && kube-backup && kube-backup-clean 7 $max_backups'"
    
    echo "Cron entry to add:"
    echo "$cron_entry"
    echo ""
    read -p "Add this cron job? [y/N] " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
        echo "✓ Automatic backup scheduled"
        echo "Backups will be created $interval and kept for at most $max_backups"
    else
        echo "Scheduling cancelled"
    fi
}
