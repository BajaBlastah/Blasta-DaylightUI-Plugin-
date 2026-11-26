-- SPDX-License-Identifier: GPL-3.0-or-later
-- Blasta's "What's new": a few pages in DaylightUI's setup guide window, like
-- DaylightUI's own, showing what a Blasta version brings, with moving
-- previews and the new settings right on the page. They show once per
-- account after login (after DaylightUI's own pages); /blasta new and the
-- button on Blasta's General page open them again any time.
-- Settings on these pages apply at once, as on Blasta's own pages.
local ADDON, extras = ...
local DUI = DaylightUI
local API = DUI and DUI.API
local me = API and API.For and API.For(ADDON)
local W, Style = DUI and DUI.Widgets, DUI and DUI.Style
if not (me and me.AddInstaller and me.ShowInstaller and W and W.Row and Style) then return end

local T = extras.Translate
local G = extras.German
G["Marker ring"] = "Markierungsring"
G["Mark your target right on its portrait."] = "Markiere dein Ziel direkt am Porträt."
G["Coin colors"] = "Münzfarben"
G["Looted coins in Blasta's loot feed, in their own colors."] = "Gelootete Münzen im Blasta-Beutefeed, in ihren eigenen Farben."
G["All coins now gives each coin an equal share of the bar: half each for two coins, a third each for three. Highest coin uses the highest coin looted, Always gold the old look."] =
    "Alle Münzen gibt jetzt jeder Münze einen gleich großen Anteil am Balken: je die Hälfte bei zwei Münzen, je ein Drittel bei drei. Höchste Münze nimmt die höchste gelootete Münze, Immer Gold den alten Look."
G["Now in DaylightUI"] = "Jetzt in DaylightUI"
G["Two Blasta settings are DaylightUI's own now."] = "Zwei Blasta-Einstellungen gehören jetzt zu DaylightUI."
G["Breath bar edges: DaylightUI 2.4.0 sets each end of the breath bar itself (Skins → Alerts and timers). Reverse unit frame slant: each end of every unit frame has its own menu in DaylightUI now. Blasta's versions are gone and your choices were carried over, so nothing looks different."] =
    "Kanten der Atemleiste: DaylightUI 2.4.0 stellt jedes Ende der Atemleiste selbst ein (Skins → Hinweise und Timer). Einheitenrahmen-Schräge umkehren: Jedes Ende jedes Einheitenrahmens hat jetzt ein eigenes Menü in DaylightUI. Blastas Versionen sind weg, deine Einstellungen wurden übernommen, es sieht also alles aus wie vorher."
G["Also new: the bag text sizes apply to the bank and the bank and alts window too, and DaylightUI's bar animations on the experience bar end where Blasta's shaped ends do."] =
    "Außerdem neu: Die Schriftgrößen der Taschen gelten jetzt auch für die Bank und das Fenster für Bank und Twinks, und DaylightUIs Balkenanimationen auf der Erfahrungsleiste enden dort, wo Blastas geformte Enden enden."
G["What's new opens after the fight."] = "Die Neuigkeiten öffnen sich nach dem Kampf."
G["What's new can't open right now; close the open guide first."] = "Die Neuigkeiten können gerade nicht öffnen; schließe zuerst das offene Fenster."
G["What's new"] = "Neuigkeiten"
G["Show what's new in %s"] = "Neuigkeiten in %s ansehen"
G["Shows the pages about this Blasta version again: what's new, with previews and the new settings. Also /blasta new."] =
    "Zeigt die Seiten zu dieser Blasta-Version noch einmal: was neu ist, mit Vorschau und den neuen Einstellungen. Auch mit /blasta neu."
-- Raise with each release that has pages: it shows them again once.
local RELEASE, VERSION = 204, "2.4"

-- A settings row drawn like the options window's, saved at once.
local function settingRow(holder, y, width, scope, item)
    local page = { scope = scope, defaults = {} }
    local row = W.Row(holder, page, { items = { item } }, item)
    row.line:Hide()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
    row:SetWidth(width)
    if row.Refresh then row.Refresh() end
    return row, row:GetHeight()
end

local function text(holder, y, width, words, size)
    local fs = API.Text(holder, size or "body", "LEFT")
    fs:SetPoint("TOPLEFT", holder, "TOPLEFT", W.PAD or 14, -y)
    fs:SetWidth(width - 2 * (W.PAD or 14))
    fs:SetWordWrap(true)
    fs:SetText(words)
    return fs, math.ceil(fs:GetStringHeight() or 14)
end

local function rowsUnder(holder, y, width, scope, items)
    local made = {}
    for _, item in ipairs(items) do
        local row, h = settingRow(holder, y, width, scope, item)
        made[#made + 1] = row
        y = y + h
    end
    return y, made
end

local function refreshAll(rows)
    for _, row in ipairs(rows) do if row.Refresh then row.Refresh() end end
end

-- The pages are built again each time the guide opens; one listener follows
-- whichever is current.
local current = {}
DUI.On("SettingChanged", function(scope, path)
    for _, follow in pairs(current) do follow(scope, path) end
end)

-- Page: the raid marker ring.
local UF_SCOPE = "UnitFrames"
local function unitItem(kind, key, label, extra)
    local item = { type = kind, key = key, label = T(label),
        get = function() return DUI:Get(UF_SCOPE, key) end,
        set = function(value) return DUI:Set(UF_SCOPE, key, value) end }
    for k, v in pairs(extra or {}) do item[k] = v end
    return item
end

local function ringPage()
    if not (extras.MarkerRingPreview and DUI:GetModule(UF_SCOPE)) then return end
    return {
        title = T("Marker ring"),
        desc = T("Mark your target right on its portrait."),
        build = function(holder, width)
            local y = 0
            local preview = extras.MarkerRingPreview(holder, 30)
            preview:SetPoint("TOP", holder, "TOP", 0, -y)
            y = y + preview:GetHeight() + 6
            local _, h = text(holder, y, width, T("A small arrow on the target's portrait opens a ring with the eight raid markers. Click one to mark your target; the chip beside the arrow takes the marker off. Works in combat too."), "small")
            y = y + h + 10
            local off = function() return DUI:Get(UF_SCOPE, "target.blastaMarkerRing") ~= true end
            local rows
            y, rows = rowsUnder(holder, y, width, ADDON, {
                unitItem("toggle", "target.blastaMarkerRing", "Raid marker ring", { default = function() return false end }),
                unitItem("dropdown", "target.blastaMarkerOpen", "Open the marker ring", {
                    values = { click = T("On click"), hover = T("On hover") }, order = { "click", "hover" },
                    default = function() return "click" end, disabled = off }),
                unitItem("slider", "target.blastaMarkerArrowAt", "Marker arrow position", {
                    min = 0, max = 355, step = 5, unit = "°", default = function() return 135 end, disabled = off }),
            })
            holder.Refresh = function() refreshAll(rows) end
            current.ring = function(scope, path)
                if scope == UF_SCOPE and type(path) == "string" and path:find("^target%.blastaMarker") then
                    refreshAll(rows)
                    if path == "target.blastaMarkerArrowAt" and preview:IsVisible() then
                        preview:Hide(); preview:Show()
                    end
                end
            end
            return y
        end,
    }
end

-- Page: coin colors in Blasta's loot feed.
local COIN_INK = { gold = { 1, 0.82, 0 }, silver = { 0.80, 0.82, 0.88 }, copper = { 0.93, 0.56, 0.30 } }
local COIN_ORDER = { "gold", "silver", "copper" }
local function coinsOf(money)
    local out = {}
    local parts = { gold = math.floor(money / 10000), silver = math.floor(money / 100) % 100, copper = money % 100 }
    for _, k in ipairs(COIN_ORDER) do if parts[k] > 0 then out[#out + 1] = k end end
    return out
end
local function lootMode() return DUI:Get(ADDON, "blastaLoot.coinColor") or "highest" end
local function moneyText(money)
    local f = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString) or GetCoinTextureString
    return f and f(money) or tostring(money)
end

-- One sample row: a dark bar with the coins' light running in from the left,
-- in the colors the picked choice gives (half each for two coins, a third
-- each for three with "All coins").
local function coinRow(holder, money)
    local row = CreateFrame("Frame", nil, holder)
    row:SetHeight(24)
    local bg = Style.BACKGROUND
    local back = row:CreateTexture(nil, "BACKGROUND")
    back:SetAllPoints(row)
    back:SetColorTexture(bg[1], bg[2], bg[3], 0.85)
    row.pieces = {}
    for i = 1, 3 do
        local t = row:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 1, 1, 1)
        row.pieces[i] = t
    end
    local fade = row:CreateTexture(nil, "BORDER", nil, 1)
    fade:SetColorTexture(1, 1, 1, 1)
    row.fade = fade
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(133784)
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    local label = API.Text(row, "body", "LEFT")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetText(moneyText(money))
    function row.Paint()
        local w = row:GetWidth()
        if not w or w <= 0 then return end
        local mode, coins = lootMode(), coinsOf(money)
        local inks = {}
        if mode == "gold" then inks = { COIN_INK.gold }
        elseif mode == "all" then for _, k in ipairs(coins) do inks[#inks + 1] = COIN_INK[k] end
        else inks = { COIN_INK[coins[1] or "copper"] } end
        local span = w * 0.62
        local share = span / #inks
        for i, t in ipairs(row.pieces) do
            local c = inks[i]
            if c then
                local n = inks[i + 1] or c
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", row, "TOPLEFT", (i - 1) * share, 0)
                t:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (i - 1) * share, 0)
                t:SetWidth(share)
                t:SetGradient("HORIZONTAL", CreateColor(c[1], c[2], c[3], 0.55), CreateColor(n[1], n[2], n[3], 0.55))
                t:Show()
            else
                t:Hide()
            end
        end
        local last = inks[#inks]
        fade:ClearAllPoints()
        fade:SetPoint("TOPLEFT", row, "TOPLEFT", span, 0)
        fade:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", span, 0)
        fade:SetWidth(w * 0.3)
        fade:SetGradient("HORIZONTAL", CreateColor(last[1], last[2], last[3], 0.55), CreateColor(last[1], last[2], last[3], 0))
    end
    row:SetScript("OnSizeChanged", row.Paint)
    return row
end

local function coinPage()
    if not DUI:GetModule("QoL") then return end
    return {
        title = T("Coin colors"),
        desc = T("Looted coins in Blasta's loot feed, in their own colors."),
        build = function(holder, width)
            local y = 0
            local samples = {}
            for _, money in ipairs({ 67, 161, 23456 }) do
                local row = coinRow(holder, money)
                row:SetPoint("TOPLEFT", holder, "TOPLEFT", (W.PAD or 14), -y)
                row:SetWidth(width - 2 * (W.PAD or 14))
                samples[#samples + 1] = row
                y = y + 28
            end
            y = y + 6
            local _, h = text(holder, y, width, T("All coins now gives each coin an equal share of the bar: half each for two coins, a third each for three. Highest coin uses the highest coin looted, Always gold the old look."), "small")
            y = y + h + 10
            local item = { type = "dropdown", key = "blastaLoot.coinColor", label = T("Coin color"),
                values = { highest = T("Highest coin"), all = T("All coins"), gold = T("Always gold") },
                order = { "highest", "all", "gold" },
                get = lootMode,
                set = function(value) return DUI:Set(ADDON, "blastaLoot.coinColor", value) end,
                default = function() return "highest" end }
            local rows
            y, rows = rowsUnder(holder, y, width, ADDON, { item })
            local function repaint() for _, r in ipairs(samples) do r.Paint() end end
            holder.Refresh = function() refreshAll(rows); repaint() end
            current.coins = function(scope, path)
                if scope == ADDON and path == "blastaLoot.coinColor" then refreshAll(rows); repaint() end
            end
            return y
        end,
    }
end

-- Page: what moved to DaylightUI, and the smaller things.
local function movedPage()
    return {
        title = T("Now in DaylightUI"),
        desc = T("Two Blasta settings are DaylightUI's own now."),
        text = T("Breath bar edges: DaylightUI 2.4.0 sets each end of the breath bar itself (Skins → Alerts and timers). Reverse unit frame slant: each end of every unit frame has its own menu in DaylightUI now. Blasta's versions are gone and your choices were carried over, so nothing looks different.")
            .. "\n\n" .. T("Also new: the bag text sizes apply to the bank and the bank and alts window too, and DaylightUI's bar animations on the experience bar end where Blasta's shaped ends do."),
    }
end

local pages = {}
for _, make in ipairs({ ringPage, coinPage, movedPage }) do
    local ok, page = pcall(make)
    if ok and page then pages[#pages + 1] = page end
end
if #pages == 0 then return end

-- Blasta's own mark at the top of the window's step list while its pages
-- show, in place of DaylightUI's; DaylightUI's comes back for its own pages.
local UI = DUI.InstallerUI
local LOGO = "Interface\\AddOns\\" .. ADDON .. "\\Media\\BlastaMenuIcon.tga"
local badge
local function ours(opts)
    return type(opts) == "table" and type(opts.over) == "string" and opts.over:find("^Blasta") ~= nil
end
local function showBadge(on)
    local frame = UI and UI.Frame and UI.Frame()
    local rail = frame and frame.rail
    if not (rail and rail.logo) then return end
    if on and not badge then
        badge = CreateFrame("Frame", nil, rail)
        badge:SetSize(144, 36)
        badge:SetPoint("TOPLEFT", rail.logo, "TOPLEFT", 0, 0)
        badge.icon = badge:CreateTexture(nil, "ARTWORK")
        badge.icon:SetTexture(LOGO)
        badge.icon:SetSize(32, 32)
        badge.icon:SetPoint("LEFT", badge, "LEFT", 0, 0)
        badge.text = (W.Font and W.TITLE) and W.Font(badge, W.TITLE, 20, W.COLORS and W.COLORS.text) or API.Text(badge, "title", "LEFT")
        badge.text:SetPoint("LEFT", badge.icon, "RIGHT", 6, 0)
        badge.text:SetText(extras.BlastaGradient and extras.BlastaGradient("BLASTA") or "BLASTA")
        rail:HookScript("OnHide", function() showBadge(false) end)
    end
    if badge then badge:SetShown(on) end
    rail.logo:SetShown(not on)
end
if UI and UI.SetPage then
    hooksecurefunc(UI, "SetPage", function(_, opts) pcall(showBadge, ours(opts)) end)
end

me.AddInstaller({
    title = "Blasta " .. VERSION,
    version = RELEASE,
    account = true,
    pages = pages,
})

function extras.ShowWhatsNew()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("Blasta: " .. T("What's new opens after the fight."))
        DUI.AfterCombat(extras.ShowWhatsNew, "blastaWhatsNew")
        return
    end
    -- The pages take the screen: Blasta's menu closes first.
    local panel = DUI.OptionsPanel
    if panel and panel.IsShown and panel.IsShown() and panel.Toggle then pcall(panel.Toggle) end
    if not me.ShowInstaller() then
        DEFAULT_CHAT_FRAME:AddMessage("Blasta: " .. T("What's new can't open right now; close the open guide first."))
    end
end
extras.WhatsNewVersion = VERSION
-- Shared with the Blasta tour (Tour.lua).
extras.GuideRow, extras.GuideText, extras.CoinSampleRow = settingRow, text, coinRow

extras.SlashHandlers = extras.SlashHandlers or {}
table.insert(extras.SlashHandlers, function(msg)
    local word = msg:lower():match("^%s*(%S+)")
    if word == "new" or word == "neu" or word == "whatsnew" or word == "news" then
        extras.ShowWhatsNew()
        return true
    end
end)

extras.Loaded("WhatsNew")
