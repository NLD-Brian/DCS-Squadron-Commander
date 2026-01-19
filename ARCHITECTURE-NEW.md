# DCS Squadron Commander - Clean Architecture (LotATC Style)

## Simple 2-Tier Design

```
┌────────────────────────────────────────┐
│  DCS-SC-hook.lua                       │
│  Loaded by DCS at startup              │
│  └─> Loads DCS-SC-Main-new.lua         │
└────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│  DCS-SC-Main-new.lua (Server Hook)    │
│  • Minimal code                        │
│  • Only loads mission script on start  │
└────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│  DCS-SC-MissionScript-new.lua          │
│  • Runs in mission environment         │
│  • Has full world/unit access          │
│  • Has networking (desanitized)        │
│  • Sends data DIRECTLY to .NET via UDP │
└────────────────────────────────────────┘
                 │
                 ▼
┌────────────────────────────────────────┐
│  DCS-SC-Bridge.exe (.NET)              │
│  • Listens on UDP 10308                │
│  • Receives all data                   │
└────────────────────────────────────────┘
```

## Required: Desanitize MissionScripting.lua

Edit `C:\Program Files\Eagle Dynamics\DCS World\Scripts\MissionScripting.lua`

Comment out these lines:
```lua
-- require = nil
-- loadlib = nil
-- package = nil
-- io = nil
-- os = nil
```

This allows the mission script to:
- Load LuaSocket
- Use UDP networking
- Access file system

## Data Flow

### Telemetry (Every 1 second)
```
Unit data → DCSSC.getUnitData() → JSON → UDP → .NET
```

### Events (Real-time)
```
DCS Event → DCSSC.eventHandler → JSON → UDP → .NET
```

## Configuration

In `DCS-SC-MissionScript-new.lua`:
```lua
DCSSC.config = {
    netHost = "127.0.0.1",     -- .NET application IP
    netPort = 10308,            -- .NET listening port
    updateInterval = 1,         -- Telemetry frequency
    trackAI = false             -- Track AI aircraft
}
```

## Message Format

All messages are JSON with `eventType`:

### Telemetry
```json
{
  "eventType": "telemetry",
  "unitName": "Pilot #001",
  "playerName": "JohnDoe",
  "latitude": 43.123,
  "longitude": 43.234,
  "altitude": 5000,
  "heading": 180,
  "speed": 250,
  "timestamp": 12345.67
}
```

### Events
```json
{
  "eventType": "takeoff|landing|crash|...",
  "playerName": "JohnDoe",
  "unitName": "Pilot #001",
  "timestamp": 12345.67
}
```

## Benefits of This Approach

✅ **Simple** - One script does everything
✅ **Fast** - Direct UDP, no intermediary
✅ **Clean** - No complex callbacks between environments
✅ **Proven** - Same pattern as LotATC, Tacview, etc.
✅ **Debuggable** - All logic in one place

## Files to Use

- ✅ `DCS-SC-hook.lua` (updated)
- ✅ `DCS-SC-Main-new.lua` (new, simple)
- ✅ `DCS-SC-MissionScript-new.lua` (new, complete)
- ❌ `DCS-SC-Main.lua` (old, delete)
- ❌ `DCS-SC-MissionScript.lua` (old, delete)
