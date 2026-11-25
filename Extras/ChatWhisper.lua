local ADDON, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Chat")
local mod = DUI:GetModule("Chat")
local Chat, Tiles = ns and ns.Chat, ns and ns.Tiles
local Style = DUI.Style
if not (Chat and Chat.Panel and Tiles and type(Tiles.Layout) == "function" and Tiles.Drawer and ns.Convo
    and mod and mod.defaults and mod.options and Style and Style.GetShell) then return end

local G = extras.German

-- A whisper conversation opened beside the chat slides out as part of the
-- chat: the chat's own frame grows over it, and the conversation (without a
-- frame or accent line of its own) comes out from behind the chat's edge,
-- the way DaylightUI's damage meter slides out of the minimap.

local TALK = "blastaDrawerTalk"   -- kept from the chat drawers, so the choice carries over
mod.defaults[TALK] = true

local function cfg() return mod.db or mod.defaults end
local function on() return cfg()[TALK] ~= false end

local function whisperSample(parent)
    local host = CreateFrame("Frame", nil, parent)
    local scene = CreateFrame("Frame", nil, host)
    scene:SetPoint("TOP", host, "TOP", 0, -5)
    local chat = CreateFrame("Frame", nil, scene)
    chat:SetFrameLevel(scene:GetFrameLevel() + 3)
    local shared = Style.Shell(chat, { window = true })
    local drawer = CreateFrame("Frame", nil, scene)
    drawer:SetClipsChildren(true)
    drawer:SetFrameLevel(chat:GetFrameLevel() + 1)
    local convo = CreateFrame("Frame", nil, drawer)
    local separate = Style.Shell(convo, { window = true })
    local function words(frame, size, text, x, y, ink)
        local fs = Style.Text(frame, size, "LEFT")
        fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        fs:SetText(text)
        Style.InkText(fs, ink)
        return fs
    end
    local german = GetLocale() == "deDE"
    words(chat, 12, german and "Allgemein   Gilde   Handel" or "General   Guild   Trade", 10, -9, "LABEL")
    local chatLine = words(chat, 12, german and "Mira flüstert: Kommst du mit?" or "Mira whispers: Coming along?", 10, -39, "pop")
    chatLine:SetPoint("RIGHT", chat, "RIGHT", -10, 0)
    local tile = CreateFrame("Frame", nil, chat)
    tile:SetSize(56, 20)
    Style.Shell(tile, { flat = true, borderPx = 1 })
    words(tile, 11, "Mira", 8, -4, "pop")
    words(convo, 14, "Mira", 10, -10, "TITLE")
    local message = words(convo, 12, german and "Kommst du mit?" or "Coming along?", 10, -40, "VALUE")
    message:SetPoint("RIGHT", convo, "RIGHT", -8, 0)
    local reply = CreateFrame("Frame", nil, convo)
    reply:SetPoint("BOTTOMLEFT", convo, "BOTTOMLEFT", 9, 9)
    reply:SetPoint("BOTTOMRIGHT", convo, "BOTTOMRIGHT", -9, 9)
    reply:SetHeight(23)
    Style.Shell(reply, { flat = true, borderPx = 1 })
    words(reply, 11, german and "Antworten …" or "Reply …", 6, -5, "LABEL")

    local available, progress, left, together = 0, 0, false, false
    local function slide(value)
        progress = value
        local shown = math.max(1, available * value)
        drawer:SetWidth(shown)
        local extending = together and shown or 0
        shared:ClearAllPoints()
        shared:SetPoint("TOPLEFT", chat, "TOPLEFT", left and -extending or 0, 0)
        shared:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", left and 0 or extending, 0)
        if Style.LayoutShell then Style.LayoutShell(shared) end
    end
    local motionKey = {}
    local function animate()
        if available <= 0 then return end
        DUI.Motion.Tween(motionKey, 0, 1, 0.25, slide)
    end
    host:SetScript("OnShow", animate)
    return { frame = host, Parts = function() return {} end, Refresh = function(width)
        local first = available == 0
        local w, height = math.min(width, 426), 116
        host:SetSize(width, height + 30)
        scene:SetSize(w, height)
        left = Tiles.Side and Tiles.Side() == "left"
        together = on()
        local chatW = math.floor(w * 0.54)
        available = math.max(1, w - chatW)
        chat:ClearAllPoints()
        chat:SetPoint(left and "RIGHT" or "LEFT", scene, left and "RIGHT" or "LEFT")
        chat:SetSize(chatW, height - 22)
        tile:ClearAllPoints()
        tile:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT", chat, left and "TOPLEFT" or "TOPRIGHT", 0, 2)
        drawer:ClearAllPoints()
        drawer:SetPoint(left and "TOPRIGHT" or "TOPLEFT", chat, left and "TOPLEFT" or "TOPRIGHT")
        drawer:SetHeight(height - 22)
        convo:ClearAllPoints()
        convo:SetPoint(left and "TOPLEFT" or "TOPRIGHT", drawer, left and "TOPLEFT" or "TOPRIGHT")
        convo:SetSize(available, height - 22)
        separate:SetShown(not together)
        if first then animate() else slide(progress) end
        return height + 30
    end }
