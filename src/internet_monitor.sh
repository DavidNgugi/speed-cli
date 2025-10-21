#!/bin/bash

# Internet Monitor - Background monitoring script

set -e

# Configuration
LOG_FILE="${HOME}/.speed-cli/monitor.log"
CONFIG_FILE="${HOME}/.speed-cli/config"
INTERVAL=3600  # 1 hour default
MAX_LOG_ENTRIES=1000
EXPECTED_DOWNLOAD=100  # Default expected speeds
EXPECTED_UPLOAD=10

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to create necessary directories
setup_directories() {
    mkdir -p "$(dirname "$LOG_FILE")"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    mkdir -p "${HOME}/internet_logs"
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    fi
}

# Function to save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# Speed CLI Configuration
EXPECTED_DOWNLOAD=$EXPECTED_DOWNLOAD
EXPECTED_UPLOAD=$EXPECTED_UPLOAD
MONITOR_INTERVAL=$INTERVAL
MAX_LOG_ENTRIES=$MAX_LOG_ENTRIES
EOF
}

# Function to detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Function to run speed test on macOS
run_speed_test_macos() {
    if ! command -v networkquality &> /dev/null; then
        print_status $RED "Error: networkquality command not found"
        echo "This command is available on macOS Big Sur (11.0) or later."
        exit 1
    fi
    
    networkquality 2>/dev/null | while read line; do
        if [[ $line == *"Uplink capacity:"* ]]; then
            upload=$(echo "$line" | awk '{print $3}')
            echo -e "${BLUE}Upload: ${GREEN}${upload}${NC}"
        elif [[ $line == *"Downlink capacity:"* ]]; then
            download=$(echo "$line" | awk '{print $3}')
            echo -e "${BLUE}Download: ${GREEN}${download}${NC}"
        elif [[ $line == *"Idle Latency:"* ]]; then
            latency=$(echo "$line" | awk '{print $3}')
            echo -e "${BLUE}Latency: ${GREEN}${latency}${NC}"
        elif [[ $line == *"Responsiveness:"* ]]; then
            responsiveness=$(echo "$line" | awk '{print $2}')
            echo -e "${BLUE}Responsiveness: ${GREEN}${responsiveness}${NC}"
        fi
    done
}

# Function to run speed test on Linux
run_speed_test_linux() {
    # Try speedtest-cli first (preferred method)
    if command -v speedtest >/dev/null 2>&1; then
        echo -e "${BLUE}Running speed test with speedtest-cli...${NC}"
        local json_output=$(speedtest --accept-license --accept-gdpr -f json 2>/dev/null)
        
        if [ -n "$json_output" ]; then
            if command -v jq >/dev/null 2>&1; then
                # Use jq for JSON parsing
                local dl_bw=$(echo "$json_output" | jq -r '.download.bandwidth // 0')
                local ul_bw=$(echo "$json_output" | jq -r '.upload.bandwidth // 0')
                local ping_ms=$(echo "$json_output" | jq -r '.ping.latency // 0')
            else
                # Fallback to Python for JSON parsing
                local parsed=$(printf '%s' "$json_output" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    dl = data.get('download', {}).get('bandwidth', 0)
    ul = data.get('upload', {}).get('bandwidth', 0)
    lat = data.get('ping', {}).get('latency', 0)
    print(f'{dl},{ul},{lat}')
except:
    print('0,0,0')
" 2>/dev/null)
                local dl_bw=$(echo "$parsed" | awk -F, '{print $1}')
                local ul_bw=$(echo "$parsed" | awk -F, '{print $2}')
                local ping_ms=$(echo "$parsed" | awk -F, '{print $3}')
            fi
            
            # Convert bandwidth (bytes/sec) to Mbps
            local download_speed=$(echo "scale=2; ($dl_bw * 8) / 1000000" | bc -l 2>/dev/null || echo "0")
            local upload_speed=$(echo "scale=2; ($ul_bw * 8) / 1000000" | bc -l 2>/dev/null || echo "0")
            local latency=$(printf '%.2f' "${ping_ms:-0}" 2>/dev/null || echo "0")
            
            echo -e "${BLUE}Download: ${GREEN}${download_speed} Mbps${NC}"
            echo -e "${BLUE}Upload: ${GREEN}${upload_speed} Mbps${NC}"
            echo -e "${BLUE}Latency: ${GREEN}${latency} ms${NC}"
        else
            print_status $RED "Speedtest-cli failed, trying fallback method..."
            run_speed_test_linux_fallback
        fi
    else
        print_status $YELLOW "speedtest-cli not found, using fallback method..."
        echo "To install speedtest-cli:"
        echo "  Debian/Ubuntu: sudo apt install speedtest-cli"
        echo "  Or via pip: pip install speedtest-cli"
        echo ""
        run_speed_test_linux_fallback
    fi
}

# Fallback method for Linux when speedtest-cli is not available
run_speed_test_linux_fallback() {
    # Use Hetzner test file (100MB) as recommended
    local test_url="https://ash-speed.hetzner.com/100MB.bin"
    local temp_file="/tmp/speed_test_$$"
    
    if ! command -v wget &> /dev/null; then
        print_status $RED "Error: wget command not found"
        echo "Please install wget: sudo apt-get install wget (Ubuntu/Debian) or sudo yum install wget (RHEL/CentOS)"
        exit 1
    fi
    
    echo -e "${BLUE}Downloading test file (100MB)...${NC}"
    local start_time=$(date +%s.%N)
    if wget -q --progress=bar:force "$test_url" -O "$temp_file" 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
        local file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "104857600") # 100MB fallback
        local speed_mbps=$(echo "scale=2; ($file_size * 8) / ($duration * 1024 * 1024)" | bc -l 2>/dev/null || echo "0")
        
        echo -e "${BLUE}Download: ${GREEN}${speed_mbps} Mbps${NC}"
        echo -e "${BLUE}Upload: ${GREEN}Not available (install speedtest-cli for upload testing)${NC}"
        echo -e "${BLUE}Latency: ${GREEN}Not available (install speedtest-cli for latency testing)${NC}"
        
        rm -f "$temp_file"
    else
        print_status $RED "Download test failed"
        exit 1
    fi
}

