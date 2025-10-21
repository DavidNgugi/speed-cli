#!/bin/bash
set -e

VERSION="1.0.4"
REPO_URL="https://raw.githubusercontent.com/DavidNgugi/speed-cli/main"
INSTALL_DIR="$HOME/scripts"
LOG_DIR="$HOME/internet_logs"
PORT=6432

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Speed CLI v${VERSION}...${NC}"

# Check if running in non-interactive mode
if [[ ! -t 0 ]] || [[ -n "$CI" ]] || [[ -n "$NONINTERACTIVE" ]] || [[ -z "$PS1" ]] || [[ "$TERM" == "dumb" ]]; then
    echo -e "${YELLOW}Running in non-interactive mode. Using default settings.${NC}"
    EXPECTED_DOWNLOAD=100
    EXPECTED_UPLOAD=20
    MONITOR_INTERVAL=1800  # 30 minutes
    echo -e "${BLUE}Using defaults: ${EXPECTED_DOWNLOAD} Mbps down, ${EXPECTED_UPLOAD} Mbps up, every 30 minutes${NC}"
    echo -e "${YELLOW}💡 You can reconfigure later with: speed configure${NC}"
else
    # Configuration prompts
    echo -e "${YELLOW}Let's configure your speed monitoring settings:${NC}"
    echo ""

    # Ask for expected speed from provider with validation
    echo -e "${BLUE}Download Speed:${NC}"
    while true; do
        read -p "What's your expected download speed from your ISP? (Mbps) [default: 100]: " EXPECTED_DOWNLOAD
        EXPECTED_DOWNLOAD=${EXPECTED_DOWNLOAD:-100}
        
        # Check if it's a valid positive number
        if [[ "$EXPECTED_DOWNLOAD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            # Use bc if available, otherwise use awk for comparison
            if command -v bc &> /dev/null; then
                if (( $(echo "$EXPECTED_DOWNLOAD > 0" | bc -l) )); then
                    break
                fi
            else
                # Fallback: check if it's greater than 0 using awk
                if (( $(echo "$EXPECTED_DOWNLOAD" | awk '{print ($1 > 0)}') )); then
                    break
                fi
            fi
        else
            echo -e "${RED}Please enter a valid positive number${NC}"
        fi
    done

    echo -e "${BLUE}Upload Speed:${NC}"
    while true; do
        read -p "What's your expected upload speed from your ISP? (Mbps) [default: 20]: " EXPECTED_UPLOAD
        EXPECTED_UPLOAD=${EXPECTED_UPLOAD:-20}
        
        # Check if it's a valid positive number
        if [[ "$EXPECTED_UPLOAD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            # Use bc if available, otherwise use awk for comparison
            if command -v bc &> /dev/null; then
                if (( $(echo "$EXPECTED_UPLOAD > 0" | bc -l) )); then
                    break
                fi
            else
                # Fallback: check if it's greater than 0 using awk
                if (( $(echo "$EXPECTED_UPLOAD" | awk '{print ($1 > 0)}') )); then
                    break
                fi
            fi
        else
            echo -e "${RED}Please enter a valid positive number${NC}"
        fi
    done

    # Ask for monitoring frequency
    echo ""
    echo -e "${YELLOW}How often would you like to run speed tests?${NC}"
    echo "1) Every 15 minutes (frequent monitoring)"
    echo "2) Every 30 minutes (moderate monitoring)"
    echo "3) Every hour (standard monitoring)"
    echo "4) Every 2 hours (light monitoring)"
    echo "5) Custom interval (in minutes)"

    while true; do
        read -p "Choose option (1-5): " FREQ_CHOICE
        case $FREQ_CHOICE in
            1) MONITOR_INTERVAL=900; break ;;  # 15 minutes
            2) MONITOR_INTERVAL=1800; break ;; # 30 minutes
            3) MONITOR_INTERVAL=3600; break ;; # 1 hour
            4) MONITOR_INTERVAL=7200; break ;; # 2 hours
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
                break
                ;;
            *)
                echo -e "${RED}Please choose 1-5${NC}"
                ;;
        esac
    done

