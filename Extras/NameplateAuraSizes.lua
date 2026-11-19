local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Nameplates")
local ns = mod and mod.ns
local Auras, Sizes = ns and ns.Auras, extras.AuraSizes
if not (mod and mod.defaults and Auras and Auras.Layout and Auras.ShowSample and Auras.Place and Auras.Room
    and Auras.FitPending and Auras.KINDS and type(Auras.ASPECT) == "number" and type(Auras.BORDER_PX) == "number"
    and Sizes) then return end

-- Nameplate aura icons: square buffs and debuffs, 1 px borders, and each
-- row's icon height beside its native size slider.

local NATIVE_ASPECT, NATIVE_BORDER = Auras.ASPECT, Auras.BORDER_PX
local SQUARE = { buff = "blastaSquareBuffs", debuff = "blastaSquareDebuffs" }
local THIN = "blastaThinAuraBorders"
mod.defaults[SQUARE.buff] = false
mod.defaults[SQUARE.debuff] = false
mod.defaults[THIN] = false

local ROWS = {
    debuffs = { key = "debuffSize", kind = "debuff", label = "Nameplate debuffs" },
    cc = { key = "ccSize", kind = "debuff", label = "Nameplate crowd control" },
    defensives = { key = "defensiveSize", kind = "buff", label = "Nameplate defensives" },
    buffs = { key = "buffSize", kind = "buff", label = "Nameplate buffs" },
    helps = { key = "friendly.myBuffSize", kind = "buff", label = "Friendly nameplate buffs" },
}
-- Blasta's menu gathers these on the Auras page, Nameplates tab.
local function route(label) return { page = "Auras", tab = "Nameplates", label = label } end
extras.NameplateAuraRoute = route
for _, row in pairs(ROWS) do
    row.path, row.names = Sizes.Names(row.key)
    row.field = row.key:match("([^.]+)$")
    row.table = row.path:match("^(.-)%.?$")
end

local function cfg() return mod.db or ns.cfg end
local function square(kind)
    local db = cfg()
    return db and db[SQUARE[kind]] == true
end
local function baseRatio(kind) return square(kind) and 1 or NATIVE_ASPECT end

local function settingsOf(row)
    local db = cfg()
    if not db then return end
    if row.table == "" then return db end
    return type(db[row.table]) == "table" and db[row.table] or nil
end

local function widthOf(row)
    local settings = settingsOf(row)
    return tonumber(settings and settings[row.field]) or 0
end

local function heightOf(row, width)
    return Sizes.Height(Sizes.TableReader(settingsOf(row), row.names), width, baseRatio(row.kind))
end

local function nativeHeight(width) return math.floor(width * NATIVE_ASPECT + .5) end

local function useBorder()
    local db = cfg()
    Auras.BORDER_PX = db and db[THIN] == true and 1 or NATIVE_BORDER
end

