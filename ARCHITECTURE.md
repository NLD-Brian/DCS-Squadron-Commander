# DCS Squadron Commander - Architecture

## Overview
Clean 3-tier architecture for sending DCS flight data to external applications.

```
┌─────────────────────────────────────────────────────┐
│  DCS-SC-hook.lua                                    │
│  (Loaded by DCS at startup)                         │
│  └─> Loads DCS-SC-Main.lua                          │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  DCS-SC-Main.lua (SERVER ENVIRONMENT)               │
│  • Has networking access (UDP sockets)              │
│  • Handles server events (player connect/disconnect)│
│  • Injects mission script on sim start              │
│  • Forwards all data to .NET via UDP                │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  DCS-SC-MissionScript.lua (MISSION ENVIRONMENT)     │
│  • Has access to world/aircraft data                │
│  • Collects telemetry (position, speed, fuel, etc)  │
│  • Monitors events (takeoff, landing, crashes, etc) │
│  • Calls DCSSC.sendToNet() to send to Main Script   │
└─────────────────────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────┐
│  DCS-SC-Bridge.exe (.NET APPLICATION)               │
│  • Listens on UDP port 10308                        │
│  • Receives JSON data                               │
│  • Processes/stores/forwards to external services   │
└─────────────────────────────────────────────────────┘
```

## Data Flow

### 1. Initialization (Mission Start)
1. `DCS-SC-hook.lua` loads `DCS-SC-Main.lua` at DCS startup
2. Main script registers callbacks with DCS
3. When mission starts, Main script injects `DCS-SC-MissionScript.lua` into mission environment
4. Mission script starts telemetry collection loop (every 1 second)
5. Mission script registers event handlers

### 2. Telemetry Updates (Every 1 second)
```
Mission Script → Collect aircraft data → DCSSC.sendToNet() → 
Main Script → UDP Socket → .NET Application
```

### 3. Event Handling (Real-time)
```
DCS Event (takeoff/landing/crash) → Mission Script Event Handler → 
DCSSC.sendToNet() → Main Script → UDP Socket → .NET Application
```

### 4. Server Events (Real-time)
```
DCS Server Event (player connect/disconnect) → Main Script Callback → 
DCSSC.sendToNet() → UDP Socket → .NET Application
```

## Configuration

### Main Script (DCS-SC-Main.lua)
```lua
DCSSC.config = {
    netHost = "127.0.0.1",      -- IP of .NET application
    netPort = 10308,            -- Port .NET listens on
    receivePort = 10309,        -- Port for commands FROM .NET (future use)
    updateInterval = 1.0        -- Not used (mission script controls this)
}
```

### Mission Script (DCS-SC-MissionScript.lua)
```lua
DCSSC.missionConfig = {
    updateInterval = 1,         -- Telemetry update frequency (seconds)
    trackAI = false             -- Whether to track AI aircraft (only players by default)
}
```

## Message Format

All messages are JSON objects with an `eventType` field:

### Telemetry Update
```json
{
  "eventType": "telemetry_update",
  "unitName": "Pilot #001",
  "unitType": "F-16C_50",
  "playerName": "JohnDoe",
  "latitude": 43.123456,
  "longitude": 43.234567,
  "altitudeAmsl": 5000.5,
  "headingTrue": 180.5,
  "pitch": 5.2,
  "bank": -3.1,
  "groundSpeed": 250.5,
  "verticalSpeed": 10.2,
  "fuel": 0.85,
  "damage": 5.5,
  "inAir": true,
  "missionTime": 12345.67
}
```

### Events
```json
{
  "eventType": "takeoff|landing|crash|ejection|kill|weapon_launch|pilot_death",
  "playerName": "JohnDoe",
  "unitName": "Pilot #001",
  "missionTime": 12345.67
}
```

### Server Events
```json
{
  "eventType": "player_connect|player_disconnect|player_change_slot",
  "playerId": 1,
  "playerName": "JohnDoe",
  "timestamp": 1234567890
}
```

## Key Design Decisions

### Why Not Direct UDP from Mission Script?
Mission environment is sandboxed for security. While it's possible to load sockets with desanitized MissionScripting.lua, it's cleaner to:
- Keep mission script focused on data collection
- Let server script handle all networking
- Maintain clear separation of concerns

### Why Not File-Based Communication?
- File I/O is slow and unreliable
- Creates race conditions
- Requires file cleanup
- Direct function calls are instant and cleaner

### Why UDP Instead of TCP?
- Fire-and-forget (don't block DCS if .NET is down)
- Lower overhead for high-frequency telemetry
- Acceptable data loss (next update arrives in 1 second)
- Simpler implementation

## Future Enhancements

1. **Command Reception**: Main script can receive commands on port 10309
   - Kick players
   - Change weather
   - Spawn units
   - Send messages

2. **Configuration Hot-Reload**: Watch for config file changes

3. **Multiple .NET Endpoints**: Send to multiple applications simultaneously

4. **Data Compression**: For high-frequency updates or many aircraft
