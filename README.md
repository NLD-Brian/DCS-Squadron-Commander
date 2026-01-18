# Learning Lua with DCS Squadron Commander ACARS

## What We've Built

A DCS World hook that:
1. Captures server events (player connections, simulation start, etc.)
2. Sends data via UDP to your .NET application
3. Uses callbacks to respond to DCS events

## Lua Concepts Covered

### 1. **Variables & Scope**
```lua
local myVariable = "Hello"  -- Local scope (recommended)
globalVariable = "World"     -- Global scope (avoid)
```

### 2. **Tables** (Lua's main data structure)
```lua
-- As an array
local array = {1, 2, 3}  -- indices start at 1, not 0!

-- As a dictionary/object
local object = {
    name = "John",
    age = 30
}

-- Nested tables
local config = {
    network = {
        host = "127.0.0.1",
        port = 8080
    }
}
```

### 3. **Functions**
```lua
-- Simple function
function greet(name)
    return "Hello, " .. name  -- .. is string concatenation
end

-- Function in table (OOP style)
local MyModule = {}
function MyModule.doSomething()
    print("Doing something!")
end
```

### 4. **String Operations**
```lua
local str1 = "Hello"
local str2 = "World"
local combined = str1 .. " " .. str2  -- Concatenation

-- Convert to string
local num = 42
local numStr = tostring(num)

-- String formatting
local formatted = string.format("Number: %d, Text: %s", 42, "hello")
```

### 5. **Loops**
```lua
-- For loop
for i = 1, 10 do
    print(i)
end

-- Iterating over table
for key, value in pairs(myTable) do
    print(key, value)
end
```

### 6. **Conditionals**
```lua
if condition then
    -- do something
elseif otherCondition then
    -- do something else
else
    -- default case
end

-- Not equals: ~=
if value ~= nil then
    print("Value exists")
end
```

### 7. **Error Handling**
```lua
-- pcall = "protected call" - catches errors
local success, result = pcall(function()
    -- Risky code here
    return riskyOperation()
end)

if success then
    print("Success: " .. result)
else
    print("Error: " .. result)
end
```

## DCS-Specific Concepts

### Callbacks
DCS uses callbacks to notify your code of events:
- `onSimulationStart()` - Mission starts
- `onPlayerConnect(id)` - Player joins
- `onPlayerDisconnect(id, reason)` - Player leaves
- `onSimulationFrame()` - Every frame (60fps+)

### DCS API Functions
```lua
-- Get player information
local playerInfo = net.get_player_info(playerId)
-- Returns: { name, ucid, side, slot, ... }

-- Get server info
local serverId = net.get_server_id()

-- Get mission time
local time = DCS.getModelTime()

-- Logging
log.write("ModuleName", log.INFO, "Message")
log.write("ModuleName", log.ERROR, "Error message")
```

## Data Flow

```
DCS Server Event
    ↓
DCS-SC-hook.lua (Captures event)
    ↓
tableToJson() (Converts to JSON)
    ↓
UDP Socket (Sends to .NET)
    ↓
.NET Application (Receives & processes)
    ↓
Laravel API (Stores/displays data)
```

## Testing Your Hook

1. Place the hook file in: `Saved Games\DCS\Scripts\Hooks\`
2. Rename it or create a file: `DCS-SC-hook.lua`
3. Start DCS Server
4. Check `Saved Games\DCS\Logs\dcs.log` for messages

## Next Steps

1. **Add proper JSON library** - The current JSON is basic
2. **Implement throttling** - Control update frequency better
3. **Add more events** - Chat messages, mission events, etc.
4. **Error handling** - Robust error recovery
5. **Configuration file** - Load settings from external file

## Important Lua Tips

- **Arrays start at 1**, not 0 (unlike most languages)
- **nil** is Lua's null/undefined value
- **~=** means "not equal" (not !=)
- **..** concatenates strings (not +)
- Use **local** whenever possible for better performance
- **Tables are passed by reference**, not by value
- **No classes**, but tables + functions = OOP pattern

## Common Pitfalls

```lua
-- WRONG: Array starting at 0
local arr = {[0] = "first", "second"}  -- Confusing!

-- RIGHT: Array starting at 1
local arr = {"first", "second"}

-- WRONG: Comparing to nil without checking
if myVar == "something" then  -- Error if myVar is nil!

-- RIGHT: Check for nil first
if myVar and myVar == "something" then

-- WRONG: Global variables everywhere
myVar = 123  -- Pollutes global scope

-- RIGHT: Use local
local myVar = 123
```

## Resources

- [Lua 5.1 Reference Manual](https://www.lua.org/manual/5.1/) (DCS uses Lua 5.1)
- [DCS Scripting Engine Documentation](https://wiki.hoggitworld.com/view/Simulator_Scripting_Engine_Documentation)
- [DCS Hook Documentation](https://wiki.hoggitworld.com/view/DCS_server_hook)

## Your Architecture

```
DCS World Server
    │
    ├─ entry.lua (Plugin declaration)
    │   └─ Scripts/script.lua (Loaded by plugin)
    │
    └─ Hooks/
        └─ DCS-SC-hook.lua (Event capture & network communication)
            │
            └─ UDP → .NET Application
                    │
                    └─ HTTP → Laravel API
```

Good luck with your Squadron Commander ACARS system! 🚁
