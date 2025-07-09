#!/bin/bash

# Setup script for Claude auto-renewal cron job

SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/claude-auto-renew.sh"
CRON_LOG="$HOME/.claude-cron-setup.log"

echo "Setting up Claude auto-renewal cron job..."
echo "Script path: $SCRIPT_PATH"

# Check if script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "ERROR: claude-auto-renew.sh not found at $SCRIPT_PATH"
    exit 1
fi

# Create a temporary file for the new crontab
TEMP_CRON=$(mktemp)

# Get existing crontab (if any)
crontab -l 2>/dev/null > "$TEMP_CRON" || true

# Check if our cron job already exists
if grep -q "claude-auto-renew.sh" "$TEMP_CRON"; then
    echo "Claude auto-renewal cron job already exists. Updating..."
    # Remove existing entry
    grep -v "claude-auto-renew.sh" "$TEMP_CRON" > "${TEMP_CRON}.new"
    mv "${TEMP_CRON}.new" "$TEMP_CRON"
fi

# Add our cron job
# Run every 30 minutes to check if we need to renew
echo "*/30 * * * * $SCRIPT_PATH >> $HOME/.claude-cron.log 2>&1" >> "$TEMP_CRON"

# Install the new crontab
crontab "$TEMP_CRON"

# Clean up
rm "$TEMP_CRON"

echo "Cron job installed successfully!"
echo ""
echo "The script will run every 30 minutes to check if Claude needs renewal."
echo "Logs will be written to:"
echo "  - Main log: $HOME/.claude-auto-renew.log"
echo "  - Cron log: $HOME/.claude-cron.log"
echo ""
echo "To view the cron job:"
echo "  crontab -l | grep claude"
echo ""
echo "To remove the cron job:"
echo "  crontab -l | grep -v claude-auto-renew.sh | crontab -"
echo ""
echo "To test the script manually:"
echo "  $SCRIPT_PATH"