end

-- Options: Blasta -> World & moments, its own tab (as every Blasta row from
-- the chat module lands there).
do
    local row = { type = "toggle", key = TALK, label = "Whisper conversation from the chat's edge", blastaSince = "1.9.4",
        desc = "A whisper conversation opened beside the chat slides out as part of it: the chat's frame grows over it and the conversation comes out from behind the chat's edge.",
        disabled = function(get) return get("whispersIn") == "chat" end }
    local page = mod.options.pages and mod.options.pages[1]
    if page and page.groups then
        table.insert(page.groups, { label = "Whisper conversation", blastaTab = "Whisper conversation", blastaSample = whisperSample, items = { row } })
    end
end
G["Whisper conversation"] = "Flüster-Gespräch"
G["Whisper conversation from the chat's edge"] = "Flüster-Gespräch aus dem Chat-Rand"
G["A whisper conversation opened beside the chat slides out as part of it: the chat's frame grows over it and the conversation comes out from behind the chat's edge."] =
    "Ein Flüster-Gespräch neben dem Chat fährt als Teil des Chats aus: Der Chat-Rahmen wächst darüber, und das Gespräch kommt hinter dem Chat-Rand hervor."

local JOIN = Tiles.JOIN or 2

-- The conversation's slide frame when it's open beside the chat, its side
-- and how far it reaches.
local function talkAt()
    local talk = Tiles.Drawer()
    if talk and talk:IsShown() and ns.Convo.At and ns.Convo.At() == "side" and (talk:GetWidth() or 0) > 1 then
        return talk, Tiles.Side and Tiles.Side() or "right", talk:GetWidth() + JOIN
    end
end

-- The chat's frame stretched over the open conversation; back on the chat
-- when it's closed (or the option is off).
local stretched
local function relayShell()
    local panel = Chat.Panel()
    local s = panel and Style.GetShell(panel)
    if not s then return end
    local talk, side, reach = talkAt()
    if not (on() and talk) then
        if not stretched then return end
        stretched = nil
        s:ClearAllPoints()
        s:SetAllPoints(panel)
    else
        stretched = true
        local l, r = side == "left" and reach or 0, side == "right" and reach or 0
        s:ClearAllPoints()
        s:SetPoint("TOPLEFT", panel, "TOPLEFT", -l, 0)
        s:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", r, 0)
    end
    if Style.LayoutShell then pcall(Style.LayoutShell, s) end
end

-- The conversation itself: no frame or accent line of its own beside the
-- chat, riding its slide's outer edge. Elsewhere (above the tiles, dragged
-- away) it keeps its own.
local function styleTalk()
    local card = ns.Convo.Card and ns.Convo.Card()
    if not card then return end
    local ours = on() and ns.Convo.At and ns.Convo.At() == "side"
    local s = Style.GetShell(card)
    if s then s:SetShown(not ours) end
    if card.top then card.top:SetShown(not ours) end
    local talk = Tiles.Drawer()
    if ours and talk and not (ns.Convo.moving or ns.Convo.sizing) then
        card:ClearAllPoints()
        if Tiles.Side and Tiles.Side() == "left" then card:SetPoint("TOPLEFT", talk, "TOPLEFT")
        else card:SetPoint("TOPRIGHT", talk, "TOPRIGHT") end
    end
