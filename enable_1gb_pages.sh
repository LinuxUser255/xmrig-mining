#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Check for root permissions
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root" >&2
    exit 1
fi

# Check if 1GB pages are supported
if ! grep -q pdpe1gb /proc/cpuinfo; then
    echo "Warning: CPU does not support 1GB pages"
    echo "Falling back to 2MB huge pages..."
    
    # Enable 2MB huge pages instead
    if echo 1280 > /proc/sys/vm/nr_hugepages 2>/dev/null; then
        allocated=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null || echo "0")
        # Calculate total MB using arithmetic expansion (no subshell)
        total_mb=$((allocated * 2))
        echo "Enabled ${allocated} x 2MB huge pages (${total_mb} MB total)"
        exit 0
    else
        echo "Error: Failed to allocate 2MB huge pages" >&2
        exit 1
    fi
fi

# Enable 1GB huge pages
echo "Enabling 1GB huge pages for RandomX..."

# Check if the 1GB hugepages path exists
readonly HUGEPAGE_PATH="/sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages"

if [ ! -f "$HUGEPAGE_PATH" ]; then
    echo "Error: 1GB hugepages not available in kernel" >&2
    echo "Try adding 'hugepagesz=1G hugepages=3' to kernel parameters" >&2
    exit 1
fi

# Function to allocate huge pages with retries
allocate_hugepages() {
    local target="$1"
    local attempt=1
    local max_attempts=3
    
    while [ "$attempt" -le "$max_attempts" ]; do
        echo "Attempt $attempt: Allocating ${target} x 1GB pages..."
        
        if echo "$target" > "$HUGEPAGE_PATH" 2>/dev/null; then
            # Small delay to let kernel allocate
            sleep 0.5
            
            # Read actual allocation (no subshell, direct cat)
            local allocated
            allocated=$(cat "$HUGEPAGE_PATH" 2>/dev/null || echo "0")
            
            # Validate it's a number
            case "$allocated" in
                ''|*[!0-9]*) allocated=0 ;;
            esac
            
            if [ "$allocated" -eq "$target" ]; then
                echo "Successfully allocated ${allocated} x 1GB huge pages"
                return 0
            elif [ "$allocated" -gt 0 ]; then
                echo "Partially successful: allocated ${allocated} x 1GB huge pages"
                return 0
            fi
        fi
        
        if [ "$attempt" -lt "$max_attempts" ]; then
            echo "Allocation failed, freeing memory and retrying..."
            sync
            echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
            sleep 1
        fi
        
        # Use arithmetic expansion instead of subshell
        attempt=$((attempt + 1))
    done
    
    echo "Error: Failed to allocate 1GB huge pages after ${max_attempts} attempts" >&2
    return 1
}

# Try to allocate 3 x 1GB pages (optimal for RandomX)
if ! allocate_hugepages 3; then
    echo "Trying fallback allocation of 2 x 1GB pages..."
    if ! allocate_hugepages 2; then
        echo "Error: Unable to allocate any 1GB huge pages" >&2
        exit 1
    fi
fi

echo
echo "For persistent configuration across reboots:"
echo "1. Add to kernel boot parameters:"
echo "   hugepagesz=1G hugepages=3"
echo "2. Or add to /etc/default/grub:"
echo "   GRUB_CMDLINE_LINUX_DEFAULT=\"... hugepagesz=1G hugepages=3\""
echo "3. Then run: update-grub"
