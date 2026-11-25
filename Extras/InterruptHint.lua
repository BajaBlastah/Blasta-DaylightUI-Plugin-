-- SPDX-License-Identifier: GPL-3.0-or-later
-- Interrupt hint: an enemy's cast bar lights up while you could kick it right
-- now: the cast can be interrupted and your interrupt (DaylightUI.Interrupt:
-- the spell for your class, rank, stance or form) is ready. A light pulses on
-- the bar's fill, clipped to it like DaylightUI's own hit flash.
-- Whether a cast can be interrupted may be secret; it only goes to
-- SetAlphaFromBoolean, never compared in Lua.
local ADDON, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Nameplates")
local ns = mod and mod.ns
local Cast, Interrupt = ns and ns.Cast, DUI.Interrupt
if not (Cast and Cast.Update and Cast.Stop and Cast.Interrupted and Cast.ShowSample and Cast.Layout
    and Interrupt and Interrupt.Ready and Interrupt.Spell and mod.defaults
    and extras.FindSetting(mod, "castKickMark")) then return end

local VERSION = "1.9.8"
local german = extras.German
local isSecret = DUI.IsSecret or function() return false end

local ON, COLOR, ONLY, STRENGTH = "blastaKickHint", "blastaKickHintColor", "blastaKickHintTarget", "blastaKickHintPulse"
mod.defaults[ON] = false
mod.defaults[COLOR] = { 0.36, 1, 0.74, 0.55 }
mod.defaults[ONLY] = false
mod.defaults[STRENGTH] = "pulse"

local label = "Interrupt hint"
local desc = "An enemy's cast bar lights up while you could interrupt it right now: the cast can be interrupted and your interrupt is ready."
german[label] = "Unterbrechungs-Hinweis"
german[desc] = "Die Zauberleiste eines Gegners leuchtet auf, solange du sie jetzt unterbrechen kannst: Der Zauber ist unterbrechbar und deine Unterbrechung ist bereit."
german["Interrupt hint color"] = "Farbe des Unterbrechungs-Hinweises"
german["Only on your target"] = "Nur bei deinem Ziel"
german["Lights only your target's cast bar, not every enemy's."] = "Lässt nur die Zauberleiste deines Ziels aufleuchten, nicht die jedes Gegners."
german["Interrupt hint look"] = "Aussehen des Unterbrechungs-Hinweises"
german["Pulse"] = "Pulsieren"
german["Steady light"] = "Gleichmäßiges Leuchten"
german["Interrupts"] = "Unterbrechungen"

local function off(get) return get(ON) ~= true end
local rows = {
    { type = "toggle", key = ON, label = label, desc = desc, blastaSince = VERSION },
    { type = "color", key = COLOR, label = "Interrupt hint color", alpha = true, disabled = off, blastaSince = VERSION },
    { type = "dropdown", key = STRENGTH, label = "Interrupt hint look", values = { pulse = "Pulse", steady = "Steady light" },
      order = { "pulse", "steady" }, disabled = off, blastaSince = VERSION },
    { type = "toggle", key = ONLY, label = "Only on your target", desc = "Lights only your target's cast bar, not every enemy's.",
      disabled = off, blastaSince = VERSION },
}
local anchor = "castKickMark"
for _, row in ipairs(rows) do
    extras.AddSetting(mod, anchor, row)
    anchor = row.key
end

local function cfg() return ns.cfg or mod.db or mod.defaults end

-- One light per cast bar, on the bar like DaylightUI's hit flash, with the
-- same masks (the fill's moving edge, Blasta's slanted ends).
local lights = setmetatable({}, { __mode = "k" })
local function lightOf(c)
    local t = lights[c]
    if t then return t end
    t = c.bar:CreateTexture(nil, "ARTWORK", nil, 2)
    t:SetTexture("Interface\\Buttons\\WHITE8x8")
    t:SetBlendMode("ADD")
    t:SetAllPoints(c.bar:GetStatusBarTexture())
    t:SetAlpha(0)
    t:Hide()
    t.masks = {}
    lights[c] = t
    return t
