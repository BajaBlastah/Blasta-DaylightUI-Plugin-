-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
local DUI = DaylightUI
local dots = DUI.Dots
local unitFrames = DUI:GetModule("UnitFrames")
if not (unitFrames and unitFrames.defaults and unitFrames.defaults.colors
    and extras.FindSetting(unitFrames, "colors.dotTint")
    and dots and dots.Paint and dots.LayoutVeil and dots.NewVeil and dots.TintVeil
    and dots.Left and dots.KeyOf and dots.Parse and dots.PATTERNS) then return end

-- DaylightUI 1.9.4 no longer splits the damage left by kind (Dots.LeftByType),
-- so Blasta keeps its own small record of your finishers: the player's casts
-- stay readable, the description gives total and duration, and the damage
-- still to come is the share of the time left. It never exceeds what
-- DaylightUI says all your DoTs on the mob will still deal.
local finishers = {} -- mob key -> { [spell id] = { total, from, to } }
local function recordFinisher(id)
    local okD, desc = pcall(C_Spell.GetSpellDescription, id)
    if not okD or type(desc) ~= "string" or (issecretvalue and issecretvalue(desc)) then return end
    if not string.find(desc, dots.PATTERNS.finisher) then return end
    local points = dots.Combo and dots.Combo(id)
    local total, _, duration = dots.Parse(desc, points)
    local key = dots.KeyOf("target")
    if not (total and duration and duration > 0 and key) then return end
    local now = GetTime()
    finishers[key] = finishers[key] or {}
    finishers[key][id] = { total = total, from = now, to = now + duration }
end

local function finisherLeft(unit)
    local total = dots.Left(unit)
    local key = dots.KeyOf(unit)
    local list = key and finishers[key]
    if not total then
        if key then finishers[key] = nil end
        return nil
    end
    if not list then return total, 0 end
    local now, left = GetTime(), 0
    for id, f in pairs(list) do
        if now >= f.to then list[id] = nil
        else left = left + f.total * (f.to - now) / (f.to - f.from) end
    end
    if not next(list) then finishers[key] = nil end
    return total, math.min(total, math.floor(left + 0.5))
end

local own = type(dots.LeftByType) == "function" and dots.LeftByType or finisherLeft
if own == finisherLeft then
    local watch = CreateFrame("Frame")
    watch:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    watch:SetScript("OnEvent", function(_, _, _, _, id)
        if type(id) == "number" and DUI:Get("UnitFrames", "colors.blastaFinisherTintEnabled") == true then
            pcall(recordFinisher, id)
        end
    end)
    if dots.Forget then hooksecurefunc(dots, "Forget", function() finishers = {} end) end
end

local toggleKey, colorKey = "colors.blastaFinisherTintEnabled", "colors.blastaFinisherTint"
local defaultColor = { 0.85, 0.26, 0.12, 0.75 }
local label, colorLabel = "Separate finisher damage color", "Finisher damage color"
local desc = "Gives the remaining damage from combo-point finishers a separate color on the target and enemy nameplates."
unitFrames.defaults.colors.blastaFinisherTintEnabled = false
unitFrames.defaults.colors.blastaFinisherTint = defaultColor
extras.German[label] = "Eigene Farbe für Finisher-Schaden"
extras.German[colorLabel] = "Farbe für Finisher-Schaden"
extras.German[desc] = "Färbt den verbleibenden Schaden von Combopunkt-Finishern am Zielrahmen und auf gegnerischen Namensplaketten separat ein."
local destination = { page = "Auras", tab = "General", label = "Finisher damage" }
extras.German[destination.label] = "Finisher-Schaden"
extras.AddSetting(unitFrames, "colors.dotTint", {
    type = "toggle", key = toggleKey, label = label, desc = desc, blastaDestination = destination,
})
extras.AddSetting(unitFrames, toggleKey, {
    type = "color", key = colorKey, label = colorLabel, alpha = true, blastaDestination = destination,
    disabled = function(get) return get(toggleKey) ~= true end,
})

local function enabled()
    return DUI:Get("UnitFrames", toggleKey) == true
end

local states = setmetatable({}, { __mode = "k" })
local layout, paint = dots.LayoutVeil, dots.Paint
function dots.LayoutVeil(veil, health, growLeft)
    layout(veil, health, growLeft)
    local state = states[veil]
    if not state then
        state = {}
        states[veil] = state
    end
    state.health, state.growLeft, state.linked = health, growLeft, false
    if state.extra then layout(state.extra, health, growLeft) end
end

-- The finisher segment of a veil, for the nameplate shape's clipping.
function extras.FinisherVeil(veil)
    local state = veil and states[veil]
    return state and state.extra
end

local function restore(veil, state)
    if not (state and state.extra) then return end
    state.extra:Hide()
    if state.linked then layout(veil, state.health, state.growLeft) end
    veil.bar:Show()
    state.linked = false
end

function dots.Paint(unit, veil, skull)
    local state = veil and states[veil]
    local total, finisher
    if state and unit and enabled() then total, finisher = own(unit) end
    if not total or not finisher or finisher <= 0 then
        restore(veil, state)
        return paint(unit, veil, skull)
    end
    if not paint(unit, nil, skull) then
        restore(veil, state)
        veil:Hide()
        return false
    end

    local normal = total - finisher
    local extra = state.extra
    if not extra then
        extra = dots.NewVeil(state.health, 1)
        extra:SetParent(veil)
        extra:SetFrameLevel(veil:GetFrameLevel() + 1)
        state.extra = extra
        layout(extra, state.health, state.growLeft)
    end
    if extras.ClipPlateVeil then extras.ClipPlateVeil(state.health, extra) end
    local max = UnitHealthMax(unit)
    dots.TintVeil(extra, DUI:Get("UnitFrames", colorKey) or defaultColor)
    extra.bar:SetMinMaxValues(0, max)
    extra.bar:SetValue(finisher)
    extra.edge:SetShown(normal <= 0)
    extra:Show()
    if normal > 0 then
        if not state.linked then
            local lead = state.growLeft and "LEFT" or "RIGHT"
            local inner = state.growLeft and "RIGHT" or "LEFT"
            local fill = extra.bar:GetStatusBarTexture()
            veil.bar:ClearAllPoints()
            veil.bar:SetPoint("TOP" .. lead, fill, "TOP" .. inner)
            veil.bar:SetPoint("BOTTOM" .. lead, fill, "BOTTOM" .. inner)
            state.linked = true
        end
        veil.bar:SetMinMaxValues(0, max)
        veil.bar:SetValue(normal)
    end
    veil.bar:SetShown(normal > 0)
    veil:Show()
    return true
end

DUI.On("SettingChanged", function(scope, key)
    if scope == "UnitFrames" and (key == toggleKey or key == colorKey) then DUI.Fire("DotsChanged") end
end)

extras.Loaded("FinisherTint")
