#!/bin/bash

# Claude Code Timezone Configuration Helper
# This script helps configure and manage timezone settings for Claude Code renewal

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Japan timezone configuration
JAPAN_TZ="Asia/Tokyo"
JAPAN_SCHEDULE_HOURS=("7" "12")  # 7 AM and 12 PM
JAPAN_SCHEDULE_MINUTES=("0" "1")  # 0 minutes for 7 AM, 1 minute for 12 PM

# Function to display current timezone information
show_timezone_info() {
    log "Current Timezone Information:"
    echo "System timezone: $(date +%Z)"
    echo "Current time: $(date)"
    echo "Current time in Japan: $(TZ=Asia/Tokyo date)"
    echo "UTC time: $(TZ=UTC date)"
    echo
    
    # Show timezone offset
    OFFSET=$(date +%z)
    JAPAN_OFFSET=$(TZ=Asia/Tokyo date +%z)
    echo "Local offset from UTC: $OFFSET"
    echo "Japan offset from UTC: $JAPAN_OFFSET"
    echo
}

# Function to calculate next execution times
calculate_next_executions() {
    log "Calculating next execution times..."
    
    # Get current time in Japan
    JAPAN_TIME=$(TZ=Asia/Tokyo date "+%Y-%m-%d %H:%M:%S")
    JAPAN_WEEKDAY=$(TZ=Asia/Tokyo date "+%u")  # 1=Monday, 7=Sunday
    
    log "Current time in Japan: $JAPAN_TIME (Weekday: $JAPAN_WEEKDAY)"
    
    if [[ $JAPAN_WEEKDAY -eq 7 ]]; then
        echo "Today is Sunday - no executions scheduled"
        echo "Next execution: Monday at 7:00 AM Japan time"
    else
        echo "Today is a weekday - executions scheduled at:"
        echo "  - 7:00 AM Japan time"
        echo "  - 12:01 PM Japan time"
    fi
    echo
}

# Function to convert Japan time to local time
convert_japan_to_local() {
    local japan_hour=$1
    local japan_minute=$2
    
    # Create a timestamp for today at the specified Japan time
    local japan_date=$(TZ=Asia/Tokyo date "+%Y-%m-%d")
    local japan_timestamp="${japan_date} ${japan_hour}:${japan_minute}:00"
    
    # Convert to local time
    local local_time=$(TZ=Asia/Tokyo date -d "$japan_timestamp" "+%Y-%m-%d %H:%M:%S")
    local local_time_converted=$(date -d "$local_time" "+%H:%M")
    
    echo "$local_time_converted"
}

# Function to show schedule conversion
show_schedule_conversion() {
    log "Schedule Conversion (Japan time to local time):"
    
    for i in "${!JAPAN_SCHEDULE_HOURS[@]}"; do
        local japan_hour=${JAPAN_SCHEDULE_HOURS[$i]}
        local japan_minute=${JAPAN_SCHEDULE_MINUTES[$i]}
        local local_time=$(convert_japan_to_local "$japan_hour" "$japan_minute")
        
        echo "Japan time ${japan_hour}:$(printf "%02d" ${japan_minute}) -> Local time ${local_time}"
    done
    echo
}

# Function to validate timezone configuration
validate_timezone_config() {
    log "Validating timezone configuration..."
    
    # Check if system timezone is set correctly
    CURRENT_TZ=$(date +%Z)
    
    if [[ "$CURRENT_TZ" == "JST" ]]; then
        success "System timezone is correctly set to Japan Standard Time"
        return 0
    else
        warning "System timezone is not set to Japan Standard Time"
        warning "Current timezone: $CURRENT_TZ"
        warning "This means the launchd schedule will run in local time, not Japan time"
        echo
        echo "To fix this, you have two options:"
        echo "1. Change system timezone to Japan: sudo systemsetup -settimezone Asia/Tokyo"
        echo "2. Adjust the launchd schedule to account for timezone difference"
        echo
        return 1
    fi
}