# Function to run speed test on Windows
run_speed_test_windows() {
    # Try speedtest-cli first (preferred method)
    local powershell_script="
        try {
            # Check if speedtest-cli is available
            \$speedtestPath = Get-Command speedtest.exe -ErrorAction SilentlyContinue
            if (\$speedtestPath) {
                Write-Output 'Running speed test with speedtest-cli...'
                \$json = & speedtest.exe --accept-license --accept-gdpr -f json 2>\$null
                if (\$json) {
                    \$data = \$json | ConvertFrom-Json
                    \$dl = [math]::Round((\$data.download.bandwidth * 8) / 1000000, 2)
                    \$ul = [math]::Round((\$data.upload.bandwidth * 8) / 1000000, 2)
                    \$lat = [math]::Round([double]\$data.ping.latency, 2)
                    Write-Output \"Download: \$dl Mbps\"
                    Write-Output \"Upload: \$ul Mbps\"
                    Write-Output \"Latency: \$lat ms\"
                } else {
                    Write-Output 'Speedtest-cli failed, trying fallback method...'
                    throw 'Speedtest-cli failed'
                }
            } else {
                Write-Output 'speedtest-cli not found, using fallback method...'
                Write-Output 'To install speedtest-cli:'
                Write-Output '  pip install speedtest-cli'
                Write-Output ''
                throw 'Speedtest-cli not found'
            }
        } catch {
            # Fallback method using Hetzner test file
            try {
                Write-Output 'Downloading test file (100MB)...'
                \$testUrl = 'https://ash-speed.hetzner.com/100MB.bin'
                \$tempFile = \"\$env:TEMP\\speed_test_\$(Get-Random).bin\"
                \$startTime = Get-Date
                Invoke-WebRequest -Uri \$testUrl -OutFile \$tempFile -UseBasicParsing
                \$endTime = Get-Date
                \$duration = (\$endTime - \$startTime).TotalSeconds
                \$fileSize = (Get-Item \$tempFile).Length
                \$speedMbps = [math]::Round((\$fileSize * 8) / (\$duration * 1024 * 1024), 2)
                Write-Output \"Download: \$speedMbps Mbps\"
                Write-Output 'Upload: Not available (install speedtest-cli for upload testing)'
                Write-Output 'Latency: Not available (install speedtest-cli for latency testing)'
                Remove-Item \$tempFile -ErrorAction SilentlyContinue
            } catch {
                Write-Output 'Download test failed'
                exit 1
            }
        }
    "
    
    if command -v powershell &> /dev/null; then
        powershell -Command "$powershell_script"
    else
        print_status $RED "Error: PowerShell not found"
        echo "Please ensure PowerShell is available on your Windows system."
        exit 1
    fi
}

