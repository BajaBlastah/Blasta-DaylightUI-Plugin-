-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
local DUI = DaylightUI
local dots, style = DUI.Dots, DUI.Style
local units, plates = extras.Compatible("UnitFrames"), extras.Compatible("Nameplates")
local mod = DUI:GetModule("UnitFrames")
if not (mod and mod.defaults and mod.defaults.colors and dots and dots.NewSkull
    and extras.FindSetting(mod, "colors.dotTint")) then return end

local enabledKey, damageKey = "colors.blastaDeathHelper", "colors.blastaDeathDamage"
local destination = { page = "Auras", tab = "General", label = "Finisher damage" }
local label, override = "Shadow Word: Death kill estimate", "Manual damage threshold"
local desc = "Marks the target's current-health threshold for a likely killing blow on the target frame and enemy nameplates."
local manualDesc = "Set an absolute damage threshold in health points. Set 0 to use the lower tooltip damage with a 15% margin."
extras.German[destination.label] = "Finisher-Schaden"
extras.German[label] = "Schattenwort: Tod – Tötungshilfe"
extras.German[override] = "Manuelle Schadensschwelle"
extras.German[desc] = "Markiert am Zielrahmen und auf gegnerischen Namensplaketten, ab welchen aktuellen Lebenspunkten ein Treffer voraussichtlich tödlich ist."
extras.German[manualDesc] = "Legt die Schwelle in Lebenspunkten fest. Bei 0 gilt der untere Tooltip-Schadenswert mit 15 % Puffer."
mod.defaults.colors.blastaDeathHelper = false
mod.defaults.colors.blastaDeathDamage = 0
extras.AddSetting(mod, "colors.dotTint", {
    type = "toggle", key = enabledKey, label = label, desc = desc, blastaDestination = destination,
})
extras.AddSetting(mod, enabledKey, {
    type = "slider", key = damageKey, label = override, desc = manualDesc, min = 0, max = 10000, step = 5,
    blastaDestination = destination, disabled = function(get) return get(enabledKey) ~= true end,
})

local secret = DUI.IsSecret
local function number(v) return type(v) == "number" and not secret(v) end
local function enabled() return DUI:Get("UnitFrames", enabledKey) == true end

-- The first four IDs are the Forever ranks, ordered from highest to lowest.
local ranks = { 1309636, 1309635, 1309633, 1309595, 32996, 32379 }
local function knownSpell()
    if not (C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellCooldown
        and C_Spell.IsSpellUsable and C_Spell.IsSpellInRange) then return end
    local _, class = UnitClass("player")
    if secret(class) or class ~= "PRIEST" then return end
    local known = C_SpellBook and C_SpellBook.IsSpellKnown or IsPlayerSpell
    if not known then return end
    for _, id in ipairs(ranks) do
        local ok, yes = pcall(known, id)
        if ok and not secret(yes) and yes == true then return id end
    end
end

local function tooltipThreshold(text)
    if type(text) ~= "string" or secret(text) then return end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("\194\160", " "):gsub("\226\128\175", " "):gsub("–", "-"):gsub("—", "-")
    local count
    repeat
        text, count = text:gsub("(%d)[., ](%d%d%d)%f[%D]", "%1%2")
    until count == 0
    local first = text:match("^[^%.\n]+")
    if not first then return end
    first = first:lower()
    local school = first:find("schattenschaden", 1, true) and "schattenschaden" or "shadow damage"
    local suffix = "[%s%a%(%)]+"
    local low = first:match("(%d+)%s*%-%s*%d+" .. suffix .. school)
        or first:match("(%d+)%s+bis%s+%d+" .. suffix .. school)
        or first:match("(%d+)%s+bis%s+zu%s+%d+" .. suffix .. school)
        or first:match("(%d+)%s+to%s+%d+" .. suffix .. school)
        or first:match("(%d+)%s+" .. school)
        or first:match("(%d+)%s+punkt[%a%(%)]+%s+" .. school)
    local amount = tonumber(low)
    if amount and amount > 0 then return math.floor(amount * 0.85) end
end

local spell, threshold, ticker
local function canCast(id)
    local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
    if not ok or type(cd) ~= "table" or secret(cd) or secret(cd.isActive) or cd.isActive ~= false
        or secret(cd.isEnabled) or cd.isEnabled == false then return false end
    local readable, usable = pcall(C_Spell.IsSpellUsable, id)
    return readable and not secret(usable) and usable == true
end

local WHITE = "Interface\\Buttons\\WHITE8x8"

