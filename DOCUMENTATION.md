# XMRig Mining Optimization - Complete Documentation
## AMD Ryzen 9 3900X + RX 580 Setup Guide

---

## Table of Contents
1. [Overview](#overview)
2. [Script Files](#script-files)
3. [Initial Setup](#initial-setup)
4. [Optimization Scripts Detailed](#optimization-scripts-detailed)
5. [Configuration Guide](#configuration-guide)
6. [Monitoring Your Mining](#monitoring-your-mining)
7. [Troubleshooting](#troubleshooting)
8. [Performance Tuning](#performance-tuning)
9. [Security Considerations](#security-considerations)
10. [FAQ](#faq)

---

## Overview

This documentation covers a complete XMRig mining setup optimized for:
- **CPU**: AMD Ryzen 9 3900X (12 cores, 24 threads)
- **GPU**: AMD Radeon RX 580 (8GB)
- **Algorithm**: RandomX (Monero/XMR)
- **Expected Performance**: 11-13 KH/s combined

### What These Optimizations Do
The optimization scripts apply hardware-level tweaks that can improve your mining performance by 25-40%:
- **MSR modifications**: Optimize CPU cache and memory prefetching
- **Huge pages**: Reduce memory translation overhead
- **CPU governor**: Ensure maximum CPU frequency
- **Thread affinity**: Optimal thread-to-core mapping

---

## Script Files

### Files Created
| File | Purpose |
|------|---------|
| `config-optimized.json` | Main mining configuration |
| `msr_boost.sh` | CPU MSR register optimizations |
| `enable_1gb_pages.sh` | Memory huge pages setup |
| `start_mining_optimized.sh` | Automated startup script |
| `xmrig-monitor.sh` | Real-time earnings monitor |
| `DOCUMENTATION.md` | This documentation |

---

## Initial Setup

### Step 1: Prerequisites
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required tools
sudo apt install -y curl wget git build-essential cmake libuv1-dev libssl-dev libhwloc-dev

# Install monitoring tools
sudo apt install -y htop lm-sensors bc jq

# For AMD GPU support
sudo apt install -y ocl-icd-opencl-dev mesa-opencl-icd

# MSR tools for CPU optimization
sudo apt install -y msr-tools

# CPU frequency management
sudo apt install -y cpufrequtils
```

### Step 2: Set Up Your Wallet
1. Get a Monero wallet address:
   - **GUI Wallet**: https://www.getmonero.org/downloads/
   - **CLI Wallet**: `monero-wallet-cli`
   - **Exchange Wallet**: Binance, Kraken (not recommended for mining)

2. Update the configuration:
```bash
# Edit config-optimized.json
nvim config-optimized.json

# Replace YOUR_WALLET_ADDRESS with your actual address
# Example: 44AFFq5kSiGBoZ4NMDwYtN18obc8AemS33DBLWs3H7otXft3XjrpDtQGv7SqSsaBYBb98uNbr2VBBEt7f2wfn3RVGQBEP3A
```

### Step 3: Make Scripts Executable
```bash
chmod +x msr_boost.sh enable_1gb_pages.sh start_mining_optimized.sh xmrig-monitor.sh
```

---

## Optimization Scripts Detailed

### 1. MSR Boost Script (`msr_boost.sh`)

**Purpose**: Modifies CPU Model Specific Registers for optimal RandomX performance.

#### What it does:
- Detects your CPU architecture (AMD Zen1/2/3/4/5 or Intel)
- Applies architecture-specific MSR values
- Optimizes CPU prefetcher behavior
- Improves memory access patterns

#### Technical Details:
```bash
# For AMD Ryzen 9 3900X (Zen2):
wrmsr -a 0xc0011020 0           # Data prefetch disable
wrmsr -a 0xc0011021 0x40        # L2 prefetch disable  
wrmsr -a 0xc0011022 0x1510000   # Prefetch control
wrmsr -a 0xc001102b 0x2000cc16  # Memory controller optimization
```

#### Usage:
```bash
# Must run as root
sudo ./msr_boost.sh

# Expected output:
# Detected Zen1/Zen2 CPU (Ryzen 9 3900X)
# MSR register values for Zen1/Zen2 applied
# ✓ Optimizations applied for your Ryzen 9 3900X
```

#### Performance Impact:
- **+10-15% hashrate improvement**
- Reduced memory latency
- Better cache utilization
- Lower power consumption per hash

### 2. Huge Pages Script (`enable_1gb_pages.sh`)

**Purpose**: Enables 1GB huge pages for RandomX dataset storage.

#### What it does:
- Checks CPU support for 1GB pages (pdpe1gb flag)
- Allocates 3x 1GB huge pages (optimal for RandomX)
- Falls back to 2MB pages if 1GB not supported
- Reduces TLB (Translation Lookaside Buffer) misses

#### Technical Details:
```bash
# Allocate 3GB as 1GB pages
echo 3 > /sys/kernel/mm/hugepages/hugepages-1048576kB/nr_hugepages

# Or fallback to 2MB pages
echo 1280 > /proc/sys/vm/nr_hugepages  # 2560 MB total
```

#### Usage:
```bash
# Must run as root
sudo ./enable_1gb_pages.sh

# Expected output:
# Enabling 1GB huge pages for RandomX...
# Successfully allocated 3 x 1GB huge pages
```

#### Verification:
```bash
# Check huge pages status
grep Huge /proc/meminfo

# Output should show:
# HugePages_Total:    3
# HugePages_Free:     0  (when mining is running)
# Hugepagesize:    1048576 kB
```

#### Performance Impact:
- **+10-20% hashrate improvement**
- Reduced memory access overhead
- Lower CPU usage for same hashrate
- More consistent performance

### 3. Start Mining Script (`start_mining_optimized.sh`)

**Purpose**: Automated startup with all optimizations applied.

#### What it does:
1. Checks for root privileges
2. Applies huge pages if root
3. Applies MSR optimizations if root
4. Sets CPU governor to performance
5. Starts XMRig with optimized config

#### Usage:
```bash
# With full optimizations (recommended)
sudo ./start_mining_optimized.sh

# Without root optimizations (lower performance)
./start_mining_optimized.sh
```

### 4. Mining Monitor (`xmrig-monitor.sh`)

**Purpose**: Real-time display of mining statistics and earnings.

#### Features:
- Live hashrate monitoring (CPU + GPU)
- XMR and USD earnings calculation
- Pool payout progress tracking
- Performance status indicators
- Automatic XMR price updates
- Share acceptance rate
- Uptime tracking

#### Usage:
```bash
# Start monitoring (XMRig must be running)
./xmrig-monitor.sh

# Monitor will refresh every 5 seconds
# Press Ctrl+C to exit
```

#### Display Sections:
1. **Connection Info**: Pool, algorithm, difficulty
2. **Hashrate**: Total, CPU, GPU breakdown
3. **Statistics**: Uptime, shares accepted
4. **Earnings**: Hourly, daily, monthly in XMR and USD
5. **Payout Progress**: Visual progress bar to minimum payout
6. **Performance**: Status indicators and expected ranges

---

## Configuration Guide

### Understanding config-optimized.json

#### CPU Configuration
```json
"cpu": {
    "enabled": true,              // Enable CPU mining
    "huge-pages": true,           // Use huge pages
    "huge-pages-jit": true,       // JIT compiler huge pages
    "priority": 3,                // Process priority (1-5)
    "memory-pool": true,          // Memory pool for efficiency
    "yield": false,               // Don't yield CPU time
    "max-threads-hint": 75,       // Use 75% of threads max
    "asm": "ryzen",              // Ryzen-specific assembly
    "rx": [0,2,4,6,8,10,12,14,16,18,20,22,1,3,5,7,9,11,13,15,17,19]
    // Thread affinity: physical cores first, then SMT
}
```

#### GPU Configuration
```json
"opencl": {
    "enabled": true,
    "platform": "AMD",
    "rx/0": {
        "intensity": 640,     // Conservative for stability
        "worksize": 16,      
        "threads": 2,         // GPU threads
        "bfactor": 8,
        "gcn_asm": true,      // AMD GCN assembly
        "dataset_host": false // Store dataset on GPU
    }
}
```

#### Pool Configuration
```json
"pools": [{
    "algo": "rx/0",           // RandomX algorithm
    "coin": "XMR",           
    "url": "pool.supportxmr.com:443",
    "user": "YOUR_WALLET_ADDRESS",
    "pass": "x",             // Password (usually 'x')
    "rig-id": "ryzen3900x-rx580",  // Rig identifier
    "keepalive": true,       // Keep connection alive
    "tls": true             // Encrypted connection
}]
```

### Customization Options

#### Adjust Thread Count
```json
// For 100% CPU usage (24 threads)
"rx": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]

// For 50% CPU usage (12 threads - physical cores only)
"rx": [0,2,4,6,8,10,12,14,16,18,20,22]

// Current: 22 threads (keeps system responsive)
```

#### Adjust GPU Intensity
```json
// Low (stable, cool)
"intensity": 512

// Medium (balanced)
"intensity": 640  // Current setting

// High (maximum performance, hot)
"intensity": 768
```

---

## Monitoring Your Mining

### Using the XMRig Monitor

#### Start Monitoring
```bash
# Terminal 1: Start mining
sudo ./start_mining_optimized.sh

# Terminal 2: Start monitor
./xmrig-monitor.sh
```

#### Understanding the Display

**Hashrate Section**:
- **Total**: Combined CPU + GPU
- **CPU**: Should be 10-12 KH/s for 3900X
- **GPU**: Should be 0.7-0.9 KH/s for RX 580

**Earnings Calculation**:
- Based on current network difficulty
- Updates XMR price every 60 seconds
- Shows time to pool minimum payout

**Performance Indicators**:
- 🟢 Optimal: >10 KH/s total
- 🟡 Below Expected: 8-10 KH/s
- 🔴 Poor: <8 KH/s

### System Monitoring

#### CPU Temperature
```bash
# Real-time temperature monitoring
watch -n 1 sensors

# Look for:
# Tdie: +65.0°C  (should be <75°C)
```

#### CPU Frequency
```bash
# Check current frequency
grep MHz /proc/cpuinfo

# All cores should be at or near max (4.6 GHz boost)
```

#### Memory Usage
```bash
# Check huge pages usage
grep Huge /proc/meminfo

# When mining:
# HugePages_Free: 0 (all in use)
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Low Hashrate (<8 KH/s)

**Causes & Solutions**:
```bash
# Check if huge pages are enabled
grep Huge /proc/meminfo
# If HugePages_Total is 0, run:
sudo ./enable_1gb_pages.sh

# Check if MSR mod is applied
sudo ./msr_boost.sh

# Check CPU governor
cpupower frequency-info
# If not "performance":
sudo cpupower frequency-set -g performance

# Check thermal throttling
sensors | grep Tdie
# If >75°C, improve cooling
```

#### 2. GPU Not Detected

**Solutions**:
```bash
# Check OpenCL installation
clinfo | grep "Number of platforms"

# Install AMD drivers
sudo apt install mesa-opencl-icd

# Check GPU status
sudo lspci | grep VGA

# Verify in config
"opencl": {
    "enabled": true,  # Must be true
    "platform": "AMD"
}
```

#### 3. Connection Issues

**Solutions**:
```bash
# Test pool connectivity
ping pool.supportxmr.com

# Try different pool
# Edit config-optimized.json, change url to:
"url": "xmr-us-east1.nanopool.org:14433"

# Check firewall
sudo ufw status
# If blocking, allow:
sudo ufw allow out 443/tcp
```

#### 4. "MEMORY ALLOC FAILED" Error

**Solution**:
```bash
# Increase huge pages
sudo sysctl -w vm.nr_hugepages=1280

# Or use 1GB pages
sudo ./enable_1gb_pages.sh

# Check available memory
free -h
# Need at least 4GB free
```

#### 5. Monitor Shows 0 H/s

**Solutions**:
```bash
# Check if API is enabled
grep -A5 '"http"' config-optimized.json
# Should show "enabled": true

# Test API access
curl http://127.0.0.1:8080/1/summary

# Restart XMRig
killall xmrig
sudo ./start_mining_optimized.sh
```

---

## Performance Tuning

### Advanced Optimizations

#### 1. CPU Affinity Tuning
```bash
# Test different thread configurations
# Edit config-optimized.json

# Option 1: Physical cores only (lower power)
"rx": [0,2,4,6,8,10,12,14,16,18,20,22]

# Option 2: Full 24 threads (maximum hashrate)
"rx": [0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23]

# Option 3: CCX-aware (Zen2 optimization)
"rx": [0,1,2,3,4,5,12,13,14,15,16,17,6,7,8,9,10,11,18,19,20,21,22,23]
```

#### 2. Memory Timing Optimization
```bash
# In BIOS:
# - Enable XMP/DOCP profile
# - Set RAM to 3600MHz CL16 (optimal for Zen2)
# - Set Infinity Fabric to 1800MHz (1:1 with RAM)
```

#### 3. Power Optimization
```bash
# Undervolt CPU (reduces heat, maintains performance)
# In BIOS:
# - Set CPU Vcore offset: -0.05V to -0.1V
# - Test stability with stress test

# Undervolt GPU
echo "s 7 1150 950" | sudo tee /sys/class/drm/card0/device/pp_od_clk_voltage
```

#### 4. Linux Kernel Parameters
```bash
# Edit /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="... hugepagesz=1G hugepages=3 isolcpus=1-23"

# Update grub
sudo update-grub
sudo reboot
```

### Benchmarking

#### Test Configuration Changes
```bash
# Run 1M hash benchmark
./xmrig --bench=1M --print-time=10

# Compare results with different settings
# Document hashrate for each configuration
```

---

## Security Considerations

### Best Practices

#### 1. Wallet Security
- **Never share** your wallet seed phrase
- Use a **dedicated mining wallet**
- Consider **hardware wallet** for storage
- Enable **2FA** on exchange accounts

#### 2. System Security
```bash
# Firewall configuration
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh  # If using SSH

# Disable XMRig API external access
# In config: "host": "127.0.0.1"  # Local only
```

#### 3. Pool Selection
- Use **TLS-enabled pools** (port 443)
- Verify pool reputation
- Monitor pool fees (should be ≤1%)
- Consider **P2Pool** for decentralization

#### 4. Monitoring for Attacks
```bash
# Check for unauthorized miners
ps aux | grep -E "xmrig|minerd|minergate"

# Monitor network connections
netstat -tunap | grep ESTABLISHED

# Check CPU usage
top -bn1 | head -20
```

---

## FAQ

### Q: How much will I earn per day?
**A:** With optimized settings (11-13 KH/s):
- **XMR**: ~0.002-0.003 XMR/day
- **USD**: ~$0.30-0.45/day (at $150/XMR)
- Depends on network difficulty and XMR price

### Q: Why is my hashrate lower than expected?
**A:** Common reasons:
1. Optimizations not applied (run with sudo)
2. Thermal throttling (check temperatures)
3. Background processes using CPU
4. Power saving features enabled
5. RAM running at low frequency

### Q: Should I mine 24/7?
**A:** Consider:
- **Electricity cost**: ~250W total system draw
- **Hardware wear**: Constant high temps reduce lifespan
- **Profitability**: Check if earnings > electricity cost
- **Recommendation**: Mine when electricity is cheap (night rates)

### Q: Can I use the PC while mining?
**A:** Yes, with reduced threads:
```json
// Change to 12 threads for mining + desktop use
"rx": [0,2,4,6,8,10,12,14,16,18,20,22]
```

### Q: How do I update XMRig?
**A:** 
```bash
# Backup config
cp config-optimized.json config-backup.json

# Download new version
wget https://github.com/xmrig/xmrig/releases/download/v6.24.0/xmrig-6.24.0-linux-x64.tar.gz
tar xzf xmrig-6.24.0-linux-x64.tar.gz

# Copy config to new version
cp config-optimized.json xmrig-6.24.0/
```

### Q: What's the minimum payout?
**A:** Varies by pool:
- **SupportXMR**: 0.003 XMR
- **Nanopool**: 0.001 XMR  
- **MineXMR**: 0.004 XMR
- **P2Pool**: 0.0001 XMR (no minimum)

### Q: How do I stop mining?
**A:**
```bash
# Graceful stop
Press Ctrl+C in the mining terminal

# Force stop
killall xmrig

# Verify stopped
ps aux | grep xmrig
```

### Q: Do optimizations persist after reboot?
**A:** No, you must reapply after each reboot:
```bash
# Add to startup (optional)
sudo crontab -e
# Add line:
@reboot /home/linux/Projects/Monero-Xmrig/xmrig/enable_1gb_pages.sh && /home/linux/Projects/Monero-Xmrig/xmrig/msr_boost.sh
```

---

## Quick Command Reference

```bash
# Start mining with optimizations
sudo ./start_mining_optimized.sh

# Monitor mining progress
./xmrig-monitor.sh

# Apply optimizations manually
sudo ./enable_1gb_pages.sh
sudo ./msr_boost.sh
sudo cpupower frequency-set -g performance

# Check temperatures
watch -n 1 sensors

# Check hashrate via API
curl http://127.0.0.1:8080/1/summary | jq .hashrate

# Stop mining
killall xmrig

# Edit configuration
nvim config-optimized.json

# View logs
tail -f xmrig.log

# Benchmark
./xmrig --bench=1M --print-time=10
```

---

## Support & Resources

### Official Resources
- **XMRig**: https://xmrig.com
- **Monero**: https://getmonero.org
- **RandomX**: https://github.com/tevador/RandomX

### Mining Pools
- **SupportXMR**: https://supportxmr.com
- **Nanopool**: https://xmr.nanopool.org
- **P2Pool**: https://p2pool.io

### Monitoring Tools
- **Mining Calculator**: https://whattomine.com
- **Network Stats**: https://miningpoolstats.stream/monero
- **XMR Price**: https://coinmarketcap.com/currencies/monero

---

*Last Updated: November 2024*
*Configuration Version: 1.0*
*For XMRig v6.24.0*