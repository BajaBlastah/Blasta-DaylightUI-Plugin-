-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
local DUI = DaylightUI
local qol = DUI:GetModule("QoL")
local afk = qol and qol.ns and qol.ns.Afk
local info = extras.Compatible("InfoPanel")
local xp, data = info and info.XP, info and info.DataTexts
local style, L, T = DUI.Style, DUI.L, extras.Translate
if not (qol and qol.defaults and afk and afk.Fill and afk.Tick and afk.PlacePanel
    and afk.Read and afk.Preview and afk.Shown and afk.TimeOfDay and afk.Clock
    and extras.FindSetting(qol, "afkScreen")) then return end

local key, detailKey = "blastaAfk", "blastaAfkDetails"
local destination = { page = "Afk", label = "Appearance" }
local labels = {
    ["AFK screen"] = "AFK-Bildschirm",
    ["Blasta AFK layout"] = "Blasta-AFK-Layout",
    ["Uses the Blasta layout when DaylightUI's AFK screen opens."] = "Verwendet das Blasta-Layout, wenn DaylightUIs AFK-Bildschirm geöffnet wird.",
    ["Show session details"] = "Sitzungsdetails anzeigen",
    ["Preview the Blasta AFK screen"] = "Blasta-AFK-Bildschirm ansehen",
    ["Ready to turn in"] = "Abgabebereit",
    ["%d quests · %s XP"] = "%d Quests · %s EP",
    ["%s XP to next level"] = "%s EP bis zur nächsten Stufe",
    ["%s rested XP"] = "%s ausgeruhte EP",
    ["Gold since UI loaded"] = "Geld seit UI-Start",
    ["Free bag slots"] = "Freie Taschenplätze",
    ["Session time"] = "Sitzungsdauer",
    ["New mail"] = "Neue Post",
    ["At the mailbox"] = "Am Briefkasten",
    ["Lowest durability"] = "Niedrigste Haltbarkeit",
    ["Rest area"] = "Rastgebiet",
}
for en, de in pairs(labels) do extras.German[en] = de end
qol.defaults[key], qol.defaults[detailKey] = false, true
extras.AddSetting(qol, "afkScreen", {
    type = "toggle", key = key, label = "Blasta AFK layout",
    desc = "Uses the Blasta layout when DaylightUI's AFK screen opens.", blastaDestination = destination,
})
extras.AddSetting(qol, key, {
    type = "toggle", key = detailKey, label = "Show session details", blastaDestination = destination,
})

local function number(v) return type(v) == "number" and not DUI.IsSecret(v) end
local function formatted(v)
    return (BreakUpLargeNumbers and BreakUpLargeNumbers(v)) or tostring(v)
end

local function getProgress()
    if xp and xp.Read then return xp.Read() end
    if IsPlayerAtEffectiveMaxLevel and IsPlayerAtEffectiveMaxLevel() == true then return end
    local value, max = UnitXP("player"), UnitXPMax("player")
    if not (number(value) and number(max) and max > 0) then return end
    return { value = value, max = max, rested = GetXPExhaustion(), label = L["Experience"] }
end

local card, fade, active, previewLook, openingMoney, sessionRow
local sessionStart = GetTime()
local function shade(texture, bottom, top)
    if texture.SetGradient and CreateColor then
        texture:SetGradient("VERTICAL", CreateColor(0, 0, 0, bottom), CreateColor(0, 0, 0, top))
    else
        texture:SetVertexColor(0, 0, 0, (bottom + top) / 2)
    end
end

local function text(parent, size, top, quiet)
    local fs = style.Text(parent, size, "LEFT")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 22, -top)
    fs:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -top)
    fs:SetWordWrap(false)
    style.InkText(fs, quiet and "LABEL" or "VALUE")
    return fs
end

local function stat(parent)
    local line = CreateFrame("Frame", nil, parent)
    local name = style.Text(line, 13, "LEFT")
    name:SetPoint("LEFT")
    style.InkText(name, "LABEL")
    local value = style.Text(line, 14, "RIGHT")
    value:SetPoint("RIGHT")
    name:SetPoint("RIGHT", value, "LEFT", -8, 0)
    name:SetWordWrap(false)
    value:SetWordWrap(false)
    style.InkText(value, "VALUE")
    line.name, line.value = name, value
    return line
end

