#!/usr/bin/env bash

# cache.sh - Advanced caching and performance optimization

# Cache configuration
export KCM_CACHE_DIR="$HOME/.kube-cache"
export KCM_CACHE_DEFAULT_TTL=300  # 5 minutes
export KCM_CACHE_MAX_SIZE=10485760  # 10MB
export KCM_CACHE_CLEANUP_INTERVAL=3600  # 1 hour

# Cache statistics
declare -A KCM_CACHE_STATS
KCM_CACHE_STATS[hits]=0
KCM_CACHE_STATS[misses]=0
KCM_CACHE_STATS[evictions]=0
KCM_CACHE_STATS[size]=0

# Initialize cache system
_kcm_init_cache() {
    # Check if cache is enabled
    if [[ "${KCM_ENABLE_CACHE:-1}" != "1" ]]; then
        return 0
    fi
    
    mkdir -p "$KCM_CACHE_DIR"
    chmod 700 "$KCM_CACHE_DIR"
    
    # Load cache statistics
    local stats_file="$KCM_CACHE_DIR/stats"
    if [[ -f "$stats_file" ]]; then
        source "$stats_file"
    fi
    
    # Cleanup old cache files periodically
    _kcm_cache_cleanup_if_needed
}

# Generate cache key
_kcm_cache_key() {
    local prefix="$1"
    shift
    local args="$*"
    
    # Create a hash of the arguments
    local key
    if command -v sha256sum >/dev/null 2>&1; then
        key=$(echo "${prefix}:${args}" | sha256sum | cut -d' ' -f1)
    elif command -v md5sum >/dev/null 2>&1; then
        key=$(echo "${prefix}:${args}" | md5sum | cut -d' ' -f1)
    else
        # Fallback to simple string
        key="${prefix}_${args//[^a-zA-Z0-9]/_}"
    fi
    
    echo "$key"
}

# Get cache file path
_kcm_cache_file() {
    local key="$1"
    echo "$KCM_CACHE_DIR/${key}.cache"
}

# Check if cache is valid
_kcm_cache_is_valid() {
    local cache_file="$1"
    local ttl="${2:-$KCM_CACHE_DEFAULT_TTL}"
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local cache_time
    cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    local current_time
    current_time=$(date +%s)
    
    if [[ $((current_time - cache_time)) -gt $ttl ]]; then
        return 1
    fi
    
    return 0
}

# Get data from cache
_kcm_cache_get() {
    # Check if cache is enabled
    if [[ "${KCM_ENABLE_CACHE:-1}" != "1" ]]; then
        return 1
    fi
    
    local key="$1"
    local ttl="${2:-$KCM_CACHE_DEFAULT_TTL}"
    
    local cache_file
    cache_file=$(_kcm_cache_file "$key")
    
    if _kcm_cache_is_valid "$cache_file" "$ttl"; then
        local data
        data=$(cat "$cache_file")
        ((KCM_CACHE_STATS[hits]++))
        _kcm_log "DEBUG" "Cache hit: $key"
        echo "$data"
        return 0
    else
        ((KCM_CACHE_STATS[misses]++))
        _kcm_log "DEBUG" "Cache miss: $key"
        return 1
    fi
}

# Set data in cache
_kcm_cache_set() {
    # Check if cache is enabled
    if [[ "${KCM_ENABLE_CACHE:-1}" != "1" ]]; then
        return 0
    fi
    
    local key="$1"
    local data="$2"
    local ttl="${3:-$KCM_CACHE_DEFAULT_TTL}"
    
    local cache_file
    cache_file=$(_kcm_cache_file "$key")
    
    # Check cache size limit
    _kcm_cache_check_size
    
    # Redact sensitive data before caching
    local redacted_data
    redacted_data=$(_kcm_redact_sensitive_data "$data")
    
    # Write data with metadata
    local temp_file
    temp_file=$(_kcm_mktemp cache_set)
    {
        echo "# Cache entry created: $(date)"
        echo "# TTL: $ttl seconds"
        echo "# Size: $(echo "$data" | wc -c) bytes"
        echo "---"
        echo "$redacted_data"
    } > "$temp_file"
    
    mv "$temp_file" "$cache_file"
    chmod 600 "$cache_file"
    
    _kcm_log "DEBUG" "Cache set: $key ($(echo "$data" | wc -c) bytes)"
}

