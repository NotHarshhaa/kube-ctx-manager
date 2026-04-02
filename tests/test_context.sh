#!/usr/bin/env bats

# test_context.sh - Tests for context switching functionality

load test_helper

setup() {
    # Setup test environment
    export KCM_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export KCM_USAGE_FILE="$BATS_TMPDIR/kube-usage"
    export KCM_ALIASES_FILE="$BATS_TMPDIR/kube-aliases"
    export KCM_AUDIT_LOG="$BATS_TMPDIR/audit.log"
    
    # Source the context module
    source "$KCM_DIR/lib/context.sh"
    
    # Mock kubectl for testing
    kubectl() {
        case "$1" in
            config)
                case "$2" in
                    current-context)
                        echo "test-context"
                        ;;
                    use-context)
                        return 0
                        ;;
                    get-contexts)
                        echo -e "test-context\nprod-context\nstaging-context"
                        ;;
                    view)
                        case "$3" in
                            --minify)
                                echo "default"
                                ;;
                        esac
                        ;;
                    set-context)
                        return 0
                        ;;
                esac
                ;;
            get)
                if [[ "$2" == "namespaces" ]]; then
                    echo -e "default\nkube-system\nmonitoring"
                fi
                ;;
        esac
    }
}

teardown() {
    # Clean up test files
    rm -f "$KCM_USAGE_FILE" "$KCM_ALIASES_FILE" "$KCM_AUDIT_LOG"
}

@test "_kcm_get_current_context returns current context" {
    run _kcm_get_current_context
    [ "$status" -eq 0 ]
    [ "$output" = "test-context" ]
}

@test "_kcm_get_current_namespace returns current namespace" {
    run _kcm_get_current_namespace
    [ "$status" -eq 0 ]
    [ "$output" = "default" ]
}

@test "_kcm_list_contexts lists all contexts" {
    run _kcm_list_contexts
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "test-context" ]
    [ "${lines[1]}" = "prod-context" ]
    [ "${lines[2]}" = "staging-context" ]
}

@test "_kcm_list_namespaces lists all namespaces" {
    run _kcm_list_namespaces
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "default" ]
    [ "${lines[1]}" = "kube-system" ]
    [ "${lines[2]}" = "monitoring" ]
}

@test "_kcm_switch_context switches to specified context" {
    run _kcm_switch_context "prod-context"
    [ "$status" -eq 0 ]
    [ "$output" = "Switched to context: prod-context" ]
}

@test "_kcm_switch_context handles previous context switch" {
    export KCM_PREV_CONTEXT="old-context"
    run _kcm_switch_context "-"
    [ "$status" -eq 0 ]
    [ "$output" = "Switched to context: old-context" ]
}

@test "_kcm_switch_context fails when no previous context" {
    unset KCM_PREV_CONTEXT
    run _kcm_switch_context "-"
    [ "$status" -eq 1 ]
    [ "$output" = "No previous context to switch to" ]
}

@test "_kcm_switch_namespace switches to specified namespace" {
    run _kcm_switch_namespace "kube-system"
    [ "$status" -eq 0 ]
    [ "$output" = "Switched to namespace: kube-system" ]
}

@test "kx switches directly when context specified" {
    run kx "staging-context"
    [ "$status" -eq 0 ]
    [ "$output" = "Switched to context: staging-context" ]
}

@test "kx fails gracefully without fzf" {
    # Mock fzf as not available
    command -v fzf() { return 1; }
    
    run kx
    [ "$status" -eq 1 ]
    [ "$output" = "fzf is required for fuzzy context selection" ]
}

@test "kns switches directly when namespace specified" {
    run kns "monitoring"
    [ "$status" -eq 0 ]
    [ "$output" = "Switched to namespace: monitoring" ]
}

@test "kns fails gracefully without fzf" {
    # Mock fzf as not available
    command -v fzf() { return 1; }
    
    run kns
    [ "$status" -eq 1 ]
    [ "$output" = "fzf is required for fuzzy namespace selection" ]
}
