-- Blasta's additions to DaylightUI's zone title (QoL > Zone title animation).
-- Each one is its own switch, all off at first:
--   level range  "Level 10–20" under the title, colored like a quest of that level
--   discovered   "Discovered" over the name when the game counts a place as newly explored
--   resting      "Resting" when you step into an inn or a city
local ADDON, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("QoL")
local ZoneTitle = ns and ns.ZoneTitle
if not (ZoneTitle and ZoneTitle.Play and ZoneTitle.Sub) then return end

local Style, Motion = DUI.Style, DUI.Motion
local ROOT = "zoneTitleExtras"
local defaults = { levels = false, discovered = false, resting = false }
extras.ZoneTitleExtrasDefaults = defaults

local REST_COLOR = { 0.45, 0.68, 1 }
local LINE_SIZE, TAG_SIZE = 13, 12

local function on(field)
    local v = DUI:Get(ADDON, ROOT .. "." .. field)
    if v == nil then return defaults[field] end
    return v == true
end

local function secret(v) return DUI.IsSecret and DUI.IsSecret(v) end

local line, tag
local parts = {}
local function title() return _G.DaylightUIZoneTitle end

local function build()
    local f = title()
    if not f then return end
    if not line then
        line = Style.Text(f, LINE_SIZE, "CENTER")
        tag = Style.Text(f, TAG_SIZE, "CENTER")
    end
    return f
end

-- Under the lowest of the title's lines that has text.
local function placeLine(f)
    line:ClearAllPoints()
    local below
    if f.pvp and (f.pvp:GetText() or "") ~= "" then below = f.pvp
    elseif f.sub and (f.sub:GetText() or "") ~= "" then below = f.sub end
    if below then line:SetPoint("TOP", below, "BOTTOM", 0, -4)
    else line:SetPoint("TOP", f, "CENTER", 0, -8) end
end

local function placeTag(f)
    tag:ClearAllPoints()
    if f.name and (f.name:GetText() or "") ~= "" then tag:SetPoint("BOTTOM", f.name, "TOP", 0, 4)
    else tag:SetPoint("BOTTOM", f.sub, "TOP", 0, 4) end
end

local function colored(text, c) return ("|cff%02x%02x%02x%s|r"):format(c[1] * 255, c[2] * 255, c[3] * 255, text) end

