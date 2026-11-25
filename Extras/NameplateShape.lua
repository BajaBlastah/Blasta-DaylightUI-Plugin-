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
-- The right end: DaylightUI only cuts it one way (top corner projects) or not
-- at all (its "Health bar angled end"). Straight here is that switch off.
local function rightDirection(db)
    if db.slant == false then return "straight" end
    return db.plateRight == "bottom" and "bottom" or "top"
end
local function flipRight(db) return db and rightDirection(db) == "bottom" end
local rightRow = Edges.Options(mod, "plateRight", "Right edge direction", function(reset)
    return rightDirection(not reset and mod.db or mod.defaults)
end)
rightRow.get = function() return rightDirection(mod.db or mod.defaults) end
rightRow.set = function(value)
    DUI:Set(mod.name, "plateRight", value == "bottom" and "bottom" or "top")
    return DUI:Set(mod.name, "slant", value ~= "straight")
end
rightRow.desc = "Which corner of the bar's right end projects. Straight is DaylightUI's Health bar angled end switched off."
extras.AddSetting(mod, "plateLeft", rightRow)
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

-- Cast bar height on Blasta's cast bar tab: a copy of DaylightUI's row (it
-- keeps its own with the health bar), writing the same setting. And the
-- spell name movable on the bar; the time has its own rows (DesignParts).
local G = extras.German
local CAST_TEXT = {
    { "blastaCastNameSize", "Spell name text size", 0, 24, "At 0, DaylightUI's size (it follows the bar's height). Values below 6 use 6.", true },
    { "blastaCastTimeSize", "Cast time text size", 0, 24, "At 0, DaylightUI's size (it follows the bar's height). Values below 6 use 6.", true },
    { "blastaCastTextX", "Spell name left / right", -80, 80, "Moves the spell name on enemy cast bars left or right, in pixels." },
    { "blastaCastTextY", "Spell name up / down", -30, 30, "Moves the spell name on enemy cast bars up or down, in pixels." },
}
do
    for _, t in ipairs(CAST_TEXT) do mod.defaults[t[1]] = 0 end
    local height = extras.FindSetting(mod, "castHeight")
    local _, items, index = extras.FindSetting(mod, "castY")
    if items and not extras.FindSetting(mod, CAST_TEXT[1][1]) then
        if height then
            local copy = {}
            for k, v in pairs(height) do copy[k] = v end
            copy.blastaCopy = true          -- DaylightUI's setting: Reset this tab leaves it
            copy.blastaJumpAnchor = "castY"
            index = index + 1
            table.insert(items, index, copy)
        end
        for _, t in ipairs(CAST_TEXT) do
            index = index + 1
            table.insert(items, index, { type = "slider", key = t[1], label = t[2], min = t[3], max = t[4],
                step = 1, unit = not t[6] and "px" or nil, desc = t[5], blastaJumpAnchor = "castY" })
        end
    end
