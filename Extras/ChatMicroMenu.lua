local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Chat")
local mod = DUI:GetModule("Chat")
local Box, Chat = ns and ns.Box, ns and ns.Chat
local Style, Motion, Widgets = DUI.Style, DUI.Motion, DUI.Widgets
if not (mod and mod.defaults and Box and Box.BuildActions and Box.Layout and Chat and Chat.Panel
    and Style and Motion and Motion.Tween and Widgets and Widgets.IconButton) then return end

local KEY, SLOT = "blastaChatMicroMenu", "blastaMicroMenu"
local LABEL, POSITION = "Blasta Micro Menu", "blastaChatMicroMenuPosition"
local DESC = "Replace the standard micro menu with a menu opened from the three dots in the chat header."
local POS_LABEL = "Where the menu opens"
extras.German[DESC] = "Ersetzt das Standard-Mikromenü. Das Blasta-Mikromenü öffnet sich über die drei Punkte im Chatkopf."
extras.German[POS_LABEL] = "Öffnungsposition"
extras.German["Above chat, right"] = "Über dem Chat, rechts"
extras.German["Above chat, left"] = "Über dem Chat, links"
extras.German["Beside chat, right"] = "Rechts neben dem Chat"
mod.defaults[KEY], mod.defaults[POSITION] = false, "right"

local function cfg() return mod.db or mod.defaults end
local function enabled() return cfg()[KEY] == true end

local function nativeClick(name)
    local button = _G[name]
    if button and button.Click and button:IsEnabled() then button:Click() end
end

local function openBook(pageName, fallback)
    local book = DUI.Book and DUI.Book.Window
    if book and book.frame and DUI.bookOwnWindow and book.Open then
        book.Open(pageName)
    else
        nativeClick(_G[fallback] and fallback or "PlayerSpellsMicroButton")
    end
end

