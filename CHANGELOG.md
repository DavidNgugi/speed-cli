# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-10-20

### Added
- Initial release of Speed CLI
- Automatic hourly internet speed monitoring
- Beautiful web dashboard with real-time charts
- Cross-platform support (macOS, Linux, Windows)
- CLI commands for testing, logging, and monitoring
- Background service management
- CSV export functionality
- Performance alerts and degradation tracking
- Version management system
- Update and uninstall capabilities

### Features
- **Automatic monitoring**: Set it and forget it with hourly tests
- **Web dashboard**: Real-time visualization at http://localhost:6432
- **Smart alerts**: Get notified when speeds drop below thresholds
- **Historical data**: Track patterns over weeks and months
- **CSV exports**: Perfect for ISP support tickets
- **Privacy first**: All data stays on your device
- **No external dependencies**: Uses native platform tools
- **Cross-platform**: Works on macOS, Linux, and Windows

### Platform Support
- **macOS**: Uses native `networkquality` command
- **Linux**: Uses `wget` with speed calculation
- **Windows**: Uses PowerShell with speed calculation

### CLI Commands
- `speed dashboard` - Start web dashboard
- `speed test` - Run speed test now
- `speed logs` - View recent test logs
- `speed alerts` - View performance alerts
- `speed stats` - Show quick statistics
- `speed status` - Check if monitoring is running
- `speed start` - Start background monitoring
- `speed stop` - Stop background monitoring
- `speed version` - Show current version
- `speed update` - Update to latest version
- `speed uninstall` - Remove Speed CLI (keeps logs)
- `speed help` - Show help message
