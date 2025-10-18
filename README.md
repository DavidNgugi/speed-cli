# Speed CLI

> Catch your ISP throttling you! Automatic hourly monitoring with a beautiful web dashboard.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![macOS](https://img.shields.io/badge/macOS-Big_Sur+-blue.svg)](https://www.apple.com/macos/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![Dashboard Preview](https://via.placeholder.com/800x400?text=Dashboard+Screenshot+Here)

## Quick Install
```bash
curl -fsSL https://raw.githubusercontent.com/DavidNgugi/speed-cli/install.sh | bash
```

That's it! The monitor is now running in the background.

## Features

- **Automatic hourly monitoring** - Set it and forget it
- **Beautiful web dashboard** - Real-time charts and stats
- **Smart alerts** - Get notified when speeds drop
- **Historical data** - Track patterns over weeks
- **CSV exports** - Perfect for ISP support tickets
- **Privacy first** - All data stays on your Mac
- **No browser required** - Uses native macOS tools

## Quick Start

After installation:
```bash
# Open web dashboard
speed dashboard

# Run a test immediately
speed test

# View your logs
speed logs

# Check monitoring status
speed status
```

Then visit **http://localhost:6432** in your browser!

## Screenshots

[Add screenshots here of the dashboard]

## What It Does

1. Tests your internet speed every hour using macOS's native `networkquality` command
2. Logs download/upload speeds and latency to CSV files
3. Provides a web dashboard to visualize trends
4. Alerts you when speeds drop below your plan's thresholds
5. Helps you build evidence for ISP support tickets

## Requirements

- macOS Big Sur (11.0) or later
- Python 3 (pre-installed on macOS)
- 5 minutes of your time

## Usage

### Web Dashboard

Visit `http://localhost:6432` to see:
- Download/upload speed graphs
- Latency trends over time  
- Average, min, max statistics
- One-click manual testing
- Performance degradation tracking

### CLI Commands
```bash
speed dashboard   # Start web dashboard (http://localhost:6432)
speed test        # Run speed test now
speed logs        # View recent logs
speed alerts      # View performance alerts
speed status      # Check if monitoring is running
speed start       # Start background monitoring
speed stop        # Stop background monitoring
speed uninstall   # Remove everything (keeps logs)
```

## Configuration

Edit thresholds based on your ISP plan:
```bash
nano ~/scripts/internet_monitor.sh
```

Adjust these values:
```bash
MIN_DOWNLOAD=25   # Minimum download speed (Mbps)
MIN_UPLOAD=5      # Minimum upload speed (Mbps)
MAX_LATENCY=100   # Maximum latency (ms)
```

## File Locations

~/scripts/
├── internet_monitor.sh    # Monitoring script
├── speed_dashboard.py     # Web dashboard server
└── speed                  # CLI tool
~/internet_logs/
├── speed_log_2025-10.csv  # Monthly CSV logs
├── alerts.log             # Performance alerts
├── monitor_stdout.log     # Service output
└── monitor_stderr.log     # Service errors
~/Library/LaunchAgents/
└── com.user.internet.monitor.plist  # Background service config

## Use Cases

- **Catch peak-hour throttling** (evenings, weekends)
- **Document service issues** with timestamped data
- **Verify you're getting what you pay for**
- **Identify patterns** before calling support
- **Build evidence** for switching providers

## Troubleshooting

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

**Quick checks:**
```bash
# Is the service running?
launchctl list | grep internet.monitor

# Check for errors
cat ~/internet_logs/monitor_stderr.log

# Test manually
~/scripts/internet_monitor.sh
```

## Contributing

Contributions welcome! Please feel free to submit a Pull Request.

1. Fork the repo
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Show Your Support

If this tool helped you catch your ISP or save money, give it a star!

## Acknowledgments

- Built with macOS's native `networkquality` tool
- Inspired by frustrated internet users everywhere
- Made with ❤️ for people tired of paying for slow internet

---

**Made by developers, for developers (and anyone tired of slow internet)**

[Report Bug](https://github.com/DavidNgugi/speed-cli/issues) · [Request Feature](https://github.com/DavidNgugi/speed-cli/issues)