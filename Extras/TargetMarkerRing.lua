-- SPDX-License-Identifier: GPL-3.0-or-later
-- Blasta raid marker ring on the target frame's portrait.
-- A small arrow sits on the portrait's lower edge. Clicking it opens a dark
-- ring around the portrait with DaylightUI's eight raid markers; a click on one
-- marks your target and closes the ring, the chip beside the arrow takes the
-- marker off. The buttons are secure and use the game's own /tm, as
-- DaylightUI's leader drawer does, so marking works in a fight too: the arrow
-- opens and closes the ring from a secure snippet then. Out of combat the ring
-- also closes on a new target or a click elsewhere.
-- Positions and sizes are set out of combat only (the buttons are protected).
-- No Lua runs while the ring is closed, and nothing reads the target's marker
-- (its index is a secret on this client).
local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("UnitFrames")
local UF = ns and ns.UF
local mod = DUI:GetModule("UnitFrames")
local Style, Motion, Pixel = DUI.Style, DUI.Motion, DUI.Pixel
local ANCHOR = "target.portrait"
if not (UF and UF.LayoutPortrait and ns.frames and mod and mod.defaults.target and Style and Style.Accent
    and Motion and Motion.Tween and Pixel and SecureHandlerWrapScript and extras.FindSetting(mod, ANCHOR)) then return end

local KEY = "target.blastaMarkerRing"
mod.defaults.target.blastaMarkerRing = false
extras.AddSetting(mod, ANCHOR, {
    type = "toggle", key = KEY, label = "Raid marker ring", blastaSince = "2.4",
    desc = "A small arrow on the target's portrait opens a ring with the eight raid markers. Click one to mark your target; the chip beside the arrow takes the marker off. Works in combat too.",
    disabled = function(get) return get(ANCHOR) == "none" end,
})
local OPEN, ARROW_KEY = "target.blastaMarkerOpen", "target.blastaMarkerArrowAt"
mod.defaults.target.blastaMarkerOpen = "click"
mod.defaults.target.blastaMarkerArrowAt = 135
local function ringOff(get) return get(KEY) ~= true or get(ANCHOR) == "none" end
extras.AddSetting(mod, KEY, {
    type = "dropdown", key = OPEN, label = "Open the marker ring", blastaSince = "2.4",
    values = { click = "On click", hover = "On hover" }, order = { "click", "hover" },
    desc = "On click opens the ring when you click the arrow. On hover opens it as soon as the mouse is on the arrow, for marking quickly; it closes again when the mouse leaves the ring.",
    disabled = ringOff,
})
extras.AddSetting(mod, OPEN, {
    type = "slider", key = ARROW_KEY, label = "Marker arrow position", blastaSince = "2.4",
    min = 0, max = 355, step = 5, unit = "°",
    desc = "Where the arrow sits on the portrait's rim, in degrees clockwise from the top: 90 is the right side, 180 the bottom. The chip that takes the marker off sits outside the ring on the same line.",
    disabled = ringOff,
})

