#!/bin/bash

# Validate Schedule Script
# Tests and validates the new Monday-Saturday cron schedule

echo "=== Claude Auto-Renewal Schedule Validator ==="
echo ""

# Cron expressions
MORNING_CRON="0 7 * * 1-6"
AFTERNOON_CRON="1 12 * * 1-6"

echo "Testing cron expressions:"
echo "Morning (7:00 AM): $MORNING_CRON"
echo "Afternoon (12:01 PM): $AFTERNOON_CRON"
echo ""

# Function to validate cron expression format
validate_cron() {
    local cron_expr="$1"
    local desc="$2"
    
    # Basic format validation (5 fields)
    field_count=$(echo "$cron_expr" | wc -w)
    if [ "$field_count" -eq 5 ]; then
        echo "✓ $desc: Valid format (5 fields)"
    else
        echo "✗ $desc: Invalid format ($field_count fields, expected 5)"
        return 1
    fi
    
    # Parse fields
    read -r minute hour day month dow <<< "$cron_expr"
    
    # Validate minute (0-59)
    if [[ "$minute" =~ ^[0-9]+$ ]] && [ "$minute" -ge 0 ] && [ "$minute" -le 59 ]; then
        echo "  ✓ Minute: $minute (valid)"
    else
        echo "  ✗ Minute: $minute (invalid)"
        return 1
    fi
    
    # Validate hour (0-23)
    if [[ "$hour" =~ ^[0-9]+$ ]] && [ "$hour" -ge 0 ] && [ "$hour" -le 23 ]; then
        echo "  ✓ Hour: $hour (valid)"
    else
        echo "  ✗ Hour: $hour (invalid)"
        return 1
    fi
    
    # Validate day of week (1-6 for Monday-Saturday)
    if [ "$dow" = "1-6" ]; then
        echo "  ✓ Day of week: $dow (Monday-Saturday)"
    else
        echo "  ✗ Day of week: $dow (should be 1-6)"
        return 1
    fi
    
    return 0
}

# Validate both cron expressions
echo "Validating cron expressions:"
echo ""

validate_cron "$MORNING_CRON" "Morning schedule"
morning_valid=$?
echo ""

validate_cron "$AFTERNOON_CRON" "Afternoon schedule"
afternoon_valid=$?
echo ""

# Calculate weekly frequency
echo "Schedule Analysis:"
echo "- Days: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday (6 days)"
echo "- Times per day: 2 (7:00 AM and 12:01 PM)"
echo "- Total weekly renewals: 12 (6 × 2)"
echo "- Compared to previous: 300% increase (4 → 12 renewals/week)"
echo ""

# Show next execution times (approximate)
echo "Next execution times (this week):"
current_day=$(date +%u)  # 1=Monday, 7=Sunday
current_hour=$(date +%H)
current_minute=$(date +%M)

for day in {1..6}; do
    case $day in
        1) day_name="Monday" ;;
        2) day_name="Tuesday" ;;
        3) day_name="Wednesday" ;;
        4) day_name="Thursday" ;;
        5) day_name="Friday" ;;
        6) day_name="Saturday" ;;
    esac
    
    echo "  $day_name: 7:00 AM and 12:01 PM"
done
echo ""

# Resource impact analysis
echo "Resource Impact Analysis:"
echo "- Log growth rate: 3x increase expected"
echo "- CPU usage: Minimal (brief Claude CLI execution)"
echo "- Network usage: Light (authentication and session start)"
echo "- Storage: Monitor ~/.claude-cron.log size"
echo ""

# Recommendations
echo "Recommendations:"
echo "1. Set up log rotation for ~/.claude-cron.log"
echo "2. Monitor first week for proper execution"
echo "3. Consider log archival strategy"
echo "4. Update monitoring alerts for higher frequency"
echo ""

# Test cron syntax (if supported)
if command -v crontab &> /dev/null; then
    echo "Testing cron syntax (dry run):"
    
    # Create temporary crontab to test syntax
    temp_cron=$(mktemp)
    echo "$MORNING_CRON /bin/echo 'Morning renewal test'" > "$temp_cron"
    echo "$AFTERNOON_CRON /bin/echo 'Afternoon renewal test'" >> "$temp_cron"
    
    if crontab -T "$temp_cron" 2>/dev/null; then
        echo "✓ Cron syntax validation passed"
    else
        echo "✗ Cron syntax validation failed"
    fi
    
    rm "$temp_cron"
else
    echo "⚠ crontab command not available for syntax testing"
fi

echo ""
echo "=== Validation Complete ==="

# Exit with error if any validation failed
if [ $morning_valid -ne 0 ] || [ $afternoon_valid -ne 0 ]; then
    echo "⚠ Some validations failed. Please review the cron expressions."
    exit 1
else
    echo "✓ All validations passed. Schedule is ready for implementation."
    exit 0
fi