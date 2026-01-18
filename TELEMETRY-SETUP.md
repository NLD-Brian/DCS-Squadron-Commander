# Complete Player Telemetry Tracking - Setup Guide

## Architecture Overview

```
Mission Script (Full Access)          Server Hook (Limited Access)
        │                                      │
        ├─ Tracks all aircraft data            ├─ Player connect/disconnect
        ├─ Position, speed, fuel, etc.         ├─ Reads telemetry files
        ├─ Takeoff/landing events              └─ Sends to .NET app
        ├─ Weapons, kills, crashes                     │
        └─ Writes to JSON files ────────────────────>  │
                                                       UDP
                                                        │
                                                   .NET App (Port 10308)
                                                        │
                                                   Laravel API
```

## Why Two Scripts?

DCS has **security separation**:
- **Server Hooks** - Network events only (limited game access)
- **Mission Scripts** - Full game access but no network API

**Solution:** Mission script writes to files → Server hook reads files → Sends to .NET

## Setup Instructions

### 1. Server Hook (Already Done ✅)
Your [DCS-SC-hook.lua](c:\Users\BvdNe\Saved Games\DCS\Mods\Services\DCS-SC\DCS-SC-hook.lua) and [DCS-SC-Main.lua](c:\Users\BvdNe\Saved Games\DCS\Mods\Services\DCS-SC\Scripts\DCS-SC-Main.lua) are ready!

### 2. Mission Script Setup

**Option A: Add to Every Mission**
Add this to your mission triggers:
1. Open mission in Mission Editor
2. Go to Triggers
3. Create new trigger:
   - **TYPE:** ONCE
   - **EVENT:** MISSION START
   - **ACTION:** DO SCRIPT FILE
   - **FILE:** Browse to `DCS-SC-MissionScript.lua`

**Option B: Auto-Load via MissionScripting.lua (Server-Wide)**

Edit: `DCS World\Scripts\MissionScripting.lua`

At the bottom, add:
```lua
-- Auto-load Squadron Commander ACARS
local status, result = pcall(function()
    local lfs = require('lfs')
    dofile(lfs.writedir() .. [[Mods\Services\DCS-SC\Scripts\DCS-SC-MissionScript.lua]])
end)

if not status then
    env.info("DCS-SC Mission Script failed: " .. tostring(result))
end
```

⚠️ **Warning:** Option B loads for ALL missions automatically but requires editing core DCS files.

## Data Being Tracked

### Telemetry Updates (Every 1 Second)
```json
{
  "eventType": "telemetry_update",
  "playerName": "Maverick",
  "unitType": "F-16C_50",
  "position": {
    "lat": 25.594814,
    "lon": 55.938746,
    "alt": 5420
  },
  "speed": {
    "groundSpeed": 250.5,
    "tas": 250.5,
    "ias": 225.45,
    "mach": 0.736,
    "verticalSpeed": 12.5
  },
  "attitude": {
    "heading": 270,
    "pitch": 5.2,
    "roll": -2.1,
    "bank": -2.1
  },
  "fuel": 0.65,
  "fuelPercent": 65,
  "damage": 0,
  "inAir": true,
  "engineOn": true,
  "coalition": 2,
  "timestamp": 1705536000
}
```

### Event Updates (Immediate)
```json
// Takeoff
{"eventType":"takeoff","playerName":"Maverick","unitName":"F-16C_50-1","timestamp":1705536030}

// Landing
{"eventType":"landing","playerName":"Maverick","unitName":"F-16C_50-1","timestamp":1705537200}

// Weapon Launch
{"eventType":"weapon_launch","playerName":"Maverick","weaponName":"AIM-120C","timestamp":1705536500}

// Kill
{"eventType":"kill","playerName":"Maverick","targetName":"MiG-29-1","targetType":"MiG-29S","timestamp":1705536510}

// Crash
{"eventType":"crash","playerName":"Maverick","unitName":"F-16C_50-1","timestamp":1705536800}

// Ejection
{"eventType":"ejection","playerName":"Maverick","unitName":"F-16C_50-1","timestamp":1705536805}

// Death
{"eventType":"pilot_death","playerName":"Maverick","unitName":"F-16C_50-1","timestamp":1705536810}
```

## Data Files Location

Mission script writes to:
- **Telemetry:** `Saved Games\DCS\Logs\dcs-sc-telemetry.json`
- **Events:** `Saved Games\DCS\Logs\dcs-sc-events.json`

Server hook reads these files and forwards to your .NET app via UDP.

## Complete Event List

Your .NET app will now receive:

### From Server Hook:
- ✅ `player_connect` - Player joins server
- ✅ `player_disconnect` - Player leaves server
- ✅ `player_change_slot` - Player enters/changes aircraft
- ✅ `simulation_start` - Mission starts

### From Mission Script:
- ✅ `telemetry_update` - Position, speed, fuel, etc. (every 1 sec)
- ✅ `takeoff` - Aircraft leaves ground
- ✅ `landing` - Aircraft touches down
- ✅ `weapon_launch` - Player fires weapon
- ✅ `kill` - Player destroys enemy
- ✅ `crash` - Aircraft crashes
- ✅ `ejection` - Player ejects
- ✅ `pilot_death` - Player dies

## Performance Notes

- Telemetry updates: 1/second per player
- Event updates: Immediate
- File I/O overhead: Minimal (~5KB/update)
- Network overhead: ~1-2KB UDP per update

With 20 players:
- ~20 telemetry updates/second
- ~40KB/second data transfer to .NET

## Filtering by UCID

The mission script tracks by player name. To correlate with UCID:

1. Server hook sends UCID on `player_connect`
2. Store mapping: `playerName → UCID` in your .NET app
3. When telemetry arrives with playerName, look up the UCID

Example in .NET:
```csharp
Dictionary<string, string> playerUCIDs = new();

// On player_connect:
playerUCIDs[data.playerName] = data.ucid;

// On telemetry_update:
string ucid = playerUCIDs.TryGetValue(data.playerName, out var id) ? id : "unknown";
```

## Testing

1. Start DCS Server with a mission
2. Check logs: `Saved Games\DCS\Logs\dcs.log`
   - Should see "DCS-SC Mission Script: Ready to track player telemetry!"
3. Join server and take off
4. Check telemetry file is being created
5. Watch .NET app receive UDP packets

## Troubleshooting

**No telemetry data:**
- Check mission script is loaded (look in dcs.log)
- Verify telemetry file exists in Logs folder
- Check file permissions

**Missing events:**
- Events only fire for players (not AI unless configured)
- Check event handler is registered (dcs.log)

**Performance issues:**
- Increase update intervals in both scripts
- Reduce data sent (remove unused fields)
- Batch updates before sending to .NET

## What You Now Have

✅ **All requested data tracking:**
- Position (lat/lon) ✅
- Altitude (MSL) ✅
- Ground speed / IAS / Mach ✅
- Vertical speed ✅
- Heading / Pitch / Roll / Bank ✅
- Fuel quantity ✅
- Engine state ✅
- Damage state ✅
- Takeoff / landing detection ✅
- Weapon launches ✅
- Kills / deaths ✅
- Crashes / ejections ✅

Next step: Build your .NET receiver to process this data and forward to Laravel!
