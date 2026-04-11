#!/usr/bin/env bash

# bookmarks.sh - Context bookmarks and favorites functionality

# Bookmarks file
export KCM_BOOKMARKS_FILE="$HOME/.kube-bookmarks"

# Initialize bookmarks file
_kcm_init_bookmarks() {
    if [[ ! -f "$KCM_BOOKMARKS_FILE" ]]; then
        mkdir -p "$(dirname "$KCM_BOOKMARKS_FILE")"
        chmod 700 "$(dirname "$KCM_BOOKMARKS_FILE")"
        cat > "$KCM_BOOKMARKS_FILE" << EOF
# kube-ctx-manager bookmarks
# Format: <bookmark-name>:<context-name>:<description>:<tags>
# Example: prod-main:prod-eks-main:Production main cluster:prod,eks,us-east-1

EOF
        chmod 600 "$KCM_BOOKMARKS_FILE"
    fi
}

# Add a bookmark
kbookmark-add() {
    local bookmark_name="$1"
    local context_name="$2"
    local description="$3"
    local tags="$4"
    
    if [[ -z "$bookmark_name" || -z "$context_name" ]]; then
        echo "Usage: kbookmark-add <bookmark-name> <context-name> [description] [tags]"
        echo "Example: kbookmark-add prod-main prod-eks-main \"Production main cluster\" \"prod,eks,us-east-1\""
        return 1
    fi
    
    _kcm_init_bookmarks
    
    # Check if context exists
    if ! kubectl config get-contexts "$context_name" >/dev/null 2>&1; then
        echo "Context not found: $context_name"
        return 1
    fi
    
    # Check if bookmark already exists
    if grep -q "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE"; then
        echo "Bookmark already exists: $bookmark_name"
        echo "Use 'kbookmark-update' to update or 'kbookmark-delete' to remove first"
        return 1
    fi
    
    # Use default description if not provided
    if [[ -z "$description" ]]; then
        description="Bookmark for context: $context_name"
    fi
    
    # Add bookmark
    echo "${bookmark_name}:${context_name}:${description}:${tags}" >> "$KCM_BOOKMARKS_FILE"
    echo "✓ Added bookmark: $bookmark_name -> $context_name"
    
    # Show all bookmarks
    echo ""
    kbookmark-list
}

# List all bookmarks
kbookmark-list() {
    _kcm_init_bookmarks
    
    local bookmark_count
    bookmark_count=$(grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | wc -l)
    
    if [[ $bookmark_count -eq 0 ]]; then
        echo "No bookmarks found"
        return 0
    fi
    
    echo "Bookmarks ($bookmark_count):"
    echo "=================="
    printf "%-15s %-25s %-30s %s\n" "NAME" "CONTEXT" "DESCRIPTION" "TAGS"
    echo "--------------- ------------------------- ------------------------------ ----"
    
    local current_context
    current_context=$(kubectl config current-context 2>/dev/null)
    
    grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | while IFS=: read -r bookmark_name context_name description tags; do
        local current_marker=""
        if [[ "$context_name" == "$current_context" ]]; then
            current_marker="*"
        fi
        
        # Truncate long fields
        local short_desc="${description:0:30}"
        local short_tags="${tags:0:15}"
        
        printf "%s%-14s %-25s %-30s %s\n" "$current_marker" "$bookmark_name" "$context_name" "$short_desc" "$short_tags"
    done
    
    echo ""
    echo "* = current context"
}

# Switch to bookmarked context
kbookmark-go() {
    local bookmark_name="$1"
    
    if [[ -z "$bookmark_name" ]]; then
        echo "Usage: kbookmark-go <bookmark-name>"
        echo "Available bookmarks:"
        kbookmark-list
        return 1
    fi
    
    _kcm_init_bookmarks
    
    local bookmark_line
    bookmark_line=$(grep "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE")
    
    if [[ -z "$bookmark_line" ]]; then
        echo "Bookmark not found: $bookmark_name"
        echo "Available bookmarks:"
        kbookmark-list
        return 1
    fi
    
    local context_name
    context_name=$(echo "$bookmark_line" | cut -d: -f2)
    
    echo "Switching to bookmarked context: $bookmark_name -> $context_name"
    kx "$context_name"
}

# Interactive bookmark selection with fzf
kbookmark-interactive() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo "fzf is required for interactive bookmark selection"
        return 1
    fi
    
    _kcm_init_bookmarks
    
    local selected_bookmark
    selected_bookmark=$(grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Select bookmark> " \
        --header="Use arrow keys to navigate, Enter to switch context" \
        --preview="echo {} | cut -d: -f2 | xargs -I {} kubectl config view --minify --context={} --output=json 2>/dev/null | jq -r '.contexts[0].context | \"Cluster: \\(.cluster)\\nUser: \\(.user)\\nNamespace: \\(.namespace // \"default\")\"' 2>/dev/null || echo 'No details available'")
    
    if [[ -n "$selected_bookmark" ]]; then
        local bookmark_name
        bookmark_name=$(echo "$selected_bookmark" | cut -d: -f1)
        local context_name
        context_name=$(echo "$selected_bookmark" | cut -d: -f2)
        
        echo "Switching to bookmarked context: $bookmark_name -> $context_name"
        kx "$context_name"
    else
        echo "No bookmark selected"
    fi
}

