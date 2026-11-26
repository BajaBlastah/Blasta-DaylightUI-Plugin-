local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Nameplates")
local ns = mod and mod.ns
local Auras, Sizes = ns and ns.Auras, extras.AuraSizes
local Style = DUI.Style
if not (mod and mod.defaults and Auras and Auras.Layout and Auras.ShowSample and Auras.Place and Auras.Room
    and Auras.FitPending and Auras.KINDS and type(Auras.ASPECT) == "number" and type(Auras.BORDER_PX) == "number"
    and Sizes) then return end

-- Nameplate aura icons: square buffs and debuffs, 1 px borders, and each
-- row's icon height beside its native size slider.

local NATIVE_ASPECT, NATIVE_BORDER = Auras.ASPECT, Auras.BORDER_PX
local SQUARE = { buff = "blastaSquareBuffs", debuff = "blastaSquareDebuffs" }
local THIN = "blastaThinAuraBorders"
-- Fit to the nameplate: so many debuffs per row, so many rows, shrunk to the
-- health bar's width when a full row would stick out, centered on the bar.
local FIT, PER_ROW, ROW_COUNT = "blastaDebuffFit", "blastaDebuffPerRow", "blastaDebuffRows"
mod.defaults[SQUARE.buff] = false
mod.defaults[SQUARE.debuff] = false
mod.defaults[THIN] = false
mod.defaults[FIT] = false
mod.defaults[PER_ROW] = 6
local ROW_GAP = "blastaDebuffRowGap"
mod.defaults[ROW_COUNT] = 1
mod.defaults[ROW_GAP] = 0

local ROWS = {
    debuffs = { key = "debuffSize", kind = "debuff", label = "Nameplate debuffs" },
    cc = { key = "ccSize", kind = "debuff", label = "Nameplate crowd control" },
    defensives = { key = "defensiveSize", kind = "buff", label = "Nameplate defensives" },
    buffs = { key = "buffSize", kind = "buff", label = "Nameplate buffs" },
    helps = { key = "friendly.myBuffSize", kind = "buff", label = "Friendly nameplate buffs" },
}
-- Blasta's menu gathers these on the Auras page, Nameplates tab.
local function route(label) return { page = "Auras", tab = "Nameplates", label = label } end
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

-- Debuff fit: per row and rows from the settings; the width shrinks only when
-- a full row of the set size would be wider than the bar.
local function fitOn()
    local db = cfg()
    return db and db[FIT] == true and db.debuffs ~= false
end
local function perRow()
    local db = cfg()
    return math.max(1, math.floor(tonumber(db and db[PER_ROW]) or 6))
end
local function rowCount()
    local db = cfg()
    return math.max(1, math.floor(tonumber(db and db[ROW_COUNT]) or 1))
end
local function barWidth(p)
    local w = p and p.hp and p.hp.GetWidth and p.hp:GetWidth()
    if type(w) == "number" and w > 0 and not (issecretvalue and issecretvalue(w)) then return w end
    local db = cfg()
    return tonumber(db and db.width) or 170
end
local GAP = function() return Auras.GAP or 2 end

-- Width and height of a fitted debuff on plate p (nil: fit off).
local function fitSize(p)
    if not fitOn() then return nil end
    local row = ROWS.debuffs
    local base = widthOf(row)
    if base <= 0 then return nil end
    local n, gap = perRow(), GAP()
    local width = base
    local room = barWidth(p)
    if n * base + (n - 1) * gap > room then width = math.max(8, math.floor((room - (n - 1) * gap) / n)) end
    local height = math.max(1, math.floor(heightOf(row, base) * width / base + .5))
    return width, height
end
local function rowGap()
    local db = cfg()
    return tonumber(db and db[ROW_GAP]) or 0
end

local function lineSpacing(width, fitted)
    local timeRoom = fitted and math.ceil(width * .35) or math.ceil(math.max(8, math.floor(width * .3 + 4.5)) / 2)
    -- Use a positive gap for the client flow and the preview alike.
    return math.max(1, GAP() + timeRoom + rowGap())
end

