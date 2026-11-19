local ADDON, extras = ...
local DUI = DaylightUI

-- The zone levels on the world map are DaylightUI's own since 1.9.4 (Skins:
-- "Zone levels", the hovered zone's range after its name). Blasta keeps the
-- card for its own map extras (boat and zeppelin routes, TravelRoutes.lua) and
-- the current zone's range for the zone title.
extras.MapLevelsGroup = { label = "World Map", items = {} }

local skins = extras.Compatible and extras.Compatible("Skins")
local native = skins and skins.MapLevels
local foreverLevelCap = 60

local function positiveLevel(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
        and value > 0 and value or nil
end

local function playableRange(low, high)
    if positiveLevel(low) and positiveLevel(high) and high >= low and low <= foreverLevelCap then
        return low, math.min(high, foreverLevelCap)
    end
end

-- A zone's range: DaylightUI's table first (the game's C_Map.GetMapLevels
-- returns nothing on Forever), then the game's own.
local function zoneLevels(info)
    if not (info and info.mapID) then return end
    local range = native and type(native.ZONES) == "table" and native.ZONES[info.mapID]
    if type(range) == "table" then
        local low, high = playableRange(range[1], range[2])
        if low then return low, high end
    end
    if C_Map.GetMapLevels then return playableRange(C_Map.GetMapLevels(info.mapID)) end
end

-- The level range of the zone you're in (its Zone map, above any city or
-- cave map), for the zone title: low, high or nil.
function extras.CurrentZoneLevels()
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetMapInfo) then return end
    local id = C_Map.GetBestMapForUnit("player")
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    for _ = 1, 6 do
        local info = type(id) == "number" and C_Map.GetMapInfo(id)
        if not info then return end
        local low, high = zoneLevels(info)
        if low then return low, high end
        if info.mapType == zoneType then return end
        id = info.parentMapID
    end
end
