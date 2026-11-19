-- SPDX-License-Identifier: GPL-3.0-or-later
-- Blasta bar effects: short light effects on DaylightUI's bars that play only when
-- something happens. A hit leaves the lost part behind in red while the bar
-- slides over it, a heal sparkles over exactly what was healed, a spell's cost
-- stays behind where the cost preview showed it and drains away, low health
-- beats like a heart, a full resource shimmers, and a target in execute range
-- glows like embers.
--
-- Health is secret on this client, even out of combat. Nothing here compares
-- or computes with it: invisible copies of a bar hold the health before and
-- after the last change (stored as given), and the client spans the effect
-- between their edges. UNIT_COMBAT (whose action is plain) says whether it was
-- a hit or a heal. The low-health and execute effects take their visibility
-- from curves over the health percent (the result goes straight to SetAlpha,
-- as DaylightUI's own execute mark does).
--
-- Every effect is light (additive) in Blasta's own frames above the bar and
-- its overlays (heal prediction, DoT veils, the cost preview) and below the
-- bar's texts, so all of those stay visible. Inside a bar it shares the fill's
-- masks, so slanted ends and angled edges stay clean. Animations run on the
-- client; Lua only runs when an event starts one.
local ADDON, extras = ...
local DUI = DaylightUI
local api, style = DUI.API, DUI.Style
local units = extras.Compatible("UnitFrames")
if not (api and api.On and api.Parts and style and style.FollowFill and style.ClipLike and style.AngleFill
    and style.AngleTrail and style.GetFillAngle and DUI.IsSecret and DUI.Motion and DUI.Motion.On
    and units and units.frames) then return end

local secret = DUI.IsSecret
local function number(v) return type(v) == "number" and not secret(v) end

local WHITE = "Interface\\Buttons\\WHITE8x8"
local SPARK = "Interface\\CastingBar\\UI-CastingBar-Spark"
local DOT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

-- Settings

local defaults = {
    enabled = true,
    shatter = true, shatterPlates = true, shatterStrength = 1, hitSparks = true, hitColor = { 0.72, 0.1, 0.08 },
    heal = true, healStrength = 1, healColor = { 0.55, 1, 0.65 },
    shatterParty = true, healParty = true, healTarget = true,
    spend = true, spendStrength = 1, spendOwnColor = false, spendColor = { 1, 1, 1 },
    spendTarget = true, spendParty = true, spendFocus = false, spendTargetSpark = false,
    heart = true, heartStrength = 1, heartAt = 0.35, vignette = false, vignetteStrength = 1, heartColor = { 1, 0.22, 0.18 },
    ready = true, readyStrength = 1, readyColor = { 0.88, 0.85, 1 },
    ember = true, emberPlates = true, emberStrength = 1, emberAt = 0.2, emberColor = { 1, 0.55, 0.15 },
}
extras.MomentsDefaults = defaults
local function get(key)
    local v = DUI:Get(ADDON, "moments." .. key)
    if v == nil then return defaults[key] end
    return v
end
local function enabled() return get("enabled") == true end
local function on(key) return enabled() and get(key) == true end
local function strength(key)
    local v = tonumber(get(key)) or 1
    return math.max(0, math.min(2, v))
end

-- A color setting as r, g, b ({ r, g, b } as the options save it).
local function color(key)
    local c = get(key)
    local r, g, b
    if type(c) == "table" then r, g, b = c.r or c[1], c.g or c[2], c.b or c[3] end
    if not (number(r) and number(g) and number(b)) then
        c = defaults[key]
        r, g, b = c[1], c[2], c[3]
    end
    return r, g, b
end
local function paler(r, g, b, t)
    t = t or 0.5
    return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

-- Parts made once and colored from the settings: painted now and again
-- whenever a setting changes.
local painters = {}
local function painted(fn)
    painters[#painters + 1] = fn
    fn()
end

-- Shared helpers

local function atLevel(frame, parent, plus)
    frame:SetFrameLevel(parent:GetFrameLevel() + plus)
end

-- Above the bar's own overlays (heal prediction and DoT veils sit a level or
-- two up), below a unit frame's text overlay when it has one.
local function fxLevel(bar, frame, cap)
    local level = bar:GetFrameLevel() + 3
    local overlay = frame and frame.overlay
    if overlay and overlay.GetFrameLevel then level = math.min(level, overlay:GetFrameLevel() - 1) end
    if cap then level = math.min(level, cap - 1) end
    return math.max(bar:GetFrameLevel() + 1, level)
end

local function leadOf(bar) return bar:GetReverseFill() and "LEFT" or "RIGHT" end
local function originOf(bar) return bar:GetReverseFill() and "RIGHT" or "LEFT" end
local function outward(bar) return bar:GetReverseFill() and -1 or 1 end

-- A texture over the fill that keeps the fill's angled edge (shared, and kept
-- up by every AngleFill) and the frame's slanted ends.
local function onFill(bar, tex)
    style.FollowFill(bar, tex)
    style.ClipLike(tex, bar:GetStatusBarTexture())
end

-- Bands: status bars over a part of the bar, with both ends at the fill's
-- angle and cut at the frame's ends like the fill. The client places and
-- sizes them, so secret values are fine.
local function band(fx, bar)
    local b = CreateFrame("StatusBar", nil, fx)
    b:SetStatusBarTexture(WHITE)
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    local tex = b:GetStatusBarTexture()
    tex:SetBlendMode("ADD")
    tex:SetDrawLayer("ARTWORK", 2)
    style.ClipLike(tex, bar:GetStatusBarTexture())
    b:Hide()
    return b
end

-- The frame whose slant clips bar's fill (the one ClipLike copied), and the
-- fill's own clip there.
local function clipOwner(bar)
    local fill = bar:GetStatusBarTexture()
    local frame = bar
    while frame do
        local sl = style.GetSlant(frame)
        if sl then
            for _, clip in ipairs(sl.clips) do
                if clip.tex == fill then return frame, sl, clip end
            end
        end
        frame = frame:GetParent()
    end
end

-- A texture takes at most three masks. A band angled at both of its own ends
-- (AngleFill, AngleTrail) has room for one of the frame's slanted ends only, so
-- on a bar slanted at both ends it keeps the clip at the empty end, where its
-- back can reach, and lets its angled lead edge stand in for the full end.
local function makeRoom(b, bar, left, angled)
    if not (style.GetSlant and style.ClipSpan and style.LayoutSlant) then return end
    local frame, sl, own = clipOwner(bar)
    if not frame then return end
    local only = own.only or false
    if angled and sl.side == "both" then only = left and "right" or "left" end
    if b.clipOnly == only then return end
    b.clipOnly = only
    style.ClipSpan(b:GetStatusBarTexture(), nil, nil, only)
    style.LayoutSlant(frame)
end

local function angle(b, bar, followShellOnly)
    local side, cut, under = style.GetFillAngle(bar)
    if followShellOnly then side, cut = nil, nil end
    style.AngleFill(b, side, cut, under)
    style.AngleTrail(b, side, cut, under)
end

-- Invisible copies of the bar holding a value of our choice: the health just
-- before the last change, the health now, the power now. The bar itself may
-- still be gliding (smooth bars), these never do.
local function mirror(rig, key)
    local m = rig[key]
    if not m then
        m = CreateFrame("StatusBar", nil, rig.fx)
        m:SetAllPoints(rig.bar)
        m:SetStatusBarTexture(WHITE)
        m:SetAlpha(0)
        rig[key] = m
    end
    m:SetReverseFill(rig.bar:GetReverseFill() == true)
    return m
end

-- A band between two edges along the fill: from the end of texture `a` to
-- the end of texture `z` (a mirror's fill, or the bar's own fill as drawn,
-- which glides with smooth bars). Backwards it has no size and shows nothing,
-- so a loss band stays empty on a gain and a heal band on pure overhealing.
-- The back end is cut by AngleTrail, which leans the other way from the
-- fill's own edge mask: started right at the fill's rect it would leave a
-- wedge-wide gap. Pulled back by the cut, both slanted edges meet exactly.
local function between(b, bar, a, z, geometry, followShellOnly)
    local left = bar:GetReverseFill() == true
    geometry = geometry or bar
    local _, cut = style.GetFillAngle(geometry)
    cut = (not followShellOnly and number(cut) and cut > 0) and cut or 0
    b:ClearAllPoints()
    if left then
        b:SetPoint("TOPRIGHT", a, "TOPLEFT", cut, 0)
        b:SetPoint("BOTTOMLEFT", z, "BOTTOMLEFT")
    else
        b:SetPoint("TOPLEFT", a, "TOPRIGHT", -cut, 0)
        b:SetPoint("BOTTOMRIGHT", z, "BOTTOMRIGHT")
    end
    b:SetReverseFill(left)
    makeRoom(b, bar, left, cut > 0)
    angle(b, geometry, followShellOnly)
end

-- Soft light motes: a pool of textures, each with its own animation group
-- (a gentle arc in two Translation steps and a fade). Lua only places and
-- starts them.
local function newMote(fx)
    local holder = CreateFrame("Frame", nil, fx)
    holder:Hide()
    local halo = holder:CreateTexture(nil, "OVERLAY", nil, 5)
    halo:SetTexture(DOT)
    halo:SetAllPoints(holder)
    halo:SetBlendMode("ADD")
    local core = holder:CreateTexture(nil, "OVERLAY", nil, 6)
    core:SetTexture(DOT)
    core:SetPoint("CENTER")
    core:SetBlendMode("ADD")
    local g = holder:CreateAnimationGroup()
    local drift = g:CreateAnimation("Translation")
    drift:SetOrder(1)
    drift:SetSmoothing("OUT")
    local settle = g:CreateAnimation("Translation")
    settle:SetOrder(2)
    settle:SetSmoothing("IN_OUT")
    local fade = g:CreateAnimation("Alpha")
    fade:SetOrder(2)
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0)
    fade:SetSmoothing("OUT")
    local shrink = g:CreateAnimation("Scale")
    shrink:SetOrder(2)
    shrink:SetScaleFrom(1, 1)
    shrink:SetScaleTo(0.4, 0.4)
    g:SetScript("OnFinished", function() holder:Hide() end)
    return { holder = holder, halo = halo, core = core, group = g, drift = drift, settle = settle,
        fade = fade, shrink = shrink }
