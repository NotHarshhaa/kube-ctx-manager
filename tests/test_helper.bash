#!/usr/bin/env bash

# test_helper.bash - Common test helper functions for bats tests

# Helper to mock commands
mock_command() {
    local command="$1"
    local output="$2"
    local exit_code="${3:-0}"
    
    eval "$command() { echo '$output'; return $exit_code; }"
}

# Helper to create temporary kubeconfig
create_test_kubeconfig() {
    local kubeconfig_file="$1"
    cat > "$kubeconfig_file" << EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    server: https://test-cluster.example.com
  name: test-cluster
contexts:
- context:
    cluster: test-cluster
    user: test-user
  name: test-context
- context:
    cluster: test-cluster
    user: test-user
  name: prod-context
current-context: test-context
users:
- name: test-user
  user:
    token: test-token
EOF
}

# Helper to check if function exists
function_exists() {
    declare -f "$1" >/dev/null
}

# Helper to check if variable exists
variable_exists() {
    [[ -n "${!1+x}" ]]
}

# Helper to compare arrays
arrays_match() {
    local -n arr1=$1
    local -n arr2=$2
    
    if [[ ${#arr1[@]} -ne ${#arr2[@]} ]]; then
        return 1
    fi
    
    for i in "${!arr1[@]}"; do
        if [[ "${arr1[$i]}" != "${arr2[$i]}" ]]; then
            return 1
        fi
    done
    
    return 0
}

# Helper to wait for file to exist
wait_for_file() {
    local file="$1"
    local timeout="${2:-5}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if [[ -f "$file" ]]; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    return 1
}

# Helper to create mock fzf
create_mock_fzf() {
    local selection="$1"
    
    fzf() {
        echo "$selection"
    }
}

# Helper to create mock jq (if needed)
create_mock_jq() {
    local output="$1"
    
    jq() {
        echo "$output"
    }
}

# Setup common test environment
setup_test_env() {
    export BATS_TMPDIR="${BATS_TMPDIR:-/tmp}"
    export KCM_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export KCM_USAGE_FILE="$BATS_TMPDIR/kube-usage"
    export KCM_ALIASES_FILE="$BATS_TMPDIR/kube-aliases"
    export KCM_AUDIT_LOG="$BATS_TMPDIR/audit.log"
    export KCM_PROD_PATTERN="prod|production|live|prd"
    export KCM_SUGGEST_THRESHOLD=3
    export KCM_PROMPT=1
    export KCM_PROMPT_STYLE="full"
}

# Cleanup common test environment
cleanup_test_env() {
    rm -f "$KCM_USAGE_FILE" "$KCM_ALIASES_FILE" "$KCM_AUDIT_LOG"
    unset KCM_DIR KCM_USAGE_FILE KCM_ALIASES_FILE KCM_AUDIT_LOG
    unset KCM_PROD_PATTERN KCM_SUGGEST_THRESHOLD KCM_PROMPT KCM_PROMPT_STYLE
}