local MEDIA = DUI.MEDIA
-- Skull first and clockwise from the top left, like the game's own order.
local ORDER = { 8, 1, 2, 3, 4, 5, 6, 7 }
local FIRST, STEP = 112.5, -45   -- degrees: skull's place, then one step per marker
local OUTER = 1.8                -- the ring's outer edge, in portrait radii
local ICON, ICON_MIN = 0.5, 14  -- a marker, in portrait radii and at least this many px
local ARROW, ARROW_MIN = 0.36, 13
local EDGE_PX = 2                -- the ring's outer edge, in screen pixels
local RING_OUTER = UF.RING_OUTER or 0.6   -- the band's outer edge in its image, in half widths
local GLOW = 2.2                 -- the hover light, in marker sizes
-- A marker's click closes the ring once it's done: the pre-body passes a
-- message on the release only (the action runs on press or release, as the
-- game's key-down setting says), and the post-body hides the ring.
local CLOSE_PRE = 'if not down then return nil, "close" end'
local CLOSE_POST = "owner:Hide()"

local function cfg() return mod.db and mod.db.target or mod.defaults.target end
local function on() return cfg().blastaMarkerRing == true end
-- The arrow's place: degrees clockwise from the top, turned into the math angle.
local function arrowAngle()
    local v = tonumber(cfg().blastaMarkerArrowAt) or 135
    return 90 - v
end
local function target() return ns.frames and ns.frames.target end

-- In a raid only the leader and assistants may mark; anyone may in a party.
local function mayMark()
    if not (IsInRaid and IsInRaid()) then return true end
    local lead = UnitIsGroupLeader and UnitIsGroupLeader("player")
    local assist = UnitIsGroupAssistant and UnitIsGroupAssistant("player")
    return lead == true or assist == true
end

local function polar(radius, degrees)
    local a = math.rad(degrees)
    return radius * math.cos(a), radius * math.sin(a)
end

-- Round or square: a square portrait (DaylightUI's Square and Angled) gets a
-- square ring, its markers on the corners and the middles of the sides, and
-- square chips in the portrait's square frame.
local SQUARE = UF.SQUARE or 0.886   -- a square's half-side, as a share of the ring's radius
local SQUARE_FIRST = 135            -- the skull on the top left corner, then one step per marker
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = MEDIA .. "shape-circle.png"
local function isSquare(shape) return shape == "square" or shape == "angled" end
-- A point at this distance and angle, out on a square's edge for a square:
-- distance is then the square's half-side.
local function spot(square, distance, degrees)
    local x, y = polar(1, degrees)
    if square then
        local k = distance / math.max(math.abs(x), math.abs(y))
        return x * k, y * k
    end
    return x * distance, y * distance
end
local function markAngle(square, i) return (square and SQUARE_FIRST or FIRST) + STEP * (i - 1) end

local ring, under, over, arrow, clear, clearArt, glow
local chipFrom, chipTo, chipAt = 0, 0, 0   -- the clear chip runs from the arrow out to its place
local marks = {}       -- { button, icon, angle }
local radius, middle = 0, 0   -- the portrait's radius and the markers' circle, in the frame's units
local outerR, edge = 0, 0     -- the ring's outer edge and its line's width
local square = false          -- the target's portrait is square (its ring and chips too)
local iconSize = 0
local shown = 0               -- how far open the ring's art is, 0 .. 1
local OPEN_TIME, CLOSE_TIME = 0.16, 0.12

local function showTip(self)
    if not self.tipTitle then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.tipTitle, 1, 1, 1)
    if self.tipHint then GameTooltip:AddLine(self.tipHint, 0.8, 0.8, 0.8, true) end
    GameTooltip:Show()
end
local function hideTip() GameTooltip:Hide() end

local function light(icon)
    if not icon then glow:Hide() return end
    local size = icon:GetWidth() * GLOW
    glow:SetSize(size, size)
    glow:ClearAllPoints()
    glow:SetPoint("CENTER", icon, "CENTER")
    glow:Show()
end

-- The ring grows out of the portrait's rim and the markers ride out with it;
-- closing runs it back. k: 0 closed .. 1 open. Only the art moves (plain
-- frames), so it runs in a fight too; the secure buttons stay where they are.
local function placeArt(k)
    shown = k
    local o = radius + (outerR - radius) * k
    ring.rim:SetSize(2 * o, 2 * o)
    local inner = math.max(0, 2 * (o - edge))
    ring.disc:SetSize(inner, inner)
    local alpha = math.min(1, k * 1.6)
    under:SetAlpha(alpha)
    over:SetAlpha(alpha)
    -- The clear chip rolls out of the arrow along the same line, growing.
    if clearArt then
        local scale = 0.6 + 0.4 * k
        local x, y = spot(square, chipFrom + (chipTo - chipFrom) * k, chipAt)
        clearArt:SetAlpha(alpha)
        clearArt:SetScale(scale)
        clearArt:ClearAllPoints()
        clearArt:SetPoint("CENTER", ring, "CENTER", x / scale, y / scale)
    end
    -- Blasta's Shadow Word: Death marker on the health bar would show through.
    if extras.TargetDeathMarkerAlpha then extras.TargetDeathMarkerAlpha(1 - alpha) end
    local r = radius + (middle - radius) * k
    for i, m in ipairs(marks) do
        local x, y = spot(square, r, markAngle(square, i))
        m.icon:ClearAllPoints()
        m.icon:SetPoint("CENTER", ring, "CENTER", x, y)
        local size = iconSize * (0.6 + 0.4 * k)
        m.icon:SetSize(size, size)
    end
end

-- A chip dressed like a small portrait: a black opening inside the portrait's
-- own band, in the band's width and colors (UF.PaintRing).
-- art: a plain frame to draw it on instead of the button, so it can move
-- with the ring's animation while the secure button stays put.
local function chip(parent, file, art)
    local b = CreateFrame("Button", nil, parent, file)
    local on = art or b
    b.back = on:CreateTexture(nil, "BACKGROUND")
    b.back:SetTexture(MEDIA .. "shape-circle.png")
    b.back:SetPoint("CENTER", on, "CENTER")
    b.back:SetVertexColor(0, 0, 0, 1)
    b.rim = on:CreateTexture(nil, "BORDER")
    b.rim:SetTexture(UF.RING_FILE or (MEDIA .. "portrait-band.png"))
    b.rim:SetPoint("CENTER", on, "CENTER")
    b.icon = on:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("CENTER", on, "CENTER")
    b:SetScript("OnEnter", showTip)
    b:SetScript("OnLeave", hideTip)
    return b
end

-- The portrait band's colors, worked out the way DaylightUI paints its ring:
-- a pair for a gradient, one color for the lit band, or neither (plain gray).
local function bandColors(f)
    local mode = f.ringColor
    local Grad = DUI.Gradients
    if mode == "dark" and Style.BAND and Style.BAND_LIT then
        local b, l = Style.BAND, Style.BAND_LIT
        return CreateColor(b[1], b[2], b[3], 1), CreateColor(l[1], l[2], l[3], 1)
    elseif mode == "class" and Grad then
        if Grad.HiddenClassColor then
            local r, g, b = Grad.HiddenClassColor(f.unitToken)
            if type(r) ~= "nil" then return nil, nil, r, g, b end
        end
        if Grad.Colors and Grad.KeyFor then return Grad.Colors(Grad.KeyFor(f.unitToken)) end
    elseif mode == "accent" then
        local a, b = Style.AccentPair()
        if a then return CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1) end
        return nil, nil, Style.Accent()
    elseif mode == "daylight" and Style.GRADIENT_SHAPE then
        local a, b = Style.GRADIENT_SHAPE[1], Style.GRADIENT_SHAPE[2]
        return CreateColor(a[1], a[2], a[3], 1), CreateColor(b[1], b[2], b[3], 1)
    end