end

-- Reuse DaylightUI's buttons so click actions, unread counts and pins still work.
local TILE_HEIGHT, TILE_GAP, TILE_LIFT = 22, 3, 2
local function layoutNames()
    if not (Tiles.Column and Tiles.Tiles and ns.Talk and ns.Talk.Get and ns.Thread and ns.Thread.Name) then return end
    local column, panel = Tiles.Column(), Chat.Panel()
    if not (column and panel) then return end
    local left = Tiles.Side and Tiles.Side() == "left"
    local corner = left and "BOTTOMLEFT" or "BOTTOMRIGHT"
    local limit = panel:GetWidth()
    local x, row, widest = 0, 0, 0
    for _, button in ipairs(Tiles.Tiles()) do
        local conversation = button.slotted and ns.Talk.Get(button.key)
        if conversation then
            local name = button.blastaName
            if not name then
                name = Style.Text(button, 11, "CENTER")
                name:SetPoint("CENTER", button)
                name:SetWordWrap(false)
                button.blastaName = name
            end
            local label = conversation.name
            if conversation.bn then
                local info = C_BattleNet and C_BattleNet.GetAccountInfoByID and C_BattleNet.GetAccountInfoByID(conversation.bn)
                local tag = info and info.battleTag
                if type(tag) == "string" and not (issecretvalue and issecretvalue(tag)) then
                    label = tag:match("^[^#]+")
                else
                    label = ns.Thread.Name(conversation)
                end
            end
            name:SetText(label)
            name:SetTextColor(Style.ClassTextColor(conversation.class))
            local width = name.GetUnboundedStringWidth and name:GetUnboundedStringWidth() or name:GetStringWidth()
            if (issecretvalue and issecretvalue(width)) or type(width) ~= "number" then width = 125 end
            width = math.max(46, math.ceil(width) + 36)
            if x > 0 and x + width > limit then x, row = 0, row + 1 end
            local rise = button.rise or 0
            local smooth = rise * rise * (3 - 2 * rise)
            local y = TILE_LIFT + row * (TILE_HEIGHT + TILE_GAP) - (1 - smooth) * (TILE_HEIGHT + TILE_LIFT + 2)
            button:SetSize(width, TILE_HEIGHT)
            button:ClearAllPoints()
            button:SetPoint(corner, column, corner, left and x or -x, y)
            button.letter:Hide()
            for _, slice in ipairs(button.slices) do slice:Hide() end
            if button.icon then button.icon:Hide() end
            name:Show()
            widest = math.max(widest, x + width)
            x = x + width + TILE_GAP
        elseif button.blastaName then
            button.blastaName:Hide()
        end
    end
    local height = TILE_LIFT + TILE_HEIGHT + row * (TILE_HEIGHT + TILE_GAP)
    column:SetSize(math.max(1, widest), height)
    return height + TILE_GAP
end

local namesLaidOut
if Tiles.AboveTiles then
    local aboveTiles = Tiles.AboveTiles
    function Tiles.AboveTiles()
        local height = layoutNames()
        namesLaidOut = height ~= nil
        return height or aboveTiles()
    end
end

local function apply()
    if not namesLaidOut then layoutNames() end
    namesLaidOut = nil
    pcall(styleTalk)
    pcall(relayShell)
end

-- DaylightUI lays the conversation out on every step of its slide.
local layout = Tiles.Layout
function Tiles.Layout(...)
    namesLaidOut = nil
    local a, b = layout(...)
    apply()
    return a, b
end

-- The chat drawers are gone: a damage meter they held goes back to where
-- DaylightUI had it.
local function giveMeterBack()
    if DUI:Get(ADDON, "chatDrawerMeterWas") == "attached" then
        DUI:Set(ADDON, "chatDrawerMeterWas", "")
        if DUI:GetModule("InfoPanel") then DUI:Set("InfoPanel", "meter.detached", false) end
    end
end

DUI.On("Login", function() pcall(giveMeterBack); apply() end)
if DUI.loggedIn then pcall(giveMeterBack); apply() end
DUI.On("SettingChanged", function(scope, path)
    if scope == mod.name and (path == TALK or path == "whisperSide" or path == "whispersIn") then apply() end
end)

extras.Loaded("ChatWhisper")
