# Step-by-Step Guide: Mining Monero with XMRig Optimization Scripts

## Prerequisites
- Linux system (Debian/Ubuntu recommended)
- XMRig compiled and ready in `/home/linux/Projects/Monero-Xmrig/xmrig`
- Monero wallet address
- Root/sudo access for optimizations

## Step 1: Prepare Your Configuration

### 1.1 Get Your Wallet Address
First, you need a Monero wallet address. Get one from:
- Official Monero GUI wallet
- MyMonero web wallet
- Exchange deposit address (not recommended for long-term)

### 1.2 Create/Edit Configuration File
```bash
cd /home/linux/Projects/Monero-Xmrig/xmrig

# Copy sample config if needed
cp config.json config-optimized.json

# Edit the configuration
nano config-optimized.json
```

Update these critical fields:
- `"url"`: Your mining pool address (e.g., `"pool.minexmr.com:4444"`)
- `"user"`: Your wallet address
- `"pass"`: Usually "x" or your worker name

## Step 2: Apply System Optimizations (Root Required)

### 2.1 Enable Huge Pages for Better Memory Performance
```bash
# Enable 1GB huge pages (best for RandomX)
sudo ./enable_1gb_pages.sh

# Alternative: Use the script in scripts folder
sudo ./scripts/enable_1gb_pages.sh
```

**Expected output:**
- "Successfully allocated 3 x 1GB huge pages" (optimal)
- Or fallback to 2MB huge pages if 1GB not supported

### 2.2 Apply MSR CPU Optimizations
```bash
# Apply MSR boost for your CPU
sudo ./msr_boost.sh

# Alternative: Use the original script
sudo ./scripts/randomx_boost.sh
```

**Expected output for Ryzen 9 3900X:**
- "Detected Zen1/Zen2 CPU (likely Ryzen 9 3900X)"
- "MSR register values for Zen1/Zen2 applied"
- "✓ Optimizations applied for Ryzen 9 3900X"

### 2.3 Set CPU Performance Mode (Optional)
```bash
# Install cpupower if not available
sudo apt-get install linux-cpupower

# Set performance governor
sudo cpupower frequency-set -g performance
```

## Step 3: Start Mining - Two Methods

### Method A: Using the All-in-One Script (Recommended)
```bash
# This script applies all optimizations and starts mining
sudo ./start_mining_optimized.sh
```

This script will:
1. Check system requirements
2. Apply huge pages optimization
3. Apply MSR optimizations
4. Set CPU to performance mode
5. Start XMRig with optimized config

### Method B: Manual Step-by-Step

#### 3.1 Apply Optimizations First
```bash
# Step 1: Enable huge pages
sudo ./enable_1gb_pages.sh

# Step 2: Apply MSR optimizations
sudo ./msr_boost.sh

# Step 3: Set performance mode (optional)
sudo cpupower frequency-set -g performance
```

#### 3.2 Start XMRig
```bash
# Start mining with your config
./xmrig -c config-optimized.json
```

## Step 4: Monitor Mining Performance

### 4.1 Check Initial Output
Look for these indicators of proper optimization:
```
[XXXX-XX-XX XX:XX:XX] huge pages 100% 3/3
[XXXX-XX-XX XX:XX:XX] JIT program light
[XXXX-XX-XX XX:XX:XX] MSR mod enabled
```

### 4.2 Monitor Hashrate
- **Ryzen 9 3900X expected hashrate:** 12,000-14,000 H/s
- Without optimizations: ~8,000-10,000 H/s
- **Performance boost from optimizations:** ~20-30%

### 4.3 Use Monitoring Scripts (Optional)
```bash
# Basic monitoring
./xmrig-monitor.sh

# Parallel monitoring (advanced)
./xmrig-monitor-parallel.sh
```

## Step 5: Verify Optimizations Are Working

### Check Huge Pages:
```bash
grep Huge /proc/meminfo
```
Should show allocated huge pages.

### Check MSR Module:
```bash
lsmod | grep msr
```
Should show msr module loaded.

### Check CPU Governor:
```bash
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```
Should show "performance".

## Optimization Impact Summary

| Optimization | Performance Gain | Command |
|-------------|-----------------|---------|
| 1GB Huge Pages | +10-15% | `sudo ./enable_1gb_pages.sh` |
| MSR Modifications | +10-15% | `sudo ./msr_boost.sh` |
| Performance Governor | +2-5% | `sudo cpupower frequency-set -g performance` |
| **Total Boost** | **+20-30%** | All combined |

## Troubleshooting

### Issue: "MSR modifications require root access"
**Solution:** Run with sudo: `sudo ./msr_boost.sh`

### Issue: "CPU does not support 1GB pages"
**Solution:** Script will automatically fallback to 2MB pages

### Issue: "Failed to allocate huge pages"
**Solution:** 
```bash
# Free memory first
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
# Then retry
sudo ./enable_1gb_pages.sh
```

### Issue: Low hashrate despite optimizations
**Check:**
1. Temperature throttling: `sensors` (install with `apt install lm-sensors`)
2. Background processes: `htop`
3. Correct pool and wallet in config

## Quick Start Command Sequence

For experienced users, here's the complete sequence:
```bash
# Navigate to XMRig directory
cd /home/linux/Projects/Monero-Xmrig/xmrig

# Edit config with your wallet
nano config-optimized.json

# Apply all optimizations and start mining
sudo ./start_mining_optimized.sh
```

## Stopping the Miner
Press `Ctrl+C` to stop mining gracefully.

## Important Notes
- Always use your own wallet address
- Choose a reputable mining pool
- Monitor temperatures to prevent hardware damage
- Optimizations need to be reapplied after system reboot
- Consider adding optimizations to system startup for persistence