end

local function float(p, anchor, point, x, y, size, r, g, b, alpha, dx, dy1, dy2, t1, t2)
    local holder = p.holder
    p.group:Stop()
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", anchor, point, x, y)
    holder:SetSize(size, size)
    holder:SetAlpha(alpha)
    p.halo:SetVertexColor(r, g, b, 0.52)
    local cr, cg, cb = paler(r, g, b, 0.7)
    p.core:SetSize(size * 0.38, size * 0.38)
    p.core:SetVertexColor(cr, cg, cb, 1)
    p.drift:SetOffset(dx * 0.6, dy1)
    p.drift:SetDuration(t1)
    p.settle:SetOffset(dx * 0.4, dy2)
    p.settle:SetDuration(t2)
    p.fade:SetFromAlpha(alpha)
    p.fade:SetDuration(t2)
    p.shrink:SetDuration(t2)
    holder:Show()
    p.group:Play()
end

local function pick(pool)
    for _, mote in ipairs(pool) do
        if not mote.group:IsPlaying() then return mote end
    end
end

-- Health curves: 1 inside [lo, hi), 0 elsewhere (also at 0, a dead unit).

local curves = {}
local function rangeCurve(lo, hi)
    local key = math.floor(lo * 1000 + 0.5) * 10000 + math.floor(hi * 1000 + 0.5)
    local c = curves[key]
    if c == nil then
        c = false
        if C_CurveUtil and C_CurveUtil.CreateCurve and hi > lo then
            local ok, made = pcall(C_CurveUtil.CreateCurve)
            if ok and made then
                if Enum and Enum.LuaCurveType and made.SetType then pcall(made.SetType, made, Enum.LuaCurveType.Linear) end
                local edge = 0.0005
                made:AddPoint(0, 0)
                made:AddPoint(math.max(edge, lo), 0)
                made:AddPoint(math.max(edge, lo) + edge, 1)
                made:AddPoint(hi - edge, 1)
                made:AddPoint(hi, 0)
                made:AddPoint(1, 0)
                c = made
            end
        end
        curves[key] = c
    end
    return c
end

-- The share of the unit's health in [lo, hi) as an alpha, maybe secret.
local function healthIn(unit, lo, hi)
    if not unit or not UnitExists(unit) then return 0 end
    local c = rangeCurve(lo, hi)
    if c and UnitHealthPercent then
        local ok, a = pcall(UnitHealthPercent, unit, true, c)
        if ok then return a end
    end
    local hp, max = UnitHealth(unit), UnitHealthMax(unit)
    if not (number(hp) and number(max) and max > 0) then return 0 end
    local f = hp / max
    return (f > 0 and f >= lo and f < hi) and 1 or 0
end

-- Rigs: one per bar we light, built on first use.

local rigs = setmetatable({}, { __mode = "k" }) -- bar -> rig

local function newRig(bar, frame)
    local rig = { bar = bar, frame = frame }
    local fx = CreateFrame("Frame", nil, bar)
    fx:SetAllPoints(bar)
    atLevel(fx, bar, 0)
    fx:SetFrameLevel(fxLevel(bar, frame))
    rig.fx = fx
    rigs[bar] = rig
    return rig
end

local function rigFor(bar, frame, cap)
    local rig = rigs[bar] or newRig(bar, frame)
    rig.fx:SetFrameLevel(fxLevel(bar, frame, cap))
    return rig
end

-- 1 · Hits: the lost part briefly lights red, with sparks at the new edge.
-- 2 · Heals: a rim lights the new edge and motes rise from it. Resource spending: the spent part
-- stays behind in the resource's color and fades the same way.
-- Every band runs from the bar's fill as it is drawn (gliding with smooth
-- bars) to a mirror holding the value before the change, so it lines up with
-- the bar, the cost preview and the heal, and overhealing shows nothing.

local function trailParts(rig)
    if rig.trail then return end
    local bar, fx = rig.bar, rig.fx

    local trail = band(fx, bar)
    local tex = trail:GetStatusBarTexture()
    tex:SetBlendMode("BLEND")
    tex:SetDrawLayer("ARTWORK", 1)
    local tg = trail:CreateAnimationGroup()
    local hold = tg:CreateAnimation("Alpha")
    hold:SetFromAlpha(0.85)
    hold:SetToAlpha(0.85)
    hold:SetDuration(0.10)
    hold:SetOrder(1)
    local fade = tg:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.85)
    fade:SetToAlpha(0)
    fade:SetDuration(0.32)
    fade:SetSmoothing("OUT")
    fade:SetOrder(2)
    tg:SetScript("OnFinished", function() trail:Hide() end)
    rig.trail, rig.trailAnim, rig.trailHold, rig.trailFade = trail, tg, hold, fade

    local gain = band(fx, bar)
    local gg = gain:CreateAnimationGroup()
    local gin = gg:CreateAnimation("Alpha")
    gin:SetFromAlpha(0)
    gin:SetToAlpha(0.55)
    gin:SetDuration(0.055)
    gin:SetOrder(1)
    local gout = gg:CreateAnimation("Alpha")
    gout:SetFromAlpha(0.55)
    gout:SetToAlpha(0)
    gout:SetDuration(0.34)
    gout:SetSmoothing("OUT")
    gout:SetOrder(2)
    gg:SetScript("OnFinished", function() gain:Hide() end)
    rig.gain, rig.gainAnim, rig.gainIn, rig.gainOut = gain, gg, gin, gout

    -- A soft line on the new edge.
    local edge = fx:CreateTexture(nil, "OVERLAY", nil, 5)
    edge:SetTexture(SPARK)
    edge:SetBlendMode("ADD")
    edge:SetAlpha(0)
    style.ClipLike(edge, bar:GetStatusBarTexture())
    local eg = edge:CreateAnimationGroup()
    local ef = eg:CreateAnimation("Alpha")
    ef:SetFromAlpha(0.7)
    ef:SetToAlpha(0)
    ef:SetDuration(0.23)
    ef:SetSmoothing("OUT")
    rig.edge, rig.edgeAnim, rig.edgeFade = edge, eg, ef

end

local function lighter(bar, t)
    local r, g, b = bar:GetStatusBarColor()
    if not (number(r) and number(g) and number(b)) then return 1, 1, 1 end
    return r + (1 - r) * t, g + (1 - g) * t, b + (1 - b) * t
end

local function barHeight(bar)
    local h = bar:GetHeight()
    if not number(h) or h <= 0 then h = 10 end
    return h
end

local function edgeOn(rig, fill, k, r, g, b)
    local bar, edge = rig.bar, rig.edge
    rig.edgeAnim:Stop()
    local h = barHeight(bar)
    local lead = leadOf(bar)
    edge:ClearAllPoints()
    edge:SetPoint("TOP", fill, "TOP" .. lead)
    edge:SetPoint("BOTTOM", fill, "BOTTOM" .. lead)
    edge:SetWidth(math.max(4, math.min(9, h * 0.35)))
    edge:SetVertexColor(paler(r, g, b, 0.45))
    rig.edgeFade:SetFromAlpha(math.min(1, 0.7 * k))
    edge:SetAlpha(0)
    rig.edgeAnim:Play()
end

-- Plays the trail from the bar's drawn edge (or `from`, the preview's made-up
-- edge) to the `before` mirror.
local function playTrail(rig, k, r, g, b, from, spending, geometry)
    local bar, trail = rig.bar, rig.trail
    rig.trailAnim:Stop()
    between(trail, bar, from or bar:GetStatusBarTexture(), rig.before:GetStatusBarTexture(), geometry)
    trail:SetStatusBarColor(r, g, b, 1)
    local a = math.min(1, (spending and 0.48 or 0.72) * k)
    rig.trailHold:SetDuration(spending and 0.06 or 0.10)
    rig.trailFade:SetDuration(spending and 0.24 or 0.32)
    rig.trailHold:SetFromAlpha(a)
    rig.trailHold:SetToAlpha(a)
    rig.trailFade:SetFromAlpha(a)
    trail:SetAlpha(a)
    trail:Show()
    rig.trailAnim:Play()
end

local function motesOff(rig, anchor, k, healing, plate, r, g, b)
    local now = GetTime()
    if not DUI.Motion.On() or now < (rig.nextMotes or 0) then return end
    rig.nextMotes = now + (plate and 0.36 or 0.16)
    local bar, dir = rig.bar, outward(rig.bar)
    local h = math.min(20, barHeight(bar))
    local count = plate and 1 or math.min(4, 2 + math.floor(k))
    if not rig.motes then
        rig.motes = {}
        for i = 1, (plate and 2 or 6) do rig.motes[i] = newMote(rig.fx) end
    end
    for i = 1, count do
        local p = pick(rig.motes)
        if not p then break end
        local dx = healing and (math.random() - 0.5) * 7 or dir * (6 + math.random() * 9)
        local dy = healing and (6 + math.random() * 6) or (1 + math.random() * 4)
        local size = (plate and 3 or 4) + math.random() * 2
        float(p, anchor, leadOf(bar), 0, (math.random() - 0.5) * h * 0.5,
            size, r, g, b, math.min(0.95, 0.7 * k), dx, dy, healing and 5 or -2,
            0.07 + math.random() * 0.04, 0.18 + math.random() * 0.12)
    end
