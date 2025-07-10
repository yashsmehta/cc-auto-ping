#!/bin/bash

# Setup Log Rotation for Claude Auto-Renewal
# Handles increased log volume from 12 renewals/week vs 4 renewals/week

echo "Setting up log rotation for Claude auto-renewal..."

# Check if logrotate is available
if ! command -v logrotate &> /dev/null; then
    echo "Warning: logrotate not found. Consider installing it for automatic log management."
    echo "On macOS: brew install logrotate"
    echo "On Linux: Usually pre-installed"
    exit 1
fi

# Create logrotate configuration directory if it doesn't exist
LOGROTATE_DIR="$HOME/.config/logrotate"
mkdir -p "$LOGROTATE_DIR"

# Create logrotate configuration for Claude logs
cat > "$LOGROTATE_DIR/claude-auto-renewal" << 'EOF'
# Claude Auto-Renewal Log Rotation Configuration
# Handles increased log volume from 12 renewals/week

# Main cron log
/Users/*/claude-cron.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644
    # Keep logs for 7 days (covers 12 renewals)
}

# Daemon log
/Users/*/claude-auto-renew-daemon.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 644
    # Keep logs for 14 days for debugging
}

# Setup log for troubleshooting
/Users/*/claude-cron-setup.log {
    weekly
    rotate 4
    compress
    delaycompress
    missingok
    notifempty
    create 644
}
EOF

echo "Log rotation configuration created at: $LOGROTATE_DIR/claude-auto-renewal"

# Create a simple log rotation script for manual execution
cat > "$HOME/.claude-log-rotate.sh" << 'EOF'
#!/bin/bash

# Manual log rotation for Claude auto-renewal logs
# Run this weekly or when logs get too large

LOG_DIR="$HOME"
DATE=$(date +%Y%m%d)

# Function to rotate a log file
rotate_log() {
    local log_file="$1"
    local keep_days="$2"
    
    if [ -f "$log_file" ]; then
        # Get file size
        size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
        
        if [ "$size" -gt 1048576 ]; then  # 1MB
            echo "Rotating $log_file (size: $((size / 1024))KB)"
            
            # Compress and archive
            gzip -c "$log_file" > "${log_file}.${DATE}.gz"
            
            # Clear the original log
            > "$log_file"
            
            # Clean up old archives (keep last N days)
            find "$(dirname "$log_file")" -name "$(basename "$log_file").*.gz" -mtime +${keep_days} -delete
            
            echo "  Archived to: ${log_file}.${DATE}.gz"
        else
            echo "$log_file is small (size: $((size / 1024))KB), no rotation needed"
        fi
    else
        echo "Log file not found: $log_file"
    fi
}

echo "=== Claude Auto-Renewal Log Rotation ==="
echo "Date: $(date)"
echo ""

# Rotate logs
rotate_log "$LOG_DIR/.claude-cron.log" 7
rotate_log "$LOG_DIR/.claude-auto-renew-daemon.log" 14
rotate_log "$LOG_DIR/.claude-cron-setup.log" 30

echo ""
echo "Log rotation complete."
echo "Run this script weekly or when logs exceed 1MB."
EOF

chmod +x "$HOME/.claude-log-rotate.sh"
echo "Manual log rotation script created at: $HOME/.claude-log-rotate.sh"

# Create a simple monitoring script
cat > "$HOME/.claude-log-monitor.sh" << 'EOF'
#!/bin/bash

# Claude Auto-Renewal Log Monitor
# Checks log sizes and renewal frequency

echo "=== Claude Auto-Renewal Log Monitor ==="
echo "Date: $(date)"
echo ""

# Function to check log file
check_log() {
    local log_file="$1"
    local description="$2"
    
    if [ -f "$log_file" ]; then
        size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
        lines=$(wc -l < "$log_file")
        
        echo "$description:"
        echo "  File: $log_file"
        echo "  Size: $((size / 1024))KB"
        echo "  Lines: $lines"
        
        # Check if log is growing too fast
        if [ "$size" -gt 5242880 ]; then  # 5MB
            echo "  ⚠ WARNING: Log file is large (>5MB)"
        elif [ "$size" -gt 1048576 ]; then  # 1MB
            echo "  ⚠ Notice: Log file is growing (>1MB)"
        else
            echo "  ✓ Size OK"
        fi
        
        # Show recent activity
        echo "  Recent entries:"
        tail -3 "$log_file" | sed 's/^/    /'
        echo ""
    else
        echo "$description: File not found ($log_file)"
        echo ""
    fi
}

# Check all log files
check_log "$HOME/.claude-cron.log" "Cron Log"
check_log "$HOME/.claude-auto-renew-daemon.log" "Daemon Log"
check_log "$HOME/.claude-cron-setup.log" "Setup Log"

# Check renewal frequency (from cron log)
if [ -f "$HOME/.claude-cron.log" ]; then
    echo "Renewal Frequency Analysis:"
    echo "Expected: 12 renewals per week (Monday-Saturday, 7AM & 12:01PM)"
    
    # Count renewals in the last 7 days
    if command -v grep &> /dev/null; then
        week_renewals=$(grep -c "$(date -d '7 days ago' +%Y-%m-%d)" "$HOME/.claude-cron.log" 2>/dev/null || echo "0")
        echo "Last 7 days: $week_renewals renewals"
        
        if [ "$week_renewals" -lt 10 ]; then
            echo "  ⚠ WARNING: Lower than expected renewal frequency"
        elif [ "$week_renewals" -gt 15 ]; then
            echo "  ⚠ WARNING: Higher than expected renewal frequency"
        else
            echo "  ✓ Renewal frequency looks normal"
        fi
    fi
fi

echo ""
echo "=== Monitor Complete ==="
EOF

chmod +x "$HOME/.claude-log-monitor.sh"
echo "Log monitoring script created at: $HOME/.claude-log-monitor.sh"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Created:"
echo "  - Log rotation config: $LOGROTATE_DIR/claude-auto-renewal"
echo "  - Manual rotation script: $HOME/.claude-log-rotate.sh"
echo "  - Log monitoring script: $HOME/.claude-log-monitor.sh"
echo ""
echo "Usage:"
echo "  - Monitor logs: $HOME/.claude-log-monitor.sh"
echo "  - Rotate logs manually: $HOME/.claude-log-rotate.sh"
echo "  - Set up automatic rotation: Configure logrotate with created config"
echo ""
echo "With 12 renewals per week, consider running log rotation weekly."