-- ========================================
-- Squadron Commander ACARS - Mission Script
-- This runs IN THE MISSION and has access to all unit data
-- Place in mission triggers or load via mission scripting
-- ========================================

-- This script bridges the gap between mission environment and server hooks
-- It tracks detailed player aircraft data and sends directly via UDP

DCSSC_Mission = {}

-- Configuration
DCSSC_Mission.config = {
    updateInterval = 1,      -- Send updates every 1 second
    trackAI = false,         -- Whether to track AI units too
    netHost = "127.0.0.1",   -- .NET application host
    netPort = 10308,         -- .NET application port
    useDirectUDP = true      -- Use direct UDP instead of file I/O
}

-- Initialize UDP socket (if using direct UDP)
if DCSSC_Mission.config.useDirectUDP then
    package.path = package.path .. ";.\\LuaSocket\\?.lua;"
    package.cpath = package.cpath .. ";.\\LuaSocket\\?.dll;"
    
    local socket = require("socket")
    DCSSC_Mission.udpSocket = socket.udp()
    DCSSC_Mission.udpSocket:settimeout(0)
    DCSSC_Mission.udpSocket:setsockname("*", 0)
    
    env.info("DCS-SC Mission: Using DIRECT UDP mode (like DCSServerBot)")
else
    env.info("DCS-SC Mission: Using FILE I/O mode")
end

-- Track player data
DCSSC_Mission.playerData = {}
DCSSC_Mission.lastUpdate = 0

-- Initialize
function DCSSC_Mission.initialize()
    env.info("DCS-SC Mission Script: Initializing...")
    
    -- Start the update loop
    timer.scheduleFunction(DCSSC_Mission.update, nil, timer.getTime() + 1)
    
    env.info("DCS-SC Mission Script: Initialized successfully!")
end

-- Get detailed unit data
function DCSSC_Mission.getUnitData(unit)
    if not unit or not Unit.isExist(unit) then
        return nil
    end
    
    -- Get position
    local pos = unit:getPosition()
    local point = unit:getPoint()
    
    -- Convert to lat/lng
    local lat, lon, alt = coord.LOtoLL(point)
    
    -- Get velocity
    local velocity = unit:getVelocity()
    local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)  -- m/s
    
    -- Calculate IAS, TAS, Mach from velocity and altitude
    local tas = speed  -- m/s (True Airspeed ≈ ground speed at low alt)
    local mach = speed / 340.29  -- Approximate Mach number (speed of sound ~340 m/s)
    
    -- Get vertical speed (climb rate)
    local verticalSpeed = velocity.y  -- m/s
    
    -- Get heading (yaw)
    local heading = math.deg(math.atan2(pos.x.z, pos.x.x))
    if heading < 0 then
        heading = heading + 360
    end
    
    -- Get pitch and roll
    local pitch = math.deg(math.asin(pos.x.y))
    local roll = math.deg(math.atan2(pos.y.z, pos.y.y))
    
    -- Get fuel
    local fuel = unit:getFuel()  -- Returns 0.0 to 1.0 (percentage)
    
    -- Get life (damage state)
    local life = unit:getLife()  -- Current health
    local life0 = unit:getLife0()  -- Initial health
    local damagePercent = 100 - ((life / life0) * 100)
    
    -- Check if in air
    local inAir = unit:inAir()
    
    -- Get player name (if applicable)
    local playerName = unit:getPlayerName()
    
    -- Get unit descriptor for engine info
    local desc = unit:getDesc()
    
    -- Build comprehensive data package
    local data = {
        -- Basic info
        unitName = unit:getName(),
        unitType = unit:getTypeName(),
        playerName = playerName,
        groupName = unit:getGroup():getName(),
        coalition = unit:getCoalition(),  -- 1=red, 2=blue, 0=neutral
        country = unit:getCountry(),
        
        -- Position
        position = {
            lat = lat,
            lon = lon,
            alt = alt,  -- MSL (meters above sea level)
        },
        
        -- Speed data
        speed = {
            groundSpeed = speed,  -- m/s
            tas = tas,  -- m/s True Airspeed
            ias = tas * 0.9,  -- Approximate IAS (would need pressure altitude for accuracy)
            mach = mach,
            verticalSpeed = verticalSpeed  -- m/s (positive = climbing)
        },
        
        -- Attitude
        attitude = {
            heading = heading,  -- degrees
            pitch = pitch,      -- degrees
            roll = roll,        -- degrees
            bank = roll         -- Same as roll
        },
        
        -- Aircraft state
        fuel = fuel,  -- 0.0 to 1.0
        fuelPercent = fuel * 100,
        damage = damagePercent,
        inAir = inAir,
        life = life,
        maxLife = life0,
        
        -- Engine state (simplified - checking if unit is alive and has fuel)
        engineOn = life > 0 and fuel > 0,
        
        -- Timestamp
        timestamp = os.time(),
        missionTime = timer.getAbsTime()
    }
    
    return data
end

-- Main update loop
function DCSSC_Mission.update()
    local currentTime = timer.getTime()
    
    -- Throttle updates
    if currentTime - DCSSC_Mission.lastUpdate < DCSSC_Mission.config.updateInterval then
        return timer.getTime() + 0.1
    end
    
    DCSSC_Mission.lastUpdate = currentTime
    
    -- Collect data for all player units
    local updates = {}
    
    -- Scan both coalitions
    for _, coalitionID in pairs({coalition.side.RED, coalition.side.BLUE}) do
        local groups = coalition.getGroups(coalitionID, Group.Category.AIRPLANE)
        
        if groups then
            for _, group in pairs(groups) do
                local units = group:getUnits()
                
                if units then
                    for _, unit in pairs(units) do
                        -- Only track players (unless trackAI is enabled)
                        local playerName = unit:getPlayerName()
                        
                        if playerName or DCSSC_Mission.config.trackAI then
                            local unitData = DCSSC_Mission.getUnitData(unit)
                            
                            if unitData then
                                table.insert(updates, unitData)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Export data (write to file for server hook to read)
    if #updates > 0 then
        DCSSC_Mission.exportData(updates)
    end
    
    -- Schedule next update
    return currentTime + DCSSC_Mission.config.updateInterval
