local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("UnitFrames")
local ns = mod and mod.ns
local Auras, Groups = ns and ns.Auras, ns and ns.AuraGroups
local Style, Sizes = DUI.Style, extras.AuraSizes
if not (mod and mod.defaults and Auras and Auras.Apply and Auras.SetOwnSize and Auras.InitButton
    and Auras.DrawSample and Auras.ShowSample and Auras.HolderFor and Auras.IsPlain and Auras.KINDS
    and Groups and Groups.Place and Style.GetShell and Style.LayoutShell and Sizes) then return end

-- Unit frame aura icons on every frame: square buff and debuff icons as one
-- global choice, and each frame's icon height beside its native size slider.

local SQUARE = { buff = "blastaSquareBuffs", debuff = "blastaSquareDebuffs" }
local KIND = { buff = "buff", selfbuff = "buff", tilebuff = "buff",
    debuff = "debuff", selfdebuff = "debuff", gdebuff = "debuff", gcc = "debuff" }
mod.defaults[SQUARE.buff] = false
mod.defaults[SQUARE.debuff] = false
-- 1 px borders around every unit frame aura icon, as one global choice.
local THIN = "blastaThinAuraBorders"
mod.defaults[THIN] = false
local NATIVE_BORDER = Auras.BORDER_PX or 2
local Pixel = DUI.Pixel

local function thin() return mod.db and mod.db[THIN] == true end
-- New buttons and samples read the module's border width when they're drawn.
local function useBorder() Auras.BORDER_PX = thin() and 1 or NATIVE_BORDER end

local function square(kind)
    return mod.db and mod.db[SQUARE[kind]] == true
end

local function baseRatio(kind)
    return square(kind) and 1 or (Auras.ASPECT or .88)
end

