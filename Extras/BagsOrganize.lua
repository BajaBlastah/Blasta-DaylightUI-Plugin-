-- SPDX-License-Identifier: GPL-3.0-or-later
local ADDON, extras = ...
local DUI = DaylightUI
local bags = extras.Compatible("Bags")
local cat, search = bags and bags.Categories, bags and bags.Search
local items, layout, window = bags and bags.Items, bags and bags.Layout, bags and bags.Window
local W = DUI.Widgets
if not (cat and cat.AddCustom and cat.DeleteCustom and cat.Rename and cat.Assign and cat.Get and cat.Order and cat.Facts
    and cat.Pin and cat.PinOf and cat.Custom and cat.IsRecent
    and search and search.Matches and search.Facts and search.KEYWORDS and search.KEYWORDS.quest
    and items and items.InfoAt and layout and layout.Apply and layout.Groups and layout.ShowEmpty
    and window and window.Changed and window.Relayout and window.FillAll and window.MatchAll
    and W.Tab and W.Prompt and W.OpenMenu) then return end

local T = extras.Translate
local setting = "blastaBags"
local windowState

local filterHeight = W.TAB_H or 24
local extraHeight = filterHeight + 3
local function enabled()
    return DUI:Get(ADDON, setting) == true
end
local filterSetting = "blastaBagFilters"
local function filtersOn()
    return enabled() and DUI:Get(ADDON, filterSetting) ~= false
end

local style = DUI.Style

-- Single categories are renamed, hidden and deleted on DaylightUI's own
-- Categories page; Blasta no longer keeps a second list for that.
local function hidden() return false end

local subclass = Enum and Enum.ItemTradegoodsSubclass or {}
local groups = {
    { "cloth", "Bag cloth", subclass.Cloth or 5 },
    { "leather", "Bag leather", subclass.Leather or 6 },
    { "metal", "Metal and stone", subclass.MetalAndStone or 7 },
    { "cooking", "Cooking materials", subclass.Cooking or 8 },
    { "herbs", "Bag herbs", subclass.Herb or subclass.Herbs or 9 },
    { "enchanting", "Enchanting materials", subclass.Enchanting or 12 },
}

local function updateMaterial(key, label, id)
    local api = enabled() and DUI.API and DUI.API.For and DUI.API.For(ADDON)
    if not (api and api.AddBagGroup and search.CLASS) then return end
    api.AddBagGroup(key, { label = T(label), match = function(facts)
        return facts.classID == search.CLASS.tradegoods and facts.subClassID == id
    end })
end

DUI.On("Login", function()
    for _, group in ipairs(groups) do updateMaterial(unpack(group)) end
end)

local function inCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function itemID(info)
    local id = info and info.itemID
    if type(id) == "number" and not (issecretvalue and issecretvalue(id)) then return id end
end

local function passes(filter, bag, slot, info, section)
    if filter == "group:empty" then return info == nil end
    local id = itemID(info)
    if not id then return false end
    if filter == "new" then return cat.IsRecent(bag, slot, id) end
    if filter == "quest" then return search.KEYWORDS.quest(search.Facts(bag, slot, info)) end
    local key = cat.Assign(cat.Facts(bag, slot, info), section)
    if filter:sub(1, 6) == "group:" then return key == filter:sub(7) end
    local group = cat.Get(key)
    return group and group.custom == true
end

local function build(frame)
    local bar = CreateFrame("Frame", nil, frame)
    bar:SetFrameLevel(frame:GetFrameLevel() + 5)
    bar:SetHeight(filterHeight)
    local state = { frame = frame, bar = bar, filter = "all", filters = {} }
    windowState = state
    local controls = {}
    local function add(b) controls[#controls + 1] = b; return b end
    local function pick(key)
        if inCombat() then return end
        state.filter = key
        for id, control in pairs(state.filters) do control.Pick(id == key, true) end
        window.Relayout(frame)
        window.FillAll(frame)
    end
    local labels = { all = "All", new = "New loot", quest = "Quest filter", custom = "Own categories" }
    for _, key in ipairs({ "all", "new", "quest", "custom" }) do
        local b = add(W.Tab(bar, T(labels[key])))
        b:SetScript("OnClick", function() pick(key) end)
        b.Pick(key == state.filter, false)
        state.filters[key] = b
    end
    state.categoryFilter = W.Tab(bar, T("Bag categories"))
    state.categoryFilter:SetPoint("LEFT", bar, "LEFT", 264, 0)
    state.categoryFilter:SetWidth(88)
    state.categoryFilter:SetScript("OnClick", function(owner)
        if inCombat() then return end
        local keys, labels = { "all" }, { all = T("All") }
        for _, key in ipairs(cat.Order()) do
            local group = cat.Get(key)
            if group then
                local filter = "group:" .. key
                keys[#keys + 1] = filter
                labels[filter] = group.name
            end
        end
        W.OpenMenu(owner, keys, labels, state.filter, pick)
    end)
    for i, b in ipairs(controls) do
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * 66, 0)
        b:SetWidth(62)
    end
end

local function positionFilters(frame, nativeHeight)
    local bar = windowState.bar
    local top = window.Top and window.Top(frame) or window.TITLE
    local y = -(top + window.ROW + 2 * window.GAP + nativeHeight)
    bar:SetPoint("TOPLEFT", frame, "TOPLEFT", window.EDGE, y)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -window.EDGE, y)
