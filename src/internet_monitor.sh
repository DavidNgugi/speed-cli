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
    # Use wget to download a test file and measure speed
    local test_url="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
    local temp_file="/tmp/speed_test_$$"
    
    if ! command -v wget &> /dev/null; then
        print_status $RED "Error: wget command not found"
        echo "Please install wget: sudo apt-get install wget (Ubuntu/Debian) or sudo yum install wget (RHEL/CentOS)"
        exit 1
    fi
    
    echo -e "${BLUE}Downloading test file...${NC}"
    local start_time=$(date +%s.%N)
    if wget -q --progress=bar:force "$test_url" -O "$temp_file" 2>&1; then
        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
        local file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "10485760") # 10MB fallback
        local speed_mbps=$(echo "scale=2; ($file_size * 8) / ($duration * 1024 * 1024)" | bc -l 2>/dev/null || echo "0")
        
        echo -e "${BLUE}Download: ${GREEN}${speed_mbps} Mbps${NC}"
        echo -e "${BLUE}Upload: ${GREEN}Testing...${NC}"
        echo -e "${BLUE}Latency: ${GREEN}Testing...${NC}"
        
        rm -f "$temp_file"
    else
        print_status $RED "Download test failed"
        exit 1
    fi
}

# Function to run speed test on Windows
run_speed_test_windows() {
    local test_url="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
    local temp_file="$TEMP\\speed_test_$$.zip"
    
    # Use PowerShell to download and measure speed
    local powershell_script="
        \$startTime = Get-Date
        try {
            Invoke-WebRequest -Uri '$test_url' -OutFile '$temp_file' -UseBasicParsing
            \$endTime = Get-Date
            \$duration = (\$endTime - \$startTime).TotalSeconds
            \$fileSize = (Get-Item '$temp_file').Length
            \$speedMbps = [math]::Round((\$fileSize * 8) / (\$duration * 1024 * 1024), 2)
            Write-Output \"Download: \$speedMbps Mbps\"
            Remove-Item '$temp_file' -ErrorAction SilentlyContinue
        } catch {
            Write-Output 'Download test failed'
            exit 1
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

# Function to log speed test result
log_speed_test() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local platform=$(detect_platform)
    local result=""
    
    case "$platform" in
        "macos")
            local network_output=$(networkquality 2>/dev/null)
            local download_speed=$(echo "$network_output" | grep "Downlink capacity:" | awk '{print $3}' | sed 's/Mbps//')
            local upload_speed=$(echo "$network_output" | grep "Uplink capacity:" | awk '{print $3}' | sed 's/Mbps//')
            local latency=$(echo "$network_output" | grep "Idle Latency:" | awk '{print $3}' | sed 's/ms//')
            
            # Set defaults if values are empty
            download_speed=${download_speed:-0}
            upload_speed=${upload_speed:-0}
            latency=${latency:-0}
            
            # Check performance and log results
            check_performance "$download_speed" "$upload_speed" "$latency"
            local performance_status=$?
            
            result="Download: ${download_speed} Mbps Upload: ${upload_speed} Mbps Latency: ${latency}ms"
            ;;
        "linux")
            # Use wget for logging on Linux
            local test_url="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
            local temp_file="/tmp/speed_test_$$"
            local start_time=$(date +%s.%N)
            if wget -q "$test_url" -O "$temp_file" 2>/dev/null; then
                local end_time=$(date +%s.%N)
                local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
                local file_size=$(stat -c%s "$temp_file" 2>/dev/null || echo "10485760")
                local download_speed=$(echo "scale=2; ($file_size * 8) / ($duration * 1024 * 1024)" | bc -l 2>/dev/null || echo "0")
                local upload_speed=0  # Linux test doesn't measure upload
                local latency=0       # Linux test doesn't measure latency
                
                # Check performance (only download for Linux)
                check_performance "$download_speed" "$upload_speed" "$latency"
                local performance_status=$?
                
                result="Download: ${download_speed} Mbps Upload: N/A Latency: N/A"
                rm -f "$temp_file"
            else
                result="ERROR: Speed test failed"
            fi
            ;;
        "windows")
            # Use PowerShell for logging on Windows
            local test_url="http://speedtest.wdc01.softlayer.com/downloads/test10.zip"
            local temp_file="$TEMP\\speed_test_$$.zip"
            local powershell_script="
                \$startTime = Get-Date
                try {
                    Invoke-WebRequest -Uri '$test_url' -OutFile '$temp_file' -UseBasicParsing
                    \$endTime = Get-Date
                    \$duration = (\$endTime - \$startTime).TotalSeconds
                    \$fileSize = (Get-Item '$temp_file').Length
                    \$speedMbps = [math]::Round((\$fileSize * 8) / (\$duration * 1024 * 1024), 2)
                    Write-Output \"\$speedMbps\"
                    Remove-Item '$temp_file' -ErrorAction SilentlyContinue
                } catch {
                    Write-Output 'ERROR'
                }
            "
            local download_speed=$(powershell -Command "$powershell_script" 2>/dev/null)
            local upload_speed=0  # Windows test doesn't measure upload
            local latency=0       # Windows test doesn't measure latency
            
            if [[ "$download_speed" != "ERROR" ]]; then
                # Check performance (only download for Windows)
                check_performance "$download_speed" "$upload_speed" "$latency"
                local performance_status=$?
                
                result="Download: ${download_speed} Mbps Upload: N/A Latency: N/A"
            else
                result="ERROR: Speed test failed"
            fi
            ;;
        *)
            result="ERROR: Unsupported platform"
            ;;
    esac
    
    if [[ "$result" != *"ERROR"* ]]; then
        echo "$timestamp - $result" >> "$LOG_FILE"
        print_status $GREEN "Speed test logged at $timestamp"
    else
        echo "$timestamp - $result" >> "$LOG_FILE"
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
