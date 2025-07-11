# CC AutoRenew

Automatically maintains Claude Code availability through intelligent sleep-aware scheduling.

## Quick Start

```bash
git clone https://github.com/yourusername/cc-auto-ping.git && cd cc-auto-ping
chmod +x scripts/*.sh setup/*.sh utils/*.sh tests/*.sh
./scripts/claude-sleep-aware-manager.sh install
```

## Key Features

- **Sleep-Aware Scheduling** - Automatically wakes your Mac to renew Claude sessions
- **Japan Timezone Optimized** - Monday-Saturday at 7:00 AM and 12:01 PM JST
- **Smart Monitoring** - Integrates with ccusage for accurate timing
- **Power Management** - Uses macOS pmset for wake scheduling
- **Native Integration** - Runs as launchd service for reliability

## Prerequisites

- macOS (for launchd and pmset)
- [Claude CLI](https://claude.ai/claude-code) installed and authenticated
- (Optional) [ccusage](https://github.com/ryoppippi/ccusage) for precise timing

## Usage

```bash
# Check status
./scripts/claude-sleep-aware-manager.sh status

# View logs
./scripts/claude-sleep-aware-manager.sh logs

# Test renewal
./scripts/claude-sleep-aware-manager.sh test

# Uninstall
./scripts/claude-sleep-aware-manager.sh uninstall
```

## Schedule

**Monday-Saturday**: 7:00 AM and 12:01 PM JST (12 renewals/week)
**Sunday**: Rest day

The system automatically wakes your Mac 2 minutes before renewal times.

## Logs

- `~/.claude-auto-renew.log` - Main activity log
- `~/.claude-last-activity` - Last renewal timestamp

## Troubleshooting

```bash
# Check service status
./scripts/claude-sleep-aware-manager.sh status

# View recent logs
tail -50 ~/.claude-auto-renew.log

# Verify wake schedule
pmset -g sched
```

## Project Structure

```
cc-auto-ping/
├── scripts/          # Core functionality
├── setup/            # Installation scripts  
├── config/           # launchd configuration
├── utils/            # Helper scripts
└── tests/            # Test scripts
```

## License

MIT License - see [LICENSE](LICENSE) file for details.