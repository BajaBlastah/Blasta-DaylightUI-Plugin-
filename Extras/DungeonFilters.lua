-- SPDX-License-Identifier: GPL-3.0-or-later
local ADDON, extras = ...
local DUI = DaylightUI
local lfg = DUI.Lfg
local browse, data = lfg and lfg.Browse, lfg and lfg.Data
local win, widgets, style = DUI.Win, DUI.Widgets, DUI.Style
if not (browse and browse.Render and browse.PaintChips and data and data.Places
    and data.Groups and data.ActivityName and data.PlaystyleWord and data.PLAYSTYLES
    and win and win.Header and win.Feel and win.Feel.Slide and win.Feel.Settle
    and widgets and widgets.Input and widgets.RoleText and widgets.OpenMenu and widgets.CloseMenu
    and style and style.Shell and DUI.Motion and DUI.Motion.AlphaTo) then return end

local T = extras.Translate
local setting = "dungeonFinder"
local function enabled()
    return DUI:Get(ADDON, setting) == true
end

extras.DungeonFinderGroup = { label = "Blasta Dungeon Finder", items = {
    { type = "toggle", key = setting, label = "Blasta Dungeon Finder", reload = true,
        desc = "Enable the docked dungeon filters in DaylightUI's group finder: several dungeons, open roles, who is already in the group, level ranges and one-click applying.",
        get = enabled, set = function(value) return DUI:Set(ADDON, setting, value) end,
        default = function() return false end },
} }

local nativePlaystyle = data.PlaystyleWord
function data.PlaystyleWord(id)
    local native = nativePlaystyle(id)
    if native and id == 4 and (GetLocale() == "deDE" or extras.Language == "deDE") then
        return "Mitziehen"
    end
    return native
end

-- ---------------------------------------------------------------------
-- Filters
-- ---------------------------------------------------------------------

local dungeonCategory = GROUP_FINDER_CATEGORY_ID_DUNGEONS or 2

