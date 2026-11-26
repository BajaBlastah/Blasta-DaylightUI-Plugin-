local ADDON, extras = ...
local DUI = DaylightUI

-- Capture Daylight's original rows before the feature modules add their controls.
-- Move the controls before Daylight builds its options, while keeping their
-- original profile keys and module callbacks.
local modules = { "Nameplates", "UnitFrames", "ActionBars", "Tooltip", "QoL", "Professions", "Quests", "Bags", "Skins" }
local original = {}
local nativeSwitches = {}
local function rememberRows(name)
    local mod = DUI:GetModule(name)
    local switches = {}
    nativeSwitches[name] = switches
    for _, page in ipairs(mod and mod.options and mod.options.pages or {}) do
        for _, group in ipairs(page.groups or {}) do
            for _, item in ipairs(group.items or {}) do
                original[item] = true
                if item.type == "toggle" and item.key and type(item.label) == "string" then
                    switches[item.key] = { label = item.label, invert = item.invert }
                end
            end
        end
    end
end
for _, name in ipairs(modules) do rememberRows(name) end
rememberRows("InfoPanel")
rememberRows("Buffs")
rememberRows("Chat")

local function notice(label, hidden)
    local widgets = DUI.Widgets
    return {
        type = "custom", label = "DaylightUI", hidden = hidden,
        build = function(row)
            local text = widgets.Font(row, widgets.BODY, 12, nil, "LEFT")
            text:SetPoint("TOPLEFT", row, "TOPLEFT", widgets.PAD, -8)
            text:SetJustifyV("TOP")
            text:SetWordWrap(true)
            text:SetText(label())
            row.blastaNotice = text
        end,
        height = function(row)
            local text = row.blastaNotice
            text:SetWidth(math.max(1, row:GetWidth() - 2 * widgets.PAD))
            return math.max(14, math.ceil(text:GetStringHeight())) + 16
        end,
    }
end

local function moduleNotice(mod)
    return notice(function()
        return extras.Translate("Enable the DaylightUI module “%s”."):format(extras.Translate(mod.label or mod.name))
    end, function() return mod.enabled == true end)
end

local function switchOn(mod, key, switch)
    local value = DUI:Get(mod.name, key)
    if switch.invert then return value ~= true end
    return value == true
end

local function switchNotice(mod, key, switch)
    return notice(function()
        return extras.Translate("In DaylightUI, enable “%s”."):format(extras.Translate(switch.label))
    end, function() return not mod.enabled or switchOn(mod, key, switch) end)
end