-- How far the top and the bottom of the edge sit from its straight line, in the
-- bar's units: one of them 0, the other the cut toward the bar's start.
local function lean(bar, growLeft)
    local m = style.GetFillMask and style.GetFillMask(bar)
    local cut = m and m.added and type(m.cut) == "number" and m.cut > 0 and m.cut or 0
    if cut == 0 then return 0, 0 end
    local back = growLeft and cut or -cut
    if m.under == true then return back, 0 end
    return 0, back
end

-- A texture's top and bottom moved sideways (the client's vertex offsets:
-- 1 upper left, 2 lower left, 3 upper right, 4 lower right).
local function shear(tex, top, bottom)
    if not tex.SetVertexOffset then return end
    pcall(tex.SetVertexOffset, tex, 1, top, 0)
    pcall(tex.SetVertexOffset, tex, 3, top, 0)
    pcall(tex.SetVertexOffset, tex, 2, bottom, 0)
    pcall(tex.SetVertexOffset, tex, 4, bottom, 0)
end
local markers = setmetatable({}, { __mode = "k" })
-- The raid marker ring (TargetMarkerRing.lua) opens over the target frame's
-- health bar: the marker on that bar fades out under it and back after.
local targetAlpha = 1
function extras.TargetDeathMarkerAlpha(alpha)
    targetAlpha = alpha
    local target = units and units.frames and units.frames.target
    local pin = target and markers[target.health]
    if pin then pin:SetAlpha(alpha) end
end
local function marker(bar)
    local pin = CreateFrame("StatusBar", nil, bar)
    pin:SetAllPoints(bar)
    pin:SetFrameLevel(bar:GetFrameLevel() + 6)
    pin:SetStatusBarTexture(WHITE)
    pin:SetStatusBarColor(0, 0, 0, 0)
    local line = pin:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(0.77, 0.60, 1, 0.56)
    local hot = dots.NewSkull(pin, 3)
    hot.icon:SetTexture(WHITE)
    hot.icon:SetVertexColor(0.97, 0.86, 1, 1)
    hot:SetFrameLevel(pin:GetFrameLevel() + 1)
    pin.line, pin.hot = line, hot
    markers[bar] = pin
    local target = units and units.frames and units.frames.target
    if target and bar == target.health then pin:SetAlpha(targetAlpha) end
    return pin
end

local function draw(bar, growLeft, max, current, damage, ready)
    local pin = markers[bar] or marker(bar)
    local h, pixel = bar:GetHeight(), DUI.Pixel.Px(bar, 1)
    local edge = growLeft and "LEFT" or "RIGHT"
    local line, hot = pin.line, pin.hot
    local top, bottom = lean(bar, growLeft)
    if pin.edge ~= edge or pin.height ~= h or pin.pixel ~= pixel or pin.top ~= top or pin.bottom ~= bottom then
        pin.edge, pin.height, pin.pixel, pin.top, pin.bottom = edge, h, pixel, top, bottom
        line:ClearAllPoints()
        line:SetPoint("TOP", pin:GetStatusBarTexture(), "TOP" .. edge)
        line:SetPoint("BOTTOM", pin:GetStatusBarTexture(), "BOTTOM" .. edge)
        line:SetWidth(pixel)
        shear(line, top, bottom)
        -- The glow leans the same way. Its window (it clips) is widened by the
        -- cut, with the glow's straight side at the window's right edge.
        local cut = math.abs(top - bottom)
        local right = math.max(top, bottom)
        hot:ClearAllPoints()
        hot:SetPoint("RIGHT", line, "CENTER", right + 1.5 * pixel, 0)
        hot:SetSize(3 * pixel + cut, h)
        hot.icon:SetSize(3 * pixel, h)
        shear(hot.icon, top - right, bottom - right)
        hot.bar:SetHeight(h)
        pin:SetReverseFill(growLeft)
    end
    pin:SetMinMaxValues(0, max)
    pin:SetValue(damage)
    pin:Show()
    if ready and (not number(current) or current <= damage) then
        -- Native clipped-bar threshold, so restricted health stays in the UI.
        hot.bar:SetMinMaxValues(0, current)
        hot.bar:SetValue(damage)
        hot:Show()
    else
        hot:Hide()
    end
end

local function hide(bar)
    if bar and markers[bar] then markers[bar]:Hide() end
end

