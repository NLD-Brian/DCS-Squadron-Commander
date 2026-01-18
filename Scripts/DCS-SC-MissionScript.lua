-- ========================================
-- Squadron Commander ACARS - Mission Script
-- Runs in mission environment - collects aircraft data
-- ========================================

local base = _G

if not base.DCSSC then
    net.log("DCS-SC Mission: ERROR - Main script not loaded!")
    env.error("DCS-SC Mission: ERROR - Main script not loaded!")
    return
end

DCSSC = base.DCSSC

DCSSC.missionConfig = {
    updateInterval = 1,
    trackAI = false
}

DCSSC.lastUpdate = 0

-- ========================================
-- INITIALIZATION
-- ========================================

function DCSSC.init()
    net.log("DCS-SC Mission: Initializing data collection...")
    env.info("DCS-SC Mission: Initializing data collection...")
    
    timer.scheduleFunction(DCSSC.update, nil, timer.getTime() + 1)
    world.addEventHandler(DCSSC.eventHandler)
    
    net.log("DCS-SC Mission: Ready - sending data to Main Script")
    env.info("DCS-SC Mission: Ready - sending data to Main Script")
    
    -- Send confirmation that mission script loaded successfully
    local confirmData = {
        eventType = "mission_script_loaded",
        timestamp = timer.getAbsTime(),
        missionName = env.mission.theatre or "Unknown"
    }
    DCSSC.sendToMain(confirmData)
end

-- ========================================
-- DATA COLLECTION
-- ========================================

function DCSSC.getUnitData(unit)
    if not unit or not Unit.isExist(unit) then return nil end
    
    local pos = unit:getPosition()
    local point = unit:getPoint()
    local lat, lon, alt = coord.LOtoLL(point)
    local velocity = unit:getVelocity()
    local speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2)
    
    local heading = math.deg(math.atan2(pos.x.z, pos.x.x))
    if heading < 0 then heading = heading + 360 end
    
    local pitch = math.deg(math.asin(pos.x.y))
    local bank = math.deg(math.atan2(pos.y.z, pos.y.y))
    
    return {
        unitName = unit:getName(),
        unitType = unit:getTypeName(),
        playerName = unit:getPlayerName(),
        coalition = unit:getCoalition(),
        latitude = lat,
        longitude = lon,
        altitudeAmsl = alt,
        headingTrue = heading,
        pitch = pitch,
        bank = bank,
        groundSpeed = speed,
        verticalSpeed = velocity.y,
        fuel = unit:getFuel(),
        damage = 100 - ((unit:getLife() / unit:getLife0()) * 100),
        inAir = unit:inAir(),
        missionTime = timer.getAbsTime()
    }
end

-- ========================================
-- UPDATE LOOP
-- ========================================

function DCSSC.update()
    local currentTime = timer.getTime()
    
    if currentTime - DCSSC.lastUpdate < DCSSC.missionConfig.updateInterval then
        return currentTime + 0.1
    end
    
    DCSSC.lastUpdate = currentTime
    
    for _, coalitionID in pairs({coalition.side.RED, coalition.side.BLUE}) do
        local groups = coalition.getGroups(coalitionID, Group.Category.AIRPLANE)
        if groups then
            for _, group in pairs(groups) do
                local units = group:getUnits()
                if units then
                    for _, unit in pairs(units) do
                        if unit:getPlayerName() or DCSSC.missionConfig.trackAI then
                            local data = DCSSC.getUnitData(unit)
                            if data then
                                data.eventType = "telemetry_update"
                                DCSSC.sendToMain(data)
                            end
                        end
                    end
                end
            end
        end
    end
    
    return currentTime + DCSSC.missionConfig.updateInterval
end

-- ========================================
-- SEND DATA TO MAIN SCRIPT
-- ========================================

function DCSSC.sendToMain(data)
    if DCSSC.sendToNet then
        DCSSC.sendToNet(data)
    else
        net.log("DCS-SC Mission: ERROR - sendToNet function not available!")
        env.error("DCS-SC Mission: ERROR - sendToNet function not available!")
    end
end

-- ========================================
-- EVENT HANDLER
-- ========================================

DCSSC.eventHandler = {}

function DCSSC.eventHandler:onEvent(event)
    if not event or not event.initiator then return end
    
    local unit = event.initiator
    local playerName = nil
    if unit.getPlayerName then
        playerName = unit:getPlayerName()
    end
    
    if not playerName then return end
    
    local eventData = {
        playerName = playerName,
        unitName = unit:getName(),
        missionTime = timer.getAbsTime()
    }
    
    local eventMap = {
        [world.event.S_EVENT_TAKEOFF] = "takeoff",
        [world.event.S_EVENT_LAND] = "landing",
        [world.event.S_EVENT_CRASH] = "crash",
        [world.event.S_EVENT_EJECTION] = "ejection",
        [world.event.S_EVENT_PILOT_DEAD] = "pilot_death",
        [world.event.S_EVENT_SHOT] = "weapon_launch",
        [world.event.S_EVENT_KILL] = "kill"
    }
    
    eventData.eventType = eventMap[event.id]
    
    if eventData.eventType then
        if event.id == world.event.S_EVENT_SHOT and event.weapon then
            eventData.weaponName = event.weapon:getTypeName()
        elseif event.id == world.event.S_EVENT_KILL and event.target then
            eventData.targetName = event.target:getName()
            eventData.targetType = event.target:getTypeName()
        end
        
        DCSSC.sendToMain(eventData)
        net.log("DCS-SC Mission: " .. eventData.eventType .. " - " .. playerName)
        env.info("DCS-SC Mission: " .. eventData.eventType .. " - " .. playerName)
    end
end

-- ========================================
-- START
-- ========================================

do
    if not base.dcssc_mission_hook then
        base.dcssc_mission_hook = true
        DCSSC.init()
        net.log("DCS-SC Mission: Hook installed")
        env.info("DCS-SC Mission: Hook installed")
    end
end