-- Whether Blasta changes nameplate auras at all. With every Blasta option at
-- DaylightUI's look, aura changes (UNIT_AURA on every plate in range, many
-- times a second in a fight) skip all of the work below. Read again after
-- every layout, which a settings change always brings.
local activeCache
local function blastaActive()
    if activeCache ~= nil then return activeCache end
    local db, on = cfg(), false
    -- Before the settings exist there's nothing to decide yet: don't keep
    -- that answer, or the sizes stay off until the next layout.
    if not db then return false end
    do
        if db[THIN] == true or db[SQUARE.buff] == true or db[SQUARE.debuff] == true or fitOn() then
            on = true
        else
            for _, row in pairs(ROWS) do
                local w = widthOf(row)
                if w > 0 and heightOf(row, w) ~= nativeHeight(w) then on = true; break end
            end
        end
    end
    activeCache = on
    return on
end

local function useBorder()
    local db = cfg()
    Auras.BORDER_PX = db and db[THIN] == true and 1 or NATIVE_BORDER
end

-- Options: the global switches with the native aura rows, and a height and
-- an aspect lock under each size slider.
extras.German["Debuff row spacing"] = "Abstand zwischen Debuffreihen"
extras.German["Adjust the vertical gap between rows. 0 keeps the automatic spacing."] =
    "Ändert den senkrechten Abstand zwischen den Reihen. 0 behält den automatischen Abstand bei."

local function addRows()
    for _, page in ipairs(mod.options and mod.options.pages or {}) do
        for _, group in ipairs(page.groups or {}) do
            for i = #group.items, 1, -1 do
                local item = group.items[i]
                if item.key == "maxDebuffs" and not item.blastaFitGuard then
                    -- Fit sets the count itself (per row x rows).
                    local was = item.disabled
                    item.blastaFitGuard = true
                    item.disabled = function(get, ...)
                        if get(FIT) == true then return true end
                        if type(was) == "function" then return was(get, ...) end
                        return was
                    end
                end
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
            items[#items + 1] = { type = "toggle", key = FIT, label = "Fit debuffs to the nameplate", blastaDestination = route("Nameplate auras"),
                desc = "Your debuffs in rows centered on the health bar: as many per row and as many rows as set below. When a full row at your debuff size would be wider than the bar, the icons shrink until it fits edge to edge. Replaces Max debuffs shown." }
            items[#items + 1] = { type = "slider", key = PER_ROW, label = "Debuffs per row", min = 1, max = 12, step = 1,
                blastaDestination = route("Nameplate auras"), disabled = function(get) return get(FIT) ~= true end,
                desc = "How many debuffs sit side by side in a row." }
            items[#items + 1] = { type = "slider", key = ROW_COUNT, label = "Debuff rows", min = 1, max = 3, step = 1,
                blastaDestination = route("Nameplate auras"), disabled = function(get) return get(FIT) ~= true end,
                desc = "How many rows of debuffs at most. Rows stack upward from the bar." }
            items[#items + 1] = { type = "slider", key = ROW_GAP, label = "Debuff row spacing", min = -10, max = 24,
                step = 1, unit = "px", blastaSince = "1.9.4", blastaDestination = route("Nameplate auras"),
                desc = "Adjust the vertical gap between rows. 0 keeps the automatic spacing." }
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

-- Whether a button's size differs from w x h. nil when it can't be read
-- (closed to addons, or secret): then only new buttons are fitted.
local function offSize(button, w, h)
    local ok, bw, bh = pcall(function() return button:GetWidth(), button:GetHeight() end)
    if not ok or type(bw) ~= "number" or type(bh) ~= "number" then return nil end
    if issecretvalue and (issecretvalue(bw) or issecretvalue(bh)) then return nil end
    return math.abs(bw - w) > 0.5 or math.abs(bh - h) > 0.5
end

-- Apply container geometry with the native layout pass. The individual
-- buttons can stay deferred during combat without losing the row spacing.
local function layoutGroups(p)
    for what, c in pairs(p.auras or {}) do
        local row = ROWS[what]
        local width = row and widthOf(row) or 0
        if width > 0 then
            local fw, fh
            if what == "debuffs" then fw, fh = fitSize(p) end
            local height = fh or heightOf(row, width)
            local kind = Auras.KINDS[what]
            if kind and c.SetAuraGroupLayout
                and (fw or height ~= nativeHeight(width) or (what == "debuffs" and rowGap() ~= 0)) then
                local spacing = what == "debuffs" and lineSpacing(fw or width, fw ~= nil)
                    or GAP() + math.ceil(width * .35)
                pcall(c.SetAuraGroupLayout, c, kind.key, {
                    layoutIndex = 1, elementWidth = fw or width, elementHeight = height,
                    elementSpacing = GAP(), lineSpacing = spacing,
                })
            end
            if fw and c.SetAuraGroupMaxFrameCount then
                pcall(c.SetAuraGroupMaxFrameCount, c, kind.key, perRow() * rowCount())
            end
        end
    end