local function addNotices(mod, items, requiredKey)
    local switches = nativeSwitches[mod.name] or {}
    local seen = {}
    local notices = { moduleNotice(mod) }
    local function add(key)
        if key and switches[key] and not seen[key] then
            notices[#notices + 1] = switchNotice(mod, key, switches[key])
            seen[key] = true
        end
    end
    add(requiredKey)
    for _, item in ipairs(items) do
        local requirements = {}
        local parent = item.key and item.key:match("^(.*)%.[^.]+$")
        while parent do
            local key = parent .. ".enabled"
            if switches[key] then requirements[#requirements + 1] = key end
            parent = parent:match("^(.*)%.[^.]+$")
        end
        if switches[item.blastaRequires] then requirements[#requirements + 1] = item.blastaRequires end
        if #requirements > 0 then
            for _, key in ipairs(requirements) do add(key) end
            local hidden = item.hidden
            item.hidden = function(get)
                if hidden and hidden(get) == true then return true end
                for _, key in ipairs(requirements) do
                    if not switchOn(mod, key, switches[key]) then return true end
                end
                return false
            end
        end
    end
    for i = #notices, 1, -1 do table.insert(items, 1, notices[i]) end
end

function extras.ShowDaylightRequirements(page, mod, requiredKey)
    page.hidden = nil
    local requiredSwitch = nativeSwitches[mod.name] and nativeSwitches[mod.name][requiredKey]
    for _, group in ipairs(page.groups) do
        for _, row in ipairs(group.items) do
            local hidden = row.hidden
            row.hidden = function(get)
                return not mod.enabled or (requiredSwitch and not switchOn(mod, requiredKey, requiredSwitch))
                    or (hidden and hidden(get) == true)
            end
        end
    end
    local first = page.groups[1]
    if first then addNotices(mod, first.items, requiredKey) end
    return page
end

local portraitOffsets = {   -- label -> { switch, native name, Blasta name, native spot (none = drag) }
    ["Leader crown"] = { "showLeader", "leader", "blastaLeader" },
    ["PvP flag"] = { "showPvP", "pvp", "blastaPvP" },
    Resting = { "showResting", "rest", "blastaRest" },
    Level = { "showLevel", "level", "level" },
}
extras.PortraitOffsets = portraitOffsets   -- DesignParts.lua adds the raid marker

local function offsetsFor(mod, source, part, wanted)
    local spec = mod.name == "UnitFrames" and portraitOffsets[part.label]
    if not spec then return end
    local function mapped(path) return source.mapKey and source.mapKey(path) or path end
    for _, key in ipairs(part.keys or {}) do
        local prefix = key:match("^(.*%.)" .. spec[1] .. "$")
        -- A part DaylightUI already moves to spots keeps its own drag.
        if prefix and spec[4] and extras.FindSetting(mod, prefix .. spec[4]) then return end
        if prefix then
            local result = {}
            for _, axis in ipairs({ "X", "Y" }) do
                local native, blasta = prefix .. spec[2] .. axis, prefix .. spec[3] .. axis
                if extras.FindSetting(mod, native) and not DUI.Options.Locked(source, { key = native }) then
                    result[axis], wanted[native] = native, true
                elseif DUI.DB.GetPath(mod.defaults, mapped(blasta)) ~= nil and blasta ~= native then
                    result[axis], wanted[blasta] = blasta, true
                end
            end
            if result.X and result.Y then return result end
        end
    end
end

local function portraitMove(mod, source, part, wanted)
    local keys = offsetsFor(mod, source, part, wanted)
    if part.move and part.move.xKey and part.move.yKey then return part.move end
    if not keys then return part.move end
    local region = part.region
    local owner = part.move and part.move.owner or region:GetParent()
    if not owner then return part.move end
    -- Resolve the home position now: the native drag moves the region itself.
    local cx, cy = region:GetCenter()
    if not (cx and cy and owner:GetLeft() and owner:GetTop()) then return part.move end
    local scale = region:GetEffectiveScale() / owner:GetEffectiveScale()
    local dx = DUI:Get(mod.name, DUI.Options.Key(source, keys.X)) or 0
    local dy = DUI:Get(mod.name, DUI.Options.Key(source, keys.Y)) or 0
    local dots = { { spot = "home", x = cx * scale - owner:GetLeft() - dx, y = owner:GetTop() - cy * scale + dy } }
    return { xKey = keys.X, yKey = keys.Y, owner = owner, dots = dots,
        offsetLimit = 50,
        drop = function(x, y) return DUI.Spots.Drop(dots, x, y) end }
end

local previewHosts = setmetatable({}, { __mode = "k" })
function extras.IsUnitFramePreview(frame)
    local parent = frame:GetParent()
    while parent and not previewHosts[parent] do parent = parent:GetParent() end
    return parent ~= nil
end


-- Daylight's own previews show Blasta's additions: the unit frame previews
-- count as previews for Blasta's drawing (extras.IsUnitFramePreview), and
-- the portrait icons and aura bars Blasta adds can be dragged in Daylight's
-- Design mode like its own parts.
local function wrapSample(mod, page)
    local factory = page.sample
    if type(factory) ~= "function" or page.blastaSample then return end
    page.blastaSample = true
    page.sample = function(parent, ...)
        local preview = factory(parent, ...)
        if type(preview) ~= "table" then return preview end
        if preview.frame then previewHosts[preview.frame] = true end
        local refresh = preview.Refresh
        if refresh and mod.name == "UnitFrames" then
            preview.Refresh = function(...)
                local used = refresh(...)
                if extras.PaintDispelPreview then pcall(extras.PaintDispelPreview, preview) end
                return used
            end
        end
        local readParts = preview.Parts
        if readParts and mod.name == "UnitFrames" then
            preview.Parts = function(...)
                local parts = readParts(...) or {}
                local wanted = {}
                for _, part in ipairs(parts) do
                    local ok, move = pcall(portraitMove, mod, page, part, wanted)
                    if ok then part.move = move end
                end
                if extras.AppendAuraBarPreviewParts then
                    pcall(extras.AppendAuraBarPreviewParts, parts, preview, page)
                end
                if page.id == "party" then
                    if extras.AddPartyPortraitMove then pcall(extras.AddPartyPortraitMove, preview, parts) end
                    if extras.AddPartyPowerMove then pcall(extras.AddPartyPowerMove, preview, parts) end
                end
                return parts
            end
        elseif readParts and mod.name == "Nameplates" then
            preview.Parts = function(...)
                local parts = readParts(...) or {}
                if extras.AddPlateCastTimeMove then pcall(extras.AddPlateCastTimeMove, parts) end
                return parts
            end
        end
        return preview
    end
end

-- Per-bar rows on Daylight's "Bars" card show only for the bar picked
-- under "Settings for", like Daylight's own rows on that card.
local function followPick(group, item)
    local picker
    for _, row in ipairs(group.items) do
        if row.type == "dropdown" and row.get and not row.key then picker = row; break end
    end
    local id = item.key and item.key:match("^bars%.([^.]+)%.")
    if not (picker and id) then return end
    local own = item.hidden
    item.baseHidden = own
    item.hidden = function(get) return picker.get() ~= id or (own ~= nil and own(get) == true) end
end
-- ---------------------------------------------------------------------------
-- Blasta's own menu. Every row Blasta adds to a DaylightUI page comes off that
-- page again and goes to one of Blasta's pages, so DaylightUI's menus show only
-- DaylightUI. The rows keep their keys and still save in the DaylightUI module
-- they extend (bridged get/set), so nothing a player set is lost.
-- ---------------------------------------------------------------------------

-- Blasta's pages, in menu order. Options.lua builds them from this.
extras.MENU = {
    { id = "start", label = "Overview" },
    { id = "units", label = "Unit frames" },
    { id = "auras", label = "Auras & DoTs" },
    { id = "plates", label = "Nameplates" },
    { id = "bars", label = "Action bars" },
    { id = "info", label = "Info panel & buffs" },
    { id = "tooltips", label = "Tooltips & money" },
    { id = "windows", label = "Windows" },
    { id = "world", label = "World & moments" },
    { id = "language", label = "General" },
}

local MODULE_PAGE = {
    Nameplates = "plates", UnitFrames = "units", ActionBars = "bars", Tooltip = "tooltips",
    InfoPanel = "info", Buffs = "info", Bags = "windows", Professions = "windows", Quests = "windows",
    QoL = "world", Skins = "world", Chat = "world",
}
-- Pages the older Blasta menus named in a row's blastaDestination.
local OLD_PAGE = { Auras = "auras", UnitFrames = "units", Afk = "world" }
-- Pages whose rows sit in one list, without tabs.
local NO_TABS = { tooltips = true }
local AURA_GROUP = { Buffs = true, Debuffs = true, Auras = true }
local SCANNED = { "Nameplates", "UnitFrames", "ActionBars", "Tooltip", "QoL", "Professions", "Quests", "Bags",
    "Skins", "InfoPanel", "Buffs", "Chat" }

local function auraRow(group, item)
    if AURA_GROUP[group.label] then return true end
    local key = type(item.key) == "string" and item.key:lower() or ""
    return key:find("aura", 1, true) ~= nil or key:find("dispel", 1, true) ~= nil
        or key:find("blastadot", 1, true) ~= nil
end

-- Unit frame pages share tabs, so the tab row fits: the main frames keep
-- their own, the raid sizes share one and the smaller frames share "More
-- frames", their cards named after the frame.
local UNIT_TAB = { player = "Player", target = "Target", party = "Party", raid = "Raid", raid20 = "Raid",
    raid40 = "Raid", colors = "Look", castbars = "Cast bars", swing = "Cast bars" }
local NAMED_BY_FRAME = { Raid = true, ["More frames"] = true }

local function worldTab(label)
    local text = type(label) == "string" and label:lower() or ""
    if text:find("flight", 1, true) or text:find("breath", 1, true) or text:find("mirror", 1, true)
        or text:find("timer", 1, true) then return "Flight & breath bars" end
    if text:find("map", 1, true) then return "World map" end
    if text:find("loot", 1, true) then return "Loot" end
    if text:find("zone", 1, true) then return "Zone title" end
    if text:find("afk", 1, true) or text:find("away", 1, true) then return "AFK screen" end
    return label
end

-- Blasta page, tab and card a row goes to.
local function route(mod, source, group, item)
    local dest = item.blastaDestination
    local where = MODULE_PAGE[mod.name] or "world"
    local tab, label = source.label, group.label
    local name = mod.name
    if name == "UnitFrames" then
        if (dest and dest.page == "Auras") or auraRow(group, item) then where = "auras" end
        tab = UNIT_TAB[source.id] or "More frames"
        if where == "auras" and tab == "Look" then tab = "General" end
        if NAMED_BY_FRAME[tab] then label = source.label end
        if dest then
            if OLD_PAGE[dest.page] then where = OLD_PAGE[dest.page] end
            tab = dest.tab or tab
            label = dest.label or label
        end
    elseif name == "Buffs" then
        tab = "Buffs"
    elseif name == "Bags" or name == "Professions" or name == "Quests" then
        tab = mod.label or name
    elseif name == "QoL" or name == "Skins" then
        local key = type(item.key) == "string" and item.key:lower() or ""
        if dest and dest.page == "Afk" then tab, label = "AFK screen", dest.label or label
        elseif key:find("flight", 1, true) then tab, label = "Flight & breath bars", "Flight timer"
        elseif key:find("mirror", 1, true) or key:find("breath", 1, true) then
            tab, label = "Flight & breath bars", "Breath and fatigue bar"
        else tab = worldTab(group.label) or source.label end
    end
    if group.blastaTab then tab = group.blastaTab end
    if name == "Chat" then tab = "Chat" end
    if where == "world" and (tab == "Loot feed" or tab == "Loot Roll Window") then tab = "Loot" end
    if NO_TABS[where] then tab = nil end
    if type(label) ~= "string" or label == "" then label = type(source.label) == "string" and source.label or "Settings" end
    if tab ~= nil and (type(tab) ~= "string" or tab == "") then tab = nil end
    return where, tab, label
end

-- A row of a DaylightUI module, read and saved there. mapKey and locks of the
-- page it came from still apply (the raid page maps its rows per raid size).
local function bridgeTo(mod, source, row)
    if row.blastaBridged then return row end
    row.blastaBridged = true
    local options = DUI.Options
    local function path(key)
        if options and options.Key then return options.Key(source, key) end
        return key
    end
    local function get(key) return DUI:Get(mod.name, path(key)) end
    if row.key and not row.get then
        local key = row.key
        row.get = function() return get(key) end
        row.set = function(value) return DUI:Set(mod.name, path(key), value) end
        row.default = function() return DUI.DB.GetPath(mod.defaults, path(key)) end
    end
    local hidden, disabled = row.hidden, row.disabled
    row.hidden = function() return not mod.enabled or (hidden ~= nil and hidden(get) == true) end
    local locked = source.locked and options and options.Locked
    if disabled or locked then
        row.disabled = function()
            if locked and options.Locked(source, row) then return true end
            return disabled ~= nil and disabled(get) == true
        end
    end
    return row
end

-- The "Settings for" dropdown of a picker card (one bar, one aura bar...):
-- Blasta's rows on that card show for the picked one, so the card on Blasta's
-- page carries the same dropdown.
local function pickerOf(group)
    if not group.Picked then return end
    for _, row in ipairs(group.items or {}) do
        if row.type == "dropdown" and row.get and not row.key then return row end
    end
end

local collected = {}   -- Blasta page id -> { order = { cards }, cards = { [tab|label] = card }, samples = { [tab] = source } }
local function into(where)
    local dest = collected[where]
    if not dest then
        dest = { order = {}, cards = {}, samples = {}, tabs = {} }
        collected[where] = dest
    end
    return dest
end

local function remember(dest, tab, source, group, mod)
    local key = tab or ""
    local sample = group and group.blastaSample
    if tab == "Chat" and mod and mod.name == "Chat" and (sample or type(source.sample) == "function") then
        local reference = sample or source
        local entry = dest.samples[key] or { previews = {} }
        if not entry.previews then
            entry.label = "Chat"
            entry = { previews = { entry } }
        end
        dest.samples[key] = entry
        for _, preview in ipairs(entry.previews) do
            if preview.reference == reference then return end
        end
        entry.previews[#entry.previews + 1] = {
            reference = reference, sample = sample or source.sample,
            label = sample and group.label or source.label,
            page = not sample and source or nil, mod = not sample and mod.name or nil,
        }
        return
    end
    if dest.samples[key] then return end
    if sample then
        dest.samples[key] = { sample = sample }
    elseif type(source.sample) == "function" then
        dest.samples[key] = { sample = function(parent) return source.sample(parent) end, page = source,
            mod = mod and mod.name }
    end
end

local function cardFor(dest, tab, label, mod, source, group)
    local id = (tab or "") .. "\0" .. tostring(label)
    local card = dest.cards[id]
    if not card then
        card = { label = label, desc = type(group.desc) == "string" and label == group.label and group.desc or nil,
            tab = tab, items = {}, blastaModule = mod,
            reveal = group.reveal, Picked = group.Picked }
        local picker = pickerOf(group)
        if picker then card.items[1] = picker; card.blastaPicker = picker end
        dest.cards[id] = card
        dest.order[#dest.order + 1] = card
        if tab and not dest.tabs[tab] then dest.tabs[tab] = true; dest.tabs[#dest.tabs + 1] = tab end
    end
    remember(dest, tab, source, group, mod)
    return card
end

function extras.CollectSettings()
    if extras.SettingsCollected then return collected end
    extras.SettingsCollected = true
    if extras.PlaceTooltipCards then pcall(extras.PlaceTooltipCards) end
    if extras.PlaceBarFxCombat then pcall(extras.PlaceBarFxCombat) end
    for _, name in ipairs(SCANNED) do
        local mod = DUI:GetModule(name)
        for _, source in ipairs(mod and mod.options and mod.options.pages or {}) do
            wrapSample(mod, source)
            local groups = source.groups or {}
            local gi = 1
            while gi <= #groups do
                local group = groups[gi]
                local items = group.items or {}
                local picker = name == "ActionBars" and group.Picked ~= nil
                if picker then
                    -- Pixel-exact bars: Blasta's own button size and spacing
                    -- sliders, the same settings as DaylightUI's, in half
                    -- pixels and down to -10. DaylightUI's rows stay as they are.
                    local fine = {}
                    for _, row in ipairs(items) do
                        local field = original[row] and row.key and row.key:match("^bars%.[^.]+%.([^.]+)$")
                        if (field == "pad" or field == "size") and row.type == "slider" then
                            local copy = {}
                            for k, v in pairs(row) do copy[k] = v end
                            copy.blastaCopy = true   -- DaylightUI's setting: Reset this tab leaves it
                            if field == "pad" then
                                copy.min = math.min(type(row.min) == "number" and row.min or 0, -10)
                                copy.label = "Button spacing (fine)"
                            else
                                copy.step = math.min(row.step or 1, 0.5)
                                copy.label = "Button size (half pixels)"
                            end
                            fine[#fine + 1] = copy
                        end
                    end
                    for _, copy in ipairs(fine) do items[#items + 1] = copy end
                end
                local kept, moved = 0, false
                for i = 1, #items do
                    local item = items[i]
                    if original[item] then
                        kept = kept + 1
                        items[kept] = item
                    else
                        moved = true
                        if picker then followPick(group, item) end
                        local where, tab, label = route(mod, source, group, item)
                        item.blastaDestination, item.blastaCompanion = nil, nil
                        local card = cardFor(into(where), tab, label, mod, source, group)
                        card.items[#card.items + 1] = bridgeTo(mod, source, item)
                    end
                end
                for i = #items, kept + 1, -1 do items[i] = nil end
                if moved and kept == 0 then table.remove(groups, gi) else gi = gi + 1 end
            end
        end
    end
    -- One line on each card when the DaylightUI module or switch it extends is
    -- off; rows that need a switch hide until it's on (addNotices).
    for _, dest in pairs(collected) do
        for _, card in ipairs(dest.order) do
            local mod = card.blastaModule
            card.blastaModule = nil
            local rows = {}
            for _, row in ipairs(card.items) do
                if row ~= card.blastaPicker then rows[#rows + 1] = row end
            end
            local count = #rows
            addNotices(mod, rows)
            for i = #rows - count, 1, -1 do table.insert(card.items, 1, rows[i]) end
        end
    end
    return collected
end

-- Design mode on Blasta's pages: DaylightUI saves a drag in the page's own
-- settings (Blasta's), so a dragged part of a DaylightUI preview passes its
-- keys here and the value goes on to the module the part belongs to. Blasta's
-- copy of the value stays, so the arrow keys start from where the part is.
local forward = {}   -- key -> { mod = module name, path = its key there }
local forwarding
local function forwardSets()
    if forwarding ~= nil or not hooksecurefunc then return end
    forwarding = false
    hooksecurefunc(DUI, "Set", function(_, scope, key, value)
        if forwarding or scope ~= ADDON or type(key) ~= "string" then return end
        local to = forward[key]
        if not to then return end
        forwarding = true
        pcall(DUI.Set, DUI, to.mod, to.path, value)
        forwarding = false
    end)
end
local function mirror(key)
    local to = forward[key]
    local me = DUI:GetModule(ADDON)
    if not (to and me and type(me.db) == "table") then return end
    DUI.DB.SetPath(me.db, key, DUI:Get(to.mod, to.path))
end

-- A preview that follows the page's tabs: each tab shows the preview of the
-- DaylightUI page its cards came from (or Blasta's own), so the unit frame
-- tab shows that frame, the nameplate tab a nameplate. Parts whose settings
-- are on this page can be clicked (known: those keys), and dragged in Design
-- mode when they can move.
function extras.TabbedSample(byTab, known, fallback)
    forwardSets()
    return function(parent)
        local holder = CreateFrame("Frame", nil, parent)
        local made, current, currentEntry = {}, nil, nil
        local chosen, activePreviews = {}, nil
        local s = { frame = holder }
        local function wanted()
            local panel = DUI.OptionsPanel
            local pf = panel and panel.PageFrame and panel.PageFrame()
            local tab = pf and pf.tab
            return (tab and byTab[tab]) or byTab[""] or (fallback and byTab[fallback])
        end
        local function instance(source)
            local inner = made[source]
            if inner == nil then
                local ok, built = pcall(source.sample, holder)
                inner = ok and type(built) == "table" and built.frame and built or false
                made[source] = inner
                if inner then inner.frame:Hide() end
            end
            return inner or nil
        end
        function s.Refresh(width, room)
            local source = wanted()
            activePreviews = source and source.previews
            if activePreviews then source = activePreviews[chosen[activePreviews] or 1] end
            local inner = source and instance(source)
            if current and current ~= inner then current.frame:Hide() end
            current, currentEntry = inner, source
            if not inner then return 0 end
            inner.frame:SetParent(holder)
            inner.frame:ClearAllPoints()
            inner.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
            inner.frame:Show()
            local ok, h = pcall(inner.Refresh, width, room)
            if not ok or type(h) ~= "number" then return 0 end
            holder:SetSize(math.max(1, width), math.max(1, h))
            return h
        end
        function s.Parts()
            if not (current and current.Parts) then return {} end
            local ok, parts = pcall(current.Parts)
            if not ok or type(parts) ~= "table" then return {} end
            local entry = currentEntry
            local options = DUI.Options
            local function route(key)
                if not (entry and entry.mod and type(key) == "string") then return false end
                local path = options and options.Key and entry.page and options.Key(entry.page, key) or key
                forward[key] = { mod = entry.mod, path = path }
                mirror(key)
                return true
            end
            local out = {}
            for _, part in ipairs(parts) do
                local keys, movable = {}, false
                for _, key in ipairs(part.keys or {}) do
                    if not known or known[key] then keys[#keys + 1] = key end
                end
                local m = part.move
                if m and (m.xKey or m.yKey) and ((m.xKey and known and known[m.xKey]) or (m.yKey and known and known[m.yKey])) then
                    movable = (not m.xKey or route(m.xKey)) and (not m.yKey or route(m.yKey))
                    if movable and m.spotKey and known[m.spotKey] then route(m.spotKey) end
                end
                local size = part.size
                if movable and size and type(size.keys) == "table" then
                    for _, key in pairs(size.keys) do route(key) end
                end
                if (#keys > 0 or movable) and part.region then
                    local copy = {}
                    for k, v in pairs(part) do copy[k] = v end
                    copy.keys = #keys > 0 and keys or part.keys
                    if not movable then copy.move, copy.size = nil, nil end
                    out[#out + 1] = copy
                end
            end
            return out
        end
        function s.Views()
            if activePreviews and #activePreviews > 1 then
                local views = {}
                for i, preview in ipairs(activePreviews) do
                    views[i] = { key = i, label = extras.Translate(preview.label),
                        on = i == (chosen[activePreviews] or 1) }
                end
                return views
            end
            if current and current.Views then return current.Views() end
        end
        function s.SetView(key, ...)
            if activePreviews and #activePreviews > 1 then
                if activePreviews[key] then chosen[activePreviews] = key end
            elseif current and current.SetView then
                return current.SetView(key, ...)
            end
        end
        return s
    end
end