-- Global switches, on the frames' shared extras page. A change refreshes
-- every frame through the module's own setting callback.
local squareRows = {
    { type = "toggle", key = SQUARE.buff, label = "Square buff icons", blastaSince = "1.5",
        desc = "Unit frame buff icons without rounded corners, as tall as they are wide unless their own size says otherwise. Applies to every unit frame." },
    { type = "toggle", key = SQUARE.debuff, label = "Square debuff icons", blastaSince = "1.5",
        desc = "Unit frame debuff and crowd control icons without rounded corners, as tall as they are wide unless their own size says otherwise. Applies to every unit frame." },
    { type = "toggle", key = THIN, label = "1 px aura borders", blastaSince = "1.5",
        desc = "Draws the border around unit frame buffs and debuffs one pixel thick. Applies to every unit frame." },
}
for _, page in ipairs(mod.options and mod.options.pages or {}) do
    if page.id == "extras" then
        page.groups[#page.groups + 1] = { label = "Blasta aura icons", items = squareRows }
        break
    end
end

-- Only buffs with a duration: a Blasta switch beside each frame's buff
-- switch. The client leaves out buffs that never run out with the same
-- duration filter DaylightUI's lists use for long debuffs.
local TIMED_LIMIT = 359999
local function timedRow(show, key, page)
    local mapKey = page.mapKey
    local row = {
        type = "toggle", key = key, label = "Only buffs with a duration", blastaSince = "1.5",
        desc = "Leaves out buffs that never run out, like auras and long-term effects.",
        blastaJumpAnchor = show.key,
        get = function() return DUI:Get(mod.name, mapKey and mapKey(key) or key) == true end,
        set = function(value) return DUI:Set(mod.name, mapKey and mapKey(key) or key, value == true) end,
        default = function() return false end,
    }
    local function read(k) return DUI:Get(mod.name, mapKey and mapKey(k) or k) end
    row.disabled = function(get)
        if page.locked and page.locked(key, row) then return true end
        local on = read(show.key)
        if on == nil then on = DUI.DB.GetPath(mod.defaults, show.key) end
        return on ~= true or (show.disabled and show.disabled(mapKey and read or get)) == true
    end
    if show.hidden then row.hidden = function(get) return show.hidden(mapKey and read or get) end end
    return row
end

-- Height rows beside every native aura size slider: the player, target,
-- focus, pet and personal rows, and every aura group of party and raid.
local function sizeKind(key)
    if type(key) ~= "string" then return end
    local kind = key:match("^[%w]+Auras%.(%a+)Size$") or key:match("^personal%.auras%.(%a+)Size$")
    if kind == "buff" or kind == "debuff" then return kind end
    local path, group = key:match("^([%w]+%.auras%.([%w]+))%.size$")
    if group == "buffs" then return "buff" end
    if group == "debuffs" or group == "cc" then return "debuff" end
    -- Extra aura group slots show buffs or debuffs by their own setting.
    if group then return "slot", path .. ".what" end
end

for _, page in ipairs(mod.options and mod.options.pages or {}) do
    for _, group in ipairs(page.groups or {}) do
        for i = #group.items, 1, -1 do
            local row = group.items[i]
            local kind, whatKey = sizeKind(row.key)
            if kind and row.type == "slider" then
                local mapKey = page.mapKey
                local function base()
                    if kind ~= "slot" then return baseRatio(kind) end
                    local what = DUI:Get(mod.name, mapKey and mapKey(whatKey) or whatKey)
                    return baseRatio(what == "buffs" and "buff" or "debuff")
                end
                local heightRow, keepRow = Sizes.Rows(row, {
                    scope = mod.name, since = "1.5", defaults = mod.defaults, base = base,
                    mapKey = page.mapKey, locked = page.locked,
                })
                if heightRow then
                    -- Blasta's menu shows the native width slider right above.
                    heightRow.blastaCompanion = row
                    -- Buff rows also get the duration filter, under the aspect lock.
                    local single = row.key:match("^(.-)%.buffSize$")
                    local grouped = row.key:match("^(.-%.auras%.buffs)%.size$")
                    local show = single and single .. ".buffs" or grouped and grouped .. ".show"
                    if show then
                        local timedKey = single and single .. ".blastaTimedBuffs" or grouped .. ".blastaTimed"
                        table.insert(group.items, i + 1, timedRow(
                            { key = show, hidden = row.hidden, disabled = row.disabled }, timedKey, page))
                    end
                    table.insert(group.items, i + 1, keepRow)
                    table.insert(group.items, i + 1, heightRow)
                end
            end
        end
    end
end

-- Which settings table sizes each container. Single frames pass theirs to
-- Auras.Apply; aura groups (party, raid and their extra slots) to Groups.Place.
local SINGLE = {}
SINGLE.buff = select(2, Sizes.Names("buffSize"))
SINGLE.debuff = select(2, Sizes.Names("debuffSize"))
local GROUP = select(2, Sizes.Names("size"))
local rules = setmetatable({}, { __mode = "k" })
local placing

local apply = Auras.Apply
function Auras.Apply(set, cfg)
    useBorder()
    if set and type(cfg) == "table" then
        -- The kind rides along: the options preview's stand-ins have none of their own.
        if set.debuffs then rules[set.debuffs] = { cfg = cfg, names = SINGLE.debuff, kind = "debuff" } end
        if set.buffs then rules[set.buffs] = { cfg = cfg, names = SINGLE.buff, kind = "buff" } end
    end
    return apply(set, cfg)
end

local function groupRule(set, all, c)
    if type(all) ~= "table" then return end
    for _, def in ipairs(Groups.DEFS or {}) do
        if set[def.key] == c and type(all[def.key]) == "table" then return { cfg = all[def.key], names = GROUP } end
    end
    for slot, containers in pairs(set.extra or {}) do
        for _, container in pairs(containers) do
            if container == c and type(all[slot]) == "table" then return { cfg = all[slot], names = GROUP } end
        end
    end
end

local place = Groups.Place
function Groups.Place(set, frame, all, box)
    if not set then return place(set, frame, all, box) end
    local previous = placing
    placing = { set = set, all = all }
    local ok, a, b = pcall(place, set, frame, all, box)
    placing = previous
    if not ok then error(a, 0) end
    return a, b
end

local function ruleFor(c)
    if placing then
        local rule = groupRule(placing.set, placing.all, c)
        if rule then rules[c] = rule; return rule end
    end
    return rules[c]
end

-- The flag rides on the container's picks, so a change re-applies its filters.
local lists = ns.AuraLists
if lists and lists.Use and lists.Filters then
    local BUFF_KINDS = { buff = true, selfbuff = true, tilebuff = true }
    local function timed(c)
        local rule = rules[c]
        local cfg = rule and rule.cfg
        if type(cfg) ~= "table" then return false end
        if rule.names == GROUP then return cfg.blastaTimed == true end
        return cfg.blastaTimedBuffs == true
    end
    local use = lists.Use
    function lists.Use(c, picks, ...)
        if c and BUFF_KINDS[c.dluiKind] and type(picks) == "table" then
            local on = timed(c)
            if on or picks.blastaTimed then
                local copy = {}
                for key, value in pairs(picks) do copy[key] = value end
                copy.blastaTimed = on or nil
                -- The native signature reads maxTime, so a switch re-applies.
                copy.maxTime = on and TIMED_LIMIT or (tonumber(picks.maxTime) or 0)
                picks = copy
            end
        end
        return use(c, picks, ...)
    end
    local filters = lists.Filters
    function lists.Filters(c, g, ...)
        local cand = filters(c, g, ...)
        local picks = c and c.dluiPicks
        if c and BUFF_KINDS[c.dluiKind] and type(picks) == "table" and picks.blastaTimed then
            cand = cand or {}
            cand.maxDuration = TIMED_LIMIT
        end
        return cand
    end
end

-- Square corners: the native shell's corner radius set to 0.
local nativeCorners = setmetatable({}, { __mode = "k" })
local function shape(button, on)
    local shell = Style.GetShell(button)
    if not (shell and shell.opts) then return end
    local old = nativeCorners[shell]
    if on and not old then
        nativeCorners[shell] = { corner = shell.opts.cornerPx }
        shell.opts.cornerPx = 0
        Style.LayoutShell(shell)
    elseif old and not on then
        shell.opts.cornerPx = old.corner
        nativeCorners[shell] = nil
        Style.LayoutShell(shell)
    end
end

local icons = setmetatable({}, { __mode = "k" })
local function iconOf(button)
    if button.icon then return button.icon end
    if icons[button] then return icons[button] end
    local icon = button.GetIcon and select(2, pcall(button.GetIcon, button))
    if type(icon) ~= "table" or not icon.SetTexCoord then
        icon = nil
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

-- The border: the shell's width, and the icon inset by it (a debuff's
-- dispel-colored edge is the button showing around the icon).
local function border(button, icon)
    local px = Auras.BORDER_PX or NATIVE_BORDER
    local shell = Style.GetShell(button)
    if shell and shell.opts and shell.opts.borderPx ~= px then
        shell.opts.borderPx = px
        pcall(Style.LayoutShell, shell)
    end
    if icon and Pixel and Pixel.Px then
        local T = Pixel.Px(button, px)
        pcall(icon.ClearAllPoints, icon)
        pcall(icon.SetPoint, icon, "TOPLEFT", button, "TOPLEFT", T, -T)
        pcall(icon.SetPoint, icon, "BOTTOMRIGHT", button, "BOTTOMRIGHT", -T, T)
    end