end
-- The preview's cast bar answers to them like to its own settings.
for _, part in ipairs(ns.Sample and ns.Sample.PARTS or {}) do
    if part.label == "Cast bar" and type(part.keys) == "table" then
        for _, t in ipairs(CAST_TEXT) do part.keys[#part.keys + 1] = t[1] end
    end
end
G["Spell name text size"] = G["Spell name text size"] or "Textgröße Zaubername"
G["Cast time text size"] = G["Cast time text size"] or "Textgröße Zauberzeit"
G["At 0, DaylightUI's size (it follows the bar's height). Values below 6 use 6."] =
    "Bei 0 DaylightUIs Größe (sie richtet sich nach der Höhe der Leiste). Werte unter 6 ergeben 6."
G["Spell name left / right"] = "Zaubername links / rechts"
G["Spell name up / down"] = "Zaubername hoch / runter"
G["Moves the spell name on enemy cast bars left or right, in pixels."] = "Verschiebt den Zaubernamen auf gegnerischen Zauberleisten nach links oder rechts, in Pixeln."
G["Moves the spell name on enemy cast bars up or down, in pixels."] = "Verschiebt den Zaubernamen auf gegnerischen Zauberleisten nach oben oder unten, in Pixeln."

local wanted = setmetatable({}, { __mode = "k" })
local customCast = setmetatable({}, { __mode = "k" })
local angled = setmetatable({}, { __mode = "k" })
local clips = setmetatable({}, { __mode = "k" })
local function owner(p)
    if not p.friendly and ns.cfg and (leftDirection(ns.cfg) ~= "straight" or flipRight(ns.cfg)) then return p end
end

-- both: true clips at both ends, "right" only at the right one, else only
-- at the left. A texture holds three masks at most, so each part is cut only
-- at the ends it can reach.
local function clip(frame, texture, both)
    if not texture then return end
    local registration = clips[texture]
    local side = type(both) == "string" and both or (not both and "left" or nil)
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
        -- The cast bar's top edge meets the health bar's bottom edge as drawn,
        -- from its bottom-left to its bottom-right corner; its own ends then
        -- lean on in their direction. Worked out from the health bar each time
        -- (never read back from the cast bar: the plate can't be measured under
        -- restrictions, and a repeated layout, as in the preview, must not
        -- shift or shrink it further).
        local plate = custom.plate
        local hp = plate and plate.hp
        if hp then
            local cfg = ns.cfg or {}
            local W, hh = hp:GetWidth(), hp:GetHeight()
            local H = tonumber(cfg.castHeight) or 10
            local c = nativeCut > 0 and nativeCut or H * Plate.SLANT
            local left = custom.left == "follow" and leftDirection(cfg) or custom.left
            local right = custom.right == "follow" and rightDirection(cfg) or custom.right
            local x0 = (custom.healthLeft or 0) - (left == "bottom" and c or 0)
            local x1 = W - (custom.healthRight or 0) + (right == "bottom" and c or 0)
            if x1 - x0 > 4 then
                local gap = Cast.GAP + (ns.Combo and ns.Combo.Drop(plate) or 0) + (Power.Drop and Power.Drop(plate) or 0)
                frame:ClearAllPoints()
                frame:SetPoint("TOPLEFT", hp, "TOPLEFT", (tonumber(cfg.castX) or 0) + x0,
                    -(hh + gap) + (tonumber(cfg.castY) or 0))
                frame:SetWidth(x1 - x0)
            end
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
        local right = custom.right == "follow" and rightDirection(ns.cfg) or custom.right
        g.leftTop, g.leftBottom = left == "bottom" and cut or 0, left == "top" and cut or 0
        g.rightTop, g.rightBottom = right == "bottom" and cut or 0, right == "top" and cut or 0
        custom.cut, custom.effectiveRight, custom.effectiveLeft = cut, right, left
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
    if left == "straight" then g.leftTop, g.leftBottom = 0, 0 end
    -- The right end turned over: the top corner cut in, the bottom one
    -- projecting (the left end's "bottom", mirrored).
    local flip = g.angled and flipRight(ns.cfg) or false
    g.flipRight = flip
    if flip then
        g.rightTop, g.rightBottom = cut - cut * y / span, 0
    else
        g.rightTop, g.rightBottom = g.cutTop or 0, g.cutBottom or 0
    end
    -- Otherwise leave the native right fill and its reference untouched.
    Edges.Apply(frame, left, flip and "bottom" or (g.angled and "top" or "straight"), cut, ref, not flip)
    if ref then ref.y = y end
    body.shellMode = true
    body.holder:Hide()
    body.shell:SetShown(not body.off)
end

-- Everything that leans inside the bar (the fill's moving edge, heals and
-- shields, the DoT veil, the execute line, Shadow Word: Death's mark) runs
-- parallel to the left end, the way the plate is seen in perspective. The
-- right end only cuts the bar off. With a straight left end they follow the
-- right end; with a straight right end they stay upright (a leaning fill
-- would leave a notch at full health there).
-- under: true leans like "\" (top corner further left), false like "/".
local function innerUnder(left, right)
    if right == "straight" then return nil end
    if left == "top" then return true elseif left == "bottom" then return false end
    return right == "bottom"
end

local fit = Body.FitBar
function Body.FitBar(body, bar, overlays)
    local cut = fit(body, bar, overlays)
    local frame = body.frame
    local g = angled[frame]
    if g then
        local custom = customCast[body]
        local left, right
        if custom then
            left, right = custom.effectiveLeft or "straight", custom.effectiveRight or "straight"
        else
            left = leftDirection(ns.cfg)
            right = g.flipRight and "bottom" or (g.angled and "top" or "straight")
        end
        local under = innerUnder(left, right)
        local T = g.T or 0
        -- The contents' right end, in from the frame's right edge at their top
        -- and their bottom, and the lean of the fill's edge.
        local fc, rTi, rBi
        if custom then
            fc = under ~= nil and custom.cut * math.max(0, 1 - 2 * T / g.H) or 0
            rTi, rBi = T + (g.rightTop or 0), T + (g.rightBottom or 0)
        else
            fc = cut
            local IR = Body.InnerRight(body)
            rTi = IR + (right == "bottom" and fc or 0)
            rBi = IR + (right == "top" and fc or 0)
        end
        local takeOver = custom or right == "bottom" or (under ~= nil and under ~= (right == "bottom"))
        g.fillCut, g.fillUnder, g.fillBoth = fc, under, takeOver and true or false
        if takeOver then
            if under == nil or fc <= 0 then
                Style.AngleFill(bar, nil, 0)
            else
                -- The bar reaches as far as the leaning edge must go to cover
                -- the whole right end at full; the end's own clip cuts the rest.
                local inset = under and math.min(rTi - fc, rBi) or math.min(rTi, rBi - fc)
                bar:ClearAllPoints()
                bar:SetPoint("TOPLEFT", frame, "TOPLEFT", T, -T)
                bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, T)
                Style.AngleFill(bar, "right", fc, under or nil)
            end
            -- The background and overlays stay upright; the clips shape them.
            local back = Style.BarBack(bar)
            if back then Body.Lean(back, 0) end
            for _, tex in ipairs(overlays or {}) do Body.Lean(tex, 0) end
            cut = under ~= nil and fc or 0
        end
        clip(frame, bar:GetStatusBarTexture(), takeOver)
        clip(frame, Style.BarBack(bar), takeOver)
        for _, tex in ipairs(overlays or {}) do clip(frame, tex, takeOver) end
        Style.LayoutSlant(frame)
    elseif clips[bar:GetStatusBarTexture()] then
        clip(frame, bar:GetStatusBarTexture())
        clip(frame, Style.BarBack(bar))
        Style.LayoutSlant(frame)
    end
    return cut
end

-- DaylightUI leans the execute line and the DoT veil's end with the fill but
-- only one way. A fill leaning the other way (Style.AngleFill's under) takes
-- them along. Vertex offsets: 1 upper left, 2 lower left, 3 upper right,
-- 4 lower right.
local sheared = setmetatable({}, { __mode = "k" })
local function shear(tex, top, bottom, left)
    if not (tex and tex.SetVertexOffset) then return end
    sheared[tex] = true
    if left ~= false then
        pcall(tex.SetVertexOffset, tex, 1, top, 0)
        pcall(tex.SetVertexOffset, tex, 2, bottom, 0)
    end
    pcall(tex.SetVertexOffset, tex, 3, top, 0)
    pcall(tex.SetVertexOffset, tex, 4, bottom, 0)
end
-- Back to DaylightUI's own lean: it sets the upper corners itself, so only
-- the lower ones Blasta moved go back.
local function unshear(tex)
    if not (tex and sheared[tex]) then return end
    sheared[tex] = nil
    pcall(tex.SetVertexOffset, tex, 2, 0, 0)
    pcall(tex.SetVertexOffset, tex, 4, 0, 0)
end
local function underLean(bar)
    local side, cut, under = Style.GetFillAngle(bar)
    if not (side and under and type(cut) == "number" and cut > 0) then return nil end
    return side, cut, side == "right" and cut or -cut
end

local layoutExecute = Plate.LayoutExecute
if layoutExecute then
    function Plate.LayoutExecute(p, ...)
        local a, b = layoutExecute(p, ...)
        local e = p.exec
        if p.execOn and e and p.health then
            local _, _, lean = underLean(p.health)
            if lean then
                shear(e.band, 0, lean, false)
                shear(e.lit, 0, lean, false)
                shear(e.line, 0, lean)
            else
                unshear(e.band); unshear(e.lit); unshear(e.line)
            end
        end
        return a, b
    end
end

local Dots = DUI.Dots
local layoutVeil = Dots and Dots.LayoutVeil
if layoutVeil then
    function Dots.LayoutVeil(veil, bar, ...)
        local a, b = layoutVeil(veil, bar, ...)
        if veil and veil.bar and bar then
            local side, cut, lean = underLean(bar)
            if lean then
                Style.AngleTrail(veil.bar, side, cut, true)
                shear(veil.edge, 0, lean)
            else
                unshear(veil.edge)
            end
        end
        return a, b
    end
end

-- A DoT veil on an angled plate: its fill and its dark end line both stop at
-- the plate's slanted end. Also used for Blasta's finisher segment.
local function clipVeil(frame, veil, both)
    if not (veil and veil.bar) then return false end
    local fill = clip(frame, veil.bar:GetStatusBarTexture(), both)
    local line = clip(frame, veil.edge, both)
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
        if g.fillBoth then
            -- Heals and shields start at the fill's moving edge and lean with it.
            local fc, under = g.fillCut or 0, g.fillUnder
            for _, key in ipairs({ "heals", "absorbs" }) do
                if p[key] then Style.AngleFill(p[key], under ~= nil and fc > 0 and "right" or nil, fc, under or nil) end
            end
        end
        -- Heals and shields start past the fill, so only the right end can
        -- reach them; the DoT veils grow back into the fill toward the left end
        -- and already wear the fill's edge and their own back edge.
        local tail = g.fillBoth and "right" or nil
        local heals = clip(frame, p.heals and p.heals:GetStatusBarTexture(), tail)
        local absorbs = clip(frame, p.absorbs and p.absorbs:GetStatusBarTexture(), tail)
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
    if g and g.flipRight then topCut, bottomCut = g.rightTop, g.rightBottom end
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

-- The spell name and time where they sit, moved by their offsets. Laid out
-- here from the same insets DaylightUI and the edges above use (nothing is
-- read back from the plate).
local function num(v) return tonumber(v) or 0 end
local function moveCastText(c, g, custom)
    local cfg = ns.cfg
    local nameSize, timeSize = num(cfg.blastaCastNameSize), num(cfg.blastaCastTimeSize)
    if nameSize > 0 then Style.SetTextSize(c.text, math.max(6, nameSize)) end
    if timeSize > 0 then Style.SetTextSize(c.time, math.max(6, timeSize)) end
    local tx, ty = num(cfg.blastaCastTextX), num(cfg.blastaCastTextY)
    -- The time's offset (DesignParts' rows). Placed from the insets, as a
    -- nameplate's text can't be measured (GetPoint) under restrictions.
    local mx, my = num(cfg.castTimeX), num(cfg.castTimeY)
    if mx ~= 0 or my ~= 0 then
        local timeX
        if g and custom then
            timeX = -(g.T + 2 + math.max(g.rightTop or 0, g.rightBottom or 0))
        else
            local T = c.body and c.body.T or 0
            local geo = c.body and c.body.geo
            local edge = geo and ((geo.cutTop or 0) + (geo.lean or 0) * (0.5 + (Cast.TEXT or 0.7) * 0.5)) or 0
            timeX = -(T + 2 + edge)
        end
        c.time:ClearAllPoints()
        c.time:SetPoint("RIGHT", c, "RIGHT", timeX + mx, my)
    end
    if tx == 0 and ty == 0 and my == 0 then return end
    local textX = 3 + (g and math.max(g.leftTop or 0, g.leftBottom or 0) or 0)
    c.text:ClearAllPoints()
    c.text:SetPoint("LEFT", c.bar, "LEFT", textX + tx, ty)
    -- Its right end stays before the time (or the target's name beside it),
    -- at the same height as its left.
    c.text:SetPoint("RIGHT", cfg.castTarget ~= false and c.target or c.time, "LEFT", -3, ty - my)
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
        local rightInset = math.max(0, health and health.flipRight and health.rightBottom
            or nativeHealth and nativeHealth.cutBottom or p.hpCut or 0)
        if not p.friendly and (left ~= "follow" or right ~= "follow" or health or rightInset > 0) then
            custom = customCast[c.body] or {}
            custom.left, custom.right, custom.plate = left, right, p
            -- The health bar's bottom corners, in from its frame's ends.
            if health then
                custom.healthLeft, custom.healthRight = health.leftBottom or 0, health.rightBottom or 0
            else
                custom.healthLeft, custom.healthRight = 0, rightInset
            end
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
    if c and c.text and c.time then pcall(moveCastText, c, g, custom) end
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

-- The elite dragon grips the bar's top-right corner. With the right end
-- turned over that corner is cut in, so the dragon moves in with it.
local layoutDragon = Plate.LayoutDragon
if layoutDragon then
    function Plate.LayoutDragon(p, h, ...)
        local a, b = layoutDragon(p, h, ...)
        local g = p.hp and angled[p.hp]
        local D, t = Plate.DRAGON, p.dragon
        if g and g.flipRight and D and t and type(h) == "number" then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", p.hp, "TOPRIGHT", -D.endX * h - (g.rightTop or 0), D.topY * h)
        end
        return a, b
    end
end

-- Pieces centered above or below the bar (the name, the debuffs...) sit on the
-- middle of that edge as drawn. With a slanted end the bar's top and bottom
-- edges are shorter than its frame and no longer share the frame's middle.
local spotBox = Plate.SpotBox
if spotBox then
    function Plate.SpotBox(p, into, ...)
        local box = spotBox(p, into, ...)
        if type(box) == "table" then box.blastaPlate = p end
        return box
    end
end
local Spots = DUI.Spots
local spotLayout = Spots and Spots.Layout
if spotLayout then
    function Spots.Layout(spot, grow, box, opts, ...)
        local L = spotLayout(spot, grow, box, opts, ...)
        local p = type(box) == "table" and box.blastaPlate
        if p and type(L) == "table" and (spot == "above" or spot == "below")
            and (L.point == "BOTTOM" or L.point == "TOP") then
            local g = p.hp and angled[p.hp]
            if g then
                local up = spot == "above"
                local left = tonumber(up and g.leftTop or g.leftBottom) or 0
                local right = tonumber(up and (g.rightTop or g.cutTop) or (g.rightBottom or g.cutBottom)) or 0
                L.x = (L.x or 0) + (left - right) / 2
            end
        end
        return L
    end
end

extras.Loaded("NameplateShape")