-- An activity's suggested levels in DaylightUI's words and colors ("24-34"; dimmed
-- when it's below you, a warning when above), as text for a label or row.
local function hexOf(c)
    local function byte(v) return math.floor((tonumber(v) or 1) * 255 + 0.5) end
    return string.format("|cff%02x%02x%02x", byte(c[1]), byte(c[2]), byte(c[3]))
end
local function rangeText(info)
    if type(info) ~= "table" or not (data.Levels and data.LevelColor) then return "" end
    local ok, text = pcall(data.Levels, info)
    if not ok or type(text) ~= "string" or text == "" then return "" end
    local okc, c = pcall(data.LevelColor, info)
    if not okc or type(c) ~= "table" then return text end
    return hexOf(c) .. text .. "|r"
end

-- One range over all the activities a listing names: the lowest start, the highest end.
local function listingRange(acts)
    local lo, hi
    for _, id in ipairs(acts or {}) do
        local a = data.Activity and data.Activity(id)
        if type(a) == "table" then
            local l, h = a.minLevelSuggestion or 0, a.maxLevelSuggestion or 0
            if l > 0 and (not lo or l < lo) then lo = l end
            if h > 0 and (not hi or h > hi) then hi = h end
        end
    end
    if not (lo or hi) then return "" end
    return rangeText({ minLevelSuggestion = lo or 0, maxLevelSuggestion = hi or 0 })
end
local roles = { "TANK", "HEALER", "DAMAGER" }
local roleLabels = { TANK = "Tank", HEALER = "Healer", DAMAGER = "Damage" }
local roleKeys = { TANK = "tank", HEALER = "healer", DAMAGER = "dps" }
local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local selectedRoles = {}   -- open spot wanted: any of them
local presentRoles = {}    -- already in the group: all of them
local presentClasses = {}  -- already in the group: all of them
local dungeons = {}        -- picked dungeons (activity ids): any of them
local playstyle, drawer, activityButton, clickActivity
local opened, menuOpen, slideOffset = false, false, 0
-- Closed by hand: stays closed until Find a group is left and opened again.
local dismissed, autoPending = false, false
local width, gap, inset = 300, 8, 14

local function hasRoles() return next(selectedRoles) ~= nil end
local function hasDungeons() return next(dungeons) ~= nil end

-- A group listed for several dungeons counts if one of them is picked.
local function forDungeon(result)
    for _, id in ipairs(result.acts or {}) do
        if dungeons[id] then return true end
    end
    return false
end

-- "All dungeons", the one picked, or "Gnomeregan +2".
local function dungeonText()
    local first, count = nil, 0
    for id in pairs(dungeons) do
        count = count + 1
        local name = data.ActivityName(id)
        if not first or (name and name < first) then first = name end
    end
    if count == 0 then return T("All dungeons") end
    if count == 1 then return first or T("All dungeons") end
    return (first or "") .. "  +" .. (count - 1)
end
local function hasPresent() return next(presentRoles) ~= nil or next(presentClasses) ~= nil end

local function plain(v)
    if data.Plain then return data.Plain(v) end
    return v
end

-- Classes in a group: its members, else the client's class counts.
local function hasClass(result, token)
    for _, member in ipairs(result.members or {}) do
        if member.class == token then return true end
    end
    local counts = result.counts
    return type(counts) == "table" and (tonumber(plain(counts[token])) or 0) > 0
end

-- Groups need an open spot for one of the chosen roles and already have every
-- chosen role and class. Solo players only need to be able to fill a chosen role;
-- what a group already has doesn't apply to them.
local function matches(result)
    if hasDungeons() and not forDungeon(result) then return false end
    if playstyle and result.style ~= data.PlaystyleWord(playstyle) then return false end
    if result.solo then
        if not hasRoles() then return true end
        if result.delisted then return false end
        local can = result.roles or {}
        for role in pairs(selectedRoles) do
            if can[roleKeys[role]] then return true end
        end
        return false
    end
    if (hasRoles() or hasPresent()) and result.delisted then return false end
    local have, free = data.Places(result)
    if hasRoles() then
        local any = false
        for role in pairs(selectedRoles) do
            if (free[role] or 0) > 0 then any = true break end
        end
        if not any then return false end
    end
    for role in pairs(presentRoles) do
        if (have[role] or 0) <= 0 then return false end
    end
    for token in pairs(presentClasses) do
        if not hasClass(result, token) then return false end
    end
    return true
end

local function filterCount()
    return (hasDungeons() and 1 or 0) + (hasRoles() and 1 or 0) + (playstyle and 1 or 0) + (hasPresent() and 1 or 0)
end

local function refresh()
    browse.open = nil
    browse.Render()
end

local function closeMenu()
    if menuOpen then widgets.CloseMenu() end
    menuOpen = false
end

local function closeDrawer(immediate, manual)
    if manual then dismissed = true end
    if not drawer or not opened then return end
    opened = false
    closeMenu()
    drawer.search:ClearFocus()
    if immediate then
        DUI.Motion.AlphaTo(drawer, 0, 0, true)
        drawer:Hide()
        win.Feel.Settle(drawer)
    else
        win.Feel.Slide(drawer, slideOffset)
        DUI.Motion.AlphaTo(drawer, 0, DUI.Motion.NORMAL, true)
    end
    if activityButton then activityButton.SetActive(filterCount() > 0) end
end

local function placeDrawer(page)
    local host = page.win or page:GetParent()
    local rootScale, scale = UIParent:GetEffectiveScale(), host:GetEffectiveScale()
    local ratio = scale / rootScale
    local left = (host:GetLeft() or 0) * ratio
    local right = UIParent:GetWidth() - (host:GetRight() or 0) * ratio
    local needed = (width + gap) * ratio
    local dockRight = right >= needed or right >= left
    slideOffset = dockRight and -36 or 36
    drawer:ClearAllPoints()
    if right < needed and left < needed then
        local side = dockRight and "TOPRIGHT" or "TOPLEFT"
        drawer:SetPoint(side, host, side, dockRight and -gap or gap, 0)
    elseif dockRight then
        drawer:SetPoint("TOPLEFT", host, "TOPRIGHT", gap, 0)
    else
        drawer:SetPoint("TOPRIGHT", host, "TOPLEFT", -gap, 0)
    end
end

local dungeonMenu
local function dungeonMenuAt(owner, inView)
    local query = drawer.search:GetText():lower()
    local ids, labels = { 0 }, { [0] = T("All dungeons") }
    for _, group in ipairs(data.Groups(dungeonCategory)) do
        for _, activity in ipairs(group.acts) do
            if activity.name:lower():find(query, 1, true) and not labels[activity.id] then
                ids[#ids + 1] = activity.id
                local range = rangeText(activity.info)
                labels[activity.id] = range ~= "" and (activity.name .. "  " .. range) or activity.name
            end
        end
    end
    if #ids == 1 and query ~= "" then
        drawer.dungeon.text:SetText(T("No dungeons found"))
        return
    end
    drawer.search:ClearFocus()
    menuOpen = true
    -- A menu of switches: each click picks or drops a dungeon and it stays open.
    -- "All dungeons" drops them all.
    widgets.OpenMenu(owner, ids, labels, inView, function(id)
        if id == 0 then wipe(dungeons) else dungeons[id] = not dungeons[id] or nil end
        refresh()
        -- The list re-renders under the menu; if anything closed it on the way,
        -- open it again where it was, so several dungeons can be ticked in a row.
        C_Timer.After(0, function()
            if opened and widgets.menuOwner ~= owner then dungeonMenuAt(owner, id) end
        end)
    end, width - 2 * inset, {
        keepOpen = true,
        checked = function(id)
            if id == 0 then return not hasDungeons() end
            return dungeons[id] == true
        end,
    })
end
dungeonMenu = function(owner) return dungeonMenuAt(owner, nil) end

local function fullWidth(region, parent, y)
    region:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -y)
    region:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -y)