end

local function fitButton(button, width, height, on)
    local icon = iconOf(button)
    local inset = Pixel and Pixel.Px and Pixel.Px(button, Auras.BORDER_PX or NATIVE_BORDER) or 0
    if icon then pcall(icon.SetTexCoord, icon, Sizes.IconCoords(width, height, inset)) end
    shape(button, on)
    border(button, icon)
end

local buttons = setmetatable({}, { __mode = "k" })
local applied = setmetatable({}, { __mode = "k" })

local function relayout(c, width, height, gap)
    local def = Auras.KINDS[c.dluiKind]
    for _, group in ipairs(def and def.groups or {}) do
        if c.dluiGroups and c.dluiGroups[group.key] then
            pcall(c.SetAuraGroupLayout, c, group.key, {
                layoutIndex = group.index, elementWidth = width, elementHeight = height,
                elementSpacing = gap, lineSpacing = gap + 4,
            })
        end
    end
end

local size = Auras.SetOwnSize
function Auras.SetOwnSize(c, width, gap)
    local s = size(c, width, gap)
    if not c or type(s) ~= "table" then return s end
    if extras.AuraBarWidth and extras.AuraBarWidth(c) then
        -- Bars own the size now; icons coming back get fitted from scratch.
        applied[c] = nil
        return s
    end
    local rule = ruleFor(c)
    local kind = KIND[c.dluiKind] or (rule and rule.kind)
    if not kind then return s end
    local read = rule and Sizes.TableReader(rule.cfg, rule.names) or function() return nil end
    local height = Sizes.Height(read, s[1], baseRatio(kind))
    if height <= 0 then return s end
    local on, px = square(kind), Auras.BORDER_PX
    -- The native size is cached per container, so its own button fitting and
    -- sample drawing pick up the height from here.
    if s[2] ~= height then
        s[2] = height
        if not Auras.IsPlain(c) then relayout(c, s[1], height, gap) end
    end
    local last = applied[c]
    if Auras.IsPlain(c) or (last and last.w == s[1] and last.h == height and last.square == on and last.px == px) then return s end
    applied[c] = { w = s[1], h = height, square = on, px = px }
    DUI.AfterRestrictions(function()
        for button in pairs(buttons[c] or {}) do
            pcall(button.SetSize, button, s[1], s[2])
            fitButton(button, s[1], s[2], on)
        end
    end, "blasta:aura-shape:" .. tostring(c))
    return s