end

local fitted = setmetatable({}, { __mode = "k" })
local function adjust(p, relayout)
    for what, c in pairs(p.auras or {}) do
        local buttons = c.buttons
        local count = buttons and #buttons or 0
        local first = relayout and 1 or (fitted[c] or 0) + 1
        local row = ROWS[what]
        -- Every button, not just new ones: DaylightUI fits a button to its
        -- own size when it's made or refitted, which would undo Blasta's.
        local width = row and widthOf(row) or 0
        local fw, fh
        if what == "debuffs" and width > 0 then fw, fh = fitSize(p) end
        if fw then
            for i = 1, count do
                local b = buttons[i]
                if relayout or i >= first or offSize(b, fw, fh) ~= false then
                    if not fitButton(b, fw, fh, p, true) then break end
                end
                fitted[c] = math.max(fitted[c] or 0, i)
            end
        elseif width > 0 then
            local height = heightOf(row, width)
            local custom = height ~= nativeHeight(width)
            for i = 1, count do
                local b = buttons[i]
                local fresh = relayout or i >= first
                if fresh or (custom and offSize(b, width, height) ~= false) then
                    if not fitButton(b, width, height, p, fresh or custom) then break end
                end
                fitted[c] = math.max(fitted[c] or 0, i)
            end
        end
    end
end

local held = setmetatable({}, { __mode = "k" })
local function flushHeld()
    for plate, relayout in pairs(held) do
        held[plate] = nil
        if plate.blastaAuraUnit then
            if relayout then layoutGroups(plate) end
            adjust(plate, relayout)
        end
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
    if not blastaActive() then return end
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

-- The very moment DaylightUI sizes one of a plate's aura buttons: when the
-- client makes it for a new aura (in a fight too, inside the client's own
-- call, where an addon may still size it) and when DaylightUI refits it. Its
-- last step is placing the halo. Blasta sets its own size right there, in the
-- same call. Queued for the next frame, or held until the fight was over, new
-- debuffs kept DaylightUI's size for the whole fight.
local containers = setmetatable({}, { __mode = "k" })   -- container -> { plate, what }
local function fitOne(btn, p, what)
    local row = ROWS[what]
    local width = row and widthOf(row) or 0
    if width <= 0 then return end
    local fw, fh
    if what == "debuffs" then fw, fh = fitSize(p) end
    if fw then
        fitButton(btn, fw, fh, p, true)
    else
        local height = heightOf(row, width)
        fitButton(btn, width, height, p, height ~= nativeHeight(width))
    end
