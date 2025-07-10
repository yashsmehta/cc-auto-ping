#!/bin/bash

# pmset Wake Scheduling Helper for Claude Auto-Renewal
# Manages system wake scheduling for Claude renewal times (7am and 12:01pm Japan time)
# Schedules wake 2 minutes before renewal times Monday-Saturday

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$HOME/.claude-wake-scheduler.log"
BACKUP_SCHEDULE_FILE="$HOME/.claude-wake-backup-schedule"
JAPAN_TZ="Asia/Tokyo"

# Wake times (2 minutes before renewal)
MORNING_WAKE="06:58:00"    # 2 minutes before 7:00 AM
AFTERNOON_WAKE="11:59:00"  # 2 minutes before 12:01 PM
WEEKDAYS="MTWRFS"          # Monday-Saturday (1-6)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(TZ="$JAPAN_TZ" date '+%Y-%m-%d %H:%M:%S JST')
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$LOG_FILE"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_message "INFO" "$1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_message "WARNING" "$1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_message "ERROR" "$1"
}

print_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
    log_message "DEBUG" "$1"
}

# Function to check if script is run with sudo
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        return 1
    fi
    return 0
}

# Function to handle sudo requirements
handle_sudo_requirements() {
    if ! check_sudo; then
        print_error "This script must be run with sudo privileges to modify pmset settings"
        print_info "Please run: sudo $0 $*"
        return 1
    fi
    return 0
}

# Function to calculate wake times in Japan timezone
calculate_wake_times() {
    local current_time_jp=$(TZ="$JAPAN_TZ" date '+%H:%M:%S')
    local current_date_jp=$(TZ="$JAPAN_TZ" date '+%Y-%m-%d')
    local current_weekday=$(TZ="$JAPAN_TZ" date '+%u')  # 1=Monday, 7=Sunday
    
    print_debug "Current Japan time: $current_time_jp"
    print_debug "Current Japan date: $current_date_jp"
    print_debug "Current weekday: $current_weekday (1=Mon, 7=Sun)"
    
    # Check if today is a weekday (1-6, Monday-Saturday)
    if [ "$current_weekday" -eq 7 ]; then
        print_warning "Today is Sunday - Claude renewals are not scheduled"
        return 1
    fi
    
    print_info "Wake times will be scheduled for Monday-Saturday:"
    print_info "  Morning wake: $MORNING_WAKE (2 minutes before 7:00 AM renewal)"
    print_info "  Afternoon wake: $AFTERNOON_WAKE (2 minutes before 12:01 PM renewal)"
    
    return 0
}

# Function to setup wake schedule for Japan timezone
setup_wake_schedule_japan() {
    print_info "Setting up wake schedule for Japan timezone..."
    
    if ! handle_sudo_requirements; then
        return 1
    fi
    
    if ! calculate_wake_times; then
        return 1
    fi
    
    # Cancel existing repeating schedules first
    print_info "Canceling existing repeating schedules..."
    if ! pmset repeat cancel 2>/dev/null; then
        print_warning "Failed to cancel existing schedules (may not exist)"
    fi
    
    # Create backup of current schedule
    create_backup_schedule
    
    # Set up the repeating wake schedule
    print_info "Setting up repeating wake schedule..."
    
    # Try to schedule both wake times
    local success_count=0
    
    # Morning wake (6:58 AM for 7:00 AM renewal)
    print_info "Scheduling morning wake at $MORNING_WAKE..."
    if pmset repeat wake "$WEEKDAYS" "$MORNING_WAKE" 2>/dev/null; then
        print_info "Morning wake scheduled successfully"
        success_count=$((success_count + 1))
    else
        print_error "Failed to schedule morning wake"
    fi
    
    # Note: pmset repeat can only handle one repeating event at a time
    # We'll need to use a different approach for multiple wake times
    
    # Alternative approach: Use schedule command for specific dates
    setup_specific_date_schedules
    
    if [ $success_count -gt 0 ]; then
        print_info "Wake schedule setup completed with $success_count successful schedules"
        verify_wake_schedule
        return 0
    else
        print_error "Failed to setup wake schedule"
        return 1
    fi
}

