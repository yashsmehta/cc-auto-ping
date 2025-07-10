# CC AutoRenew 🚀

> Never miss a Claude Code renewal window again! Automatically maintains your 5-hour usage blocks with intelligent sleep-aware scheduling.

## 🎯 Problem

Claude Code operates on a 5-hour subscription model that renews from your first message. If you:
- Start coding at 5pm (block runs 5pm-10pm)
- Don't use Claude again until 11:01pm
- Your next block runs 11pm-4am (missing an hour!)

This tool ensures you automatically start new sessions at optimal times using sleep-aware scheduling, maximizing your available Claude time while respecting your sleep schedule and system power management.

## ✨ Features

- 🔄 **Sleep-Aware Scheduling** - Automatically wakes your Mac to renew Claude sessions
- 📊 **Smart Monitoring** - Integrates with [ccusage](https://github.com/ryoppippi/ccusage) for accurate timing
- 🎯 **Japan Timezone Optimized** - Schedules renewals for Monday-Saturday at 7:00 AM and 12:01 PM JST
- 📝 **Detailed Logging** - Track all renewal activities with timestamps
- 🛡️ **Power Management** - Integrates with macOS pmset for wake scheduling
- 🖥️ **launchd Integration** - Native macOS system service for reliability
- 🌙 **Sleep-Friendly** - Respects your sleep schedule and system power state

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/cc-auto-ping.git
cd cc-auto-ping

# Make scripts executable
chmod +x scripts/*.sh setup/*.sh utils/*.sh tests/*.sh

# Run quick test
./tests/test-sleepaware.sh

# Install sleep-aware scheduling
./scripts/claude-sleep-aware-manager.sh install
```

That's it! The launchd service will now schedule automatic Claude renewals at 7:00 AM and 12:01 PM JST (Monday-Saturday), waking your Mac when necessary.

## 📋 Prerequisites

- [Claude CLI](https://claude.ai/claude-code) installed and authenticated
- macOS (for sleep-aware scheduling and pmset integration)
- Bash 4.0+ (pre-installed on macOS)
- (Optional) [ccusage](https://github.com/ryoppippi/ccusage) for precise timing

## 🔧 Installation

### 1. Install Claude CLI

First, ensure you have Claude Code installed:
```bash
# Follow the official installation guide
# https://claude.ai/claude-code
```

### 2. Install ccusage (Optional but Recommended)

For accurate renewal timing:
```bash
# Option 1: Global install
npm install -g ccusage

# Option 2: Use without installing
npx ccusage@latest
bunx ccusage
```

### 3. Setup CC AutoRenew

```bash
# Clone this repository
git clone https://github.com/yourusername/cc-auto-ping.git
cd cc-auto-ping

# Make all scripts executable
chmod +x scripts/*.sh setup/*.sh utils/*.sh tests/*.sh

# Test your setup
./tests/test-sleepaware.sh

# Install sleep-aware scheduling
./scripts/claude-sleep-aware-manager.sh install
```

## 📖 Usage

### Managing Sleep-Aware Scheduling

```bash
# Install the sleep-aware launchd service
./scripts/claude-sleep-aware-manager.sh install

# Check service status
./scripts/claude-sleep-aware-manager.sh status

# View logs
./scripts/claude-sleep-aware-manager.sh logs

# Follow logs in real-time
./scripts/claude-sleep-aware-manager.sh logs -f

# Uninstall the service
./scripts/claude-sleep-aware-manager.sh uninstall

# Force renewal (for testing)
./scripts/claude-sleep-aware-manager.sh test
```

### How It Works

1. **Schedules** renewal sessions at optimal times (7:00 AM and 12:01 PM JST, Monday-Saturday)
2. **Wakes** your Mac from sleep using pmset wake scheduling when needed
3. **Executes** a minimal Claude session ("hi" command) to activate new 5-hour blocks
4. **Monitors** your Claude usage using ccusage for timing verification
5. **Logs** all activities with timestamps for transparency
6. **Manages** power efficiently by scheduling wake events only when necessary

### Scheduling Details

**Sleep-Aware Schedule (Japan Timezone):**
- **Monday-Saturday**: 7:00 AM and 12:01 PM JST
- **Weekly total**: 12 renewals per week (6 days × 2 times)
- **Sunday**: Rest day (no renewals scheduled)
- **Auto-wake**: System wakes from sleep 2 minutes before scheduled time
- **Power management**: Integrates with macOS pmset for efficient wake scheduling

**Schedule Benefits:**
- **Morning renewal (7:00 AM)**: Ensures fresh 5-hour block for morning coding
- **Afternoon renewal (12:01 PM)**: Provides second 5-hour block for afternoon/evening work
- **Sleep-friendly**: No overnight renewals to disturb rest
- **Timezone-aware**: Optimized for Japan Standard Time (JST)


## 📁 Project Structure

```
cc-auto-ping/
├── CLAUDE.md                           # Development guidelines
├── LICENSE                             # MIT License
├── README.md                           # Main project documentation
├── scripts/                            # Core scripts
│   ├── claude-sleep-aware-manager.sh   # Main management interface
│   ├── claude-auto-renew-sleepaware.sh # Enhanced renewal script
│   ├── pmset-wake-helper.sh            # Wake scheduling integration
│   └── claude-timezone-config.sh       # Japan timezone utilities
├── setup/                              # Installation scripts
│   ├── install-launchd-sleepaware.sh   # launchd service installer
│   └── setup-log-rotation.sh           # Log rotation configuration
├── config/                             # Configuration files
│   └── com.claude.autorenew.sleepaware.plist # launchd configuration
├── utils/                              # Utility scripts
│   └── validate-schedule.sh            # Schedule validation
├── tests/                              # Test scripts
│   ├── test-sleepaware.sh              # Sleep-aware system tests
│   └── test-wake-integration.sh        # Wake integration tests
├── docs/                               # Documentation
│   └── archived/                       # Historical documentation
└── logs/                               # Log files
    ├── claude-autorenew-sleepaware.log     # Main activity log
    └── claude-autorenew-sleepaware-error.log # Error log
```

## 🔍 Logs and Debugging

Logs are stored in your home directory:
- `~/.claude-auto-renew-sleep-aware.log` - Sleep-aware renewal activity
- `~/.claude-last-activity` - Timestamp of last renewal
- `~/.claude-sleep-aware-status` - Current service status and wake scheduling

View recent activity:
```bash
# Last 50 log entries
tail -50 ~/.claude-auto-renew-sleep-aware.log

# Follow logs in real-time
tail -f ~/.claude-auto-renew-sleep-aware.log

# Check current service status
./scripts/claude-sleep-aware-manager.sh status

# View pmset wake schedule
pmset -g sched
```

## ⚙️ Configuration

**Sleep-Aware Schedule (Current):**
- Uses `scripts/claude-sleep-aware-manager.sh` to configure launchd service
- Runs Monday-Saturday at 7:00 AM and 12:01 PM JST
- Automatically wakes Mac from sleep when needed
- Integrates with macOS power management

**Timezone Configuration:**
The system is optimized for Japan Standard Time (JST):
- **Morning renewal**: 7:00 AM JST (great for starting the day)
- **Afternoon renewal**: 12:01 PM JST (perfect for afternoon work)
- **Wake buffer**: System wakes 2 minutes before renewal time
- **Power efficiency**: Uses pmset for intelligent wake scheduling

**launchd Schedule Format:**
- `0 7 * * 1-6` = 7:00 AM Monday through Saturday
- `1 12 * * 1-6` = 12:01 PM Monday through Saturday
- Days: 1=Monday, 2=Tuesday, 3=Wednesday, 4=Thursday, 5=Friday, 6=Saturday
- **Note**: Sunday (0) is excluded for rest day

## 🐛 Troubleshooting

### Service won't install or start
```bash
# Check installation status
./claude-sleep-aware-manager.sh status

# Check logs for errors
tail -20 ~/.claude-auto-renew-sleep-aware.log

# Verify launchd service is loaded
launchctl list | grep com.claude.autorenew
```

### Mac not waking for renewals
```bash
# Check pmset wake schedule
pmset -g sched

# Verify wake permissions
pmset -g assertions

# Check power management settings
pmset -g
```

### ccusage not working
```bash
# Test ccusage directly
ccusage blocks

# The system will fall back to time-based checking automatically
```

### Claude command fails
```bash
# Verify Claude CLI is installed
which claude

# Test Claude directly
echo "hi" | claude

# Check if authentication is valid
claude --version
```

### Timezone issues
```bash
# Check system timezone
date
timedatectl show

# Verify Japan timezone setting
TZ=Asia/Tokyo date
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [ccusage](https://github.com/ryoppippi/ccusage) by @ryoppippi for accurate usage tracking
- Claude Code team for the amazing coding assistant
- Community feedback and contributions

## 💡 Tips

- Run `claude-sleep-aware-manager.sh status` regularly to ensure the service is active
- Check logs after updates to verify renewals are working
- The sleep-aware system is ultra-lightweight - only runs when needed
- Uses macOS native launchd for maximum reliability
- Respects your sleep schedule - no overnight disturbances
- Perfect for Japan timezone users with morning and afternoon coding sessions
- Sunday is a rest day - no renewals scheduled to give you a break

---

Made with ❤️ for the Claude Code community