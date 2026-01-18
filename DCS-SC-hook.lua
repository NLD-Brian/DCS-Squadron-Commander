-- Hook to load Squadron Commander ACARS
local status, result = pcall(function() 
    local dcsSC = require('lfs')
    dofile(dcsSC.writedir()..[[Mods\Services\DCS-SC\Scripts\DCS-SC-Main.lua]])
end, nil)

if not status then
    net.log("DCS-SC ERROR: " .. tostring(result))
end
