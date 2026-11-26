local ADDON, extras = ...
local DUI = DaylightUI
local Book, Style = DUI.Book, DUI.Style
local Talents = Book and Book.Talents
if not (Talents and Talents.Layout and Talents.FillTree and Talents.PaintTile and Talents.DrawArc and Style) then return end

local key = "talentWorkbench"
local function enabled() return DUI:Get(ADDON, key) == true end
extras.German["Talent layout"] = "Talentansicht"
extras.German["Enable Blasta talent layout (test)"] = "Blasta-Talentansicht aktivieren (Test)"
extras.German["Talent trees on a shared Daylight background, with the point thresholds beside the rows. Disable to restore the previous view."] =
    "Talentbäume auf einem gemeinsamen Daylight-Hintergrund, mit den Punktschwellen neben den Reihen. Ausschalten stellt die bisherige Ansicht wieder her."
extras.TalentStyleGroup = { label = "Talent layout", items = {
    { type = "toggle", key = key, label = "Enable Blasta talent layout (test)", blastaSince = "2.3",
        desc = "Talent trees on a shared Daylight background, with the point thresholds beside the rows. Disable to restore the previous view." },
} }

-- Only the player's book layout opts in. Inspect/Legacy share these APIs.
local layingOut = false
local function paint(b)
    if not (b.box and b.box.blastaTalentStyle and b.node) then return end
    local state = Talents.StateOf(b.node)
    -- A talent that can't be picked yet (too few points in the tree, or its
    -- required talent missing) is gray; hovered, it shows its colors, a little
    -- dimmed. One you can pick stays in color.
    local locked = state == "locked"
    b.icon:SetDesaturated(locked and not b.over)
    local light
    if locked then light = b.over and .8 or .42
    else light = b.over and 1 or state == "avail" and .78 or 1 end
    b.icon:SetVertexColor(light, light, light, 1)
    b.badge:ClearAllPoints()
    b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, -5)
    b.badge:SetSize(26, 14)
    b.badge:Show()
end
hooksecurefunc(Talents, "PaintTile", paint)

-- A talent that becomes available fades from gray into its colors along with
-- DaylightUI's own wake (bump and warm flash), instead of switching at once.
-- A gray copy of the icon lies on top and fades out on DaylightUI's shared
-- tween driver: no frame of its own, nothing running once it's done. The copy
-- is made the first time a tile wakes. With motion off, nothing changes.
local Motion = DUI.Motion
local GRAY_LIGHT, FADE = .42, .45
if Motion and Motion.On and Motion.Tween and Talents.Wake then
    hooksecurefunc(Talents, "Wake", extras.SafeHook("TalentStyle.Wake", function(b, delay)
        if not (b and b.box and b.box.blastaTalentStyle and b.icon and Motion.On()) then return end
        local gray = b.blastaWakeGray
        if not gray then
            gray = b:CreateTexture(nil, "ARTWORK", nil, 1)
            gray:SetAllPoints(b.icon)
            gray:SetDesaturated(true)
            gray.key = {}
            b.blastaWakeGray = gray
        end
        gray:SetTexture(b.icon:GetTexture())
        gray:SetTexCoord(b.icon:GetTexCoord())
        gray:SetVertexColor(GRAY_LIGHT, GRAY_LIGHT, GRAY_LIGHT, 1)
        gray:SetAlpha(1)
        gray:Show()
        local function fade()
            Motion.Tween(gray.key, 1, 0, FADE, function(v) gray:SetAlpha(v) end, function() gray:Hide() end)
        end
        -- Gray at once (the tile is already painted in color), fading when
        -- DaylightUI's wake for this tile starts.
        if delay and delay > 0 then C_Timer.After(delay, fade) else fade() end
    end))
end