fi  # End of interactive mode check

# Create configuration file
CONFIG_DIR="$HOME/.speed-cli"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config" << EOF
# Speed CLI Configuration
EXPECTED_DOWNLOAD=$EXPECTED_DOWNLOAD
EXPECTED_UPLOAD=$EXPECTED_UPLOAD
MONITOR_INTERVAL=$MONITOR_INTERVAL
EOF

echo ""
echo -e "${GREEN}Configuration saved!${NC}"
echo -e "${BLUE}Expected speeds: ${EXPECTED_DOWNLOAD} Mbps down, ${EXPECTED_UPLOAD} Mbps up${NC}"
echo -e "${BLUE}Monitoring interval: $((MONITOR_INTERVAL / 60)) minutes${NC}"
echo ""

# Detect platform
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

PLATFORM=$(detect_platform)

# Check platform-specific requirements
case "$PLATFORM" in
    "macos")
        if ! command -v networkquality &> /dev/null; then
            echo -e "${RED}Error: Requires macOS Big Sur (11.0) or later${NC}"
            exit 1
        fi
        ;;
    "linux")
        echo -e "${BLUE}Checking Linux dependencies...${NC}"
        
        # Check and install basic dependencies
        MISSING_DEPS=()
        
        if ! command -v wget &> /dev/null; then
            MISSING_DEPS+=("wget")
        fi
        
        if ! command -v bc &> /dev/null; then
            MISSING_DEPS+=("bc")
        fi
        
        if ! command -v python3 &> /dev/null; then
            MISSING_DEPS+=("python3")
        fi
        
        # Install missing basic dependencies
        if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
            echo -e "${YELLOW}Installing missing dependencies: ${MISSING_DEPS[*]}${NC}"
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y "${MISSING_DEPS[@]}"
            elif command -v yum &> /dev/null; then
                sudo yum install -y "${MISSING_DEPS[@]}"
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y "${MISSING_DEPS[@]}"
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm "${MISSING_DEPS[@]}"
            else
                echo -e "${RED}Error: Please install ${MISSING_DEPS[*]} manually${NC}"
                exit 1
            fi
        fi
        
        # Check for optional but recommended dependencies
        echo -e "${BLUE}Checking for optional dependencies...${NC}"
        
        if ! command -v speedtest &> /dev/null; then
            echo -e "${YELLOW}speedtest-cli not found. Installing for better speed testing...${NC}"
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y speedtest-cli
            elif command -v pip3 &> /dev/null; then
                pip3 install speedtest-cli
            else
                echo -e "${YELLOW}Note: Install speedtest-cli manually for better speed testing:${NC}"
                echo "  Debian/Ubuntu: sudo apt install speedtest-cli"
                echo "  Or via pip: pip install speedtest-cli"
            fi
        else
            echo -e "${GREEN}✓ speedtest-cli found${NC}"
        fi
        
        if ! command -v jq &> /dev/null; then
            echo -e "${YELLOW}jq not found. Installing for better JSON parsing...${NC}"
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y jq
            elif command -v yum &> /dev/null; then
                sudo yum install -y jq
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y jq
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm jq
            else
                echo -e "${YELLOW}Note: Install jq manually for better JSON parsing:${NC}"
                echo "  Debian/Ubuntu: sudo apt install jq"
                echo "  RHEL/CentOS: sudo yum install jq"
                echo "  Arch: sudo pacman -S jq"
            fi
        else
            echo -e "${GREEN}✓ jq found${NC}"
        fi
        
        echo -e "${GREEN}Linux dependencies check complete!${NC}"
        ;;
    "windows")
        echo -e "${BLUE}Checking Windows dependencies...${NC}"
        
        if ! command -v powershell &> /dev/null; then
            echo -e "${RED}Error: PowerShell not found. Please install PowerShell.${NC}"
            exit 1
        fi
        
        # Check for Python 3
        if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
            echo -e "${YELLOW}Python 3 not found. Please install Python 3:${NC}"
            echo "  Download from: https://www.python.org/downloads/"
            echo "  Make sure to check 'Add Python to PATH' during installation"
            echo ""
        else
            echo -e "${GREEN}✓ Python found${NC}"
        fi
        
        # Check for Git (needed for bash environment)
        if ! command -v git &> /dev/null; then
            echo -e "${YELLOW}Git not found. Please install Git for Windows:${NC}"
            echo "  Download from: https://git-scm.com/download/win"
            echo "  This provides the bash environment needed for the tool"
            echo ""
        else
            echo -e "${GREEN}✓ Git found${NC}"
        fi
        
        # Check for optional speedtest-cli
        echo -e "${BLUE}Checking for optional dependencies...${NC}"
        
        if ! command -v speedtest &> /dev/null; then
            echo -e "${YELLOW}speedtest-cli not found. Installing for better speed testing...${NC}"
            if command -v pip3 &> /dev/null; then
                pip3 install speedtest-cli
            elif command -v pip &> /dev/null; then
                pip install speedtest-cli
            else
                echo -e "${YELLOW}Note: Install speedtest-cli manually for better speed testing:${NC}"
                echo "  pip install speedtest-cli"
                echo "  Or download from: https://www.speedtest.net/apps/cli"
            fi
        else
            echo -e "${GREEN}✓ speedtest-cli found${NC}"
        fi
        
        echo -e "${GREEN}Windows dependencies check complete!${NC}"
        ;;
    *)
        echo -e "${RED}Error: Unsupported platform: $OSTYPE${NC}"
        echo "Supported platforms: macOS, Linux, Windows"
        exit 1
        ;;