-- Forever exposes some Mainline buttons without the systems they open.
local specs = {
    { "CharacterMicroButton", "character", "Character Info", "Charakterinfo", "TOGGLECHARACTER0" },
    { "ProfessionMicroButton", "professions", "Professions", "Berufe", "TOGGLEPROFESSIONBOOK" },
    { "SpellbookMicroButton", "spellbook", "Spellbook", "Zauberbuch", "TOGGLESPELLBOOK" },
    { "TalentMicroButton", "talents", "Talents", "Talente", "TOGGLETALENTS" },
    { "LegacyMicroButton", "legacy", "Legacy", "Vermächtnis" },
    { "QuestLogMicroButton", "quests", "Quest Log", "Questlog", "TOGGLEQUESTLOG" },
    { "GuildMicroButton", "guild", "Guild and Communities", "Gilde und Communitys", "TOGGLEGUILDTAB" },
    { "LFDMicroButton", "finder", "Dungeon Finder", "Dungeonbrowser", "TOGGLEGROUPFINDER" },
    { "CollectionsMicroButton", "collections", "Account Collections", "Accountsammlungen", "TOGGLECOLLECTIONS" },
    { "StoreMicroButton", "shop", "Shop", "Shop", "TOGGLESTORE" },
    { "MainMenuMicroButton", "menu", "Game Menu", "Spielmenü", "TOGGLEGAMEMENU" },
}
local bars = DUI:GetModule("ActionBars")
local barNS = bars and bars.ns
local Hide = barNS and barNS.Hide
local canReplace = Hide and Hide.Apply and Hide.Repark and Hide.FadeFrame
local function collectEntries()
    local entries = {}
    for _, spec in ipairs(specs) do
        local name = spec[1]
        local button = _G[name]
        -- Parking the native menu changes its visibility through its parent.
        if button and button.Click and button:IsShown() then
            entries[#entries + 1] = { name = name, button = button, spec = spec }
        end
    end
    return entries
end

local function activate(entry)
    local name = entry.name
    if name == "SpellbookMicroButton" or name == "TalentMicroButton" then
        openBook(name == "SpellbookMicroButton" and "spells" or "talents", name)
    elseif name == "ProfessionMicroButton" then
        local craft = DUI.Craft
        local window = craft and craft.Window
        local spell = window and craft.Key and craft.Key.Spell and craft.Key.Spell()
        if spell and window.Switch then
            if window.frame and DUI.Win.IsOpen(window.frame) then window.Close() else window.Switch(spell) end
        else nativeClick(name) end
    else nativeClick(name) end
end

local panel, trigger, pane
local opened, progress = false, 0
local PANEL_WIDTH, ROW_HEIGHT, GAP = 192, 23, 9
local function colorLine(frame)
    if frame.topLine then Style.PaintAccent(frame.topLine, 0.7) end
end

local function anchorMenu(menu, chat, value)
    local offset = 6 * (1 - value)
    menu:ClearAllPoints()
    if cfg()[POSITION] == "left" then
        menu:SetPoint("BOTTOMLEFT", chat, "TOPLEFT", 0, GAP - offset)
    elseif cfg()[POSITION] == "side" then
        menu:SetPoint("BOTTOMLEFT", chat, "BOTTOMRIGHT", GAP - offset, 0)
    else
        menu:SetPoint("BOTTOMRIGHT", chat, "TOPRIGHT", 0, GAP - offset)
    end
end

local function createMenu(parent, name)
    local menu = CreateFrame("Frame", name, parent)
    menu:SetWidth(PANEL_WIDTH)
    Style.Shell(menu, { window = true })
    if DUI.Win and DUI.Win.Lines then DUI.Win.Lines(menu) end
    colorLine(menu)
    menu.rows = {}
    return menu
end

local function publicText(value)
    if not (issecretvalue and issecretvalue(value)) and type(value) == "string" and value ~= "" then return value end
end

local function hideHover(row)
    if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
end

local function showHover(row)
    local entry = row.entry
    if not (GameTooltip and entry) then return end
    local button = entry.button
    local title = publicText(button.tooltipText) or row.name:GetText()
    local description = publicText(button.newbieText)
    local disabled = not button:IsEnabled() and publicText(button.disabledTooltip)
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    if description and description ~= title then GameTooltip:AddLine(description, 0.88, 0.84, 0.76, true) end
    if disabled and disabled ~= description then GameTooltip:AddLine(disabled, 1, 0.45, 0.35, true) end
    GameTooltip:Show()
end

local function sizeMenu(menu)
    local corner = extras.ApplyChatPanelCorner and extras.ApplyChatPanelCorner(menu) or 0
    -- The last row normally has six UI units of clearance below it.
    menu:SetHeight(menu.baseHeight + math.max(0, corner - 6))
end

local function fillMenu(menu, entries, onPick)
    for i, entry in ipairs(entries) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -6 - (i - 1) * ROW_HEIGHT)
            row:SetPoint("RIGHT", menu, "RIGHT", -4, 0)
            row:SetHeight(ROW_HEIGHT)
            row.tint = row:CreateTexture(nil, "BACKGROUND")
            row.tint:SetAllPoints()
            row.mark = row:CreateTexture(nil, "ARTWORK")
            row.mark:SetPoint("TOPLEFT")
            row.mark:SetPoint("BOTTOMLEFT")
            row.mark:SetWidth(DUI.Pixel.Px(row, 1))
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(15, 15)
            row.icon:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.key = Style.Text(row, Style.SIZE.tiny, "RIGHT")
            row.key:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            Style.InkText(row.key, "LABEL")
            row.name = Style.Text(row, Style.SIZE.small, "LEFT")
            row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
            row.name:SetPoint("RIGHT", row.key, "LEFT", -6, 0)
            row.name:SetWordWrap(false)
            function row:Highlight(over)
                local r, g, b = Style.Accent()
                self.tint:SetColorTexture(r, g, b, over and 0.16 or 0)
                self.mark:SetColorTexture(r, g, b, over and 1 or 0)
            end
            row:SetScript("OnEnter", function(self) self:Highlight(true); showHover(self) end)
            row:SetScript("OnLeave", function(self) self:Highlight(false); hideHover(self) end)
            row:SetScript("OnHide", hideHover)
            row:SetScript("OnClick", function(self) if onPick then onPick(self.entry) end end)
            menu.rows[i] = row
        end
        row.entry = entry
        local spec = entry.spec
        local binding = publicText(entry.button.commandName) or publicText(entry.button.bindingAction) or spec[5]
        local key = type(binding) == "string" and GetBindingKey(binding)
        row.icon:SetTexture(DUI.MEDIA .. "ui-micro-" .. spec[2] .. ".png")
        row.name:SetText(GetLocale() == "deDE" and spec[4] or spec[3])
        row.key:SetText(key and GetBindingText(key, "KEY_") or "")
        row.key:SetWidth(math.max(1, row.key:GetStringWidth()))
        Style.InkText(row.name, entry.button:IsEnabled() and "VALUE" or "LABEL")
        row:EnableMouse(true)
        row:Highlight(false)
        row:Show()
    end
    for i = #entries + 1, #menu.rows do menu.rows[i]:Hide() end
    menu.baseHeight = 12 + #entries * ROW_HEIGHT
    sizeMenu(menu)
    colorLine(menu)
