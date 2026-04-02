#!/usr/bin/env bats

# test_suggester.sh - Tests for alias suggester functionality

load test_helper

setup() {
    # Setup test environment
    export KCM_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export KCM_USAGE_FILE="$BATS_TMPDIR/kube-usage"
    export KCM_ALIASES_FILE="$BATS_TMPDIR/kube-aliases"
    export KCM_AUDIT_LOG="$BATS_TMPDIR/audit.log"
    export KCM_SUGGEST_THRESHOLD=3
    
    # Source the suggester module
    source "$KCM_DIR/lib/suggester.sh"
    
    # Create sample usage data
    cat > "$KCM_USAGE_FILE" << EOF
1640995200:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995300:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995400:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995500:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995600:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995700:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995800:kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp
1640995900:kubectl logs -f deployment/api-server -n production
1640996000:kubectl logs -f deployment/api-server -n production
1640996100:kubectl logs -f deployment/api-server -n production
1640996200:kubectl describe pod mypod -n kube-system
1640996300:kubectl describe pod mypod -n kube-system
1640996400:kubectl describe pod mypod -n kube-system
1640996500:kubectl get pods
1640996600:kubectl get pods
1640996700:kubectl get pods
EOF
}

teardown() {
    # Clean up test files
    rm -f "$KCM_USAGE_FILE" "$KCM_ALIASES_FILE" "$KCM_AUDIT_LOG"
    unset KCM_SUGGEST_THRESHOLD
}

@test "_kcm_suggester_init creates usage file" {
    rm -f "$KCM_USAGE_FILE"
    run _kcm_suggester_init
    [ "$status" -eq 0 ]
    [ -f "$KCM_USAGE_FILE" ]
}

@test "_kcm_generate_alias_name creates meaningful aliases" {
    run _kcm_generate_alias_name "kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp"
    [ "$status" -eq 0 ]
    [ "$output" = "kgpmonsort" ]
    
    run _kcm_generate_alias_name "kubectl logs -f deployment/api-server -n production"
    [ "$status" -eq 0 ]
    [ "$output" = "klfdepapiprod" ]
    
    run _kcm_generate_alias_name "kubectl describe pod mypod -n kube-system"
    [ "$status" -eq 0 ]
    [ "$output" = "kdpmykub" ]
}

@test "_kcm_generate_alias_name handles simple commands" {
    run _kcm_generate_alias_name "kubectl get pods"
    [ "$status" -eq 0 ]
    [ "$output" = "kgppod" ]
    
    run _kcm_generate_alias_name "kubectl delete pod mypod"
    [ "$status" -eq 0 ]
    [ "$output" = "kdpmy" ]
}

@test "_kcm_suggest_aliases analyzes usage patterns" {
    run _kcm_suggest_aliases
    [ "$status" -eq 0 ]
    
    # Should suggest alias for the most frequently used command
    [ "${lines[1]}" = "You've run this 7 times:" ]
    [ "${lines[2]}" = "  kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp" ]
    [ "${lines[4]}" = "Suggested alias:" ]
    [ "${lines[5]}" = "  alias kgpmonsort='kubectl get pods -n monitoring --sort-by=.metadata.creationTimestamp'" ]
}

@test "_kcm_suggest_aliases respects threshold" {
    export KCM_SUGGEST_THRESHOLD=10
    
    run _kcm_suggest_aliases
    [ "$status" -eq 0 ]
    [ "$output" = "No alias suggestions found. You need to run commands at least 10 times." ]
}

@test "_kcm_suggest_aliases applies suggestions with --apply flag" {
    run _kcm_suggest_aliases --apply
    [ "$status" -eq 0 ]
    
    # Check if aliases file was created and contains suggestions
    [ -f "$KCM_ALIASES_FILE" ]
    run grep "kgpmonsort" "$KCM_ALIASES_FILE"
    [ "$status" -eq 0 ]
}

@test "_kcm_apply_suggested_aliases applies and sources aliases" {
    run _kcm_apply_suggested_aliases
    [ "$status" -eq 0 ]
    
    # Check if aliases file was created
    [ -f "$KCM_ALIASES_FILE" ]
    
    # Check if alias was applied
    run grep "kgpmonsort" "$KCM_ALIASES_FILE"
    [ "$status" -eq 0 ]
}

@test "_kcm_track_command tracks kubectl commands" {
    rm -f "$KCM_USAGE_FILE"
    
    # Test tracking function
    run _kcm_track_command "kubectl get pods"
    [ "$status" -eq 0 ]
    
    # Check if command was tracked
    run grep "kubectl get pods" "$KCM_USAGE_FILE"
    [ "$status" -eq 0 ]
}

@test "_kcm_track_command ignores non-kubectl commands" {
    rm -f "$KCM_USAGE_FILE"
    
    # Test with non-kubectl command
    run _kcm_track_command "ls -la"
    [ "$status" -eq 0 ]
    
    # File should be empty or not contain the command
    if [ -f "$KCM_USAGE_FILE" ]; then
        run grep "ls -la" "$KCM_USAGE_FILE"
        [ "$status" -eq 1 ]
    fi
}

@test "_kcm_suggest_aliases skips existing aliases" {
    # Create an existing alias
    alias kgpmonsort="kubectl get pods"
    
    run _kcm_suggest_aliases
    [ "$status" -eq 0 ]
    
    # Should not suggest the alias that already exists
    run grep "kgpmonsort" <<< "$output"
    [ "$status" -eq 1 ]
    
    # Clean up
    unalias kgpmonsort 2>/dev/null || true
}
