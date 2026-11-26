-- SPDX-License-Identifier: GPL-3.0-or-later
-- The Blasta tour: one page per area of Blasta in DaylightUI's setup guide
-- window, like the "What's new" pages, with what Blasta adds there, a moving
-- preview where it helps and the most useful settings to try right away
-- (they apply at once). It shows only when asked: the button on Blasta's
-- overview, /blasta tour, or the last "What's new" page.
-- The rows are Blasta's own menu rows, found by their English labels before
-- the menu is translated (ns.PrepareTour, from Imported/Options.lua), so they
-- read and save exactly as in the menu.
local ADDON, extras = ...
local DUI = DaylightUI
local API = DUI and DUI.API
local W = DUI and DUI.Widgets
local PI = DUI and DUI.InstallerPlugins
if not (API and W and W.Row and PI and PI.Start and extras.GuideRow and extras.GuideText) then return end

local T = extras.Translate
local G = extras.German
local TITLE = "Blasta tour"
G[TITLE] = "Blasta-Tour"

-- page: Blasta's menu page; labels: rows to show, by their English label.
local TOUR = {
    { id = "welcome", page = "language", noButton = true, title = "Welcome",
      desc = "What Blasta is, and where to find it.",
      text = "Blasta is a plugin for DaylightUI: it adds settings and refinements, and replaces nothing. Everything it adds sits in its own menu, /blasta or Blasta in DaylightUI's options, sorted like DaylightUI's. This tour shows each area with the settings most worth trying; they apply at once, and the menu has the rest.",
      labels = { "Blasta language", "Show Blasta login message", "Show animation at login" } },
    { id = "units", sample = { "target", "player" }, page = "units", from = { { "units", skip = { "cast", "effect" } } }, title = "Unit frames",
      desc = "Portraits, party frames and your target.",
      text = "What Blasta adds to DaylightUI's unit frames: the rows below are the ones most worth trying, the cards listed under them are all of it.",
      preview = "ring",
      labels = { "Global portrait shape", "Portrait position", "Compact party resource bar", "Raid marker ring" } },
    { id = "casts", sample = { "cast" }, page = "units", from = { { "units", only = { "cast", "effect" } } }, title = "Cast bars",
      desc = "Bars that tell you a little more.",
      text = "Blasta's additions to the cast bars, the swing timer and bar effects.",
      labels = { "Retract swing timer while casting", "Interrupt light pulse", "Auto Shot wind-up wave", "Spell icon in portrait" } },
    { id = "auras", sample = { "aura", "buff" }, page = "auras", title = "Auras",
      desc = "Buffs, debuffs and reminders.",
      text = "Blasta's additions to auras on your frames.",
      labels = { "Fit aura icons to frame width", "Square debuff icons", "1 px aura borders", "Show aura reminders" } },
    { id = "plates", sample = { "" }, page = "plates", title = "Nameplates",
      desc = "Shape, threat and auras on the plates.",
      text = "Blasta's additions to DaylightUI's nameplates.",
      labels = { "Threat state colors", "Fit debuffs to the nameplate", "Animate nameplate auras", "Slide out nameplate cast bar" } },
    { id = "bars", sample = { "" }, page = "bars", title = "Action bars",
      desc = "Crisp buttons and what they cost.",
      text = "Blasta's additions to DaylightUI's action bars.",
      labels = { "Pixel-aligned buttons", "Channel tick markers", "Show food and drink bars" } },
    { id = "bags", sample = { "loot", "bag" }, page = "windows", from = { { "windows", only = { "bag" } }, { "world", only = { "loot" } } }, title = "Bags and loot",
      desc = "Sorting, selling and what you loot.",
      text = "Blasta's additions to the bags and to loot.",
      preview = "coins",
      labels = { "Blasta categories", "Blasta filter bar", "Sell bag categories with right-click", "Use Blasta loot feed", "Coin color" } },
    { id = "windows", sample = { "" }, page = "windows", from = { { "windows", skip = { "bag" } } }, title = "Windows",
      desc = "Character, talents, spellbook and professions.",
      text = "Blasta's additions to DaylightUI's windows.",
      labels = { "Cut corner on all windows", "Enable Blasta Character Panel", "Enable Blasta talent layout (test)", "Professions panel", "Learnable recipes in the window" } },
    { id = "world", sample = { "experience", "zone", "map" }, page = "world", from = { { "world", skip = { "loot" } }, { "info" } }, title = "World and info",
      desc = "Map, zone title, experience and more.",
      text = "Blasta's additions around the world, the map and the info panel.",
      labels = { "Boat and zeppelin routes", "Show the zone's level range", "Animate experience gains", "Crowd control alert as a ring", "Blasta AFK layout" } },
    { id = "tooltips", sample = { "" }, page = "tooltips", title = "Tooltips and friends",
      desc = "What's worth knowing at a glance.",
      text = "Blasta's additions to tooltips and prices.",
      labels = { "Tooltip style", "Show disenchant results", "Daylight coins everywhere", "Sell price per piece", "Whisper conversation from the chat's edge" } },
    { id = "done", title = "That's Blasta",
      desc = "Where to go from here.",
      text = "Every setting is in Blasta's menu, page by page like this tour. Profiles carry Blasta's settings to your other characters. If something doesn't look right after a DaylightUI update, /blasta check lists what needs a look, and /blasta report puts a bug report together.",
      buttons = "done" },
}