# Function to run speed test and display results
run_speed_test() {
    echo -e "${BLUE}Testing your internet speed...${NC}"
    echo "This may take a few moments..."
    echo ""
    
    local platform=$(detect_platform)
    
    case "$platform" in
        "macos")
            run_speed_test_macos
            ;;
        "linux")
            run_speed_test_linux
            ;;
        "windows")
            run_speed_test_windows
            ;;
        *)
            print_status $RED "Unsupported platform: $OSTYPE"
            echo "Supported platforms: macOS, Linux, Windows"
            exit 1
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        echo ""
        print_status $GREEN "✓ Speed test completed successfully!"
    else
        print_status $RED "✗ Speed test failed. Please check your internet connection."
        exit 1
    fi
}

# Function to check if speeds are degraded
check_performance() {
    local download=$1
    local upload=$2
    local latency=$3
    
    local degraded=false
    local alert_message=""
    
    # Check if download is significantly below expected (less than 80% of expected)
    local download_threshold=$(echo "$EXPECTED_DOWNLOAD * 0.8" | bc -l)
    if (( $(echo "$download < $download_threshold" | bc -l) )); then
        degraded=true
        alert_message="${alert_message}Download speed ${download} Mbps is below expected ${EXPECTED_DOWNLOAD} Mbps. "
    fi
    
    # Check if upload is significantly below expected (less than 80% of expected)
    local upload_threshold=$(echo "$EXPECTED_UPLOAD * 0.8" | bc -l)
    if (( $(echo "$upload < $upload_threshold" | bc -l) )); then
        degraded=true
        alert_message="${alert_message}Upload speed ${upload} Mbps is below expected ${EXPECTED_UPLOAD} Mbps. "
    fi
    
    # Check if latency is high (more than 100ms)
    if (( $(echo "$latency > 100" | bc -l) )); then
        degraded=true
        alert_message="${alert_message}High latency: ${latency}ms. "
    fi
    
    if [ "$degraded" = true ]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo "$timestamp - PERFORMANCE ALERT: $alert_message" >> "${HOME}/internet_logs/alerts.log"
        print_status $YELLOW "Performance alert: $alert_message"
    fi
    
    return $([ "$degraded" = true ] && echo 1 || echo 0)
}

