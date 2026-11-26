-- SPDX-License-Identifier: GPL-3.0-or-later
local ADDON, extras = ...
local DUI = DaylightUI
local Char = DUI.Char
local Page, Stats, Gear = Char and Char.CharacterPage, Char and Char.Stats, Char and Char.Gear
local Style = DUI.Style
if not (Page and Page.Rects and Page.Place and Page.PaintFooter and Page.RefreshStats and Page.Build
    and Stats and Stats.GROUPS and Stats.Read and Stats.IsOpen and Gear and Gear.LEFT and Gear.RIGHT
    and Style and extras.CharacterGrid) then return end
local function on()
    local layout = DUI:Get(ADDON, "characterPanel.layout")
    return DUI:Get(ADDON, "characterPanel.enabled") == true
        and (layout == "grid" or (layout ~= "classic" and DUI:Get(ADDON, "characterPanel.refined") ~= false))
end
local T = extras.Translate
extras.German["Refined character sheet"] = "Überarbeitetes Charakterfenster"
extras.German["Model on the left, a compact equipment grid and focused stat tabs. Keeps your equipment quality gradients."] =
    "Modell links, kompaktes Ausrüstungsraster und Werte-Tabs. Deine Qualitätsfarbverläufe bleiben erhalten."
extras.German["Spell stats"] = "Zauber"
extras.German["Melee stats"] = "Nahkampf"
extras.German["Ranged stats"] = "Distanz"
extras.German["All stats"] = "Alle"
extras.German["Character sheet layout"] = "Aufbau des Charakterfensters"
extras.German["Equipment grid"] = "Raster"
extras.German["Classic"] = "Klassisch"
extras.German["Choose the classic equipment around the model or the equipment grid. Both keep your existing appearance settings."] =
    "Wähle die klassische Ausrüstung um das Modell oder das Ausrüstungsraster. Deine bisherigen Darstellungseinstellungen bleiben erhalten."
