# Claude Auto-Renewal Schedule Configuration

## Updated Schedule: Monday-Saturday (6 days)

### Cron Expressions
- **7:00 AM**: `0 7 * * 1-6` (Monday through Saturday)
- **12:01 PM**: `1 12 * * 1-6` (Monday through Saturday)

### Schedule Breakdown
- **Days**: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday
- **Times per day**: 2 (7:00 AM and 12:01 PM)
- **Total weekly renewals**: 12 (6 days × 2 times)

### Cron Format Explanation
```
0 7 * * 1-6
│ │ │ │ │
│ │ │ │ └── Day of week (1-6: Monday-Saturday)
│ │ │ └──── Month (any)
│ │ └────── Day of month (any)
│ └──────── Hour (7 = 7:00 AM)
└────────── Minute (0 = :00)

1 12 * * 1-6
│ │  │ │ │
│ │  │ │ └── Day of week (1-6: Monday-Saturday)
│ │  │ └──── Month (any)
│ │  └────── Day of month (any)
│ └──────── Hour (12 = 12:00 PM)
└────────── Minute (1 = :01)
```

### Previous vs New Schedule

**Previous Schedule (Incorrect):**
- Monday and Saturday only
- 2 days × 2 times = 4 renewals per week

**New Schedule (Correct):**
- Monday through Saturday (6 days)
- 6 days × 2 times = 12 renewals per week

### Impact Analysis

**Frequency Increase:**
- **Previous**: 4 renewals/week
- **New**: 12 renewals/week  
- **Increase**: 3x more frequent (300% increase)

**Resource Implications:**
- More frequent Claude CLI executions
- Higher log file growth rate
- More cron job activity
- Need for log rotation consideration

**Benefits:**
- More consistent Claude Code availability
- Better coverage throughout the work week
- Reduced risk of service gaps
- More predictable renewal timing

### Log Management Recommendations

With 12 renewals per week instead of 4, consider:

1. **Log Rotation**: Set up logrotate for `~/.claude-cron.log`
2. **Monitoring**: Check log sizes more frequently
3. **Archival**: Implement log archival strategy
4. **Alerting**: Monitor for failed renewals across more frequent runs

### Testing the Schedule

```bash
# Test cron expressions
echo "0 7 * * 1-6" | crontab -
echo "1 12 * * 1-6" | crontab -

# View current crontab
crontab -l

# Test next run times
date
# Use online cron calculator to verify next execution times
```

### Recommended Next Steps

1. Update all documentation with new schedule
2. Test cron expressions in development
3. Monitor initial week for proper execution
4. Set up log rotation for higher frequency
5. Update monitoring/alerting thresholds