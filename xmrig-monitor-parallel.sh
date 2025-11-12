#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# XMRig Parallel Mining Monitor
# Optimized for Ryzen 9 3900X + RX 580
# Version 2.0 - With Process-Level Parallelism

# Color codes for output
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
readonly REFRESH_RATE=5
readonly MAX_PARALLEL_JOBS=3

# Process management
PRICE_PID=""
DATA_PIDS=()

# Shared data (written to temp files for parallel access)
readonly TEMP_DIR=$(mktemp -d)
readonly PRICE_FILE="$TEMP_DIR/price"
readonly API_FILE="$TEMP_DIR/api_data"
readonly STATS_FILE="$TEMP_DIR/stats"

# Cleanup function
cleanup() {
        # Kill background processes
        if [ -n "$PRICE_PID" ] && kill -0 "$PRICE_PID" 2>/dev/null; then
                kill "$PRICE_PID" 2>/dev/null || true
        fi
        
        for pid in "${DATA_PIDS[@]}"; do
                if kill -0 "$pid" 2>/dev/null; then
                        kill "$pid" 2>/dev/null || true
                fi
        done
        
        # Clean up temp files
        rm -rf "$TEMP_DIR"
        
        echo -e "\n${YELLOW}Mining monitor stopped.${NC}"
        exit 0
}

# Trap signals for clean exit
trap cleanup INT TERM EXIT

# Initialize files with defaults
echo "150" > "$PRICE_FILE"
echo "{}" > "$API_FILE"
echo "0,0,0" > "$STATS_FILE"

# Function to validate numeric input
validate_number() {
        local num="${1:-}"
        case "$num" in
                ''|*[!0-9.]*) return 1 ;;
                *) return 0 ;;
        esac
}