# Delete cache entry
_kcm_cache_delete() {
    local key="$1"
    
    local cache_file
    cache_file=$(_kcm_cache_file "$key")
    
    if [[ -f "$cache_file" ]]; then
        rm -f "$cache_file"
        _kcm_log "DEBUG" "Cache deleted: $key"
    fi
}

# Clear all cache
_kcm_cache_clear() {
    local pattern="${1:-*}"
    
    local deleted_count
    deleted_count=$(find "$KCM_CACHE_DIR" -name "${pattern}.cache" -delete -print 2>/dev/null | wc -l)
    
    _kcm_log "INFO" "Cache cleared: $deleted_count entries"
    echo "✓ Cleared $deleted_count cache entries"
}

# Check cache size and cleanup if needed
_kcm_cache_check_size() {
    local current_size
    current_size=$(du -sb "$KCM_CACHE_DIR" 2>/dev/null | cut -f1 || echo 0)
    
    if [[ $current_size -gt $KCM_CACHE_MAX_SIZE ]]; then
        _kcm_log "INFO" "Cache size limit reached (${current_size} bytes), performing cleanup"
        _kcm_cache_cleanup
    fi
}

# Cleanup old cache files
_kcm_cache_cleanup() {
    local deleted_count=0
    
    # Find and remove old cache files
    while IFS= read -r -d '' cache_file; do
        local cache_time
        cache_time=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        local current_time
        current_time=$(date +%s)
        
        # Remove files older than TTL
        if [[ $((current_time - cache_time)) -gt $KCM_CACHE_DEFAULT_TTL ]]; then
            rm -f "$cache_file"
            ((deleted_count++))
            ((KCM_CACHE_STATS[evictions]++))
        fi
    done < <(find "$KCM_CACHE_DIR" -name "*.cache" -print0 2>/dev/null)
    
    _kcm_log "INFO" "Cache cleanup completed: $deleted_count files removed"
}

# Cleanup if needed (based on time since last cleanup)
_kcm_cache_cleanup_if_needed() {
    local last_cleanup_file="$KCM_CACHE_DIR/.last_cleanup"
    local current_time
    current_time=$(date +%s)
    
    if [[ -f "$last_cleanup_file" ]]; then
        local last_cleanup
        last_cleanup=$(cat "$last_cleanup_file")
        if [[ $((current_time - last_cleanup)) -lt $KCM_CACHE_CLEANUP_INTERVAL ]]; then
            return 0
        fi
    fi
    
    _kcm_cache_cleanup
    echo "$current_time" > "$last_cleanup_file"
}

# Get cache statistics
_kcm_cache_stats() {
    echo "Cache Statistics:"
    echo "================"
    echo "Hits: ${KCM_CACHE_STATS[hits]}"
    echo "Misses: ${KCM_CACHE_STATS[misses]}"
    echo "Evictions: ${KCM_CACHE_STATS[evictions]}"
    
    local hit_rate=0
    local total_requests=$((KCM_CACHE_STATS[hits] + KCM_CACHE_STATS[misses]))
    if [[ $total_requests -gt 0 ]]; then
        hit_rate=$((KCM_CACHE_STATS[hits] * 100 / total_requests))
    fi
    
    echo "Hit rate: ${hit_rate}%"
    
    local cache_size
    cache_size=$(du -sh "$KCM_CACHE_DIR" 2>/dev/null | cut -f1 || echo "0")
    echo "Cache size: $cache_size"
    
    local cache_files
    cache_files=$(find "$KCM_CACHE_DIR" -name "*.cache" | wc -l)
    echo "Cache files: $cache_files"
}

# Save cache statistics
_kcm_cache_save_stats() {
    local stats_file="$KCM_CACHE_DIR/stats"
    
    cat > "$stats_file" << EOF
# Cache statistics
KCM_CACHE_STATS[hits]=${KCM_CACHE_STATS[hits]}
KCM_CACHE_STATS[misses]=${KCM_CACHE_STATS[misses]}
KCM_CACHE_STATS[evictions]=${KCM_CACHE_STATS[evictions]}
KCM_CACHE_STATS[size]=${KCM_CACHE_STATS[size]}
EOF
}