end

-- With secret health both snapshots go to the client. Clip hit motes to the
-- intersection from the new edge to the old one, with room above and below
-- the bar for the particles. Healing produces an empty intersection.
local function playerHitMotes(rig, before, now)
    if not on("hitSparks") or not DUI.Motion.On() then return end
    local k = strength("shatterStrength")
    if k <= 0 then return end
    local bar = rig.bar
    local sparks = rig.damageMotes
    if not sparks then
        local outer = CreateFrame("Frame", nil, rig.fx)
        outer:SetClipsChildren(true)
        local inner = CreateFrame("Frame", nil, outer)
        inner:SetClipsChildren(true)
        sparks = { bar = bar, fx = inner, clip = outer }
        rig.damageMotes = sparks
    end
    local lead, origin = leadOf(bar), originOf(bar)
    atLevel(sparks.clip, rig.fx, 0)
    atLevel(sparks.fx, rig.fx, 0)
    sparks.clip:ClearAllPoints()
    sparks.clip:SetPoint("TOP" .. origin, bar, "TOP" .. origin, 0, 18)
    sparks.clip:SetPoint("BOTTOM" .. lead, before, "BOTTOM" .. lead, 0, -12)
    sparks.fx:ClearAllPoints()
    sparks.fx:SetPoint("TOP" .. origin, now, "TOP" .. lead, 0, 18)
    sparks.fx:SetPoint("BOTTOM" .. lead, bar, "BOTTOM" .. lead, 0, -12)
    local r, g, b = color("hitColor")
    r, g, b = paler(r, g, b, 0.35)
    motesOff(sparks, now, k, false, false, r, g, b)
end

local function hit(rig, plate, from)
    if not enabled() then return end
    local k = strength("shatterStrength")
    if k <= 0 or not rig.before then return end
    trailParts(rig)
    -- The lost part in red, held a moment, then gone; a few sparks rise from it.
    local r, g, b = color("hitColor")
    local fill = from or rig.bar:GetStatusBarTexture()
    playTrail(rig, k, r, g, b, fill)
    if not plate then edgeOn(rig, fill, k * 0.65, r, g, b) end
    if on("hitSparks") then
        local sr, sg, sb = paler(r, g, b, 0.35)
        motesOff(rig, fill, k, false, plate, sr, sg, sb)
    end
end

local function heal(rig, to)
    if not enabled() then return end
    local k = strength("healStrength")
    if k <= 0 or not rig.before then return end
    trailParts(rig)
    local bar, gain = rig.bar, rig.gain
    rig.gainAnim:Stop()
    local fill = to or bar:GetStatusBarTexture()
    between(gain, bar, rig.before:GetStatusBarTexture(), fill)
    local r, g, b = color("healColor")
    gain:SetStatusBarColor(r, g, b, 1)
    rig.gainIn:SetToAlpha(math.min(1, 0.55 * k))
    rig.gainOut:SetFromAlpha(math.min(1, 0.55 * k))
    -- The first animation supplies the zero-alpha start. Reset the region
    -- itself so a previous playback cannot carry its transparency over.
    gain:SetAlpha(1)
    gain:Show()
    rig.gainAnim:Play()
    edgeOn(rig, fill, k * 0.8, r, g, b)
    motesOff(rig, fill, k, true, false, r, g, b)
end

local FEEDBACK_WINDOW = 0.12

local function snapshot(rig, first, last, max)
    local before, now = mirror(rig, "before"), mirror(rig, "now")
    before:SetMinMaxValues(0, max)
    now:SetMinMaxValues(0, max)
    before:SetValue(first)
    now:SetValue(last)
    return now:GetStatusBarTexture()
end

-- The changed section as a band with the fill's angled edges and the frame's
-- slanted ends, like the player's trail. A band whose ends are swapped (a heal
-- band on a hit, either may be secret) has no size and shows nothing.
local function sectionPulse(rig, before, now, healing)
    local key = healing and "sectionHealPulse" or "sectionHitPulse"
    local pulse = rig[key]
    if not pulse then
        local b = band(rig.fx, rig.bar)
        if not healing then b:GetStatusBarTexture():SetBlendMode("BLEND") end
        local group = b:CreateAnimationGroup()
        local fade = group:CreateAnimation("Alpha")
        fade:SetDuration(0.21)
        fade:SetToAlpha(0)
        fade:SetSmoothing("OUT")
        group:SetToFinalAlpha(true)
        group:SetScript("OnFinished", function() b:Hide() end)
        pulse = { band = b, group = group, fade = fade }
        rig[key] = pulse
    end

    pulse.group:Stop()
    if healing then
        between(pulse.band, rig.bar, before, now)
    else
        between(pulse.band, rig.bar, now, before)
    end
    local r, g, b = color(healing and "healColor" or "hitColor")
    pulse.band:SetStatusBarColor(r, g, b, 1)
    local alpha = math.min(0.9, strength(healing and "healStrength" or "shatterStrength") * 0.53)
    pulse.band:SetAlpha(alpha)
    pulse.fade:SetFromAlpha(alpha)
    pulse.band:Show()
    pulse.group:Play()
end

-- Only real health updates can pair with a recent combat event. Batch changes
-- until the next paint without re-anchoring a visible trail on unrelated updates.
local function remember(rig, unit, changed)
    if not UnitExists(unit) then return end
    local max, now = UnitHealthMax(unit), UnitHealth(unit)
    local previous = rig.value
    if not changed or rig.unit ~= unit then
        rig.change, rig.feedback = nil, nil
    elseif type(previous) == "number" and not (number(previous) and number(now) and previous == now) then
        local time = GetTime()
        local change = rig.change
        if not change or time - change.time > FEEDBACK_WINDOW then
            change = { first = previous }
            rig.change = change
        end
        change.last, change.max, change.time = now, max, time
    end
    rig.value, rig.unit = now, unit
end

-- Flash the spent segment itself, with the same two angled edges as the cost
-- preview. The mirrors still determine its position after the cast finishes.
local function spendFlash(rig, fill, geometry, k, r, g, b, followShellOnly)
    if not rig.spendFlash then
        local flash = band(rig.fx, rig.bar)
        local group = flash:CreateAnimationGroup()
        local release = group:CreateAnimation("Alpha")
        release:SetOrder(1)
        release:SetDuration(0.075)
        release:SetSmoothing("OUT")
        local fade = group:CreateAnimation("Alpha")
        fade:SetOrder(2)
        fade:SetDuration(0.17)
        fade:SetToAlpha(0)
        fade:SetSmoothing("IN_OUT")
        group:SetScript("OnFinished", function() flash:Hide() end)
        rig.spendFlash = { band = flash, group = group, release = release, fade = fade }
    end
    local flash = rig.spendFlash
    local peak, afterglow = math.min(1, 0.95 * k), math.min(0.5, 0.25 * k)
    flash.group:Stop()
    between(flash.band, rig.bar, fill, rig.before:GetStatusBarTexture(), geometry, followShellOnly)
    local texture = flash.band:GetStatusBarTexture()
    local hot = CreateColor(r, g, b, 0.95)
    local tail = CreateColor(r, g, b, 0.22)
    if outward(rig.bar) > 0 then
        texture:SetGradient("HORIZONTAL", hot, tail)
    else
        texture:SetGradient("HORIZONTAL", tail, hot)
    end
    flash.band:SetAlpha(peak)
    flash.release:SetFromAlpha(peak)
    flash.release:SetToAlpha(afterglow)
    flash.fade:SetFromAlpha(afterglow)
    flash.band:Show()
    flash.group:Play()
end

local function spendSparks(rig, fill, k, r, g, b)
    local now = GetTime()
    if now < (rig.nextMotes or 0) then return end
    rig.nextMotes = now + 0.14
    if not rig.motes then
        rig.motes = {}
        for i = 1, 4 do rig.motes[i] = newMote(rig.fx) end
    end
    local direction, edge = outward(rig.bar), leadOf(rig.bar)
    local spread = math.min(3, barHeight(rig.bar) * 0.2)
    for i = -1, 1 do
        local mote = pick(rig.motes)
        if not mote then break end
        float(mote, fill, edge, 0, i * spread, i == 0 and 5.5 or 4.5,
            r, g, b, math.min(0.9, 0.8 * k), direction * (i == 0 and 21 or 13), i * 4, i * 3, 0.055, 0.17)
    end
end

local function spend(rig, from)
    if not enabled() then return end
    local k = strength("spendStrength")
    if k <= 0 or not rig.before then return end
    trailParts(rig)
    local r, g, b
    if on("spendOwnColor") then r, g, b = color("spendColor") else r, g, b = lighter(rig.bar, 0.25) end
    local fill = from or rig.bar:GetStatusBarTexture()
    local frame = rig.frame
    local geometry = frame and frame.power == rig.bar and frame.cost or rig.bar
    playTrail(rig, k, r, g, b, fill, true, geometry)
    if not DUI.Motion.On() then return end
    local lr, lg, lb = paler(r, g, b, 0.5)
    spendFlash(rig, fill, geometry, k, lr, lg, lb)
    spendSparks(rig, fill, k, lr, lg, lb)
end

-- 3 · Heartbeat: a double beat over the health fill, faster below 20%.
-- Two copies (normal and fast); a curve over the health shows one of them.

