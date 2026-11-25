-- SPDX-License-Identifier: GPL-3.0-or-later
-- Blasta's menu helpers:
--   * a short help line at the top of every tab of Blasta's pages (English or
--     German, by Blasta's language), and "Open ..." buttons on the tabs that
--     change a window;
--   * the Tooltips page's live preview in a column on the right of DaylightUI's
--     options window: the page's settings make room for it while that page is
--     open, every other page keeps the window's full width.
local ADDON, extras = ...
local DUI = DaylightUI
local T = extras.Translate
local German = extras.German or {}

-- ---------------------------------------------------------------------
-- Help lines
-- ---------------------------------------------------------------------

-- What each page and tab is for. A tab without its own line shows the page's.
local HELP = {
    units = {
        [""] = "Blasta's extras for DaylightUI's unit frames. The preview above shows the frame of the tab you're on; in Design mode you can drag Blasta's parts on it, like the leader crown or the PvP badge.",
        Player = "Your own frame: slants, portrait shape, text sizes and the icons on the portrait. In Design mode, drag the icons on the preview.",
        Target = "Your target's frame: slants, portrait shape, text sizes and the icons on the portrait.",
        Party = "The party frames: Blasta's portraits, the compact resource bar and the icons on them.",
        Raid = "The raid frames, for each raid size.",
        ["More frames"] = "Focus, pet, target of target and the other small frames, each on its own card.",
        Look = "Settings that go for every frame, like the shape of the frames.",
        ["Cast bars"] = "Blasta's extras for the cast bars and the swing timer.",
        ["Bar effects"] = "Short effects on the bars when something happens: a big hit, a heal, a level up.",
    },
    auras = {
        [""] = "Buffs, debuffs and DoTs on the unit frames: their size and shape and the dispel highlight.",
        General = "DoT fill and the Shadow Word: Death marker on the target frame.",
        ["Aura bars"] = "Your buffs as bars with time left instead of icons, near your frame.",
    },
    plates = {
        [""] = "Blasta's extras for DaylightUI's nameplates: shape and edges, borders, names, the cast bar's entrance and aura sizes.",
    },
    bars = {
        [""] = "Blasta's extras for DaylightUI's action bars: pixel-exact buttons, slants and finer size and spacing.",
        ["Resource costs"] = "Shows on each button how much rage, energy or mana you're missing for it, or how much you have to spare.",
        ["Food and drink"] = "Small bars that show while you eat or drink, filling up to full health and mana.",
    },
    info = {
        [""] = "The info panel at the top right, the experience bar and your buffs.",
        ["Experience bar"] = "Blasta's look for the experience bar and the animation when you gain experience.",
        General = "Spacing and layout of the info panel and the buffs beside it.",
        ["Data texts"] = "Colors of the data texts and whether money shows to the copper.",
        Buffs = "Spacing, borders, and animation for the buffs and debuffs next to the minimap.",
        ["Buff reminders"] = "A reminder when a buff you want is missing, with a key to cast it.",
    },
    tooltips = {
        [""] = "Blasta's own tooltip look, its text sizes, DaylightUI's coins in every price and sell prices per piece. Click a part of the preview on the right to jump to its setting. Click \"Item\" again for a recipe or a quest item.",
    },
    windows = {
        ["Group Finder"] = "Filters in the group finder: several dungeons at once, open roles, who's already in the group, level ranges and applying with one click.",
        Spellbook = "Square spell icons in the spellbook and the total cost of what you still have to train.",
        Character = "Extras for the character window.",
        Bags = "Blasta's categories and item icons in DaylightUI's bags.",
        Professions = "Extras for the profession window, like the golden sweep after a craft.",
        Quests = "Extras for the quest log, like abandoning a quest in one step.",
    },
    world = {
        ["World map"] = "Boat and zeppelin routes when you hover one of their symbols on the map. Zone levels are DaylightUI's own now (Game window skins → World map).",
        ["Zone title"] = "More on DaylightUI's zone title when you enter a zone: its level range, whether you discovered it and whether it's a rest area.",
        Loot = "Loot window icons, making room in full bags, loot rolls, and loot feed messages.",
        Chat = "Chat corners, the micro menu, and whisper windows.",
        ["Flight & breath bars"] = "The look of the bar while you fly with a flight master, and of the breath and fatigue bars.",
        ["AFK screen"] = "Blasta's layout for DaylightUI's AFK screen, with what you did this session.",
    },
    language = {
        General = "Blasta's language, the login message and the startup animation.",
        Profiles = "Move your DaylightUI and Blasta settings to another character or computer in one string.",
    },
}