end

local function paintBand(f)
    if not arrow then return end
    local file, lit = UF.RING_FILE, UF.RING_LIT_FILE
    if UF.RingFiles then file, lit = UF.RingFiles(cfg().portraitRingWidth, cfg().portraitRingLine, square and "square" or nil) end
    local lo, hi, r, g, b = bandColors(f)
    local gray = UF.RING_COLOR or { 0.34, 0.34, 0.36 }
    for _, c in ipairs({ arrow, clear }) do
        if type(r) ~= "nil" then
            c.rim:SetTexture(lit)
            c.rim:SetVertexColor(r, g, b, 1)
        elseif lo then
            c.rim:SetTexture(file)
            c.rim:SetVertexColor(1, 1, 1, 1)
            c.rim:SetGradient("VERTICAL", lo, hi)
        else
            c.rim:SetTexture(file)
            c.rim:SetVertexColor(gray[1], gray[2], gray[3], 1)
        end
    end
    -- The ring's thin edge: a plain circle in the band's colors, without the
    -- band's black outline. The band image is a little darker than its tint
    -- (its face is about 84 %, the lit one's 65 %); a black veil over the
    -- circle matches that, since a hidden class's secret color can't be
    -- multiplied.
    local edgeTex = ring.rim
    if type(r) ~= "nil" then
        edgeTex:SetVertexColor(r, g, b, 1)
        ring.veil:SetAlpha(0.35)
    elseif lo then
        edgeTex:SetVertexColor(1, 1, 1, 1)
        edgeTex:SetGradient("VERTICAL", lo, hi)
        ring.veil:SetAlpha(0.16)
    else
        edgeTex:SetVertexColor(gray[1], gray[2], gray[3], 1)
        ring.veil:SetAlpha(0.16)
    end
end

local function paint()
    local r, g, b = Style.Accent()
    glow:SetVertexColor(r, g, b, 0.55)
    local ink = Style.INK and Style.INK.LABEL
    if type(ink) == "table" then arrow.icon:SetVertexColor(ink[1], ink[2], ink[3], 1) end
end

local function build(f)
    ring = CreateFrame("Frame", nil, f, "SecureHandlerBaseTemplate")
    ring:Hide()
    -- The art lies below the portrait (the dark disc and its line) and above it
    -- (the markers). Plain frames beside the ring, not in it: a child can't
    -- sit below its parent's level. They come and go with the ring.
    under = CreateFrame("Frame", nil, f)
    under:SetAllPoints(ring)
    under:Hide()
    over = CreateFrame("Frame", nil, f)
    over:SetAllPoints(ring)
    over:Hide()
    -- The edge: a circle in the portrait band's colors; the dark disc over it
    -- leaves a thin line.
    ring.rim = under:CreateTexture(nil, "BACKGROUND", nil, -3)
    ring.rim:SetTexture(MEDIA .. "shape-circle.png")
    ring.rim:SetPoint("CENTER", ring, "CENTER")
    ring.veil = under:CreateTexture(nil, "BACKGROUND", nil, -2)
    ring.veil:SetTexture(MEDIA .. "shape-circle.png")
    ring.veil:SetVertexColor(0, 0, 0, 1)
    ring.veil:SetAllPoints(ring.rim)
    ring.disc = under:CreateTexture(nil, "BACKGROUND", nil, 0)
    ring.disc:SetTexture(MEDIA .. "shape-circle.png")
    ring.disc:SetPoint("CENTER", ring, "CENTER")
    local bg = Style.BACKGROUND
    ring.disc:SetVertexColor(bg[1], bg[2], bg[3], 1)
    glow = over:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "glow.png")
    glow:SetBlendMode("ADD")
    glow:Hide()
    for i, n in ipairs(ORDER) do
        local b = CreateFrame("Button", nil, ring, "SecureActionButtonTemplate")
        b:RegisterForClicks("AnyUp", "AnyDown")
        b:SetAttribute("type", "macro")
        b:SetAttribute("macrotext", "/tm " .. n)
        SecureHandlerWrapScript(b, "OnClick", ring, CLOSE_PRE, CLOSE_POST)
        local icon = over:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(string.format(MEDIA .. "marker-%d.png", n))
        -- No tooltip: the marker under the mouse lights up instead.
        b:SetScript("OnEnter", function() light(icon) end)
        b:SetScript("OnLeave", function() light(nil) end)
        b:HookScript("OnMouseDown", function() Motion.Bump(icon, 0.85) end)
        marks[i] = { button = b, icon = icon, angle = FIRST + STEP * (i - 1) }
    end

    clearArt = CreateFrame("Frame", nil, f)
    clearArt:Hide()
    clear = chip(ring, "SecureActionButtonTemplate", clearArt)
    clear:RegisterForClicks("AnyUp", "AnyDown")
    clear:SetAttribute("type", "macro")
    clear:SetAttribute("macrotext", "/tm 0")
    SecureHandlerWrapScript(clear, "OnClick", ring, CLOSE_PRE, CLOSE_POST)
    clear.icon:SetTexture(MEDIA .. "marker-clear.png")
    clear:SetScript("OnEnter", function() light(clear.icon) end)
    clear:SetScript("OnLeave", function() light(nil) end)

    arrow = chip(f, "SecureHandlerClickTemplate")
    arrow:RegisterForClicks("AnyUp")
    arrow:SetFrameRef("ring", ring)
    arrow:SetFrameRef("clear", clear)
    arrow:SetAttribute("_onclick", [[
        local r = self:GetFrameRef("ring")
        if r:IsShown() then r:Hide() else r:Show() end
    ]])
    -- On hover: the mouse on the arrow opens the ring, and the ring closes
    -- itself a moment after the mouse leaves it (the game's secure auto-hide,
    -- as its flyouts use), so it works in a fight too.
    SecureHandlerWrapScript(arrow, "OnEnter", arrow, [[
        if self:GetAttribute("blastaHover") then
            local r = self:GetFrameRef("ring")
            r:Show()
            r:RegisterAutoHide(0.4)
            r:AddToAutoHide(self)
            r:AddToAutoHide(self:GetFrameRef("clear"))
        end
    ]])
    arrow.icon:SetTexture(MEDIA .. "ui-chevron.png")
    arrow.tipTitle = extras.Translate("Raid markers")
    arrow.tipHint = extras.Translate("Click: open or close the marker ring")
    arrow:Hide()

    ring:HookScript("OnShow", function()
        under:Show()
        over:Show()
        clearArt:Show()
        Motion.Tween(ring, shown, 1, OPEN_TIME, placeArt)
        Motion.Tween(arrow.icon, arrow.turn or 0, math.pi, OPEN_TIME, function(a)
            arrow.turn = a
            arrow.icon:SetRotation(a)
        end)
    end)
    ring:HookScript("OnHide", function()
        light(nil)
        -- The buttons are gone at once (secure); the art runs back in.
        Motion.Tween(ring, shown, 0, CLOSE_TIME, placeArt, function()
            if not ring:IsShown() then
                under:Hide()
                over:Hide()
                clearArt:Hide()
            end
        end)
        Motion.Tween(arrow.icon, arrow.turn or math.pi, 0, CLOSE_TIME, function(a)
            arrow.turn = a
            arrow.icon:SetRotation(a)
        end)
    end)
    paint()