local state = setmetatable({}, { __mode = "k" })
local function plain(v) if not (issecretvalue and issecretvalue(v)) then return v end end
local function line(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetColorTexture(1, 1, 1, 0.12)
    t:SetHeight(DUI.Pixel.Px(parent, 1))
    return t
end
local function get(page)
    local s = state[page]
    if not s then s = { dividers = {} }; state[page] = s end
    return s
end

-- Give names room instead of squeezing a mockup into the old 1000px shell.
-- Respect the usable screen width and retain the compact icons-only layout.
if Char.Window and Char.Window.Width then
    local width = Char.Window.Width
    function Char.Window.Width()
        local base = width()
        if not on() or (Char.Setting and Char.Setting("names") == false) then return base end
        local scale = DUI.Win and DUI.Win.Scale and DUI.Win.Scale(Char.Setting and Char.Setting("scale")) or 1
        local screen = UIParent and UIParent.GetWidth and UIParent:GetWidth()
        local limit = type(screen) == "number" and screen / math.max(0.1, scale or 1) - 48 or base + 120
        return math.min(base + 120, math.max(base, limit))
    end
end
local slotSizes = setmetatable({}, { __mode = "k" })
if Char.Window and Char.Window.Apply and Char.Window.H then
    local apply, baseHeight = Char.Window.Apply, Char.Window.H
    function Char.Window.Apply(...)
        local height = baseHeight
        if on() then
            local scale = DUI.Win and DUI.Win.Scale and DUI.Win.Scale(Char.Setting and Char.Setting("scale")) or 1
            local screen = UIParent and UIParent.GetHeight and UIParent:GetHeight()
            local limit = type(screen) == "number" and screen / math.max(0.1, scale or 1) - 32 or baseHeight + 40
            height = math.min(baseHeight + 40, math.max(baseHeight, limit))
        end
        Char.Window.H = height
        return apply(...)
    end
end
local slotSides = setmetatable({}, { __mode = "k" })
if Char.Slots and Char.Slots.Layout then
    local layoutSlot = Char.Slots.Layout
    function Char.Slots.Layout(slot, ...)
        local parent = slot.GetParent and slot:GetParent()
        if state[parent] and slot.key ~= "Ammo" then
            slotSizes[slot] = slotSizes[slot] or slot.size
            slotSides[slot] = slotSides[slot] or slot.side
            local grid = state[parent].grid
            local node = grid and grid.slots[slot.key]
            slot.size = on() and math.min(slotSizes[slot], node and node.icon or ((slot.key == "Shirt" or slot.key == "Tabard") and 28 or 36)) or slotSizes[slot]
            local side = on() and "left" or slotSides[slot]
            if slot.side ~= side then
                slot.side = side
                if slot.blastaQualityGradient then
                    local gradient = slot.blastaQualityGradient
                    gradient.blastaEdge = nil
                    if gradient.SetVertexOffset then
                        gradient:SetVertexOffset(2, 0, 0)
                        gradient:SetVertexOffset(4, 0, 0)
                    end
                end
            end
            for _, fs in ipairs({ slot.name, slot.line, slot.enchant }) do
                if fs.SetJustifyH then fs:SetJustifyH(side == "right" and "RIGHT" or "LEFT") end
            end
        end
        return layoutSlot(slot, ...)
    end
end

local rects = Page.Rects
local lastRects
function Page.Rects(width, height, names, ammo)
    local r = rects(width, height, names, ammo)
    if on() and extras.CharacterGrid then
        local border = tonumber(DUI:Get(ADDON, "characterPanel.border")) or 3
        if Char.window and DUI.Pixel and DUI.Pixel.Px then border = DUI.Pixel.Px(Char.window, border) end
        local grid = extras.CharacterGrid(width, height, Page.STATS_W, ammo, Page.GROUP_HEAD, border)
        r.grid, r.model, r.stats = grid, grid.model, grid.stats
        r.left.w, r.right.w = grid.slots.Head.w, grid.slots.Head.w
        for i, key in ipairs(Gear.BOTTOM) do r.bottom[i] = grid.slots[key] end
    end
    lastRects = r
    return r
end
extras.German["Armor"] = "Rüstung"
extras.German["Jewelry"] = "Schmuck"
extras.German["Weapons"] = "Waffen"
local function place(page)
    local s, active, r = get(page), on(), lastRects
    if not r then return end
    s.grid = active and r.grid or nil
    local grid = s.grid
    page.foot.blastaGrid = grid ~= nil
    if not s.summary then
        s.summary = CreateFrame("Frame", nil, page)
        s.summary:EnableMouse(false)
        s.statsLine, s.modelLine = line(page), line(page)
        s.groupHeads = {}
    end
    s.summary:SetShown(grid ~= nil)
    for _, head in pairs(s.groupHeads) do head.text:Hide(); head.line:Hide() end
    for _, divider in pairs(s.dividers) do divider:Hide() end
    if page.stats.bg then
        if s.statsAlpha == nil then s.statsAlpha = page.stats.bg:GetAlpha() end
        page.stats.bg:SetAlpha(active and 0 or s.statsAlpha)
    end
    for _, divider in ipairs({ s.statsLine, s.modelLine }) do divider:SetShown(grid ~= nil) end
    if grid then
        s.summary:ClearAllPoints()
        s.summary:SetPoint("TOPLEFT", page, "TOPLEFT", grid.summary.x, grid.summary.y)
        s.summary:SetSize(grid.summary.w, 26)
        for i, x in ipairs({ grid.stats.x - 7, grid.gridX - 7 }) do
            local divider = i == 1 and s.statsLine or s.modelLine
            divider:ClearAllPoints()
            divider:SetColorTexture(1, 1, 1, 0.06)
            divider:SetPoint("TOPLEFT", page, "TOPLEFT", x, -Page.TOP)
            divider:SetPoint("BOTTOMLEFT", page.foot, "TOPLEFT", x - 16, 6)
            divider:SetWidth(DUI.Pixel.Px(page, 1))
        end
        for _, group in ipairs(grid.groups) do
            local head = s.groupHeads[group.key]
            if not head then
                head = { text = Style.Text(page, Page.GROUP_SIZE or 14, "LEFT"), line = line(page) }
                s.groupHeads[group.key] = head
            end
            head.text:ClearAllPoints()
            head.text:SetPoint("LEFT", page, "TOPLEFT", group.x, group.y - (Page.GROUP_HEAD or 26) / 2)
            head.text:SetWidth(group.w)
            if Style.SetTextSize then Style.SetTextSize(head.text, Page.GROUP_SIZE or 14) end
            local title = Style.Upper and Style.Upper(T(group.key)) or T(group.key)
            if Char.Colors and Char.Colors.HeadText then
                Char.Colors.HeadText(head.text, "attributes", title)
            else head.text:SetText(title) end
            -- Exactly one physical pixel on a pixel row, like the stat headings.
            -- A height of 1 UI unit renders 2px (or blurred) at most UI scales.
            local px = DUI.Pixel.Px(page, 1)
            local ly = math.floor((group.y - (Page.GROUP_HEAD or 26)) / px + 0.5) * px
            local lx = math.floor(group.x / px + 0.5) * px
            head.line:ClearAllPoints()
            head.line:SetPoint("BOTTOMLEFT", page, "TOPLEFT", lx, ly)
            head.line:SetPoint("BOTTOMRIGHT", page, "TOPLEFT", lx + math.floor(group.w / px + 0.5) * px, ly)
            head.line:SetHeight(px)
            if head.line.SetSnapToPixelGrid then head.line:SetSnapToPixelGrid(false) end
            if head.line.SetTexelSnappingBias then head.line:SetTexelSnappingBias(0) end
            head.line:SetColorTexture(1, 1, 1, 1)
            if Char.Colors and Char.Colors.Line then Char.Colors.Line(head.line, Page.LINE_ALPHA or 0.85) end
            head.text:Show(); head.line:Show()
        end
    end
    for _, keys in ipairs({ Gear.LEFT, Gear.RIGHT, Gear.BOTTOM }) do
        for _, key in ipairs(keys) do
            local slot = page.slots[key]
            local node = grid and grid.slots[key]
            if slot then
                if node then
                    local names = slot.names
                    if Char.Setting then names = Char.Setting("names") ~= false end
                    Char.Slots.Layout(slot, node.w, names and not node.cosmetic, key == "Ranged" and r.grid.ammo or 0)
                    slot:ClearAllPoints()
                    slot:SetPoint("TOPLEFT", page, "TOPLEFT", node.x, node.y + (node.h - slot.px) / -2)
                end
                if Style.SetTextSize and Char.Slots then
                    local cosmetic = key == "Shirt" or key == "Tabard"
                    Style.SetTextSize(slot.name, active and (cosmetic and 11 or 13) or Char.Slots.NAME_SIZE)
                    Style.SetTextSize(slot.line, active and 11 or Char.Slots.LINE_SIZE)
                    if Char.Slots.FitText then Char.Slots.FitText(slot) end
                end
            end
        end
    end
    if grid and Char.Model and Char.Model.Spread then Char.Model.Spread(0) end
end
hooksecurefunc(Page, "Place", extras.SafeHook("CharacterSheet.Place", place))
local nativePlace = Page.Place
function Page.Place(page, ...)
    get(page)
    return nativePlace(page, ...)
end

extras.German["Average item level"] = "Durchschnittliche Gegenstandsstufe"
extras.German["Equipment durability"] = "Haltbarkeit der Ausrüstung"
local function iconSummary(s, sum, repairAt)
    if not s.summaryValues then
        s.summaryValues = {}
        for i, entry in ipairs({ { DUI.MEDIA .. "ui-data-ilvl.png", "Average item level" }, { DUI.MEDIA .. "ui-data-durability.png", "Equipment durability" } }) do
            local icon = CreateFrame("Frame", nil, s.summary)
            icon:SetSize(14, 14)
            icon.texture = icon:CreateTexture(nil, "ARTWORK")
            icon.texture:SetAllPoints()
            icon.texture:SetTexture(entry[1])
            icon.value = Style.Text(s.summary, Page.FOOT_SIZE or 11, "LEFT")
            icon.value:SetPoint("LEFT", icon, "RIGHT", 5, 0)
            icon.title = T(entry[2])
            icon:EnableMouse(true)
            icon:SetScript("OnEnter", function(self)
                if not GameTooltip then return end
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(self.title)
                GameTooltip:AddLine(self.value:GetText() or "", 1, 1, 1)
                GameTooltip:Show()
            end)
            icon:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            s.summaryValues[i] = icon
        end
    end
    sum = sum or {}
    local level = plain(sum.level)
    local durability = plain(sum.durability)
    local a = level ~= nil and tostring(level) or "-"
    local b = type(durability) == "number" and string.format("%d%%", math.floor(durability * 100 + .5)) or "-"
    local colors = Char.Colors
    if colors and colors.Wrap and (not Char.Setting or Char.Setting("footColors") ~= false) then
        if sum.quality and Gear.QualityColor then a = colors.Wrap(a, Gear.QualityColor(sum.quality)) end
        if type(durability) == "number" then b = colors.Wrap(b, colors.Durability(durability, repairAt)) end
    end
    local first, second = s.summaryValues[1], s.summaryValues[2]
    first.value:SetText(a); second.value:SetText(b)
    local w1 = plain(first.value:GetStringWidth()) or 24
    local w2 = plain(second.value:GetStringWidth()) or 30
    local total = 14 + 5 + w1 + 18 + 14 + 5 + w2
    local x = math.max(0, (s.summary:GetWidth() - total) / 2)
    first:ClearAllPoints(); second:ClearAllPoints()
    first:SetPoint("LEFT", s.summary, "TOPLEFT", x, -12)
    second:SetPoint("LEFT", first.value, "RIGHT", 18, 0)
end
local function footer(page, sum, repairAt)
    local s, foot = get(page), page.foot
    if not s.summary or not foot then return end
    local active = on()
    foot.level:SetShown(not active)
    foot.dura:SetShown(not active)
    foot.level:ClearAllPoints()
    foot.dura:ClearAllPoints()
    if active and s.grid then
        foot.level:SetPoint("LEFT", s.summary, "LEFT", 0, 0)
        foot.dura:SetPoint("LEFT", foot.level, "RIGHT", 20, 0)
        iconSummary(s, sum, repairAt)
        if foot.shine then foot.shine:Hide() end
    else
        foot.level:SetPoint("LEFT", foot, "LEFT", 0, 0)
        foot.dura:SetPoint("LEFT", foot.level, "RIGHT", 24, 0)
    end
    if s.setsWidth == nil then s.setsWidth = foot.sets:GetWidth() end
    foot.sets:ClearAllPoints()
    if active and s.grid then
        foot.sets:SetPoint("TOP", s.summary, "BOTTOM", 0, -5)
        foot.sets:SetWidth(math.min(s.grid.model.w, math.max(160, s.setsWidth)))
    else
        foot.sets:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
        foot.sets:SetWidth(s.setsWidth)
    end
    foot.ammo:ClearAllPoints()
    foot.ammo:SetPoint("LEFT", active and foot or foot.dura, active and "LEFT" or "RIGHT", active and 0 or 24, 0)
    if active and s.grid then foot.ammo:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
    else foot.ammo:SetPoint("RIGHT", foot.sets, "LEFT", -16, 0) end
    local check = foot.blastaGearCheck
    if check then
        check:ClearAllPoints()
        local ammo = plain(foot.ammo:GetText())
        local width = type(ammo) == "string" and ammo ~= "" and plain(foot.ammo:GetStringWidth()) or 0
        if active then check:SetPoint("LEFT", foot, "LEFT", (type(width) == "number" and width > 0) and width + 14 or 0, 0)
        else check:SetPoint("LEFT", foot.dura, "RIGHT", 20, 0) end
        if active and s.grid then check:SetPoint("RIGHT", foot, "RIGHT", 0, 0)
        else check:SetPoint("RIGHT", foot.sets, "LEFT", -12, 0) end
        for _, key in ipairs({ "missingEnchant", "lowDurability" }) do
            local region = check[key]
            local text = region and plain(region.text:GetText())
            if region then region:SetShown(not active or not (type(text) == "string" and text:match("^0%s"))) end
        end
    end
end
hooksecurefunc(Page, "PaintFooter", extras.SafeHook("CharacterSheet.PaintFooter", footer))

local context
if Page.FitStat and Style.SetTextSize then
    local fitStat = Page.FitStat
    function Page.FitStat(row, width)
        local size = context and math.max(13, Page.STAT_SIZE or 12) or (Page.STAT_SIZE or 12)
        Style.SetTextSize(row.label, size)
        Style.SetTextSize(row.value, size)
        return fitStat(row, width)
    end
end
local nativeRead = Stats.Read
function Stats.Read(group, ...)
    local rows = nativeRead(group, ...)
    if not context or group ~= "attributes" then return rows end
    local copy, index = {}, {}
    for i, row in ipairs(rows) do copy[i] = row; index[row] = i end
    local rank = { health = 1, power = 2 }
    table.sort(copy, function(a, b) return (rank[a.id] or (10 + index[a])) < (rank[b.id] or (10 + index[b])) end)
    return copy
end
local refreshStats = Page.RefreshStats
function Page.RefreshStats(page, ...)
    local pane = page and page.stats
    if not pane or not pane.groups or pane.list ~= Stats.GROUPS then return refreshStats(page, ...) end
    local active = on()
    -- Match the equipment heading's top edge. No bars, tabs or reserved gap.
    pane.scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", Page.STATS_PAD, active and 0 or -Page.STATS_PAD)
    local previous = context
    context = active or nil
    local ok, err = pcall(refreshStats, page, ...)
    context = previous
    if not ok then error(err, 0) end
    if active then
        for _, group in pairs(pane.groups) do
            for _, row in ipairs(group.rows) do if row.stripe then row.stripe:Hide() end end
        end
    end
end

hooksecurefunc(Page, "Build", extras.SafeHook("CharacterSheet.Build", function(page) get(page) end))
-- The existing CharacterPanel refresh handles every characterPanel option;
-- Place is needed too, because the refined view changes anchors and spacing.
DUI.On("SettingChanged", function(scope, key)
    if scope ~= ADDON or (key ~= "characterPanel.layout" and key ~= "characterPanel.refined" and key ~= "characterPanel.enabled") then return end
    DUI.AfterCombat(function()
        if Char.Window and Char.Window.Apply then Char.Window.Apply(); return end
        for page in pairs(state) do
            if page:IsShown() then Page.Place(page); Page.Refresh(page) end
        end
    end, "blastaCharacterSheet")
end)
extras.Loaded("CharacterSheet")