local function beatGroup(region, period, peak)
    local g = region:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    local function step(from, to, dur, order, smoothing)
        local a = g:CreateAnimation("Alpha")
        a:SetFromAlpha(from)
        a:SetToAlpha(to)
        a:SetDuration(dur)
        a:SetOrder(order)
        if smoothing then a:SetSmoothing(smoothing) end
    end
    step(0, peak, 0.05, 1)
    step(peak, peak * 0.2, period * 0.18, 2, "OUT")
    step(peak * 0.2, peak * 0.7, 0.05, 3)
    step(peak * 0.7, 0, period * 0.3, 4, "OUT")
    step(0, 0, math.max(0.05, period - 0.1 - period * 0.48), 5)
    return g
end

-- gate (alpha from the curve, maybe secret) > level (the strength) > pulse (the beat).
local function heartLayer(fx, bar, period)
    local gate = CreateFrame("Frame", nil, fx)
    gate:SetAllPoints(fx)
    gate:SetAlpha(0)
    local level = CreateFrame("Frame", nil, gate)
    level:SetAllPoints(gate)
    local tint = level:CreateTexture(nil, "ARTWORK", nil, 1)
    painted(function() local r, g, b = color("heartColor"); tint:SetColorTexture(r, g, b, 1) end)
    tint:SetBlendMode("ADD")
    onFill(bar, tint)
    local g = beatGroup(tint, period, 0.55)
    tint:SetAlpha(0)
    g:Play()
    return { gate = gate, level = level, group = g }
end

-- The screen's edge in the same rhythm (optional).
local vignette
local function vignetteParts()
    if vignette then return vignette end
    local v = {}
    for _, speed in ipairs({ "slow", "fast" }) do
        local gate = CreateFrame("Frame", nil, UIParent)
        gate:SetAllPoints(UIParent)
        gate:SetFrameStrata("BACKGROUND")
        gate:SetAlpha(0)
        gate:EnableMouse(false)
        local level = CreateFrame("Frame", nil, gate)
        level:SetAllPoints(gate)
        local pulse = CreateFrame("Frame", nil, level)
        pulse:SetAllPoints(level)
        local function edge(p1, p2, horizontal, size, flip)
            local t = pulse:CreateTexture(nil, "BACKGROUND")
            t:SetColorTexture(1, 1, 1, 1)
            t:SetPoint(p1)
            t:SetPoint(p2)
            if horizontal then t:SetHeight(size) else t:SetWidth(size) end
            painted(function()
                local r, g, b = color("heartColor")
                r, g, b = r * 0.8, g * 0.1, b * 0.1
                local a, z = CreateColor(r, g, b, 0.55), CreateColor(r, g, b, 0)
                if flip then a, z = z, a end
                t:SetGradient(horizontal and "VERTICAL" or "HORIZONTAL", a, z)
            end)
        end
        edge("BOTTOMLEFT", "BOTTOMRIGHT", true, 160, false)
        edge("TOPLEFT", "TOPRIGHT", true, 160, true)
        edge("TOPLEFT", "BOTTOMLEFT", false, 220, false)
        edge("TOPRIGHT", "BOTTOMRIGHT", false, 220, true)
        local g = beatGroup(pulse, speed == "fast" and 0.62 or 0.95, 1)
        pulse:SetAlpha(0)
        g:Play()
        v[speed] = { gate = gate, level = level }
    end
    vignette = v
    return v
end

local heartRig
local function heartUpdate(force)
    local frame = units.frames.player
    local bar = frame and frame.health
    if not bar then return end
    if not on("heart") then
        if heartRig then heartRig.slow.gate:SetAlpha(0); heartRig.fast.gate:SetAlpha(0) end
        if vignette then vignette.slow.gate:SetAlpha(0); vignette.fast.gate:SetAlpha(0) end
        return
    end
    if not heartRig then
        local rig = rigFor(bar, frame)
        heartRig = { slow = heartLayer(rig.fx, bar, 0.95), fast = heartLayer(rig.fx, bar, 0.62) }
    end
    local at = math.max(0.21, math.min(0.6, tonumber(get("heartAt")) or 0.35))
    local k = strength("heartStrength")
    heartRig.slow.level:SetAlpha(math.min(1, 0.75 * k))
    heartRig.fast.level:SetAlpha(math.min(1, k))
    local slow, fast = healthIn("player", 0.2, at), healthIn("player", 0, 0.2)
    if force then slow, fast = 0, 1 end
    heartRig.slow.gate:SetAlpha(slow)
    heartRig.fast.gate:SetAlpha(fast)
    if on("vignette") then
        local v = vignetteParts()
        local vk = strength("vignetteStrength")
        v.slow.level:SetAlpha(math.min(1, 0.6 * vk))
        v.fast.level:SetAlpha(math.min(1, 0.85 * vk))
        v.slow.gate:SetAlpha(slow)
        v.fast.gate:SetAlpha(fast)
    elseif vignette then
        vignette.slow.gate:SetAlpha(0)
        vignette.fast.gate:SetAlpha(0)
    end
end