end

-- Where the portrait sits: the frame point DaylightUI puts its middle on, or,
-- for a portrait on its own, the secure button DaylightUI lays over its mover
-- (a secure button may only anchor to the screen or another secure frame).
-- Read from DaylightUI's own fields, so it also works while the target frame
-- is hidden (a hidden frame has no place on the screen to measure).
local function portraitPlace(f, p)
    local R = p:GetWidth() * p:GetEffectiveScale() / f:GetEffectiveScale() / 2
    if f.portraitFree then
        local click = f.portraitClick
        if not click then return end
        return click, "CENTER", 0, 0, R
    end
    if not f.portraitEdge then return end
    return f, f.portraitEdge, f.portraitX or 0, f.portraitY or 0, R
end

local function layout()
    local f = target()
    if not f then return end
    local p = f.portrait
    local want = on() and p and f.portraitMode and f.portraitMode ~= "none" and mayMark()
    if not want then
        if ring then ring:Hide(); arrow:Hide() end
        return
    end
    if not ring then build(f) end
    local host, point, dx, dy, R = portraitPlace(f, p)
    if not host or not (R and R > 0) then return end
    square = p.shapeArt and true or false
    -- A square's reach is its half-side.
    if square then R = R * SQUARE end
    radius = R
    local outer = Pixel.Snap(f, R * OUTER)
    middle = (R + outer) / 2
    for _, t in ipairs({ ring.rim, ring.veil, ring.disc }) do t:SetTexture(square and WHITE or CIRCLE) end
    local bg = Style.BACKGROUND
    ring.disc:SetVertexColor(bg[1], bg[2], bg[3], 1)
    ring.veil:SetVertexColor(0, 0, 0, 1)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", host, point, dx, dy)
    ring:SetSize(2 * outer, 2 * outer)
    outerR, edge = outer, Pixel.Px(f, EDGE_PX)

    local levelP = p:GetFrameLevel()
    local top = p.top and p.top:GetFrameLevel() or levelP + 3
    -- Above DaylightUI's click button over a portrait on its own, too.
    if f.portraitFree and f.portraitClick then top = math.max(top, f.portraitClick:GetFrameLevel()) end
    top = top + 4
    -- The art goes where the portrait is drawn (its mover, for one on its own).
    local home = p:GetParent() or f
    local strata = p:GetFrameStrata()
    for _, layer in ipairs({ under, over, clearArt }) do
        if layer:GetParent() ~= home then layer:SetParent(home) end
        layer:SetFrameStrata(strata)
    end
    ring:SetFrameLevel(top)
    under:SetFrameLevel(math.max(1, levelP - 1))
    over:SetFrameLevel(top + 2)

    local icon = math.max(ICON_MIN, Pixel.Snap(f, R * ICON))
    iconSize = icon
    for i, m in ipairs(marks) do
        local x, y = spot(square, middle, markAngle(square, i))
        m.button:SetSize(icon + 4, icon + 4)
        m.button:ClearAllPoints()
        m.button:SetPoint("CENTER", ring, "CENTER", x, y)
        m.button:SetFrameLevel(top + 3)
    end

    -- The arrow on the portrait's rim where the player put it; the clear chip
    -- just outside the ring on the same line.
    local size = math.max(ARROW_MIN, Pixel.Snap(f, R * ARROW))
    local at = arrowAngle()
    local ax, ay = spot(square, R * 0.92, at)
    arrow:SetSize(size, size)
    arrow:ClearAllPoints()
    arrow:SetPoint("CENTER", host, point, dx + ax, dy + ay)
    arrow:SetFrameLevel(top + 5)
    local cx, cy = spot(square, outer + size * 0.2, at)
    clear:SetSize(size, size)
    clear:ClearAllPoints()
    clear:SetPoint("CENTER", ring, "CENTER", cx, cy)
    clear:SetFrameLevel(top + 5)
    clearArt:SetSize(size, size)
    clearArt:SetFrameLevel(top + 5)
    chipFrom, chipTo, chipAt = R * 0.92, outer + size * 0.2, at
    for _, b in ipairs({ arrow, clear }) do
        -- The band image's ring radius: a square's half-side is SQUARE of it.
        local rim = size / RING_OUTER / (square and SQUARE or 1)
        b.rim:SetSize(rim, rim)
        b.back:SetTexture(square and WHITE or CIRCLE)
        b.back:SetVertexColor(0, 0, 0, 1)
        b.back:SetSize(size * 0.9, size * 0.9)
        local inner = Pixel.Snap(f, size * 0.6)
        b.icon:SetSize(inner, inner)
    end
    arrow:SetAttribute("blastaHover", cfg().blastaMarkerOpen == "hover" or nil)
    -- On hover the ring itself answers the mouse: no tooltip over it.
    arrow.tipTitle = cfg().blastaMarkerOpen ~= "hover" and extras.Translate("Raid markers") or nil
    paintBand(f)
    placeArt(ring:IsShown() and 1 or 0)
    arrow:Show()
