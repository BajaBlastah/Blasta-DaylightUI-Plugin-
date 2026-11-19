-- SPDX-License-Identifier: GPL-3.0-or-later
-- A professions panel built into DaylightUI's profession window, on its
-- right side under the header, always there while the window is: every profession the character has as a
-- compact card with its skill bar, the next rank (skill, level, cost) and how
-- many recipes it can learn now with what the trainer asks. The open
-- profession is lit; clicking another opens it. Gathering professions and
-- fishing are there too, dimmed, as they have no window. With the panel on,
-- the header's profession tabs can go (the panel does their job).
--
-- It is part of the window, not a pane beside it: the window's base width
-- (Craft.W) grows by the panel, and the page area (f.host) ends where the
-- panel starts, behind one divider like the one between list and recipe.
-- DaylightUI sizes the list from the width beyond Craft.W, so the list and
-- the recipe page keep their sizes; the grip, the header and the saved spot
-- work as before.
local ADDON, extras = ...
local DUI = DaylightUI
local craft = DUI.Craft
local window, data = craft and craft.Window, craft and craft.Data
local Win, Style, W = DUI.Win, DUI.Style, DUI.Widgets
local parts = Win and Win.Parts
local mod = DUI:GetModule("Professions")
if not (mod and mod.defaults and window and window.W and window.Switch and window.Show and window.Refreshed
    and window.MakeTabs and data and data.Tabs and data.Profession and Win and Win.Tabs
    and parts and parts.Stack and parts.Hex and parts.Light and parts.Rule and Win.HEADER and W and W.Bar and W.BarColor and W.BarAccent
    and Style and Style.Text and Style.InkText and Style.SIZE and Style.INK and Style.SetBarValue and Style.PaintAccent
    and DUI.MoneyString and extras.FindSetting(mod, "rarityNames")) then return end

local T = extras.Translate
local german = extras.German
local KEY, TABS_KEY = "blastaProfPanel", "blastaProfPanelTabs"
mod.defaults[KEY] = true
mod.defaults[TABS_KEY] = false

for en, de in pairs({
    ["Professions panel"] = "Berufsleiste",
    ["A panel beside the profession window with every profession: skill, the next rank and the recipes you can learn. Click one to open it."] =
        "Eine Leiste neben dem Berufsfenster mit allen Berufen: Fertigkeit, nächster Rang und die Rezepte, die du lernen kannst. Ein Klick öffnet den Beruf.",
    ["Keep the profession tabs"] = "Berufsreiter behalten",
    ["Also show the tabs in the window's header. Off, the panel switches professions."] =
        "Zeigt zusätzlich die Reiter im Kopf des Fensters. Aus: Die Leiste wechselt die Berufe.",
    ["Professions"] = "Berufe",
    ["Primary"] = "Hauptberufe", ["Secondary"] = "Nebenberufe",
    ["Apprentice"] = "Lehrling", ["Journeyman"] = "Geselle", ["Expert"] = "Experte", ["Artisan"] = "Fachmann",
    ["Fully trained"] = "Voll ausgebildet",
    ["%s at the trainer"] = "%s beim Lehrer",
    ["%s from %d"] = "%s ab %d",
    ["level %d"] = "Stufe %d",
    ["%d learnable"] = "%d lernbar", ["%d soon"] = "%d bald",
    ["Nothing new to learn"] = "Nichts Neues zu lernen",
    ["Click: open this profession"] = "Klicken: Beruf öffnen",
    ["Gathering: no window of its own"] = "Sammelberuf: kein eigenes Fenster",
    ["Skill"] = "Fertigkeit", ["Rank"] = "Rang", ["Next rank"] = "Nächster Rang",
    ["Learnable now"] = "Jetzt lernbar", ["With a missing requirement"] = "Mit fehlender Voraussetzung",
    ["Soon (up to +15 skill)"] = "Bald (bis +15 Fertigkeit)",
    ["No professions yet."] = "Noch keine Berufe.",
}) do german[en] = de end

