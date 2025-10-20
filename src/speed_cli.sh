#!/bin/bash
#
# Speed CLI - CLI Tool
# Simple command-line interface for speed monitoring
# Author: David Ngugi
#

VERSION="1.0.2"
SCRIPTS_DIR="$HOME/scripts"
LOGS_DIR="$HOME/internet_logs"
PLIST_FILE="$HOME/Library/LaunchAgents/com.user.internet.monitor.plist"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PORT=6432

case "$1" in
    dashboard|web)
        echo -e "${BLUE}Starting dashboard server...${NC}"
        echo -e "${BLUE}Open your browser to: http://localhost:${PORT}${NC}"
        echo -e "${BLUE}Press Ctrl+C to stop${NC}"
        python3 "$SCRIPTS_DIR/speed_dashboard.py"
        ;;
    
    test)
        echo -e "${YELLOW}Running speed test...${NC}"
        "$SCRIPTS_DIR/internet_monitor.sh" --test
        ;;
    
    logs)
        LOG_FILE="$LOGS_DIR/speed_log_$(date +%Y-%m).csv"
        if [ -f "$LOG_FILE" ]; then
            echo -e "${BLUE}Recent speed tests:${NC}"
            echo ""
            tail -20 "$LOG_FILE" | column -t -s','
        else
            echo -e "${RED}No logs found yet. Run: speed test${NC}"
        fi
        ;;
    
    alerts)
        if [ -f "$LOGS_DIR/alerts.log" ]; then
            echo -e "${RED}Performance alerts:${NC}"
            echo ""
            cat "$LOGS_DIR/alerts.log"
        else
            echo -e "${GREEN}No alerts yet - your connection is performing well!${NC}"
        fi
        ;;
    
    status)
        # Detect platform and check service status
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if launchctl list | grep -q "internet.monitor"; then
                echo -e "${GREEN}Monitoring is running${NC}"
                echo ""
                launchctl list | grep internet.monitor
                echo ""
                if [ -f "$LOGS_DIR/speed_log_$(date +%Y-%m).csv" ]; then
                    ENTRIES=$(tail -n +2 "$LOGS_DIR/speed_log_$(date +%Y-%m).csv" | wc -l)
                    echo -e "${BLUE}Tests this month: $ENTRIES${NC}"
                fi
            else
                echo -e "${RED}Monitoring is not running${NC}"
                echo "Start it with: speed start"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if systemctl is-active --quiet speed-monitor.service 2>/dev/null; then
                echo -e "${GREEN}Monitoring is running${NC}"
                echo ""
                systemctl status speed-monitor.service --no-pager
                echo ""
                if [ -f "$LOGS_DIR/speed_log_$(date +%Y-%m).csv" ]; then
                    ENTRIES=$(tail -n +2 "$LOGS_DIR/speed_log_$(date +%Y-%m).csv" | wc -l)
                    echo -e "${BLUE}Tests this month: $ENTRIES${NC}"
                fi
            else
                echo -e "${RED}Monitoring is not running${NC}"
                echo "Start it with: speed start"
            fi
        else
            echo -e "${YELLOW}Service status check not implemented for this platform${NC}"
        fi
        ;;
    
    start)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if launchctl list | grep -q "internet.monitor"; then
                echo -e "${YELLOW}Already running${NC}"
            else
                launchctl load "$PLIST_FILE"
                echo -e "${GREEN}Monitoring started${NC}"
                echo "Tests will run every hour automatically"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if systemctl is-active --quiet speed-monitor.service 2>/dev/null; then
                echo -e "${YELLOW}Already running${NC}"
            else
                sudo systemctl start speed-monitor.service
                echo -e "${GREEN}Monitoring started${NC}"
                echo "Tests will run every hour automatically"
            fi
        else
            echo -e "${YELLOW}Service management not implemented for this platform${NC}"
        fi
        ;;
    
    stop)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if launchctl list | grep -q "internet.monitor"; then
                launchctl unload "$PLIST_FILE"
                echo -e "${GREEN}Monitoring stopped${NC}"
            else
                echo -e "${YELLOW}Not running${NC}"
            fi
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if systemctl is-active --quiet speed-monitor.service 2>/dev/null; then
                sudo systemctl stop speed-monitor.service
                echo -e "${GREEN}Monitoring stopped${NC}"
            else
                echo -e "${YELLOW}Not running${NC}"
            fi
        else
            echo -e "${YELLOW}Service management not implemented for this platform${NC}"
        fi
        ;;
    
    stats)
        python3 "$SCRIPTS_DIR/analyze_speeds.py" 2>/dev/null || {
            echo -e "${BLUE}Quick stats:${NC}"
            LOG_FILE="$LOGS_DIR/speed_log_$(date +%Y-%m).csv"
            if [ -f "$LOG_FILE" ]; then
                TESTS=$(tail -n +2 "$LOG_FILE" | wc -l)
                AVG_DOWN=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$2; count++} END {print sum/count}')
                AVG_UP=$(tail -n +2 "$LOG_FILE" | awk -F',' '{sum+=$3; count++} END {print sum/count}')
                echo "  Total tests: $TESTS"
                echo "  Avg download: ${AVG_DOWN} Mbps"
                echo "  Avg upload: ${AVG_UP} Mbps"
            else
                echo "No data yet"
            fi
        }
        ;;
    
    uninstall)
        echo -e "${YELLOW}This will remove Internet Speed Monitor${NC}"
        echo "   Logs will be preserved in $LOGS_DIR"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            launchctl unload "$PLIST_FILE" 2>/dev/null || true
            rm -f "$PLIST_FILE"
            rm -f "$SCRIPTS_DIR/internet_monitor.sh"
            rm -f "$SCRIPTS_DIR/speed_dashboard.py"
            rm -f "$SCRIPTS_DIR/speed"
            echo -e "${GREEN}Uninstalled successfully${NC}"
            echo "   Logs preserved in $LOGS_DIR"
        else
            echo "Cancelled"
        fi
        ;;
    
    version)
        echo -e "${BLUE}Speed CLI v${VERSION}${NC}"
        ;;
    
    configure)
        CONFIG_FILE="$HOME/.speed-cli/config"
        if [ ! -f "$CONFIG_FILE" ]; then
            echo -e "${RED}Configuration file not found. Please run the installer first.${NC}"
            exit 1
        fi
        
        # Load current configuration
        source "$CONFIG_FILE"
        
        echo -e "${BLUE}Current Configuration:${NC}"
        echo "Expected Download: ${EXPECTED_DOWNLOAD} Mbps"
        echo "Expected Upload: ${EXPECTED_UPLOAD} Mbps"
        echo "Monitoring Interval: $((MONITOR_INTERVAL / 60)) minutes"
        echo ""
        
        echo -e "${YELLOW}Would you like to update these settings? (y/N)${NC}"
        read -p "> " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${YELLOW}Enter new values (press Enter to keep current):${NC}"
            
            # Update expected download speed
            read -p "Expected download speed (current: ${EXPECTED_DOWNLOAD} Mbps): " NEW_DOWNLOAD
            if [ -n "$NEW_DOWNLOAD" ]; then
                if [[ "$NEW_DOWNLOAD" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$NEW_DOWNLOAD > 0" | bc -l) )); then
                    EXPECTED_DOWNLOAD="$NEW_DOWNLOAD"
                else
                    echo -e "${RED}Invalid input, keeping current value${NC}"
                fi
            fi
            
            # Update expected upload speed
            read -p "Expected upload speed (current: ${EXPECTED_UPLOAD} Mbps): " NEW_UPLOAD
            if [ -n "$NEW_UPLOAD" ]; then
                if [[ "$NEW_UPLOAD" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$NEW_UPLOAD > 0" | bc -l) )); then
                    EXPECTED_UPLOAD="$NEW_UPLOAD"
                else
                    echo -e "${RED}Invalid input, keeping current value${NC}"
                fi
            fi
            
            # Update monitoring interval
            echo ""
            echo "Monitoring frequency options:"
            echo "1) Every 15 minutes (frequent monitoring)"
            echo "2) Every 30 minutes (moderate monitoring)"
            echo "3) Every hour (standard monitoring)"
            echo "4) Every 2 hours (light monitoring)"
            echo "5) Custom interval"
            echo "6) Keep current ($((MONITOR_INTERVAL / 60)) minutes)"
            
            read -p "Choose option (1-6): " FREQ_CHOICE
            case $FREQ_CHOICE in
                1) MONITOR_INTERVAL=900 ;;  # 15 minutes
                2) MONITOR_INTERVAL=1800 ;; # 30 minutes
                3) MONITOR_INTERVAL=3600 ;; # 1 hour
                4) MONITOR_INTERVAL=7200 ;; # 2 hours
                5) 
                    while true; do
                        read -p "Enter interval in minutes (minimum 5): " CUSTOM_MINUTES
                        if [[ "$CUSTOM_MINUTES" =~ ^[0-9]+$ ]] && [ "$CUSTOM_MINUTES" -ge 5 ]; then
                            MONITOR_INTERVAL=$((CUSTOM_MINUTES * 60))
                            break
                        else
                            echo -e "${RED}Please enter a valid number (minimum 5 minutes)${NC}"
                        fi
                    done
                    ;;
                6) ;; # Keep current
                *)
                    echo -e "${RED}Invalid choice, keeping current interval${NC}"
                    ;;
            esac
            
            # Save updated configuration
            cat > "$CONFIG_FILE" << EOF