end

local function copyMasks(c, t)
    local light = c.light
    if not (light and light.GetNumMaskTextures and t.AddMaskTexture) then return end
    for i = 1, light:GetNumMaskTextures() or 0 do
        local m = light:GetMaskTexture(i)
        if m and not t.masks[m] then
            if pcall(t.AddMaskTexture, t, m) then t.masks[m] = true end
        end
    end
end

local active = {}   -- cast bar -> { ni = flag, sample = bool }
local ticker = CreateFrame("Frame")
ticker:Hide()
local clock = 0

local function paint(c, state, k)
    local t = lights[c]
    if not t then return end
    local col = cfg()[COLOR] or mod.defaults[COLOR]
    local a = (col[4] or 1) * k
    if state.sample or not state.ni or (not isSecret(state.ni) and state.ni == false) then
        t:SetAlpha(a)
    elseif t.SetAlphaFromBoolean then
        if not pcall(t.SetAlphaFromBoolean, t, state.ni, 0, a) then t:SetAlpha(0) end
    elseif not isSecret(state.ni) then
        t:SetAlpha(state.ni == true and 0 or a)
    else
        t:SetAlpha(0)
    end
end

local function level()
    if cfg()[STRENGTH] == "steady" or not (DUI.Motion and DUI.Motion.On and DUI.Motion.On()) then return 1 end
    return 0.45 + 0.55 * (0.5 + 0.5 * math.sin(clock * 2 * math.pi / 0.9))
end

ticker:SetScript("OnUpdate", function(self, dt)
    clock = clock + (dt or 0)
    if next(active) == nil then self:Hide(); return end
    local k = level()
    for c, state in pairs(active) do
        if not pcall(paint, c, state, k) then active[c] = nil end
    end
end)

local function hide(c)
    active[c] = nil
    local t = lights[c]
    if t then t:SetAlpha(0); t:Hide() end
end

local function isTarget(unit)
    if not unit then return false end
    local ok, same = pcall(UnitIsUnit, unit, "target")
    if not ok then return false end
    if isSecret(same) then return true end   -- can't tell: show it
    return same == true
end

local function show(c, ni, sample)
    local t = lightOf(c)
    copyMasks(c, t)
    local col = cfg()[COLOR] or mod.defaults[COLOR]
    t:SetVertexColor(col[1], col[2], col[3])
    t:Show()
    active[c] = { ni = ni, sample = sample }
    paint(c, active[c], level())
    if not ticker:IsShown() then ticker:Show() end
end

-- Whether p's running cast gets the light now.
local function update(p)
    local c = p and p.cast
    if not c then return end
    local db = cfg()
    if db[ON] ~= true or p.friendly or not c.duration or c.interrupted or c.leaving then return hide(c) end
    if Interrupt.Ready() ~= true then return hide(c) end
    if db[ONLY] == true and not isTarget(p.unit) then return hide(c) end
    show(c, c.notInterruptible, false)
end

local plates = setmetatable({}, { __mode = "k" })   -- plates seen casting
local function all()
    for p in pairs(plates) do pcall(update, p) end
end

hooksecurefunc(Cast, "Update", function(p) plates[p] = true; pcall(update, p) end)
hooksecurefunc(Cast, "Stop", function(p) if p and p.cast then hide(p.cast) end end)
hooksecurefunc(Cast, "Interrupted", function(p) if p and p.cast then hide(p.cast) end end)
hooksecurefunc(Cast, "ShowSample", function(p, s)
    local c = p and p.cast
    if not c then return end
    if s and cfg()[ON] == true then show(c, false, true) else hide(c) end
end)
DUI.On("InterruptChanged", all)
DUI.RegisterEvent("PLAYER_TARGET_CHANGED", function() if cfg()[ONLY] == true then all() end end)
DUI.On("SettingChanged", function(scope, key)
    if scope == "Nameplates" and (key == ON or key == COLOR or key == ONLY or key == STRENGTH) then all() end
end)

extras.Loaded("InterruptHint")
