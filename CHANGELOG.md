# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.5] - 2025-01-27

### Added
- **Linux Support**: Added comprehensive Linux speed testing with `speedtest-cli` integration
- **Windows Support**: Added comprehensive Windows speed testing with PowerShell integration
- **Dependency Management**: Automatic installation of required dependencies on Linux and Windows
- **Fallback Methods**: Reliable fallback using Hetzner test file (100MB) when speedtest-cli unavailable
- **Cross-Platform Testing**: Improved platform detection and error handling

### Fixed
- **Linux Speed Testing**: Now uses `speedtest-cli` for accurate upload/download/latency measurements
- **Windows Speed Testing**: Fixed PowerShell integration with proper error handling
- **Syntax Errors**: Fixed bash syntax errors in PowerShell script strings
- **Dependency Installation**: Added support for multiple Linux package managers (apt, yum, dnf, pacman)
- **Windows Task Scheduler**: Automated setup with PowerShell script generation

### Improved
- **User Experience**: Clear installation guidance and error messages
- **Reliability**: Better fallback methods when primary tools unavailable
- **Documentation**: Updated installation instructions for all platforms

## [1.0.4] - 2025-10-20

### Fixed
- Dashboard `/api/trigger` now runs an actual one-off speed test using the existing `internet_monitor.sh --test` and returns the latest logged result as JSON instead of only nudging the background service. This makes the “Run Test Now” button immediately useful.

## [1.0.3] - 2025-10-20

### Fixed
- Fixed infinite loop issue in install script when running via `curl | bash`
- Added non-interactive mode detection to prevent hanging during automated installation
- Improved input validation with proper error handling and user feedback
- Enhanced installation experience with automatic default settings for non-interactive mode

### Added
- Non-interactive installation mode with sensible defaults (100 Mbps down, 20 Mbps up, 30 min intervals)
- User guidance messages about `speed configure` command for post-installation customization
- Enhanced installation messages to inform users about reconfiguration options
- Improved error handling for invalid input during interactive installation

### Changed
- Installation script now automatically detects non-interactive environments
- Default settings are applied automatically when running via `curl | bash`
- Enhanced user experience with clear guidance on available commands
- Improved installation flow for both interactive and non-interactive modes

## [1.0.2] - 2025-10-20

### Fixed
- Fixed installation script infinite loop issue
- Removed dependency on `bc` command for input validation
- Improved input validation to work across all platforms
- Installation script now completes successfully without hanging

## [1.0.1] - 2025-10-20

### Added
- Background dashboard service with automatic startup
- New dashboard management commands (start, stop, status)
- Enhanced installation process with both monitoring and dashboard services
- Improved launch agent configuration with absolute paths
- Updated documentation with dashboard management commands

### Fixed
- Fixed launch agent plist files to use absolute paths instead of $HOME variables
- Resolved dashboard "Address already in use" errors
- Improved service reliability and startup process

### Changed
- Dashboard now runs automatically in background after installation
- Enhanced CLI help text with new dashboard commands
- Updated Homebrew formula with new dashboard features
- Improved user experience with both services running by default

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