end

local function setOpen(want, instant)
    if not panel or (want and not (trigger and trigger:IsVisible() and enabled())) then return end
    opened = want
    if want then
        fillMenu(panel, collectEntries(), function(entry)
            if InCombatLockdown() then return end
            setOpen(false)
            activate(entry)
        end)
        panel:SetScale(trigger:GetEffectiveScale() / UIParent:GetEffectiveScale())
        panel:SetAlpha(progress)
        anchorMenu(panel, Chat.Panel(), progress)
        panel:Show()
    end
    panel:EnableMouse(want)
    for _, row in ipairs(panel.rows) do
        row:EnableMouse(want)
        if not want then hideHover(row) end
    end
    Motion.Tween(panel, progress, want and 1 or 0, instant and 0 or 0.13, function(value)
        if not panel:IsShown() then return end
        progress = value
        panel:SetAlpha(value)
        anchorMenu(panel, Chat.Panel(), value)
    end, function() if not opened then panel:Hide() end end)
end

local function buildMenu()
    if panel then return end
    panel = createMenu(UIParent, "DaylightBlastaChatMicroMenu")
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:Hide()
    panel:SetScript("OnHide", function() opened, progress = false, 0 end)
    if UISpecialFrames then table.insert(UISpecialFrames, panel:GetName()) end
    DUI.RegisterEvent("GLOBAL_MOUSE_DOWN", function()
        if opened and not panel:IsMouseOver() and not trigger:IsMouseOver() then setOpen(false) end
    end)
end

local function sample(parent)
    local host = CreateFrame("Frame", nil, parent)
    local inner = CreateFrame("Frame", nil, host)
    inner:SetPoint("BOTTOM", host)
    local chat = CreateFrame("Frame", nil, inner)
    Style.Shell(chat, { window = true })
    local tabs = Style.Text(chat, Style.SIZE.small, "LEFT")
    tabs:SetPoint("LEFT", chat, "LEFT", 10, 0)
    tabs:SetText("Chat")
    local dots = Style.Text(chat, Style.SIZE.small, "RIGHT")
    dots:SetPoint("RIGHT", chat, "RIGHT", -9, 0)
    dots:SetText("···")
    Style.InkText(dots, "pop")
    local menu = createMenu(inner)
    return { frame = host, Parts = function() return {} end, Refresh = function(width, room)
        fillMenu(menu, collectEntries())
        local side = cfg()[POSITION] == "side"
        local chatWidth = math.min(225, math.max(80, width - (side and PANEL_WIDTH + GAP or 0)))
        local y = side and 0 or 12
        local height = menu:GetHeight() + 40
        local scale = room and room > 0 and math.min(1, room / height) or 1
        inner:SetSize(width, height)
        inner:SetScale(scale)
        host:SetSize(width, height * scale)
        chat:ClearAllPoints()
        chat:SetSize(chatWidth, 22)
        chat:SetPoint("BOTTOMLEFT", inner, "BOTTOMLEFT", math.max(0, (width - chatWidth - (side and PANEL_WIDTH + GAP or 0)) / 2), y)
        anchorMenu(menu, chat, 1)
        return height * scale
    end }