esac

mkdir -p "$INSTALL_DIR" "$LOG_DIR"

echo -e "${BLUE}Downloading files...${NC}"
curl -fsSL "$REPO_URL/src/internet_monitor.sh" -o "$INSTALL_DIR/internet_monitor.sh"
curl -fsSL "$REPO_URL/src/speed_dashboard.py" -o "$INSTALL_DIR/speed_dashboard.py"
curl -fsSL "$REPO_URL/src/speed_cli.sh" -o "$INSTALL_DIR/speed"

chmod +x "$INSTALL_DIR/internet_monitor.sh"
chmod +x "$INSTALL_DIR/speed_dashboard.py"
chmod +x "$INSTALL_DIR/speed"

# Platform-specific service setup
case "$PLATFORM" in
    "macos")
        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENT_DIR"
        
        cat > "$LAUNCH_AGENT_DIR/com.user.internet.monitor.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.internet.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$INSTALL_DIR/internet_monitor.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>$MONITOR_INTERVAL</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/monitor_stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/monitor_stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
        
        # Create dashboard launch agent
        cat > "$LAUNCH_AGENT_DIR/com.user.speed.dashboard.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.speed.dashboard</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>$INSTALL_DIR/speed_dashboard.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/dashboard_stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/dashboard_stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
</dict>
</plist>
EOF
        
        launchctl unload "$LAUNCH_AGENT_DIR/com.user.internet.monitor.plist" 2>/dev/null || true
        launchctl load "$LAUNCH_AGENT_DIR/com.user.internet.monitor.plist"
        
        # Start dashboard service
        launchctl unload "$LAUNCH_AGENT_DIR/com.user.speed.dashboard.plist" 2>/dev/null || true
        launchctl load "$LAUNCH_AGENT_DIR/com.user.speed.dashboard.plist"
        ;;
    "linux")
        # Create systemd service for Linux
        SERVICE_FILE="/etc/systemd/system/speed-monitor.service"
        if [ -w "/etc/systemd/system" ]; then
            sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Speed Monitor
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/bin/bash $INSTALL_DIR/internet_monitor.sh
Restart=always
RestartSec=$MONITOR_INTERVAL

