-- ========================================
-- Squadron Commander ACARS Main Script
-- Loaded by DCS-SC-hook.lua
-- ========================================

-- Write a message to DCS log file (found in Saved Games\DCS\Logs\dcs.log)
-- 'net.log' is a DCS function that writes to the network log
net.log("DCS-SC: Loading Squadron Commander ACARS...")

-- ========================================
-- MODULE INITIALIZATION
-- ========================================

-- Create a local table to hold all our module functions and data
-- 'local' means this variable only exists in this file (good practice!)
-- Tables are Lua's main data structure (like objects/dictionaries)
local DCSSC = {}

-- Configuration table - stores all our settings
-- This is a nested table (table inside a table)
DCSSC.config = {
    netHost = "127.0.0.1",      -- IP address to send data to (.NET app on same machine)
    netPort = 10308,            -- Port number where .NET app listens for data
    receivePort = 10309,        -- Port number where we listen for commands from .NET
    updateInterval = 1.0        -- Update frequency in seconds (not used yet)
}

-- ========================================
-- JSON LIBRARY LOADING
-- ========================================

-- Load DCS World's built-in JSON library
-- 'loadfile()' reads a Lua file and returns it as a function
-- The '()' at the end immediately executes that function
-- Result: JSON object with :encode() and :decode() methods
local JSON = loadfile("Scripts\\JSON.lua")()

-- Store JSON in our module table so other functions can access it
-- Now we can call DCSSC.JSON:encode(table) to convert tables to JSON
DCSSC.JSON = JSON

-- ========================================
-- NETWORK SOCKET SETUP
-- ========================================

-- Load the LuaSocket library (provides networking capabilities)
-- 'require()' loads a library and returns it
local socket = require("socket")

-- Create a UDP socket for SENDING data
-- UDP = User Datagram Protocol (fast, connectionless, no guarantees)
-- This socket will be used to send events to our .NET application
DCSSC.UDPSendSocket = socket.udp()

-- Create a UDP socket for RECEIVING data
-- This socket will listen for commands from our .NET application
DCSSC.UDPReceiveSocket = socket.udp()

-- Bind the receive socket to a specific port so it can listen for incoming data
-- ':setsockname(ip, port)' tells the socket which port to monitor
-- "*" means "all network interfaces" (localhost, LAN, etc.)
-- This is REQUIRED for receiving data - without it, socket can only send
DCSSC.UDPReceiveSocket:setsockname("*", DCSSC.config.receivePort)

-- Set socket to non-blocking mode
-- ':settimeout(0)' means :receive() returns immediately even if no data
-- Without this, :receive() would pause (block) execution until data arrives
-- In DCS, blocking = freezing the game, so we MUST use non-blocking!
DCSSC.UDPReceiveSocket:settimeout(0)

-- ========================================
-- BACKUP JSON SERIALIZATION
-- ========================================