end

if window.LayoutChips then
    local layoutChips = window.LayoutChips
    function window.LayoutChips(frame, ...)
        local height = layoutChips(frame, ...)
        if windowState and frame == windowState.frame then
            positionFilters(frame, height)
            local point, relative, anchor, x, y = frame.items:GetPoint(1)
            frame.items:ClearAllPoints()
            frame.items:SetPoint(point, relative, anchor, x, y - extraHeight)
            return height + extraHeight
        end
        return height
    end

    local feel = DUI.Win and DUI.Win.Feel
    if feel and feel.Moving and feel.Settle then
        hooksecurefunc(window, "Relayout", function(frame)
            -- Native grid glides start at the previous anchor, which can now
            -- be inside the filter row after the header or chip height changes.
            if windowState and frame == windowState.frame and not frame.stale and not inCombat()
                and feel.Moving(frame.items) then
                feel.Settle(frame.items)
            end
        end)
    end
end

local apply = layout.Apply
function layout.Apply(frame, cfg)
    if frame.kind ~= "bag" or (not windowState and not filtersOn()) then return apply(frame, cfg) end
    if not windowState then build(frame) end
    if not window.LayoutChips then
        positionFilters(frame, 0)
        local y = -(window.TITLE + window.ROW + 2 * window.GAP + extraHeight)
        frame.items:SetPoint("TOPLEFT", frame, "TOPLEFT", window.EDGE, y)
    end
    local w, h
    local filter = windowState.filter
    local key = filter:sub(1, 6) == "group:" and filter:sub(7)
    local group = key and not hidden(key) and cat.Get(key)
    if not group and filter:sub(1, 6) == "group:" then
        filter = "all"
        windowState.filter = filter
        windowState.filters.all.Pick(true, false)
    end
    windowState.categoryFilter.Pick(group ~= nil and group ~= false, false)
    windowState.categoryFilter.text:SetText(group and group.name or T("Bag categories"))
    windowState.categoryFilter.text:SetWidth(88)
    windowState.categoryFilter.text:SetWordWrap(false)
    if filter == "all" then
        w, h = apply(frame, cfg)
    else
        local slots = frame.set.Slots
        local visible = {}
        for _, slot in ipairs(slots()) do
            local button = slot.button
            local id = button:GetID()
            if passes(filter, slot.bag, id, items.InfoAt(slot.bag, id), slot.section) then
                visible[#visible + 1] = slot
            else
                button:Hide()
            end
        end
        frame.set.Slots = function() return visible, false end
        local ok
        ok, w, h = pcall(apply, frame, cfg)
        frame.set.Slots = slots
        -- Daylight's hold-layout optimization must not compare against a partial grid.
        frame.laid = nil
        if not ok then error(w, 0) end
    end
    return math.max(w, 355), h + (window.LayoutChips and 0 or extraHeight)
end

hooksecurefunc(window, "Changed", function(frame)
    if not windowState or frame ~= windowState.frame or windowState.filter == "all"
        or frame.Setting("view") == "categories" or frame.Setting("emptySlots") == "grouped"
        or inCombat() or frame.stale or not frame:IsShown() then return end
    window.Relayout(frame)
    window.FillAll(frame)
end)

extras.German["Sorts DaylightUI's bags with Blasta's material and standard categories, and adds Blasta's filter bar."] =
    "Sortiert DaylightUIs Taschen mit Blastas Material- und Standardkategorien und ergänzt Blastas Filterleiste."
extras.German["Blasta categories"] = "Blasta-Kategorien"
extras.German["Blasta filter bar"] = "Blasta-Filterleiste"
extras.German["Sorts DaylightUI's bags with Blasta's material and standard categories."] =
    "Sortiert DaylightUIs Taschen mit Blastas Material- und Standardkategorien."
extras.German["A row of filters over the bags: all, new loot, quests, your own categories and a category menu."] =
    "Eine Filterreihe über den Taschen: alle, neue Beute, Quests, eigene Kategorien und ein Kategorie-Menü."
-- Both switches sit at the top of DaylightUI's "Shelf and List views" card.
local bagModule = DUI:GetModule("Bags")
extras.AddSetting(bagModule, "combineStacks", {
    type = "toggle", key = "blastaBags", label = "Blasta categories", reload = true, blastaSince = "1.7",
    desc = "Sorts DaylightUI's bags with Blasta's material and standard categories.",
    get = enabled, default = function() return false end,
    set = function(value) return DUI:Set(ADDON, setting, value) end }, true)
extras.AddSetting(bagModule, "combineStacks", {
    type = "toggle", key = "blastaBagFilters", label = "Blasta filter bar", reload = true, blastaSince = "1.7",
    desc = "A row of filters over the bags: all, new loot, quests, your own categories and a category menu.",
    get = function() return DUI:Get(ADDON, filterSetting) ~= false end, default = function() return true end,
    disabled = function() return not enabled() end,
    set = function(value) return DUI:Set(ADDON, filterSetting, value) end }, true)

extras.Loaded("BagsOrganize")
