#!/bin/bash
set -e

REPO_URL="https://raw.githubusercontent.com/DavidNgugi/speed-cli/main"
INSTALL_DIR="$HOME/scripts"
LOG_DIR="$HOME/internet_logs"
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
PORT=6432

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Installing Speed CLI...${NC}"

if ! command -v networkquality &> /dev/null; then
    echo -e "${RED}Error: Requires macOS Big Sur (11.0) or later${NC}"
    exit 1
fi

mkdir -p "$INSTALL_DIR" "$LOG_DIR" "$LAUNCH_AGENT_DIR"

echo -e "${BLUE}Downloading files...${NC}"
curl -fsSL "$REPO_URL/src/internet_monitor.sh" -o "$INSTALL_DIR/internet_monitor.sh"
curl -fsSL "$REPO_URL/src/speed_dashboard.py" -o "$INSTALL_DIR/speed_dashboard.py"
curl -fsSL "$REPO_URL/src/speed_cli.sh" -o "$INSTALL_DIR/speed"

chmod +x "$INSTALL_DIR/internet_monitor.sh"
chmod +x "$INSTALL_DIR/speed_dashboard.py"
chmod +x "$INSTALL_DIR/speed"

cat > "$LAUNCH_AGENT_DIR/com.user.internet.monitor.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.internet.monitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/scripts/internet_monitor.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/internet_logs/monitor_stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/internet_logs/monitor_stderr.log</string>
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
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo -e "${BLUE}Start using it:${NC}"
echo "   speed dashboard    # Open web interface"
echo "   speed test         # Run test now"
echo ""
echo -e "${BLUE}Dashboard: http://localhost:${PORT}${NC}"