end

local page = mod.options and mod.options.pages and mod.options.pages[1]
if page and page.groups then
    page.groups[#page.groups + 1] = { label = LABEL, blastaTab = LABEL, blastaSample = sample, items = {
        { type = "toggle", key = KEY, label = LABEL, desc = DESC, blastaSince = "1.9.4", disabled = function() return not canReplace end },
        { type = "dropdown", key = POSITION, label = POS_LABEL, blastaSince = "1.9.4",
            values = { right = "Above chat, right", left = "Above chat, left", side = "Beside chat, right" },
            order = { "right", "left", "side" } },
    } }
end

local function replacing() return canReplace and trigger ~= nil and enabled() and Box.On() == true end
local applyStock = Hide and Hide.Apply
if canReplace then
    local repark, fade = Hide.Repark, Hide.FadeFrame
    local overrides = setmetatable({}, { __mode = "k" })
    local function stockConfig(db)
        if not replacing() then return db end
        if not overrides[db] then overrides[db] = setmetatable({ microMenu = "hidden" }, { __index = db }) end
        return overrides[db]
    end
    function Hide.Apply(db) return applyStock(stockConfig(db)) end
    function Hide.Repark(db) return repark(stockConfig(db)) end
    function Hide.FadeFrame(db, key)
        if key == "microMenu" and replacing() then return nil end
        return fade(db, key)
    end
end

local wasReplacing
local function syncStock()
    if not applyStock or not bars.db then return end
    local on = replacing()
    if on == wasReplacing then return end
    wasReplacing = on
    DUI.AfterCombat(function() Hide.Apply(bars.db) end, "blasta:microMenu")
end

local function syncTrigger()
    if not pane then return end
    local order = pane.iconOrder
    local index
    for i, key in ipairs(order) do if key == SLOT then index = i; break end end
    if canReplace and enabled() then
        if not index then order[#order + 1] = SLOT end
        trigger:Show()
    else
        if index then table.remove(order, index) end
        trigger:Hide()
    end
    Box.Layout()
    syncStock()
end

hooksecurefunc(Box, "BuildActions", function(P)
    if P.panel ~= Chat.Panel() or not (P.actions and P.icons and P.iconOrder) then return end
    pane = P
    trigger = Widgets.IconButton(P.actions, "ui-micro-menu.png", extras.Translate("Micro menu"), function()
        buildMenu()
        setOpen(not opened)
    end)
    -- Three quiet dots distinguish this trigger from DaylightUI's chat menu.
    trigger.icon:Hide()
    local dots = Style.Text(trigger, Style.SIZE.small, "CENTER")
    dots:SetPoint("CENTER")
    dots:SetText("···")
    Style.InkText(dots, "LABEL")
    trigger:HookScript("OnEnter", function() Style.InkText(dots, "pop") end)
    trigger:HookScript("OnLeave", function() Style.InkText(dots, "LABEL") end)
    trigger:HookScript("OnHide", function() setOpen(false, true) end)
    P.icons[SLOT] = trigger
    if canReplace and enabled() then P.iconOrder[#P.iconOrder + 1] = SLOT else trigger:Hide() end
end)

DUI.On("SettingChanged", function(scope, key)
    if scope ~= mod.name then return end
    if key == KEY then syncTrigger() elseif key == POSITION and opened then anchorMenu(panel, Chat.Panel(), progress) end
    if key == "blastaPanelCorner" and panel and panel.baseHeight then sizeMenu(panel) end
    syncStock()
end)
hooksecurefunc(Box, "Apply", syncStock)
DUI.On("Login", syncStock)
DUI.On("StyleChanged", function() if panel then colorLine(panel) end end)
DUI.RegisterEvent("PLAYER_REGEN_DISABLED", function() setOpen(false, true) end)

extras.Loaded("ChatMicroMenu")