end

local queued
local function refresh()
    if queued then return end
    queued = true
    -- After the frame's own layout, once the portrait has its place.
    C_Timer.After(0, function()
        queued = nil
        DUI.AfterCombat(function()
            local ok, err = pcall(layout)
            if not ok then extras.ReportOnce("TargetMarkerRing", err) end
        end, "blastaMarkerRing")
    end)
end

hooksecurefunc(UF, "LayoutPortrait", extras.SafeHook("TargetMarkerRing", function(f)
    if f == target() then refresh() end
end))
-- The chips' band follows the portrait's: a new target, a tapped or changed
-- reaction, a ring color picked.
if UF.PaintRing then
    hooksecurefunc(UF, "PaintRing", extras.SafeHook("TargetMarkerRing", function(f)
        if f == target() then paintBand(f) end
    end))
end
DUI.On("Login", refresh)
DUI.On("StyleChanged", function() if ring then paint() end refresh() end)
DUI.On("SettingChanged", function(scope, path)
    if scope == "UnitFrames" and (path == KEY or path == OPEN or path == ARROW_KEY) then refresh() end
end)
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PARTY_LEADER_CHANGED" }) do
    DUI.RegisterEvent(event, refresh)
end
-- Out of combat the ring closes on a new target and on a click anywhere else.
DUI.RegisterEvent("PLAYER_TARGET_CHANGED", function()
    if ring and ring:IsShown() and not InCombatLockdown() then ring:Hide() end
end)
DUI.RegisterEvent("GLOBAL_MOUSE_DOWN", function()
    if not (ring and ring:IsShown()) or InCombatLockdown() then return end
    if ring:IsMouseOver() or arrow:IsMouseOver() or clear:IsMouseOver() then return end
    ring:Hide()
end)