local fillTree = Talents.FillTree
function Talents.FillTree(box, t, pitch, size, data, px, ...)
    local active = layingOut and enabled()
    local was = box.blastaTalentStyle
    box.blastaTalentStyle = active
    if was and not active then
        for _, b in ipairs(box.tiles or {}) do
            b.ring:ClearAllPoints()
            b.ring:SetPoint("TOPLEFT", b, "TOPLEFT", -Talents.RING, Talents.RING)
            b.ring:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", Talents.RING, -Talents.RING)
            b.well:ClearAllPoints()
            b.well:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
            b.well:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
            b.badge:ClearAllPoints(); b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -6)
            b.badge:SetSize(24, 13)
        end
    end
    local a, b = fillTree(box, t, pitch, size, data, px, ...)
    box.bg:SetShown(not active); box.glow:SetShown(not active)
    if box.blastaTalentRule then box.blastaTalentRule:SetShown(active) end
    if not box.blastaHeaderIcon then
        local coords = { box.icon:GetTexCoord() }
        box.blastaHeaderIcon = { w = box.icon:GetWidth(), h = box.icon:GetHeight(), coords = coords }
    end
    local header = box.blastaHeaderIcon
    if active then
        box.icon:SetSize(20, 20)
        box.icon:SetTexCoord(.07, .93, .07, .93)
        if not box.blastaTalentRule then
            box.blastaTalentRule = box:CreateTexture(nil, "ARTWORK")
            box.blastaTalentRule:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        local rule = box.blastaTalentRule
        rule:ClearAllPoints()
        rule:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -32)
        rule:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -32)
        rule:SetHeight(1); rule:SetVertexColor(1, 1, 1, .55); rule:Show()
        box.name:ClearAllPoints()
        box.name:SetPoint("LEFT", box.icon, "RIGHT", 7, 0)
        box.name:SetPoint("RIGHT", box.pts, "LEFT", -8, 0)
        local title = Style.Upper and Style.Upper(t.name) or t.name
        local colors = DUI.Char and DUI.Char.Colors
        if colors and colors.Line then colors.Line(rule, .65) end
        if colors and colors.HeadText then colors.HeadText(box.name, "attributes", title)
        else box.name:SetText(title); Style.InkText(box.name, "LABEL") end
        box.icon:ClearAllPoints(); box.icon:SetPoint("LEFT", box, "TOPLEFT", 6, -16)
        box.pts:ClearAllPoints(); box.pts:SetPoint("RIGHT", box, "TOPRIGHT", -4, -16)
        -- The reserved left gutter cannot collide with the first talent column.
        box.grid:ClearAllPoints()
        box.grid:SetPoint("TOP", box, "TOP", 12, -Talents.HEAD)
    else
        box.icon:SetSize(header.w, header.h)
        if #header.coords > 0 then box.icon:SetTexCoord(unpack(header.coords)) end
        box.icon:ClearAllPoints(); box.icon:SetPoint("LEFT", box, "TOPLEFT", Talents.PAD + 2, -Talents.HEAD / 2)
        box.pts:ClearAllPoints(); box.pts:SetPoint("RIGHT", box, "TOPRIGHT", -Talents.PAD - 2, -Talents.HEAD / 2)
    end
    return a, b
end

-- The icons keep DaylightUI's own size: its sizing, worked out with its own
-- header and gaps. Only where Blasta's taller header and the threshold
-- gutter leave less room does the smaller fit win, so nothing runs out of
-- the window.
local GUTTER_ROOM = 24
local fit = Talents.Fit
local daylightHead, daylightGap
local function fitWith(head, gap, data, w, h)
    local ownHead, ownGap = Talents.HEAD, Talents.GAP
    Talents.HEAD, Talents.GAP = head, gap
    local ok, pitch, size, across = pcall(fit, data, w, h)
    Talents.HEAD, Talents.GAP = ownHead, ownGap
    if not ok then error(pitch, 0) end
    return pitch, size, across
end
function Talents.Fit(data, w, h)
    if not layingOut or not enabled() or not daylightHead then return fit(data, w, h) end
    local pitch, size, across = fitWith(daylightHead, daylightGap, data, w, h)
    local roomPitch, roomSize, roomAcross = fitWith(Talents.HEAD, Talents.GAP, data, w - GUTTER_ROOM, h)
    if type(roomPitch) == "number" and type(pitch) == "number" and roomPitch < pitch then
        return roomPitch, roomSize, roomAcross
    end
    return pitch, size, across
end
local layout = Talents.Layout
function Talents.Layout(page, data, ...)
    local previous, head, gap = layingOut, Talents.HEAD, Talents.GAP
    if not previous then daylightHead, daylightGap = head, gap end
    layingOut = true
    if enabled() then Talents.HEAD, Talents.GAP = 48, 18 end
    local ok, err = pcall(layout, page, data, ...)
    layingOut, Talents.HEAD, Talents.GAP = previous, head, gap
    if not ok then error(err, 0) end
end

DUI.On("SettingChanged", function(scope, setting)
    if scope == ADDON and setting == key then
        DUI.AfterCombat(function() if Talents.Soon then Talents.Soon() end end, "blastaTalentLayout")
    end
end)
extras.Loaded("TalentStyle")