# Search bookmarks
kbookmark-search() {
    local pattern="$1"
    local search_field="${2:-all}"  # all, name, context, description, tags
    
    if [[ -z "$pattern" ]]; then
        echo "Usage: kbookmark-search <pattern> [search-field]"
        echo "Search fields: all, name, context, description, tags"
        return 1
    fi
    
    _kcm_init_bookmarks
    
    echo "Searching bookmarks for: $pattern"
    echo ""
    
    local matches=0
    
    grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | while IFS=: read -r bookmark_name context_name description tags; do
        local match=0
        
        case "$search_field" in
            "all")
                if [[ "$bookmark_name" =~ $pattern || "$context_name" =~ $pattern || "$description" =~ $pattern || "$tags" =~ $pattern ]]; then
                    match=1
                fi
                ;;
            "name")
                if [[ "$bookmark_name" =~ $pattern ]]; then
                    match=1
                fi
                ;;
            "context")
                if [[ "$context_name" =~ $pattern ]]; then
                    match=1
                fi
                ;;
            "description")
                if [[ "$description" =~ $pattern ]]; then
                    match=1
                fi
                ;;
            "tags")
                if [[ "$tags" =~ $pattern ]]; then
                    match=1
                fi
                ;;
        esac
        
        if [[ $match -eq 1 ]]; then
            printf "%-15s %-25s %-30s %s\n" "$bookmark_name" "$context_name" "${description:0:30}" "$tags"
            ((matches++))
        fi
    done
    
    if [[ $matches -eq 0 ]]; then
        echo "No bookmarks found matching: $pattern"
    fi
}

# Update bookmark
kbookmark-update() {
    local bookmark_name="$1"
    local new_description="$2"
    local new_tags="$3"
    
    if [[ -z "$bookmark_name" ]]; then
        echo "Usage: kbookmark-update <bookmark-name> [new-description] [new-tags]"
        return 1
    fi
    
    _kcm_init_bookmarks
    
    if ! grep -q "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE"; then
        echo "Bookmark not found: $bookmark_name"
        return 1
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    grep -v "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE" > "$temp_file"
    
    local original_line
    original_line=$(grep "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE")
    local context_name
    context_name=$(echo "$original_line" | cut -d: -f2)
    local original_description
    original_description=$(echo "$original_line" | cut -d: -f3)
    local original_tags
    original_tags=$(echo "$original_line" | cut -d: -f4)
    
    # Use original values if new ones not provided
    [[ -z "$new_description" ]] && new_description="$original_description"
    [[ -z "$new_tags" ]] && new_tags="$original_tags"
    
    echo "${bookmark_name}:${context_name}:${new_description}:${new_tags}" >> "$temp_file"
    
    mv "$temp_file" "$KCM_BOOKMARKS_FILE"
    echo "✓ Updated bookmark: $bookmark_name"
    
    echo ""
    kbookmark-list
}

# Delete bookmark
kbookmark-delete() {
    local bookmark_name="$1"
    
    if [[ -z "$bookmark_name" ]]; then
        echo "Usage: kbookmark-delete <bookmark-name>"
        echo "Available bookmarks:"
        kbookmark-list
        return 1
    fi
    
    _kcm_init_bookmarks
    
    if ! grep -q "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE"; then
        echo "Bookmark not found: $bookmark_name"
        return 1
    fi
    
    local temp_file
    temp_file=$(mktemp)
    
    grep -v "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE" > "$temp_file"
    mv "$temp_file" "$KCM_BOOKMARKS_FILE"
    
    echo "✓ Deleted bookmark: $bookmark_name"
    
    echo ""
    kbookmark-list
}

# Export bookmarks to share
kbookmark-export() {
    local export_file="${1:-$HOME/kube-bookmarks-export.yaml}"
    
    _kcm_init_bookmarks
    
    echo "Exporting bookmarks to: $export_file"
    
    cat > "$export_file" << EOF
# kube-ctx-manager bookmarks export
# Generated on: $(date)
# Import with: kbookmark-import <file>

apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-bookmarks
  labels:
    app: kube-ctx-manager
    component: bookmarks
data:
  bookmarks.yaml: |
EOF
    
    grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | while IFS=: read -r bookmark_name context_name description tags; do
        echo "    ${bookmark_name}:${context_name}:${description}:${tags}" >> "$export_file"
    done
    
    echo "✓ Exported $(grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | wc -l) bookmarks"
}