-- A moving picture of the ring for Blasta's "What's new" pages: your own
-- portrait with the ring opening, one marker lit, and closing again, over
-- and over while it's shown. Plain frames only; nothing is marked.
function extras.MarkerRingPreview(parent, R)
    local outer = R * OUTER
    local box = CreateFrame("Frame", nil, parent)
    box:SetSize(2 * outer + 16, 2 * outer + 16)
    local function layer(level)
        local l = CreateFrame("Frame", nil, box)
        l:SetAllPoints(box)
        l:SetFrameLevel(box:GetFrameLevel() + level)
        return l
    end
    local low, face, high, top = layer(1), layer(3), layer(5), layer(7)
    local function circle(on, sub, size)
        local t = on:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetTexture(MEDIA .. "shape-circle.png")
        t:SetPoint("CENTER", box, "CENTER")
        if size then t:SetSize(size, size) end
        return t
    end
    -- The ring: an edge in the portrait band's colors, a veil and the dark disc.
    local rim, veil, disc = circle(low, -3), circle(low, -2), circle(low, 0)
    veil:SetVertexColor(0, 0, 0, 1)
    local bg = Style.BACKGROUND
    disc:SetVertexColor(bg[1], bg[2], bg[3], 1)
    -- The portrait: your face, round, in the band DaylightUI draws around it.
    local hole = circle(face, -1, 2 * R * 0.9)
    hole:SetVertexColor(0, 0, 0, 1)
    local pic = face:CreateTexture(nil, "ARTWORK", nil, 0)
    pic:SetSize(2 * R * 0.78, 2 * R * 0.78)
    pic:SetPoint("CENTER", box, "CENTER")
    if SetPortraitTexture then SetPortraitTexture(pic, "player") end
    local mask = face:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(pic)
    pic:AddMaskTexture(mask)
    pic.masked = true
    local band = face:CreateTexture(nil, "OVERLAY")
    band:SetPoint("CENTER", box, "CENTER")
    band:SetSize(2 * R / RING_OUTER, 2 * R / RING_OUTER)
    local light = high:CreateTexture(nil, "BACKGROUND")
    light:SetTexture(MEDIA .. "glow.png")
    light:SetBlendMode("ADD")
    light:Hide()
    local icons = {}
    for i, n in ipairs(ORDER) do
        local t = high:CreateTexture(nil, "ARTWORK")
        t:SetTexture(string.format(MEDIA .. "marker-%d.png", n))
        icons[i] = { tex = t, angle = FIRST + STEP * (i - 1) }
    end
    local function chipArt(on, file)
        local c = CreateFrame("Frame", nil, on)
        c.back = c:CreateTexture(nil, "BACKGROUND")
        c.back:SetTexture(MEDIA .. "shape-circle.png")
        c.back:SetVertexColor(0, 0, 0, 1)
        c.back:SetPoint("CENTER")
        c.rim = c:CreateTexture(nil, "BORDER")
        c.rim:SetPoint("CENTER")
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetTexture(file)
        c.icon:SetPoint("CENTER")
        return c
    end
    local arrowArt, clearArtP = chipArt(top, MEDIA .. "ui-chevron.png"), chipArt(top, MEDIA .. "marker-clear.png")
    local chipSize = math.max(ARROW_MIN, R * ARROW)
    for _, c in ipairs({ arrowArt, clearArtP }) do
        c:SetSize(chipSize, chipSize)
        c.rim:SetSize(chipSize / RING_OUTER, chipSize / RING_OUTER)
        c.back:SetSize(chipSize * 0.9, chipSize * 0.9)
        c.icon:SetSize(chipSize * 0.6, chipSize * 0.6)
    end
    local ink = Style.INK and Style.INK.LABEL
    if type(ink) == "table" then arrowArt.icon:SetVertexColor(ink[1], ink[2], ink[3], 1) end

    -- Colors from your target frame's portrait settings.
    local sq = false
    -- The shape of your target frame's portrait: round, or square.
    local function shape()
        sq = isSquare(cfg().portraitShape)
        for _, t in ipairs({ rim, veil, disc, hole }) do t:SetTexture(sq and WHITE or CIRCLE) end
        disc:SetVertexColor(bg[1], bg[2], bg[3], 1)
        veil:SetVertexColor(0, 0, 0, 1)
        hole:SetVertexColor(0, 0, 0, 1)
        local half = sq and R * SQUARE or R
        hole:SetSize(2 * half * 0.98, 2 * half * 0.98)
        if sq and pic.masked then pic:RemoveMaskTexture(mask); pic.masked = nil
        elseif not sq and not pic.masked then pic:AddMaskTexture(mask); pic.masked = true end
        local face = sq and 2 * half * 0.86 or 2 * R * 0.78
        pic:SetSize(face, face)
        for _, c in ipairs({ arrowArt, clearArtP }) do
            c.back:SetTexture(sq and WHITE or CIRCLE)
            c.back:SetVertexColor(0, 0, 0, 1)
            local rimSize = chipSize / RING_OUTER / (sq and SQUARE or 1)
            c.rim:SetSize(rimSize, rimSize)
        end
    end
    local function colorize()
        local fake = { ringColor = cfg().portraitRing, unitToken = "player" }
        local lo, hi, r, g, b = bandColors(fake)
        local gray = UF.RING_COLOR or { 0.34, 0.34, 0.36 }
        local file, lit = UF.RING_FILE, UF.RING_LIT_FILE
        if UF.RingFiles then file, lit = UF.RingFiles(cfg().portraitRingWidth, cfg().portraitRingLine, sq and "square" or nil) end
        for _, t in ipairs({ band, arrowArt.rim, clearArtP.rim }) do
            if type(r) ~= "nil" then t:SetTexture(lit); t:SetVertexColor(r, g, b, 1)
            elseif lo then t:SetTexture(file); t:SetVertexColor(1, 1, 1, 1); t:SetGradient("VERTICAL", lo, hi)
            else t:SetTexture(file); t:SetVertexColor(gray[1], gray[2], gray[3], 1) end
        end
        if type(r) ~= "nil" then rim:SetVertexColor(r, g, b, 1); veil:SetAlpha(0.35)
        elseif lo then rim:SetVertexColor(1, 1, 1, 1); rim:SetGradient("VERTICAL", lo, hi); veil:SetAlpha(0.16)
        else rim:SetVertexColor(gray[1], gray[2], gray[3], 1); veil:SetAlpha(0.16) end
        local ar, ag, ab = Style.Accent()
        light:SetVertexColor(ar, ag, ab, 0.55)
    end

    local at = arrowAngle()
    local edgePx, iconPx = 2, math.max(ICON_MIN, R * ICON)
    local function place(k)
        local half = sq and R * SQUARE or R
        local out = half * OUTER
        local middle = (half + out) / 2
        local o = half + (out - half) * k
        rim:SetSize(2 * o, 2 * o)
        veil:SetSize(2 * o, 2 * o)
        local inner = math.max(0, 2 * (o - edgePx))
        disc:SetSize(inner, inner)
        local alpha = math.min(1, k * 1.6)
        low:SetAlpha(alpha)
        high:SetAlpha(alpha)
        local r = half + (middle - half) * k
        for i, m in ipairs(icons) do
            local x, y = spot(sq, r, markAngle(sq, i))
            m.tex:ClearAllPoints()
            m.tex:SetPoint("CENTER", box, "CENTER", x, y)
            local size = iconPx * (0.6 + 0.4 * k)
            m.tex:SetSize(size, size)
        end
        local ax, ay = spot(sq, half * 0.92, at)
        arrowArt:ClearAllPoints()
        arrowArt:SetPoint("CENTER", box, "CENTER", ax, ay)
        arrowArt.icon:SetRotation(math.pi * k)
        local scale = 0.6 + 0.4 * k
        local cx, cy = spot(sq, half * 0.92 + (out + chipSize * 0.2 - half * 0.92) * k, at)
        clearArtP:SetAlpha(alpha)
        clearArtP:SetScale(scale)
        clearArtP:ClearAllPoints()
        clearArtP:SetPoint("CENTER", box, "CENTER", cx / scale, cy / scale)
    end

    -- Open, light a marker, close, rest; again while the box is shown.
    local run = 0
    local function after(seconds, id, fn)
        C_Timer.After(seconds, function() if id == run and box:IsVisible() then fn() end end)
    end
    local function cycle(id)
        Motion.Tween(box, 0, 1, OPEN_TIME * 2, place)
        after(0.7, id, function()
            local m = icons[1]
            light:SetSize(iconPx * GLOW, iconPx * GLOW)
            light:ClearAllPoints()
            light:SetPoint("CENTER", m.tex, "CENTER")
            light:Show()
            Motion.Bump(m.tex, 0.85)
        end)
        after(1.5, id, function()
            light:Hide()
            Motion.Tween(box, 1, 0, CLOSE_TIME * 2, place)
        end)
        after(2.4, id, function() cycle(id) end)
    end
    box:SetScript("OnShow", function()
        run = run + 1
        at = arrowAngle()
        shape()
        colorize()
        place(0)
        cycle(run)
    end)
    box:SetScript("OnHide", function() run = run + 1 end)
    shape()
    colorize()
    place(0)
    return box
end

extras.Loaded("TargetMarkerRing")
