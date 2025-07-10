#!/bin/bash

# Installation script for Claude Code sleep-aware launchd configuration
# This script installs the launchd plist for automatic Claude renewal

set -euo pipefail

# Configuration
PLIST_NAME="com.claude.autorenew.sleepaware.plist"
PLIST_SOURCE="/Users/yashmehta/src/cc-auto-ping/${PLIST_NAME}"
PLIST_DESTINATION="/Users/yashmehta/Library/LaunchAgents/${PLIST_NAME}"
RENEWAL_SCRIPT="/Users/yashmehta/src/cc-auto-ping/claude-auto-renew-sleepaware.sh"
LOG_DIR="/Users/yashmehta/src/cc-auto-ping/logs"

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    error "This script should not be run as root. Run as your regular user."
    exit 1
fi

# Validation functions
validate_files() {
    log "Validating required files..."
    
    if [[ ! -f "$PLIST_SOURCE" ]]; then
        error "Plist file not found: $PLIST_SOURCE"
        exit 1
    fi
    
    if [[ ! -f "$RENEWAL_SCRIPT" ]]; then
        error "Renewal script not found: $RENEWAL_SCRIPT"
        log "Creating placeholder renewal script..."
        cat > "$RENEWAL_SCRIPT" << 'EOF'
#!/bin/bash
# Placeholder Claude renewal script
# This script will be replaced with the actual renewal logic

echo "$(date): Claude renewal script executed" >> /Users/yashmehta/src/cc-auto-ping/logs/claude-autorenew-sleepaware.log
echo "Renewal script placeholder - replace with actual implementation"
EOF
        chmod +x "$RENEWAL_SCRIPT"
        warning "Created placeholder renewal script. Please replace with actual implementation."
    fi
    
    success "File validation completed"
}

setup_directories() {
    log "Setting up directories..."
    
    # Create LaunchAgents directory if it doesn't exist
    mkdir -p "/Users/yashmehta/Library/LaunchAgents"
    
    # Create logs directory if it doesn't exist
    mkdir -p "$LOG_DIR"
    
    success "Directories created"
}

install_plist() {
    log "Installing launchd plist..."
    
    # Copy plist to LaunchAgents directory
    cp "$PLIST_SOURCE" "$PLIST_DESTINATION"
    
    # Set proper permissions
    chmod 644 "$PLIST_DESTINATION"
    
    success "Plist installed at: $PLIST_DESTINATION"
}

load_service() {
    log "Loading launchd service..."
    
    # Unload if already loaded (ignore errors)
    launchctl unload "$PLIST_DESTINATION" 2>/dev/null || true
    
    # Load the service
    if launchctl load "$PLIST_DESTINATION"; then
        success "Service loaded successfully"
    else
        error "Failed to load service"
        exit 1
    fi
}

verify_installation() {
    log "Verifying installation..."
    
    # Check if service is loaded
    if launchctl list | grep -q "com.claude.autorenew.sleepaware"; then
        success "Service is loaded and running"
    else
        error "Service is not loaded"
        exit 1
    fi
    
    # Show next execution times
    log "Service status:"
    launchctl list com.claude.autorenew.sleepaware
}

configure_timezone() {
    log "Configuring timezone settings..."
    
    # Check current timezone
    CURRENT_TZ=$(date +%Z)
    log "Current system timezone: $CURRENT_TZ"
    
    # Check if we need to set Japan timezone
    if [[ "$CURRENT_TZ" != "JST" ]]; then
        warning "System timezone is not set to Japan Standard Time (JST)"
        warning "The schedule will run in local time. Consider setting system timezone to Asia/Tokyo"
        warning "You can change it with: sudo systemsetup -settimezone Asia/Tokyo"
    else
        success "System timezone is correctly set to Japan Standard Time"
    fi
}

show_usage() {
    cat << EOF
Claude Code Sleep-Aware Launchd Installation

This script will install a launchd service that runs Claude Code renewal:
- Schedule: Monday-Saturday at 7:00 AM and 12:01 PM Japan time
- Sleep-aware execution using launchd
- Proper logging and error handling
- Timezone support for Japan

Files that will be created/modified:
- $PLIST_DESTINATION
- $LOG_DIR/claude-autorenew-sleepaware.log
- $LOG_DIR/claude-autorenew-sleepaware-error.log

The service will reference: $RENEWAL_SCRIPT
EOF
}

uninstall_service() {
    log "Uninstalling launchd service..."
    
    # Unload the service
    if launchctl unload "$PLIST_DESTINATION" 2>/dev/null; then
        success "Service unloaded"
    else
        warning "Service was not loaded"
    fi
    
    # Remove plist file
    if [[ -f "$PLIST_DESTINATION" ]]; then
        rm "$PLIST_DESTINATION"
        success "Plist file removed"
    else
        warning "Plist file not found"
    fi
    
    success "Service uninstalled"
}

# Main execution
main() {
    case "${1:-install}" in
        "install")
            log "Starting Claude Code sleep-aware launchd installation..."
            show_usage
            echo
            read -p "Do you want to continue with the installation? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "Installation cancelled"
                exit 0
            fi
            
            validate_files
            setup_directories
            install_plist
            configure_timezone
            load_service
            verify_installation
            
            success "Installation completed successfully!"
            log "The service will run Claude Code renewal Monday-Saturday at 7:00 AM and 12:01 PM Japan time"
            log "Logs will be written to: $LOG_DIR/"
            ;;
        "uninstall")
            log "Uninstalling Claude Code sleep-aware launchd service..."
            uninstall_service
            ;;
        "status")
            log "Checking service status..."
            if launchctl list | grep -q "com.claude.autorenew.sleepaware"; then
                success "Service is loaded"
                launchctl list com.claude.autorenew.sleepaware
            else
                warning "Service is not loaded"
            fi
            ;;
        "logs")
            log "Showing recent logs..."
            if [[ -f "$LOG_DIR/claude-autorenew-sleepaware.log" ]]; then
                tail -20 "$LOG_DIR/claude-autorenew-sleepaware.log"
            else
                warning "No log file found"
            fi
            ;;
        "help"|"--help"|"-h")
            show_usage
            echo
            echo "Usage: $0 [install|uninstall|status|logs|help]"
            echo
            echo "Commands:"
            echo "  install   - Install the launchd service (default)"
            echo "  uninstall - Remove the launchd service"
            echo "  status    - Check if the service is running"
            echo "  logs      - Show recent log entries"
            echo "  help      - Show this help message"
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