end

local function heading(parent, text, y)
    local label = style.Text(parent, style.SIZE.body, "LEFT")
    fullWidth(label, parent, y)
    label:SetText(T(text))
    style.InkText(label, "VALUE")
end

local function className(token)
    local names = LOCALIZED_CLASS_NAMES_MALE
    return (type(names) == "table" and names[token]) or (token:sub(1, 1) .. token:sub(2):lower())
end

-- A row of equal buttons, `columns` to a line. Returns the y under the last line.
local function grid(panel, keys, columns, y, label, onClick)
    local buttons = {}
    local w = (width - 2 * inset - (columns - 1) * 4) / columns
    for index, key in ipairs(keys) do
        local button = widgets.Button(panel, label(key), 24)
        button:SetWidth(w)
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", inset + ((index - 1) % columns) * (w + 4),
            -y - math.floor((index - 1) / columns) * 28)
        button:SetScript("OnClick", function() onClick(key) end)
        buttons[key] = button
    end
    return buttons, y + math.ceil(#keys / columns) * 28
end

local function roleLabel(role) return widgets.RoleText(role, 12) .. " " .. T(roleLabels[role]) end

local function buildDrawer(page)
    local panel = CreateFrame("Frame", nil, page)
    panel:SetSize(width, 350)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:Hide()
    style.Shell(panel, { window = "GroupFinder" })
    win.Header(panel, { compact = true, onClose = function() closeDrawer(nil, true) end })
    panel.title:SetText(T("Dungeon filters"))

    heading(panel, "Dungeons", 44)
    panel.search = widgets.Input(panel, { search = true, hint = T("Search dungeons"), onChange = function()
        closeMenu()
        if panel.dungeon then panel.dungeon.text:SetText(dungeonText()) end
        if panel.reset then panel.reset.SetOff(filterCount() == 0 and panel.search:GetText() == "") end
    end })
    fullWidth(panel.search, panel, 64)
    panel.dungeon = widgets.Button(panel, "", 24)
    fullWidth(panel.dungeon, panel, 95)
    panel.dungeon:SetScript("OnClick", dungeonMenu)
    panel.search:HookScript("OnEnterPressed", function() dungeonMenu(panel.dungeon) end)

    local y = 132
    heading(panel, "Open roles", y)
    panel.roles, y = grid(panel, roles, 3, y + 20, roleLabel, function(role)
        selectedRoles[role] = not selectedRoles[role] or nil
        refresh()
    end)

    y = y + 9
    heading(panel, "Already in the group", y)
    panel.present, y = grid(panel, roles, 3, y + 20, roleLabel, function(role)
        presentRoles[role] = not presentRoles[role] or nil
        refresh()
    end)
    panel.classes, y = grid(panel, classes, 3, y, function(token)
        return win.Parts.Hex({ style.ClassTextColor(token) }) .. className(token) .. "|r"
    end, function(token)
        presentClasses[token] = not presentClasses[token] or nil
        refresh()
    end)

    y = y + 9
    heading(panel, "Playstyle", y)
    panel.styles, y = grid(panel, data.PLAYSTYLES, 2, y + 20, data.PlaystyleWord, function(id)
        playstyle = playstyle ~= id and id or nil
        refresh()
    end)

    y = y + 12
    local reset = widgets.Button(panel, T("Reset filters"), 24)
    fullWidth(reset, panel, y)
    reset:SetScript("OnClick", function()
        playstyle = nil
        wipe(dungeons)
        wipe(selectedRoles)
        wipe(presentRoles)
        wipe(presentClasses)
        panel.search:SetText("")
        refresh()
    end)
    panel.reset = reset
    panel.count = style.Text(panel, style.SIZE.body, "CENTER")
    fullWidth(panel.count, panel, y + 44)
    style.InkText(panel.count, "LABEL")
    panel:SetHeight(y + 73)
    page:HookScript("OnHide", function() closeDrawer(true) end)
    return panel
end

local function paintDrawer()
    if not drawer then return end
    drawer.dungeon.text:SetText(dungeonText())
    for role, button in pairs(drawer.roles) do button.SetActive(selectedRoles[role] == true) end
    for role, button in pairs(drawer.present) do button.SetActive(presentRoles[role] == true) end
    for token, button in pairs(drawer.classes) do button.SetActive(presentClasses[token] == true) end
    for id, button in pairs(drawer.styles) do button.SetActive(playstyle == id) end
    drawer.reset.SetOff(filterCount() == 0 and drawer.search:GetText() == "")
end

local function toggleDrawer(page)
    if opened then return closeDrawer(nil, true) end
    drawer = drawer or buildDrawer(page)
    win.Feel.Settle(drawer)
    drawer:Hide()
    placeDrawer(page)
    win.Feel.Slide(drawer, slideOffset)
    drawer:SetAlpha(0)
    drawer:Show()
    opened = true
    win.Feel.Slide(drawer, 0)
    DUI.Motion.AlphaTo(drawer, 1, DUI.Motion.NORMAL)
    browse.Render(page, true)
end

hooksecurefunc(browse, "PaintChips", function(page)
    if not enabled() then return closeDrawer(true) end
    page = page or browse.page
    if not page or not page.act then return end
    if activityButton ~= page.act then
        activityButton = page.act
        clickActivity = activityButton:GetScript("OnClick")
        activityButton:SetScript("OnClick", function(self, ...)
            if enabled() and browse.cat == dungeonCategory then toggleDrawer(page)
            elseif clickActivity then clickActivity(self, ...) end
        end)
    end
    if not page.blastaAutoHook then
        page.blastaAutoHook = true
        page:HookScript("OnHide", function() dismissed = false end)
    end
    if browse.cat ~= dungeonCategory then return closeDrawer(true) end
    -- Opens with Find a group (and on going back to Dungeons), unless closed by hand.
    if not opened and not dismissed and not autoPending and page:IsVisible() then
        autoPending = true
        C_Timer.After(0, function()
            autoPending = false
            if not opened and not dismissed and enabled() and browse.cat == dungeonCategory and page:IsVisible() then
                toggleDrawer(page)
            end
        end)
    end
    local count = filterCount()
    activityButton.text:SetText(count == 0 and T("Filters") or T("Filters") .. " (" .. count .. ")")
    activityButton.FitWidth(86)
    activityButton.SetActive(opened or count > 0)
    paintDrawer()
end)

-- Groups and solo players side by side: DaylightUI does that itself now
-- (Browse.SPLIT_W, the window's resize grip). Blasta only filters the list.
local render = browse.Render
local function draw(page, ...) return render(page, ...) end

function browse.Render(page, ...)
    if not enabled() then return render(page, ...) end
    page = page or browse.page
    if not page then return render(page, ...) end
    local active = browse.cat == dungeonCategory and filterCount() > 0
    -- Each listing's activity with its level range, once per search result.
    for _, result in ipairs(browse.results or {}) do
        if type(result) == "table" and not result.blastaBase and type(result.text) == "string" then
            result.blastaBase = result.text
            local range = listingRange(result.acts)
            if range ~= "" then result.text = result.text .. "  " .. range end
        end
    end
    local original = browse.results
    local filtered, groups, players = {}, 0, 0
    if not browse.searching then
        for _, result in ipairs(original or {}) do
            if not active or matches(result) then
                if active then filtered[#filtered + 1] = result end
                if not result.mine then
                    if result.solo then players = players + 1 else groups = groups + 1 end
                end
            end
        end
    end
    if active then browse.results = filtered end
    local ok, err = pcall(draw, page, ...)
    if active and browse.results == filtered then browse.results = original end
    if not ok then error(err, 0) end
    if drawer then
        drawer.count:SetText(browse.searching and DUI.L["Searching..."]
            or T("%d groups found"):format(groups) .. "  ·  " .. T("%d players"):format(players))
    end
    if active and #filtered == 0 and not browse.searching and not browse.failed and browse.searched then
        page.note:SetText(T("No groups match these filters"))
        page.note:Show()
    end
end

-- ---------------------------------------------------------------------
-- One-click application: a "Apply" button on a group's card whispers its
-- leader a short note (level, class, roles, dungeon). Shift-click opens the
-- whisper with the note in it to change first. /blasta apply <text> sets your
-- own note; {level} {class} {roles} {dungeon} are filled in.
-- ---------------------------------------------------------------------

local german = GetLocale() == "deDE" or extras.Language == "deDE"
local DEFAULT_NOTE = german and "Hallo! Stufe {level} {class} ({roles}) – darf ich bei {dungeon} mit?"
    or "Hi! Level {level} {class} ({roles}) – can I join you for {dungeon}?"
local ROLE_WORDS = german and { tank = "Tank", healer = "Heiler", dps = "DD" }
    or { tank = "Tank", healer = "Healer", dps = "DPS" }
local applied = {}   -- listing id -> true, this session

local function note()
    local own = DUI:Get(ADDON, "applyText")
    return (type(own) == "string" and own ~= "") and own or DEFAULT_NOTE
end

local function noteFor(r)
    local level = UnitLevel and UnitLevel("player")
    local class = UnitClass and UnitClass("player")
    local roles = {}
    local mine = data.Roles and data.Roles() or {}
    for _, key in ipairs({ "tank", "healer", "dps" }) do
        if mine[key] then roles[#roles + 1] = ROLE_WORDS[key] end
    end
    -- The picked dungeons the group goes to, else everything it's listed for.
    local names = {}
    for _, id in ipairs(r.acts or {}) do
        if dungeons[id] then names[#names + 1] = data.ActivityName(id) end
    end
    local dungeon = #names > 0 and table.concat(names, ", ") or (r.blastaBase or r.text or "")
    dungeon = dungeon:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local text = note()
    text = text:gsub("{level}", tostring(type(level) == "number" and level or ""))
    text = text:gsub("{class}", tostring(class or ""))
    text = text:gsub("{dungeon}", (dungeon:gsub("%%", "%%%%")))
    if #roles > 0 then
        text = text:gsub("{roles}", table.concat(roles, "/"))
    else
        text = text:gsub("%s*%({roles}%)", ""):gsub("{roles}", "")
    end
    return text
end

local function apply(r)
    local name = r and r.leader and r.leader.name
    if type(name) ~= "string" or name == "" then return end
    local text = noteFor(r)
    if IsShiftKeyDown and IsShiftKeyDown() then
        if ChatFrame_OpenChat then ChatFrame_OpenChat("/w " .. name .. " " .. text) end
        return
    end
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(text, "WHISPER", nil, name)
    elseif SendChatMessage then
        SendChatMessage(text, "WHISPER", nil, name)
    else
        return
    end
    applied[r.id] = true
    if browse.PaintDetail then browse.PaintDetail() end
end

if type(browse.Spec) == "function" then
    local spec = browse.Spec
    function browse.Spec(r)
        local out = spec(r)
        if not (enabled() and type(out) == "table" and type(out.buttons) == "table" and type(r) == "table") then return out end
        if r.mine or r.solo or type(r.leader) ~= "table" or type(r.leader.name) ~= "string" then return out end
        -- Whisper stays as it is (a blank whisper); Apply comes first. A listing
        -- that's gone shows Apply greyed out.
        for _, b in ipairs(out.buttons) do b.primary = false end
        local done = applied[r.id] == true
        table.insert(out.buttons, 1, { text = done and T("Applied") or T("Apply"), primary = true,
            off = done or r.delisted == true, onClick = function() apply(r) end })
        return out
    end
end

extras.SlashHandlers = extras.SlashHandlers or {}
table.insert(extras.SlashHandlers, function(msg)
    local word, rest = msg:match("^%s*(%S+)%s*(.-)%s*$")
    word = word and word:lower()
    if word ~= "apply" and word ~= "bewerbung" then return false end
    local say = DUI.Print or print
    if rest == "" then
        say(T("Your application note:") .. " " .. note())
        say(T("Change it with /blasta apply <text>; {level} {class} {roles} {dungeon} are filled in. /blasta apply reset brings back the default."))
    elseif rest:lower() == "reset" then
        DUI:Set(ADDON, "applyText", nil)
        say(T("Your application note:") .. " " .. note())
    else
        DUI:Set(ADDON, "applyText", rest)
        say(T("Your application note:") .. " " .. note())
    end
    return true
end)

-- ---------------------------------------------------------------------
-- The group card beside the list: DaylightUI gives it a faint white wash
-- (Social's Detail.FILL), so it reads lighter than the rest of the window.
-- Here it's see-through like the list, parted from it by a thin rule.
-- ---------------------------------------------------------------------

local function plainCard()
    local page = browse.page
    local card = page and page.detail
    local f = card and card.frame
    if type(f) ~= "table" or f.blastaPlain then return end
    f.blastaPlain = true
    if f.fill and f.fill.SetAlpha then f.fill:SetAlpha(0) end
    local rule = f:CreateTexture(nil, "BORDER")
    rule:SetWidth(DUI.Pixel and DUI.Pixel.Px and DUI.Pixel.Px(f, 1) or 1)
    rule:SetPoint("TOPRIGHT", f, "TOPLEFT", -6, 0)
    rule:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -6, 0)
    local c = style.INK.LABEL
    rule:SetColorTexture(c[1], c[2], c[3], 0.2)
end

if type(browse.PaintDetail) == "function" then hooksecurefunc(browse, "PaintDetail", plainCard) end

extras.Loaded("DungeonFilters")