end

hooksecurefunc(Auras, "InitButton", function(button, _, container)
    local kind = container and KIND[container.dluiKind]
    if not kind or (extras.AuraBarWidth and extras.AuraBarWidth(container)) then return end
    if not buttons[container] then buttons[container] = setmetatable({}, { __mode = "k" }) end
    buttons[container][button] = true
    local w, h = button:GetSize()
    if type(w) == "number" and type(h) == "number" and not (issecretvalue and (issecretvalue(w) or issecretvalue(h))) then
        fitButton(button, w, h, square(kind))
    else
        shape(button, square(kind))
    end
end)

-- Sample icons in the options preview and test mode.
local function fitPool(pool, kind)
    for _, button in ipairs(pool or {}) do
        local w, h = button:GetSize()
        if w and h and w > 0 and h > 0 then fitButton(button, w, h, square(kind)) end
    end
end

hooksecurefunc(Auras, "DrawSample", function(c, _, _, kind)
    local which = KIND[kind]
    if which and c and not (extras.AuraBarWidth and extras.AuraBarWidth(c)) then fitPool(c.pool, which) end
end)

function extras.GeneralAuraPreview(parent)
    local host = CreateFrame("Frame", nil, parent)
    local rows = {}
    for i, kind in ipairs({ "buff", "debuff" }) do
        local c = Auras.Plain(host)
        local label = Style.Text(host, 12, "CENTER")
        rows[i] = { frame = c, label = label, kind = kind }
    end
    return {
        frame = host,
        Refresh = function(width, room)
            useBorder()
            local size = math.max(12, math.min(28, math.floor((width / 2 - 24) / 4), (room or 100) - 32))
            for i, row in ipairs(rows) do
                local buff, c = row.kind == "buff", row.frame
                local offset = (i == 1 and -.25 or .25) * width
                row.label:SetText(extras.Translate(buff and "Buffs" or "Debuffs"))
                row.label:SetPoint("TOP", host, "TOP", offset, -2)
                c:SetPoint("TOP", host, "TOP", offset, -23)
                rules[c] = { kind = row.kind, names = GROUP, cfg = {} }
                Auras.SetOwnSize(c, size, 3)
                local list = Groups.SAMPLES[buff and "buffs" or "debuffs"]
                Auras.DrawSample(c, list, #list, buff and "tilebuff" or "gdebuff",
                    { anchor = "TOPLEFT", perRow = 4, timers = false, counts = false })
            end
            host:SetSize(width, size + 26)
            return size + 26
        end,
    }
end

hooksecurefunc(Auras, "ShowSample", function(set)
    if not set then return end
    for _, key in ipairs({ "buffs", "debuffs" }) do
        local c = set[key]
        local holder = c and Auras.HolderFor(c)
        if holder and not (extras.AuraBarWidth and extras.AuraBarWidth(c)) then
            fitPool(holder.pool, key == "buffs" and "buff" or "debuff")
        end
    end
end)

-- 1.5 previews had square icons on the target only. Carry that choice over to
-- the global switches once.
DUI.On("Login", function()
    useBorder()
    local db = mod.db
    if not db or db.blastaSquareMigrated then return end
    local target = type(db.targetAuras) == "table" and db.targetAuras
    if target then
        if target.blastaSquareBuffs == true then db[SQUARE.buff] = true end
        if target.blastaSquareDebuffs == true then db[SQUARE.debuff] = true end
    end
    db.blastaSquareMigrated = true
end)

extras.Loaded("TargetAuraShape")