local DE = {
    ["Spacing, borders, and animation for the buffs and debuffs next to the minimap."] =
        "Abstände, Rahmen und Animationen der Buffs und Debuffs neben der Minikarte.",
    ["Loot window icons, making room in full bags, loot rolls, and loot feed messages."] =
        "Beute-Icons, Platz in vollen Taschen, Würfelfenster und Meldungen im Beute-Feed.",
    ["Chat corners, the micro menu, and whisper windows."] =
        "Chat-Ecken, Mikromenü und Flüsterfenster.",
    ["Blasta's extras for DaylightUI's unit frames. The preview above shows the frame of the tab you're on; in Design mode you can drag Blasta's parts on it, like the leader crown or the PvP badge."] =
        "Blastas Extras für DaylightUIs Einheitenfenster. Die Vorschau oben zeigt das Fenster des gewählten Reiters; im Design-Modus kannst du Blastas Teile darauf verschieben, etwa die Anführerkrone oder das PvP-Abzeichen.",
    ["Your own frame: slants, portrait shape, text sizes and the icons on the portrait. In Design mode, drag the icons on the preview."] =
        "Dein eigenes Fenster: Schrägen, Porträtform, Textgrößen und die Symbole am Porträt. Im Design-Modus ziehst du die Symbole in der Vorschau.",
    ["Your target's frame: slants, portrait shape, text sizes and the icons on the portrait."] =
        "Das Fenster deines Ziels: Schrägen, Porträtform, Textgrößen und die Symbole am Porträt.",
    ["The party frames: Blasta's portraits, the compact resource bar and the icons on them."] =
        "Die Gruppenfenster: Blastas Porträts, die kompakte Ressourcenleiste und die Symbole darauf.",
    ["The raid frames, for each raid size."] = "Die Schlachtzugsfenster, für jede Schlachtzugsgröße.",
    ["Focus, pet, target of target and the other small frames, each on its own card."] =
        "Fokus, Begleiter, Ziel des Ziels und die anderen kleinen Fenster, jedes auf einer eigenen Karte.",
    ["Settings that go for every frame, like the shape of the frames."] = "Einstellungen für alle Fenster, etwa ihre Form.",
    ["Blasta's extras for the cast bars and the swing timer."] = "Blastas Extras für die Zauberleisten und den Schlagtimer.",
    ["Short effects on the bars when something happens: a big hit, a heal, a level up."] =
        "Kurze Effekte auf den Leisten, wenn etwas passiert: ein großer Treffer, eine Heilung, ein Stufenaufstieg.",
    ["Buffs, debuffs and DoTs on the unit frames: their size and shape and the dispel highlight."] =
        "Buffs, Debuffs und DoTs an den Einheitenfenstern: Größe und Form und die Bannhervorhebung.",
    ["DoT fill and the Shadow Word: Death marker on the target frame."] =
        "DoT-Füllung und die Schattenwort: Tod-Markierung am Zielfenster.",
    ["Your buffs as bars with time left instead of icons, near your frame."] =
        "Deine Buffs als Leisten mit Restzeit statt als Symbole, nahe deinem Fenster.",
    ["Blasta's extras for DaylightUI's nameplates: shape and edges, borders, names, the cast bar's entrance and aura sizes."] =
        "Blastas Extras für DaylightUIs Namensplaketten: Form und Kanten, Ränder, Namen, das Einfahren der Zauberleiste und Aura-Größen.",
    ["Blasta's extras for DaylightUI's action bars: pixel-exact buttons, slants and finer size and spacing."] =
        "Blastas Extras für DaylightUIs Aktionsleisten: pixelgenaue Tasten, Schrägen und feinere Größe und Abstände.",
    ["Shows on each button how much rage, energy or mana you're missing for it, or how much you have to spare."] =
        "Zeigt auf jeder Taste, wie viel Wut, Energie oder Mana dir dafür fehlt oder wie viel du übrig hast.",
    ["Small bars that show while you eat or drink, filling up to full health and mana."] =
        "Kleine Leisten beim Essen und Trinken, die sich bis zu vollem Leben und Mana füllen.",
    ["The info panel at the top right, the experience bar and your buffs."] = "Das Info-Panel oben rechts, die Erfahrungsleiste und deine Buffs.",
    ["Blasta's look for the experience bar and the animation when you gain experience."] =
        "Blastas Aussehen für die Erfahrungsleiste und die Animation, wenn du Erfahrung bekommst.",
    ["Spacing and layout of the info panel and the buffs beside it."] = "Abstände und Anordnung des Info-Panels und der Buffs daneben.",
    ["Colors of the data texts and whether money shows to the copper."] = "Farben der Datentexte und ob Geld auf das Kupfer genau angezeigt wird.",
    ["A reminder when a buff you want is missing, with a key to cast it."] = "Eine Erinnerung, wenn ein gewünschter Buff fehlt, mit einer Taste zum Wirken.",
    ["Blasta's own tooltip look, its text sizes, DaylightUI's coins in every price and sell prices per piece. Click a part of the preview on the right to jump to its setting. Click \"Item\" again for a recipe or a quest item."] =
        "Blastas eigenes Tooltip-Aussehen, seine Textgrößen, DaylightUIs Münzen bei jedem Preis und Verkaufspreise pro Stück. Klick auf einen Teil der Vorschau rechts springt zu seiner Einstellung. Klicke erneut auf „Gegenstand“ für ein Rezept oder einen Questgegenstand.",
    ["Filters in the group finder: several dungeons at once, open roles, who's already in the group, level ranges and applying with one click."] =
        "Filter in der Gruppensuche: mehrere Dungeons auf einmal, offene Rollen, wer schon in der Gruppe ist, Stufenbereiche und Bewerben mit einem Klick.",
    ["Square spell icons in the spellbook and the total cost of what you still have to train."] =
        "Eckige Zaubersymbole im Zauberbuch und die Gesamtkosten dessen, was du noch lernen musst.",
    ["Extras for the character window."] = "Extras für das Charakterfenster.",
    ["Blasta's categories and item icons in DaylightUI's bags."] = "Blastas Kategorien und Gegenstandssymbole in DaylightUIs Taschen.",
    ["Extras for the profession window, like the golden sweep after a craft."] = "Extras für das Berufsfenster, etwa der goldene Schimmer nach dem Herstellen.",
    ["Extras for the quest log, like abandoning a quest in one step."] = "Extras für das Questlog, etwa eine Quest in einem Schritt abbrechen.",
    ["Boat and zeppelin routes when you hover one of their symbols on the map. Zone levels are DaylightUI's own now (Game window skins → World map)."] =
        "Schiffs- und Zeppelinrouten, wenn du auf der Karte über eines ihrer Symbole fährst. Zonenstufen hat DaylightUI jetzt selbst (Spielfenster-Skins → Weltkarte).",
    ["More on DaylightUI's zone title when you enter a zone: its level range, whether you discovered it and whether it's a rest area."] =
        "Mehr auf DaylightUIs Zonentitel beim Betreten einer Zone: ihr Stufenbereich, ob du sie entdeckt hast und ob sie ein Rastgebiet ist.",
    ["The look of the bar while you fly with a flight master, and of the breath and fatigue bars."] =
        "Das Aussehen der Leiste beim Flug mit einem Flugmeister und der Atem- und Erschöpfungsleiste.",
    ["Blasta's layout for DaylightUI's AFK screen, with what you did this session."] =
        "Blastas Layout für DaylightUIs AFK-Bildschirm, mit dem, was du in dieser Sitzung gemacht hast.",
    ["Blasta's language, the login message and the startup animation."] = "Blastas Sprache, die Login-Nachricht und die Startanimation.",
    ["Move your DaylightUI and Blasta settings to another character or computer in one string."] =
        "Übertrage deine DaylightUI- und Blasta-Einstellungen mit einem Text auf einen anderen Charakter oder Rechner.",
    ["Open the group finder"] = "Gruppensuche öffnen",
    ["Open the spellbook"] = "Zauberbuch öffnen",
    ["Open the character window"] = "Charakterfenster öffnen",
    ["Open the bags"] = "Taschen öffnen",
    ["Open the quest log"] = "Questlog öffnen",
    ["Open the world map"] = "Weltkarte öffnen",
    ["Open"] = "Öffnen",
    ["Preview"] = "Vorschau",
    ["Turn on Blasta tooltips (Tooltip style: Blasta) to see the preview."] =
        "Schalte Blasta-Tooltips ein (Tooltip-Stil: Blasta), um die Vorschau zu sehen.",
    ["Flight & breath bars"] = "Flug- & Atemleiste",
    ["Flight timer"] = "Flugtimer",
    ["Breath and fatigue bar"] = "Atem- und Erschöpfungsleiste",
}
for en, de in pairs(DE) do German[en] = de end

