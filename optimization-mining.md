# XMRig Mining Optimization Guide

## Table of Contents
1. [MSR Optimizations Explained](#msr-optimizations-explained)
2. [Huge Pages Configuration](#huge-pages-configuration)
3. [Combined Optimizations](#combined-optimizations)
4. [Manual Setup Without Scripts](#manual-setup-without-scripts)
5. [AMD Ryzen 9 3900X Specific Optimizations](#amd-ryzen-9-3900x-specific-optimizations)
6. [AMD RX 580 GPU Optimization](#amd-rx-580-gpu-optimization)
7. [Complete Configuration Guide](#complete-configuration-guide)

---

## MSR Optimizations Explained

The `sudo ./scripts/randomx_boost.sh` command applies hardware-level optimizations to improve RandomX mining performance by modifying Model Specific Registers (MSRs) on your CPU.

### What MSR Modifications Do

**MSR (Model Specific Register)** modifications are low-level CPU configuration changes that can significantly boost RandomX mining performance - typically 10-15% improvement. The process:

1. **Detects your CPU type** (AMD Ryzen/EPYC or Intel)
2. **Writes optimized values to specific MSR registers** based on CPU architecture:
   - For AMD Zen1/Zen2, Zen3, Zen4, or Zen5 CPUs - modifies prefetcher settings
   - For Intel CPUs - adjusts prefetch configuration
3. **Enables MSR writes** if needed via the kernel module

### Key MSR Modifications

#### For AMD CPUs:
- `0xc0011020, 0xc0011021, 0xc0011022`: Control data and instruction prefetchers
- `0xc001102b`: Controls memory prefetch settings
- Different values are applied for each Zen generation for optimal performance

#### For Intel CPUs:
- `0x1a4`: Sets all prefetcher bits to optimize RandomX memory access patterns

### Why Root Access Required

MSR registers are protected CPU configuration registers that control critical hardware behavior. Modifying them requires:
- Root/sudo privileges to access `/dev/cpu/*/msr`
- Loading the `msr` kernel module with write permissions
- Writing to `/sys/module/msr/parameters/allow_writes` on newer kernels

### Important Notes

- **These changes are temporary** - they reset on reboot
- **Safe for mining** - the values are specifically tuned for RandomX and widely tested
- **May affect other workloads** - these settings optimize for RandomX's specific memory access patterns
- **Can be reverted** - XMRig will restore original MSR values on exit (unless `--randomx-no-rdmsr` is used)

The performance boost comes from optimizing how the CPU prefetches data into cache, which is crucial for RandomX's random memory access patterns.

---

## Huge Pages Configuration

The `sudo ./scripts/enable_1gb_pages.sh` command enables 1GB huge pages for improved memory management.

### Why Huge Pages Matter

- Reduces TLB (Translation Lookaside Buffer) misses
- Minimizes virtual-to-physical memory translation overhead
- **Improvement: ~10-20%**

---

## Combined Optimizations

Using both MSR optimizations and huge pages together yields **20-30% better hashrate** compared to running without either, because they address different bottlenecks:

### Combined Effect:

1. **MSR Optimizations** (`randomx_boost.sh`)
   - Optimizes CPU prefetching behavior
   - Reduces memory access latency
   - **Improvement: ~10-15%**

2. **1GB Huge Pages** (`enable_1gb_pages.sh`)
   - Reduces TLB misses
   - Minimizes memory translation overhead
   - **Improvement: ~10-20%**

### Why They Work Better Together

**RandomX requires 2GB+ of memory per mining instance** and performs millions of random memory accesses. The combination addresses both:
- **Memory access patterns** (MSR mods optimize prefetching)
- **Memory translation overhead** (1GB pages reduce TLB pressure)

### Performance Impact

Without optimizations: **100%** baseline
- With MSR only: ~**110-115%**
- With 1GB pages only: ~**110-120%**
- **With both: ~120-130%** (multiplicative effect)

---

## Manual Setup Without Scripts

Since you're using a pre-compiled XMRig binary without the scripts directory, here are the manual optimization scripts:

### MSR Optimization Script (`~/msr_boost.sh`)

```bash
#!/bin/sh -e

# Enable MSR writes
MSR_FILE=/sys/module/msr/parameters/allow_writes
if test -e "$MSR_FILE"; then
    echo on > $MSR_FILE
else
    modprobe msr allow_writes=on
fi

# Install msr-tools if not present
if ! command -v wrmsr &> /dev/null; then
    echo "Installing msr-tools..."
    apt-get update && apt-get install -y msr-tools
fi

# Detect and apply CPU-specific optimizations
if grep -E 'AMD Ryzen|AMD EPYC|AuthenticAMD' /proc/cpuinfo > /dev/null; then
    if grep "cpu family[[:space:]]\{1,\}:[[:space:]]25" /proc/cpuinfo > /dev/null; then
        if grep "model[[:space:]]\{1,\}:[[:space:]]97" /proc/cpuinfo > /dev/null; then
            echo "Detected Zen4 CPU"
            wrmsr -a 0xc0011020 0x4400000000000
            wrmsr -a 0xc0011021 0x4000000000040
            wrmsr -a 0xc0011022 0x8680000401570000
            wrmsr -a 0xc001102b 0x2040cc10
            echo "MSR register values for Zen4 applied"
        else
            echo "Detected Zen3 CPU"
            wrmsr -a 0xc0011020 0x4480000000000
            wrmsr -a 0xc0011021 0x1c000200000040
            wrmsr -a 0xc0011022 0xc000000401570000
            wrmsr -a 0xc001102b 0x2000cc10
            echo "MSR register values for Zen3 applied"
        fi
    elif grep "cpu family[[:space:]]\{1,\}:[[:space:]]26" /proc/cpuinfo > /dev/null; then
        echo "Detected Zen5 CPU"
        wrmsr -a 0xc0011020 0x4400000000000
        wrmsr -a 0xc0011021 0x4000000000040
        wrmsr -a 0xc0011022 0x8680000401570000
        wrmsr -a 0xc001102b 0x2040cc10
        echo "MSR register values for Zen5 applied"
    else
        echo "Detected Zen1/Zen2 CPU"
        wrmsr -a 0xc0011020 0
        wrmsr -a 0xc0011021 0x40
        wrmsr -a 0xc0011022 0x1510000
        wrmsr -a 0xc001102b 0x2000cc16
        echo "MSR register values for Zen1/Zen2 applied"
    fi
elif grep "Intel" /proc/cpuinfo > /dev/null; then
    echo "Detected Intel CPU"
    wrmsr -a 0x1a4 0xf
    echo "MSR register values for Intel applied"
else
    echo "No supported CPU detected"
fi
```

### 1GB Huge Pages Script (`~/enable_1gb_pages.sh`)

```bash
#!/bin/bash

# Check if 1GB pages are supported
if ! grep -q pdpe1gb /proc/cpuinfo; then
    echo "Error: CPU does not support 1GB pages"
    echo "Falling back to 2MB huge pages..."
    
    # Enable 2MB huge pages instead
    echo 1280 > /proc/sys/vm/nr_hugepages
    echo "Enabled 1280 x 2MB huge pages (2560 MB total)"
    exit 0
fi

# Enable 1GB huge pages
echo "Enabling 1GB huge pages for RandomX..."

# First, try to allocate 3 x 1GB pages (optimal for RandomX)
echo 3 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

# Check if successful
allocated=$(cat /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages)

if [ "$allocated" -eq "3" ]; then
    echo "Successfully allocated 3 x 1GB huge pages"
else
    echo "Could only allocate $allocated x 1GB huge pages"
    echo "Trying to free memory and retry..."
    
    # Free memory
    sync
    echo 3 > /proc/sys/vm/drop_caches
    
    # Retry
    echo 3 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages
    allocated=$(cat /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages)
    echo "After retry: $allocated x 1GB huge pages allocated"
fi

# For persistent configuration across reboots
echo "To make this permanent, add to kernel boot parameters:"
echo "  hugepagesz=1G hugepages=3"
echo "Or add to /etc/default/grub:"
echo "  GRUB_CMDLINE_LINUX_DEFAULT=\"... hugepagesz=1G hugepages=3\""
```

### Setup Commands

```bash
# Make scripts executable
chmod +x ~/msr_boost.sh ~/enable_1gb_pages.sh

# Apply optimizations
sudo ~/enable_1gb_pages.sh
sudo ~/msr_boost.sh
```

---

## AMD Ryzen 9 3900X Specific Optimizations

Your Ryzen 9 3900X (Zen2 architecture) should achieve **12-14 KH/s** optimized.

### CPU-Specific MSR Settings

The MSR script will automatically detect and apply Zen2 optimizations:
```bash
sudo ~/msr_boost.sh
# Will apply Zen1/Zen2 specific values
```

### Optimal config.json for 3900X

```json
{
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": true,
        "hw-aes": null,
        "priority": 5,
        "memory-pool": true,
        "yield": false,
        "max-threads-hint": 100,
        "asm": "ryzen",
        "argon2-impl": null,
        "rx": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23],
        "rx/0": {
            "init": -1,
            "init-avx2": -1,
            "mode": "auto",
            "1gb-pages": true,
            "rdmsr": true,
            "wrmsr": true,
            "cache_qos": false,
            "numa": false
        }
    }
}
```

**Key points for 3900X:**
- Uses all 24 threads (12 cores × 2 SMT)
- Threads ordered by physical cores first, then SMT pairs
- `"asm": "ryzen"` for Zen2-specific optimizations
- NUMA disabled (single CCD config is better)

### 3900X System Tweaks

```bash
# Set performance governor
sudo cpupower frequency-set -g performance

# Lock CPU at high frequency (optional, increases power)
sudo sh -c "echo 3800000 > /sys/devices/system/cpu/cpu*/cpufreq/scaling_min_freq"

# Disable core boost for consistent performance (optional)
echo 0 | sudo tee /sys/devices/system/cpu/cpufreq/boost

# Set PBO (Precision Boost Overdrive) if available in BIOS
```

---

## AMD RX 580 GPU Optimization

The RX 580 can add **800-1000 H/s** for RandomX.

### Enable OpenCL Mining

Add to your config.json:
```json
{
    "opencl": {
        "enabled": true,
        "loader": null,
        "platform": "AMD",
        "cn/0": {
            "index": 0,
            "intensity": 896,
            "worksize": 8,
            "strided_index": 2,
            "mem_chunk": 2,
            "unroll": 8,
            "comp_mode": true
        },
        "rx/0": {
            "index": 0,
            "intensity": 768,
            "worksize": 16,
            "threads": 2,
            "bfactor": 8,
            "gcn_asm": true,
            "dataset_host": false
        }
    }
}
```

### GPU Performance Tweaks

```bash
# Install AMD GPU tools
sudo apt install rocm-smi radeontop

# Set GPU to compute mode
echo manual | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
echo 7 | sudo tee /sys/class/drm/card0/device/pp_dpm_sclk

# Overclock memory for better RandomX (be careful)
# RX 580 sweet spot: 2050-2150 MHz memory
echo "m 1 2050" | sudo tee /sys/class/drm/card0/device/pp_od_clk_voltage

# Monitor GPU
radeontop
```

### GPU Undervolting for Efficiency

```bash
# Undervolt for efficiency (saves power, runs cooler)
# Typical: 1150MHz @ 950mV
echo "s 7 1150 950" | sudo tee /sys/class/drm/card0/device/pp_od_clk_voltage
echo "c" | sudo tee /sys/class/drm/card0/device/pp_od_clk_voltage
```

---

## Complete Configuration Guide

### Combined CPU + GPU Mining Configuration

```json
{
    "autosave": true,
    "cpu": {
        "enabled": true,
        "huge-pages": true,
        "huge-pages-jit": true,
        "hw-aes": null,
        "priority": 4,
        "memory-pool": true,
        "yield": false,
        "asm": "ryzen",
        "rx": [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23]
    },
    "opencl": {
        "enabled": true,
        "platform": "AMD"
    },
    "pools": [
        {
            "algo": "rx/0",
            "coin": "monero",
            "url": "your-pool:port",
            "user": "your-wallet",
            "pass": "x"
        }
    ]
}
```

### System-Level Optimizations

```bash
# Disable CPU frequency scaling (max performance)
sudo cpupower frequency-set -g performance

# Disable SMT/Hyper-threading if you have high core count
# (test both ways - sometimes better without SMT)
echo off | sudo tee /sys/devices/system/cpu/smt/control

# Set CPU affinity to physical cores only
# Check your topology first:
lscpu --extended
```

### Power & Thermal Management

#### For Ryzen 9 3900X:
```bash
# Monitor temperatures
watch -n 1 sensors

# Install if needed
sudo apt install lm-sensors
sudo sensors-detect

# Keep CPU under 75°C for sustained boost
# Consider undervolting in BIOS: -0.05V to -0.1V offset
```

### Quick Start Commands

Run in order:
```bash
# 1. System optimizations
sudo ~/enable_1gb_pages.sh
sudo ~/msr_boost.sh
sudo cpupower frequency-set -g performance

# 2. Start mining
cd ~/xmrig-6.24.0
./xmrig -c config.json

# 3. Monitor (in another terminal)
watch -n 1 "sensors | grep -E 'Tdie|edge'; rocm-smi"
```

### Monitoring Performance

When you start XMRig, verify optimizations are working:
- Look for: `huge pages 100%` (should show 1GB pages)
- Look for: `msr` register modifications applied
- Check hashrate stability over 5-10 minutes

### Expected Performance

With full optimization:
- **CPU (3900X)**: 12,500-14,000 H/s
- **GPU (RX 580)**: 800-1,000 H/s  
- **Combined**: ~13,500-15,000 H/s

This should get you approximately **0.002-0.003 XMR per day** depending on network difficulty.

### Expected Improvements Summary

Starting from baseline (no optimizations):
- **+10-15%** from MSR mods
- **+10-20%** from 1GB huge pages  
- **+5-10%** from proper CPU configuration
- **Total: +25-40% hashrate improvement**

## Tips to Maximize Monero Earnings

1. **Join a good pool** with low fees (< 1%) and good uptime
2. **Run 24/7** - consistency matters more than peak hashrate
3. **Monitor temperature** - thermal throttling kills performance
4. **Use P2Pool** for better decentralization and no pool fees
5. **Optimize power costs** - consider electricity rates vs earnings

## Important Reminders

- The optimization scripts need to be run after every reboot
- Consider adding them to your system startup for persistence
- Your 3900X is particularly efficient at RandomX
- Focus on CPU mining and use the GPU as a bonus
- The CPU will provide 90%+ of your total hashrate with proper optimization

---

*Generated from XMRig optimization conversation - November 2024*