# Function to show timezone conversion examples
show_timezone_examples() {
    log "Timezone Conversion Examples:"
    
    # Show what 7 AM and 12:01 PM Japan time means in different timezones
    echo "7:00 AM Japan time equals:"
    echo "  - UTC: $(TZ=UTC date -d 'TZ=\"Asia/Tokyo\" 07:00' '+%H:%M')"
    echo "  - PST: $(TZ=America/Los_Angeles date -d 'TZ=\"Asia/Tokyo\" 07:00' '+%H:%M')"
    echo "  - EST: $(TZ=America/New_York date -d 'TZ=\"Asia/Tokyo\" 07:00' '+%H:%M')"
    echo "  - GMT: $(TZ=Europe/London date -d 'TZ=\"Asia/Tokyo\" 07:00' '+%H:%M')"
    echo
    
    echo "12:01 PM Japan time equals:"
    echo "  - UTC: $(TZ=UTC date -d 'TZ=\"Asia/Tokyo\" 12:01' '+%H:%M')"
    echo "  - PST: $(TZ=America/Los_Angeles date -d 'TZ=\"Asia/Tokyo\" 12:01' '+%H:%M')"
    echo "  - EST: $(TZ=America/New_York date -d 'TZ=\"Asia/Tokyo\" 12:01' '+%H:%M')"
    echo "  - GMT: $(TZ=Europe/London date -d 'TZ=\"Asia/Tokyo\" 12:01' '+%H:%M')"
    echo
}

# Function to create a timezone-aware test script
create_test_script() {
    local test_script="/Users/yashmehta/src/cc-auto-ping/test-timezone-schedule.sh"
    
    log "Creating timezone test script..."
    
    cat > "$test_script" << 'EOF'
#!/bin/bash
# Test script for timezone-aware scheduling

echo "=== Timezone Schedule Test ==="
echo "Execution time: $(date)"
echo "Execution time in Japan: $(TZ=Asia/Tokyo date)"
echo "Execution time in UTC: $(TZ=UTC date)"
echo "Weekday: $(date +%u) (1=Monday, 7=Sunday)"
echo "Should run on weekdays 1-6 only"
echo "=== End Test ==="
EOF
    
    chmod +x "$test_script"
    success "Test script created: $test_script"
}

# Function to show usage information
show_usage() {
    cat << EOF
Claude Code Timezone Configuration Helper

This script helps configure and manage timezone settings for Claude Code renewal
scheduled to run Monday-Saturday at 7:00 AM and 12:01 PM Japan time.

Commands:
  info      - Show current timezone information
  convert   - Show schedule conversion from Japan time to local time
  validate  - Validate timezone configuration
  examples  - Show timezone conversion examples
  test      - Create a test script for timezone verification
  help      - Show this help message

Usage: $0 [command]

The launchd service is configured to run at:
- Monday-Saturday at 7:00 AM Japan time
- Monday-Saturday at 12:01 PM Japan time

Note: If your system timezone is not set to Asia/Tokyo, the schedule will
run in local time. Use the 'convert' command to see what times this means
in your local timezone.
EOF
}

# Function to set system timezone (requires sudo)
set_japan_timezone() {
    log "Setting system timezone to Japan..."
    
    if command -v systemsetup >/dev/null 2>&1; then
        echo "This will change your system timezone to Asia/Tokyo"
        echo "Current timezone: $(date +%Z)"
        echo
        read -p "Are you sure you want to change the system timezone? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo systemsetup -settimezone Asia/Tokyo
            success "System timezone changed to Asia/Tokyo"
            log "New timezone: $(date +%Z)"
        else
            log "Timezone change cancelled"
        fi
    else
        error "systemsetup command not found. Cannot change timezone automatically."
        log "Please change timezone manually through System Preferences"
    fi
}

# Main execution
main() {
    case "${1:-info}" in
        "info")
            show_timezone_info
            calculate_next_executions
            ;;
        "convert")
            show_schedule_conversion
            ;;
        "validate")
            validate_timezone_config
            ;;
        "examples")
            show_timezone_examples
            ;;
        "test")
            create_test_script
            ;;
        "set-japan")
            set_japan_timezone
            ;;
        "help"|"--help"|"-h")
            show_usage
            ;;
        *)
            error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"