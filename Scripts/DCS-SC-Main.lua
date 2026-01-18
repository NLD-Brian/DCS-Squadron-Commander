-- ========================================
-- Squadron Commander ACARS Main Script
-- Runs in server environment - handles networking
-- ========================================

local base = _G

base.DCSSC = {}

local require = base.require
local loadfile = base.loadfile
local lfs = require('lfs')

DCSSC.config = {
    netHost = "127.0.0.1",
    netPort = 10308,
    receivePort = 10309,
    updateInterval = 1.0
}

-- ========================================
-- JSON LIBRARY LOADING
-- ========================================

local JSON = loadfile("Scripts\\JSON.lua")()
DCSSC.JSON = JSON

-- ========================================
-- NETWORK SOCKET SETUP
-- ========================================

package.path  = package.path..";.\\LuaSocket\\?.lua;"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll;"
local socket = require("socket")

DCSSC.UDPSendSocket = socket.udp()
DCSSC.UDPReceiveSocket = socket.udp()
DCSSC.UDPReceiveSocket:setsockname(DCSSC.config.netHost, DCSSC.config.receivePort)
DCSSC.UDPReceiveSocket:settimeout(0)
DCSSC.UDPReceiveSocket:setoption('reuseaddr', true)
net.log("DCS-SC-Main: UDP sockets initialized")
env.info("DCS-SC-Main: UDP sockets initialized")

-- ========================================
-- BACKUP JSON SERIALIZATION
-- ========================================

function DCSSC.tableToJson(tbl)
    local json = "{"
    local first = true
    
    for key, value in pairs(tbl) do
        if not first then
            json = json .. ","
        end
        first = false
        
        if type(value) == "string" then
            json = json .. '"' .. key .. '":"' .. value .. '"'
        elseif type(value) == "number" then
            json = json .. '"' .. key .. '":' .. tostring(value)
        elseif type(value) == "boolean" then
            json = json .. '"' .. key .. '":' .. tostring(value)
        end
    end
    
    json = json .. "}"
    return json
end

-- ========================================
-- NETWORK SEND FUNCTION
-- ========================================

function DCSSC.sendToNet(data)
    if not DCSSC.UDPSendSocket then
        return false
    end
    
    local jsonData
    if DCSSC.JSON then
        jsonData = DCSSC.JSON:encode(data)
    else
        jsonData = DCSSC.tableToJson(data)
    end
    
    local success, error = pcall(function()
        socket.try(DCSSC.UDPSendSocket:sendto(jsonData .. "\n", DCSSC.config.netHost, DCSSC.config.netPort))
    end)
    
    if not success then
        net.log("DCS-SC-Main: Error sending data: " .. tostring(error))
        env.error("DCS-SC-Main: Error sending data: " .. tostring(error))
        return false
    end
    
    return true
end

-- ========================================
-- NETWORK RECEIVE FUNCTION
-- ========================================

function DCSSC.receiveFromNet()
    local received = DCSSC.UDPReceiveSocket:receive()
    
    if received then
        local decoded = DCSSC.JSON:decode(received)
        
        if decoded then
            net.log("DCS-SC-Main: Received command: " .. received)
            env.info("DCS-SC-Main: Received command: " .. received)
            return decoded
        end
    end
    
    return nil
end

-- ========================================
-- DCS EVENT CALLBACKS
-- ========================================

DCSSC.callbacks = {}

function DCSSC.callbacks.onSimulationStart()
    net.log("DCS-SC-Main: Simulation started - injecting mission script...")
    env.info("DCS-SC-Main: Simulation started - injecting mission script...")
    
    local lfs = require('lfs')
    local scriptPath = lfs.writedir() .. [[Mods\Services\DCS-SC\Scripts\DCS-SC-MissionScript.lua]]
    
    -- Check if mission script file exists
    local file = io.open(scriptPath, "r")
    if not file then
        net.log("DCS-SC-Main: ERROR - Mission script file not found: " .. scriptPath)
        env.error("DCS-SC-Main: ERROR - Mission script file not found: " .. scriptPath)
        return
    end
    file:close()
    
    -- Attempt injection with error handling
    local command = 'dofile("' .. scriptPath:gsub('\\', '/') .. '")'
    local success, error = pcall(function()
        net.dostring_in('mission', 'a_do_script("' .. command .. '")')
    end)
    
    if success then
        net.log("DCS-SC-Main: Mission script injection attempted - waiting for confirmation...")
        env.info("DCS-SC-Main: Mission script injection attempted - waiting for confirmation...")
    else
        net.log("DCS-SC-Main: ERROR - Failed to inject mission script: " .. tostring(error))
        env.error("DCS-SC-Main: ERROR - Failed to inject mission script: " .. tostring(error))
        return
    end
    
    local eventData = {
        eventType = "simulation_start",
        timestamp = os.time(),
        serverName = net.get_server_id() or "Unknown"
    }
    
    DCSSC.sendToNet(eventData)
end

function DCSSC.callbacks.onPlayerConnect(id)
    net.log("DCS-SC-Main: Player connected: " .. tostring(id))
    env.info("DCS-SC-Main: Player connected: " .. tostring(id))
    
    local playerInfo = net.get_player_info(id)
    
    if playerInfo then
        local eventData = {
            eventType = "player_connect",
            timestamp = os.time(),
            playerId = id,
            playerName = playerInfo.name or "Unknown",
            ucid = playerInfo.ucid or ""
        }
        
        DCSSC.sendToNet(eventData)
    end
end

function DCSSC.callbacks.onPlayerDisconnect(id, reason)
    net.log("DCS-SC-Main: Player disconnected: " .. tostring(id))
    env.info("DCS-SC-Main: Player disconnected: " .. tostring(id))
    
    local eventData = {
        eventType = "player_disconnect",
        timestamp = os.time(),
        playerId = id,
        reason = tostring(reason)
    }
    
    DCSSC.sendToNet(eventData)
end

function DCSSC.callbacks.onPlayerChangeSlot(id)
    net.log("DCS-SC-Main: Player changed slot: " .. tostring(id))
    env.info("DCS-SC-Main: Player changed slot: " .. tostring(id))
    
    local playerInfo = net.get_player_info(id)
    
    if playerInfo then
        local eventData = {
            eventType = "player_change_slot",
            timestamp = os.time(),
            playerId = id,
            playerName = playerInfo.name or "Unknown",
            side = playerInfo.side or 0,
            slotId = playerInfo.slot or ""
        }
        
        DCSSC.sendToNet(eventData)
    end
end

function DCSSC.callbacks.onSimulationFrame()
    DCSSC.receiveFromNet()
end

-- ========================================
-- REGISTER WITH DCS
-- ========================================

DCS.setUserCallbacks(DCSSC.callbacks)

-- ========================================
-- STARTUP COMPLETE
-- ========================================

net.log("DCS-SC-Main: Squadron Commander ACARS loaded")
env.info("DCS-SC-Main: Squadron Commander ACARS loaded")
net.log("DCS-SC-Main: Listening on port " .. DCSSC.config.receivePort)
env.info("DCS-SC-Main: Listening on port " .. DCSSC.config.receivePort)
net.log("DCS-SC-Main: Sending to " .. DCSSC.config.netHost .. ":" .. DCSSC.config.netPort)
env.info("DCS-SC-Main: Sending to " .. DCSSC.config.netHost .. ":" .. DCSSC.config.netPort)