-- Options: the global switches with the native aura rows, and a height and
-- an aspect lock under each size slider.
local function addRows()
    for _, page in ipairs(mod.options and mod.options.pages or {}) do
        for _, group in ipairs(page.groups or {}) do
            for i = #group.items, 1, -1 do
                local item = group.items[i]
                for _, row in pairs(ROWS) do
                    if item.key == row.key and item.type == "slider" then
                        local heightRow, keepRow = Sizes.Rows(item, {
                            scope = mod.name, since = "1.5", defaults = mod.defaults,
                            base = function() return baseRatio(row.kind) end,
                        })
                        if heightRow then
                            heightRow.blastaCompanion = item
                            heightRow.blastaDestination, keepRow.blastaDestination = route(row.label), route(row.label)
                            table.insert(group.items, i + 1, keepRow)
                            table.insert(group.items, i + 1, heightRow)
                        end
                    end
                end
            end
        end
        if page.id == "auras" and page.groups and page.groups[1] and page.groups[1].items then
            local card = extras.NameplateAuraCard
            if not card then
                card = { label = "Nameplate auras", items = {} }
                page.groups[#page.groups + 1] = card
                extras.NameplateAuraCard = card
            end
            local items = card.items
            items[#items + 1] = { type = "toggle", key = SQUARE.buff, label = "Square buff icons", blastaDestination = route("Nameplate auras"), blastaSince = "1.5",
                desc = "Nameplate buff icons as tall as they are wide, unless their own size says otherwise." }
            items[#items + 1] = { type = "toggle", key = SQUARE.debuff, label = "Square debuff icons", blastaDestination = route("Nameplate auras"), blastaSince = "1.5",
                desc = "Nameplate debuff and crowd control icons as tall as they are wide, unless their own size says otherwise." }
            items[#items + 1] = { type = "toggle", key = THIN, label = "1 px aura borders", blastaDestination = route("Nameplate auras"), blastaSince = "1.5",
                desc = "Draws the border around nameplate buffs and debuffs one pixel thick." }
        end
    end
end
addRows()

-- Finds the art texture of a client or sample icon: the button's icon in the
-- artwork layer, beneath the shade.
local icons = setmetatable({}, { __mode = "k" })
local function iconOf(button)
    local icon = icons[button]
    if icon then return icon end
    if button.GetIcon then
        local ok, found = pcall(button.GetIcon, button)
        if ok and type(found) == "table" and found.SetTexCoord then icon = found end
    end
    if not icon then
        for _, region in ipairs({ button:GetRegions() }) do
            if region:GetObjectType() == "Texture" then
                local layer, sublevel = region:GetDrawLayer()
                if layer == "ARTWORK" and (sublevel or 0) == 0 then icon = region; break end
            end
        end
    end
    icons[button] = icon
    return icon
end

local function fitButton(button, width, height, plate, relayout)
    if (relayout or height ~= nativeHeight(width)) and not pcall(button.SetSize, button, width, height) then return false end
    local icon = iconOf(button)
    if not icon then return false end
    return pcall(icon.SetTexCoord, icon, Sizes.IconCoords(width, height, DUI.Pixel.Px(plate, Auras.BORDER_PX)))
end

local fitted = setmetatable({}, { __mode = "k" })
local function adjust(p, relayout)
    for what, c in pairs(p.auras or {}) do
        local buttons = c.buttons
        local count = buttons and #buttons or 0
        local first = relayout and 1 or (fitted[c] or 0) + 1
        local row = ROWS[what]
        local width = row and (relayout or first <= count) and widthOf(row) or 0
        if width > 0 then
            local height = heightOf(row, width)
            if relayout and height ~= nativeHeight(width) then
                local key = Auras.KINDS[what] and Auras.KINDS[what].key
                if key and c.SetAuraGroupLayout then
                    pcall(c.SetAuraGroupLayout, c, key, {
                        layoutIndex = 1, elementWidth = width, elementHeight = height,
                        elementSpacing = Auras.GAP or 2, lineSpacing = (Auras.GAP or 2) + math.ceil(width * .35),
                    })
                end
            end
            fitted[c] = first - 1
            for i = first, count do
                if not fitButton(buttons[i], width, height, p, relayout) then break end
                fitted[c] = i
            end
        end
    end
end

local held = setmetatable({}, { __mode = "k" })
local function flushHeld()
    for plate, relayout in pairs(held) do
        held[plate] = nil
        if plate.blastaAuraUnit then adjust(plate, relayout) end
    end
end
local function adjustLater(p, relayout)
    if DUI.Restricted() then
        local alreadyQueued = next(held) ~= nil
        held[p] = held[p] or relayout
        if not alreadyQueued then DUI.AfterRestrictions(flushHeld, "blasta:nameplate-aura-size") end
    else
        adjust(p, relayout)
    end
end

-- The client appends buttons after layout. Revisit only the new indices.
local byUnit, pending = {}, {}
local needsUpdate
local function queueFit(p)
    pending[p] = true
    if needsUpdate then return end
    needsUpdate = true
    C_Timer.After(0, function()
        needsUpdate = nil
        for plate in pairs(pending) do
            pending[plate] = nil
            if plate.blastaAuraUnit then adjustLater(plate, false) end
        end
    end)
end

hooksecurefunc(Auras, "SetUnit", function(p, unit)
    local old = p.blastaAuraUnit
    if old and byUnit[old] == p then byUnit[old] = nil end
    if issecretvalue and issecretvalue(unit) then unit = nil end
    p.blastaAuraUnit = unit
    if unit then
        byUnit[unit] = p
        queueFit(p)
    end
end)

DUI.On("Login", function()
    local events = CreateFrame("Frame")
    events:RegisterEvent("UNIT_AURA")
    events:SetScript("OnEvent", function(_, _, unit)
        if issecretvalue and issecretvalue(unit) then return end
        local p = byUnit[unit]
        if p then queueFit(p) end
    end)
end)

local layout = Auras.Layout
function Auras.Layout(p, ...)
    useBorder()
    local a, b = layout(p, ...)
    if p and p.auras then adjustLater(p, true) end
    return a, b
end

local place = Auras.Place
function Auras.Place(f, what, at, p, ...)
    local a, b = place(f, what, at, p, ...)
    local row = ROWS[what]
    if row and (what == "cc" or what == "defensives" or
        what == "buffs" and at.L.point ~= "BOTTOM" and at.L.point ~= "TOP") then
        local width = widthOf(row)
        if width > 0 then pcall(f.SetSize, f, what == "buffs" and p.hp:GetWidth() or width, heightOf(row, width)) end
    end
    return a, b
end

local room = Auras.Room
function Auras.Room(what, ...)
    local across, up = room(what, ...)
    local row = ROWS[what]
    if row and type(up) == "number" then
        local width = widthOf(row)
        if width > 0 then up = up + heightOf(row, width) - nativeHeight(width) end
    end
    return across, up
end

local showSample = Auras.ShowSample
function Auras.ShowSample(p, what, list, ...)
    useBorder()
    local shown = showSample(p, what, list, ...)
    local row = ROWS[what]
    if shown and row and list and #list > 0 then
        local width = widthOf(row)
        if width > 0 then
            local height = heightOf(row, width)
            shown:SetHeight(height)
            for i = 1, #list do
                local button = shown.icons and shown.icons[i]
                if button then fitButton(button, width, height, p) end
            end
        end
    end
    return shown
end

DUI.On("Login", useBorder)

extras.Loaded("NameplateAuraSizes")
