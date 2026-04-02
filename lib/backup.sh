#!/usr/bin/env bash

# backup.sh - Kubeconfig backup and restore functionality

# Backup configuration
export KCM_BACKUP_DIR="$HOME/.kube-backups"
export KCM_BACKUP_FORMAT="yaml"

# Create backup of kubeconfig
kube-backup() {
    local config_file="${1:-$HOME/.kube/config}"
    local backup_name="$2"
    
    mkdir -p "$KCM_BACKUP_DIR"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Config file not found: $config_file"
        return 1
    fi
    
    # Generate backup name if not provided
    if [[ -z "$backup_name" ]]; then
        local timestamp
        timestamp=$(date '+%Y%m%d_%H%M%S')
        local hostname
        hostname=$(hostname)
        backup_name="kubeconfig_${hostname}_${timestamp}"
    fi
    
    local backup_file="$KCM_BACKUP_DIR/${backup_name}.yaml"
    
    echo "Creating backup: $backup_file"
    cp "$config_file" "$backup_file"
    echo "✓ Backup created: $backup_file"
    
    # Show backup summary
    echo ""
    echo "Backup Summary:"
    echo "=============="
    echo "File: $backup_file"
    echo "Size: $(du -h "$backup_file" | cut -f1)"
    echo "Contexts: $(kubectl --kubeconfig="$config_file" config get-contexts --no-headers | wc -l)"
}

# List available backups
kube-backup-list() {
    mkdir -p "$KCM_BACKUP_DIR"
    
    echo "Available kubeconfig backups:"
    echo "============================"
    
    local backup_count=0
    
    for backup_file in "$KCM_BACKUP_DIR"/*.yaml; do
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
    
    if [[ -z "$backup_name" ]]; then
        echo "Usage: kube-backup-restore <backup-name> [target-file]"
        echo "Example: kube-backup-restore kubeconfig_myhost_20230402_120000"
        return 1
    fi
    
    # Find backup file
    local backup_file
    backup_file=$(find "$KCM_BACKUP_DIR" -name "${backup_name}*.yaml" | head -1)
    
    if [[ -z "$backup_file" ]]; then
        echo "Backup not found: $backup_name"
        echo "Available backups:"
        kube-backup-list
        return 1
    fi
    
    echo "Restoring from: $backup_file"
    echo "Target: $target_file"
    
    # Create backup of current config before restoring
    if [[ -f "$target_file" ]]; then
        local pre_restore_backup
        pre_restore_backup="before_restore_$(date +%s)"
        echo "Creating pre-restore backup..."
        kube-backup "$target_file" "$pre_restore_backup"
    fi
    
    # Apply restored config
    cp "$backup_file" "$target_file"
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
        return 1
    fi
    
    mkdir -p "$KCM_BACKUP_DIR"
    
    local deleted_count=0
    local backup_files
    backup_files=$(find "$KCM_BACKUP_DIR" -name "${backup_pattern}*.yaml")
    
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
    
    mkdir -p "$KCM_BACKUP_DIR"
    
    echo "Cleaning backups older than $days days..."
    
    local deleted_count=0
    local backups_to_delete
    backups_to_delete=$(find "$KCM_BACKUP_DIR" -name "kubeconfig_*.yaml" -mtime +$days)
    
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
