#!/bin/bash

# Claude Sleep-Aware Manager
# Comprehensive management script for sleep-aware Claude renewal system
# Handles launchd job installation, pmset wake scheduling, and system management

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LAUNCHD_PLIST_PATH="$HOME/Library/LaunchAgents/com.claude.auto-renew.plist"
PMSET_WAKE_LABEL="claude-auto-renew"
LOG_FILE="$HOME/.claude-auto-renew.log"
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"
RENEWAL_SCRIPT="$SCRIPT_DIR/claude-auto-renew-sleepaware.sh"
WAKE_SCHEDULE_FILE="$HOME/.claude-wake-schedule"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to get Japan timezone time
get_japan_time() {
    TZ='Asia/Tokyo' date "$@"
}

# Function to create launchd plist
create_launchd_plist() {
    cat > "$LAUNCHD_PLIST_PATH" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.auto-renew</string>
    <key>Program</key>
    <string>$RENEWAL_SCRIPT</string>
    <key>StartInterval</key>
    <integer>600</integer>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>RunAtLoad</key>
    <false/>
    <key>ProcessType</key>
    <string>Background</string>
    <key>LowPriorityIO</key>
    <true/>
    <key>Nice</key>
    <integer>1</integer>
</dict>
</plist>
EOF
}

# Function to setup pmset wake schedule
setup_pmset_wake_schedule() {
    print_info "Setting up pmset wake schedule..."
    
    # Clear existing schedules with our label
    pmset -g sched | grep "$PMSET_WAKE_LABEL" | while read -r line; do
        if [[ "$line" =~ wake.*\"$PMSET_WAKE_LABEL\" ]]; then
            print_info "Removing existing wake schedule: $line"
            # Extract the schedule ID and remove it
            schedule_id=$(echo "$line" | awk '{print $1}')
            sudo pmset schedule cancel "$schedule_id" 2>/dev/null || true
        fi
    done
    
    # Set up wake schedule every 4 hours (4 times per day)
    local wake_times=("02:00:00" "06:00:00" "10:00:00" "14:00:00" "18:00:00" "22:00:00")
    local current_hour=$(date +%H)
    
    for wake_time in "${wake_times[@]}"; do
        local wake_hour=${wake_time:0:2}
        
        # Only schedule future wake times for today and tomorrow
        if [ "$wake_hour" -gt "$current_hour" ] || [ "$wake_hour" -eq "$current_hour" ]; then
            # Schedule for today
            sudo pmset schedule wake "$wake_time" "$PMSET_WAKE_LABEL" 2>/dev/null || true
        fi
        
        # Schedule for tomorrow
        local tomorrow=$(date -v+1d +%m/%d/%Y)
        sudo pmset schedule wake "$tomorrow $wake_time" "$PMSET_WAKE_LABEL" 2>/dev/null || true
    done
    
    # Save schedule info
    echo "$(date): Wake schedule updated" > "$WAKE_SCHEDULE_FILE"
    echo "Wake times: ${wake_times[*]}" >> "$WAKE_SCHEDULE_FILE"
    
    print_status "Wake schedule configured for times: ${wake_times[*]}"
}

# Function to install the sleep-aware system
install_sleep_aware_system() {
    print_status "Installing Claude sleep-aware renewal system..."
    
    # Check if renewal script exists
    if [ ! -f "$RENEWAL_SCRIPT" ]; then
        print_error "Renewal script not found: $RENEWAL_SCRIPT"
        return 1
    fi
    
    # Make renewal script executable
    chmod +x "$RENEWAL_SCRIPT"
    
    # Create launchd plist
    print_info "Creating launchd plist..."
    create_launchd_plist
    
    # Load the launchd job
    print_info "Loading launchd job..."
    if launchctl load "$LAUNCHD_PLIST_PATH" 2>/dev/null; then
        print_status "LaunchAgent loaded successfully"
    else
        print_warning "LaunchAgent may already be loaded"
    fi
    
    # Enable the job
    if launchctl enable "gui/$(id -u)/com.claude.auto-renew" 2>/dev/null; then
        print_status "LaunchAgent enabled successfully"
    else
        print_warning "LaunchAgent may already be enabled"
    fi
    
    # Setup pmset wake schedule
    setup_pmset_wake_schedule
    
    # Create initial log file
    touch "$LOG_FILE"
    log_message "Sleep-aware Claude renewal system installed"
    
    print_status "Installation complete!"
    print_info "System will now:"
    print_info "  - Wake the computer at scheduled times"
    print_info "  - Check for renewal needs every 10 minutes when awake"
    print_info "  - Maintain continuous 5-hour usage blocks"
    print_info "  - Log all activity to: $LOG_FILE"
    
    return 0
}

# Function to uninstall the sleep-aware system
uninstall_sleep_aware_system() {
    print_status "Uninstalling Claude sleep-aware renewal system..."
    
    # Stop and unload launchd job
    print_info "Stopping launchd job..."
    launchctl bootout "gui/$(id -u)/com.claude.auto-renew" 2>/dev/null || true
    launchctl unload "$LAUNCHD_PLIST_PATH" 2>/dev/null || true
    
    # Remove plist file
    if [ -f "$LAUNCHD_PLIST_PATH" ]; then
        rm -f "$LAUNCHD_PLIST_PATH"
        print_status "Removed launchd plist"
    fi
    
    # Remove pmset wake schedules
    print_info "Removing pmset wake schedules..."
    pmset -g sched | grep "$PMSET_WAKE_LABEL" | while read -r line; do
        if [[ "$line" =~ wake.*\"$PMSET_WAKE_LABEL\" ]]; then
            print_info "Removing wake schedule: $line"
            schedule_id=$(echo "$line" | awk '{print $1}')
            sudo pmset schedule cancel "$schedule_id" 2>/dev/null || true
        fi
    done
    
    # Clean up files
    rm -f "$WAKE_SCHEDULE_FILE"
    
    log_message "Sleep-aware Claude renewal system uninstalled"
    print_status "Uninstallation complete!"
    
    return 0
}

# Function to check system status
check_system_status() {
    print_status "Claude Sleep-Aware Renewal System Status"
    echo "=================================================="
    
    # Check launchd job status
    print_info "LaunchAgent Status:"
    if launchctl list | grep -q "com.claude.auto-renew"; then
        local status_info=$(launchctl list com.claude.auto-renew 2>/dev/null)
        if [ -n "$status_info" ]; then
            echo "  Status: Running"
            echo "  Details: $status_info"
        else
            echo "  Status: Loaded but not running"
        fi
    else
        echo "  Status: Not loaded"
    fi
    
    # Check plist file
    print_info "Configuration:"
    if [ -f "$LAUNCHD_PLIST_PATH" ]; then
        echo "  Plist: Installed"
    else
        echo "  Plist: Not found"
    fi
    
    # Check pmset wake schedules
    print_info "Wake Schedules:"
    local wake_schedules=$(pmset -g sched | grep "$PMSET_WAKE_LABEL" || echo "")
    if [ -n "$wake_schedules" ]; then
        echo "$wake_schedules" | while read -r line; do
            if [[ "$line" =~ wake.*\"$PMSET_WAKE_LABEL\" ]]; then
                echo "  $line"
            fi
        done
    else
        echo "  No wake schedules found"
    fi
    
    # Show next wake time
    local next_wake=$(pmset -g sched | grep "$PMSET_WAKE_LABEL" | head -1)
    if [ -n "$next_wake" ]; then
        print_info "Next Wake: $next_wake"
    fi
    
    # Check last activity
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        local last_activity=$(cat "$LAST_ACTIVITY_FILE")
        local last_activity_date=$(date -r "$last_activity" '+%Y-%m-%d %H:%M:%S')
        local last_activity_japan=$(TZ='Asia/Tokyo' date -r "$last_activity" '+%Y-%m-%d %H:%M:%S JST')
        print_info "Last Activity: $last_activity_date (Local) / $last_activity_japan"
        
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_activity))
        local hours=$((time_diff / 3600))
        local minutes=$(((time_diff % 3600) / 60))
        echo "  Time since last activity: ${hours}h ${minutes}m"
    else
        print_info "Last Activity: No activity recorded"
    fi
    
    # Check log file
    print_info "Log File:"
    if [ -f "$LOG_FILE" ]; then
        local log_size=$(wc -l < "$LOG_FILE")
        echo "  Location: $LOG_FILE"
        echo "  Lines: $log_size"
        echo "  Recent activity:"
        tail -3 "$LOG_FILE" | sed 's/^/    /' 2>/dev/null || echo "    (No recent activity)"
    else
        echo "  Status: No log file found"
    fi
    
    echo "=================================================="
}

# Function to show logs with Japan timezone
show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        print_error "No log file found at $LOG_FILE"
        return 1
    fi
    
    local lines=${1:-50}
    local follow_mode=${2:-false}
    
    if [ "$follow_mode" = "true" ]; then
        print_info "Following log file (showing times in Japan timezone):"
        tail -f "$LOG_FILE" | while read -r line; do
            # Extract timestamp and convert to Japan time
            if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local japan_time=$(TZ='Asia/Tokyo' date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%Y-%m-%d %H:%M:%S JST" 2>/dev/null)
                if [ -n "$japan_time" ]; then
                    echo "$line" | sed "s/\[$timestamp\]/[$japan_time]/"
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        done
    else
        print_info "Showing last $lines log entries (times in Japan timezone):"
        tail -"$lines" "$LOG_FILE" | while read -r line; do
            # Extract timestamp and convert to Japan time
            if [[ "$line" =~ ^\[([^\]]+)\] ]]; then
                local timestamp="${BASH_REMATCH[1]}"
                local japan_time=$(TZ='Asia/Tokyo' date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%Y-%m-%d %H:%M:%S JST" 2>/dev/null)
                if [ -n "$japan_time" ]; then
                    echo "$line" | sed "s/\[$timestamp\]/[$japan_time]/"
                else
                    echo "$line"
                fi
            else
                echo "$line"
            fi
        done
    fi
}

# Function to test renewal
test_renewal() {
    print_status "Testing Claude renewal process..."
    
    # Check if renewal script exists
    if [ ! -f "$RENEWAL_SCRIPT" ]; then
        print_error "Renewal script not found: $RENEWAL_SCRIPT"
        return 1
    fi
    
    # Make sure it's executable
    chmod +x "$RENEWAL_SCRIPT"
    
    # Run the renewal script in test mode
    print_info "Running renewal script in test mode..."
    log_message "Manual test renewal initiated"
    
    if "$RENEWAL_SCRIPT" --test; then
        print_status "Renewal script completed successfully"
        print_info "Check the logs for detailed output: $LOG_FILE"
        return 0
    else
        print_error "Renewal script failed"
        print_error "Check the logs for details: $LOG_FILE"
        return 1
    fi
}

# Function to migrate from daemon system
migrate_from_daemon() {
    print_status "Migrating from daemon system to sleep-aware system..."
    
    # Check if daemon is running and stop it
    local daemon_pid_file="$HOME/.claude-auto-renew-daemon.pid"
    if [ -f "$daemon_pid_file" ]; then
        print_info "Stopping existing daemon..."
        local daemon_manager="$SCRIPT_DIR/claude-daemon-manager.sh"
        if [ -f "$daemon_manager" ]; then
            "$daemon_manager" stop 2>/dev/null || true
        else
            # Manual cleanup
            local pid=$(cat "$daemon_pid_file")
            if kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
                sleep 2
                kill -9 "$pid" 2>/dev/null || true
            fi
            rm -f "$daemon_pid_file"
        fi
        print_status "Daemon stopped"
    fi
    
    # Preserve existing logs and activity data
    local daemon_log="$HOME/.claude-auto-renew-daemon.log"
    if [ -f "$daemon_log" ]; then
        print_info "Preserving daemon logs..."
        cat "$daemon_log" >> "$LOG_FILE"
        print_status "Daemon logs merged into $LOG_FILE"
    fi
    
    # Install new system
    if install_sleep_aware_system; then
        print_status "Migration completed successfully!"
        print_info "The sleep-aware system is now active"
        print_info "You can remove the daemon files if no longer needed:"
        print_info "  - $daemon_pid_file"
        print_info "  - $daemon_log"
        print_info "  - $SCRIPT_DIR/claude-daemon-manager.sh"
        print_info "  - $SCRIPT_DIR/claude-auto-renew-daemon.sh"
    else
        print_error "Migration failed during installation"
        return 1
    fi
}

# Function to verify installation
verify_installation() {
    print_status "Verifying sleep-aware system installation..."
    
    local errors=0
    
    # Check renewal script
    if [ ! -f "$RENEWAL_SCRIPT" ]; then
        print_error "Renewal script not found: $RENEWAL_SCRIPT"
        ((errors++))
    elif [ ! -x "$RENEWAL_SCRIPT" ]; then
        print_error "Renewal script is not executable: $RENEWAL_SCRIPT"
        ((errors++))
    fi
    
    # Check launchd plist
    if [ ! -f "$LAUNCHD_PLIST_PATH" ]; then
        print_error "LaunchAgent plist not found: $LAUNCHD_PLIST_PATH"
        ((errors++))
    fi
    
    # Check if launchd job is loaded
    if ! launchctl list | grep -q "com.claude.auto-renew"; then
        print_error "LaunchAgent is not loaded"
        ((errors++))
    fi
    
    # Check pmset wake schedules
    if ! pmset -g sched | grep -q "$PMSET_WAKE_LABEL"; then
        print_error "No pmset wake schedules found"
        ((errors++))
    fi
    
    # Check log file
    if [ ! -f "$LOG_FILE" ]; then
        print_warning "Log file not found (will be created on first run)"
    fi
    
    if [ $errors -eq 0 ]; then
        print_status "Installation verification successful!"
        print_info "All components are properly installed and configured"
        return 0
    else
        print_error "Installation verification failed with $errors errors"
        return 1
    fi
}

# Main command handling
case "$1" in
    install)
        install_sleep_aware_system
        ;;
    uninstall)
        uninstall_sleep_aware_system
        ;;
    status)
        check_system_status
        ;;
    logs)
        if [ "$2" = "-f" ] || [ "$2" = "--follow" ]; then
            show_logs 50 true
        else
            show_logs "${2:-50}" false
        fi
        ;;
    test)
        test_renewal
        ;;
    migrate)
        migrate_from_daemon
        ;;
    verify)
        verify_installation
        ;;
    wake-schedule)
        setup_pmset_wake_schedule
        ;;
    *)
        echo "Claude Sleep-Aware Renewal System Manager"
        echo ""
        echo "Usage: $0 {install|uninstall|status|logs|test|migrate|verify|wake-schedule}"
        echo ""
        echo "Commands:"
        echo "  install       - Install the sleep-aware renewal system"
        echo "  uninstall     - Remove the sleep-aware renewal system"
        echo "  status        - Show system status and configuration"
        echo "  logs [N]      - Show last N log entries (default: 50)"
        echo "  logs -f       - Follow log file in real-time"
        echo "  test          - Test the renewal process manually"
        echo "  migrate       - Migrate from daemon system to sleep-aware"
        echo "  verify        - Verify installation integrity"
        echo "  wake-schedule - Update pmset wake schedule"
        echo ""
        echo "The sleep-aware system will:"
        echo "  - Wake your Mac at scheduled times for renewals"
        echo "  - Monitor Claude usage and maintain 5-hour blocks"
        echo "  - Handle system sleep/wake cycles automatically"
        echo "  - Log all activity with Japan timezone support"
        echo ""
        echo "Benefits over daemon system:"
        echo "  - Works even when computer is sleeping"
        echo "  - More reliable wake scheduling"
        echo "  - Better power management"
        echo "  - Automatic system integration"
        ;;
esac