[Install]
WantedBy=multi-user.target
EOF
            sudo systemctl daemon-reload
            sudo systemctl enable speed-monitor.service
            sudo systemctl start speed-monitor.service
        else
            echo -e "${YELLOW}Note: Cannot create systemd service. You may need to run monitoring manually.${NC}"
        fi
        ;;
    "windows")
        echo -e "${BLUE}Setting up Windows background monitoring...${NC}"
        
        # Create PowerShell script for Windows Task Scheduler
        cat > "$INSTALL_DIR/setup_windows_service.ps1" << 'EOF'
# PowerShell script to set up Windows Task Scheduler for Speed CLI
param(
    [string]$InstallDir = "$env:USERPROFILE\scripts",
    [int]$IntervalMinutes = 30
)

Write-Host "Setting up Windows Task Scheduler for Speed CLI..." -ForegroundColor Blue

# Create the scheduled task
$action = New-ScheduledTaskAction -Execute "C:\Program Files\Git\bin\bash.exe" -Argument "-c '$InstallDir/internet_monitor.sh"
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365)
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken

try {
    Register-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -TaskName "Speed Monitor" -Description "Internet Speed Monitoring" -Force
    Write-Host "✓ Speed Monitor scheduled task created successfully!" -ForegroundColor Green
    Write-Host "Task will run every $IntervalMinutes minutes" -ForegroundColor Blue
} catch {
    Write-Host "Error creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "You may need to run PowerShell as Administrator" -ForegroundColor Yellow
}
EOF
        
        # Try to set up the scheduled task automatically
        echo -e "${BLUE}Attempting to set up Windows Task Scheduler...${NC}"
        if command -v powershell &> /dev/null; then
            powershell -ExecutionPolicy Bypass -File "$INSTALL_DIR/setup_windows_service.ps1" -InstallDir "$INSTALL_DIR" -IntervalMinutes $((MONITOR_INTERVAL / 60))
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Windows background monitoring set up successfully!${NC}"
            else
                echo -e "${YELLOW}Automatic setup failed. Manual setup required.${NC}"
                echo ""
                echo -e "${BLUE}Manual Setup Instructions:${NC}"
                echo "1. Open Task Scheduler (search in Start menu)"
                echo "2. Click 'Create Basic Task'"
                echo "3. Name: 'Speed Monitor'"
                echo "4. Trigger: 'Daily' → 'Recur every: 1 days'"
                echo "5. Action: 'Start a program'"
                echo "6. Program: C:\\Program Files\\Git\\bin\\bash.exe"
                echo "7. Arguments: -c '$INSTALL_DIR/internet_monitor.sh'"
                echo "8. Check 'Run whether user is logged on or not'"
                echo ""
                echo -e "${BLUE}Or run this PowerShell command as Administrator:${NC}"
                echo "powershell -ExecutionPolicy Bypass -File '$INSTALL_DIR/setup_windows_service.ps1'"
            fi
        else
            echo -e "${YELLOW}PowerShell not available for automatic setup.${NC}"
            echo "Please set up a scheduled task manually to run: $INSTALL_DIR/internet_monitor.sh"
        fi
        ;;
esac

"$INSTALL_DIR/internet_monitor.sh"

SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ] && ! grep -q "internet-speed-monitor" "$SHELL_RC"; then
    echo "" >> "$SHELL_RC"
    echo "# Internet Speed Monitor" >> "$SHELL_RC"
    echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_RC"
fi

echo ""
echo -e "${GREEN}Installation complete! Both monitoring and dashboard are now running.${NC}"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo "   speed dashboard        # Open web interface (interactive)"
echo "   speed dashboard start   # Start dashboard in background"
echo "   speed dashboard stop    # Stop dashboard service"
echo "   speed dashboard status  # Check dashboard status"
echo "   speed test             # Run test now"
echo "   speed logs             # View recent tests"
echo "   speed status           # Check monitoring status"
echo "   speed configure        # Reconfigure settings (speeds & frequency)"
echo ""
echo -e "${BLUE}Dashboard: http://localhost:${PORT}${NC}"
echo -e "${GREEN}Both monitoring and dashboard are running automatically!${NC}"
echo ""
echo -e "${YELLOW}💡 Tip: Run 'speed configure' to change your settings later${NC}"