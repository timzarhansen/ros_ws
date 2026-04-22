#!/usr/bin/env bash
set -euo pipefail

# Autoresearch script for fsregistration package
# Outputs METRIC lines for timing metrics

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/home/tim-external/volumeROS"
BUILD_DIR="${PROJECT_ROOT}/build/fsregistration"
TEST_BINARY="${PROJECT_ROOT}/cache/humble/build/test_full_registration_comparison"

# Default values for metrics (for error cases)
total_time_new=0
rotation_time_new=0
translation_time_new=0
total_time_old=0
speedup=0
test_status=0

# Output metrics function
output_metrics() {
    echo "METRIC total_time_new=${total_time_new}"
    echo "METRIC rotation_time_new=${rotation_time_new}"
    echo "METRIC translation_time_new=${translation_time_new}"
    echo "METRIC total_time_old=${total_time_old}"
    echo "METRIC speedup=${speedup}"
    echo "METRIC test_status=${test_status}"
}

# Cleanup on exit
cleanup() {
    if [[ -n "${output_file:-}" ]]; then
        rm -f "${output_file}"
    fi
}
trap cleanup EXIT

# Quick build check (just verify binary exists and is executable)
check_build() {
    if [[ ! -x "${TEST_BINARY}" ]]; then
        echo "Build check failed: ${TEST_BINARY} not found or not executable" >&2
        echo "METRIC build_status=0"
        output_metrics
        return 1
    fi
    echo "METRIC build_status=1"
    return 0
}

# Run test and capture output
run_test() {
    local output_file
    output_file=$(mktemp)
    
    # Run test with timeout to prevent hanging
    if ! timeout 60 "${TEST_BINARY}" > "${output_file}" 2>&1; then
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo "Test timed out" >&2
        else
            echo "Test failed with exit code ${exit_code}" >&2
        fi
        # Parse partial output if available
        parse_output "${output_file}"
        return 1
    fi
    
    parse_output "${output_file}"
    return 0
}

# Parse test output to extract metrics
parse_output() {
    local output_file="$1"
    
    # Extract NEW method total time
    # Line format: "  Total time: X ms" (last occurrence is NEW method)
    local new_time
    new_time=$(grep -oP 'Total time: \K[0-9.]+' "${output_file}" 2>/dev/null | tail -1 || echo "0")
    total_time_new="${new_time:-0}"
    
    # Extract OLD method total time
    # Line format: "  Total time: X ms" (first occurrence is OLD method)
    local old_time
    old_time=$(grep -oP 'Total time: \K[0-9.]+' "${output_file}" 2>/dev/null | head -1 || echo "0")
    total_time_old="${old_time:-0}"
    
    # Extract speedup from comparison line
    # Line format: "  Total: OLD=X ms, NEW=Y ms, speedup=Zx"
    local speedup_val
    speedup_val=$(grep -oP 'speedup=\K[0-9.]+' "${output_file}" 2>/dev/null | head -1 || echo "0")
    speedup="${speedup_val:-0}"
    
    # For rotation_time_new and translation_time_new, we need to estimate
    # Since the test doesn't output separate rotation/translation times,
    # we use the total time as a proxy (or 0 if not available)
    # These could be refined if the test output format changes
    rotation_time_new="${total_time_new:-0}"
    translation_time_new="${total_time_new:-0}"
    
    # Extract test pass/fail status
    # Line format: "✓ TEST PASSED" or "✗ TEST FAILED"
    if grep -q 'TEST PASSED' "${output_file}" 2>/dev/null; then
        test_status=1
    elif grep -q 'TEST FAILED' "${output_file}" 2>/dev/null; then
        test_status=2
    else
        test_status=0  # Unknown/partial
    fi
}

# Main execution
main() {
    cd "${PROJECT_ROOT}"
    
    # Check build
    if ! check_build; then
        exit 0
    fi
    
    # Run test
    run_test || true
    
    # Output metrics
    output_metrics
}

main "$@"
