local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Nameplates")
local plate = mod and mod.ns and mod.ns.Plate
if not (plate and plate.PaintThreatPct and plate.UpdateThreatPct and mod.defaults) then return end

local show, items, index = extras.FindSetting(mod, "threatPct")
if not show then return end

local gradient, reverse = "blastaThreatGradient", "blastaThreatReverse"
mod.defaults[gradient] = false
mod.defaults[reverse] = true
local rawThreat, displayMode = "blastaThreatRaw", "blastaThreatDisplay"
mod.defaults[displayMode] = "legacy"
mod.defaults[rawThreat] = false
local L = extras.German
L["Threat % on enemy nameplates"] = "Bedrohung in % auf gegnerischen Namensplaketten"
L["Enable the threat number and drag it on the nameplate preview in Design mode."] =
    "Aktiviert die Bedrohungszahl. Ziehe sie im Designer auf der Namensplaketten-Vorschau an die gewünschte Stelle."
L["Threat state colors"] = "Farben nach Aggro-Status"
L["Color the number by who holds aggro and whether it is about to change."] = "Färbt die Zahl danach, wer Aggro hat und ob ein Wechsel droht."
L["Green while holding aggro"] = "Grün bei eigener Aggro"
L["Green for stable aggro and red when someone else has it. Turn off to swap green and red."] = "Grün bei stabiler Aggro und Rot, wenn jemand anderes Aggro hat. Ausschalten vertauscht Grün und Rot."

-- Share the native option and designer position, including existing profiles.
local toggle = {}
for key, value in pairs(show) do toggle[key] = value end
toggle.label = "Threat % on enemy nameplates"
toggle.desc = "Enable the threat number and drag it on the nameplate preview in Design mode."
toggle.blastaCopy = true
toggle.blastaDesignerKeys = { "threatPctPos", "threatPctX", "threatPctY" }
table.insert(items, index + 1, toggle)
local version = "1.9.8"
local function disabled(get) return get("threatPct") ~= true end
extras.AddSetting(mod, "threatPct", {
    type = "toggle", key = gradient, label = "Threat state colors",
    desc = "Color the number by who holds aggro and whether it is about to change.", disabled = disabled, blastaSince = version,
})
extras.AddSetting(mod, gradient, {
    type = "toggle", key = reverse, label = "Green while holding aggro",
    desc = "Green for stable aggro and red when someone else has it. Turn off to swap green and red.", blastaSince = version,
    disabled = function(get) return disabled(get) or get(gradient) ~= true end,
})

L["Threat display"] = "Bedrohungsanzeige"
L["Pull threshold"] = "Aggro-Schwelle (normal)"
L["Relative threat"] = "Relative Bedrohung"
L["Both threat values"] = "Beide Werte"
L["%.0f%% (%.0f%% relative)"] = "%.0f%% (%.0f%% relativ)"

-- Keep the meaning of the old switch for profiles that have not picked a mode.
local function modeOf(mode, legacyRaw)
    if mode == "scaled" or mode == "raw" or mode == "both" then return mode end
    return legacyRaw == true and "both" or "scaled"
end

extras.AddSetting(mod, reverse, {
    type = "dropdown", key = displayMode, label = "Threat display",
    values = { scaled = "Pull threshold", raw = "Relative threat", both = "Both threat values" },
    order = { "scaled", "raw", "both" },
    get = function() return modeOf(DUI:Get(mod.name, displayMode), DUI:Get(mod.name, rawThreat)) end,
    set = function(value) return DUI:Set(mod.name, displayMode, value) end,
    default = function() return "scaled" end,
    disabled = disabled, blastaSince = version,
})

local function paintState(text, state, db)
    if state == "warn" then
        text:SetTextColor(1, 0.83, 0.17)
    elseif state == "aggro" or state == "lost" then
        local green = (state == "aggro") == (db[reverse] ~= false)
        if green then text:SetTextColor(0.25, 1, 0.18)
        else text:SetTextColor(1, 0.27, 0.24) end
    else
        text:SetTextColor(0.65, 0.70, 0.76)
    end
end

-- DaylightUI's preview already passes the state selected in its threat chips.
hooksecurefunc(plate, "PaintThreatPct", function(text, _, state)
    local db = mod.db
    if db and db[gradient] == true and state then paintState(text, state, db) end
end)

local function readableNumber(value)
    return type(value) == "number" and not DUI.IsSecret(value)
end

hooksecurefunc(plate, "UpdateThreatPct", function(p)
    local db, text = mod.db, p.threatPct
    if not (db and p.threatPctOn and text and text:IsShown() and p.unit
        and type(UnitDetailedThreatSituation) == "function") then return end
    local mode = modeOf(db[displayMode], db[rawThreat])
    if mode == "scaled" and not db[gradient] and p.isTarget ~= true then return end
    -- Match the target frame on the current target. Other plates use their
    -- own unit token. Both display the game's scaled pull percentage.
    local unit = p.isTarget == true and "target" or p.unit
    local ok, tanking, status, scaled, raw = pcall(UnitDetailedThreatSituation, "player", unit)
    if not ok then return end
    if mode == "raw" then
        if type(raw) == "number" then
            text:SetFormattedText("%.0f%%", raw)
        else
            text:SetText("—")
        end
    elseif mode == "both" and type(scaled) == "number" and type(raw) == "number" then
        text:SetFormattedText(extras.Translate("%.0f%% (%.0f%% relative)"), scaled, raw)
    elseif unit == "target" and type(scaled) == "number" then
        if DUI.IsSecret(scaled) then
            text:SetFormattedText("%.0f%%", scaled)
        else
            text:SetFormattedText("%d%%", math.floor(scaled + 0.5))
        end
    end
    if db[gradient] ~= true then return end
    if not readableNumber(status) and type(UnitThreatSituation) == "function" then
        local known, unitStatus = pcall(UnitThreatSituation, "player", unit)
        if known and readableNumber(unitStatus) then status = unitStatus end
    end

    local state
    if readableNumber(status) then
        if status == 3 then state = "aggro"
        elseif status == 1 or status == 2 then state = "warn"
        elseif status == 0 then state = "lost" end
    elseif type(tanking) == "boolean" and not DUI.IsSecret(tanking) then
        state = tanking and "aggro" or "lost"
    end
    paintState(text, state, db)
end)

extras.Loaded("NameplateThreat")
