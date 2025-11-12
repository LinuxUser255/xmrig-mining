#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
        echo "Error: MSR modifications require root access" >&2
        exit 1
fi

# Function to enable MSR writes
enable_msr_writes() {
        local msr_file="/sys/module/msr/parameters/allow_writes"
        
        if [ -e "$msr_file" ]; then
                echo "Enabling MSR writes via sysfs..."
                echo on > "$msr_file" || {
                        echo "Error: Failed to enable MSR writes" >&2
                        return 1
                }
        else
                echo "Loading MSR module with write support..."
                modprobe msr allow_writes=on || {
                        echo "Error: Failed to load MSR module" >&2
                        return 1
                }
        fi
        return 0
}

# Function to ensure msr-tools are available
ensure_msr_tools() {
        if command -v wrmsr &>/dev/null; then
                return 0
        fi
        
        echo "Warning: msr-tools not found"
        echo "Install with: apt-get install msr-tools"
        echo "Attempting installation..."
        
        # Use timeout and quiet mode to prevent hanging
        if timeout 30 apt-get update -qq &>/dev/null && \
           timeout 30 apt-get install -qq -y msr-tools &>/dev/null; then
                echo "Successfully installed msr-tools"
                return 0
        else
                echo "Error: Failed to install msr-tools" >&2
                echo "Please install manually: apt-get install msr-tools" >&2
                return 1
        fi
}

# Enable MSR writes first
if ! enable_msr_writes; then
        exit 1
fi

# Ensure tools are available
if ! ensure_msr_tools; then
        exit 1
fi

# Function to apply MSR values safely
apply_msr() {
        local msr_reg="$1"
        local msr_val="$2"
        
        if ! wrmsr -a "$msr_reg" "$msr_val" 2>/dev/null; then
                echo "  Warning: Failed to write MSR $msr_reg" >&2
                return 1
        fi
        return 0
}

# Function to detect and optimize AMD CPUs
optimize_amd_cpu() {
        local cpu_family
        local cpu_model
        
        # Extract CPU family and model
        cpu_family=$(grep -m1 "cpu family" /proc/cpuinfo | awk '{print $4}')
        cpu_model=$(grep -m1 "model[[:space:]]" /proc/cpuinfo | awk '{print $3}')
        
        case "$cpu_family" in
                25)  # Zen3/Zen4
                        if [ "$cpu_model" = "97" ]; then
                                echo "Detected Zen4 CPU"
                                apply_msr 0xc0011020 0x4400000000000
                                apply_msr 0xc0011021 0x4000000000040
                                apply_msr 0xc0011022 0x8680000401570000
                                apply_msr 0xc001102b 0x2040cc10
                                echo "MSR register values for Zen4 applied"
                        else
                                echo "Detected Zen3 CPU"
                                apply_msr 0xc0011020 0x4480000000000
                                apply_msr 0xc0011021 0x1c000200000040
                                apply_msr 0xc0011022 0xc000000401570000
                                apply_msr 0xc001102b 0x2000cc10
                                echo "MSR register values for Zen3 applied"
                        fi
                        ;;
                26)  # Zen5
                        echo "Detected Zen5 CPU"
                        apply_msr 0xc0011020 0x4400000000000
                        apply_msr 0xc0011021 0x4000000000040
                        apply_msr 0xc0011022 0x8680000401570000
                        apply_msr 0xc001102b 0x2040cc10
                        echo "MSR register values for Zen5 applied"
                        ;;
                23)  # Zen1/Zen2
                        echo "Detected Zen1/Zen2 CPU (likely Ryzen 9 3900X)"
                        apply_msr 0xc0011020 0
                        apply_msr 0xc0011021 0x40
                        apply_msr 0xc0011022 0x1510000
                        apply_msr 0xc001102b 0x2000cc16
                        echo "MSR register values for Zen1/Zen2 applied"
                        echo "✓ Optimizations applied for Ryzen 9 3900X"
                        ;;
                *)
                        echo "Detected AMD CPU (family $cpu_family)"
                        # Apply generic AMD optimizations
                        apply_msr 0xc0011020 0
                        apply_msr 0xc0011021 0x40
                        apply_msr 0xc0011022 0x1510000
                        apply_msr 0xc001102b 0x2000cc16
                        echo "Generic AMD MSR values applied"
                        ;;
        esac
}

# Function to optimize Intel CPUs  
optimize_intel_cpu() {
        echo "Detected Intel CPU"
        if apply_msr 0x1a4 0xf; then
                echo "MSR register values for Intel applied"
        else
                echo "Warning: Some Intel MSR values could not be applied" >&2
        fi
}

# Main CPU detection and optimization
echo "Detecting CPU type..."

if grep -qE 'AMD Ryzen|AMD EPYC|AuthenticAMD' /proc/cpuinfo; then
        optimize_amd_cpu
elif grep -q "Intel" /proc/cpuinfo; then
        optimize_intel_cpu
else
        echo "Warning: No supported CPU detected" >&2
        echo "MSR optimizations not applied"
        exit 0
fi

echo "MSR optimization complete"
