local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Nameplates")
local ns = mod and mod.ns
local Body, Plate, Cast, Power = ns and ns.Body, ns and ns.Plate, ns and ns.Cast, ns and ns.Power
if not (Body and Plate and Cast and Power and Body.Layout and Body.FitBar and Plate.LayoutRing
    and Plate.ShowRing and Plate.DropRing and Cast.Layout and Cast.Stop and Cast.Update
    and Cast.Kicked and Cast.ShowSample and Power.Layout and Plate.Layout) then return end
local Style, Motion = DUI.Style, DUI.Motion
local Edges = extras.Edges

mod.defaults.slantBoth = false
mod.defaults.castSlide = false
local function leftDirection(db)
    return db.plateLeft or (db.slantBoth and db.slant ~= false and "top" or "straight")
end
extras.AddSetting(mod, "slant", Edges.Options(mod, "plateLeft", "Left edge direction", function(reset)
    return leftDirection(not reset and mod.db or mod.defaults)
end), true)
mod.defaults.castSlideFrom = "below"
extras.AddSetting(mod, "castIcon", { type = "toggle", key = "castSlide", label = "Slide out nameplate cast bar",
    desc = "The cast bar glides into place at the start of a cast." }, true)
extras.AddSetting(mod, "castSlide", { type = "dropdown", key = "castSlideFrom", label = "Cast bar entrance direction",
    values = { below = "From below", above = "From above", left = "From left", right = "From right" },
    order = { "below", "above", "left", "right" }, disabled = function(get) return get("castSlide") ~= true end })

local castEdges = { follow = "Follow nameplate edge", straight = "Straight",
    top = "Top corner projects", bottom = "Bottom corner projects" }
local anchor = "castSlideFrom"
for _, edge in ipairs({ { "castEdgeLeft", "Left cast bar edge" }, { "castEdgeRight", "Right cast bar edge" } }) do
    mod.defaults[edge[1]] = "follow"
    extras.AddSetting(mod, anchor, { type = "dropdown", key = edge[1], label = edge[2],
        values = castEdges, order = { "follow", "straight", "top", "bottom" } })
    anchor = edge[1]
end

local wanted = setmetatable({}, { __mode = "k" })
local customCast = setmetatable({}, { __mode = "k" })
local angled = setmetatable({}, { __mode = "k" })
local clips = setmetatable({}, { __mode = "k" })
local function owner(p)
    if not p.friendly and ns.cfg and leftDirection(ns.cfg) ~= "straight" then return p end
end