# Function to log speed test result to CSV
log_speed_test() {
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local platform=$(detect_platform)
    local download_speed=0
    local upload_speed=0
    local latency=0
    local responsiveness=0
    local status="OK"
    
    case "$platform" in
        "macos")
            local network_output=$(networkquality 2>/dev/null)
            download_speed=$(echo "$network_output" | grep "Downlink capacity:" | awk '{print $3}' | sed 's/Mbps//')
            upload_speed=$(echo "$network_output" | grep "Uplink capacity:" | awk '{print $3}' | sed 's/Mbps//')
            latency=$(echo "$network_output" | grep "Idle Latency:" | awk '{print $3}' | sed 's/ms//')
            responsiveness=$(echo "$network_output" | grep "Responsiveness:" | awk '{print $2}' | sed 's/rpm//')
            
            # Set defaults if values are empty
            download_speed=${download_speed:-0}
            upload_speed=${upload_speed:-0}
            latency=${latency:-0}
            responsiveness=${responsiveness:-0}
            
            # Check performance and set status
            if check_performance "$download_speed" "$upload_speed" "$latency"; then
                status="DEGRADED"
            else
                status="OK"
            fi
            ;;
        "linux")
            # Prefer Ookla Speedtest CLI if available; fallback to wget method
            if command -v speedtest >/dev/null 2>&1; then
                local json_output=$(speedtest --accept-license --accept-gdpr -f json 2>/dev/null)
                if [ -n "$json_output" ]; then
                    if command -v jq >/dev/null 2>&1; then
                        local dl_bw=$(echo "$json_output" | jq -r '.download.bandwidth // 0')
                        local ul_bw=$(echo "$json_output" | jq -r '.upload.bandwidth // 0')
                        local ping_ms=$(echo "$json_output" | jq -r '.ping.latency // 0')
                    else
                        # Fallback to Python for JSON parsing if jq is not available
                        local parsed=$(printf '%s' "$json_output" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    dl = data.get('download', {}).get('bandwidth', 0)
    ul = data.get('upload', {}).get('bandwidth', 0)
    lat = data.get('ping', {}).get('latency', 0)
    print(f'{dl},{ul},{lat}')
except:
    print('0,0,0')
" 2>/dev/null)
                        local dl_bw=$(echo "$parsed" | awk -F, '{print $1}')
                        local ul_bw=$(echo "$parsed" | awk -F, '{print $2}')
                        local ping_ms=$(echo "$parsed" | awk -F, '{print $3}')
                    fi
                    # Convert bandwidth (bytes/sec) to Mbps
                    download_speed=$(echo "scale=2; ($dl_bw * 8) / 1000000" | bc -l 2>/dev/null || echo "0")
                    upload_speed=$(echo "scale=2; ($ul_bw * 8) / 1000000" | bc -l 2>/dev/null || echo "0")
                    latency=$(printf '%.2f' "${ping_ms:-0}" 2>/dev/null || echo "0")
                    responsiveness=0
                    if check_performance "$download_speed" "$upload_speed" "$latency"; then
                        status="DEGRADED"
                    else
                        status="OK"
                    fi
                else
                    status="FAILED"
                fi
            else
                # Fallback: simple wget-based download timing using Hetzner test file
                local test_url="https://ash-speed.hetzner.com/100MB.bin"
                local temp_file="/tmp/speed_test_$$"
                local start_time=$(date +%s.%N)
                if wget -q "$test_url" -O "$temp_file" 2>/dev/null; then
                    local end_time=$(date +%s.%N)
                    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
                    local file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "104857600") # 100MB fallback
                    download_speed=$(echo "scale=2; ($file_size * 8) / ($duration * 1024 * 1024)" | bc -l 2>/dev/null || echo "0")
                    upload_speed=0
                    latency=0
                    responsiveness=0
                    if check_performance "$download_speed" "$upload_speed" "$latency"; then
                        status="DEGRADED"
                    else
                        status="OK"
                    fi
                    rm -f "$temp_file"
                else
                    status="FAILED"
                fi
            fi
            ;;
        "windows")
            # Prefer Ookla Speedtest CLI on Windows via PowerShell
            local powershell_script="
                try {
                    # Check if speedtest-cli is available
                    \$speedtestPath = Get-Command speedtest.exe -ErrorAction SilentlyContinue
                    if (\$speedtestPath) {
                        \$json = & speedtest.exe --accept-license --accept-gdpr -f json 2>\$null
                        if (\$json) {
                            \$d = \$json | ConvertFrom-Json
                            \$dl = [math]::Round((\$d.download.bandwidth * 8) / 1000000, 2)
                            \$ul = [math]::Round((\$d.upload.bandwidth * 8) / 1000000, 2)
                            \$lat = [math]::Round([double]\$d.ping.latency, 2)
                            Write-Output \"\$dl,\$ul,\$lat\"
                        } else {
                            Write-Output 'ERROR'
                        }
                    } else {
                        # Fallback method using Hetzner test file
                        \$testUrl = 'https://ash-speed.hetzner.com/100MB.bin'
                        \$tempFile = \"\$env:TEMP\\speed_test_\$(Get-Random).bin\"
                        \$startTime = Get-Date
                        Invoke-WebRequest -Uri \$testUrl -OutFile \$tempFile -UseBasicParsing
                        \$endTime = Get-Date
                        \$duration = (\$endTime - \$startTime).TotalSeconds
                        \$fileSize = (Get-Item \$tempFile).Length
                        \$speedMbps = [math]::Round((\$fileSize * 8) / (\$duration * 1024 * 1024), 2)
                        Write-Output \"\$speedMbps,0,0\"
                        Remove-Item \$tempFile -ErrorAction SilentlyContinue
                    }
                } catch {
                    Write-Output 'ERROR'
                }
            "
            local result=$(powershell -Command "$powershell_script" 2>/dev/null)
            if [[ "$result" != "ERROR" && -n "$result" ]]; then
                IFS=',' read -r download_speed upload_speed latency <<EOF
$result
EOF
                responsiveness=0
                if check_performance "$download_speed" "$upload_speed" "$latency"; then
                    status="DEGRADED"
                else
                    status="OK"
                fi
            else
                status="FAILED"
            fi
            ;;
        *)
            status="FAILED"
            ;;
    esac
    
    # Create CSV log file if it doesn't exist
    local csv_file="${HOME}/internet_logs/speed_log_$(date +%Y-%m).csv"
    mkdir -p "${HOME}/internet_logs"
    
    # Add header if file doesn't exist
    if [ ! -f "$csv_file" ]; then
        echo "timestamp,download_mbps,upload_mbps,latency_ms,responsiveness_rpm,status" > "$csv_file"
    fi
    
    # Append the test result
    echo "$timestamp,$download_speed,$upload_speed,$latency,$responsiveness,$status" >> "$csv_file"
    
    if [[ "$status" != "FAILED" ]]; then
        print_status $GREEN "Speed test logged at $timestamp"
    else
        print_status $RED "Speed test failed at $timestamp"
    fi
}

