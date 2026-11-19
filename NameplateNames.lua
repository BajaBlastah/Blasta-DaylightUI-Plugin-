local _, blasta = ...
local german = blasta.German
local DUI = DaylightUI

local charPattern = "[%z\1-\127\194-\244][\128-\191]*"
local function charCount(text)
    local _, count = text:gsub(charPattern, "")
    return count
end

local function shorten(text, limit)
    if charCount(text) <= limit then return text end
    local words = {}
    for word in text:gmatch("%S+") do words[#words + 1] = word end
    for i = 1, #words - 1 do
        words[i] = (words[i]:match(charPattern) or "") .. "."
    end
    local abbreviated = table.concat(words, " ")
    if charCount(abbreviated) <= limit then return abbreviated end
    local last = words[#words] or text
    if charCount(last) <= limit then return last end

    local count, boundary = 0, 1
    for nextByte in last:gmatch(charPattern .. "()") do
        count, boundary = count + 1, nextByte
        if count == limit - 3 then break end
    end
    return last:sub(1, boundary - 1) .. "..."
end

local function addTargetOptions()
    local units = DUI:GetModule("UnitFrames")
    local uf = units and units.ns and units.ns.UF
    local defaults = units and units.defaults and units.defaults.target
    if not (uf and type(uf.Layout) == "function" and type(uf.NameText) == "function"
        and type(defaults) == "table") then return end

    local items, index
    for _, page in ipairs(units.options and units.options.pages or {}) do
        if page.id == "target" then
            for _, group in ipairs(page.groups or {}) do
                for i, item in ipairs(group.items or {}) do
                    if item.key == "target.nameLimitLen" then
                        items, index = group.items, i
                        break
                    end
                end
                if items then break end
            end
            break
        end
    end
    if not items then return end

    local toggle, limitKey = "target.shortenName", "target.shortNameLimit"
    local label, limitLabel = "Abbreviate target names", "Target name character limit"
    local desc = "Shortens long target names to initials and the last word. While enabled, this replaces DaylightUI's target name limit."
    german[label] = "Zielnamen kürzen"
    german[limitLabel] = "Maximale Länge des Zielnamens"
    german[desc] = "Kürzt lange Zielnamen auf Initialen und das letzte Wort. Solange aktiv, ersetzt dies DaylightUIs Zeichenlimit für Zielnamen."
    defaults.shortenName, defaults.shortNameLimit = false, 19
    table.insert(items, index + 1, { type = "toggle", key = toggle, label = label, desc = desc })
    table.insert(items, index + 2, {
        type = "slider", key = limitKey, label = limitLabel, min = 10, max = 40, step = 1,
        disabled = function(get) return not get(toggle) end,
    })

    -- Unit-frame names already use a single line. When initials are enabled,
    -- give the formatter the full name before the native gradient is applied.
    hooksecurefunc(uf, "Layout", function(frame, cfg)
        if frame.spec and frame.spec.unit == "target" and cfg.shortenName then
            frame.nameLimitLen = 0
        end
    end)
    local formatName = uf.NameText
    function uf.NameText(frame, name)
        local cfg = units.db and units.db.target
        if frame.spec and frame.spec.unit == "target" and cfg and cfg.shortenName and type(name) == "string"
            and not (issecretvalue and issecretvalue(name)) then
            local limit = math.max(10, math.min(40, math.floor(tonumber(cfg.shortNameLimit) or 19)))
            name = shorten(name, limit)
        end
        return formatName(frame, name)
    end
end

addTargetOptions()

local module = DUI:GetModule("Nameplates")
local ns = module and module.ns
if not (ns and ns.Plate and type(ns.Plate.PlaceSpots) == "function"
    and type(DUI.UnitName) == "function" and type(module.defaults) == "table") then return end

local items
for _, page in ipairs(module.options and module.options.pages or {}) do
    if page.id == "bars" then
        for _, group in ipairs(page.groups or {}) do
            if group.label == "Name" then items = group.items; break end
        end
        break
    end
end
if type(items) ~= "table" then return end

local toggle, limitKey = "shortenPlateNames", "plateNameLimit"
local label, limitLabel = "Shorten nameplate names", "Maximum name length"
local desc = "Shortens long names to initials and the last word, and keeps the name on one line."
german[label] = "Namen kürzen"
german[limitLabel] = "Maximale Namenslänge"
german[desc] = "Kürzt lange Namen auf Initialen und das letzte Wort und zeigt sie einzeilig an."
module.defaults[toggle] = false
module.defaults[limitKey] = 19
items[#items + 1] = { type = "toggle", key = toggle, label = label, desc = desc }
items[#items + 1] = {
    type = "slider", key = limitKey, label = limitLabel, min = 10, max = 40, step = 1,
    disabled = function(get) return not get(toggle) end,
}

local getName = DUI.UnitName
local cache, cacheSize, previousLimit = {}, 0, nil
function DUI.UnitName(unit, element)
    local name = getName(unit, element)
    local cfg = ns.cfg
    if element ~= "nameplates" or not (cfg and cfg[toggle]) or type(name) ~= "string"
        or (issecretvalue and issecretvalue(name)) then return name end
    local limit = math.max(10, math.min(40, math.floor(tonumber(cfg[limitKey]) or 19)))
    if previousLimit ~= limit then
        cache, cacheSize, previousLimit = {}, 0, limit
    end
    if cache[name] then return cache[name] end
    if cacheSize >= 256 then cache, cacheSize = {}, 0 end
    local result = shorten(name, limit)
    cache[name], cacheSize = result, cacheSize + 1
    return result
end

local wrapped = setmetatable({}, { __mode = "k" })
local place = ns.Plate.PlaceSpots
function ns.Plate.PlaceSpots(plate)
    local name = plate.name
    if name and name.SetWordWrap then
        if ns.cfg and ns.cfg[toggle] then
            if wrapped[name] == nil then
                wrapped[name] = not name.CanWordWrap or name:CanWordWrap()
                name:SetWordWrap(false)
            end
        elseif wrapped[name] ~= nil then
            name:SetWordWrap(wrapped[name])
            wrapped[name] = nil
        end
    end
    return place(plate)
end

blasta.Loaded("NameplateNames")