local function build(screen)
    fade = screen:CreateTexture(nil, "BACKGROUND", nil, 1)
    fade:SetPoint("TOPRIGHT", screen, "TOPRIGHT")
    fade:SetPoint("BOTTOMRIGHT", screen, "BOTTOMRIGHT")
    fade:SetColorTexture(0, 0, 0, 1)
    if fade.SetGradient and CreateColor then
        fade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0.68))
    else
        fade:SetVertexColor(0, 0, 0, 0.32)
    end

    local p = CreateFrame("Frame", nil, screen)
    p:SetSize(354, 340)
    p:SetFrameLevel(screen.panel:GetFrameLevel() + 1)
    local rule = p:CreateTexture(nil, "BORDER")
    rule:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -4)
    rule:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 4)
    rule:SetWidth(2)
    rule:SetColorTexture(1, 1, 1, 1)
    p.rule = rule
    p.away = text(p, 13, 0, true)
    p.clock = text(p, 64, 19)
    p.name = text(p, 26, 97)
    p.identity = text(p, 14, 130, true)
    p.zone = text(p, 15, 155)
    local progress = CreateFrame("Frame", nil, p)
    progress:SetPoint("TOPLEFT", p, "TOPLEFT", 22, -196)
    progress:SetPoint("TOPRIGHT", p, "TOPRIGHT", -8, -196)
    progress:SetHeight(56)
    p.progress = progress
    progress.title = style.Text(progress, 14, "LEFT")
    progress.title:SetPoint("TOPLEFT")
    progress.percent = style.Text(progress, 14, "RIGHT")
    progress.percent:SetPoint("TOPRIGHT")
    style.InkText(progress.percent, "VALUE")
    progress.title:SetPoint("RIGHT", progress.percent, "LEFT", -8, 0)
    progress.title:SetWordWrap(false)
    progress.track = style.Bar(progress)
    progress.track:SetPoint("TOPLEFT", progress, "TOPLEFT", 0, -22)
    progress.track:SetPoint("TOPRIGHT", progress, "TOPRIGHT", 0, -22)
    progress.track:SetHeight(5)
    progress.fill = style.Bar(progress)
    progress.fill:SetAllPoints(progress.track)
    progress.fill:SetFrameLevel(progress.track:GetFrameLevel() + 1)
    style.BarBack(progress.fill):Hide()
    local detail = style.Text(progress, 12, "LEFT")
    detail:SetPoint("TOPLEFT", progress, "TOPLEFT", 0, -36)
    detail:SetPoint("RIGHT", progress, "RIGHT")
    detail:SetWordWrap(false)
    style.InkText(detail, "LABEL")
    progress.detail = detail
    p.stats = {}
    card = p
end

local function layout(p, slide)
    local width, height = UIParent:GetWidth(), UIParent:GetHeight()
    if not (number(width) and number(height) and width > 0 and height > 0) then return end
    local scale = math.min(1.18, width / 960, height / 540)
    fade:SetWidth(width * 0.57)
    p:SetScale(scale)
    p:ClearAllPoints()
    p:SetPoint("RIGHT", p:GetParent(), "RIGHT", -width * 0.10 / scale + (1 - slide) * 24, -8)
end

local function progress(p, value)
    local bar = p.progress
    if not (value and number(value.value) and number(value.max) and value.max > 0) then bar:Hide(); return end
    local current, max = math.max(0, math.min(value.value, value.max)), value.max
    local rest = number(value.rested) and math.max(0, value.rested) or 0
    bar.title:SetText(value.label or L["Experience"])
    bar.percent:SetText(("%d%%"):format(math.floor(current / max * 100)))
    bar.track:SetMinMaxValues(0, max)
    bar.track:SetValue(math.min(max, current + rest))
    style.SetBarColor(bar.track, 0.39, 0.34, 0.64)
    bar.fill:SetMinMaxValues(0, max)
    bar.fill:SetValue(current)
    if value.rep and value.color then
        style.SetBarGradient(bar.fill, false)
        style.SetBarColor(bar.fill, value.color[1], value.color[2], value.color[3])
    else
        style.PaintAccentBar(bar.fill)
    end
    local detail
    if value.rep then
        detail = ("%s / %s"):format(formatted(current), formatted(max))
    else
        detail = T("%s XP to next level"):format(formatted(max - current))
        if rest > 0 then detail = detail .. "  ·  " .. T("%s rested XP"):format(formatted(rest)) end
    end
    bar.detail:SetText(detail)
    bar:Show()
end

local function tick()
    if not (active and card) then return end
    local away = afk.Clock(math.max(0, GetTime() - (afk.since or GetTime())))
    card.away:SetText(L["AWAY"] .. "  ·  " .. away)
    card.clock:SetText(afk.TimeOfDay())
    if sessionRow then sessionRow.value:SetText(afk.Clock(math.max(0, GetTime() - sessionStart))) end
end