# Parallel function to fetch XMR price
fetch_xmr_price_async() {
        while true; do
                local price_json
                price_json=$(timeout 5 curl -s "https://api.coingecko.com/api/v3/simple/price?ids=monero&vs_currencies=usd" 2>/dev/null || echo "")
                
                if [[ $price_json =~ \"usd\":([0-9]+\.?[0-9]*) ]]; then
                        echo "${BASH_REMATCH[1]}" > "$PRICE_FILE"
                else
                        echo "150" > "$PRICE_FILE"  # Fallback
                fi
                
                sleep 60  # Update every minute
        done
}

# Parallel function to fetch API data continuously
fetch_api_data_async() {
        while true; do
                local api_response
                api_response=$(timeout 2 curl -s "$API_URL/1/summary" 2>/dev/null || echo "{}")
                
                if [ -n "$api_response" ] && [ "$api_response" != "{}" ]; then
                        echo "$api_response" > "$API_FILE"
                fi
                
                sleep "$REFRESH_RATE"
        done
}

# Parallel function to calculate stats
calculate_stats_async() {
        while true; do
                local api_data
                api_data=$(cat "$API_FILE" 2>/dev/null || echo "{}")
                
                if [ "$api_data" != "{}" ]; then
                        # Extract key metrics using single awk pass
                        local stats
                        stats=$(echo "$api_data" | awk '
                                BEGIN { ht=0; hc=0; ho=0; sg=0; st=0; up=0 }
                                {
                                        if (match($0, /"hashrate":\{"total":\[([0-9.]+)/, a)) ht=a[1]
                                        if (match($0, /"cpu":\{"hashrate":\[([0-9.]+)/, a)) hc=a[1]
                                        if (match($0, /"opencl":\{"hashrate":\[([0-9.]+)/, a)) ho=a[1]
                                        if (match($0, /"good":([0-9]+)/, a)) sg=a[1]
                                        if (match($0, /"total":([0-9]+)/, a)) st=a[1]
                                        if (match($0, /"uptime":([0-9]+)/, a)) up=a[1]
                                }
                                END { printf "%.2f,%.2f,%.2f,%d,%d,%d", ht, hc, ho, sg, st, up }
                        ')
                        
                        if [ -n "$stats" ]; then
                                echo "$stats" > "$STATS_FILE"
                        fi
                fi
                
                sleep "$REFRESH_RATE"
        done
}

# Function to format hashrate
format_hashrate() {
        local hashrate="${1:-0}"
        
        if ! validate_number "$hashrate"; then
                echo "0 H/s"
                return
        fi
        
        local hashrate_int="${hashrate%%.*}"
        
        if [ "$hashrate_int" -ge 1000000 ]; then
                printf "%.2f MH/s" "$(awk "BEGIN {print $hashrate / 1000000}")"
        elif [ "$hashrate_int" -ge 1000 ]; then
                printf "%.2f KH/s" "$(awk "BEGIN {print $hashrate / 1000}")"
        else
                echo "${hashrate} H/s"
        fi
}

# Function to draw progress bar
draw_progress_bar() {
        local percent="${1:-0}"
        local width=30
        
        if ! validate_number "$percent"; then
                percent=0
        fi
        
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

# Main monitoring function
main() {
        # Check API availability
        if ! curl -s "$API_URL" > /dev/null 2>&1; then
                echo -e "${RED}Error: Cannot connect to XMRig API at $API_URL${NC}"
                echo -e "${YELLOW}Make sure XMRig is running with HTTP API enabled${NC}"
                exit 1
        fi
        
        echo "Starting parallel data collectors..."
        
        # Start background data collection processes
        fetch_xmr_price_async &
        PRICE_PID=$!
        DATA_PIDS+=("$PRICE_PID")
        
        fetch_api_data_async &
        DATA_PIDS+=("$!")
        
        calculate_stats_async &
        DATA_PIDS+=("$!")
        
        # Give collectors time to initialize
        sleep 2
        
        # Main display loop
        while true; do
                clear
                
                # Read collected data from temp files
                local xmr_price
                local stats_line
                xmr_price=$(cat "$PRICE_FILE" 2>/dev/null || echo "150")
                stats_line=$(cat "$STATS_FILE" 2>/dev/null || echo "0,0,0,0,0,0")
                
                # Parse stats
                IFS=',' read -r hashrate_total hashrate_cpu hashrate_opencl shares_good shares_total uptime <<< "$stats_line"
                
                # Set defaults
                hashrate_total="${hashrate_total:-0}"
                hashrate_cpu="${hashrate_cpu:-0}"
                hashrate_opencl="${hashrate_opencl:-0}"
                shares_good="${shares_good:-0}"
                shares_total="${shares_total:-0}"
                uptime="${uptime:-0}"
                
                # Calculate derived values
                local uptime_hours=$(( uptime / 3600 ))
                local uptime_minutes=$(( (uptime % 3600) / 60 ))
                local uptime_seconds=$(( uptime % 60 ))
                
                local acceptance_rate=0
                if [ "$shares_total" -gt 0 ]; then
                        acceptance_rate=$(awk "BEGIN {printf \"%.2f\", $shares_good * 100 / $shares_total}")
                fi
                
                # Calculate earnings (simplified)
                local xmr_per_day
                xmr_per_day=$(awk "BEGIN {printf \"%.8f\", ($hashrate_total * 86400 * 0.6) / (250000 * 4294967296)}")
                
                local usd_per_day
                usd_per_day=$(awk "BEGIN {printf \"%.2f\", $xmr_per_day * $xmr_price}")
                
                # Display header
                echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${CYAN}║${WHITE}      XMRig Parallel Monitor - Ryzen 9 3900X + RX 580              ${CYAN}║${NC}"
                echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
                echo
                
                # Hashrate section
                echo -e "${GREEN}▶ Hashrate${NC}"
                echo -e "  Total:       ${WHITE}$(format_hashrate "$hashrate_total")${NC}"
                echo -e "  ├─ CPU:      ${CYAN}$(format_hashrate "$hashrate_cpu")${NC}"
                echo -e "  └─ GPU:      ${PURPLE}$(format_hashrate "$hashrate_opencl")${NC}"
                echo
                
                # Statistics
                echo -e "${GREEN}▶ Statistics${NC}"
                echo -e "  Uptime:      ${YELLOW}${uptime_hours}h ${uptime_minutes}m ${uptime_seconds}s${NC}"
                echo -e "  Shares:      ${GREEN}${shares_good}${NC}/${shares_total} (${GREEN}${acceptance_rate}%${NC} accepted)"
                echo
                
                # Earnings
                echo -e "${GREEN}▶ Earnings (XMR @ \$${xmr_price})${NC}"
                echo -e "  Per Day:     ${WHITE}$(printf "%.8f" "$xmr_per_day") XMR${NC} ≈ ${GREEN}\$${usd_per_day}${NC}"
                echo
                
                # Performance indicator
                local perf_status="🟢 Optimal"
                if validate_number "$hashrate_total"; then
                        local ht_int="${hashrate_total%%.*}"
                        if [ "$ht_int" -lt 10000 ]; then
                                perf_status="🟡 Below Expected"
                        fi
                        if [ "$ht_int" -lt 8000 ]; then
                                perf_status="🔴 Poor"
                        fi
                fi
                
                echo -e "${GREEN}▶ Performance${NC}"
                echo -e "  Status:      $perf_status"
                echo -e "  Expected:    ${CYAN}CPU: 10-12 KH/s, GPU: 0.7-0.9 KH/s${NC}"
                echo
                
                # Footer
                echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
                echo -e "Parallel collectors active | Refreshing every ${REFRESH_RATE}s | Press ${RED}Ctrl+C${NC} to exit"
                
                sleep "$REFRESH_RATE"
        done
}

# Run main function
main