G["Welcome"] = "Willkommen"
G["What Blasta is, and where to find it."] = "Was Blasta ist und wo du es findest."
G["Blasta is a plugin for DaylightUI: it adds settings and refinements, and replaces nothing. Everything it adds sits in its own menu, /blasta or Blasta in DaylightUI's options, sorted like DaylightUI's. This tour shows each area with the settings most worth trying; they apply at once, and the menu has the rest."] =
    "Blasta ist ein Plugin für DaylightUI: Es ergänzt Einstellungen und Feinschliff und ersetzt nichts. Alles, was es hinzufügt, steht in seinem eigenen Menü, /blasta oder Blasta in DaylightUIs Optionen, sortiert wie bei DaylightUI. Diese Tour zeigt jeden Bereich mit den Einstellungen, die sich am meisten lohnen; sie gelten sofort, der Rest steht im Menü."
G["Unit frames"] = "Einheitenrahmen"
G["Portraits, party frames and your target."] = "Porträts, Gruppenrahmen und dein Ziel."
G["Cast bars"] = "Zauberleisten"
G["Bars that tell you a little more."] = "Leisten, die dir etwas mehr verraten."
G["Auras"] = "Auren"
G["Buffs, debuffs and reminders."] = "Buffs, Debuffs und Erinnerungen."
G["Nameplates"] = "Namensplaketten"
G["Shape, threat and auras on the plates."] = "Form, Bedrohung und Auren auf den Plaketten."
G["Action bars"] = "Aktionsleisten"
G["Crisp buttons and what they cost."] = "Scharfe Knöpfe und was sie kosten."
G["Bags and loot"] = "Taschen und Beute"
G["Sorting, selling and what you loot."] = "Sortieren, Verkaufen und was du lootest."
G["Windows"] = "Fenster"
G["Character, talents, spellbook and professions."] = "Charakter, Talente, Zauberbuch und Berufe."
G["World and info"] = "Welt und Info"
G["Map, zone title, experience and more."] = "Karte, Zonentitel, Erfahrung und mehr."
G["Tooltips and friends"] = "Tooltips und Freunde"
G["What's worth knowing at a glance."] = "Was man auf einen Blick wissen will."
G["That's Blasta"] = "Das ist Blasta"
G["Where to go from here."] = "Wie es weitergeht."
G["Every setting is in Blasta's menu, page by page like this tour. Profiles carry Blasta's settings to your other characters. If something doesn't look right after a DaylightUI update, /blasta check lists what needs a look, and /blasta report puts a bug report together."] =
    "Jede Einstellung steht im Blasta-Menü, Seite für Seite wie in dieser Tour. Profile übertragen Blastas Einstellungen auf deine anderen Charaktere. Wenn nach einem DaylightUI-Update etwas nicht stimmt, zeigt /blasta check, was du dir ansehen solltest, und /blasta report stellt einen Fehlerbericht zusammen."
G["Open Blasta's menu"] = "Blasta-Menü öffnen"
G["Bug report"] = "Fehlerbericht"
G["Show all settings"] = "Alle Einstellungen"
G["The tour opens after the fight."] = "Die Tour öffnet sich nach dem Kampf."
G["The tour can't open right now; close the open guide first."] = "Die Tour kann gerade nicht öffnen; schließe zuerst das offene Fenster."
G["Start the tour"] = "Tour starten"
G["Shows every area of Blasta with its most useful settings, page by page. Also /blasta tour."] =
    "Zeigt jeden Bereich von Blasta mit seinen wichtigsten Einstellungen, Seite für Seite. Auch mit /blasta tour."

