# Claude Auto-Renewal Wake Scheduling Guide

## Overview

The Claude Auto-Renewal system now includes wake scheduling integration to ensure your system is awake before Claude renewal times. This prevents missed renewals due to system sleep.

## Key Features

- **Japan Timezone Support**: All scheduling based on Asia/Tokyo timezone
- **Dual Wake Times**: 6:58 AM and 11:59 AM (2 minutes before renewals)
- **Weekday Scheduling**: Monday-Saturday only (excludes Sunday)
- **Error Handling**: Comprehensive error handling and logging
- **Backup Support**: Automatic backup of existing schedules

## Quick Start

### 1. Setup Wake Schedule

```bash
# Setup wake scheduling (requires sudo)
sudo ./claude-daemon-manager.sh setup-wake
```

### 2. Verify Schedule

```bash
# Check wake schedule status
./claude-daemon-manager.sh wake-status

# Verify current schedule
./claude-daemon-manager.sh wake-verify
```

### 3. Remove Schedule (if needed)

```bash
# Remove wake schedule (requires sudo)
sudo ./claude-daemon-manager.sh remove-wake
```

## Wake Schedule Details

### Timing
- **Morning Wake**: 6:58 AM JST (for 7:00 AM renewal)
- **Afternoon Wake**: 11:59 AM JST (for 12:01 PM renewal)
- **Days**: Monday-Saturday (1-6)
- **Timezone**: Asia/Tokyo (JST)

### What Happens
1. System wakes 2 minutes before renewal times
2. Claude daemon detects the renewal window
3. Automatic session initiation occurs
4. System can return to sleep after renewal

## Command Reference

### Daemon Manager Commands

```bash
# Wake scheduling commands
./claude-daemon-manager.sh setup-wake     # Setup wake schedule (requires sudo)
./claude-daemon-manager.sh remove-wake    # Remove wake schedule (requires sudo)
./claude-daemon-manager.sh wake-status    # Show wake schedule status
./claude-daemon-manager.sh wake-verify    # Verify current wake schedule
```

### Direct Wake Helper Commands

```bash
# Direct access to wake helper
./pmset-wake-helper.sh setup      # Setup wake schedule
./pmset-wake-helper.sh remove     # Remove wake schedule
./pmset-wake-helper.sh verify     # Verify schedule
./pmset-wake-helper.sh status     # Show status
./pmset-wake-helper.sh test       # Test mode (dry run)
./pmset-wake-helper.sh backup     # Backup current schedule
./pmset-wake-helper.sh restore    # Restore backup schedule
```

## System Requirements

### Prerequisites
- macOS system with pmset command
- sudo privileges for pmset modifications
- Claude Auto-Renewal daemon system

### Permissions
- Wake scheduling requires sudo privileges
- Status and verification commands do not require sudo

## Troubleshooting

### Common Issues

1. **"Must be run as root" error**
   - Solution: Use `sudo` for setup/remove commands

2. **No Claude-related wake events found**
   - This is normal before first setup
   - Run `sudo ./claude-daemon-manager.sh setup-wake` to create schedule

3. **Conflicting wake schedules**
   - Use `./pmset-wake-helper.sh backup` before setup
   - Review existing schedules with `pmset -g sched`

### Logs
- Wake scheduler logs: `~/.claude-wake-scheduler.log`
- Daemon logs: `~/.claude-auto-renew-daemon.log`
- Schedule backup: `~/.claude-wake-backup-schedule`

## Technical Details

### pmset Integration
- Uses `pmset repeat` for recurring schedules
- Falls back to `pmset schedule` for specific dates
- Handles timezone conversions automatically

### Limitations
- pmset can only handle one repeating schedule at a time
- Multiple wake times require specific date scheduling
- System must remain powered for wake scheduling to work

### Security
- All pmset commands require sudo privileges
- Backup schedules are created before modifications
- Comprehensive error handling prevents system conflicts

## Best Practices

1. **Test First**: Use `./pmset-wake-helper.sh test` to verify settings
2. **Backup**: Always backup existing schedules before modifications
3. **Monitor**: Check logs regularly for scheduling issues
4. **Verify**: Use verify commands to confirm schedule is active

## Integration with Claude Daemon

The wake scheduling system integrates seamlessly with the Claude Auto-Renewal daemon:

1. Wake schedule ensures system is awake before renewal times
2. Daemon detects renewal windows and initiates sessions
3. Combined system provides uninterrupted Claude usage

## Example Usage

```bash
# Complete setup process
sudo ./claude-daemon-manager.sh setup-wake

# Start the daemon
./claude-daemon-manager.sh start

# Check both daemon and wake status
./claude-daemon-manager.sh status
./claude-daemon-manager.sh wake-status

# Monitor logs
./claude-daemon-manager.sh logs -f
```

This ensures your Claude renewals happen reliably, even when your system is asleep.