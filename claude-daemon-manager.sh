#!/bin/bash

# Claude Daemon Manager - Start, stop, and manage the auto-renewal daemon

DAEMON_SCRIPT="$(cd "$(dirname "$0")" && pwd)/claude-auto-renew-daemon.sh"
PID_FILE="$HOME/.claude-auto-renew-daemon.pid"
LOG_FILE="$HOME/.claude-auto-renew-daemon.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

start_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            print_error "Daemon is already running with PID $PID"
            return 1
        fi
    fi
    
    print_status "Starting Claude auto-renewal daemon..."
    nohup "$DAEMON_SCRIPT" > /dev/null 2>&1 &
    
    sleep 2
    
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            print_status "Daemon started successfully with PID $PID"
            print_status "Logs: $LOG_FILE"
            return 0
        fi
    fi
    
    print_error "Failed to start daemon"
    return 1
}

stop_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        print_warning "Daemon is not running (no PID file found)"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if ! kill -0 "$PID" 2>/dev/null; then
        print_warning "Daemon is not running (process $PID not found)"
        rm -f "$PID_FILE"
        return 1
    fi
    
    print_status "Stopping daemon with PID $PID..."
    kill "$PID"
    
    # Wait for graceful shutdown
    for i in {1..10}; do
        if ! kill -0 "$PID" 2>/dev/null; then
            print_status "Daemon stopped successfully"
            rm -f "$PID_FILE"
            return 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    print_warning "Daemon did not stop gracefully, forcing..."
    kill -9 "$PID" 2>/dev/null
    rm -f "$PID_FILE"
    print_status "Daemon stopped"
}

status_daemon() {
    if [ ! -f "$PID_FILE" ]; then
        print_status "Daemon is not running"
        return 1
    fi
    
    PID=$(cat "$PID_FILE")
    
    if kill -0 "$PID" 2>/dev/null; then
        print_status "Daemon is running with PID $PID"
        
        # Show recent activity
        if [ -f "$LOG_FILE" ]; then
            echo ""
            print_status "Recent activity:"
            tail -5 "$LOG_FILE" | sed 's/^/  /'
        fi
        
        # Show next renewal estimate
        if [ -f "$HOME/.claude-last-activity" ]; then
            last_activity=$(cat "$HOME/.claude-last-activity")
            current_time=$(date +%s)
            time_diff=$((current_time - last_activity))
            remaining=$((18000 - time_diff))
            
            if [ $remaining -gt 0 ]; then
                hours=$((remaining / 3600))
                minutes=$(((remaining % 3600) / 60))
                echo ""
                print_status "Estimated time until next renewal: ${hours}h ${minutes}m"
            fi
        fi
        
        return 0
    else
        print_warning "Daemon is not running (process $PID not found)"
        rm -f "$PID_FILE"
        return 1
    fi
}

restart_daemon() {
    print_status "Restarting daemon..."
    stop_daemon
    sleep 2
    start_daemon
}

show_logs() {
    if [ ! -f "$LOG_FILE" ]; then
        print_error "No log file found"
        return 1
    fi
    
    if [ "$1" = "-f" ]; then
        tail -f "$LOG_FILE"
    else
        tail -50 "$LOG_FILE"
    fi
}

# Main command handling
case "$1" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        restart_daemon
        ;;
    status)
        status_daemon
        ;;
    logs)
        show_logs "$2"
        ;;
    *)
        echo "Claude Auto-Renewal Daemon Manager"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "Commands:"
        echo "  start    - Start the daemon"
        echo "  stop     - Stop the daemon"
        echo "  restart  - Restart the daemon"
        echo "  status   - Show daemon status"
        echo "  logs     - Show recent logs (use 'logs -f' to follow)"
        echo ""
        echo "The daemon will:"
        echo "  - Monitor your Claude usage blocks"
        echo "  - Automatically start a session when renewal is needed"
        echo "  - Prevent gaps in your 5-hour usage windows"
        ;;
esac