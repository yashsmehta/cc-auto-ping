# Kill Stuck Claude Processes

If you have stuck Claude processes running, follow these steps to clean them up:

## 1. Find stuck Claude processes
```bash
ps aux | grep claude | grep -v grep
```

## 2. Kill only Claude CLI processes (more precise)
```bash
# Kill only the claude CLI command
pkill -f "^claude "

# Or kill specific Claude auto-renew scripts
pkill -f "claude-auto-renew-sleepaware.sh"
```

## 3. If processes persist, manually kill by PID
```bash
# Find the specific PIDs
ps aux | grep -E "(^claude |claude-auto-renew)" | grep -v grep

# Kill specific PIDs (replace XXX with actual PID numbers)
kill XXX XXX

# Force kill if needed
kill -9 XXX XXX
```

## 4. Clean up lock file
```bash
rm -f /tmp/claude-auto-renew-sleepaware.lock
```

## 5. Reload the launchd service
```bash
launchctl unload ~/Library/LaunchAgents/com.claude.autorenew.sleepaware.plist
launchctl load ~/Library/LaunchAgents/com.claude.autorenew.sleepaware.plist
```

## 6. Check service status
```bash
launchctl list | grep com.claude.autorenew
```

The service should now run on the correct schedule (Monday-Saturday at 7:00 AM and 12:01 PM JST) instead of every 5 minutes.