local function paint()
    local character = afk.Read()
    local current = getProgress()
    local rows, zone = {}, nil
    for _, row in ipairs(character.rows or {}) do
        if row[1] == L["Zone"] then zone = row[2]
        elseif row[1] == L["Played"] then rows[1] = row end
    end
    if DUI:Get("QoL", detailKey) ~= false then
        rows[#rows + 1] = { T("Session time"), nil, session = true }
        if current and not current.rep and xp and xp.Banked then
            local reward, count = xp.Banked()
            if number(count) and count > 0 and number(reward) then
                rows[#rows + 1] = { T("Ready to turn in"), T("%d quests · %s XP"):format(count, formatted(reward)) }
            end
        end
        local money = GetMoney()
        if number(openingMoney) and number(money) then
            local gain = money - openingMoney
            local sign = gain > 0 and "+" or gain < 0 and "−" or ""
            rows[#rows + 1] = { T("Gold since UI loaded"), sign .. DUI.MoneyString(math.abs(gain)) }
        end
        if data and data.ReadBags then
            local free, total = data.ReadBags()
            if number(free) and number(total) and total > 0 then
                rows[#rows + 1] = { T("Free bag slots"), ("%d / %d"):format(free, total) }
            end
        end
        if data and data.ReadDurability then
            local lowest = data.ReadDurability()
            if number(lowest) and lowest <= (data.GEAR_WARN or 50) then
                local bad = lowest <= (data.GEAR_BAD or 20)
                rows[#rows + 1] = { T("Lowest durability"), ("%d%%"):format(lowest), ink = bad and "BAD" or "WARN" }
            end
        end
        local unread
        if HasNewMail then
            unread = HasNewMail()
        elseif GetLatestThreeSenders then
            local sender = GetLatestThreeSenders()
            unread = type(sender) == "string" and not DUI.IsSecret(sender) and sender ~= ""
        end
        if not DUI.IsSecret(unread) and unread == true then
            rows[#rows + 1] = { T("New mail"), T("At the mailbox"), ink = "pop" }
        end
    end
    card.name:SetText(character.name or "")
    card.identity:SetText(character.sub or "")
    local resting = IsResting and IsResting()
    if not DUI.IsSecret(resting) and resting == true then
        zone = zone and (zone .. "  ·  " .. T("Rest area")) or T("Rest area")
    end
    card.zone:SetText(zone or "")
    style.PaintAccent(card.rule, 0.88, "VERTICAL")
    progress(card, current)
    local top = card.progress:IsShown() and 260 or 192
    sessionRow = nil
    for i = 1, math.max(#rows, #card.stats) do
        local row = rows[i]
        local widget = card.stats[i]
        if not widget then
            widget = stat(card)
            card.stats[i] = widget
        end
        widget:SetShown(row ~= nil)
        if row then
            widget:ClearAllPoints()
            widget:SetPoint("TOPLEFT", card, "TOPLEFT", 22, -top)
            widget:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -top)
            widget:SetHeight(20)
            widget.name:SetText(row[1])
            widget.value:SetText(row[2] or "")
            style.InkText(widget.value, row.ink or "VALUE")
            if row.session then sessionRow = widget end
            top = top + 22
        end
    end
    card:SetHeight(top + 2)
    tick()
end

hooksecurefunc(afk, "Fill", function()
    local screen = _G.DaylightUIAfkScreen
    if not (screen and screen.panel and screen.dim) then return end
    local useBlasta = previewLook == true or DUI:Get("QoL", key) == true
    active = false
    if not useBlasta then
        screen.panel:Show()
        if card then
            card:Hide()
            fade:Hide()
            shade(screen.dim, afk.DIM_BOTTOM, afk.DIM_TOP)
        end
        return
    end
    if not card then build(screen) end
    layout(card, 1)
    paint()
    active = true
    tick()
    shade(screen.dim, 0.54, 0.16)
    screen.panel:Hide()
    card:Show()
    fade:Show()
end)
hooksecurefunc(afk, "Tick", tick)
hooksecurefunc(afk, "PlacePanel", function(slide)
    if active and card then layout(card, slide) end
end)

local function rememberMoney()
    if openingMoney ~= nil then return end
    local money = GetMoney()
    if number(money) then openingMoney = money end
end
DUI.On("Login", rememberMoney)
DUI.RegisterEvent("PLAYER_ENTERING_WORLD", rememberMoney)
DUI.On("AfkScreenHidden", function() previewLook = nil end)
for _, event in ipairs({ "PLAYER_MONEY", "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "PLAYER_XP_UPDATE",
    "UPDATE_EXHAUSTION", "UPDATE_FACTION", "UPDATE_INVENTORY_DURABILITY", "UPDATE_PENDING_MAIL",
    "MAIL_INBOX_UPDATE", "PLAYER_UPDATE_RESTING" }) do
    DUI.RegisterEvent(event, function()
        if active and card and afk.Shown() then paint() end
    end)
end

local function preview()
    previewLook = true
    afk.Preview()
    if not afk.Shown() then previewLook = nil end
end
extras.AddSetting(qol, detailKey, {
    type = "button", key = "blastaAfkPreview", label = "Preview the Blasta AFK screen",
    text = "Preview", func = preview, blastaDestination = destination,
})

extras.Loaded("AfkScreen")