local function update(bar, unit, growLeft, ready)
    if not bar then return end
    if not (unit and bar:IsVisible() and threshold and threshold > 0) then return hide(bar) end
    local dead = UnitIsDeadOrGhost(unit)
    local hostile = UnitCanAttack("player", unit)
    if secret(hostile) or hostile ~= true or (not secret(dead) and dead == true) then return hide(bar) end
    local max, current = UnitHealthMax(unit), UnitHealth(unit)
    if type(max) ~= "number" or type(current) ~= "number" or (number(max) and max <= 0)
        or (number(current) and current <= 0) then return hide(bar) end
    if ready and (not number(current) or current <= threshold) then
        local ok, inRange = pcall(C_Spell.IsSpellInRange, spell, unit)
        ready = ok and not secret(inRange) and inRange == true
    end
    draw(bar, growLeft, max, current, threshold, ready)
end

-- One plate callback for the whole session instead of a new closure on
-- every tick (five times a second while the marker is active).
local plateReady
local function updatePlate(p)
    update(p.health, not p.friendly and not p.corpse and p.unit or nil, false, plateReady)
end

local function refresh()
    local ready = spell and threshold and canCast(spell)
    local target = units and units.frames and units.frames.target
    if target then update(target.health, target.unitToken, target.growLeft == true, ready) end
    if plates and plates.Manager and plates.Manager.Each then
        plateReady = ready
        plates.Manager.Each(updatePlate)
    end
end

local function estimate()
    if not spell then return end
    local manual = DUI:Get("UnitFrames", damageKey)
    if number(manual) and manual > 0 then return manual end
    local ok, text = pcall(C_Spell.GetSpellDescription, spell)
    if ok then return tooltipThreshold(text) end
end

local function reconcile()
    spell = enabled() and knownSpell() or nil
    threshold = estimate()
    if threshold and not ticker then ticker = C_Timer.NewTicker(0.2, refresh) end
    if not threshold and ticker then ticker:Cancel(); ticker = nil end
    refresh()
end

for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "GET_SPELL_DATA_LOAD_RESULT",
    "PLAYER_EQUIPMENT_CHANGED", "PLAYER_DAMAGE_DONE_MODS" }) do
    DUI.RegisterEvent(event, reconcile)
end
DUI.RegisterEvent("PLAYER_TARGET_CHANGED", function() if ticker then refresh() end end)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", reconcile)
DUI.On("Login", reconcile)
DUI.On("SettingChanged", function(scope, key)
    if scope == "UnitFrames" and (key == enabledKey or key == damageKey) then reconcile() end
end)
if plates and plates.Plate and plates.Plate.Uninstall then
    hooksecurefunc(plates.Plate, "Uninstall", function(p) hide(p.health) end)
end

local panel, button, previewRequest
local previewLabel = "Preview Shadow Word: Death"
extras.German[previewLabel] = "Vorschau für Schattenwort: Tod"
extras.German["Above the threshold"] = "Über der Schwelle"
extras.German["Estimated killing blow"] = "Voraussichtlich tödlich"
local function preview()
    if not button then return end
    if not panel then
        panel = CreateFrame("Frame", nil, UIParent)
        panel:SetSize(208, 76)
        panel:SetFrameStrata("TOOLTIP")
        style.Shell(panel)
        for index, title in ipairs({ "Above the threshold", "Estimated killing blow" }) do
            local text = style.Text(panel, 11, "LEFT")
            text:SetPoint("TOPLEFT", panel, "TOPLEFT", 9, -7 - (index - 1) * 33)
            text:SetText(extras.Translate(title))
            local bar = style.Bar(panel)
            bar:SetPoint("TOPLEFT", panel, "TOPLEFT", 9, -21 - (index - 1) * 33)
            bar:SetSize(190, 10)
            bar:SetMinMaxValues(0, 1000)
            local health = index == 1 and 410 or 230
            bar:SetValue(health)
            style.SetBarColor(bar, 0.37, 0.53, 0.45)
            local veil = dots.NewVeil(bar, 1)
            dots.LayoutVeil(veil, bar, false)
            dots.PaintSample(veil, nil, 1000, index == 1 and 200 or 35, false)
            draw(bar, false, 1000, health, 250, true)
        end
    end
    panel:ClearAllPoints()
    if (button:GetTop() or 0) + 82 < UIParent:GetTop() then
        panel:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 5)
    else
        panel:SetPoint("TOPRIGHT", button, "BOTTOMRIGHT", 0, -5)
    end
    panel:Show()
    local request = {}
    previewRequest = request
    C_Timer.After(5, function()
        if previewRequest == request then panel:Hide() end
    end)
end
extras.AddSetting(mod, damageKey, {
    type = "button", key = "colors.blastaDeathPreview", label = previewLabel, text = "Preview",
    blastaDestination = destination, func = preview,
    built = function(control)
        button = control
        control:HookScript("OnHide", function()
            if button == control and panel then panel:Hide() end
        end)
    end,
})

extras.Loaded("ShadowWordDeath")