end

-- Export data - either via UDP or file I/O
function DCSSC_Mission.exportData(data)
    local exportPacket = {
        timestamp = os.time(),
        missionTime = timer.getAbsTime(),
        players = data
    }
    
    if DCSSC_Mission.config.useDirectUDP then
        -- DIRECT UDP METHOD (like DCSServerBot)
        -- Send each player's data individually to avoid large packets
        for _, playerData in ipairs(data) do
            playerData.eventType = "telemetry_update"
            
            -- Use DCS's built-in JSON converter (available in mission environment)
            local jsonData = net.lua2json(playerData)
            
            -- Send via UDP directly
            local success, err = pcall(function()
                socket.try(DCSSC_Mission.udpSocket:sendto(
                    jsonData .. "\n",
                    DCSSC_Mission.config.netHost,
                    DCSSC_Mission.config.netPort
                ))
            end)
            
            if not success then
                env.info("DCS-SC Mission: UDP send error: " .. tostring(err))
            end
        end
    else
        -- FILE I/O METHOD (fallback)
        local lfs = require('lfs')
        local exportPath = lfs.writedir() .. [[Logs\dcs-sc-telemetry.json]]
        
        -- Convert to JSON
        local JSON = loadfile("Scripts\\JSON.lua")()
        local jsonData = JSON:encode(exportPacket)
        
        -- Write to file
        local file = io.open(exportPath, "w")
        if file then
            file:write(jsonData)
            file:close()
        end
    end
end

-- Event handlers for tracking specific events
DCSSC_Mission.eventHandler = {}

function DCSSC_Mission.eventHandler:onEvent(event)
    if not event or not event.initiator then
        return
    end
    
    local unit = event.initiator
    local playerName = unit:getPlayerName and unit:getPlayerName()
    
    -- Only process player events
    if not playerName then
        return
    end
    
    local eventData = {
        eventType = nil,
        playerName = playerName,
        unitName = unit:getName(),
        timestamp = os.time(),
        missionTime = timer.getAbsTime()
    }
    
    -- Handle different event types
    if event.id == world.event.S_EVENT_TAKEOFF then
        eventData.eventType = "takeoff"
        env.info("DCS-SC: Player " .. playerName .. " took off")
        
    elseif event.id == world.event.S_EVENT_LAND then
        eventData.eventType = "landing"
        env.info("DCS-SC: Player " .. playerName .. " landed")
        
    elseif event.id == world.event.S_EVENT_CRASH then
        eventData.eventType = "crash"
        env.info("DCS-SC: Player " .. playerName .. " crashed")
        
    elseif event.id == world.event.S_EVENT_EJECTION then
        eventData.eventType = "ejection"
        env.info("DCS-SC: Player " .. playerName .. " ejected")
        
    elseif event.id == world.event.S_EVENT_PILOT_DEAD then
        eventData.eventType = "pilot_death"
        env.info("DCS-SC: Player " .. playerName .. " died")
        
    elseif event.id == world.event.S_EVENT_SHOT then
        eventData.eventType = "weapon_launch"
        if event.weapon then
            eventData.weaponName = event.weapon:getTypeName()
        end
        env.info("DCS-SC: Player " .. playerName .. " fired weapon")
        
    elseif event.id == world.event.S_EVENT_KILL then
        -- Check if player got the kill
        if event.initiator and event.initiator:getPlayerName() == playerName then
            eventData.eventType = "kill"
            if event.target then
                eventData.targetName = event.target:getName()
                eventData.targetType = event.target:getTypeName()
            end
            env.info("DCS-SC: Player " .. playerName .. " got a kill")
        end
    end
    
    -- Export event immediately
    if eventData.eventType then
        DCSSC_Mission.exportEvent(eventData)
    end
end

-- Export single event
function DCSSC_Mission.exportEvent(eventData)
    if DCSSC_Mission.config.useDirectUDP then
        -- DIRECT UDP METHOD (like DCSServerBot)
        -- Use DCS's built-in JSON converter
        local jsonData = net.lua2json(eventData)
        
        -- Send via UDP directly
        local success, err = pcall(function()
            socket.try(DCSSC_Mission.udpSocket:sendto(
                jsonData .. "\n",
                DCSSC_Mission.config.netHost,
                DCSSC_Mission.config.netPort
            ))
        end)
        
        if not success then
            env.info("DCS-SC Mission: UDP send error: " .. tostring(err))
        end
    else
        -- FILE I/O METHOD (fallback)
        local lfs = require('lfs')
        local exportPath = lfs.writedir() .. [[Logs\dcs-sc-events.json]]
        
        local JSON = loadfile("Scripts\\JSON.lua")()
        local jsonData = JSON:encode(eventData)
        
        -- Append to events file
        local file = io.open(exportPath, "a")
        if file then
            file:write(jsonData .. "\n")
            file:close()
        end
    end
end

-- Register event handler
world.addEventHandler(DCSSC_Mission.eventHandler)

-- Initialize on load
DCSSC_Mission.initialize()

env.info("DCS-SC Mission Script: Ready to track player telemetry!")
