-- SPDX-License-Identifier: GPL-3.0-or-later
-- Health and power as two bars on top of DaylightUI's stats on the character
-- page. DaylightUI's own list stays as it is, just under the bars, without its
-- Health and Mana rows (the bars show them). The values come from DaylightUI's
-- stat reader (Char.Stats) and are painted with SetFormattedText, so secret
-- values in combat are fine. Hovering a bar shows DaylightUI's stat tooltip.
local ADDON, extras = ...
local DUI = DaylightUI
local char = DUI.Char
local Page, Stats = char and char.CharacterPage, char and char.Stats
local Style = DUI.Style
if not (Page and Page.RefreshStats and Page.StatTip and Stats and Stats.Read and Stats.Paint and Stats.GROUPS
    and Style and Style.Text) then return end

local VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or nil
local KEY = "characterPanel.statsBars"
local german = extras.German
german["Health and power bars"] = "Gesundheits- und Ressourcenleiste"
german["Health and your power as two bars on top of the stats, in place of their rows."] =
    "Gesundheit und deine Ressource als zwei Leisten über den Werten, statt ihrer Zeilen."

if extras.CharacterPanelDefaults then extras.CharacterPanelDefaults.statsBars = false end
if extras.CharacterPanelGroup and extras.CharacterPanelGroup.items then
    table.insert(extras.CharacterPanelGroup.items, 2, { type = "toggle", key = KEY, label = "Health and power bars",
        desc = "Health and your power as two bars on top of the stats, in place of their rows.", blastaSince = VERSION })
end

local function on() return DUI:Get(ADDON, KEY) == true end
local BAR_H, BAR_GAP, AFTER = 18, 4, 10
local SHOWN = { health = true, power = true }

local bars = setmetatable({}, { __mode = "k" })   -- stats pane -> { health bar, power bar }

local function newBar(parent)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    b.back = b:CreateTexture(nil, "BACKGROUND")
    b.back:SetAllPoints()
    b.back:SetColorTexture(0, 0, 0, 0.35)
    b.label = Style.Text(b, Page.STAT_SIZE - 1, "LEFT")
    b.label:SetPoint("LEFT", b, "LEFT", 6, 0)
    b.label:SetTextColor(1, 1, 1)
    b.value = Style.Text(b, Page.STAT_SIZE, "RIGHT")
    b.value:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.value:SetTextColor(1, 1, 1)
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self) if self.row then Page.StatTip(self) end end)
    b:SetScript("OnLeave", function() if type(GameTooltip) == "table" then GameTooltip:Hide() end end)
    return b
end

local function barsOf(pane)
    local list = bars[pane]
    if not list then
        list = { newBar(pane.content), newBar(pane.content) }
        bars[pane] = list
    end
    return list
end

-- DaylightUI's heads and rows, top to bottom, with their offsets.
local function nativeFrames(pane)
    local out = {}
    for _, G in pairs(pane.groups or {}) do
        local list = { G.head }
        for _, r in ipairs(G.rows or {}) do list[#list + 1] = r end
        for _, f in ipairs(list) do
            if f and f:IsShown() then
                local _, _, _, x, y = f:GetPoint(1)
                if type(y) == "number" then out[#out + 1] = { f = f, x = x or 0, y = y } end
            end
        end
    end
    table.sort(out, function(a, b) return a.y > b.y end)
    return out
end

local function draw(page)
    local pane = page and page.stats
    if not (pane and pane.content and pane.list == Stats.GROUPS) then return end
    local list = bars[pane]
    if not on() then
        if list then for _, b in ipairs(list) do b:Hide() end end
        return
    end
    list = barsOf(pane)
    local w = Page.STATS_W - 2 * Page.STATS_PAD
    local byId = {}
    for _, r in ipairs(Stats.Read("attributes")) do byId[r.id] = r end
    local y, n = 0, 0
    for _, id in ipairs({ "health", "power" }) do
        local row = byId[id]
        if row then
            n = n + 1
            local b = list[n]
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", pane.content, "TOPLEFT", 0, -y)
            b:SetSize(w, BAR_H)
            if id == "health" then
                b:SetStatusBarColor(0.36, 0.66, 0.29)
            else
                local _, token = UnitPowerType("player")
                b:SetStatusBarColor(Style.PowerColor(token))
            end
            b.row = row
            b.label:SetText(row.label)
            Stats.Paint(b.value, row)
            b:Show()
            y = y + BAR_H + BAR_GAP
        end
    end
    for i = n + 1, #list do list[i]:Hide() end
    if n == 0 then return end
    local shift = y - BAR_GAP + AFTER
    -- Everything of DaylightUI's moves down under the bars; its Health and
    -- power rows go, and what follows them moves up into their place.
    local removed = 0
    for _, e in ipairs(nativeFrames(pane)) do
        local r = e.f
        if r.row and SHOWN[r.row.id] then
            removed = removed + (tonumber(r:GetHeight()) or 0)
            r:Hide()
        else
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", pane.content, "TOPLEFT", e.x, e.y - shift + removed)
        end
    end
    local h = tonumber(pane.content:GetHeight()) or 1
    pane.content:SetHeight(math.max(1, h + shift - removed))
end

hooksecurefunc(Page, "RefreshStats", function(page) pcall(draw, page) end)
DUI.On("SettingChanged", function(scope, key)
    if scope == ADDON and key == KEY and char.Window and char.Window.Refresh then pcall(char.Window.Refresh) end
end)

extras.Loaded("CharacterLayout")
