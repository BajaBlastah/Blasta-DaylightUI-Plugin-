-- SPDX-License-Identifier: GPL-3.0-or-later
-- Boat and zeppelin routes on the world map, on top of DaylightUI's travel
-- symbols (DaylightUI_Skins, MapPins.lua: "Boats and zeppelins").
--
--   zone maps       DaylightUI draws the docks. Hovering one draws its routes:
--                   a solid line toward each destination, cut at the map's edge
--                   with an arrow (the symbol's tooltip names the place).
--   continent and   DaylightUI draws nothing there. Blasta puts a small dock
--   world maps      symbol at each dock; hovering one draws its routes the same way.
--
-- The routes follow DaylightUI's dock list (Pins.TRAVEL), paired up into the
-- game's transport paths (TaxiPathNode ids in the comments). Place names come
-- from the game (C_Map.GetAreaInfo), so they read in the client's language.
local ADDON, extras = ...
local DUI = DaylightUI
local skins = extras.Compatible("Skins")
local Pins = skins and skins.MapPins
if not (Pins and Pins.On and Pins.Shows and Pins.COLORS and C_Map and C_Map.GetMapPosFromWorldPos
    and C_Map.GetMapInfo and CreateVector2D and DUI.Style and DUI.Motion) then return end

local L = DUI.L
local KEY = "mapTravelRoutes"
local function enabled() return DUI:Get(ADDON, KEY) ~= false end

if extras.MapLevelsGroup and extras.MapLevelsGroup.items then
    table.insert(extras.MapLevelsGroup.items, { type = "toggle", key = KEY, label = "Boat and zeppelin routes",
        desc = "Hovering a boat or zeppelin symbol on the world map draws its route as a solid line, with an arrow where it leaves the map. On continent and world maps, a small dock symbol shows the routes the same way. Needs DaylightUI's \"Boats and zeppelins\".",
        default = function() return true end,
        disabled = function()
            local mod = DUI:GetModule("Skins")
            return mod and mod.db and mod.db.mapTravel == false
        end })
end

-- A dock: { continent, world x, world y, area id, fallback name }.
local function dock(c, x, y, area, name) return { c, x, y, area, name } end
local MENETHIL_T = dock(0, -3905, -586, 150, "Menethil Harbor")
local MENETHIL = dock(0, -3709, -575, 150, "Menethil Harbor")
local SOUTHSHORE = dock(0, -1103, -555, 271, "Southshore")
local AUBERDINE_W = dock(1, 6406, 823, 442, "Auberdine")
local UNDERCITY = dock(0, 2062, 293, 1497, "Undercity")
local UNDERCITY_G = dock(0, 2063, 235, 1497, "Undercity")
local GROMGOL_O = dock(0, -12464, 232, 117, "Grom'gol Base Camp")
local GROMGOL_U = dock(0, -12407, 212, 117, "Grom'gol Base Camp")

-- { kind, side ("alliance", "horde", "both"), dock, dock }
local ROUTES = {
    { "boat", "alliance", MENETHIL_T, dock(1, -4016, -4741, 513, "Theramore Isle") },     -- 292
    { "boat", "alliance", MENETHIL, SOUTHSHORE },                                           -- 11167
    { "boat", "alliance", MENETHIL, AUBERDINE_W },                                          -- 11167
    { "boat", "alliance", SOUTHSHORE, AUBERDINE_W },                                        -- 11167
    { "boat", "alliance", dock(1, 6594, 760, 442, "Auberdine"), dock(1, 8532, 1024, 702, "Rut'theran Village") }, -- 293
    { "boat", "alliance", dock(1, 6548, 942, 442, "Auberdine"), dock(0, -8654, 1344, 17203, "Stormwind Harbor") }, -- 11616
    { "boat", "both", dock(0, -14278, 583, 35, "Booty Bay"), dock(1, -1006, -3842, 392, "Ratchet") },             -- 241
    { "boat", "alliance", dock(1, -4197, 3287, 1116, "Feathermoon Stronghold"), dock(1, -4348, 2444, 1108, "The Forgotten Coast") }, -- 303
    { "boat", "both", dock(1, -6933, -4951, 977, "Steamwheedle Port"), dock(0, -8232, -5801, 16727, "Powderfuse Port") }, -- 11391
    { "zeppelin", "horde", dock(1, 1318, -4658, 1637, "Orgrimmar"), UNDERCITY },            -- 302
    { "zeppelin", "horde", dock(1, 1361, -4631, 1637, "Orgrimmar"), GROMGOL_O },            -- 285
    { "zeppelin", "horde", UNDERCITY_G, GROMGOL_U },                                        -- 301
    { "zeppelin", "both", dock(0, 545, 424, 279, "Dalaran"), dock(2991, 1848, 569, 16638, "Valanaar") },            -- 11398
    { "zeppelin", "both", dock(1, -802, 367, 17045, "Skywatcher Plateau"), dock(2991, 1953, 1019, 16638, "Valanaar") }, -- 11457
}

local WORLD_MAP = 947        -- Azeroth, to tell which way a route leaves a continent
local NEAR = 0.02            -- a DaylightUI symbol this close (fraction of the map) is that dock
local THICK = 2.5
local SHADE = { 0, 0, 0, 0.6 } -- dark edge under each dash, so the line reads on any map
local STUB = 0.09            -- a route to another continent: this long on the map (fraction of its width)
local ICON = 18

local function secret(v) return issecretvalue and issecretvalue(v) end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function placeName(d)
    local name = call(C_Map.GetAreaInfo, d[4])
    if type(name) == "string" and name ~= "" and not secret(name) then return name end
    return d[5]
end

-- A dock's position on a map; may lie outside 0..1 when the dock is off it.
local projected = {}  -- [mapID][dock] = { x, y } or false
local function project(mapID, d)
    local byMap = projected[mapID]
    if not byMap then byMap = {}; projected[mapID] = byMap end
    local cached = byMap[d]
    if cached ~= nil then return cached or nil end
    local _, pos = call(C_Map.GetMapPosFromWorldPos, d[1], CreateVector2D(d[2], d[3]), mapID)
    local spot = false
    if type(pos) == "table" and type(pos.GetXY) == "function" then
        local x, y = pos:GetXY()
        if type(x) == "number" and type(y) == "number" and not secret(x) and not secret(y)
            and math.abs(x) < 20 and math.abs(y) < 20 then
            spot = { x, y }
        end
    end
    byMap[d] = spot
    return spot or nil
end

local function inside(p) return p and p[1] >= 0 and p[1] <= 1 and p[2] >= 0 and p[2] <= 1 end

-- Liang-Barsky: the part of a..b inside the map, as fractions t0, t1 of the way.
local function clip(ax, ay, bx, by)
    local t0, t1 = 0, 1
    local dx, dy = bx - ax, by - ay
    for _, edge in ipairs({ { -dx, ax }, { dx, 1 - ax }, { -dy, ay }, { dy, 1 - ay } }) do
        local p, q = edge[1], edge[2]
        if p == 0 then
            if q < 0 then return nil end
        else
            local r = q / p
            if p < 0 then
                if r > t1 then return nil elseif r > t0 then t0 = r end
            else
                if r < t0 then return nil elseif r < t1 then t1 = r end
            end
        end
    end
    return t0, t1
end

-- ---------------------------------------------------------------------
-- Drawing
-- ---------------------------------------------------------------------

local map, child, canvas, icons
local lines, buttons = {}, {}
local usedLines, usedButtons = 0, 0
local drawnMap, drawnW, drawnH, drawnScale
local focus             -- docks of the hovered Blasta symbol (continent and world maps)
local hovered           -- routes of the hovered DaylightUI symbol (zone maps)

-- Every route in DaylightUI's gold: one color reads at a glance on the map.
local function color()
    local c = Pins.COLORS.both
    return c[1], c[2], c[3]
end

local function line()
    usedLines = usedLines + 1
    local l = lines[usedLines]
    if not l then
        l = canvas:CreateLine(nil, "ARTWORK")
        lines[usedLines] = l
    end
    l:Show()
    return l
end

local function clearLines()
    for i = 1, usedLines do lines[i]:Hide() end
    usedLines = 0
end

local function clearDocks()
    for i = 1, usedButtons do buttons[i]:Hide(); buttons[i].docks = nil end
    usedButtons = 0
end

local function scale()
    local s = child:GetScale()
    return (s and s > 0) and 1 / s or 1
end

-- sub: the draw sublevel, so the color always lies over its dark edge.
local function stroke(x1, y1, x2, y2, r, g, b, a, thick, sub)
    local l = line()
    l:SetDrawLayer("ARTWORK", sub)
    l:SetColorTexture(r, g, b, a)
    l:SetThickness(thick)
    l:SetStartPoint("TOPLEFT", canvas, x1, -y1)
    l:SetEndPoint("TOPLEFT", canvas, x2, -y2)
end

-- A dark edge first, then the color over it.
local function segment(x1, y1, x2, y2, r, g, b, s)
    stroke(x1, y1, x2, y2, SHADE[1], SHADE[2], SHADE[3], SHADE[4], (THICK + 1.5) * s, 0)
    stroke(x1, y1, x2, y2, r, g, b, 1, THICK * s, 2)
end

-- One solid line in canvas units (y down), so a hovered route reads at a glance.
local function dashes(x1, y1, x2, y2, r, g, b, s)
    if (x2 - x1) ^ 2 + (y2 - y1) ^ 2 < 1 then return end
    segment(x1, y1, x2, y2, r, g, b, s)
end

-- An arrow head at (x, y) pointing along (ux, uy). No name: the symbol's
-- tooltip (DaylightUI's on zone maps) already says where it goes.
local function arrow(x, y, ux, uy, r, g, b, s)
    local size = 10 * s
    for _, turn in ipairs({ 2.6, -2.6 }) do
        local cs, sn = math.cos(turn), math.sin(turn)
        local vx, vy = ux * cs - uy * sn, ux * sn + uy * cs
        segment(x, y, x + vx * size, y + vy * size, r, g, b, s)
    end
end

-- Which way a route leaves this map toward a dock on another continent, from
-- the world map: a unit vector in canvas units, or nil.
local function heading(from, to)
    local a, b = project(WORLD_MAP, from), project(WORLD_MAP, to)
    if not (a and b) then return end
    -- The world map's canvas is about 3:2, like the continent and zone maps.
    local dx, dy = (b[1] - a[1]) * 1.5, b[2] - a[2]
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1e-6 then return end
    return dx / len, dy / len
end

local function drawRoute(route, fromDock)
    local mapID = drawnMap
    local w, h, s = drawnW, drawnH, scale()
    local here = fromDock or route[3]
    local there = here == route[3] and route[4] or route[3]
    local pa, pb = project(mapID, here), project(mapID, there)
    if not pa and pb then here, there, pa, pb = there, here, pb, pa end
    if not pa then return end
    local r, g, b = color(route)
    if pb then
        local t0, t1 = clip(pa[1], pa[2], pb[1], pb[2])
        if not t0 then return end
        local dx, dy = pb[1] - pa[1], pb[2] - pa[2]
        local x1, y1 = (pa[1] + dx * t0) * w, (pa[2] + dy * t0) * h
        local x2, y2 = (pa[1] + dx * t1) * w, (pa[2] + dy * t1) * h
        dashes(x1, y1, x2, y2, r, g, b, s)
        local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
        if len > 0 then
            local ux, uy = (x2 - x1) / len, (y2 - y1) / len
            if not inside(pb) then arrow(x2, y2, ux, uy, r, g, b, s) end
        end
        return
    end
    -- The other end isn't on this map at all (another continent): a short line
    -- the way it goes.
    if not inside(pa) then return end
    local ux, uy = heading(here, there)
    if not ux then return end
    local x1, y1 = pa[1] * w, pa[2] * h
    local x2, y2 = x1 + ux * STUB * w, y1 + uy * STUB * w
    local t0, t1 = clip(pa[1], pa[2], x2 / w, y2 / h)
    if t0 then x2, y2 = x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1 end
    dashes(x1, y1, x2, y2, r, g, b, s)
    arrow(x2, y2, ux, uy, r, g, b, s)
end

-- ---------------------------------------------------------------------
-- Dock symbols on continent and world maps
-- ---------------------------------------------------------------------

local function routesAt(d)
    local list = {}
    for _, route in ipairs(ROUTES) do
        if route[3] == d or route[4] == d then list[#list + 1] = route end
    end
    return list
end

local function tipFor(b)
    GameTooltip:Hide()
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    local Tips = DUI.Tips
    local seen = {}
    if Tips and Tips.Clear then Tips.Clear() end
    local first = true
    for _, d in ipairs(b.docks) do
        for _, route in ipairs(routesAt(d)) do
            local there = route[3] == d and route[4] or route[3]
            local name = placeName(there)
            local key = route[1] .. name
            if not seen[key] then
                seen[key] = true
                local text = (route[1] == "boat" and L["Boat to %s"] or L["Zeppelin to %s"]):format(name)
                if Tips and Tips.Title then
                    if not first and Tips.Gap then Tips.Gap() end
                    Tips.Title(text)
                else
                    GameTooltip:AddLine(text, 1, 1, 1)
                end
                first = false
            end
        end
    end
    if Tips and Tips.Flush then Tips.Flush(GameTooltip) end
    GameTooltip:Show()
end

-- Only the lines: the dock symbols stay as they are, so the one under the
-- mouse keeps its hover.
local function drawLines()
    if not canvas then return end
    clearLines()
    if not drawnMap then return end
    if focus then
        for _, d in ipairs(focus) do
            for _, route in ipairs(routesAt(d)) do drawRoute(route, d) end
        end
    elseif hovered then
        for _, entry in ipairs(hovered) do drawRoute(entry.route, entry.dock) end
    end
end

local function dockButton()
    usedButtons = usedButtons + 1
    local b = buttons[usedButtons]
    if not b then
        b = CreateFrame("Frame", nil, icons)
        b:SetSize(ICON, ICON)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints()
        b:EnableMouse(true)
        if b.SetMouseClickEnabled then b:SetMouseClickEnabled(false) end
        b:SetScript("OnEnter", function(self)
            focus = self.docks
            drawLines()
            tipFor(self)
        end)
        b:SetScript("OnLeave", function(self)
            focus = nil
            drawLines()
            GameTooltip:Hide()
        end)
        buttons[usedButtons] = b
    end
    b:Show()
    return b
end

-- One symbol per spot: docks that close on this map (a zeppelin tower) share one.
local function drawDocks()
    local spots = {}
    local s = scale()
    for _, route in ipairs(ROUTES) do
        do
            for i = 3, 4 do
                local d = route[i]
                local p = project(drawnMap, d)
                if inside(p) then
                    local spot
                    for _, other in ipairs(spots) do
                        if math.abs(other.x - p[1]) < 0.008 and math.abs(other.y - p[2]) < 0.008 then spot = other break end
                    end
                    if not spot then
                        spot = { x = p[1], y = p[2], docks = {}, kind = route[1] }
                        spots[#spots + 1] = spot
                    end
                    if not tContains(spot.docks, d) then spot.docks[#spot.docks + 1] = d end
                end
            end
        end
    end
    local size = ICON * ((Pins.Size and Pins.Size() or 24) / 24)
    for _, spot in ipairs(spots) do
        local b = dockButton()
        b.docks = spot.docks
        b:SetScale(s)
        b:SetSize(size, size)
        b.icon:SetTexture(DUI.MEDIA .. "mappin-" .. spot.kind .. ".png")
        b:SetAlpha(Pins.Alpha and Pins.Alpha() or 1)
        b:ClearAllPoints()
        b:SetPoint("CENTER", icons, "TOPLEFT", spot.x * drawnW / s, -spot.y * drawnH / s)
    end
end

-- ---------------------------------------------------------------------
-- When to draw
-- ---------------------------------------------------------------------

local function active()
    if not (enabled() and Pins.On() and Pins.Shows({ family = "travel" })) then return false end
    if DUI.OpenMap and DUI.OpenMap.Stitched and DUI.OpenMap.Stitched() then return false end
    return true
end

local MAP_ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3

local function level()
    local m = map and map.pinFrameLevelsManager
    local d = type(m) == "table" and type(m.definitions) == "table" and m.definitions.PIN_FRAME_LEVEL_DUNGEON_ENTRANCE
    return type(d) == "table" and type(d.startLevel) == "number" and d.startLevel or 2100
end

local function draw()
    if not canvas then return end
    clearLines()
    clearDocks()
    drawnMap = map and map.mapID
    drawnW, drawnH, drawnScale = child:GetWidth(), child:GetHeight(), child:GetScale()
    if not active() or type(drawnMap) ~= "number" or not drawnW or drawnW <= 0 then drawnMap = nil return end
    local info = call(C_Map.GetMapInfo, drawnMap)
    local mapType = type(info) == "table" and info.mapType
    canvas:SetFrameLevel(math.max(1, level() - 2))
    icons:SetFrameLevel(level())
    if type(mapType) == "number" and mapType < MAP_ZONE then
        -- Continent or world map: a symbol at each dock, routes on hover.
        drawDocks()
    else
        focus = nil
    end
    drawLines()
end

-- A DaylightUI symbol under the mouse: the routes from the docks it stands for.
local function hoverPin(pin)
    if not (active() and pin and pin.family == "travel" and type(pin.x) == "number") then return end
    local list = {}
    for _, route in ipairs(ROUTES) do
        for i = 3, 4 do
            local p = project(drawnMap or (map and map.mapID), route[i])
            if p and math.abs(p[1] - pin.x) < NEAR and math.abs(p[2] - pin.y) < NEAR then
                list[#list + 1] = { route = route, dock = route[i] }
                break
            end
        end
    end
    hovered = #list > 0 and list or nil
    drawLines()
end

local function leavePin()
    if not hovered then return end
    hovered = nil
    drawLines()
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookPins()
    local f = Pins.frame
    if not f then return end
    for _, b in ipairs({ f:GetChildren() }) do
        if not hooked[b] and b.HookScript then
            hooked[b] = true
            b:HookScript("OnEnter", function(self) hoverPin(self.pin) end)
            b:HookScript("OnLeave", leavePin)
        end
    end
end

local pendingPlace = false
local function relayout()
    if pendingPlace then return end
    pendingPlace = true
    C_Timer.After(0.03, function()
        pendingPlace = false
        if canvas and canvas:IsVisible() then draw() end
    end)
end

local function build()
    if canvas then return true end
    local f = _G.WorldMapFrame
    local sc = type(f) == "table" and f.ScrollContainer
    local c = type(sc) == "table" and sc.Child
    if type(c) ~= "table" then return false end
    map, child = f, c
    canvas = CreateFrame("Frame", nil, child)
    canvas:SetAllPoints(child)
    canvas:EnableMouse(false)
    icons = CreateFrame("Frame", nil, child)
    icons:SetAllPoints(child)
    icons:EnableMouse(false)
    canvas:SetScript("OnShow", draw)
    -- Zoom and canvas resizes have no callback: watched while the map is shown.
    canvas:SetScript("OnUpdate", function()
        if child:GetWidth() ~= drawnW or child:GetScale() ~= drawnScale then relayout() end
    end)
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("MapCanvas.MapSet", function()
            hovered, focus = nil, nil
            C_Timer.After(0, function() if canvas:IsVisible() then draw() end end)
        end, extras.TravelRoutes or {})
    end
    return true
end

extras.TravelRoutes = { routes = ROUTES }

local function setup()
    if not build() then return end
    hookPins()
    draw()
end

if Pins.Draw then hooksecurefunc(Pins, "Draw", function() if build() then hookPins(); draw() end end) end
DUI.On("Login", function() C_Timer.After(0, setup) end)
DUI.RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "Blizzard_WorldMap" then C_Timer.After(0, setup) end
end)
DUI.On("SettingChanged", function(scope, key)
    if (scope == ADDON and key == KEY) or scope == "Skins" then C_Timer.After(0, setup) end
end)

extras.Loaded("TravelRoutes")