G["What Blasta adds to DaylightUI's unit frames: the rows below are the ones most worth trying, the cards listed under them are all of it."] = "Was Blasta an DaylightUIs Einheitenrahmen ergänzt: Die Zeilen unten lohnen sich am meisten, die Karten darunter sind alles, was es gibt."
G["Blasta's additions to the cast bars, the swing timer and bar effects."] = "Blastas Ergänzungen an Zauberleisten, Schlagtimer und Balkeneffekten."
G["Blasta's additions to auras on your frames."] = "Blastas Ergänzungen an den Auren deiner Rahmen."
G["Blasta's additions to DaylightUI's nameplates."] = "Blastas Ergänzungen an DaylightUIs Namensplaketten."
G["Blasta's additions to DaylightUI's action bars."] = "Blastas Ergänzungen an DaylightUIs Aktionsleisten."
G["Blasta's additions to the bags and to loot."] = "Blastas Ergänzungen an Taschen und Beute."
G["Blasta's additions to DaylightUI's windows."] = "Blastas Ergänzungen an DaylightUIs Fenstern."
G["Blasta's additions around the world, the map and the info panel."] = "Blastas Ergänzungen rund um Welt, Karte und Infoleiste."
G["Blasta's additions to tooltips and prices."] = "Blastas Ergänzungen an Tooltips und Preisen."

local found = {}   -- tour page id -> { rows = { { page, group, item } }, cards = { group } }

-- Whether a card's tab (English, before translating) passes a source's filter.
local function tabMatches(tab, words)
    tab = type(tab) == "string" and tab:lower() or ""
    for _, w in ipairs(words) do if tab:find(w, 1, true) then return true end end
    return false
end