local function showLine(fade)
    local f = build()
    if not f then return end
    local list = {}
    if parts.level then list[#list + 1] = parts.level end
    if parts.rest then list[#list + 1] = parts.rest end
    line:SetText(table.concat(list, "  ·  "))
    placeLine(f)
    if #list > 0 and fade then Motion.Fade(line, 0, 1, Motion.NORMAL) end
end

-- A new show: nothing of the last one stays.
local function reset()
    parts = {}
    if line then
        line:SetText("")
        tag:SetText("")
        Motion.Fade(line, 0, 0, 0)
        Motion.Fade(tag, 0, 0, 0)
    end
end

local function levelText()
    if not (on("levels") and extras.CurrentZoneLevels) then return end
    local low, high = extras.CurrentZoneLevels()
    if not low then return end
    local text = ("%s %d–%d"):format(LEVEL or "Level", low, high)
    if low == high then text = ("%s %d"):format(LEVEL or "Level", low) end
    local c
    if GetQuestDifficultyColor then
        local q = GetQuestDifficultyColor(math.floor((low + high) / 2))
        if q then c = { q.r, q.g, q.b } end
    end
    return c and colored(text, c) or text
end

-- "Discovered": the game's explore message names the place. It can come a
-- moment before or after the title, so it waits a little for one.
local discovered   -- { name, at }
local function showTag()
    local f = build()
    if not (f and f:IsShown()) then return false end
    tag:SetText(extras.Translate("Discovered"))
    local r, g, b = Style.Accent()
    tag:SetTextColor(r, g, b)
    placeTag(f)
    Motion.Fade(tag, 0, 1, Motion.NORMAL)
    discovered = nil
    return true
end
local function freshDiscovery()
    return discovered and GetTime() - discovered.at < 3
end

local play, sub = ZoneTitle.Play, ZoneTitle.Sub
ZoneTitle.Play = function(...)
    reset()
    play(...)
    local f = title()
    if not (f and f:IsShown()) then return end
    parts.level = levelText()
    if parts.level then C_Timer.After(0.3, function() if f:IsShown() then showLine(true) end end) end
    if freshDiscovery() then showTag() end
end
ZoneTitle.Sub = function(text, ...)
    local f = title()
    local inPlace = f and f:IsShown() and (f.name:GetText() or "") ~= ""
    if not inPlace then reset() end
    sub(text, ...)
    f = title()
    if f and f:IsShown() then
        if line then placeLine(f) end
        if freshDiscovery() then showTag() end
    end
end

-- A global format string ("Discovered %s: %d experience gained", maybe with
-- numbered arguments) as a Lua pattern.
local patterns = {}
local function toPattern(fmt)
    if type(fmt) ~= "string" then return end
    if patterns[fmt] then return patterns[fmt] end
    local out, i = { "^" }, 1
    while i <= #fmt do
        local a, b, _, conv = fmt:find("^%%(%d*)%$?([sd])", i)
        if a then
            out[#out + 1] = conv == "d" and "[%d%.,]+" or ".+"
            i = b + 1
        else
            local c = fmt:sub(i, i)
            out[#out + 1] = c:find("^[%^%$%(%)%%%.%[%]%*%+%-%?]") and "%" .. c or c
            i = i + 1
        end
    end
    patterns[fmt] = table.concat(out)
    return patterns[fmt]
end

local function readExplore(...)
    if not on("discovered") then return end
    for i = 1, select("#", ...) do
        local text = select(i, ...)
        if type(text) == "string" and not secret(text) then
            for _, fmt in ipairs({ ERR_ZONE_EXPLORED_XP, ERR_ZONE_EXPLORED }) do
                local pattern = toPattern(fmt)
                if pattern then
                    if text:match(pattern) then
                        discovered = { at = GetTime() }
                        showTag()
                        return
                    end
                end
            end
        end
    end
end
DUI.RegisterEvent("UI_INFO_MESSAGE", function(_, ...) readExplore(...) end)
DUI.RegisterEvent("CHAT_MSG_SYSTEM", function(_, ...) readExplore(...) end)

-- Resting: when you step into an inn or a city, not at login.
local resting = IsResting and IsResting() == true
DUI.RegisterEvent("PLAYER_UPDATE_RESTING", function()
    local now = IsResting and IsResting() == true
    local was = resting
    resting = now
    if not now or was or not on("resting") then return end
    local qol = DUI:GetModule("QoL")
    if not (qol and qol.enabled and qol.db and qol.db.zoneTitle == true) then return end
    local f = title()
    local rest = colored(extras.Translate("Resting"), REST_COLOR)
    if f and f:IsShown() and line then
        parts.rest = rest
        showLine(true)
        return
    end
    local place = GetSubZoneText and GetSubZoneText()
    if type(place) ~= "string" or secret(place) or place == "" then place = GetZoneText and GetZoneText() end
    if type(place) ~= "string" or secret(place) or place == "" then return end
    ZoneTitle.Sub(place)
    f = build()
    if f and f:IsShown() then
        parts.rest = rest
        showLine(true)
    end
end)
DUI.RegisterEvent("PLAYER_ENTERING_WORLD", function() resting = IsResting and IsResting() == true end)

function extras.ZoneTitleExtrasGroup()
    local function off() local q = DUI:GetModule("QoL"); return not (q and q.db and q.db.zoneTitle == true) end
    return { label = "Zone title extras", items = {
        { type = "toggle", key = ROOT .. ".levels", label = "Show the zone's level range",
            desc = "Under the zone title, the levels the zone is meant for, colored like a quest of that level: red is dangerous, yellow just right, green and grey easy.",
            disabled = off },
        { type = "toggle", key = ROOT .. ".discovered", label = "Mark newly discovered places",
            desc = "When the game counts a place as newly explored, \"Discovered\" shows over its name.",
            disabled = off },
        { type = "toggle", key = ROOT .. ".resting", label = "Show when you start resting",
            desc = "Stepping into an inn or a city shows the place's name with \"Resting\" under it.",
            disabled = off },
        { type = "button", label = "Preview the zone title", text = "Preview",
            desc = "Plays DaylightUI's zone title for where you are, with the extras that are on.",
            func = function()
                local zone = GetZoneText and GetZoneText()
                if type(zone) ~= "string" or zone == "" or secret(zone) then ZoneTitle.Preview(); return end
                local subzone = GetSubZoneText and GetSubZoneText() or ""
                local pvp, color = ZoneTitle.PvP()
                if on("discovered") then discovered = { at = GetTime() } end
                ZoneTitle.Play(zone, subzone ~= zone and subzone or "", pvp ~= "" and pvp or nil, color)
                if on("resting") and IsResting and IsResting() then
                    parts.rest = colored(extras.Translate("Resting"), REST_COLOR)
                    C_Timer.After(0.35, function() showLine(true) end)
                end
            end },
    } }
end

extras.Loaded("ZoneTitleExtras")
