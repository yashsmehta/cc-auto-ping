# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CC AutoRenew is a sleep-aware scheduling system that automatically maintains Claude Code availability through intelligent launchd-based scheduling. It runs Monday through Saturday at 7:00 AM and 12:01 PM Japan time (12 renewals per week) and works seamlessly even when the laptop is sleeping. The system integrates with macOS power management and includes comprehensive error handling for automated operation.

## Architecture

### Core Components

1. **scripts/claude-sleep-aware-manager.sh** - Main management interface for sleep-aware system
2. **scripts/claude-auto-renew-sleepaware.sh** - Enhanced renewal script with sleep management and power handling
3. **scripts/pmset-wake-helper.sh** - Wake scheduling integration for macOS power management
4. **config/com.claude.autorenew.sleepaware.plist** - launchd configuration for native macOS scheduling
5. **scripts/claude-timezone-config.sh** - Japan timezone utilities and validation

### Supporting Components
- **setup/install-launchd-sleepaware.sh** - Installation script for sleep-aware system
- **setup/setup-log-rotation.sh** - Log rotation configuration utility
- **utils/validate-schedule.sh** - Schedule validation utility
- **tests/test-sleepaware.sh** - Sleep-aware system testing
- **tests/test-wake-integration.sh** - Wake integration testing

### Key Features

- **Sleep-Aware Scheduling**: Uses launchd for proper sleep/wake handling instead of continuous monitoring
- **Japan Timezone Optimization**: All scheduling and logging in JST (Asia/Tokyo)
- **Power Management Integration**: pmset wake scheduling + caffeinate sleep prevention
- **Enhanced Error Handling**: Timeout handling for ccusage and interactive prompt bypass
- **Comprehensive Logging**: Japan timezone timestamps and detailed system information
- **Lock File Management**: Prevents overlapping executions with proper cleanup

## Common Development Tasks

### Managing the Sleep-Aware System
```bash
# Install the sleep-aware system
./scripts/claude-sleep-aware-manager.sh install

# Check system status
./scripts/claude-sleep-aware-manager.sh status

# View logs
./scripts/claude-sleep-aware-manager.sh logs

# Test renewal manually
./scripts/claude-sleep-aware-manager.sh test

# Uninstall system
./scripts/claude-sleep-aware-manager.sh uninstall

# Migrate from legacy daemon
./scripts/claude-sleep-aware-manager.sh migrate
```

### Testing and Development
```bash
# Test renewal script directly (with timeout and permission bypass)
./scripts/claude-auto-renew-sleepaware.sh --test

# Test renewal script directly (force renewal)
./scripts/claude-auto-renew-sleepaware.sh --force

# Check Japan timezone configuration
./scripts/claude-timezone-config.sh info

# Validate pmset wake scheduling
./scripts/pmset-wake-helper.sh verify

# Run sleep-aware system tests
./tests/test-sleepaware.sh

# Test wake integration
./tests/test-wake-integration.sh

# Validate schedule configuration
./utils/validate-schedule.sh
```

### Debugging
```bash
# Check main log file (Japan timezone)
tail -f ~/.claude-auto-renew.log

# Check launchd service status
launchctl list | grep com.claude.auto-renew

# Check pmset wake schedules
pmset -g sched

# Check last activity timestamp
cat ~/.claude-last-activity

# Test ccusage integration (with timeout handling)
./scripts/claude-auto-renew-sleepaware.sh --test
```

## Technical Implementation

### Sleep-Aware Scheduling
- **Schedule**: Monday-Saturday at 7:00 AM and 12:01 PM Japan time (12 renewals per week)
- **launchd Integration**: Uses `StartCalendarInterval` for native macOS scheduling
- **Timezone**: Asia/Tokyo (JST) enforced with TZ environment variable
- **Sleep Handling**: launchd automatically runs missed jobs after system wake
- **Wake Scheduling**: pmset integration wakes system before renewal times

### Power Management
- **Wake Integration**: `pmset repeat wakeorpoweron` for scheduled system wake
- **Sleep Prevention**: `caffeinate -d -i -m -u -t 300` during renewal process
- **Lock File Management**: `/tmp/claude-auto-renew-sleepaware.lock` prevents overlapping executions
- **Process Cleanup**: Automatic caffeinate and lock file cleanup on exit

### Enhanced Session Management
- **Renewal Trigger**: "hi" command sent to Claude CLI with automation flags
- **Permission Bypass**: `--dangerously-skip-permissions` flag for automated operation
- **Non-Interactive Mode**: `--print` flag for scripted execution
- **Timeout Handling**: 30-second timeout with proper process cleanup
- **Retry Logic**: Up to 3 attempts with 10-second intervals
- **Path Management**: Explicit Claude CLI path export for launchd execution

### Error Handling Improvements
- **ccusage Timeout**: 10-second timeout for hanging ccusage commands
- **Interactive Prompt Bypass**: Automatic handling of security prompts
- **Network Resilience**: Graceful fallback when ccusage is unavailable
- **System State Detection**: Wake-from-sleep detection and missed renewal recovery