-- 4 · Ready: a light streak across the resource and a star at its end, once,
-- when it becomes full. With secret power nothing can tell the moment it fills,
-- so then a full resource shimmers every few seconds while in combat instead
-- (a curve over the power percent opens the loop's gate).

local function readyParts(rig)
    if rig.sweep then return end
    local bar, fx = rig.bar, rig.fx
    local clip = CreateFrame("Frame", nil, fx)
    clip:SetClipsChildren(true)
    local fill = bar:GetStatusBarTexture()
    clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
    clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    local s = clip:CreateTexture(nil, "OVERLAY", nil, 4)
    s:SetTexture(SPARK)
    s:SetBlendMode("ADD")
    onFill(bar, s)
    s:ClearAllPoints()
    s:SetAlpha(0)
    local g = s:CreateAnimationGroup()
    local show = g:CreateAnimation("Alpha")
    show:SetFromAlpha(0)
    show:SetToAlpha(1)
    show:SetDuration(0.08)
    local move = g:CreateAnimation("Translation")
    move:SetDuration(0.6)
    move:SetSmoothing("IN_OUT")
    local hide = g:CreateAnimation("Alpha")
    hide:SetFromAlpha(1)
    hide:SetToAlpha(0)
    hide:SetDuration(0.15)
    hide:SetStartDelay(0.45)
    rig.sweep, rig.sweepMove, rig.sweepAnim = s, move, g
    -- The star: two crossed sparks that grow, turn and fade.
    local star = CreateFrame("Frame", nil, fx)
    star:SetSize(1, 1)
    star:SetPoint("CENTER", bar, leadOf(bar) == "RIGHT" and "RIGHT" or "LEFT", -outward(bar) * 3, 0)
    for i, rot in ipairs({ 0, math.pi / 2 }) do
        local t = star:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(SPARK)
        t:SetBlendMode("ADD")
        painted(function() local r, g, b = color("readyColor"); t:SetVertexColor(r, g, b, 1) end)
        t:SetSize(10, 34)
        t:SetPoint("CENTER")
        t:SetRotation(rot + math.pi / 4)
    end
    star:SetAlpha(0)
    local sg = star:CreateAnimationGroup()
    local pop = sg:CreateAnimation("Scale")
    pop:SetScaleFrom(0.2, 0.2)
    pop:SetScaleTo(1.2, 1.2)
    pop:SetDuration(0.5)
    pop:SetSmoothing("OUT")
    local turn = sg:CreateAnimation("Rotation")
    turn:SetDegrees(70)
    turn:SetDuration(0.5)
    local glowIn = sg:CreateAnimation("Alpha")
    glowIn:SetFromAlpha(0)
    glowIn:SetToAlpha(1)
    glowIn:SetDuration(0.12)
    local glowOut = sg:CreateAnimation("Alpha")
    glowOut:SetFromAlpha(1)
    glowOut:SetToAlpha(0)
    glowOut:SetStartDelay(0.15)
    glowOut:SetDuration(0.35)
    rig.star, rig.starAnim = star, sg
end

local function ready(rig)
    local k = strength("readyStrength")
    if k <= 0 then return end
    readyParts(rig)
    local bar = rig.bar
    local w, h = bar:GetSize()
    if not (number(w) and number(h)) then return end
    local origin, dir = originOf(bar), outward(bar)
    local s = rig.sweep
    s:ClearAllPoints()
    s:SetSize(math.max(16, h * 2.6), h * 2.2)
    s:SetPoint("CENTER", bar, origin, -dir * h * 2, 0)
    local r, g, b = paler(color("readyColor"))
    s:SetVertexColor(r, g, b, math.min(1, 0.85 * k))
    rig.sweepMove:SetOffset(dir * (w + h * 4), 0)
    rig.sweepAnim:Stop()
    rig.sweepAnim:Play()
    rig.star:SetScale(math.max(0.5, math.min(1.4, h / 14)))
    rig.starAnim:Stop()
    C_Timer.After(0.42, function()
        if not on("ready") then return end
        rig.star:SetAlpha(1)
        rig.starAnim:Play()
    end)
    rig.star:SetAlpha(0)
end

-- The loop for secret power: gate (the curve) > clip (the fill) > streak.
local fullCurve
local function powerFull()
    if fullCurve == nil then
        fullCurve = false
        if C_CurveUtil and C_CurveUtil.CreateCurve then
            local ok, made = pcall(C_CurveUtil.CreateCurve)
            if ok and made then
                if Enum and Enum.LuaCurveType and made.SetType then pcall(made.SetType, made, Enum.LuaCurveType.Linear) end
                made:AddPoint(0, 0)
                made:AddPoint(0.994, 0)
                made:AddPoint(0.995, 1)
                made:AddPoint(1, 1)
                fullCurve = made
            end
        end
    end
    if fullCurve and UnitPowerPercent then
        local ok, a = pcall(UnitPowerPercent, "player", nil, false, fullCurve)
        if ok then return a end
    end
    return 0
end

local function readyLoop(rig)
    if rig.loop then return rig.loop end
    local bar = rig.bar
    local gate = CreateFrame("Frame", nil, rig.fx)
    gate:SetAllPoints(rig.fx)
    gate:SetAlpha(0)
    local clip = CreateFrame("Frame", nil, gate)
    clip:SetClipsChildren(true)
    local fill = bar:GetStatusBarTexture()
    clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
    clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    local s = clip:CreateTexture(nil, "OVERLAY", nil, 4)
    s:SetTexture(SPARK)
    s:SetBlendMode("ADD")
    onFill(bar, s)
    s:ClearAllPoints()
    s:SetAlpha(0)
    local g = s:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    local show = g:CreateAnimation("Alpha")
    show:SetFromAlpha(0)
    show:SetToAlpha(1)
    show:SetDuration(0.08)
    show:SetOrder(1)
    local move = g:CreateAnimation("Translation")
    move:SetDuration(0.6)
    move:SetSmoothing("IN_OUT")
    move:SetOrder(1)
    local hide = g:CreateAnimation("Alpha")
    hide:SetFromAlpha(1)
    hide:SetToAlpha(0)
    hide:SetDuration(0.15)
    hide:SetStartDelay(0.45)
    hide:SetOrder(1)
    local rest = g:CreateAnimation("Alpha")
    rest:SetFromAlpha(0)
    rest:SetToAlpha(0)
    rest:SetDuration(2.4)
    rest:SetOrder(2)
    rig.loop = { gate = gate, streak = s, move = move, group = g }
    return rig.loop
end

local function readyLoopUpdate(rig, active)
    if not active then
        if rig.loop then
            rig.loop.gate:SetAlpha(0)
            rig.loop.group:Stop()
        end
        return
    end
    local loop = readyLoop(rig)
    local bar = rig.bar
    local w, h = bar:GetSize()
    if not (number(w) and number(h)) then return end
    local s = loop.streak
    s:ClearAllPoints()
    s:SetSize(math.max(16, h * 2.6), h * 2.2)
    s:SetPoint("CENTER", bar, originOf(bar), -outward(bar) * h * 2, 0)
    local r, g, b = paler(color("readyColor"))
    s:SetVertexColor(r, g, b, math.min(1, 0.7 * strength("readyStrength")))
    loop.move:SetOffset(outward(bar) * (w + h * 4), 0)
    loop.gate:SetAlpha(powerFull())
    if not loop.group:IsPlaying() then loop.group:Play() end
end

-- 5 · Execute embers: the fill's edge glows and flickers, sparks rise.
-- Always animating while shown; a curve over the health opens its gate.

local function emberLayer(rig, plate)
    if rig.ember then return rig.ember end
    local bar, fx = rig.bar, rig.fx
    local gate = CreateFrame("Frame", nil, fx)
    gate:SetAllPoints(fx)
    gate:SetAlpha(0)
    local level = CreateFrame("Frame", nil, gate)
    level:SetAllPoints(gate)
    local fill = bar:GetStatusBarTexture()
    local lead = leadOf(bar)
    local h = bar:GetHeight()
    if not number(h) or h <= 0 then h = 10 end
    -- The glow inside the fill, against its edge.
    local glow = level:CreateTexture(nil, "ARTWORK", nil, 3)
    glow:SetTexture(SPARK)
    glow:SetBlendMode("ADD")
    painted(function() glow:SetVertexColor(color("emberColor")) end)
    onFill(bar, glow)
    glow:ClearAllPoints()
    glow:SetPoint("TOP" .. lead, fill, "TOP" .. lead, 0, h * 0.2)
    glow:SetPoint("BOTTOM" .. lead, fill, "BOTTOM" .. lead, 0, -h * 0.2)
    glow:SetWidth(math.max(14, h * 2.4))
    local loops = {}
    local flicker = glow:CreateAnimationGroup()
    loops[1] = flicker
    flicker:SetLooping("BOUNCE")
    local f1 = flicker:CreateAnimation("Alpha")
    f1:SetFromAlpha(0.55)
    f1:SetToAlpha(1)
    f1:SetDuration(0.13)
    flicker:Play()
    -- Sparks rising from the edge, each on its own loop.
    local sparks = {}
    for i = 1, plate and 4 or 7 do
        local t = level:CreateTexture(nil, "OVERLAY", nil, 6)
        t:SetTexture(DOT)
        t:SetBlendMode("ADD")
        painted(function()
            local r, g, b = color("emberColor")
            t:SetVertexColor(paler(r, g, b, (i % 3) * 0.12))
        end)
        local size = (plate and 1.6 or 2) + (i % 3) * 0.7
        t:SetSize(size, size)
        t:SetPoint("CENTER", fill, lead, -outward(bar) * ((i * 5.3) % (h * 1.4)), ((i * 3.7) % h) - h / 2)
        local g = t:CreateAnimationGroup()
        g:SetLooping("REPEAT")
        local rise = g:CreateAnimation("Translation")
        rise:SetOffset(((i % 2) * 2 - 1) * (3 + i % 4), h * (1.6 + (i % 3) * 0.5))
        rise:SetDuration(0.7 + (i * 0.17) % 0.6)
        rise:SetSmoothing("OUT")
        local fade = g:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetDuration(rise:GetDuration())
        fade:SetSmoothing("IN")
        g:Play()
        sparks[i] = t
        loops[#loops + 1] = g
    end
    rig.ember = { gate = gate, level = level, loops = loops, playing = true }
    return rig.ember
end

-- Loops run only while the gate may be open: a plain 0 (clearly out of
-- range) pauses them, a secret or open gate keeps them going.
local function gateTo(layer, a)
    layer.gate:SetAlpha(a)
    local closed = number(a) and a <= 0
    if closed == not layer.playing then return end
    layer.playing = not closed
    for _, g in ipairs(layer.loops) do
        if closed then g:Stop() else g:Play() end
    end
end

local function hostile(unit)
    local ok, can = pcall(UnitCanAttack, "player", unit)
    if not ok or secret(can) then return true end
    return can == true
end

local function emberUpdate(rig, unit, plate, force)
    local wanted = on("ember") and (not plate or on("emberPlates"))
    if not wanted or not unit then
        if rig.ember then gateTo(rig.ember, 0) end
        return
    end
    if not force and not hostile(unit) then
        if rig.ember then gateTo(rig.ember, 0) end
        return
    end
    local layer = emberLayer(rig, plate)
    layer.level:SetAlpha(math.min(1, strength("emberStrength")))
    if force then gateTo(layer, 1) return end
    local at = math.max(0.05, math.min(0.5, tonumber(get("emberAt")) or 0.2))
    gateTo(layer, healthIn(unit, 0, at))
end

-- Who we watch

local watched = {}   -- unit -> { rig, frame, plate }
local plates = {}    -- plate frame -> unit
local UF = units.UF

local hooks = api.For and api.For(ADDON)
local externalPowerEnabled = { target = false, party = false, focus = false }
local externalPower = setmetatable({}, { __mode = "k" })

local function powerScope(frame)
    if frame == units.frames.target then return "target" end
    if frame == units.frames.focus then return "focus" end
    if frame.spec and frame.spec.group == "party" then return "party" end
end

-- Reuse DaylightUI's unanimated resource samples. There is no reliable cast
-- attribution for another unit, so only a readable drop produces feedback.
if hooks and hooks.Hook and UF and UF.FeedPower then
    hooks.Hook(UF, "FeedPower", function(frame, value, instant)
        local scope = powerScope(frame)
        if not externalPowerEnabled[scope] then return end
        local bar, unit = frame.power, frame.unitToken
        if frame.preview or frame.test or type(unit) ~= "string" or secret(unit) or unit == "player"
            or not bar or not number(value) then
            externalPower[frame] = nil
            return
        end
        local visible = bar:IsVisible()
        if secret(visible) or not visible then
            externalPower[frame] = nil
            return
        end
        local state = externalPower[frame]
        if state and not instant and state.bar == bar and state.unit == unit and state.value == value then return end
        local _, max = bar:GetMinMaxValues()
        local kind = UnitPowerType(unit)
        if not (number(max) and max > 0 and number(kind)) then
            externalPower[frame] = nil
            return
        end
        if not state or instant or state.bar ~= bar or state.unit ~= unit or state.kind ~= kind or state.max ~= max then
            externalPower[frame] = { bar = bar, unit = unit, kind = kind, max = max, value = value }
            return
        end

        local before = state.value
        state.value = value
        if value >= before then return end
        local now = GetTime()
        if now < (state.nextFlash or 0) then return end
        local k = strength("spendStrength") * (scope == "party" and 0.48 or 0.72)
        if k <= 0 then return end
        state.nextFlash = now + (scope == "party" and 0.24 or 0.14)
        local rig = rigFor(bar, frame)
        local fill = snapshot(rig, before, value, max)
        local r, g, b
        if on("spendOwnColor") then r, g, b = color("spendColor") else r, g, b = lighter(bar, 0.35) end
        -- The compact party shell can use two masks by itself. Share its
        -- contour and leave the interior ends clear of extra fill masks.
        spendFlash(rig, fill, bar, k, r, g, b, scope == "party")
        if scope == "target" and on("spendTargetSpark") and DUI.Motion.On() then
            if not rig.targetSpendMote then rig.targetSpendMote = newMote(rig.fx) end
            local mote = rig.targetSpendMote
            if not mote.group:IsPlaying() then
                float(mote, fill, leadOf(bar), 0, 0, 5, r, g, b, math.min(0.85, k),
                    outward(bar) * 12, 2, 2, 0.055, 0.16)
            end
        end
    end)
    local function resetPower(_, frame, _, preview)
        if not preview then externalPower[frame] = nil end
    end
    api.On("FrameUnitChanged", resetPower)
    api.On("FrameRemoved", resetPower)
end

local function watchFrames()
    for unit, w in pairs(watched) do if not w.plate then watched[unit] = nil end end
    if not enabled() then return end
    local f = units.frames.player
    if f and f.health then
        watched.player = { rig = rigFor(f.health, f), frame = f }
        if f.power then watched.player.power = rigFor(f.power, f) end
    end
    local t = units.frames.target
    if t and t.health then watched.target = { rig = rigFor(t.health, t), frame = t } end
end

-- A nameplate's texts stay above the effects. A text on a frame above the
-- bar caps the effects' level; one drawn on the bar itself is lifted onto a
-- small holder above them (same anchors, same parent chain).
local lifted = setmetatable({}, { __mode = "k" }) -- text -> holder
local function plateTexts(parts, bar)
    local base, cap, lift = bar:GetFrameLevel(), nil, nil
    for _, key in ipairs({ "healthText", "name", "level", "guild" }) do
        local fs = parts[key]
        if fs and fs.GetParent and fs.SetParent then
            local holder = lifted[fs]
            local owner = holder and holder:GetParent() or fs:GetParent()
            local level = owner and owner.GetFrameLevel and owner:GetFrameLevel()
            if not holder and number(level) and level > base + 1 then
                cap = math.min(cap or level, level)
            elseif owner then
                if not holder then
                    holder = CreateFrame("Frame", nil, owner)
                    holder:SetAllPoints(owner)
                    lifted[fs] = holder
                    fs:SetParent(holder)
                end
                lift = lift or {}
                lift[#lift + 1] = holder
            end
        end
    end
    return cap, lift
end

local function plateRig(plate)
    local parts = api.Parts(plate)
    local bar = parts and parts.health
    if not bar then return end
    local ok, cap, lift = pcall(plateTexts, parts, bar)
    if not ok then cap, lift = nil, nil end
    local rig = rigFor(bar, nil, cap)
    for _, holder in ipairs(lift or {}) do holder:SetFrameLevel(rig.fx:GetFrameLevel() + 2) end
    return rig
end

local function forgetPlate(plate)
    local unit = plates[plate]
    if unit and watched[unit] and watched[unit].plate == plate then
        local rig = watched[unit].rig
        if rig.ember then gateTo(rig.ember, 0) end
        rig.value = nil
        watched[unit] = nil
    end
    plates[plate] = nil
end

local function hitsOn() return on("shatter") or on("heal") end
local function partyHits() return on("shatter") and on("shatterParty") end
local function partyHeals() return on("heal") and on("healParty") end
local partyWatched, partyTokens = {}, {}
local healthWired = setmetatable({}, { __mode = "k" })

local function stopSections(rig)
    for _, key in ipairs({ "sectionHitPulse", "sectionHealPulse" }) do
        local pulse = rig[key]
        if pulse then
            pulse.group:Stop()
            pulse.band:Hide()
        end
    end
end

local function seedSections(watch, unit)
    stopSections(watch.rig)
    watch.sectionValue, watch.sectionMax = nil, nil
    if UnitExists(unit) then
        watch.sectionValue, watch.sectionMax = UnitHealth(unit), UnitHealthMax(unit)
    end
end

local function wireHealth(frame)
    if healthWired[frame] then return end
    healthWired[frame] = true
    frame:HookScript("OnEvent", function(self, event)
        if (event ~= "UNIT_HEALTH" and event ~= "UNIT_MAXHEALTH") or not enabled() or self.test then return end
        local unit = partyTokens[self]
        if not unit then unit = self == units.frames.player and "player" or "target" end
        local watch = partyWatched[unit] or watched[unit]
        if not watch or watch.frame ~= self then return end
        local player = unit == "player"
        local hitOn = (player and on("shatter")) or (watch.party and partyHits())
        local healOn = not player and on("heal") and (watch.party and on("healParty") or not watch.party and on("healTarget"))
        if not (hitOn or healOn) or not UnitExists(unit) then return end
        if event == "UNIT_MAXHEALTH" then return seedSections(watch, unit) end

        local rig = watch.rig
        local previous, oldMax = watch.sectionValue, watch.sectionMax
        local value, max = UnitHealth(unit), UnitHealthMax(unit)
        watch.sectionValue, watch.sectionMax = value, max
        local visible = rig.bar:IsVisible()
        if (not secret(visible) and not visible) or type(previous) ~= "number"
            or (number(max) and number(oldMax) and max ~= oldMax) then return end
        if number(previous) and number(value) then
            hitOn = hitOn and value < previous
            healOn = healOn and value > previous
            if not (hitOn or healOn) then return end
            if player then
                local fill = snapshot(rig, previous, value, max)
                hit(rig, false, fill)
                return
            end
        end

        local before, now = mirror(rig, "sectionBefore"), mirror(rig, "sectionNow")
        before:SetMinMaxValues(0, max)
        now:SetMinMaxValues(0, max)
        before:SetValue(previous)
        now:SetValue(value)
        local from, to = before:GetStatusBarTexture(), now:GetStatusBarTexture()
        if hitOn then
            sectionPulse(rig, from, to, false)
            if player then playerHitMotes(rig, from, to) end
        end
        if healOn then sectionPulse(rig, from, to, true) end
    end)
end

local function seedFixedSections()
    for _, unit in ipairs({ "player", "target" }) do
        local watch = watched[unit]
        if watch then
            wireHealth(watch.frame)
            seedSections(watch, unit)
        end
    end
end

local function forgetParty(frame)
    local unit = partyTokens[frame]
    local watch = unit and partyWatched[unit]
    if watch and watch.frame == frame then
        stopSections(watch.rig)
        partyWatched[unit] = nil
    end
    partyTokens[frame] = nil
end

local function trackParty(kind, frame, unit, preview)
    if kind ~= "party" or preview then return end
    forgetParty(frame)
    if not (partyHits() or partyHeals()) or type(unit) ~= "string" or secret(unit)
        or not unit:match("^party%d+$") or not frame.health then return end
    local previous = partyWatched[unit]
    if previous then forgetParty(previous.frame) end
    local rig = rigFor(frame.health, frame)
    partyTokens[frame] = unit
    local watch = { rig = rig, frame = frame, party = true }
    partyWatched[unit] = watch
    wireHealth(frame)
    seedSections(watch, unit)
end

local function refreshParty()
    for frame in pairs(partyTokens) do forgetParty(frame) end
    if api.Frames and (partyHits() or partyHeals()) then
        for frame, unit in api.Frames("party") do trackParty("party", frame, unit, false) end
    end
end

api.On("FrameMade", trackParty)
api.On("FrameUnitChanged", trackParty)
api.On("FrameRemoved", function(kind, frame, _, preview)
    if kind == "party" and not preview then forgetParty(frame) end
end)

local function trackPlate(kind, plate, unit, preview)
    if kind ~= "nameplate" or preview then return end
    forgetPlate(plate)
    if not enabled() then return end
    if type(unit) ~= "string" or secret(unit) then return end
    local rig = plateRig(plate)
    if not rig then return end
    plates[plate] = unit
    watched[unit] = { rig = rig, plate = plate }
    rig.value = nil
    if hitsOn() then remember(rig, unit) end
    emberUpdate(rig, unit, true)
end
api.On("FrameMade", trackPlate)
api.On("FrameUnitChanged", trackPlate)
api.On("FrameRemoved", function(kind, plate, _, preview)
    if kind == "nameplate" and not preview then forgetPlate(plate) end
end)

-- Events

local events = CreateFrame("Frame")
local inCombat = false

local function refresh(unit)
    local w = watched[unit]
    if not w then return end
    if unit == "player" then heartUpdate() else emberUpdate(w.rig, unit, w.plate ~= nil) end
end

local lastPower
local function powerCheck()
    local w = watched.player
    local rig = w and w.power
    local f = w and w.frame
    local visible = rig and f.power and f.power:IsVisible()
    if not (visible and on("ready")) then
        lastPower = nil
        if rig then readyLoopUpdate(rig, false) end
        return
    end
    local v, max = UnitPower("player"), UnitPowerMax("player")
    if number(v) and number(max) and max > 0 then
        readyLoopUpdate(rig, false)
        local full = v >= max
        if full and lastPower == false then ready(rig) end
        lastPower = full
    else
        lastPower = nil
        readyLoopUpdate(rig, inCombat)
    end
end

-- Pair successful casts with an actual resource update in either event order.
local casts, lastResource, powerDrop = {}, nil, nil
local function costs(spellID)
    if not (UF and UF.SpellCost) or secret(spellID) then return false end
    local ok, kind = pcall(UnitPowerType, "player")
    if not ok or secret(kind) then return false end
    local cost = UF.SpellCost(spellID, kind)
    return cost ~= nil and not (number(cost) and cost <= 0)
end

local function castSent(guid, spellID)
    local w = watched.player
    local rig = w and w.power
    if not (rig and on("spend") and w.frame.power:IsVisible() and costs(spellID)) then return end
    if #casts == 8 then table.remove(casts, 1) end
    if #casts == 0 then lastResource = UnitPower("player") end
    casts[#casts + 1] = { guid = not secret(guid) and guid or nil, spell = spellID, sent = GetTime() }
end

local function matchSpend()
    if not powerDrop then return end
    local w = watched.player
    if not (w and w.power and w.frame.power:IsVisible() and on("spend")) then return end
    for index, cast in ipairs(casts) do
        if cast.done and powerDrop.time >= cast.sent and math.abs(powerDrop.time - cast.done) <= FEEDBACK_WINDOW then
            local fill = snapshot(w.power, powerDrop.before, powerDrop.after, powerDrop.max)
            table.remove(casts, index)
            powerDrop = nil
            spend(w.power, fill)
            return
        end
    end
end

local function castResult(guid, spellID, succeeded)
    local now = GetTime()
    local knownGUID = not secret(guid) and guid ~= nil
    for index = #casts, 1, -1 do
        local cast = casts[index]
        if now - cast.sent > 30 or (cast.done and now - cast.done > FEEDBACK_WINDOW) then
            table.remove(casts, index)
        elseif (knownGUID and guid == cast.guid)
            or ((not knownGUID or not cast.guid) and not secret(spellID) and spellID == cast.spell) then
            if succeeded then cast.done = now else table.remove(casts, index) end
            break
        end
    end
    if succeeded then matchSpend() end
end

local function resourceChanged(token)
    if not on("spend") or #casts == 0 then return end
    local _, activeToken = UnitPowerType("player")
    if not (secret(token) or secret(activeToken)) and token and activeToken and token ~= activeToken then return end
    local value, before = UnitPower("player"), lastResource
    lastResource = value
    if type(before) ~= "number" or (number(before) and number(value) and value >= before) then return end
    powerDrop = { before = before, after = value, max = UnitPowerMax("player"), time = GetTime() }
    matchSpend()
end

local function queueFeedback(unit, watch)
    local rig = watch.rig
    if rig.feedbackQueued or not (rig.change and rig.feedback) then return end
    rig.feedbackQueued = true
    C_Timer.After(0, function()
        rig.feedbackQueued = nil
        local live = watched[unit]
        if not live or live.rig ~= rig then return end
        local visible = rig.bar:IsVisible()
        if secret(visible) or not visible then return end
        local change, feedback = rig.change, rig.feedback
        if not (change and feedback) or math.abs(change.time - feedback.time) > FEEDBACK_WINDOW then return end
        rig.feedback = nil
        local healing = feedback.action == "HEAL"
        if number(change.first) and number(change.last) then
            if (healing and change.last <= change.first) or (not healing and change.last >= change.first) then return end
        end
        rig.change = nil
        if (healing and not on("heal")) or (not healing and not on("shatter")) then return end
        local fill = snapshot(rig, change.first, change.last, change.max)
        if healing then heal(rig, fill) else hit(rig, live.plate ~= nil, fill) end
    end)
end

events:SetScript("OnEvent", function(_, event, unit, action, third, fourth)
    if event == "UNIT_COMBAT" then
        if secret(unit) or secret(action) then return end
        local w = watched[unit]
        if not w then return end
        local damage = action == "WOUND" and unit ~= "player" and on("shatter") and (not w.plate or on("shatterPlates"))
        local healing = action == "HEAL" and on("heal") and unit == "player"
        if damage or healing then
            w.rig.feedback = { action = action, time = GetTime() }
            queueFeedback(unit, w)
        end
    elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if secret(unit) then return end
        local w = watched[unit]
        if not w then return end
        if hitsOn() then
            remember(w.rig, unit, event == "UNIT_HEALTH")
            queueFeedback(unit, w)
        end
        refresh(unit)
    elseif event == "GROUP_ROSTER_UPDATE" then
        refreshParty()
    elseif event == "UNIT_SPELLCAST_SENT" then
        castSent(third, fourth) -- unit, target, cast GUID, spell ID
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        castResult(action, third, true) -- unit, cast GUID, spell ID
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        castResult(action, third, false)
    elseif event == "UNIT_POWER_FREQUENT" then
        resourceChanged(action)
        powerCheck()
    elseif event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
        wipe(casts)
        lastResource, powerDrop = nil, nil
        powerCheck()
    elseif event == "PLAYER_TARGET_CHANGED" then
        local w = watched.target
        if w then
            w.rig.value = nil
            if hitsOn() then remember(w.rig, "target") end
            seedSections(w, "target")
        end
        refresh("target")
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        inCombat = event == "PLAYER_REGEN_DISABLED"
        powerCheck()
    else
        watchFrames()
        for u, w in pairs(watched) do
            w.rig.value = nil
            if hitsOn() then remember(w.rig, u) end
            refresh(u)
        end
        seedFixedSections()
        powerCheck()
    end
end)

local function anyOn()
    for _, key in ipairs({ "shatter", "heal", "heart", "ready", "ember", "spend" }) do if on(key) then return true end end
end

local function toggle(event, wanted, unit)
    if wanted then
        if unit then events:RegisterUnitEvent(event, unit) else events:RegisterEvent(event) end
    else
        events:UnregisterEvent(event)
    end
end

local function stopTransient(rig)
    rig.fx:Hide()
    stopSections(rig)
    if rig.trailAnim then
        rig.trailAnim:Stop()
        rig.trail:Hide()
    end
    if rig.gainAnim then
        rig.gainAnim:Stop()
        rig.gain:Hide()
    end
    if rig.edgeAnim then
        rig.edgeAnim:Stop()
        rig.edge:SetAlpha(0)
    end
    if rig.spendFlash then
        rig.spendFlash.group:Stop()
        rig.spendFlash.band:Hide()
    end
    if rig.sweepAnim then
        rig.sweepAnim:Stop()
        rig.starAnim:Stop()
        rig.star:SetAlpha(0)
    end
    for _, mote in ipairs(rig.motes or {}) do
        mote.group:Stop()
        mote.holder:Hide()
    end
    if rig.damageMotes and rig.damageMotes.motes then
        for _, mote in ipairs(rig.damageMotes.motes) do
            mote.group:Stop()
            mote.holder:Hide()
        end
    end
    if rig.targetSpendMote then
        rig.targetSpendMote.group:Stop()
        rig.targetSpendMote.holder:Hide()
    end
    if rig.loop then readyLoopUpdate(rig, false) end
end

local masterActive
local function apply()
    local active = enabled()
    if masterActive ~= active then
        masterActive = active
        if active then
            for _, rig in pairs(rigs) do rig.fx:Show() end
            if api.Frames then
                for plate, unit in api.Frames("nameplate") do trackPlate("nameplate", plate, unit, false) end
            end
        else
            for _, rig in pairs(rigs) do stopTransient(rig) end
            for plate in pairs(plates) do forgetPlate(plate) end
        end
    end
    externalPowerEnabled.target = on("spend") and on("spendTarget")
    externalPowerEnabled.party = on("spend") and on("spendParty")
    externalPowerEnabled.focus = on("spend") and on("spendFocus")
    wipe(externalPower)
    watchFrames()
    seedFixedSections()
    toggle("UNIT_COMBAT", hitsOn())
    toggle("GROUP_ROSTER_UPDATE", partyHits() or partyHeals())
    refreshParty()
    local health = hitsOn() or on("heart") or on("ember")
    toggle("UNIT_HEALTH", health)
    toggle("UNIT_MAXHEALTH", health)
    toggle("PLAYER_TARGET_CHANGED", health)
    for _, e in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
        "UNIT_SPELLCAST_INTERRUPTED" }) do toggle(e, on("spend"), "player") end
    for _, e in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER" }) do
        toggle(e, on("ready") or on("spend"), "player")
    end
    if not on("spend") then
        wipe(casts)
        lastResource, powerDrop = nil, nil
    end
    toggle("PLAYER_REGEN_DISABLED", on("ready"))
    toggle("PLAYER_REGEN_ENABLED", on("ready"))
    toggle("PLAYER_ENTERING_WORLD", anyOn())
    inCombat = InCombatLockdown and InCombatLockdown() or false
    for u, w in pairs(watched) do
        if hitsOn() then remember(w.rig, u) end
        if u ~= "player" then emberUpdate(w.rig, u, w.plate ~= nil) end
    end
    heartUpdate()
    powerCheck()
    if active then
        for _, paint in ipairs(painters) do paint() end
    end
end
DUI.On("Login", apply)
DUI.On("SettingChanged", function(scope, path)
    if scope == ADDON and type(path) == "string" and path:find("^moments%.") then apply() end
end)

-- Preview: every moment once on your own frame, from made-up values.

local function fake(rig, before, now)
    local b, n = mirror(rig, "before"), mirror(rig, "now")
    b:SetMinMaxValues(0, 1)
    n:SetMinMaxValues(0, 1)
    b:SetValue(before)
    n:SetValue(now)
end

-- Previews, one per effect, on your own frame. Hits and heals put the health
-- history back afterwards, so a real hit right after lines up again.
local function own()
    watchFrames()
    local w = watched.player
    local f = w and w.frame
    if f and f.health then return w, f, w.rig end
end

local restoreAt = 0
local function restoreLater(rig, delay)
    local mark = GetTime() + delay
    restoreAt = math.max(restoreAt, mark)
    C_Timer.After(delay, function()
        if GetTime() + 0.01 < restoreAt then return end
        if hitsOn() then rig.value = nil; remember(rig, "player") end
    end)
end

local PREVIEW = {}
function PREVIEW.shatter()
    local _, _, rig = own()
    if not rig then return end
    fake(rig, 0.9, 0.62)
    hit(rig, false, rig.now:GetStatusBarTexture())
    C_Timer.After(1.1, function() fake(rig, 0.62, 0.48); hit(rig, false, rig.now:GetStatusBarTexture()) end)
    restoreLater(rig, 2.2)
end
function PREVIEW.heal()
    local _, _, rig = own()
    if not rig then return end
    fake(rig, 0.48, 0.8)
    heal(rig, rig.now:GetStatusBarTexture())
    restoreLater(rig, 1.4)
end
function PREVIEW.spend()
    local w, f = own()
    local p = w and w.power
    if not (p and f.power:IsVisible()) then return end
    fake(p, 0.75, 0.45)
    spend(p, p.now:GetStatusBarTexture())
end
function PREVIEW.ready()
    local w, f = own()
    local p = w and w.power
    if p and f.power:IsVisible() then ready(p) end
end
function PREVIEW.heart()
    if not own() then return end
    heartUpdate(true)
    C_Timer.After(3.2, function() heartUpdate() end)
end
function PREVIEW.ember()
    local _, _, rig = own()
    if not rig then return end
    emberUpdate(rig, "player", false, true)
    C_Timer.After(3.2, function() if rig.ember then gateTo(rig.ember, 0) end end)
end

-- Options

local L = {
    ["Bar effects"] = "Leisten-Effekte",
    ["Enable bar effects"] = "Leisten-Effekte aktivieren",
    ["Turn all Blasta bar effects on or off without changing individual settings."] =
        "Schaltet alle Blasta-Leisten-Effekte gemeinsam ein oder aus. Die einzelnen Einstellungen bleiben gespeichert.",
    ["Damage & healing"] = "Schaden & Heilung",
    ["Resource"] = "Ressource",
    ["Warnings"] = "Warnungen",
    ["Damage taken"] = "Erlittener Schaden",
    ["Show damage taken"] = "Erlittenen Schaden zeigen",
    ["The lost part of the health bar is underlaid in red for a moment, then fades out."] =
        "Das verlorene Stück der Lebensleiste wird kurz rot unterlegt und blendet dann aus.",
    ["Sparks"] = "Funken",
    ["A few sparks rise from the lost part."] = "Aus dem verlorenen Stück steigen ein paar Funken auf.",
    ["Also on nameplates"] = "Auch auf Namensplaketten",
    ["Color"] = "Farbe",
    ["Strength"] = "Stärke",
    ["Preview"] = "Vorschau",
    ["Play"] = "Abspielen",
    ["Plays the effect once on your own frame."] = "Spielt den Effekt einmal auf deinem eigenen Rahmen ab.",
    ["Healing"] = "Heilung",
    ["Show healing"] = "Heilung zeigen",
    ["Damage feedback on party frames"] = "Trefferfeedback auf Gruppenrahmen",
    ["Healing feedback on party frames"] = "Heilfeedback auf Gruppenrahmen",
    ["Healing feedback on target"] = "Heilfeedback beim Ziel",
    ["Only the part that was really healed glows, and sparks rise from it. Overhealing and heals at full health show nothing."] =
        "Nur der tatsächlich geheilte Abschnitt leuchtet auf, Funken steigen auf. Überheilung und Heilung bei vollem Leben zeigen nichts.",
    ["Spending"] = "Verbrauch",
    ["Show spending"] = "Verbrauch zeigen",
    ["Resource drops on target"] = "Ressourcenabzug beim Ziel",
    ["Resource drops on party"] = "Ressourcenabzug in der Gruppe",
    ["Resource drops on focus"] = "Ressourcenabzug beim Fokus",
    ["Spark on target"] = "Funke beim Ziel",
    ["Briefly flashes the lost part when the game exposes a resource drop."] =
        "Lässt den verlorenen Abschnitt kurz aufleuchten, wenn das Spiel den Ressourcenabzug bereitstellt.",
    ["After a successful cast, the spent part lights up when the resource value drops."] =
        "Nach einem erfolgreichen Zauber leuchtet der verbrauchte Abschnitt auf, sobald der Ressourcenwert sinkt.",
    ["Own color"] = "Eigene Farbe",
    ["Off: a lighter shade of the resource's own color."] = "Aus: eine hellere Variante der Ressourcenfarbe.",
    ["Full resource"] = "Volle Ressource",
    ["Shimmer when full"] = "Schimmern, wenn voll",
    ["A light streak and a star when your resource becomes full. Where the game keeps your resource secret, a full resource shimmers every few seconds in combat instead."] =
        "Ein Lichtschweif und ein Stern, sobald deine Ressource voll ist. Hält das Spiel die Werte geheim, schimmert eine volle Ressource im Kampf stattdessen alle paar Sekunden.",
    ["Low health"] = "Wenig Leben",
    ["Heartbeat"] = "Herzschlag",
    ["Below the threshold your health bar beats in a double rhythm, faster below 20%."] =
        "Unter der Schwelle schlägt deine Lebensleiste im Doppelrhythmus, unter 20 % schneller.",
    ["Starts below"] = "Beginnt unter",
    ["Also on the screen's edge"] = "Auch am Bildschirmrand",
    ["The screen's edge turns red in the same rhythm."] = "Der Bildschirmrand färbt sich im selben Takt.",
    ["Screen edge strength"] = "Stärke am Bildschirmrand",
    ["Execute range"] = "Execute-Bereich",
    ["Embers"] = "Glut",
    ["Below the threshold the target's bar glows at its edge and embers rise."] =
        "Unter der Schwelle glüht die Kante der Zielleiste und Funken steigen auf.",
}
for en, de in pairs(L) do extras.German[en] = de end

local function item(kind, key, label, fields)
    local row = fields or {}
    row.type, row.key, row.label = kind, "moments." .. key, label
    row.get = function() return get(key) end
    row.set = function(v)
        return DUI:Set(ADDON, "moments." .. key, v)
    end
    if key ~= "enabled" then
        local disabled = row.disabled
        row.disabled = function(...) return not enabled() or (disabled and disabled(...) == true) end
    end
    row.default = function() return defaults[key] end
    return row
end
local function off(key) return function() return not on(key) end end
local function slider(key, label, parent, low, high, step)
    return item("slider", key, label, { min = low or 0.25, max = high or 2, step = step or 0.05, unit = "%", disabled = off(parent) })
end
local function paint(key, parent, disabled)
    return item("color", key, "Color", { disabled = disabled or off(parent) })
end
local function play(which, parent)
    return { type = "button", label = "Preview", text = "Play", desc = "Plays the effect once on your own frame.",
        func = PREVIEW[which], disabled = off(parent) }
end

-- One card per effect: its switch first, then what it changes, then a
-- button to see it. Tabs sort them by what they react to.
local function card(tab, label, items) return { label = label, tab = tab, items = items } end
function extras.BarEffectsPage()
    return { id = "barEffects", label = "Bar effects", groups = {
        card("General", "Bar effects", {
            item("toggle", "enabled", "Enable bar effects", {
                desc = "Turn all Blasta bar effects on or off without changing individual settings." }),
        }),
        card("Damage & healing", "Damage taken", {
            item("toggle", "shatter", "Show damage taken", { desc = "The lost part of the health bar is underlaid in red for a moment, then fades out." }),
            item("toggle", "hitSparks", "Sparks", { desc = "A few sparks rise from the lost part.", disabled = off("shatter") }),
            item("toggle", "shatterPlates", "Also on nameplates", { disabled = off("shatter") }),
            item("toggle", "shatterParty", "Damage feedback on party frames", { disabled = off("shatter") }),
            paint("hitColor", "shatter"),
            slider("shatterStrength", "Strength", "shatter"),
            play("shatter", "shatter"),
        }),
        card("Damage & healing", "Healing", {
            item("toggle", "heal", "Show healing", { desc = "Only the part that was really healed glows, and sparks rise from it. Overhealing and heals at full health show nothing." }),
            item("toggle", "healParty", "Healing feedback on party frames", { disabled = off("heal") }),
            item("toggle", "healTarget", "Healing feedback on target", { disabled = off("heal") }),
            paint("healColor", "heal"),
            slider("healStrength", "Strength", "heal"),
            play("heal", "heal"),
        }),
        card("Resource", "Spending", {
            item("toggle", "spend", "Show spending", { desc = "After a successful cast, the spent part lights up when the resource value drops." }),
            item("toggle", "spendTarget", "Resource drops on target", { disabled = off("spend"),
                desc = "Briefly flashes the lost part when the game exposes a resource drop." }),
            item("toggle", "spendTargetSpark", "Spark on target", {
                disabled = function() return not (on("spend") and on("spendTarget")) end }),
            item("toggle", "spendParty", "Resource drops on party", { disabled = off("spend") }),
            item("toggle", "spendFocus", "Resource drops on focus", { disabled = off("spend") }),
            item("toggle", "spendOwnColor", "Own color", { desc = "Off: a lighter shade of the resource's own color.", disabled = off("spend") }),
            paint("spendColor", "spend", function() return not (on("spend") and on("spendOwnColor")) end),
            slider("spendStrength", "Strength", "spend"),
            play("spend", "spend"),
        }),
        card("Resource", "Full resource", {
            item("toggle", "ready", "Shimmer when full", { desc = "A light streak and a star when your resource becomes full. Where the game keeps your resource secret, a full resource shimmers every few seconds in combat instead." }),
            paint("readyColor", "ready"),
            slider("readyStrength", "Strength", "ready"),
            play("ready", "ready"),
        }),
        card("Warnings", "Low health", {
            item("toggle", "heart", "Heartbeat", { desc = "Below the threshold your health bar beats in a double rhythm, faster below 20%." }),
            slider("heartAt", "Starts below", "heart", 0.25, 0.6, 0.05),
            paint("heartColor", "heart"),
            slider("heartStrength", "Strength", "heart"),
            item("toggle", "vignette", "Also on the screen's edge", { desc = "The screen's edge turns red in the same rhythm.",
                disabled = off("heart") }),
            item("slider", "vignetteStrength", "Screen edge strength", { min = 0.25, max = 2, step = 0.05, unit = "%",
                disabled = function() return not (on("heart") and on("vignette")) end }),
            play("heart", "heart"),
        }),
        card("Warnings", "Execute range", {
            item("toggle", "ember", "Embers", { desc = "Below the threshold the target's bar glows at its edge and embers rise." }),
            item("toggle", "emberPlates", "Also on nameplates", { disabled = off("ember") }),
            slider("emberAt", "Starts below", "ember", 0.05, 0.35, 0.01),
            paint("emberColor", "ember"),
            slider("emberStrength", "Strength", "ember"),
            play("ember", "ember"),
        }),
    } }
end