# Function to setup specific date schedules (alternative approach)
setup_specific_date_schedules() {
    print_info "Setting up specific date schedules for the next 7 days..."
    
    for i in {1..7}; do
        local future_date=$(TZ="$JAPAN_TZ" date -v+${i}d '+%m/%d/%y')
        local future_weekday=$(TZ="$JAPAN_TZ" date -v+${i}d '+%u')
        
        # Skip Sunday (weekday 7)
        if [ "$future_weekday" -ne 7 ]; then
            # Schedule morning wake
            print_debug "Scheduling wake for $future_date $MORNING_WAKE"
            if pmset schedule wake "$future_date $MORNING_WAKE" "Claude-Auto-Renewal-Morning" 2>/dev/null; then
                print_debug "Scheduled morning wake for $future_date"
            fi
            
            # Schedule afternoon wake
            print_debug "Scheduling wake for $future_date $AFTERNOON_WAKE"
            if pmset schedule wake "$future_date $AFTERNOON_WAKE" "Claude-Auto-Renewal-Afternoon" 2>/dev/null; then
                print_debug "Scheduled afternoon wake for $future_date"
            fi
        fi
    done
}

# Function to remove wake schedule
remove_wake_schedule() {
    print_info "Removing Claude wake schedule..."
    
    if ! handle_sudo_requirements; then
        return 1
    fi
    
    # Cancel all repeating schedules
    print_info "Canceling repeating schedules..."
    if pmset repeat cancel 2>/dev/null; then
        print_info "Repeating schedules canceled"
    else
        print_warning "No repeating schedules to cancel"
    fi
    
    # Cancel specific scheduled events related to Claude
    print_info "Canceling specific Claude-related scheduled events..."
    local canceled_count=0
    
    # Get current scheduled events and cancel Claude-related ones
    local scheduled_events=$(pmset -g sched | grep -i "claude\|Claude-Auto-Renewal")
    
    if [ -n "$scheduled_events" ]; then
        print_info "Found Claude-related scheduled events:"
        echo "$scheduled_events"
        
        # Cancel all scheduled events (pmset doesn't allow selective cancellation easily)
        # This is a limitation - we can't easily cancel just our events
        print_warning "Cannot selectively cancel Claude events - use 'pmset schedule cancelall' to cancel all if needed"
    else
        print_info "No Claude-related scheduled events found"
    fi
    
    print_info "Wake schedule removal completed"
    return 0
}

# Function to verify wake schedule
verify_wake_schedule() {
    print_info "Verifying wake schedule..."
    
    local scheduled_events=$(pmset -g sched 2>/dev/null)
    
    if [ -z "$scheduled_events" ]; then
        print_warning "No scheduled events found"
        return 1
    fi
    
    print_info "Current scheduled events:"
    echo "$scheduled_events" | while read -r line; do
        echo "  $line"
    done
    
    # Check for Claude-related events
    local claude_events=$(echo "$scheduled_events" | grep -i "claude\|Claude-Auto-Renewal")
    
    if [ -n "$claude_events" ]; then
        print_info "Found Claude-related wake events:"
        echo "$claude_events" | while read -r line; do
            echo "  $line"
        done
        return 0
    else
        print_warning "No Claude-related wake events found in schedule"
        return 1
    fi
}

# Function to create backup of current schedule
create_backup_schedule() {
    print_info "Creating backup of current schedule..."
    
    local current_schedule=$(pmset -g sched 2>/dev/null)
    
    if [ -n "$current_schedule" ]; then
        echo "# Claude Wake Schedule Backup - $(date)" > "$BACKUP_SCHEDULE_FILE"
        echo "# Original schedule before Claude wake setup" >> "$BACKUP_SCHEDULE_FILE"
        echo "$current_schedule" >> "$BACKUP_SCHEDULE_FILE"
        print_info "Schedule backup saved to $BACKUP_SCHEDULE_FILE"
    else
        print_info "No existing schedule to backup"
    fi
}

