# SlapMyMac MCP Server

SlapMyMac exposes a local HTTP API on `http://localhost:7749` that lets AI tools, scripts, and automations interact with your Mac's slap detection system.

## Endpoints

### `GET /` — Help
Returns the list of available endpoints.

### `GET /status` — Current State
```bash
curl http://localhost:7749/status
```
```json
{
  "listening": true,
  "slapCount": 12,
  "lifetimeSlaps": 847,
  "soundMode": "pain",
  "sensitivity": 0.05,
  "lidAngle": 127.0,
  "lastImpact": {
    "severity": "major",
    "amplitude": 0.234,
    "detectorCount": 4
  }
}
```

### `GET /stats` — Slap Statistics
```bash
curl http://localhost:7749/stats
```
```json
{
  "totalSlaps": 847,
  "sessionSlaps": 12,
  "avgAmplitude": 0.089,
  "maxAmplitude": 0.453,
  "majorCount": 203,
  "mediumCount": 644,
  "slapsPerMinute": 2.4,
  "sessionDurationSeconds": 300,
  "favoriteMode": "pain"
}
```

### `GET /history` — Recent Slap Records
```bash
curl http://localhost:7749/history
```
Returns the last 50 slap records with timestamp, amplitude, severity, and detector count.

### `POST /trigger` — Trigger a Sound
```bash
curl -X POST http://localhost:7749/trigger -d '{"mode":"pain"}'
curl -X POST http://localhost:7749/trigger -d '{"mode":"halo"}'
curl -X POST http://localhost:7749/trigger -d '{"mode":"sexy"}'
```
Plays a random sound from the specified voice pack.

### `POST /mode` — Change Voice Pack
```bash
curl -X POST http://localhost:7749/mode -d '{"mode":"sexy"}'
```
Switches the active voice pack.

## Use with Claude Code

### Option 1: MCP Server Config (recommended)

Add to your `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "slapmymac": {
      "type": "url",
      "url": "http://localhost:7749/"
    }
  }
}
```

Then ask Claude: *"What's my slap count?"* or *"Play a halo sound on my Mac"*

### Option 2: Claude Code Hooks

Create a hook that triggers a slap sound on events. Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "curl -s -X POST http://localhost:7749/trigger -d '{\"mode\":\"pain\"}' > /dev/null 2>&1"
          }
        ]
      }
    ]
  }
}
```

This plays a slap sound every time Claude writes or edits a file.

### Option 3: Shell Scripts

```bash
# Play a sound when a build fails
npm run build || curl -X POST http://localhost:7749/trigger -d '{"mode":"halo"}'

# Play a sound on Slack notification (with a watcher)
while true; do
  # your slack check logic here
  curl -X POST http://localhost:7749/trigger -d '{"mode":"sexy"}'
  sleep 60
done

# Dashboard: check slap stats
watch -n 5 'curl -s http://localhost:7749/stats | python3 -m json.tool'
```

### Option 4: Shortcuts / Automator

Create a macOS Shortcut with a "Run Shell Script" action:
```bash
curl -X POST http://localhost:7749/trigger -d '{"mode":"pain"}'
```

Then trigger it from the menu bar, keyboard shortcut, or Siri.

## Requirements

- SlapMyMac must be running
- MCP server must be enabled in Preferences → General → MCP Server
- Port 7749 must not be used by another process
- Localhost only — not accessible from other machines
