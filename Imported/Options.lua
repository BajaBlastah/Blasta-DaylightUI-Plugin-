local ADDON, ns = ...
if not ns.ok then return end

local DUI = DaylightUI

-- Blasta's own menu. Everything Blasta adds sits here, in its own section of
-- DaylightUI's options window, and DaylightUI's pages show only DaylightUI.
-- Rows that extend a DaylightUI feature still save in that feature's module
-- (Settings.lua bridges them), and each page shows a live preview on top that
-- follows its tabs.
local collected = ns.CollectSettings()
local menu = ns.MENU

local own = {}   -- Blasta page id -> { { group, tab, sample } } of Blasta's own cards
local function add(where, tab, groups, sample)
    own[where] = own[where] or {}
    for _, group in ipairs(groups or {}) do
        own[where][#own[where] + 1] = { group = group, tab = tab, sample = sample }
    end
end
local function groupsOf(page) return page and page.groups or {} end
local function call(fn, ...) if type(fn) == "function" then return fn(...) end end

local unitFrames = DUI:GetModule("UnitFrames")
local barCard = unitFrames and ns.AuraBarCard and ns.AuraBarCard()
if barCard then add("auras", "Aura bars", groupsOf(ns.ShowDaylightRequirements({ groups = { barCard } }, unitFrames))) end
add("units", "Bar effects", groupsOf(call(ns.BarEffectsPage)))
add("bars", "Resource costs", { ns.RageNeedGroup }, ns.RageNeedSample and function(parent) return ns.RageNeedSample(parent) end)
add("bars", "Food and drink", { call(ns.ConsumableBarsGroup) })
add("info", "Experience bar", groupsOf(call(ns.ExperiencePage)))
add("info", "General", groupsOf(call(ns.InfoPanelSpacingPage)))
add("info", "Data texts", groupsOf(call(ns.DataTextColorPage)))
add("info", "Buffs", groupsOf(call(ns.PlayerAuraLayoutPage)))
add("info", "Buffs", { call(ns.AuraIconCornersGroup) })
add("info", "Damage meter corner", { call(ns.MeterCornerGroup) })
add("info", "Buff reminders", groupsOf(call(ns.AuraReminderPage)))
add("windows", "Group Finder", { ns.DungeonFinderGroup })
add("windows", "Spellbook", { ns.SpellbookGroup })
add("windows", "Character", { ns.CharacterPanelGroup })
add("world", "World map", { ns.MapLevelsGroup })
add("world", "Chat", { call(ns.ChatCornerGroup) })
add("world", "Zone title", { call(ns.ZoneTitleExtrasGroup) })
add("world", "Loot", call(ns.LootSpaceGroups))
add("world", "Loot", groupsOf(call(ns.LootFeedPage)))
add("language", "General", groupsOf(call(ns.GeneralPage)))
add("language", "Profiles", groupsOf(call(ns.ProfileTransferPage)))

-- What each page holds, for the overview.
local BLURB = {
    units = "Frame slants, portrait shapes, party portraits and resource bar, text sizes, level badges and bar effects.",
    auras = "Aura bars, aura sizes and shapes, the dispel highlight, DoT fill, finisher damage and Shadow Word: Death.",
    plates = "Nameplate shape and edges, borders, names, the cast bar's entrance, aura sizes and motion.",
    bars = "Pixel-exact bars, slants, resource costs on buttons, channel ticks and food and drink bars.",
    info = "Experience bar and its animation, data texts, the top right layout, buffs and buff reminders.",
    tooltips = "Blasta tooltips, their text sizes, DaylightUI's coins everywhere and sell prices per piece.",
    windows = "Group finder, spellbook and training, character window, professions, bags and quests.",
    world = "World map levels and routes, zone title, loot feed, flight and breath timers, AFK screen.",
    language = "Language, login message, startup animation and profiles.",
}

local pages = {}
local samples = {}   -- page -> { [raw tab or ""] = source }
for _, entry in ipairs(menu) do
    local where = entry.id
    local dest = collected[where]
    local groups, bySource = {}, {}
    if dest then
        for _, card in ipairs(dest.order) do
            card.blastaRawTab = card.tab
            groups[#groups + 1] = card
        end
        for tab, source in pairs(dest.samples) do bySource[tab] = source end
    end
    for _, item in ipairs(own[where] or {}) do
        local group = item.group
        if group and group.items then
            group.tab = item.tab
            group.blastaRawTab = item.tab
            groups[#groups + 1] = group
            local key = item.tab or ""
            if item.sample and not bySource[key] then bySource[key] = { sample = item.sample } end
        end
    end
    -- Tabs in a steady order: each tab's cards together, tabs as they first
    -- appear. One tab only is no tabs at all; a card without one joins "General".
    local tabOrder, seen = {}, {}
    for _, group in ipairs(groups) do
        local tab = group.tab
        if tab and not seen[tab] then seen[tab] = true; tabOrder[#tabOrder + 1] = tab end
    end
    local rank = {}
    for i, tab in ipairs(tabOrder) do rank[tab] = i end
    for i, group in ipairs(groups) do
        local tab = group.tab
        if #tabOrder < 2 then
            group.tab = nil
        elseif not tab then
            group.tab = "General"
            tab = rank.General and "General" or nil
        end
        group.blastaSort = (tab and rank[tab] or 0) * 1000 + i
    end
    table.sort(groups, function(a, b) return a.blastaSort < b.blastaSort end)
    for _, group in ipairs(groups) do group.blastaSort = nil end
    if where == "start" or #groups > 0 then
        local page = { id = where, label = entry.label, desc = BLURB[where], groups = groups }
        pages[#pages + 1] = page
        samples[page] = bySource
    end
end

-- The overview: what Blasta is, then one line per page with a way there.
local start = pages[1]
local function open(id)
    return function()
        local panel = DUI.OptionsPanel
        if panel and panel.Show then panel.Show(ADDON .. "." .. id) end
    end
end
local overview = { label = "Blasta (DaylightUI Plugin)", items = {
    { type = "text", label = "Blasta adds settings and refinements to DaylightUI. It's a plugin by its own author, "
        .. "not part of DaylightUI: please send Blasta bugs to Blasta, not to the DaylightUI team." },
    { type = "button", label = "Report a Blasta bug", text = "Bug report",
      desc = "Opens a window with everything a bug report needs, ready to copy.",
      func = function() if ns.Report and ns.Report.Show then ns.Report.Show() end end },
} }
local areas = { label = "Settings", items = {} }
for i = 2, #pages do
    local page = pages[i]
    areas.items[#areas.items + 1] = { type = "button", label = page.label, desc = BLURB[page.id], text = "Open",
        func = open(page.id) }
end
-- What's new in this version, each with a way to its setting. Shown for the
-- version only; the rows themselves carry the "New" tag on their pages.
local function pageWith(key)
    for _, page in ipairs(pages) do
        for _, group in ipairs(page.groups or {}) do
            for _, item in ipairs(group.items or {}) do
                if item.key == key then return page end
            end
        end
    end
end
local function jump(key, fallback)
    return function()
        local panel = DUI.OptionsPanel
        local page = key and pageWith(key)
        local id = page and page.id or fallback
        if not (panel and panel.Show and id) then return end
        panel.Show(ADDON .. "." .. id)
        if key and panel.JumpTo then C_Timer.After(0, function() pcall(panel.JumpTo, { key }) end) end
    end
end
local NEWS = {
    { "Compact equipment tooltips and improved comparisons", "blastaStyle", "tooltips" },
    { "Make room for loot", "blastaLootSpace", "world" },
    { "Loot item icon border", "blastaLootIconBorder", "world" },
    { "Bag font sizes and category selling in DaylightUI's Bags settings" },
}
ns.German["Compact equipment tooltips and improved comparisons"] = "Kompakte Ausrüstungstooltips und verbesserte Vergleiche"
ns.German["Bag font sizes and category selling in DaylightUI's Bags settings"] =
    "Schriftgrößen und Kategorienverkauf in DaylightUIs Tascheneinstellungen"
local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
local news = { label = "New in Blasta " .. tostring(version or ""), items = {} }
if ns.German then ns.German[news.label] = "Neu in Blasta " .. tostring(version or "") end
for _, entry in ipairs(NEWS) do
    if entry[2] == nil or pageWith(entry[2]) then
        if entry[3] then
            news.items[#news.items + 1] = { type = "button", label = entry[1], text = "Show", noSearch = true,
                func = jump(entry[2], entry[3]) }
        else
            news.items[#news.items + 1] = { type = "text", label = entry[1], noSearch = true }
        end
    end
end
start.groups = { overview, news, areas }
start.desc = "Everything Blasta adds, in one place."

-- A help line on each tab and buttons that open the windows a tab changes
-- (SidePanel.lua), before the names are translated.
if ns.AddMenuHelp then ns.AddMenuHelp(pages) end

ns.LocalizePages(pages)

-- The Tooltips page shows its preview in a column on the right of the
-- window (SidePanel.lua) instead of the strip above the settings.
local COLUMN = { tooltips = ns.TooltipSample ~= nil and ns.RefreshTooltipColumn ~= nil }

-- Previews after the tabs are translated: the panel reports the shown tab by
-- its finished name.
for _, page in ipairs(pages) do
    local bySource, byTab, any, known = samples[page], {}, false, {}
    for _, group in ipairs(page.groups) do
        for _, row in ipairs(group.items) do
            if type(row.key) == "string" then known[row.key] = true end
            for _, key in ipairs(row.blastaDesignerKeys or {}) do known[key] = true end
        end
        local source = bySource[group.blastaRawTab or ""]
        local tab = group.tab or ""
        if source and byTab[tab] == nil then byTab[tab] = source; any = true end
        group.blastaRawTab = nil
    end
    if any and not COLUMN[page.id] then page.sample = ns.TabbedSample(byTab, known) end
end

ns.RegisterSettings(pages)