## File Structure

The repository follows a clean, organized structure with files categorized by function:

```
cc-auto-ping/
├── CLAUDE.md                           # Development guidelines
├── LICENSE                             # MIT License
├── README.md                           # Main project documentation
├── scripts/                            # Core scripts (4 files)
│   ├── claude-sleep-aware-manager.sh   # Main management interface
│   ├── claude-auto-renew-sleepaware.sh # Enhanced renewal script
│   ├── pmset-wake-helper.sh            # Wake scheduling integration
│   └── claude-timezone-config.sh       # Japan timezone utilities
├── setup/                              # Installation scripts (2 files)
│   ├── install-launchd-sleepaware.sh   # launchd service installer
│   └── setup-log-rotation.sh           # Log rotation configuration
├── config/                             # Configuration files (1 file)
│   └── com.claude.autorenew.sleepaware.plist # launchd configuration
├── utils/                              # Utility scripts (1 file)
│   └── validate-schedule.sh            # Schedule validation
├── tests/                              # Test scripts (2 files)
│   ├── test-sleepaware.sh              # Sleep-aware system tests
│   └── test-wake-integration.sh        # Wake integration tests
├── docs/                               # Documentation
│   └── archived/                       # Historical documentation (3 files)
│       ├── SCHEDULE_UPDATE_SUMMARY.md  # Schedule update history
│       ├── WAKE_SCHEDULING_GUIDE.md    # Wake scheduling guide
│       └── schedule-config.md          # Schedule configuration docs
└── logs/                               # Log files
    ├── claude-autorenew-sleepaware.log     # Main activity log
    └── claude-autorenew-sleepaware-error.log # Error log
```

### Directory Organization

- **scripts/**: Core system functionality (4 active scripts)
- **setup/**: Installation and configuration utilities
- **config/**: System configuration files
- **utils/**: Helper and validation scripts
- **tests/**: Testing and verification scripts
- **docs/archived/**: Historical documentation (removed from main directory)
- **logs/**: Runtime logs and activity tracking

This structure provides:
- Clear separation of concerns
- Easy maintenance and updates
- Intuitive file organization
- Reduced clutter in root directory

## Dependencies

- **Required**: macOS with launchd, Bash 4.0+, Claude CLI installed and authenticated
- **Optional**: ccusage (npm package) for accurate timing
- **Fallback**: Time-based checking when ccusage unavailable or times out
- **Power Management**: pmset (built into macOS), caffeinate (built into macOS)

## Log Files

- `~/.claude-auto-renew.log` - Main activity log with Japan timezone
- `~/.claude-last-activity` - Unix timestamp of last renewal
- `~/.claude-wake-schedule` - Current wake schedule configuration
- `~/.claude-wake-scheduler.log` - Wake scheduling activity log
- `/tmp/claude-auto-renew-sleepaware.lock` - Lock file for execution control

## Error Handling

- **Missing Claude CLI**: Checks for `claude` command availability with explicit PATH
- **Interactive Prompts**: Bypasses security prompts with `--dangerously-skip-permissions`
- **ccusage Timeout**: 10-second timeout prevents hanging on network issues
- **Process Conflicts**: Lock file prevents overlapping executions
- **Session Failures**: Enhanced retry mechanism with proper cleanup
- **Sleep/Wake Issues**: Detects system wake and handles missed renewals
- **Power Management**: Graceful fallback if pmset commands fail

## Security Considerations

This is a defensive automation tool designed to:
- Maintain continuous Claude Code availability through scheduled renewals
- Work seamlessly with macOS sleep/wake cycles
- Provide transparent logging of all activities in Japan timezone
- Use minimal system resources with efficient power management

### Security Features
- **Permission Management**: Uses `--dangerously-skip-permissions` for automation (safe in trusted environment)
- **Non-Interactive Operation**: `--print` flag prevents interactive prompts
- **Lock File Protection**: Prevents multiple instances and process conflicts
- **Path Validation**: Explicit Claude CLI path management for secure execution
- **Timeout Protection**: Prevents hanging processes and resource leaks

The scripts do not handle sensitive data or provide attack surfaces - they only automate legitimate Claude CLI usage patterns with enhanced error handling and sleep-aware capabilities.

## Troubleshooting

### Common Issues

1. **Script Hanging**: Fixed with ccusage timeout and interactive prompt bypass
2. **Permission Prompts**: Resolved with `--dangerously-skip-permissions` flag
3. **Sleep/Wake Issues**: Handled by launchd automatic job execution
4. **Timezone Problems**: Use `./scripts/claude-timezone-config.sh info` to verify JST
5. **Wake Scheduling**: Check `pmset -g sched` for active wake schedules

### Migration from Legacy System

```bash
# Install new sleep-aware system
./scripts/claude-sleep-aware-manager.sh install

# Verify installation
./scripts/claude-sleep-aware-manager.sh status

# Test renewal
./scripts/claude-sleep-aware-manager.sh test
```