# Function to restore backup schedule
restore_backup_schedule() {
    print_info "Restoring backup schedule..."
    
    if [ ! -f "$BACKUP_SCHEDULE_FILE" ]; then
        print_error "No backup schedule file found at $BACKUP_SCHEDULE_FILE"
        return 1
    fi
    
    print_info "Backup schedule contents:"
    cat "$BACKUP_SCHEDULE_FILE"
    
    print_warning "Automatic schedule restoration is not implemented"
    print_info "Please manually restore schedules if needed using pmset commands"
    
    return 0
}

# Function to show current Japan time and next renewal times
show_status() {
    print_info "Claude Wake Scheduler Status"
    
    local current_time_jp=$(TZ="$JAPAN_TZ" date '+%H:%M:%S')
    local current_date_jp=$(TZ="$JAPAN_TZ" date '+%Y-%m-%d')
    local current_weekday=$(TZ="$JAPAN_TZ" date '+%u')
    
    echo ""
    print_info "Current Japan time: $current_date_jp $current_time_jp"
    print_info "Current weekday: $current_weekday (1=Mon, 7=Sun)"
    
    # Calculate next renewal times
    local next_morning="07:00:00"
    local next_afternoon="12:01:00"
    
    if [ "$current_weekday" -eq 7 ]; then
        print_warning "Today is Sunday - no renewals scheduled"
        print_info "Next renewal: Monday at $next_morning"
    else
        print_info "Today's renewal times:"
        print_info "  Morning: $next_morning (wake at $MORNING_WAKE)"
        print_info "  Afternoon: $next_afternoon (wake at $AFTERNOON_WAKE)"
    fi
    
    echo ""
    verify_wake_schedule
}

# Function to test wake scheduling (dry run)
test_wake_scheduling() {
    print_info "Testing wake scheduling (dry run)..."
    
    print_info "Would schedule the following wake times:"
    print_info "  Weekdays: $WEEKDAYS (Monday-Saturday)"
    print_info "  Morning wake: $MORNING_WAKE (for 7:00 AM renewal)"
    print_info "  Afternoon wake: $AFTERNOON_WAKE (for 12:01 PM renewal)"
    
    calculate_wake_times
    
    print_info "Current system timezone: $(date '+%Z')"
    print_info "Target timezone: $JAPAN_TZ"
    
    if ! check_sudo; then
        print_warning "Not running as sudo - would require sudo privileges to make changes"
    else
        print_info "Running as sudo - can make changes"
    fi
    
    print_info "Test completed - no changes made"
}

# Function to show help
show_help() {
    echo "Claude Wake Scheduler Helper"
    echo ""
    echo "Usage: $0 {setup|remove|verify|status|test|backup|restore|help}"
    echo ""
    echo "Commands:"
    echo "  setup    - Setup wake schedule for Claude renewals (requires sudo)"
    echo "  remove   - Remove Claude wake schedule (requires sudo)"
    echo "  verify   - Verify current wake schedule"
    echo "  status   - Show current status and next renewal times"
    echo "  test     - Test wake scheduling without making changes"
    echo "  backup   - Create backup of current schedule"
    echo "  restore  - Restore backup schedule"
    echo "  help     - Show this help message"
    echo ""
    echo "Wake Schedule Details:"
    echo "  - Schedules wake 2 minutes before renewal times"
    echo "  - Morning: Wake at $MORNING_WAKE for 7:00 AM renewal"
    echo "  - Afternoon: Wake at $AFTERNOON_WAKE for 12:01 PM renewal"
    echo "  - Active: Monday-Saturday (excludes Sunday)"
    echo "  - Timezone: Japan (Asia/Tokyo)"
    echo ""
    echo "Note: This script requires sudo privileges to modify pmset settings"
}

# Main command handling
case "$1" in
    setup)
        setup_wake_schedule_japan
        ;;
    remove)
        remove_wake_schedule
        ;;
    verify)
        verify_wake_schedule
        ;;
    status)
        show_status
        ;;
    test)
        test_wake_scheduling
        ;;
    backup)
        create_backup_schedule
        ;;
    restore)
        restore_backup_schedule
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        show_help
        exit 1
        ;;
esac

exit $?