# Function to clean old log entries
clean_logs() {
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE")
        if [ "$line_count" -gt "$MAX_LOG_ENTRIES" ]; then
            tail -n "$MAX_LOG_ENTRIES" "$LOG_FILE" > "${LOG_FILE}.tmp"
            mv "${LOG_FILE}.tmp" "$LOG_FILE"
            print_status $YELLOW "Cleaned old log entries"
        fi
    fi
}

# Function to show help
show_help() {
    echo "Speed CLI - Background Speed Monitoring"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -t, --test           Run speed test now and display results"
    echo "  -i, --interval SEC   Set monitoring interval in seconds (default: 300)"
    echo "  -s, --start          Start monitoring in background"
    echo "  -k, --kill           Stop background monitoring"
    echo "  -l, --log            Show recent log entries"
    echo "  -c, --config         Show current configuration"
    echo ""
    echo "Examples:"
    echo "  $0 --start           # Start monitoring every 5 minutes"
    echo "  $0 --interval 60 --start  # Start monitoring every minute"
    echo "  $0 --log             # Show recent speed test results"
    echo "  $0 --kill            # Stop monitoring"
}

# Function to start monitoring
start_monitoring() {
    local pid_file="${HOME}/.speed-cli/monitor.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            print_status $YELLOW "Monitoring is already running (PID: $pid)"
            return 1
        else
            rm -f "$pid_file"
        fi
    fi
    
    print_status $BLUE "Starting internet monitoring..."
    print_status $BLUE "Interval: ${INTERVAL} seconds"
    print_status $BLUE "Log file: $LOG_FILE"
    
    # Start monitoring in background
    (
        while true; do
            log_speed_test
            clean_logs
            sleep "$INTERVAL"
        done
    ) &
    
    local monitor_pid=$!
    echo "$monitor_pid" > "$pid_file"
    
    print_status $GREEN "Monitoring started (PID: $monitor_pid)"
    print_status $BLUE "Use '$0 --kill' to stop monitoring"
}

# Function to stop monitoring
stop_monitoring() {
    local pid_file="${HOME}/.speed-cli/monitor.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pid_file"
            print_status $GREEN "Monitoring stopped"
        else
            rm -f "$pid_file"
            print_status $YELLOW "Monitoring was not running"
        fi
    else
        print_status $YELLOW "No monitoring process found"
    fi
}

# Function to show logs
show_logs() {
    if [ -f "$LOG_FILE" ]; then
        print_status $BLUE "Recent speed test results:"
        echo ""
        tail -n 20 "$LOG_FILE"
    else
        print_status $YELLOW "No log file found"
    fi
}

# Function to show configuration
show_config() {
    print_status $BLUE "Current configuration:"
    echo ""
    echo "Interval: ${INTERVAL} seconds"
    echo "Max log entries: $MAX_LOG_ENTRIES"
    echo "Log file: $LOG_FILE"
    echo "Config file: $CONFIG_FILE"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--test)
            RUN_TEST=true
            shift
            ;;
        -i|--interval)
            INTERVAL="$2"
            shift 2
            ;;
        -s|--start)
            START_MONITORING=true
            shift
            ;;
        -k|--kill)
            STOP_MONITORING=true
            shift
            ;;
        -l|--log)
            SHOW_LOGS=true
            shift
            ;;
        -c|--config)
            SHOW_CONFIG=true
            shift
            ;;
        *)
            print_status $RED "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
main() {
    setup_directories
    load_config
    
    if [ "$RUN_TEST" = true ]; then
        run_speed_test
        echo ""
        print_status $BLUE "Logging test results..."
        log_speed_test
    elif [ "$START_MONITORING" = true ]; then
        start_monitoring
    elif [ "$STOP_MONITORING" = true ]; then
        stop_monitoring
    elif [ "$SHOW_LOGS" = true ]; then
        show_logs
    elif [ "$SHOW_CONFIG" = true ]; then
        show_config
    else
        show_help
    fi
    
    save_config
}

# Run main function
main