# Parallel execution helper
_kcm_parallel_execute() {
    local max_jobs="${1:-4}"
    shift
    local commands=("$@")
    
    _kcm_log "DEBUG" "Executing ${#commands[@]} commands in parallel (max jobs: $max_jobs)"
    
    local job_count=0
    local pids=()
    
    for cmd in "${commands[@]}"; do
        # Wait for available slot
        while [[ ${#pids[@]} -ge $max_jobs ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset "pids[$i]"
                    pids=("${pids[@]}")
                    break
                fi
            done
            [[ ${#pids[@]} -ge $max_jobs ]] && sleep 0.1
        done
        
        # Start job in background
        (
            eval "$cmd"
        ) &
        pids+=("$!")
        ((job_count++))
        
        _kcm_show_progress "$job_count" "${#commands[@]}" "Executing commands"
    done
    
    # Wait for all jobs to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    
    _kcm_log "DEBUG" "Parallel execution completed: $job_count jobs"
}

# Cached kubectl execution
_kcm_cached_kubectl() {
    # Check if cache is enabled
    if [[ "${KCM_ENABLE_CACHE:-1}" != "1" ]]; then
        kubectl "$@"
        return $?
    fi
    
    local cache_key
    cache_key=$(_kcm_cache_key "kubectl" "$*")
    local ttl="${KCM_CACHE_DEFAULT_TTL}"
    
    # Check cache first
    local cached_result
    if cached_result=$(_kcm_cache_get "$cache_key" "$ttl"); then
        echo "$cached_result"
        return 0
    fi
    
    # Execute command and cache result
    local result
    if result=$(kubectl "$@" 2>&1); then
        # Don't cache commands that likely contain sensitive data
        if [[ "$*" =~ (secret|configmap|token|password) ]]; then
            echo "$result"
            return 0
        fi
        _kcm_cache_set "$cache_key" "$result" "$ttl"
        echo "$result"
        return 0
    else
        # Don't cache errors
        echo "$result"
        return 1
    fi
}

# Batch context health check with caching
_kcm_batch_health_check() {
    local contexts=("$@")
    local timeout="${1:-10}"
    local max_jobs="${2:-4}"
    
    _kcm_log "INFO" "Performing batch health check on ${#contexts[@]} contexts"
    
    local commands=()
    for context in "${contexts[@]}"; do
        commands+=("_kcm_check_context_health_cached '$context' '$timeout'")
    done
    
    _kcm_parallel_execute "$max_jobs" "${commands[@]}"
}

# Cached context health check
_kcm_check_context_health_cached() {
    local context="$1"
    local timeout="${2:-10}"
    
    local cache_key
    cache_key=$(_kcm_cache_key "health" "$context")
    local ttl=60  # Health data expires after 1 minute
    
    # Check cache first
    local cached_result
    if cached_result=$(_kcm_cache_get "$cache_key" "$ttl"); then
        echo "$cached_result"
        return 0
    fi
    
    # Perform health check
    local result
    if result=$(_kcm_safe_execute "$timeout" "kubectl --context='$context' cluster-info"); then
        local health_result="healthy:0"
        echo "$health_result"
        _kcm_cache_set "$cache_key" "$health_result" "$ttl"
        return 0
    else
        local health_result="unhealthy:0"
        echo "$health_result"
        _kcm_cache_set "$cache_key" "$health_result" "$ttl"
        return 1
    fi
}

# Cache warming function
_kcm_cache_warm() {
    local contexts
    contexts=$(kubectl config get-contexts -o name | sed 's/^.*\///')
    
    echo "Warming cache for contexts..."
    local count=0
    local total
    total=$(echo "$contexts" | wc -l)
    
    while IFS= read -r context; do
        # Warm health cache
        _kcm_check_context_health_cached "$context" 10 >/dev/null &
        
        ((count++))
        _kcm_show_progress "$count" "$total" "Warming cache"
        
        # Limit concurrent jobs
        if [[ $((count % 4)) -eq 0 ]]; then
            wait
        fi
    done <<< "$contexts"
    
    wait
    echo ""
    echo "✓ Cache warming completed"
}

# Initialize cache system when sourced
_kcm_init_cache