-- Blasta's menu rows by English label, before ns.LocalizePages translates
-- them, and the cards they sit on. Only what the menu really holds is shown:
-- a part that didn't load (an old DaylightUI, a module that's off) has no row.
function extras.PrepareTour(pages, samples)
    local byId = {}
    for _, page in ipairs(pages) do byId[page.id] = page end
    for _, spec in ipairs(TOUR) do
        local cards, rows, seenCard = {}, {}, {}
        local sources = spec.from or (spec.page and { { spec.page } }) or {}
        for _, src in ipairs(sources) do
            local page = byId[src[1]]
            for _, group in ipairs(page and page.groups or {}) do
                local ok = (not src.only or tabMatches(group.tab, src.only)) and not (src.skip and tabMatches(group.tab, src.skip))
                if ok and type(group.items) == "table" and #group.items > 0 then
                    if not seenCard[group] then seenCard[group] = true; cards[#cards + 1] = group end
                    for _, item in ipairs(group.items) do
                        for li, label in ipairs(spec.labels or {}) do
                            if item.label == label and item.type ~= "text" and not rows[li] then
                                item.blastaTourLabel = label
                                rows[li] = { page = page, group = group, item = item }
                            end
                        end
                    end
                end
            end
        end
        local list = {}
        for li = 1, #(spec.labels or {}) do if rows[li] then list[#list + 1] = rows[li] end end
        -- The preview the menu page itself shows on top, for a tab this area covers.
        local sample
        for _, word in ipairs(spec.sample or {}) do
            for _, src in ipairs(sources) do
                local bySource = samples and samples[byId[src[1]] or false]
                for tab, source in pairs(bySource or {}) do
                    local ok = (not src.only or tabMatches(tab, src.only)) and not (src.skip and tabMatches(tab, src.skip))
                    if not sample and ok and (word == "" or tabMatches(tab, { word })) then sample = source end
                end
            end
            if sample then break end
        end
        found[spec.id] = { rows = list, cards = cards, sample = sample }
    end
end

local function openMenu(id)
    local panel = DUI.OptionsPanel
    if panel and panel.Show then panel.Show(ADDON .. (id and ("." .. id) or "")) end
end

local function placeRows(holder, y, width, rows)
    local made = {}
    for _, hit in ipairs(rows) do
        local scope = hit.page.scope or ADDON
        local ok, row, h = pcall(function()
            local page = { scope = scope, defaults = hit.page.defaults or {}, mapKey = hit.page.mapKey }
            local row = W.Row(holder, page, hit.group, hit.item)
            row.line:Hide()
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
            row:SetWidth(width)
            if row.Refresh then row.Refresh() end
            return row, row:GetHeight()
        end)
        if ok and row then
            made[#made + 1] = row
            y = y + (h or W.ROW_HEIGHT or 28)
        end
    end
    return y, made
end

local function buildPage(spec)
    return function(holder, width)
        local y = 0
        local data = found[spec.id] or { rows = {}, cards = {} }
        local function has(label)
            for _, r in ipairs(data.rows) do if r.item.blastaTourLabel == label then return true end end
        end
        if spec.preview == "ring" and extras.MarkerRingPreview and has("Raid marker ring") then
            local preview = extras.MarkerRingPreview(holder, 26)
            preview:SetPoint("TOP", holder, "TOP", 0, -y)
            y = y + preview:GetHeight() + 4
        elseif spec.preview == "coins" and extras.CoinSampleRow and has("Coin color") then
            for _, money in ipairs({ 161, 23456 }) do
                local row = extras.CoinSampleRow(holder, money)
                row:SetPoint("TOPLEFT", holder, "TOPLEFT", W.PAD or 14, -y)
                row:SetWidth(width - 2 * (W.PAD or 14))
                y = y + 28
            end
            y = y + 4
        end
        if data.sample then
            local source = data.sample.previews and data.sample.previews[1] or data.sample
            local ok, inner = pcall(source.sample, holder)
            if ok and type(inner) == "table" and inner.frame then
                inner.frame:SetParent(holder)
                inner.frame:ClearAllPoints()
                inner.frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -y)
                inner.frame:Show()
                local fine, h = pcall(inner.Refresh, width, 180)
                if fine and type(h) == "number" and h > 0 then
                    y = y + h + 8
                    holder.blastaSample = inner
                else
                    inner.frame:Hide()
                end
            end
        end
        local _, h = extras.GuideText(holder, y, width, T(spec.text), "small")
        y = y + h + 10
        local rows
        y, rows = placeRows(holder, y, width, data.rows)
        holder.Refresh = function()
            for _, r in ipairs(rows) do if r.Refresh then r.Refresh() end end
            local inner = holder.blastaSample
            if inner and inner.Refresh then pcall(inner.Refresh, width, 180) end
        end
        return y
    end
end

local function pagesOf()
    local out = {}
    for _, spec in ipairs(TOUR) do
        local def = { title = T(spec.title), desc = T(spec.desc), plugin = ADDON }
        if spec.buttons == "done" then
            def.text = T(spec.text)
            def.buttons = {
                { text = T("Open Blasta's menu"), main = true, onClick = function()
                    if DUI.InstallerUI and DUI.InstallerUI.QuietHide then pcall(DUI.InstallerUI.QuietHide) end
                    openMenu()
                end },
                { text = T("Bug report"), onClick = function() if extras.Report and extras.Report.Show then extras.Report.Show() end end },
            }
        elseif #((found[spec.id] or {}).cards or {}) == 0 and spec.page then
            def = nil   -- nothing of this area in Blasta's menu here
        else
            def.build = buildPage(spec)
            if spec.page and not spec.noButton then
                def.buttons = { { text = T("Show all settings"), onClick = function()
                    if DUI.InstallerUI and DUI.InstallerUI.QuietHide then pcall(DUI.InstallerUI.QuietHide) end
                    openMenu(spec.page)
                end } }
            end
        end
        if def then out[#out + 1] = def end
    end
    return out
end

-- Shown on asking only: a guide of its own, not one that comes up at login.
function extras.ShowTour()
    if InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("Blasta: " .. T("The tour opens after the fight."))
        DUI.AfterCombat(extras.ShowTour, "blastaTour")
        return
    end
    -- The tour takes the screen: Blasta's menu closes first.
    local panel = DUI.OptionsPanel
    if panel and panel.IsShown and panel.IsShown() and panel.Toggle then pcall(panel.Toggle) end
    local entry = { plugin = ADDON .. "_Tour", title = T(TITLE), version = 1, account = true, pages = pagesOf() }
    local ok, started = pcall(PI.Start, { entry })
    if not (ok and started) then
        DEFAULT_CHAT_FRAME:AddMessage("Blasta: " .. T("The tour can't open right now; close the open guide first."))
    end
end

extras.SlashHandlers = extras.SlashHandlers or {}
table.insert(extras.SlashHandlers, function(msg)
    local word = msg:lower():match("^%s*(%S+)")
    if word == "tour" then
        extras.ShowTour()
        return true
    end
end)

extras.Loaded("Tour")
