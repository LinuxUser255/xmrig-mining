#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

echo "==================================="
echo "XMRig Mining Optimization Launcher"
echo "AMD Ryzen 9 3900X + RX 580"
echo "==================================="
echo

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Process management
XMRIG_PID=""

# Cleanup function
cleanup() {
    local exit_code=$?
    if [ -n "$XMRIG_PID" ] && kill -0 "$XMRIG_PID" 2>/dev/null; then
        echo
        echo "Stopping XMRig..."
        kill "$XMRIG_PID" 2>/dev/null || true
        wait "$XMRIG_PID" 2>/dev/null || true
    fi
    exit "$exit_code"
}

# Trap signals for clean exit
trap cleanup INT TERM EXIT

# Check if running as root for optimization scripts
if [ "$EUID" -ne 0 ]; then
        echo "Note: Some optimizations require root access."
        echo "Consider running with sudo for best performance."
        echo
fi

# Parallel system checks with controlled concurrency
MAX_PARALLEL_CHECKS=3
joblist=()

# Function to check system requirements in parallel
check_requirement() {
        local check_name="$1"
        local check_cmd="$2"
        
        case "$check_name" in
                "huge_pages")
                        if grep -q "HugePages_Total:.*[1-9]" /proc/meminfo 2>/dev/null; then
                                echo "  ✓ Huge pages: Available"
                        else
                                echo "  ⚠ Huge pages: Not configured"
                        fi
                        ;;
                "cpu_governor")
                        if command -v cpupower &>/dev/null; then
                                local gov
                                gov=$(cpupower frequency-info -p 2>/dev/null | awk '{print $3}')
                                if [ "$gov" = "performance" ]; then
                                        echo "  ✓ CPU governor: Performance mode"
                                else
                                        echo "  ⚠ CPU governor: ${gov:-unknown} (not performance)"
                                fi
                        else
                                echo "  ⚠ CPU governor: cpupower not available"
                        fi
                        ;;
                "msr_module")
                        if lsmod | grep -q "^msr" 2>/dev/null; then
                                echo "  ✓ MSR module: Loaded"
                        else
                                echo "  ⚠ MSR module: Not loaded"
                        fi
                        ;;
        esac
}

# Run checks in parallel with thread pool
run_check_parallel() {
        check_requirement "$1" "$2" &
        joblist+=($!)
        
        # Limit concurrent checks
        if [ "${#joblist[@]}" -ge "$MAX_PARALLEL_CHECKS" ]; then
                wait "${joblist[0]}" 2>/dev/null || true
                joblist=("${joblist[@]:1}")
        fi
}

# Perform parallel system checks
if [ "$EUID" -ne 0 ]; then
        echo "Running system checks..."
        run_check_parallel "huge_pages" ""
        run_check_parallel "cpu_governor" ""
        run_check_parallel "msr_module" ""
        
        # Wait for all checks to complete
        for job in "${joblist[@]}"; do
                wait "$job" 2>/dev/null || true
        done
        echo
fi

# Apply system optimizations if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Applying system optimizations..."
    
    # Enable huge pages
    if [ -f "${SCRIPT_DIR}/enable_1gb_pages.sh" ]; then
        echo "→ Enabling 1GB huge pages..."
        if ! "${SCRIPT_DIR}/enable_1gb_pages.sh"; then
            echo "  Warning: Failed to enable huge pages"
        fi
        echo
    fi
    
    # Apply MSR optimizations
    if [ -f "${SCRIPT_DIR}/msr_boost.sh" ]; then
        echo "→ Applying MSR CPU optimizations..."
        if ! "${SCRIPT_DIR}/msr_boost.sh"; then
            echo "  Warning: Failed to apply MSR optimizations"
        fi
        echo
    fi
    
    # Set performance governor
    echo "→ Setting CPU to performance mode..."
    if command -v cpupower &>/dev/null; then
        cpupower frequency-set -g performance 2>/dev/null || echo "  Warning: Could not set performance governor"
    else
        echo "  cpupower not available, skipping"
    fi
    echo
else
    echo "Skipping root-only optimizations."
    echo "Run with sudo for ~20-30% better performance."
    echo
fi

# Check if config-optimized.json exists
if [ ! -f "${SCRIPT_DIR}/config-optimized.json" ]; then
    echo "Error: config-optimized.json not found!"
    echo "Please ensure the optimized config file is in: ${SCRIPT_DIR}"
    exit 1
fi

# Check if xmrig binary exists
if [ ! -f "${SCRIPT_DIR}/xmrig" ]; then
    echo "Error: xmrig binary not found!"
    echo "Please ensure xmrig is in: ${SCRIPT_DIR}"
    exit 1
fi

# Make sure xmrig is executable
if [ ! -x "${SCRIPT_DIR}/xmrig" ]; then
    echo "Making xmrig executable..."
    chmod +x "${SCRIPT_DIR}/xmrig"
fi

echo "IMPORTANT: Please update YOUR_WALLET_ADDRESS in config-optimized.json"
echo "before starting the miner!"
echo
echo "Starting XMRig with optimized configuration..."
echo "Press Ctrl+C to stop mining"
echo "==================================="
echo

# Start XMRig with optimized config and capture PID
"${SCRIPT_DIR}/xmrig" -c "${SCRIPT_DIR}/config-optimized.json" &
XMRIG_PID=$!

# Wait for XMRig process
wait "$XMRIG_PID"