end
if Style and Style.PlaceAuraHalo then
    hooksecurefunc(Style, "PlaceAuraHalo", extras.SafeHook("NameplateAuraSizes.Halo", function(_, btn)
        if type(btn) ~= "table" or not btn.GetParent or not blastaActive() then return end
        local at = containers[btn:GetParent()]
        if not at then
            -- Not parented to its container: a new button is its list's last.
            for c, info in pairs(containers) do
                local list = c.buttons
                if list and list[#list] == btn then at = info; break end
            end
        end
        if at and (at.plate.blastaAuraUnit or at.plate.unit) then fitOne(btn, at.plate, at.what) end
    end))
end

-- Known from the moment they're made: the client can make the first buttons
-- inside SetUnit, before a hook on it runs.
local function mapContainers(p)
    for what, c in pairs(p and p.auras or {}) do
        if not containers[c] then containers[c] = { plate = p, what = what } end
    end
end
if Auras.Create then hooksecurefunc(Auras, "Create", mapContainers) end

hooksecurefunc(Auras, "SetUnit", function(p, unit)
    mapContainers(p)
    local old = p.blastaAuraUnit
    if old and byUnit[old] == p then byUnit[old] = nil end
    if issecretvalue and issecretvalue(unit) then unit = nil end
    p.blastaAuraUnit = unit
    if unit then
        byUnit[unit] = p
        queueFit(p)
    end
end)

-- DaylightUI refits existing buttons to its own size whenever the plate's
-- pixel border changes (a new scale) or a setting does. In combat that refit
-- waits for the restrictions to lift, and it can then run after Blasta's own
-- deferred pass: the debuffs fell back to DaylightUI's size until the next
-- aura change. Fit every plate again right after DaylightUI's late refit.
hooksecurefunc(Auras, "FitPending", function()
    for _, plate in pairs(byUnit) do queueFit(plate) end
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
    activeCache = nil
    useBorder()
    local a, b = layout(p, ...)
    if p and p.auras and (blastaActive() or rowGap() ~= 0) then
        layoutGroups(p)
        adjustLater(p, true)
    end
    return a, b
end

-- Fitted debuffs: rows of exactly per-row icons. Centering on the bar's
-- drawn middle happens where the spot is laid out (NameplateShape). The
-- client fills a row from the left, so a part-filled top row starts at the
-- block's left edge.
local function placeFitted(f, p)
    local fw = fitSize(p)
    if not fw then return end
    local n = perRow()
    pcall(f.SetFlowLayoutMaximumLineSize, f, n * fw + (n - 1) * GAP())
end

local place = Auras.Place
function Auras.Place(f, what, at, p, ...)
    local a, b = place(f, what, at, p, ...)
    if what == "debuffs" then pcall(placeFitted, f, p) end
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
    if what == "debuffs" then
        local fw, fh = fitSize(nil)
        if fw then
            local n, rows, gap = perRow(), rowCount(), GAP()
            return n * fw + (n - 1) * gap, rows * fh + (rows - 1) * lineSpacing(fw, true) + math.ceil(fw * .35)
        end
    end
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
    local fw, fh
    if what == "debuffs" then fw, fh = fitSize(p) end
    if fw and list and #list > 0 then
        -- Show the second row when enabled, without exceeding the configured cap.
        local columns, rows = perRow(), rowCount()
        local count = math.min(columns * rows, math.max(#list, rows > 1 and columns + 1 or 1))
        if count ~= #list then
            local entries = list
            list = {}
            for i = 1, count do list[i] = entries[(i - 1) % #entries + 1] end
        end
    end
    local shown = showSample(p, what, list, ...)
    local row = ROWS[what]
    if shown and row and list and #list > 0 then
        local width = fw or widthOf(row)
        if width > 0 then
            local height = fh or heightOf(row, width)
            local at = p.spotAt and p.spotAt[what]
            local flow = at and at.L
            local reflow = fw or (what == "debuffs" and rowGap() ~= 0 and flow and type(flow.line) == "number" and flow.line > 0)
            local gap = GAP()
            local perLine = fw and perRow() or (reflow and math.max(1, math.floor((flow.line + gap) / (width + gap))))
            local step = reflow and height + lineSpacing(width, fw ~= nil)
            shown:SetHeight(reflow and height + math.floor((#list - 1) / perLine) * step or height)
            if reflow then
                local columns = math.min(#list, perLine)
                shown:SetWidth(columns * width + (columns - 1) * gap)
            end
            for i = 1, #list do
                local button = shown.icons and shown.icons[i]
                if button then
                    fitButton(button, width, height, p, fw ~= nil)
                    if reflow then
                        local right = flow and flow.hDir == "Left"
                        local down = flow and flow.vDir == "Down"
                        local corner = (down and "TOP" or "BOTTOM") .. (right and "RIGHT" or "LEFT")
                        local col, rowIndex = (i - 1) % perLine, math.floor((i - 1) / perLine)
                        button:ClearAllPoints()
                        button:SetPoint(corner, shown, corner, (right and -1 or 1) * col * (width + gap),
                            (down and -1 or 1) * rowIndex * step)
                    end
                end
            end
        end
    end
    return shown
end

DUI.On("Login", function() activeCache = nil; useBorder() end)
DUI.On("SettingChanged", function(scope)
    if scope == mod.name then activeCache = nil end
end)

extras.Loaded("NameplateAuraSizes")