# Import bookmarks from file
kbookmark-import() {
    local import_file="$1"
    
    if [[ -z "$import_file" || ! -f "$import_file" ]]; then
        echo "Usage: kbookmark-import <export-file>"
        return 1
    fi
    
    _kcm_init_bookmarks
    
    echo "Importing bookmarks from: $import_file"
    
    local imported_count=0
    local skipped_count=0
    
    # Handle both plain text and YAML formats
    if grep -q "bookmarks.yaml:" "$import_file"; then
        # YAML export format
        grep -E "^    [^#].*:.*:" "$import_file" | sed 's/^    //' | while IFS=: read -r bookmark_name context_name description tags; do
            if grep -q "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE"; then
                echo "⚠️  Skipping existing bookmark: $bookmark_name"
                ((skipped_count++))
            else
                echo "${bookmark_name}:${context_name}:${description}:${tags}" >> "$KCM_BOOKMARKS_FILE"
                echo "✓ Imported: $bookmark_name"
                ((imported_count++))
            fi
        done
    else
        # Plain text format
        grep -v '^#' "$import_file" | grep -v '^$' | while IFS=: read -r bookmark_name context_name description tags; do
            if grep -q "^${bookmark_name}:" "$KCM_BOOKMARKS_FILE"; then
                echo "⚠️  Skipping existing bookmark: $bookmark_name"
                ((skipped_count++))
            else
                echo "${bookmark_name}:${context_name}:${description}:${tags}" >> "$KCM_BOOKMARKS_FILE"
                echo "✓ Imported: $bookmark_name"
                ((imported_count++))
            fi
        done
    fi
    
    echo ""
    echo "Import completed: $imported_count imported, $skipped_count skipped"
    
    echo ""
    kbookmark-list
}

# Show bookmark statistics
kbookmark-stats() {
    _kcm_init_bookmarks
    
    local total_bookmarks
    total_bookmarks=$(grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | wc -l)
    
    if [[ $total_bookmarks -eq 0 ]]; then
        echo "No bookmarks found"
        return 0
    fi
    
    echo "Bookmark Statistics:"
    echo "==================="
    echo "Total bookmarks: $total_bookmarks"
    
    echo ""
    echo "Contexts with bookmarks:"
    grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | cut -d: -f2 | sort | uniq -c | sort -nr
    
    echo ""
    echo "Tag usage:"
    grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | cut -d: -f4 | tr ',' '\n' | grep -v '^$' | sort | uniq -c | sort -nr
    
    echo ""
    echo "Bookmarks by context availability:"
    grep -v '^#' "$KCM_BOOKMARKS_FILE" | grep -v '^$' | while IFS=: read -r bookmark_name context_name description tags; do
        local status="❌"
        if kubectl config get-contexts "$context_name" >/dev/null 2>&1; then
            status="✅"
        fi
        printf "%s %-15s -> %s\n" "$status" "$bookmark_name" "$context_name"
    done
}

# Auto-bookmark frequently used contexts
kbookmark-auto() {
    local min_usage="${1:-5}"  # Minimum usage count to auto-bookmark
    
    if [[ ! -f "$KCM_AUDIT_LOG" ]]; then
        echo "No audit log found: $KCM_AUDIT_LOG"
        echo "Auto-bookmarking requires audit logging to be enabled"
        return 1
    fi
    
    echo "Auto-bookmarking frequently used contexts (usage >= $min_usage)"
    echo ""
    
    # Analyze usage from audit log
    grep "context=" "$KCM_AUDIT_LOG" | cut -d= -f2 | cut -d' ' -f1 | sort | uniq -c | sort -nr | while read -r count context; do
        if [[ $count -ge $min_usage ]]; then
            # Check if already bookmarked
            if grep -q ":${context_name}:" "$KCM_BOOKMARKS_FILE"; then
                echo "⚠️  Already bookmarked: $context (used $count times)"
            else
                # Generate bookmark name
                local bookmark_name
                bookmark_name=$(echo "$context" | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/^-*//' | sed 's/-*$//')
                
                # Generate description
                local description="Auto-bookmarked (used $count times)"
                
                # Generate tags from context name
                local tags
                tags=$(echo "$context" | grep -o -E '(prod|staging|dev|test|qa|eks|gke|aks|do|rancher)' | tr '\n' ',' | sed 's/,$//')
                
                echo "Adding bookmark: $bookmark_name -> $context"
                kbookmark-add "$bookmark_name" "$context" "$description" "$tags"
            fi
        fi
    done
    
    echo ""
    echo "Auto-bookmarking completed"
    kbookmark-stats
}