-- Simple JSON serialization function (backup if DCS's JSON.lua fails)
-- This converts a Lua table to a JSON string manually
-- Parameters: tbl = Lua table to convert
-- Returns: JSON string representation
function DCSSC.tableToJson(tbl)
    -- Start building JSON string with opening brace
    local json = "{"
    
    -- Track if this is the first key-value pair (to handle commas)
    local first = true
    
    -- Loop through all key-value pairs in the table
    -- 'pairs()' is a Lua function that iterates over table entries
    for key, value in pairs(tbl) do
        -- Add comma before each entry except the first
        if not first then
            json = json .. ","  -- '..' is Lua's string concatenation operator
        end
        first = false  -- After first iteration, this is always false
        
        -- Handle different value types differently
        -- 'type()' returns the data type as a string
        if type(value) == "string" then
            -- Strings need quotes around both key and value
            json = json .. '"' .. key .. '":"' .. value .. '"'
        elseif type(value) == "number" then
            -- Numbers: key in quotes, value without quotes
            -- 'tostring()' converts number to string
            json = json .. '"' .. key .. '":' .. tostring(value)
        elseif type(value) == "boolean" then
            -- Booleans: true/false without quotes
            json = json .. '"' .. key .. '":' .. tostring(value)
        end
        -- Note: This simple version doesn't handle nested tables or arrays
    end
    
    -- Close the JSON object
    json = json .. "}"
    
    -- Return the complete JSON string
    return json
end

-- ========================================
-- NETWORK SEND FUNCTION
-- ========================================

-- Send data to the .NET application via UDP
-- Parameters: data = Lua table with event information
-- Returns: true if successful, false if failed
function DCSSC.sendToNet(data)
    -- Safety check: make sure socket exists
    -- 'not' means "if false" or "if nil"
    if not DCSSC.UDPSendSocket then
        return false  -- Exit early if socket doesn't exist
    end
    
    -- Convert Lua table to JSON string
    local jsonData
    
    -- Check if DCS's JSON library loaded successfully
    if DCSSC.JSON then
        -- Use DCS's JSON library (proper, handles nested tables)
        -- ':encode()' converts Lua table → JSON string
        jsonData = DCSSC.JSON:encode(data)
    else
        -- Fallback to our simple backup function if JSON library failed
        jsonData = DCSSC.tableToJson(data)
    end
    
    -- Protected call (error handling)
    -- 'pcall' = "protected call" - catches errors without crashing
    -- If function succeeds: success=true, error=return value
    -- If function fails: success=false, error=error message
    local success, error = pcall(function()
        -- 'socket.try()' throws an error if sendto fails
        -- ':sendto(data, ip, port)' sends UDP packet
        -- We add "\n" (newline) to help the receiver parse messages
        socket.try(DCSSC.UDPSendSocket:sendto(jsonData .. "\n", DCSSC.config.netHost, DCSSC.config.netPort))
    end)
    
    -- Check if sending failed
    if not success then
        -- Log the error to DCS log file
        -- 'tostring()' converts error to string (in case it's not already)
        net.log("DCS-SC: Error sending data: " .. tostring(error))
        return false  -- Indicate failure
    end
    
    -- If we got here, send was successful
    return true
end

-- ========================================
-- NETWORK RECEIVE FUNCTION
-- ========================================

-- Check for and process incoming commands from .NET application
-- Called every frame by DCS (60+ times per second)
-- Returns: decoded command table, or nil if no data
function DCSSC.receiveFromNet()
    -- Try to read data from the UDP socket
    -- ':receive()' returns data if available, or nil if nothing waiting
    -- Because we set timeout to 0, this returns INSTANTLY (non-blocking)
    local received = DCSSC.UDPReceiveSocket:receive()
    
    -- Check if we actually received data
    -- 'if received then' is shorthand for 'if received ~= nil then'
    if received then
        -- Convert JSON string back to Lua table
        -- ':decode()' converts JSON string → Lua table
        local decoded = DCSSC.JSON:decode(received)
        
        -- Check if JSON parsing succeeded
        if decoded then
            -- Log what we received (for debugging)
            net.log("DCS-SC: Received command: " .. received)
            
            -- TODO: Handle different command types here
            -- Example: if decoded.command == "ping" then respondToPing() end
            -- Example: if decoded.command == "kick" then kickPlayer(decoded.playerId) end
            
            -- Return the decoded command so caller can use it
            return decoded
        end
    end
    
    -- If no data received or parsing failed, return nil
    -- 'nil' is Lua's way of saying "nothing" or "no value"
    return nil
end

-- ========================================
-- DCS EVENT CALLBACKS
-- ========================================

-- Create a table to hold all callback functions
-- DCS will call these functions when events happen
DCSSC.callbacks = {}

-- Called by DCS when the simulation/mission starts
-- No parameters - DCS just notifies us the mission started
function DCSSC.callbacks.onSimulationStart()
    -- Log to DCS log file
    net.log("DCS-SC: Simulation started")
    
    -- Build a Lua table with event information
    -- This table will be converted to JSON and sent to .NET
    local eventData = {
        eventType = "simulation_start",           -- What kind of event
        timestamp = os.time(),                    -- Current Unix timestamp (seconds since 1970)
        serverName = net.get_server_id() or "Unknown"  -- Server ID, or "Unknown" if nil
    }
    -- Note: 'or' operator - if left side is nil/false, use right side
    
    -- Send the event to .NET application
    DCSSC.sendToNet(eventData)
end

-- Called by DCS when a player connects to the server
-- Parameters: id = player's network ID (number)
function DCSSC.callbacks.onPlayerConnect(id)
    -- Log the connection with player ID
    -- 'tostring()' converts number to string for concatenation
    net.log("DCS-SC: Player connected: " .. tostring(id))
    
    -- Get detailed player information from DCS
    -- 'net.get_player_info()' is a DCS function that returns a table with player data
    -- Returns: { name, ucid, side, slot, ping, ... } or nil if player not found
    local playerInfo = net.get_player_info(id)
    
    -- Check if we got player info (could be nil if player disconnected immediately)
    if playerInfo then
        -- Build event data table
        local eventData = {
            eventType = "player_connect",                 -- Event type
            timestamp = os.time(),                        -- When it happened
            playerId = id,                                -- Player's network ID
            playerName = playerInfo.name or "Unknown",    -- Player's name (or "Unknown" if nil)
            ucid = playerInfo.ucid or ""                  -- Unique Client ID (empty string if nil)
        }
        -- UCID = permanent unique ID for each player (like a Steam ID)
        
        -- Send event to .NET
        DCSSC.sendToNet(eventData)
    end
end

-- Called by DCS when a player disconnects from the server
-- Parameters: 
--   id = player's network ID (number)
--   reason = disconnect reason (could be string, number, or nil)
function DCSSC.callbacks.onPlayerDisconnect(id, reason)
    -- Log the disconnection
    net.log("DCS-SC: Player disconnected: " .. tostring(id))
    
    -- Build event data
    -- Note: We don't call net.get_player_info() here because the player is already gone!
    local eventData = {
        eventType = "player_disconnect",      -- Event type
        timestamp = os.time(),                -- When it happened
        playerId = id,                        -- Player's network ID
        reason = tostring(reason)             -- Reason (convert to string, could be number/nil)
    }
    -- Reasons might be: "timeout", "kicked", "banned", etc.
    
    -- Send event to .NET
    DCSSC.sendToNet(eventData)
end


-- Called by DCS when a player changes aircraft/slot
-- Happens when player joins a unit, switches planes, or goes to spectator
-- Parameters: id = player's network ID (number)
function DCSSC.callbacks.onPlayerChangeSlot(id)
    -- Log the slot change
    net.log("DCS-SC: Player changed slot: " .. tostring(id))
    
    -- Get current player information (includes new slot)
    local playerInfo = net.get_player_info(id)
    
    -- Check if player info is available
    if playerInfo then
        -- Build event data with slot information
        local eventData = {
            eventType = "player_change_slot",             -- Event type
            timestamp = os.time(),                        -- When it happened
            playerId = id,                                -- Player's network ID
            playerName = playerInfo.name or "Unknown",    -- Player name
            side = playerInfo.side or 0,                  -- Side: 0=spectator, 1=red, 2=blue
            slotId = playerInfo.slot or ""                -- Slot identifier (aircraft type + position)
        }
        -- Slot examples: "F-16C_blk_50-1", "A-10C-2", "" (empty = spectator)
        
        -- Send event to .NET
        DCSSC.sendToNet(eventData)
    end
end

-- ========================================
-- FILE-BASED DATA EXCHANGE
-- ========================================

-- Track time for periodic file reads
DCSSC.lastTelemetryRead = 0
DCSSC.telemetryInterval = 1  -- Read telemetry every 1 second
DCSSC.lastEventRead = 0
DCSSC.eventInterval = 0.5  -- Check events every 0.5 seconds

-- Read telemetry data from mission script
function DCSSC.readTelemetryFile()
    local lfs = require('lfs')
    local telemetryPath = lfs.writedir() .. [[Logs\dcs-sc-telemetry.json]]
    
    -- Try to open and read the file
    local file = io.open(telemetryPath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        if content and content ~= "" then
            -- Parse JSON
            local success, data = pcall(function()
                return DCSSC.JSON:decode(content)
            end)
            
            if success and data and data.players then
                -- Send telemetry data to .NET
                for _, playerData in ipairs(data.players) do
                    -- Add event type for identification
                    playerData.eventType = "telemetry_update"
                    DCSSC.sendToNet(playerData)
                end
            end
        end
    end
end

-- Read events from mission script
function DCSSC.readEventsFile()
    local lfs = require('lfs')
    local eventsPath = lfs.writedir() .. [[Logs\dcs-sc-events.json]]
    
    -- Try to open and read the file
    local file = io.open(eventsPath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        
        if content and content ~= "" then
            -- Process each line as a separate event
            for line in content:gmatch("[^\r\n]+") do
                local success, event = pcall(function()
                    return DCSSC.JSON:decode(line)
                end)
                
                if success and event then
                    -- Send event to .NET
                    DCSSC.sendToNet(event)
                end
            end
            
            -- Clear the file after reading
            local clearFile = io.open(eventsPath, "w")
            if clearFile then
                clearFile:close()
            end
        end
    end
end

-- Called by DCS every single frame (60+ times per second!)
-- This is where we check for incoming network messages
-- No parameters - just runs constantly while mission is active
function DCSSC.callbacks.onSimulationFrame()
    -- Check if .NET sent us any commands
    -- Because socket is non-blocking, this returns instantly if no data
    -- If there IS data, receiveFromNet() processes it
    DCSSC.receiveFromNet()
    
    -- Throttled periodic tasks
    local currentTime = os.clock()
    
    -- Read telemetry data from mission script
    if currentTime - DCSSC.lastTelemetryRead >= DCSSC.telemetryInterval then
        DCSSC.lastTelemetryRead = currentTime
        DCSSC.readTelemetryFile()
    end
    
    -- Read events from mission script
    if currentTime - DCSSC.lastEventRead >= DCSSC.eventInterval then
        DCSSC.lastEventRead = currentTime
        DCSSC.readEventsFile()
    end
end

-- ========================================
-- REGISTER WITH DCS
-- ========================================

-- Tell DCS to use our callback functions
-- 'DCS.setUserCallbacks()' is a DCS function that registers event handlers
-- After this, DCS will automatically call our functions when events happen:
--   - Mission starts → onSimulationStart()
--   - Player joins → onPlayerConnect(id)
--   - Player leaves → onPlayerDisconnect(id, reason)
--   - Player changes slot → onPlayerChangeSlot(id)
--   - Every frame → onSimulationFrame()
DCS.setUserCallbacks(DCSSC.callbacks)

-- ========================================
-- STARTUP COMPLETE
-- ========================================

-- Log success messages (visible in dcs.log file)
net.log("DCS-SC: Squadron Commander ACARS loaded successfully!")

-- Log configuration so we know where data is going/coming from
-- String concatenation with '..' operator
net.log("DCS-SC: Listening on port " .. DCSSC.config.receivePort)
net.log("DCS-SC: Sending to " .. DCSSC.config.netHost .. ":" .. DCSSC.config.netPort)

-- At this point, the module is fully loaded and ready to:
-- 1. Send events to .NET app (port 10308)
-- 2. Receive commands from .NET app (port 10309)
-- 3. React to DCS server events in real-time
