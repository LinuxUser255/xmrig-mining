#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# XMRig Real-Time Mining Monitor
# For AMD Ryzen 9 3900X + RX 580 Setup
# Version 1.1

# Color codes for pretty output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Configuration
readonly API_URL="http://127.0.0.1:8080"
readonly REFRESH_RATE=5  # seconds

# Process management
PRICE_PID=""

# Pool configurations (update with your pool's minimum payout)
declare -A POOL_MINIMUM_PAYOUTS
POOL_MINIMUM_PAYOUTS["supportxmr"]=0.003
POOL_MINIMUM_PAYOUTS["nanopool"]=0.001
POOL_MINIMUM_PAYOUTS["minexmr"]=0.004
POOL_MINIMUM_PAYOUTS["default"]=0.003

# Current XMR price (updates automatically)
XMR_PRICE_USD=0

# Function to validate numeric input
validate_number() {
    local num="${1:-}"
    case "$num" in
        ''|*[!0-9.]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Function to get XMR price
get_xmr_price() {
    local price_json
    price_json=$(timeout 5 curl -s "https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd" 2>/dev/null || echo "")
    if [[ $price_json =~ \"usd\":([0-9]+\.?[0-9]*) ]]; then
        XMR_PRICE_USD="${BASH_REMATCH[1]}"
    else
        XMR_PRICE_USD=150  # Fallback price if API fails
    fi
}

# Function to format hashrate
format_hashrate() {
    local hashrate="${1:-0}"
    
    # Validate input
    if ! validate_number "$hashrate"; then
        echo "0 H/s"
        return
    fi
    
    # Use arithmetic instead of bc for better performance
    local hashrate_int="${hashrate%%.*}"
    
    if [ "$hashrate_int" -ge 1000000 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $hashrate / 1000000}") MH/s"
    elif [ "$hashrate_int" -ge 1000 ]; then
        echo "$(awk "BEGIN {printf \"%.2f\", $hashrate / 1000}") KH/s"
    else
        echo "${hashrate} H/s"
    fi
}

# Function to calculate earnings
calculate_earnings() {
    local hashrate="${1:-0}"
    local difficulty="${2:-250000}"
    local block_reward="${3:-0.6}"
    local price="${4:-150}"
    
    # Validate inputs
    for var in "$hashrate" "$difficulty" "$block_reward" "$price"; do
        if ! validate_number "$var"; then
            echo "0"
            return
        fi
    done
    
    # Monero network hash rate (approximate, in H/s)
    local network_hashrate=2500000000  # 2.5 GH/s typical
    
    # Calculate XMR per day
    # Formula: (hashrate / network_hashrate) * blocks_per_day * block_reward
    local blocks_per_day=720  # ~2 minute block time
    local xmr_per_day
    
    # More realistic calculation based on current difficulty
    if [ -n "$difficulty" ] && [ "$difficulty" != "0" ]; then
        # XMR per day = (hashrate * 86400 * block_reward) / (difficulty * 2^32)
        xmr_per_day=$(awk "BEGIN {printf \"%.8f\", ($hashrate * 86400 * $block_reward) / ($difficulty * 4294967296)}")
    else
        xmr_per_day=$(awk "BEGIN {printf \"%.8f\", ($hashrate / $network_hashrate) * $blocks_per_day * $block_reward}")
    fi
    
    echo "$xmr_per_day"
}

# Function to get pool stats (generic, works with most pools)
get_pool_stats() {
    local wallet=$1
    local pool_url=$2
    
    # Extract pool domain
    local pool_domain=$(echo $pool_url | cut -d: -f1 | sed 's/\./-/g')
    
    # Try to get stats from common pool API endpoints
    # This is a simplified version - each pool has different APIs
    echo "0"  # Return 0 as placeholder - implement specific pool APIs as needed
}

# Function to draw a progress bar
draw_progress_bar() {
    local percent="${1:-0}"
    local width=30
    
    # Validate and constrain percent
    if ! validate_number "$percent"; then
        percent=0
    fi
    
    # Use arithmetic instead of bc
    local percent_int="${percent%%.*}"
    [ "$percent_int" -gt 100 ] && percent_int=100
    [ "$percent_int" -lt 0 ] && percent_int=0
    
    local filled=$(( percent_int * width / 100 ))
    local empty=$(( width - filled ))
    
    printf "["
    [ "$filled" -gt 0 ] && printf "%${filled}s" | tr ' ' '█'
    [ "$empty" -gt 0 ] && printf "%${empty}s" | tr ' ' '▒'
    printf "] %3d%%" "$percent_int"
}

# Main monitoring loop
main() {
    # Check if XMRig API is accessible
    if ! curl -s "$API_URL" > /dev/null 2>&1; then
        echo -e "${RED}Error: Cannot connect to XMRig API at $API_URL${NC}"
        echo -e "${YELLOW}Make sure XMRig is running and HTTP API is enabled in config${NC}"
        echo -e "Add to your config.json:"
        echo -e '  "http": {'
        echo -e '    "enabled": true,'
        echo -e '    "host": "127.0.0.1",'
        echo -e '    "port": 8080'
        echo -e '  }'
        exit 1
    fi
    
    # Initial price fetch
    get_xmr_price
    local price_update_counter=0
    
    while true; do
        clear
        
        # Get XMRig stats from API
        local api_response=$(curl -s "$API_URL/1/summary")
        
        # Parse JSON response (using grep and sed for compatibility)
        local hashrate_total=$(echo "$api_response" | grep -o '"hashrate":{"total":\[[^]]*\]' | grep -o '[0-9.]*' | head -1)
        local hashrate_cpu=$(echo "$api_response" | grep -o '"cpu":{"hashrate":\[[^]]*\]' | grep -o '[0-9.]*' | head -1)
        local hashrate_opencl=$(echo "$api_response" | grep -o '"opencl":{"hashrate":\[[^]]*\]' | grep -o '[0-9.]*' | head -1)
        local shares_good=$(echo "$api_response" | grep -o '"good":[0-9]*' | cut -d: -f2 | head -1)
        local shares_total=$(echo "$api_response" | grep -o '"total":[0-9]*' | cut -d: -f2 | head -1)
        local uptime=$(echo "$api_response" | grep -o '"uptime":[0-9]*' | cut -d: -f2)
        local pool=$(echo "$api_response" | grep -o '"pool":"[^"]*"' | cut -d'"' -f4)
        local algo=$(echo "$api_response" | grep -o '"algo":"[^"]*"' | cut -d'"' -f4)
        
        # Get connection info
        local connection=$(echo "$api_response" | grep -o '"connection":{"pool":"[^"]*"' | cut -d'"' -f4)
        local diff=$(echo "$api_response" | grep -o '"diff":[0-9]*' | cut -d: -f2)
        
        # Set defaults if values are empty
        hashrate_total=${hashrate_total:-0}
        hashrate_cpu=${hashrate_cpu:-0}
        hashrate_opencl=${hashrate_opencl:-0}
        shares_good=${shares_good:-0}
        shares_total=${shares_total:-0}
        uptime=${uptime:-0}
        diff=${diff:-250000}
        
    # Update XMR price every 12 iterations (60 seconds at 5 second refresh)
    ((price_update_counter++))
    if [ "$price_update_counter" -ge 12 ]; then
        # Kill previous price update if still running
        if [ -n "$PRICE_PID" ] && kill -0 "$PRICE_PID" 2>/dev/null; then
            kill "$PRICE_PID" 2>/dev/null || true
        fi
        get_xmr_price &
        PRICE_PID=$!
        price_update_counter=0
    fi
        
        # Calculate uptime in human-readable format
        local uptime_hours=$((uptime / 3600))
        local uptime_minutes=$(( (uptime % 3600) / 60 ))
        local uptime_seconds=$((uptime % 60))
        
        # Calculate share acceptance rate
        local acceptance_rate=0
        if [ "$shares_total" -gt 0 ]; then
            acceptance_rate=$(echo "scale=2; $shares_good * 100 / $shares_total" | bc)
        fi
        
        # Calculate earnings
        local block_reward=0.6  # Current Monero block reward (approximate)
        local xmr_per_day=$(calculate_earnings $hashrate_total $diff $block_reward $XMR_PRICE_USD)
        local xmr_per_hour=$(echo "scale=8; $xmr_per_day / 24" | bc)
        local xmr_per_month=$(echo "scale=8; $xmr_per_day * 30" | bc)
        
        # Calculate USD earnings
        local usd_per_day=$(echo "scale=2; $xmr_per_day * $XMR_PRICE_USD" | bc)
        local usd_per_month=$(echo "scale=2; $xmr_per_month * $XMR_PRICE_USD" | bc)
        
        # Calculate time to minimum payout
        local min_payout=${POOL_MINIMUM_PAYOUTS["default"]}
        local days_to_payout=$(echo "scale=2; $min_payout / $xmr_per_day" | bc 2>/dev/null || echo "999")
        local hours_to_payout=$(echo "scale=1; $days_to_payout * 24" | bc 2>/dev/null || echo "999")
        
        # Calculate current earnings progress
        local current_xmr=$(echo "scale=8; $xmr_per_hour * ($uptime / 3600)" | bc)
        local payout_progress=$(echo "scale=0; ($current_xmr / $min_payout) * 100" | bc 2>/dev/null || echo "0")
        if [ "$payout_progress" -gt 100 ]; then
            payout_progress=100
        fi
        
        # Display header
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${WHITE}           XMRig Mining Monitor - Ryzen 9 3900X + RX 580           ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        
        # Connection info
        echo -e "${GREEN}▶ Connection${NC}"
        echo -e "  Pool:        ${YELLOW}$pool${NC}"
        echo -e "  Algorithm:   ${YELLOW}$algo${NC}"
        echo -e "  Difficulty:  ${YELLOW}$(printf "%'d" $diff)${NC}"
        echo
        
        # Hashrate section
        echo -e "${GREEN}▶ Hashrate${NC}"
        echo -e "  Total:       ${WHITE}$(format_hashrate $hashrate_total)${NC}"
        echo -e "  ├─ CPU:      ${CYAN}$(format_hashrate $hashrate_cpu)${NC}"
        echo -e "  └─ GPU:      ${PURPLE}$(format_hashrate $hashrate_opencl)${NC}"
        echo
        
        # Mining statistics
        echo -e "${GREEN}▶ Statistics${NC}"
        echo -e "  Uptime:      ${YELLOW}${uptime_hours}h ${uptime_minutes}m ${uptime_seconds}s${NC}"
        echo -e "  Shares:      ${GREEN}$shares_good${NC}/${shares_total} (${GREEN}${acceptance_rate}%${NC} accepted)"
        echo
        
        # Earnings section
        echo -e "${GREEN}▶ Earnings (XMR @ \$${XMR_PRICE_USD})${NC}"
        echo -e "  Per Hour:    ${WHITE}$(printf "%.8f" $xmr_per_hour) XMR${NC} ≈ ${GREEN}\$$(echo "scale=4; $xmr_per_hour * $XMR_PRICE_USD" | bc)${NC}"
        echo -e "  Per Day:     ${WHITE}$(printf "%.8f" $xmr_per_day) XMR${NC} ≈ ${GREEN}\$${usd_per_day}${NC}"
        echo -e "  Per Month:   ${WHITE}$(printf "%.6f" $xmr_per_month) XMR${NC} ≈ ${GREEN}\$${usd_per_month}${NC}"
        echo
        
        # Payout progress
        echo -e "${GREEN}▶ Pool Payout Progress${NC}"
        echo -e "  Minimum:     ${YELLOW}${min_payout} XMR${NC}"
        echo -e "  Earned:      ${WHITE}$(printf "%.8f" $current_xmr) XMR${NC}"
        echo -e "  Progress:    $(draw_progress_bar $payout_progress)"
        echo -e "  Time Left:   ${YELLOW}${days_to_payout} days${NC} (${hours_to_payout} hours)"
        echo
        
        # Performance indicators
        echo -e "${GREEN}▶ Performance${NC}"
        local perf_indicator="🟢 Optimal"
        if (( $(echo "$hashrate_total < 10000" | bc -l) )); then
            perf_indicator="🟡 Below Expected"
        fi
        if (( $(echo "$hashrate_total < 8000" | bc -l) )); then
            perf_indicator="🔴 Poor"
        fi
        echo -e "  Status:      $perf_indicator"
        
        # Expected ranges for this hardware
        echo -e "  Expected:    ${CYAN}CPU: 10-12 KH/s, GPU: 0.7-0.9 KH/s${NC}"
        echo
        
        # Footer
        echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
        echo -e "Refreshing every ${REFRESH_RATE} seconds... Press ${RED}Ctrl+C${NC} to exit"
        
        sleep $REFRESH_RATE
    done
}

# Cleanup function
cleanup() {
    # Kill background price update if running
    if [ -n "$PRICE_PID" ] && kill -0 "$PRICE_PID" 2>/dev/null; then
        kill "$PRICE_PID" 2>/dev/null || true
    fi
    echo -e "\n${YELLOW}Mining monitor stopped.${NC}"
    exit 0
}

# Trap signals for clean exit
trap cleanup INT TERM EXIT

# Run main function
main