local function clip(frame, texture, both)
    if not texture then return end
    local registration = clips[texture]
    local side = not both and "left" or nil
    if registration then
        local changed = registration.only ~= side
        registration.only = side
        return changed
    end
    Style.Clip(frame, texture, "inner", nil, side)
    local list = Style.GetSlant(frame).clips
    clips[texture] = list[#list]
    return true
end

local layoutBody = Body.Layout
function Body.Layout(body, cutTop, cutBottom)
    local frame = body.frame
    local was = angled[frame]
    local custom = customCast[body]
    local nativeCut
    Edges.Clear(frame)
    if custom then
        local top, bottom = cutTop or 0, cutBottom or 0
        nativeCut = math.abs(bottom - top)
        custom.nativeRight = top ~= 0 or bottom ~= 0
        -- Match the health bar at the join. Continuing its slope through
        -- the gap first would shorten the cast before its own edges are cut.
        local leftInset, rightInset = custom.leftInset, custom.rightInset
        local width = frame:GetWidth()
        if leftInset + rightInset > 0 and width - leftInset - rightInset > 1 then
            if leftInset > 0 then
                local point, relative, relativePoint, x, y = frame:GetPoint()
                frame:ClearAllPoints()
                frame:SetPoint(point, relative, relativePoint, x + leftInset, y)
            end
            frame:SetWidth(width - leftInset - rightInset)
        end
        cutTop, cutBottom = 0, 0
    end
    layoutBody(body, cutTop, cutBottom)
    local g = body.geo
    local p = wanted[body]
    if not (g and (p or custom)) then
        if was then
            angled[frame] = nil
            if not body.shellMode then Style.Slant(frame, nil, 0) end
            if body.shell then Style.Seams(frame, false, false) end
        end
        return
    end
    angled[frame] = g
    local opts = body.shellOpts or {}
    body.shellOpts = opts
    local o = body.opts
    -- Another addon can leave the general setting empty (after logout strips defaults).
    local border = tonumber(DUI.DB.General().borderPx) or (DUI.DB.GENERAL_DEFAULTS and DUI.DB.GENERAL_DEFAULTS.borderPx) or 1
    local own = o.borderPx
    opts.borderPx = type(own) == "function" and own(border) or own or border
    opts.flat, opts.noBevel, opts.noBorder = o.flat, true, o.noBorder
    opts.borderColor, opts.bandColor = body.borderColor, body.bandColor
    body.shell = Style.Shell(frame, opts)
    body.shell:SetFrameLevel(body.holder:GetFrameLevel())
    Style.Seams(frame, o.joined, false)
    if custom then
        local cut = math.min(g.W / 4, nativeCut > 0 and nativeCut or g.H * Plate.SLANT)
        local left = custom.left == "follow" and leftDirection(ns.cfg) or custom.left
        local right = custom.right == "follow" and (custom.nativeRight and "top" or "straight") or custom.right
        g.leftTop, g.leftBottom = left == "bottom" and cut or 0, left == "top" and cut or 0
        g.rightTop, g.rightBottom = right == "bottom" and cut or 0, right == "top" and cut or 0
        custom.cut, custom.effectiveRight = cut, right
        Edges.Apply(frame, left, right, cut)
        body.shellMode = true
        body.holder:Hide()
        body.shell:SetShown(not body.off)
        return
    end
    local ref = o.joined and o.ref or nil
    local span = ref and ref.height or g.H
    local cut = g.angled and g.cutBottom or math.min(g.W / 4, span * Plate.SLANT)
    local left = leftDirection(ns.cfg)
    local y = math.max(0, span - g.H)
    g.leftTop, g.leftBottom = cut * y / span, cut
    if left == "bottom" then g.leftTop, g.leftBottom = cut - g.leftTop, 0 end
    -- Leave the native right fill and its reference untouched.
    Edges.Apply(frame, left, g.angled and "top" or "straight", cut, ref, true)
    if ref then ref.y = y end
    body.shellMode = true
    body.holder:Hide()
    body.shell:SetShown(not body.off)
end

local fit = Body.FitBar
function Body.FitBar(body, bar, overlays)
    local cut = fit(body, bar, overlays)
    local frame = body.frame
    local g = angled[frame]
    if g then
        local custom = customCast[body]
        if custom then
            cut = custom.effectiveRight == "straight" and 0 or custom.cut * math.max(0, 1 - 2 * g.T / g.H)
            Edges.Fill(bar, "right", cut, custom.effectiveRight)
        end
        clip(frame, bar:GetStatusBarTexture(), custom)
        clip(frame, Style.BarBack(bar), custom)
        for _, tex in ipairs(overlays or {}) do clip(frame, tex, custom) end
        Style.LayoutSlant(frame)
    elseif clips[bar:GetStatusBarTexture()] then
        clip(frame, bar:GetStatusBarTexture())
        clip(frame, Style.BarBack(bar))
        Style.LayoutSlant(frame)
    end
    return cut
end

-- A DoT veil on an angled plate: its fill and its dark end line both stop at
-- the plate's slanted end. Also used for Blasta's finisher segment.
local function clipVeil(frame, veil)
    if not (veil and veil.bar) then return false end
    local fill = clip(frame, veil.bar:GetStatusBarTexture())
    local line = clip(frame, veil.edge)
    return fill or line
end
function extras.ClipPlateVeil(frame, veil)
    if angled[frame] and clipVeil(frame, veil) then Style.LayoutSlant(frame) end
end

local layoutPlate = Plate.Layout
function Plate.Layout(p, ...)
    if p.body then wanted[p.body] = owner(p) end
    layoutPlate(p, ...)
    local frame = p.hp
    local g = angled[frame]
    if g then
        local heals = clip(frame, p.heals and p.heals:GetStatusBarTexture())
        local absorbs = clip(frame, p.absorbs and p.absorbs:GetStatusBarTexture())
        local veil = p.dotVeil
        local dots = clipVeil(frame, veil)
        local extra = extras.FinisherVeil and extras.FinisherVeil(veil)
        local finisher = extra and clipVeil(frame, extra)
        if heals or absorbs or dots or finisher then Style.LayoutSlant(frame) end
    end
end

local layoutPower = Power.Layout
function Power.Layout(p, ...)
    if p.power and p.power.body then wanted[p.power.body] = owner(p) end
    return layoutPower(p, ...)
end

local layoutRing = Plate.LayoutRing
local function leftRing(ring, frame, depth, cutTop, cutBottom)
    local e = ring.pieces
    e.TOPLEFT:SetPoint("TOPLEFT", frame, "TOPLEFT", cutTop - depth, depth)
    e.BOTTOMLEFT:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", cutBottom - depth, -depth)
    e.TOP:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", cutTop, 0)
    e.BOTTOM:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", cutBottom, 0)
    e.LEFT:SetPoint("TOPRIGHT", frame, "TOPLEFT", cutTop, 0)
    e.LEFT:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", cutTop, 0)
    local lean = cutBottom - cutTop
    if e.LEFT.SetVertexOffset then
        e.LEFT:SetVertexOffset(2, lean, 0)
        e.LEFT:SetVertexOffset(4, lean, 0)
    end
end

function Plate.LayoutRing(ring, frame, depth, topCut, bottomCut, radius)
    local g = angled[frame]
    local was = ring.daylightBoth
    if g and ring.wipeDir then Plate.DropRing(ring) end
    ring.daylightBoth = g and true or nil
    local left = g ~= nil
    layoutRing(ring, frame, depth, topCut, bottomCut, left and radius ~= nil and 0 or radius)
    if left then
        leftRing(ring, frame, depth, g.leftTop, g.leftBottom)
    elseif ring.blastaLeft and ring.pieces.LEFT.SetVertexOffset then
        ring.pieces.LEFT:SetVertexOffset(2, 0, 0)
        ring.pieces.LEFT:SetVertexOffset(4, 0, 0)
    end
    ring.blastaLeft = left
    if was and not g then
        local keep = ring:IsShown() and ring.daylightRingGoal ~= false
        ring.daylightRingGoal = nil
        Motion.AlphaTo(ring, keep and 1 or 0, 0, not keep)
        if not keep then ring:SetAlpha(1) end
    end
end

-- A wipe assumes one straight left edge. For paired angles fade the
-- already fitted outline without moving either edge.
local showRing, dropRing = Plate.ShowRing, Plate.DropRing
function Plate.ShowRing(ring, on)
    if not ring.daylightBoth then return showRing(ring, on) end
    -- Only skip when the ring really is in that state: Daylight's previews
    -- repaint the target mark on every refresh, and a ring that was hidden
    -- elsewhere has to come back.
    if ring.daylightRingGoal == on and ring:IsShown() == on and (not on or ring:GetAlpha() > 0) then return end
    ring.daylightRingGoal = on
    Motion.AlphaTo(ring, on and 1 or 0, Motion.FAST, not on)
end
function Plate.DropRing(ring)
    if not ring.daylightBoth then return dropRing(ring) end
    ring.daylightRingGoal = nil
    Motion.AlphaTo(ring, 0, 0, true)
end

local function stopSlide(c)
    local group = c.__duiMotion and c.__duiMotion.slideIn
    if group then group:Stop() end
end

local function slideIn(c)
    if ns.cfg and ns.cfg.castSlide and Motion.On() then
        local from = ns.cfg.castSlideFrom
        local distance = math.min(8, c:GetHeight())
        local dx = from == "left" and -2 * distance or from == "right" and 2 * distance or 0
        local dy = from == "above" and distance or dx == 0 and -distance or 0
        Motion.SlideIn(c, dx, dy, 0.22)
    end
end

local _, castRows = extras.FindSetting(mod, "castSlide")
if castRows then
    castRows[#castRows + 1] = {
        type = "button", label = "Preview cast bar entrance", text = "Preview",
        func = function()
            local p = Cast.sample
            if p and p:IsVisible() and p.cast:IsShown() then slideIn(p.cast) end
        end,
        disabled = function(get) return get("castSlide") ~= true end,
    }
end

local layoutCast = Cast.Layout
function Cast.Layout(p, ...)
    local c = p.cast
    local custom
    if c and c.body and ns.cfg then
        wanted[c.body] = owner(p)
        local left = ns.cfg.castEdgeLeft or "follow"
        local right = ns.cfg.castEdgeRight or "follow"
        local health = p.hp and angled[p.hp]
        local nativeHealth = p.body and p.body.geo
        local rightInset = math.max(0, nativeHealth and nativeHealth.cutBottom or p.hpCut or 0)
        if not p.friendly and (left ~= "follow" or right ~= "follow" or health or rightInset > 0) then
            custom = customCast[c.body] or {}
            custom.left, custom.right = left, right
            custom.leftInset = health and math.max(0, health.leftBottom) or 0
            custom.rightInset = rightInset
        end
        customCast[c.body] = custom
    end
    layoutCast(p, ...)
    if c and c.text then
        c.text:SetMaxLines(1)
        c.text:SetWordWrap(false)
        c.text:SetNonSpaceWrap(false)
    end
    local g = angled[c]
    if g then
        local inset = math.max(g.leftTop, g.leftBottom)
        c.text:SetPoint("LEFT", c.bar, "LEFT", 3 + inset, 0)
        if custom then
            c.time:SetPoint("RIGHT", c, "RIGHT", -(g.T + 2 + math.max(g.rightTop, g.rightBottom)), 0)
        end
        if ns.cfg.castIconPos ~= "outright" then
            c.iconBox:SetPoint("TOPRIGHT", c, "TOPLEFT", g.leftTop - Cast.ICON_GAP, 0)
        elseif custom then
            c.iconBox:SetPoint("TOPLEFT", c, "TOPRIGHT", Cast.ICON_GAP - g.rightTop, 0)
        end
        clip(c, c.light, custom)
        Style.LayoutSlant(c)
    elseif c and clips[c.light] and clip(c, c.light) then
        Style.LayoutSlant(c)
    end
end

local stop = Cast.Stop
function Cast.Stop(p, snap)
    stopSlide(p.cast)
    return stop(p, snap)
end

-- The kick's pieces follow the cast bar's right edge. DaylightUI cuts them
-- along its own edge, so a cast bar with Blasta's own right edge hands
-- Motion.Kick that edge instead (DaylightUI 1.9.4 keeps the bar red for a
-- moment on its own; Blasta no longer holds it).
if Motion and Motion.Kick then
    local kick = Motion.Kick
    function Motion.Kick(k, over, style, r, g, b, shape)
        local geo = over and angled[over]
        local custom = geo and over.body and customCast[over.body]
        if shape and custom and geo.rightTop and geo.rightBottom then
            local W, H = geo.W or over:GetWidth(), geo.H or over:GetHeight()
            if type(W) == "number" and type(H) == "number" and H > 0 then
                local top, bottom = geo.rightTop, geo.rightBottom
                local slope = math.sqrt(1 + ((bottom - top) / H) ^ 2)
                shape = { T = shape.T, edge = shape.edge, fill = shape.fill,
                    right = function(y, inset) return W - top - (bottom - top) * y / H - inset * slope end }
            end
        end
        return kick(k, over, style, r, g, b, shape)
    end
end

local kicked = Cast.Kicked
function Cast.Kicked(p, ...)
    stopSlide(p.cast)
    return kicked(p, ...)
end

local update = Cast.Update
function Cast.Update(p)
    local c = p.cast
    local entering = not c:IsShown() or c.leaving
    update(p)
    if entering and c.duration and c:IsShown() then slideIn(c) end
end

local sample = Cast.ShowSample
function Cast.ShowSample(p, data)
    local c = p.cast
    local entering = not c:IsShown() or c.leaving
    sample(p, data)
    if data and entering and c:IsShown() then slideIn(c) end
end

extras.Loaded("NameplateShape")
