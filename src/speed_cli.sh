#!/bin/bash
#
# Speed CLI - CLI Tool
# Simple command-line interface for speed monitoring
# Author: David Ngugi
#

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