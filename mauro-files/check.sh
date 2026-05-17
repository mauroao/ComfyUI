#!/bin/bash
set -uo pipefail

# Color constants
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# Helper: version_gte A B → returns 0 if A >= B
version_gte() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# Detect Python binary
if [ -n "${VIRTUAL_ENV:-}" ]; then
    PYTHON="$VIRTUAL_ENV/bin/python"
elif command -v python3 &>/dev/null; then
    PYTHON="python3"
elif command -v python &>/dev/null; then
    PYTHON="python"
else
    PYTHON=""
fi

# Parallel arrays for results
NAMES=()
REQUIRED=()
FOUND=()
STATUS=()

# Check functions
check_python() {
    local required="3.12"
    NAMES+=("Python")
    REQUIRED+=("$required")
    if [ -z "$PYTHON" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
        return
    fi
    local ver
    ver=$("$PYTHON" --version 2>&1 | grep -oP '\d+\.\d+\.\d+' | head -n1) || true
    if [ -z "$ver" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
    elif version_gte "$ver" "$required"; then
        FOUND+=("$ver")
        STATUS+=("OK")
    else
        FOUND+=("$ver")
        STATUS+=("FAIL")
    fi
}

check_torch() {
    local required="2.4"
    NAMES+=("torch")
    REQUIRED+=("$required")
    if [ -z "$PYTHON" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
        return
    fi
    local ver
    ver=$("$PYTHON" -c "import torch; print(torch.__version__)" 2>/dev/null | sed 's/+.*//' ) || true
    if [ -z "$ver" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
    elif version_gte "$ver" "$required"; then
        FOUND+=("$ver")
        STATUS+=("OK")
    else
        FOUND+=("$ver")
        STATUS+=("FAIL")
    fi
}

check_triton() {
    local required="3.0"
    NAMES+=("triton")
    REQUIRED+=("$required")
    if [ -z "$PYTHON" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
        return
    fi
    local ver
    ver=$("$PYTHON" -c "import triton; print(triton.__version__)" 2>/dev/null) || true
    if [ -z "$ver" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
    elif version_gte "$ver" "$required"; then
        FOUND+=("$ver")
        STATUS+=("OK")
    else
        FOUND+=("$ver")
        STATUS+=("FAIL")
    fi
}

check_sage() {
    local required="2.2"
    NAMES+=("sageattention")
    REQUIRED+=("$required")
    if [ -z "$PYTHON" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
        return
    fi
    local ver
    ver=$(pip show sageattention 2>/dev/null | grep -oP '^Version:\s*\K[\d.]+') || true
    if [ -z "$ver" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
    elif version_gte "$ver" "$required"; then
        FOUND+=("$ver")
        STATUS+=("OK")
    else
        FOUND+=("$ver")
        STATUS+=("FAIL")
    fi
}

check_cuda() {
    local required="12.8"
    NAMES+=("CUDA Toolkit")
    REQUIRED+=("$required")
    local ver
    ver=$(nvcc --version 2>/dev/null | grep -oP 'release \K[\d.]+' | head -n1) || true
    if [ -z "$ver" ]; then
        FOUND+=("not found")
        STATUS+=("FAIL")
    elif version_gte "$ver" "$required"; then
        FOUND+=("$ver")
        STATUS+=("OK")
    else
        FOUND+=("$ver")
        STATUS+=("FAIL")
    fi
}

# Run all checks
check_python
check_torch
check_triton
check_sage
check_cuda

# Print summary table
echo ""
printf "${BOLD}==============================================${NC}\n"
printf "${BOLD}  Dependency Check Results${NC}\n"
printf "${BOLD}==============================================${NC}\n"
printf "${BOLD}  %-15s %-10s %-10s %s${NC}\n" "Component" "Required" "Found" "Status"
printf "  %-15s %-10s %-10s %s\n" "-----------" "--------" "-----" "------"

any_fail=0
for i in "${!NAMES[@]}"; do
    name="${NAMES[$i]}"
    req=">= ${REQUIRED[$i]}"
    found="${FOUND[$i]}"
    st="${STATUS[$i]}"

    if [ "$st" = "OK" ]; then
        status_str="${GREEN}✓ OK${NC}"
    else
        status_str="${RED}✗ FAIL${NC}"
        any_fail=1
    fi

    printf "  %-15s %-10s %-10s ${status_str}\n" "$name" "$req" "$found"
done

printf "${BOLD}==============================================${NC}\n"
echo ""

if [ "$any_fail" -eq 1 ]; then
    printf "${RED}${BOLD}Some checks failed. See table above.${NC}\n\n"
    exit 1
else
    printf "${GREEN}${BOLD}All checks passed.${NC}\n\n"
    exit 0
fi
