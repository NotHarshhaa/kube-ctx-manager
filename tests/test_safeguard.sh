#!/usr/bin/env bats

# test_safeguard.sh - Tests for production safeguard functionality

load test_helper

setup() {
    # Setup test environment
    export KCM_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export KCM_USAGE_FILE="$BATS_TMPDIR/kube-usage"
    export KCM_ALIASES_FILE="$BATS_TMPDIR/kube-aliases"
    export KCM_AUDIT_LOG="$BATS_TMPDIR/audit.log"
    export KCM_PROD_PATTERN="prod|production|live|prd"
    
    # Source the safeguard module
    source "$KCM_DIR/lib/safeguard.sh"
    
    # Mock kubectl for testing
    kubectl() {
        case "$1" in
            config)
                case "$2" in
                    current-context)
                        echo "prod-context"
                        ;;
                esac
                ;;
            delete)
                echo "kubectl delete executed"
                ;;
            get)
                echo "kubectl get executed"
                ;;
        esac
    }
    
    # Create audit log
    touch "$KCM_AUDIT_LOG"
}

teardown() {
    # Clean up test files
    rm -f "$KCM_USAGE_FILE" "$KCM_ALIASES_FILE" "$KCM_AUDIT_LOG"
    unset KCM_PROD_PATTERN
}

@test "_kcm_is_prod_context identifies prod contexts" {
    run _kcm_is_prod_context
    [ "$status" -eq 0 ]
}

@test "_kcm_is_prod_context rejects non-prod contexts" {
    # Mock kubectl to return non-prod context
    kubectl() {
        case "$1" in
            config)
                case "$2" in
                    current-context)
                        echo "staging-context"
                        ;;
                esac
                ;;
        esac
    }
    
    run _kcm_is_prod_context
    [ "$status" -eq 1 ]
}

@test "_kcm_is_destructive_command identifies destructive commands" {
    run _kcm_is_destructive_command "kubectl delete pod mypod"
    [ "$status" -eq 0 ]
    
    run _kcm_is_destructive_command "kubectl drain node-1"
    [ "$status" -eq 0 ]
    
    run _kcm_is_destructive_command "kubectl cordon node-1"
    [ "$status" -eq 0 ]
    
    run _kcm_is_destructive_command "kubectl scale deployment myapp --replicas=0"
    [ "$status" -eq 0 ]
    
    run _kcm_is_destructive_command "kubectl rollout restart deployment myapp"
    [ "$status" -eq 0 ]
}

@test "_kcm_is_destructive_command rejects safe commands" {
    run _kcm_is_destructive_command "kubectl get pods"
    [ "$status" -eq 1 ]
    
    run _kcm_is_destructive_command "kubectl describe pod mypod"
    [ "$status" -eq 1 ]
    
    run _kcm_is_destructive_command "kubectl logs mypod"
    [ "$status" -eq 1 ]
    
    run _kcm_is_destructive_command "kubectl apply -f manifest.yaml"
    [ "$status" -eq 1 ]
}

@test "_kcm_get_destructive_verbs returns destructive verbs pattern" {
    run _kcm_get_destructive_verbs
    [ "$status" -eq 0 ]
    [ "$output" = "delete|drain|cordon|scale|rollout.*restart|rollout.*undo|rollout.*abort" ]
}

@test "_kcm_audit_command logs to audit file" {
    run _kcm_audit_command "prod-context" "default" "kubectl delete pod mypod"
    [ "$status" -eq 0 ]
    
    # Check if audit log contains the entry
    run grep "kubectl delete pod mypod" "$KCM_AUDIT_LOG"
    [ "$status" -eq 0 ]
}

@test "_kcm_prompt_confirmation accepts correct context name" {
    # Mock read to return the correct context name
    read() {
        if [[ "$REPLY" == "Type the context name to confirm: " ]]; then
            echo "prod-context"
        fi
    }
    
    run _kcm_prompt_confirmation "prod-context" "kubectl delete pod mypod"
    [ "$status" -eq 0 ]
    [ "$output" = "✅ Confirmed. Executing command..." ]
}

@test "_kcm_prompt_confirmation rejects incorrect context name" {
    # Mock read to return incorrect context name
    read() {
        if [[ "$REPLY" == "Type the context name to confirm: " ]]; then
            echo "wrong-context"
        fi
    }
    
    run _kcm_prompt_confirmation "prod-context" "kubectl delete pod mypod"
    [ "$status" -eq 1 ]
    [ "$output" = "❌ Confirmation mismatch. Command blocked." ]
}

@test "_kcm_kubectl_wrapper allows safe commands" {
    run _kcm_kubectl_wrapper get pods
    [ "$status" -eq 0 ]
    [ "$output" = "kubectl get executed" ]
}

@test "_kcm_kubectl_wrapper blocks destructive commands without confirmation" {
    # Mock read to return empty (simulate Ctrl+C)
    read() {
        return 1
    }
    
    run _kcm_kubectl_wrapper delete pod mypod
    [ "$status" -eq 1 ]
}

@test "_kcm_kubectl_wrapper allows destructive commands with confirmation" {
    # Mock read to return the correct context name
    read() {
        if [[ "$REPLY" == "Type the context name to confirm: " ]]; then
            echo "prod-context"
        fi
    }
    
    run _kcm_kubectl_wrapper delete pod mypod
    [ "$status" -eq 0 ]
    [ "$output" = "kubectl delete executed" ]
}
