# Speed CLI Homebrew Tap

This is the Homebrew tap for [Speed CLI](https://github.com/DavidNgugi/speed-cli) - a tool to catch your ISP throttling you with automatic hourly monitoring and a beautiful web dashboard.

## Installation

Add this tap to your Homebrew installation:

```bash
brew tap DavidNgugi/speed-cli
```

Then install Speed CLI:

```bash
brew install speed-cli
```

## Usage

After installation, you can use Speed CLI:

```bash
# Configure your expected speeds and monitoring frequency
speed configure

# Start background monitoring
speed start

# Open the web dashboard
speed dashboard

# Run a manual speed test
speed test

# View logs
speed logs

# Check status
speed status
```

The web dashboard will be available at: http://localhost:6432

## Features

- **Automatic hourly monitoring** - Set it and forget it
- **Beautiful web dashboard** - Real-time charts and stats
- **Smart alerts** - Get notified when speeds drop
- **Historical data** - Track patterns over weeks
- **CSV exports** - Perfect for ISP support tickets
- **Privacy first** - All data stays on your device
- **Cross-platform** - Works on macOS, Linux, and Windows

## Documentation

For more information, visit the [main project repository](https://github.com/DavidNgugi/speed-cli).

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/DavidNgugi/speed-cli/blob/main/LICENSE) file for details.