# Speed CLI Configuration
EXPECTED_DOWNLOAD=$EXPECTED_DOWNLOAD
EXPECTED_UPLOAD=$EXPECTED_UPLOAD
MONITOR_INTERVAL=$MONITOR_INTERVAL
EOF
            
            echo ""
            echo -e "${GREEN}Configuration updated!${NC}"
            echo -e "${BLUE}New settings:${NC}"
            echo "Expected speeds: ${EXPECTED_DOWNLOAD} Mbps down, ${EXPECTED_UPLOAD} Mbps up"
            echo "Monitoring interval: $((MONITOR_INTERVAL / 60)) minutes"
            echo ""
            echo -e "${YELLOW}Note: You may need to restart the monitoring service for changes to take effect.${NC}"
            echo "Run: speed stop && speed start"
        else
            echo "Configuration unchanged"
        fi
        ;;
    
    update)
        echo -e "${BLUE}Updating Internet Speed Monitor...${NC}"
        REPO_URL="https://raw.githubusercontent.com/DavidNgugi/speed-cli/main"
        curl -fsSL "$REPO_URL/src/internet_monitor.sh" -o "$SCRIPTS_DIR/internet_monitor.sh"
        curl -fsSL "$REPO_URL/src/speed_dashboard.py" -o "$SCRIPTS_DIR/speed_dashboard.py"
        curl -fsSL "$REPO_URL/src/speed_cli.sh" -o "$SCRIPTS_DIR/speed"
        chmod +x "$SCRIPTS_DIR/internet_monitor.sh"
        chmod +x "$SCRIPTS_DIR/speed_dashboard.py"
        chmod +x "$SCRIPTS_DIR/speed"
        echo -e "${GREEN}Updated to latest version${NC}"
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        launchctl load "$PLIST_FILE"
        ;;
    
    help|--help|-h)
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}  Speed CLI${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Usage: speed [command]"
        echo ""
        echo "Commands:"
        echo "  dashboard   Start web dashboard (http://localhost:${PORT})"
        echo "  test        Run speed test now"
        echo "  logs        View recent test logs"
        echo "  alerts      View performance alerts"
        echo "  stats       Show quick statistics"
        echo "  status      Check if monitoring is running"
        echo "  start       Start background monitoring"
        echo "  stop        Stop background monitoring"
        echo "  version     Show current version"
        echo "  configure   Configure expected speeds and monitoring frequency"
        echo "  update      Update to latest version"
        echo "  uninstall   Remove Internet Speed Monitor"
        echo "  help        Show this help message"
        echo ""
        echo "Examples:"
        echo "  speed dashboard    # Open web interface"
        echo "  speed test         # Run immediate test"
        echo "  speed logs         # View last 20 tests"
        echo ""
        echo "Files:"
        echo "  Scripts: $SCRIPTS_DIR"
        echo "  Logs:    $LOGS_DIR"
        echo ""
        ;;
    
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo ""
        echo "Usage: speed [command]"
        echo "Run 'speed help' for available commands"
        echo ""
        echo "Quick commands:"
        echo "  speed dashboard  - Open web interface"
        echo "  speed test       - Run test now"
        echo "  speed status     - Check if running"
        ;;
esac