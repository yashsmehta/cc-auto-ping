#!/bin/bash

# Enhanced Claude Auto-Renewal Script with Sleep Management and Power Management
# Features:
# - Sleep detection and recovery
# - Caffeinate integration to prevent sleep during renewal
# - Enhanced logging for Japan timezone
# - Lock file management to prevent overlapping executions
# - Missed renewal detection and recovery
# - Integration with ccusage for accurate timing

# Configuration
LOG_FILE="$HOME/.claude-auto-renew.log"
LAST_ACTIVITY_FILE="$HOME/.claude-last-activity"
LAST_WAKE_FILE="$HOME/.claude-last-wake"
LOCK_FILE="$HOME/.claude-auto-renew.lock"
MISSED_RENEWAL_FILE="$HOME/.claude-missed-renewal"

# Timezone settings for Japan
export TZ="Asia/Tokyo"

# Function to log messages with Japan timezone
log_message() {
    local timestamp=$(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function to create lock file
create_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local lock_pid=$(cat "$LOCK_FILE")
        if kill -0 "$lock_pid" 2>/dev/null; then
            log_message "Another instance is running (PID: $lock_pid), exiting"
            exit 1
        else
            log_message "Removing stale lock file"
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    log_message "Lock file created with PID: $$"
}

# Function to remove lock file
remove_lock() {
    rm -f "$LOCK_FILE"
    log_message "Lock file removed"
}

# Function to detect if system just woke from sleep
detect_wake_from_sleep() {
    local current_time=$(date +%s)
    local last_wake_time=0
    
    if [ -f "$LAST_WAKE_FILE" ]; then
        last_wake_time=$(cat "$LAST_WAKE_FILE")
    fi
    
    # Check for power management events using pmset
    if command -v pmset &> /dev/null; then
        local sleep_events=$(pmset -g log | grep -E "(Sleep|Wake|DarkWake)" | tail -10)
        local last_wake=$(echo "$sleep_events" | grep -E "Wake|DarkWake" | tail -1)
        
        if [ -n "$last_wake" ]; then
            local wake_timestamp=$(echo "$last_wake" | awk '{print $1 " " $2}')
            local wake_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$wake_timestamp" "+%s" 2>/dev/null || echo "0")
            
            # If wake event is recent (within last 10 minutes) and newer than last recorded wake
            if [ "$wake_epoch" -gt "$last_wake_time" ] && [ $((current_time - wake_epoch)) -lt 600 ]; then
                log_message "System wake detected at: $wake_timestamp"
                echo "$wake_epoch" > "$LAST_WAKE_FILE"
                return 0
            fi
        fi
    fi
    
    # Fallback: Check if significant time gap since last activity (indicating possible sleep)
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        local last_activity=$(cat "$LAST_ACTIVITY_FILE")
        local time_gap=$((current_time - last_activity))
        
        # If more than 2 hours gap, likely the system slept
        if [ $time_gap -gt 7200 ]; then
            log_message "Large time gap detected ($((time_gap / 60)) minutes), possible sleep recovery"
            echo "$current_time" > "$LAST_WAKE_FILE"
            return 0
        fi
    fi
    
    return 1
}

# Function to prevent system sleep using caffeinate
prevent_sleep_start() {
    if command -v caffeinate &> /dev/null; then
        # Start caffeinate to prevent sleep during renewal
        caffeinate -d -i -m -u -t 300 &  # 5 minutes timeout
        local caffeinate_pid=$!
        echo "$caffeinate_pid" > "$HOME/.claude-caffeinate.pid"
        log_message "Started caffeinate to prevent sleep (PID: $caffeinate_pid)"
        return 0
    else
        log_message "WARNING: caffeinate not available, system may sleep during renewal"
        return 1
    fi
}

# Function to stop caffeinate
prevent_sleep_stop() {
    if [ -f "$HOME/.claude-caffeinate.pid" ]; then
        local caffeinate_pid=$(cat "$HOME/.claude-caffeinate.pid")
        if kill -0 "$caffeinate_pid" 2>/dev/null; then
            kill "$caffeinate_pid" 2>/dev/null
            log_message "Stopped caffeinate (PID: $caffeinate_pid)"
        fi
        rm -f "$HOME/.claude-caffeinate.pid"
    fi
}

# Function to get ccusage command
get_ccusage_cmd() {
    if command -v ccusage &> /dev/null; then
        echo "ccusage"
    elif command -v bunx &> /dev/null; then
        echo "bunx ccusage"
    elif command -v npx &> /dev/null; then
        echo "npx ccusage@latest"
    else
        return 1
    fi
}

# Function to parse time remaining from ccusage output
parse_time_remaining() {
    local ccusage_cmd=$(get_ccusage_cmd)
    if [ $? -ne 0 ]; then
        log_message "WARNING: ccusage not available, skipping time check"
        return 1
    fi
    
    log_message "Checking ccusage for time remaining..."
    
    # Try to get blocks info with timeout using background process
    local output=""
    local temp_file=$(mktemp)
    
    # Run ccusage in background with timeout
    ($ccusage_cmd blocks 2>/dev/null | grep -i "time remaining" | head -1 > "$temp_file") &
    local ccusage_pid=$!
    
    # Wait up to 10 seconds for ccusage to complete
    local count=0
    while kill -0 "$ccusage_pid" 2>/dev/null && [ $count -lt 10 ]; do
        sleep 1
        ((count++))
    done
    
    # Kill ccusage if still running
    if kill -0 "$ccusage_pid" 2>/dev/null; then
        kill "$ccusage_pid" 2>/dev/null
        wait "$ccusage_pid" 2>/dev/null
        log_message "WARNING: ccusage timed out, skipping time check"
        rm -f "$temp_file"
        return 1
    fi
    
    # Get the output
    if [ -f "$temp_file" ]; then
        output=$(cat "$temp_file")
        rm -f "$temp_file"
    fi
    
    if [ -z "$output" ]; then
        log_message "WARNING: ccusage did not return time remaining info"
        return 1
    fi
    
    # Extract hours and minutes from various formats
    local hours=0
    local minutes=0
    
    if [[ "$output" =~ ([0-9]+)h[[:space:]]*([0-9]+)m ]]; then
        hours=${BASH_REMATCH[1]}
        minutes=${BASH_REMATCH[2]}
    elif [[ "$output" =~ ([0-9]+):[0-9]{2}:[0-9]{2} ]]; then
        hours=${BASH_REMATCH[1]}
        minutes=$(echo "$output" | sed -E 's/.*([0-9]+):([0-9]{2}):[0-9]{2}.*/\2/')
    elif [[ "$output" =~ ([0-9]+)m ]]; then
        minutes=${BASH_REMATCH[1]}
    fi
    
    # Convert to total minutes
    local total_minutes=$((hours * 60 + minutes))
    echo "$total_minutes"
}

# Function to check for missed renewals
check_missed_renewals() {
    local current_time=$(date +%s)
    
    # Check if we have a missed renewal marker
    if [ -f "$MISSED_RENEWAL_FILE" ]; then
        local missed_time=$(cat "$MISSED_RENEWAL_FILE")
        local time_since_missed=$((current_time - missed_time))
        
        # If missed renewal is older than 6 hours, clean it up
        if [ $time_since_missed -gt 21600 ]; then
            rm -f "$MISSED_RENEWAL_FILE"
            log_message "Cleaned up old missed renewal marker"
        else
            log_message "Missed renewal detected from $(TZ=Asia/Tokyo date -r $missed_time '+%Y-%m-%d %H:%M:%S JST')"
            return 0
        fi
    fi
    
    # Check if we're overdue for renewal based on last activity
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        local last_activity=$(cat "$LAST_ACTIVITY_FILE")
        local time_since_activity=$((current_time - last_activity))
        
        # If more than 6 hours since last activity, consider it a missed renewal
        if [ $time_since_activity -gt 21600 ]; then
            log_message "Detected missed renewal: $((time_since_activity / 3600)) hours since last activity"
            echo "$current_time" > "$MISSED_RENEWAL_FILE"
            return 0
        fi
    fi
    
    return 1
}

# Function to check if we should start a session
should_start_session() {
    local force_renewal=false
    
    # Check for system wake
    if detect_wake_from_sleep; then
        log_message "System wake detected, checking for missed renewals"
        force_renewal=true
    fi
    
    # Check for missed renewals
    if check_missed_renewals; then
        log_message "Missed renewal detected, forcing renewal"
        force_renewal=true
    fi
    
    # First try to get accurate time from ccusage
    local minutes_remaining=$(parse_time_remaining)
    
    if [ -n "$minutes_remaining" ] && [ "$minutes_remaining" -gt 0 ]; then
        log_message "Time remaining in current block: $minutes_remaining minutes"
        
        # Force renewal if we detected wake or missed renewal
        if [ "$force_renewal" = true ]; then
            log_message "Forcing renewal due to wake/missed renewal detection"
            return 0
        fi
        
        # Start session if less than 5 minutes remaining
        if [ "$minutes_remaining" -lt 5 ]; then
            log_message "Reset window approaching, preparing to start session"
            return 0
        else
            log_message "No renewal needed, $minutes_remaining minutes remaining"
            return 1
        fi
    else
        log_message "Could not get time remaining from ccusage, using fallback logic"
    fi
    
    # Force renewal if detected
    if [ "$force_renewal" = true ]; then
        log_message "Forcing renewal due to wake/missed renewal detection"
        return 0
    fi
    
    # Fallback: Check last activity time
    if [ -f "$LAST_ACTIVITY_FILE" ]; then
        local last_activity=$(cat "$LAST_ACTIVITY_FILE")
        local current_time=$(date +%s)
        local time_diff=$((current_time - last_activity))
        
        # If more than 5 hours (18000 seconds) have passed
        if [ $time_diff -gt 18000 ]; then
            log_message "More than 5 hours since last activity, starting session"
            return 0
        else
            local remaining=$((18000 - time_diff))
            log_message "Fallback check: $((remaining / 60)) minutes until 5-hour mark"
            
            # Start if within 5 minutes of the 5-hour mark
            if [ $remaining -lt 300 ]; then
                return 0
            fi
        fi
    else
        # No activity file exists, safe to start
        log_message "No previous activity found, starting session"
        return 0
    fi
    
    return 1
}

# Function to start Claude session with enhanced error handling
start_claude_session() {
    log_message "Attempting to start Claude session"
    
    # Ensure Claude CLI path is available
    export PATH="/Users/yashmehta/.claude/local:$PATH"
    
    # Check if claude command exists
    if ! command -v claude &> /dev/null; then
        log_message "ERROR: claude command not found at $(which claude 2>/dev/null || echo 'not found')"
        log_message "PATH: $PATH"
        return 1
    fi
    
    log_message "Using Claude CLI at: $(which claude)"
    
    # Start caffeinate to prevent sleep
    prevent_sleep_start
    
    # Check if we need to login first
    local login_needed=false
    if ! claude whoami &>/dev/null; then
        log_message "Claude login required"
        login_needed=true
    fi
    
    local result=1
    local max_attempts=3
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        log_message "Starting Claude session attempt $attempt/$max_attempts"
        
        if command -v expect &> /dev/null; then
            # Create expect script for this attempt
            cat > /tmp/claude_auto_start.exp << EOF
#!/usr/bin/expect -f
set timeout 30

if {"$login_needed" == "true"} {
    spawn claude login
    expect {
        "Press Enter" {
            send "\r"
            exp_continue
        }
        "Successfully logged in" {
            # Continue to main session
        }
        timeout {
            puts "Login timeout"
            exit 1
        }
    }
}

spawn claude
expect {
    ">" {
        send "hi\r"
        expect {
            ">" {
                send "exit\r"
                expect eof
            }
            timeout {
                puts "Response timeout"
                exit 1
            }
        }
    }
    "Please login" {
        puts "Login required"
        exit 2
    }
    timeout {
        puts "Session timeout"
        exit 1
    }
}
EOF
            
            chmod +x /tmp/claude_auto_start.exp
            /tmp/claude_auto_start.exp >> "$LOG_FILE" 2>&1
            result=$?
            rm -f /tmp/claude_auto_start.exp
            
            if [ $result -eq 2 ]; then
                log_message "Login required, retrying with login"
                login_needed=true
                continue
            elif [ $result -eq 0 ]; then
                log_message "Successfully started Claude session"
                break
            else
                log_message "Attempt $attempt failed with exit code $result"
            fi
        else
            # Fallback method without expect
            log_message "Using fallback method (expect not available)"
            if [ "$login_needed" = true ]; then
                log_message "Manual login required - please run 'claude login'"
                result=1
                break
            fi
            
            # Simple timeout-based approach with permission bypass
            (echo "hi" | claude --dangerously-skip-permissions --print) >> "$LOG_FILE" 2>&1 &
            local claude_pid=$!
            
            # Wait up to 30 seconds
            local count=0
            while kill -0 "$claude_pid" 2>/dev/null && [ $count -lt 30 ]; do
                sleep 1
                ((count++))
            done
            
            # Kill if still running
            if kill -0 "$claude_pid" 2>/dev/null; then
                kill "$claude_pid" 2>/dev/null
                wait "$claude_pid" 2>/dev/null
                result=124  # timeout
            else
                wait "$claude_pid"
                result=$?
            fi
            
            if [ $result -eq 0 ]; then
                log_message "Successfully started Claude session (fallback method)"
                break
            fi
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            log_message "Retrying in 10 seconds..."
            sleep 10
        fi
    done
    
    prevent_sleep_stop
    
    if [ $result -eq 0 ]; then
        local current_time=$(date +%s)
        echo "$current_time" > "$LAST_ACTIVITY_FILE"
        rm -f "$MISSED_RENEWAL_FILE"  # Clear missed renewal marker
        log_message "Session renewal successful, activity timestamp updated"
        return 0
    else
        log_message "ERROR: Failed to start Claude session after $max_attempts attempts"
        # Mark as missed renewal for future recovery
        echo "$(date +%s)" > "$MISSED_RENEWAL_FILE"
        return 1
    fi
}

# Function to cleanup on exit
cleanup() {
    log_message "Cleaning up..."
    prevent_sleep_stop
    remove_lock
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# Main execution
main() {
    log_message "=== Starting Enhanced Claude Auto-Renewal Check ==="
    
    # Create lock file
    create_lock
    
    # Check ccusage availability
    if ! get_ccusage_cmd &> /dev/null; then
        log_message "WARNING: ccusage not found. Install with: npm install -g ccusage"
        log_message "Falling back to time-based checking"
    fi
    
    # Log system information
    log_message "System: $(uname -s) $(uname -r)"
    log_message "Timezone: $(TZ=Asia/Tokyo date '+%Z %z')"
    log_message "Current time: $(TZ=Asia/Tokyo date '+%Y-%m-%d %H:%M:%S JST')"
    
    # Check if we should start a session
    if should_start_session; then
        # Wait a moment to ensure we're in the renewal window
        log_message "Waiting 60 seconds to ensure renewal window..."
        sleep 60
        
        # Start the session
        if start_claude_session; then
            log_message "Session renewal completed successfully"
        else
            log_message "Session renewal failed"
        fi
    else
        log_message "Not time for renewal yet"
    fi
    
    log_message "=== Check complete ==="
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for test mode
    if [ "$1" = "--test" ] || [ "$1" = "--force" ]; then
        log_message "Running in test/force mode - skipping time checks"
        
        # Create lock file manually for test
        local lock_file="$LOCK_FILE"
        if [ -f "$lock_file" ]; then
            local existing_pid=$(cat "$lock_file")
            if kill -0 "$existing_pid" 2>/dev/null; then
                log_message "ERROR: Another instance is already running (PID: $existing_pid)"
                exit 1
            else
                log_message "Removing stale lock file"
                rm -f "$lock_file"
            fi
        fi
        
        echo $$ > "$lock_file"
        log_message "Lock file created with PID: $$"
        
        # Skip time checks and force renewal
        log_message "Forcing Claude session renewal for testing"
        if start_claude_session; then
            log_message "Test renewal completed successfully"
            exit_code=0
        else
            log_message "Test renewal failed"
            exit_code=1
        fi
        
        # Clean up
        log_message "Cleaning up..."
        rm -f "$lock_file"
        log_message "Lock file removed"
        
        exit $exit_code
    else
        main
    fi
fi