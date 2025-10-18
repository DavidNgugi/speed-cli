#!/bin/bash

# Internet Monitor - Background monitoring script

set -e

# Configuration
LOG_FILE="${HOME}/.speed-cli/monitor.log"
CONFIG_FILE="${HOME}/.speed-cli/config"
INTERVAL=300  # 5 minutes default
MAX_LOG_ENTRIES=1000

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
INTERVAL=$INTERVAL
MAX_LOG_ENTRIES=$MAX_LOG_ENTRIES
EOF
}

# Function to log speed test result
log_speed_test() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local result=$(speedtest-cli --simple 2>/dev/null | tr '\n' ' ')
    
    if [ $? -eq 0 ]; then
        echo "$timestamp - $result" >> "$LOG_FILE"
        print_status $GREEN "Speed test logged at $timestamp"
    else
        echo "$timestamp - ERROR: Speed test failed" >> "$LOG_FILE"
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
    
    if [ "$START_MONITORING" = true ]; then
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