extras.AddSetting(mod, "rarityNames", {
    type = "toggle", key = KEY, label = "Professions panel", reload = true,
    desc = "A panel beside the profession window with every profession: skill, the next rank and the recipes you can learn. Click one to open it.",
})
extras.AddSetting(mod, KEY, {
    type = "toggle", key = TABS_KEY, label = "Keep the profession tabs",
    desc = "Also show the tabs in the window's header. Off, the panel switches professions.",
    disabled = function(get) return get(KEY) == false end,
})

local function on() return DUI:Get(mod.name, KEY) ~= false end
local function keepTabs() return DUI:Get(mod.name, TABS_KEY) == true end
local function readable(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end
local function hex(c) return parts.Hex(c) end
local function money(c) return hex(Style.INK.MONEY) .. DUI.MoneyString(c) .. "|r" end

-- Saved settings exist once the profile loads, after this file; the panel is
-- docked once and the switch asks for a reload (reload = true above).
local active

local WIDTH, CARD_H, ICON, PAD = 230, 64, 26, 10

-- Ranks by the limit they give, for professions without recipe data.
local RANK_OF = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local NEXT_RANK = { [75] = { "Journeyman", 50, 10 }, [150] = { "Expert", 125, 20 }, [225] = { "Artisan", 200, 35 } }
local TOP = 300

-- Every profession, primary ones first: { name, icon, skill, bonus, max,
-- skillLine, primary, window = has a crafting window }.
local function professions()
    local out = {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return out end
    local windows = {}
    for _, t in ipairs(data.Tabs()) do windows[t.skillLine] = true end
    local list = { GetProfessions() }
    for i = 1, 6 do
        local idx = list[i]
        if idx then
            local ok, name, icon, rank, max, _, _, skillLine, bonus = pcall(GetProfessionInfo, idx)
            if ok and type(name) == "string" and readable(rank) and readable(max) and readable(skillLine) then
                out[#out + 1] = { name = name, icon = icon, skill = rank, bonus = readable(bonus) and bonus or 0,
                    max = max, skillLine = skillLine, primary = i <= 2, window = windows[skillLine] == true }
            end
        end
    end
    return out
end

local function summaryOf(p)
    if not extras.LearnableSummary then return nil end
    local ok, s = pcall(extras.LearnableSummary, { id = p.skillLine, skill = p.skill, bonus = p.bonus, max = p.max })
    return ok and s or nil
end

-- "capped" (this rank is done, the next is at the trainer), "done" or nil.
local function limit(p)
    local skill = p.skill + p.bonus
    if p.max <= 0 or skill < p.max then return nil end
    return p.max >= TOP and "done" or "capped"
end

local function nextRank(p, s)
    if s and s.rank then
        local r = s.rank.recipe
        return { name = T(r.rank), skill = r.skill, level = r.level, cost = r.cost }
    end
    local n = NEXT_RANK[p.max]
    if n then return { name = T(n[1]), skill = n[2], level = n[3] } end
end

local function levelShort(level)
    local mine = UnitLevel and UnitLevel("player")
    return readable(mine) and level > mine
end

-- One short status line: what's due first (the next rank), else the recipes.
local function status(p, s)
    local ink = Style.INK
    local state = limit(p)
    if state == "done" then return hex(ink.GOOD) .. T("Fully trained") .. "|r" end
    local n = nextRank(p, s)
    local skill = p.skill + p.bonus
    if n and (state == "capped" or skill >= n.skill) then
        local text = string.format(T("%s at the trainer"), n.name)
        if n.level and n.level > 0 and levelShort(n.level) then text = text .. ", " .. string.format(T("level %d"), n.level) end
        return hex(ink.WARN) .. text .. "|r"
    end
    if s and s.known and s.now > 0 then
        local text = hex(ink.GOOD) .. string.format(T("%d learnable"), s.now) .. "|r"
        if s.cost > 0 then text = text .. " " .. money(s.cost) end
        return text
    end
    if n then return string.format(T("%s from %d"), n.name, n.skill) end
    if s and s.known and s.soon > 0 then return string.format(T("%d soon"), s.soon) end
    if s and s.known then return T("Nothing new to learn") end
    return ""
end

-- Tooltip: everything the card shortens.
local function tip(c)
    local p, s = c.prof, c.summary
    if not (p and GameTooltip) then return end
    local ink = Style.INK
    GameTooltip:SetOwner(c, "ANCHOR_RIGHT")
    GameTooltip:SetText(p.name, 1, 1, 1)
    local function line(left, right, color)
        color = color or ink.VALUE
        GameTooltip:AddDoubleLine(left, right, ink.LABEL[1], ink.LABEL[2], ink.LABEL[3], color[1], color[2], color[3])
    end
    line(T("Skill"), string.format("%d / %d", p.skill + p.bonus, p.max))
    if RANK_OF[p.max] then line(T("Rank"), T(RANK_OF[p.max])) end
    local n = limit(p) ~= "done" and nextRank(p, s) or nil
    if n then
        local bits = { string.format(T("%s from %d"), n.name, n.skill) }
        if n.level and n.level > 0 then bits[#bits + 1] = string.format(T("level %d"), n.level) end
        if n.cost and n.cost > 0 then bits[#bits + 1] = money(n.cost) end
        line(T("Next rank"), table.concat(bits, ", "), (p.skill + p.bonus >= n.skill) and ink.WARN or ink.VALUE)
    end
    if s and s.known then
        line(T("Learnable now"), tostring(s.now) .. (s.cost > 0 and ("  " .. money(s.cost)) or ""), s.now > 0 and ink.GOOD or ink.VALUE)
        if s.missing > 0 then line(T("With a missing requirement"), tostring(s.missing), ink.WARN) end
        if s.soon > 0 then line(T("Soon (up to +15 skill)"), tostring(s.soon)) end
    end
    GameTooltip:AddLine(" ")
    local hint = p.window and ink.LABEL or ink.OFF
    GameTooltip:AddLine(T(p.window and "Click: open this profession" or "Gathering: no window of its own"), hint[1], hint[2], hint[3])
    GameTooltip:Show()
end

-- The card

local function makeCard(parent)
    local c = CreateFrame("Button", nil, parent)
    c:RegisterForClicks("LeftButtonUp")
    c.back = c:CreateTexture(nil, "BACKGROUND")
    c.back:SetAllPoints()
    c.back:SetColorTexture(1, 1, 1, 0.03)
    c.pick = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.pick:SetAllPoints()
    c.pick:SetTexture("Interface\\Buttons\\WHITE8X8")
    c.pick:Hide()
    c.hi = c:CreateTexture(nil, "BORDER")
    c.hi:SetAllPoints()
    c.hi:SetColorTexture(parts.HI[1], parts.HI[2], parts.HI[3], parts.HI[4])
    c.hi:Hide()
    c.mark = c:CreateTexture(nil, "ARTWORK")
    c.mark:SetTexture("Interface\\Buttons\\WHITE8X8")
    c.mark:SetWidth(2)
    c.mark:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    c.mark:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
    c.mark:Hide()
    c.edge = c:CreateTexture(nil, "ARTWORK")
    c.edge:SetColorTexture(0.23, 0.23, 0.26, 1)
    c.edge:SetSize(ICON + 2, ICON + 2)
    c.edge:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -9)
    c.icon = c:CreateTexture(nil, "OVERLAY")
    c.icon:SetPoint("TOPLEFT", c.edge, "TOPLEFT", 1, -1)
    c.icon:SetPoint("BOTTOMRIGHT", c.edge, "BOTTOMRIGHT", -1, 1)
    if Style.CropIcon then Style.CropIcon(c.icon) end
    c.value = Style.Text(c, Style.SIZE.small, "RIGHT")
    c.value:SetPoint("TOPRIGHT", c, "TOPRIGHT", -PAD, -10)
    c.name = Style.Text(c, Style.SIZE.body, "LEFT")
    c.name:SetPoint("TOPLEFT", c.edge, "TOPRIGHT", 8, -1)
    c.name:SetPoint("RIGHT", c.value, "LEFT", -6, 0)
    c.name:SetWordWrap(false)
    c.bar = W.Bar(c, 4)
    c.bar:SetPoint("BOTTOMLEFT", c.edge, "BOTTOMRIGHT", 8, 1)
    c.bar:SetPoint("RIGHT", c, "RIGHT", -PAD, 0)
    c.status = Style.Text(c, Style.SIZE.small, "LEFT")
    c.status:SetPoint("TOPLEFT", c.edge, "BOTTOMLEFT", 0, -7)
    c.status:SetPoint("RIGHT", c, "RIGHT", -PAD, 0)
    c.status:SetWordWrap(false)
    c:SetScript("OnEnter", function(self) parts.Light(self.hi, true); tip(self) end)
    c:SetScript("OnLeave", function(self)
        parts.Light(self.hi, false)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    c.blastaTip = tip
    -- The game opens a profession only straight from a click: nothing runs before it.
    c:SetScript("OnClick", function(self)
        local p = self.prof
        if not (p and p.window and not self.open) then return end
        window.Switch(p.skillLine)
        if DUI.Sound then DUI.Sound.Play("click") end
    end)
    return c
end

local function paintCard(c, p, s, open)
    local ink = Style.INK
    c.prof, c.summary, c.open = p, s, open
    c.icon:SetTexture(p.icon)
    c.icon:SetDesaturated(not p.window)
    c.name:SetText(p.name)
    Style.InkText(c.name, open and "pop" or (p.window and "VALUE" or "LABEL"))
    local skill = p.skill + p.bonus
    c.value:SetText(string.format("%d/%d", skill, p.max))
    local state = limit(p)
    Style.InkText(c.value, state == "capped" and "WARN" or state == "done" and "GOOD" or "LABEL")
    c.bar:SetMinMaxValues(0, math.max(1, p.max))
    Style.SetBarValue(c.bar, math.min(skill, p.max), true)
    if state == "capped" then W.BarColor(c.bar, ink.WARN[1], ink.WARN[2], ink.WARN[3])
    elseif state == "done" then W.BarColor(c.bar, ink.GOOD[1], ink.GOOD[2], ink.GOOD[3])
    else W.BarColor(c.bar, 1, 1, 1); W.BarAccent(c.bar) end
    c.status:SetText(status(p, s))
    Style.InkText(c.status, "LABEL")
    -- The open profession: an accent wash and a line on its left edge.
    c.pick:SetShown(open)
    c.mark:SetShown(open)
    if open then
        Style.PaintAccent(c.pick, 0.14)
        Style.PaintAccent(c.mark, 1)
    end
    c:SetAlpha(p.window and 1 or 0.8)
end

-- The panel

local pane, stack, note, painted

-- No title of its own: the Primary and Secondary headings say enough.
local function build()
    if stack then return end
    stack = parts.Stack(pane, { top = 4, bottom = 22, side = 10 })
    note = Style.Text(pane, Style.SIZE.small, "CENTER")
    note:SetPoint("CENTER", pane, "CENTER", 0, 0)
    note:SetText(T("No professions yet."))
    Style.InkText(note, "LABEL")
    note:Hide()
end

-- What the cards would show, as one string: the panel only repaints when it
-- changes. Repainting recycles the cards, which hid and showed a tooltip
-- under the mouse on every bag or list update (the flicker).
local function signature(open, all, summaries)
    local bits = { open and open.id or 0 }
    for i, p in ipairs(all) do
        local s = summaries[i]
        bits[#bits + 1] = table.concat({ p.skillLine, p.skill, p.bonus, p.max, tostring(p.window),
            s and s.now or "-", s and s.missing or "-", s and s.soon or "-", s and s.cost or "-",
            s and s.rank and s.rank.recipe.spell or "-" }, ":")
    end
    return table.concat(bits, "|")
end

local function fill(force)
    if not (pane and pane:IsVisible()) then return end
    build()
    local open = data.Profession()
    if open and data.Viewing and data.Viewing() then open = nil end
    local all = professions()
    local summaries = {}
    for i, p in ipairs(all) do summaries[i] = summaryOf(p) end
    local sig = signature(open, all, summaries)
    if sig == painted and not force then return end
    painted = sig
    local groups = { { label = "Primary", list = {} }, { label = "Secondary", list = {} } }
    for i, p in ipairs(all) do
        local g = p.primary and groups[1] or groups[2]
        g.list[#g.list + 1] = { p = p, s = summaries[i] }
    end
    local at = stack:Scrolled()
    stack:Begin()
    for _, g in ipairs(groups) do
        if #g.list > 0 then
            stack:Section(T(g.label))
            for _, e in ipairs(g.list) do
                local c = stack:Piece("blastaProfCard", makeCard, CARD_H, 6, "blasta:prof:" .. tostring(e.p.skillLine))
                paintCard(c, e.p, e.s, open ~= nil and open.id == e.p.skillLine)
            end
            stack:Gap(10)
        end
    end
    stack:End()
    if at > 0 then stack:ScrollTo(at) end
    note:SetShown(#all == 0)
    -- A card under the mouse keeps its tooltip, now with the new numbers.
    if GameTooltip and GameTooltip:IsShown() then
        local owner = GameTooltip:GetOwner()
        if owner and owner.blastaTip and owner:IsMouseOver() then owner.blastaTip(owner) end
    end
end

local queued
local function soon(force)
    if not (pane and pane:IsVisible()) or queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        pcall(fill, force == true)
    end)
end

-- Built into the window: the base width grows by the panel, the page area
-- stops at it.
local BASE_W = window.W
local function attach(f)
    if pane or not (f and f.host) then return end
    window.W = BASE_W + WIDTH
    if f.defs and f.defs.recipes then f.defs.recipes.w = window.W end
    pane = CreateFrame("Frame", nil, f)
    pane:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -Win.HEADER - 1)
    pane:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    pane:SetWidth(WIDTH)
    pane:SetFrameLevel(f.host:GetFrameLevel())
    local rule = parts.Rule(pane, true)
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    rule:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    f.host:ClearAllPoints()
    f.host:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -Win.HEADER - 1)
    f.host:SetPoint("BOTTOMRIGHT", pane, "BOTTOMLEFT", 0, 0)
    pane:SetScript("OnShow", function() soon(true) end)
    -- The open window takes its new width right away.
    if Win.IsOpen and Win.IsOpen(f) and f.current then
        local w, h = window.Size()
        f:SetSize(w, h)
        if window.Resized then pcall(window.Resized, w, h) end
    end
    if window.follow and Win.Followers and Win.Followers.WriteWidth then
        pcall(Win.Followers.WriteWidth, window.follow)
    end
    window.tabs = nil   -- MakeTabs builds the header again, without tabs
    pcall(window.MakeTabs, f)
    soon(true)
end

-- DaylightUI's header tabs: left out while the panel switches professions.
-- The title and skill line then reach to the header's right end, as they do
-- in DaylightUI when there's a single profession.
local tabs = Win.Tabs
function Win.Tabs(f, list, onPick, ...)
    if not active or f ~= window.frame or keepTabs() then return tabs(f, list, onPick, ...) end
    for _, b in ipairs(f.tabs or {}) do b:Hide() end
    f.tabs, f.onTab = nil, onPick
    local room = 40 + (f.headerRoom or 0)
    if f.title then f.title:SetPoint("RIGHT", f, "RIGHT", -room, 0) end
    if f.sub then f.sub:SetPoint("RIGHT", f, "RIGHT", -room, 0) end
end

local function after(name)
    local original = window[name]
    window[name] = function(...)
        local a, b, c = original(...)
        soon()
        return a, b, c
    end
end
-- Another addon's pane docks to the window's right edge, past the panel: fine.
after("Show")
after("Refreshed")

-- At login, once the saved switch is known; the window may be built before
-- or after that.
DUI.On("Login", function()
    if not on() or active then return end
    active = true
    if window.frame then attach(window.frame) end
end)
if window.Build then
    local buildWindow = window.Build
    function window.Build(...)
        local f = buildWindow(...)
        if active then attach(f or window.frame) end
        return f
    end
end

for _, event in ipairs({ "SKILL_LINES_CHANGED", "PLAYER_LEVEL_UP", "NEW_RECIPE_LEARNED", "LEARNED_SPELL_IN_SKILL_LINE" }) do
    DUI.RegisterEvent(event, soon)
end
DUI.On("SettingChanged", function(scope, path)
    if scope ~= mod.name or not active then return end
    if path == TABS_KEY and window.frame then
        window.tabs = nil   -- MakeTabs builds them again, with or without
        pcall(window.MakeTabs, window.frame)
        local prof = data.Profession()
        if window.frame.tabs then pcall(Win.PickTab, window.frame, prof and prof.id or nil) end
    end
    soon(true)
end)
DUI.On("StyleChanged", function() soon(true) end)

extras.Loaded("ProfessionOverview")