-- Windows a tab changes, opened from a button on it.
local function call(fn, ...) if type(fn) == "function" then pcall(fn, ...) end end
local OPEN = {
    windows = {
        ["Group Finder"] = { "Open the group finder", function()
            local w = DUI.Lfg and DUI.Lfg.Window
            if w and w.ShowTab then call(w.ShowTab, "find") else call(_G.ToggleLFGParentFrame) end
        end },
        Spellbook = { "Open the spellbook", function() call(_G.ToggleSpellBook, _G.BOOKTYPE_SPELL or "spell") end },
        Character = { "Open the character window", function() call(_G.ToggleCharacter, "PaperDollFrame") end },
        Bags = { "Open the bags", function() call(_G.ToggleAllBags) end },
        Quests = { "Open the quest log", function() call(_G.ToggleQuestLog) end },
    },
    world = {
        ["World map"] = { "Open the world map", function() call(_G.ToggleWorldMap) end },
    },
}

-- Before the pages are translated: the first card of each tab gets the help
-- line on top, and the button that opens its window at the bottom.
function extras.AddMenuHelp(pages)
    for _, page in ipairs(pages) do
        local help, open, seen = HELP[page.id] or {}, OPEN[page.id] or {}, {}
        for _, group in ipairs(page.groups or {}) do
            local tab = group.tab or ""
            if not seen[tab] and type(group.items) == "table" then
                seen[tab] = true
                local line = help[tab] or (tab == "" and help[""]) or nil
                if line and line ~= page.desc then
                    table.insert(group.items, 1, { type = "text", label = line, noSearch = true })
                end
                local o = open[tab]
                if o then
                    group.items[#group.items + 1] = { type = "button", label = o[1], text = "Open", func = o[2] }
                end
            end
        end
        extras.AddTabResets(page)
    end
end

-- "Reset this tab" at the end of each tab's last card, on pages with tabs
-- (a page without tabs has DaylightUI's own Reset page). It resets Blasta's
-- rows on that tab only; copies of DaylightUI's own rows (the bar animation
-- speed, for one) stay as they are, since they belong to DaylightUI.
local function resetTab(page, groups)
    local options = DUI.Options
    if not (options and options.ResetItem) then return end
    local live = options.GetPage and options.GetPage(ADDON .. "." .. page.id) or page
    for _, group in ipairs(groups) do
        for _, item in ipairs(group.items or {}) do
            if options.VALUE and options.VALUE[item.type] and (item.blastaOwn or not item.blastaCopy) then
                pcall(options.ResetItem, live, item)
            end
        end
    end
end

function extras.AddTabResets(page)
    local byTab, order = {}, {}
    for _, group in ipairs(page.groups or {}) do
        local tab = group.tab
        if tab then
            if not byTab[tab] then byTab[tab] = {}; order[#order + 1] = tab end
            table.insert(byTab[tab], group)
        end
    end
    if #order < 2 then return end
    for _, tab in ipairs(order) do
        local groups = byTab[tab]
        local values = false
        for _, group in ipairs(groups) do
            for _, item in ipairs(group.items or {}) do
                if (item.key or item.get) and item.type ~= "button" and item.type ~= "text"
                    and item.type ~= "custom" and (item.blastaOwn or not item.blastaCopy) then values = true end
            end
        end
        local last = groups[#groups]
        if values and type(last.items) == "table" then
            last.items[#last.items + 1] = { type = "button", label = "Reset this tab", text = "Reset",
                confirm = true, noSearch = true, blastaTabReset = true,
                desc = "Puts Blasta's settings on this tab back to their defaults. The rest of the page stays as it is.",
                func = function() resetTab(page, groups) end }
        end
    end
end

-- ---------------------------------------------------------------------
-- The Tooltips page's preview column
-- ---------------------------------------------------------------------

local PAGE = ADDON .. ".tooltips"
local GAP, MIN_CONTENT = 20, 420
local style, widgets = DUI.Style, DUI.Widgets
local column, baseRight, width

local function panel() return DUI.OptionsPanel end

local function wantColumn(id)
    local p = panel()
    return (id or (p.Current and p.Current())) == PAGE
end

-- The settings' right margin: wider while the Tooltips page is open, so the
-- preview fits beside them.
local function setMargin(id)
    local p = panel()
    baseRight = baseRight or p.CONTENT_RIGHT
    local frame = p.Frame and p.Frame()
    width = nil
    if wantColumn(id) and frame then
        local w = frame:GetWidth() or 0
        local room = (p.ContentWidth and p.ContentWidth() or 600) + (p.CONTENT_RIGHT - baseRight)
        local want = math.floor(math.max(300, math.min(420, w * 0.3)))
        if room - want - GAP >= MIN_CONTENT then width = want end
    end
    p.CONTENT_RIGHT = baseRight + (width and width + GAP or 0)
end

local function build(frame)
    local c = CreateFrame("Frame", nil, frame)
    c:SetFrameLevel(frame:GetFrameLevel() + 3)
    c.rule = c:CreateTexture(nil, "ARTWORK")
    c.rule:SetColorTexture(1, 1, 1, 1)
    c.rule:SetVertexColor(1, 1, 1, 0.08)
    c.rule:SetPoint("TOPLEFT", c, "TOPLEFT", -GAP / 2, 0)
    c.rule:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", -GAP / 2, 0)
    c.rule:SetWidth(1)
    c.title = style.Text(c, style.SIZE and style.SIZE.head or 15, "LEFT")
    c.title:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
    if style.InkText then style.InkText(c.title, "VALUE") end
    c.host = CreateFrame("Frame", nil, c)
    c.note = style.Text(c, style.SIZE and style.SIZE.small or 12, "LEFT")
    c.note:SetWordWrap(true)
    if style.InkText then style.InkText(c.note, "LABEL") end
    c.chips, c.spots = {}, {}
    return c
end

local function chip(c, i)
    local b = c.chips[i]
    if not b then
        b = widgets.Button(c, "", 22)
        b:SetScript("OnClick", function(self)
            if c.sample and c.sample.SetView then c.sample.SetView(self.view) end
            extras.RefreshTooltipColumn()
        end)
        c.chips[i] = b
    end
    return b
end

local function spot(c, i)
    local b = c.spots[i]
    if not b then
        b = CreateFrame("Button", nil, c.host)
        b.glow = b:CreateTexture(nil, "OVERLAY")
        b.glow:SetAllPoints(b)
        b.glow:SetColorTexture(1, 1, 1, 1)
        if style.PaintAccent then style.PaintAccent(b.glow, 0.18) else b.glow:SetVertexColor(1, 0.8, 0.3, 0.18) end
        b.glow:Hide()
        b:SetScript("OnEnter", function(self)
            self.glow:Show()
            if GameTooltip and self.label then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.label)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function(self) self.glow:Hide(); if GameTooltip then GameTooltip:Hide() end end)
        b:SetScript("OnClick", function(self)
            local p = panel()
            if p.JumpTo and self.keys then p.JumpTo(self.keys) end
        end)
        c.spots[i] = b
    end
    return b
end

local function render(c, frame)
    local p = panel()
    local border = DUI.Pixel and DUI.Pixel.Px and DUI.DB and DUI.DB.General
        and DUI.Pixel.Px(frame, DUI.DB.General().borderPx) or 1
    local top = (p.HEADER or 76) + 12
    c:ClearAllPoints()
    c:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(border + baseRight), -top)
    c:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(border + baseRight), border + 14)
    c:SetWidth(width)
    c.title:SetText(T("Preview"))
    for _, b in ipairs(c.chips) do b:Hide() end
    for _, b in ipairs(c.spots) do b:Hide() end
    c.note:Hide()
    if c.sample == nil and extras.TooltipSample then
        local ok, made = pcall(extras.TooltipSample, c.host)
        c.sample = ok and type(made) == "table" and made.frame and made or false
    end
    local s = c.sample
    if not s then return end
    local y = 26
    local views = s.Views and s.Views() or {}
    if #views > 1 then
        local x = 0
        for i = #views, 1, -1 do
            local v = views[i]
            local b = chip(c, #views - i + 1)
            b.view = v.key
            b.text:SetText(v.label)
            b:SetWidth(math.max(40, (b.text:GetStringWidth() or 30) + 18))
            -- Five views don't fit one row of a narrow column: wrap.
            if x > 0 and x + b:GetWidth() > width then x, y = 0, y + 28 end
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
            b:SetAlpha(v.on and 1 or 0.55)
            b:Show()
            x = x + b:GetWidth() + 4
        end
        y = y + 32
    end
    c.host:ClearAllPoints()
    c.host:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
    c.host:SetSize(width, math.max(1, (c:GetHeight() or 400) - y))
    s.frame:SetParent(c.host)
    s.frame:ClearAllPoints()
    s.frame:SetPoint("TOPLEFT", c.host, "TOPLEFT", 0, 0)
    s.frame:Show()
    local room = math.max(160, ((c:GetHeight() or 500) - y) / 1.5)
    local ok, h = pcall(s.Refresh, width, room)
    if not ok or (tonumber(h) or 0) <= 0 then
        c.note:ClearAllPoints()
        c.note:SetPoint("TOPLEFT", c.host, "TOPLEFT", 0, 0)
        c.note:SetWidth(width)
        c.note:SetText(T("Turn on Blasta tooltips (Tooltip style: Blasta) to see the preview."))
        c.note:Show()
        return
    end
    local parts = s.Parts and s.Parts() or {}
    for i, part in ipairs(type(parts) == "table" and parts or {}) do
        if part.region and part.keys then
            local b = spot(c, i)
            b.keys, b.label = part.keys, part.label
            b:ClearAllPoints()
            b:SetAllPoints(part.region)
            b:SetFrameLevel(c.host:GetFrameLevel() + 20)
            b:Show()
        end
    end
end

local busy
function extras.RefreshTooltipColumn()
    local p = panel()
    local frame = p and p.Frame and p.Frame()
    if not frame or busy then return end
    if not (wantColumn() and width) then
        if column then column:Hide() end
        return
    end
    column = column or build(frame)
    column:Show()
    busy = true
    local ok, err = pcall(render, column, frame)
    busy = false
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

local hooked
local function hook()
    local p = panel()
    if hooked or not (p and p.Show and p.Refresh and p.Current and p.Frame and p.CONTENT_RIGHT) then return end
    hooked = true
    local show = p.Show
    p.Show = function(id, ...)
        setMargin(id)
        return show(id, ...)
    end
    hooksecurefunc(p, "Refresh", function() extras.RefreshTooltipColumn() end)
end
hook()
DUI.On("Login", hook)
