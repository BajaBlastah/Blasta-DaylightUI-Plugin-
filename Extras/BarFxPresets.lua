-- SPDX-License-Identifier: GPL-3.0-or-later
-- Blasta bar animation presets for DaylightUI's bar animations (BarFx):
-- Frost, Arcane, Holy, Nature, Shadowflame, Lava, Radiance, Wild, Storm and
-- Poison, and "By class", which gives each class its own.
-- Registered with BarFx.Add, so they show up in every "Bar animation" choice
-- Daylight offers: unit frames, party, nameplates, cast bars, swing timer and
-- the Cooldown Manager. Each preset's art is a flipbook sheet (Media\BarFx,
-- made by Blasta-QA/make_frost.py and make_presets.py) held at the fill's
-- moving end at a fixed size, slanted like that end and cut by the fill's
-- masks. The client plays it; no Lua runs while a bar sits there,
-- and nothing reads the bar's value (health is secret on this client).
local ADDON, extras = ...
local DUI = DaylightUI
local BarFx, Style = DUI and DUI.BarFx, DUI and DUI.Style
if not (BarFx and BarFx.Add and BarFx.DEFS and BarFx.STYLES and BarFx.FX_SUB
    and Style and Style.FollowFill and Style.SameMasks and Style.GetFillAngle) then return end

local ART = "Interface\\AddOns\\" .. ADDON .. "\\Media\\BarFx\\"
local FLASH_ART = ART .. "blasta-flash.png"
local SOLID = "Interface\\Buttons\\WHITE8X8"

-- Sheet layout: 256 frames in 8 columns x 32 rows, each frame stored at half
-- its shown width (the client stretches it back), so presets play at 40 to
-- 60 frames a second. A tall frame spans 8 bar heights, a thin one (bars
-- under 13 px) 16, the flash 4.
local SHEET = { frames = 256, columns = 8 }
local REACH = { tall = 8, thin = 16, flash = 4, thinBelow = 13 }
local FLASH = { heal = 0.95, hit = 0.7, seconds = 0.45 }

local function artFor(name, thin, mirrored)
    local file = "barfx-" .. name
    if thin then file = file .. "-thin" end
    if mirrored then file = file .. "-l" end
    return ART .. file .. ".png"
end

-- Which end of the bar the fill grows toward, the anchors of that end, and
-- the sign that points from it back into the fill.
local ENDS = {
    right = { top = "TOPRIGHT", bottom = "BOTTOMRIGHT", inward = -1 },
    left = { top = "TOPLEFT", bottom = "BOTTOMLEFT", inward = 1 },
}

-- The fill's angled end: one pair of corners (top or bottom) sits back by
-- cut pixels. The texture leans the same way.
local CORNERS = {
    top = { UPPER_LEFT_VERTEX or 1, UPPER_RIGHT_VERTEX or 3 },
    bottom = { LOWER_LEFT_VERTEX or 2, LOWER_RIGHT_VERTEX or 4 },
}
local function slant(tex, edge, cut, under)
    for _, pair in pairs(CORNERS) do
        for _, v in ipairs(pair) do tex:SetVertexOffset(v, 0, 0) end
    end
    if cut and cut > 0 then
        local shift = edge.inward * cut
        for _, v in ipairs(CORNERS[under and "top" or "bottom"]) do tex:SetVertexOffset(v, shift, 0) end
    end
end

-- A texture laid over the fill, a given width back from its moving end.
local function stick(tex, fill, edge, width, gap)
    local dx = edge.inward * (gap or 0)
    tex:ClearAllPoints()
    tex:SetPoint(edge.top, fill, edge.top, dx, 0)
    tex:SetPoint(edge.bottom, fill, edge.bottom, dx, 0)
    tex:SetWidth(width)
end

local function mix(a, b, k)
    return { a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k }
end

-- The colour to light with; a fill whose colours are secret lights in the accent.
local function baseColor(hi)
    if hi then return hi end
    if Style.AccentPair then
        local _, second = Style.AccentPair()
        if second then return second end
    end
    if Style.Accent then return { Style.Accent() } end
    return { 1, 1, 1 }
end

-- A preset's piece on one bar: its textures, one animation group playing the
-- sheets in step, and the flash with its own fade.
local Piece = {}
Piece.__index = Piece

local function newTexture(piece, blend)
    local tex = piece.bar:CreateTexture(nil, "ARTWORK", nil, BarFx.FX_SUB)
    tex:SetBlendMode(blend)
    Style.FollowFill(piece.bar, tex)
    piece.all[#piece.all + 1] = tex
    return tex
end

function Piece.new(bar, look)
    local piece = setmetatable({ bar = bar, look = look, all = {} }, Piece)
    piece.sheet = newTexture(piece, look.blend or "ADD")
    if look.glow then piece.glow = newTexture(piece, "ADD") end
    piece.flash = newTexture(piece, "ADD")
    piece.flash:SetTexture(FLASH_ART, "CLAMP", "CLAMP")
    piece.flash:SetAlpha(0)
    piece.rim = newTexture(piece, "ADD")
    piece.rim:SetTexture(SOLID)
    piece.anim = bar:CreateAnimationGroup()
    piece.anim:SetLooping("REPEAT")
    for _, tex in ipairs({ piece.sheet, piece.glow }) do
        local book = piece.anim:CreateAnimation("FlipBook")
        book:SetTarget(tex)
        book:SetDuration(look.loop)
        book:SetFlipBookRows(SHEET.frames / SHEET.columns)
        book:SetFlipBookColumns(SHEET.columns)
        book:SetFlipBookFrames(SHEET.frames)
        book:SetFlipBookFrameWidth(0)
        book:SetFlipBookFrameHeight(0)
    end
    -- The flash fades on the client's own animation: no Lua per frame.
    piece.fade = piece.flash:CreateAnimationGroup()
    piece.fadeAlpha = piece.fade:CreateAnimation("Alpha")
    piece.fadeAlpha:SetToAlpha(0)
    piece.fadeAlpha:SetDuration(FLASH.seconds)
    piece.fadeAlpha:SetSmoothing("OUT")
    return piece
end

function Piece:Arrange(height)
    local bar = self.bar
    local fill = bar:GetStatusBarTexture()
    local mirrored = bar.GetReverseFill ~= nil and bar:GetReverseFill() == true
    local edge = ENDS[mirrored and "left" or "right"]
    local thin = height < REACH.thinBelow
    local art = (thin and "thin" or "tall") .. (mirrored and "L" or "R")
    if self.art ~= art then
        self.art = art
        self.sheet:SetTexture(artFor(self.look.name, thin, mirrored), "CLAMP", "CLAMP")
        if self.glow then self.glow:SetTexture(artFor(self.look.glow, thin, mirrored), "CLAMP", "CLAMP") end
        if mirrored then self.flash:SetTexCoord(1, 0, 0, 1) else self.flash:SetTexCoord(0, 1, 0, 1) end
    end
    local reach = height * (thin and REACH.thin or REACH.tall)
    stick(self.sheet, fill, edge, reach)
    if self.glow then stick(self.glow, fill, edge, reach) end
    stick(self.flash, fill, edge, height * REACH.flash)
    local px = 1
    if DUI.Pixel and DUI.Pixel.Px then px = DUI.Pixel.Px(bar, 1) end
    stick(self.rim, fill, edge, thin and px or 2 * px, px)
    local _, cut, under = Style.GetFillAngle(bar)
    for _, tex in ipairs(self.all) do slant(tex, edge, cut or 0, under == true) end
end

function Piece:SetPlaying(on, speed)
    local starting = on and not self.on
    self.on = on
    for _, tex in ipairs(self.all) do tex:SetShown(on) end
    if not on then self.anim:Stop(); return end
    -- Coming on starts the loop over; a repaint while on lets it run.
    if starting then self.anim:Stop() end
    self.anim:Play()
    if self.anim.SetAnimationSpeedMultiplier then
        self.anim:SetAnimationSpeedMultiplier(math.max(0.05, speed or 1))
    end
end

function Piece:Tint(lo, hi, strength)
    local fill = self.bar:GetStatusBarTexture()
    for _, tex in ipairs(self.all) do Style.SameMasks(tex, fill, true) end
    local sheet, rim, flash, glow = self.look.tints(baseColor(hi))
    self.sheet:SetVertexColor(sheet[1], sheet[2], sheet[3], strength)
    if self.glow and glow then self.glow:SetVertexColor(glow[1], glow[2], glow[3], strength) end
    self.rim:SetVertexColor(rim[1], rim[2], rim[3], strength * 0.85)
    self.flash:SetVertexColor(flash[1], flash[2], flash[3], 1)
end

function Piece:Flash(dir, size)
    local peak = math.min(1, (dir > 0 and FLASH.heal or FLASH.hit) * (size or 1))
    self.fade:Stop()
    self.fadeAlpha:SetFromAlpha(peak)
    self.fade:Play()
end

-- One preset, in the shape BarFx.Add takes. look: name (its sheets), loop
-- (seconds), tints(hi) -> sheet, rim, flash and glow colours, blend ("ADD",
-- or "BLEND" for a sheet that darkens), glow (a second, added sheet).
local function preset(name, loop, tints, blend, glow)
    local look = { name = name, loop = loop, tints = tints, blend = blend, glow = glow }
    local key = "blasta" .. name
    return {
        build = function(s)
            local piece = Piece.new(s.bar, look)
            -- The client stops animations on hidden frames: start again on show.
            s.bar:HookScript("OnShow", function()
                if piece.on and s.style == key then
                    piece.on = false
                    piece:SetPlaying(true, s.speed)
                end
            end)
            return piece
        end,
        layout = function(s, piece, w, h) piece:Arrange(h) end,
        paint = function(s, piece, lo, hi, strength) piece:Tint(lo, hi, strength) end,
        show = function(s, piece, on) piece:SetPlaying(on, s.speed) end,
        kick = function(s, piece, dir, size) piece:Flash(dir, size) end,
    }
end

local German = {
    ["Frost (Blasta)"] = "Frost (Blasta)", ["Arcane (Blasta)"] = "Arkan (Blasta)",
    ["Holy (Blasta)"] = "Heilig (Blasta)", ["Shadow (Blasta)"] = "Schatten (Blasta)",
    ["Nature (Blasta)"] = "Natur (Blasta)", ["By class (Blasta)"] = "Nach Klasse (Blasta)",
    ["Shadowflame (Blasta)"] = "Schattenflamme (Blasta)", ["Lava (Blasta)"] = "Lava (Blasta)",
    ["Radiance (Blasta)"] = "Strahlen (Blasta)", ["Wild (Blasta)"] = "Wildnis (Blasta)",
    ["Storm (Blasta)"] = "Sturm (Blasta)", ["Poison (Blasta)"] = "Gift (Blasta)",
}
local labels = {}
local function label(key, text)
    labels[key] = text
    if extras and extras.German then extras.German[text] = German[text] end
    return extras and extras.Translate and extras.Translate(text) or text
end
-- Blasta's language is known for sure once its saved settings are in.
DUI.RegisterEvent("ADDON_LOADED", function(_, name)
    if name ~= ADDON or not (extras and extras.Translate) then return end
    for key, text in pairs(labels) do
        if BarFx.STYLES[key] then BarFx.STYLES[key] = extras.Translate(text) end
    end
end)

-- Frost: a cold shimmer on the end, fine rime creeping in and out along it,
-- glints on the longer needles and snow drifting back through the fill.
local ICE, ICE_WHITE = { 0.72, 0.9, 1 }, { 0.92, 0.98, 1 }
BarFx.Add("blastafrost", label("blastafrost", "Frost (Blasta)"), preset("frost", 4.8, function(hi)
    local cold = mix(hi, ICE, 0.7)
    return mix(cold, ICE_WHITE, 0.35), ICE_WHITE, mix(cold, ICE_WHITE, 0.6)
end))

-- Arcane: runes drifting back through the fill and fading out, motes, and
-- small arcs crackling on the end.
local ARCANE, ARCANE_WHITE = { 0.78, 0.5, 1 }, { 0.98, 0.9, 1 }
BarFx.Add("blastaarcane", label("blastaarcane", "Arcane (Blasta)"), preset("arcane", 4.2, function(hi)
    local magic = mix(hi, ARCANE, 0.75)
    return mix(magic, ARCANE_WHITE, 0.25), ARCANE_WHITE, mix(magic, ARCANE_WHITE, 0.55)
end))

-- Holy: soft slanted rays gliding back through the fill, twinkling glitter and
-- a warm end.
local HOLY, HOLY_WHITE = { 1, 0.82, 0.45 }, { 1, 0.98, 0.88 }
BarFx.Add("blastaholy", label("blastaholy", "Holy (Blasta)"), preset("holy", 5.2, function(hi)
    local gold = mix(hi, HOLY, 0.75)
    return mix(gold, HOLY_WHITE, 0.3), HOLY_WHITE, mix(gold, HOLY_WHITE, 0.6)
end))

-- Nature: leaves tumbling back through the fill, green motes, and vines
-- curling out of the end and back.
local LEAF, LEAF_LIGHT = { 0.55, 1, 0.45 }, { 0.9, 1, 0.82 }
BarFx.Add("blastanature", label("blastanature", "Nature (Blasta)"), preset("nature", 5.6, function(hi)
    local green = mix(hi, LEAF, 0.7)
    return mix(green, LEAF_LIGHT, 0.25), LEAF_LIGHT, mix(green, LEAF_LIGHT, 0.55)
end))

-- Shadowflame: violet flames licking back from the end over a light dark
-- smoke. The smoke darkens the fill (BLEND); the flames are a second, added
-- sheet in step with it.
local SMOKE, VIOLET, VIOLET_WHITE = { 1, 1, 1 }, { 0.72, 0.45, 1 }, { 0.95, 0.88, 1 }
BarFx.Add("blastashadow", label("blastashadow", "Shadowflame (Blasta)"), preset("shadow", 6, function(hi)
    local flame = mix(hi, VIOLET, 0.75)
    return SMOKE, mix(flame, VIOLET_WHITE, 0.3), mix(flame, VIOLET_WHITE, 0.5), mix(flame, VIOLET_WHITE, 0.15)
end, "BLEND", "shadowglow"))

-- Lava: molten rock glowing on the end and flowing slowly back, cracks glowing
-- through the cooling crust behind it, and heat bubbles swelling and popping.
local MOLTEN, MOLTEN_HOT = { 1, 0.55, 0.2 }, { 1, 0.9, 0.62 }
BarFx.Add("blastalava", label("blastalava", "Lava (Blasta)"), preset("lava", 6.4, function(hi)
    local hot = mix(hi, MOLTEN, 0.8)
    return mix(hot, MOLTEN_HOT, 0.2), MOLTEN_HOT, mix(hot, MOLTEN_HOT, 0.5)
end))

-- Radiance: a golden seal turning on the end, a shield of light swelling over
-- it, and sparks of light lifting off and drifting back.
local GOLD, GOLD_WHITE = { 1, 0.8, 0.4 }, { 1, 0.97, 0.85 }
BarFx.Add("blastaradiance", label("blastaradiance", "Radiance (Blasta)"), preset("radiance", 6.4, function(hi)
    local gold = mix(hi, GOLD, 0.8)
    return mix(gold, GOLD_WHITE, 0.25), GOLD_WHITE, mix(gold, GOLD_WHITE, 0.6)
end))

-- Wild: arrows whistling back through the fill with streaks behind them,
-- feathers tumbling after, and a warm amber end.
local AMBER, AMBER_LIGHT = { 1, 0.7, 0.32 }, { 1, 0.94, 0.8 }
BarFx.Add("blastawild", label("blastawild", "Wild (Blasta)"), preset("wild", 5.2, function(hi)
    local amber = mix(hi, AMBER, 0.7)
    return mix(amber, AMBER_LIGHT, 0.3), AMBER_LIGHT, mix(amber, AMBER_LIGHT, 0.55)
end))

-- Storm: forked lightning leaping back from the end now and then, its
-- afterglow fading, and rain slanting through the fill.
local STORM, STORM_WHITE = { 0.5, 0.75, 1 }, { 0.92, 0.97, 1 }
BarFx.Add("blastastorm", label("blastastorm", "Storm (Blasta)"), preset("storm", 6, function(hi)
    local sky = mix(hi, STORM, 0.75)
    return mix(sky, STORM_WHITE, 0.35), STORM_WHITE, mix(sky, STORM_WHITE, 0.65)
end))

-- Poison: toxic bubbles rising and popping by the end, drops of venom dripping
-- back through the fill, and a sickly green haze.
local VENOM, VENOM_LIGHT = { 0.55, 1, 0.25 }, { 0.9, 1, 0.75 }
BarFx.Add("blastapoison", label("blastapoison", "Poison (Blasta)"), preset("poison", 5.6, function(hi)
    local venom = mix(hi, VENOM, 0.75)
    return mix(venom, VENOM_LIGHT, 0.2), VENOM_LIGHT, mix(venom, VENOM_LIGHT, 0.5)
end))

-- By class: a player's bars wear that player's class preset (yours, a target
-- or focus who is a player, party members); NPCs, and bars with no unit (cast
-- bar, swing timer, Cooldown Manager), wear yours. It hands each call on to
-- that preset, swaps presets when the bar's unit changes, and restarts the
-- animation when the bar shows again (the preset's own restart looks for its
-- own key).
local BY_CLASS = {
    MAGE = "blastafrost", WARRIOR = "blastalava", PRIEST = "blastaholy", PALADIN = "blastaradiance",
    WARLOCK = "blastashadow", ROGUE = "blastapoison", DRUID = "blastanature", HUNTER = "blastawild",
    SHAMAN = "blastastorm", DEATHKNIGHT = "blastafrost", MONK = "blastanature",
    DEMONHUNTER = "blastashadow", EVOKER = "blastaarcane",
}
local secret = DUI.IsSecret or function() return false end
local function plain(v) return v ~= nil and not secret(v) end

local function classOf(unit)
    if type(unit) == "string" and plain(unit) then
        local isPlayer = UnitIsPlayer and UnitIsPlayer(unit)
        if plain(isPlayer) and isPlayer then
            local _, class = UnitClass(unit)
            if type(class) == "string" and plain(class) then return class end
        end
    end
    local _, class = UnitClass("player")
    return plain(class) and class or nil
end

local function presetKey(unit)
    local key = BY_CLASS[classOf(unit) or ""]
    if key and BarFx.DEFS[key] then return key end
    return "blastaarcane"
end

local byClass = setmetatable({}, { __mode = "k" })   -- tracked bar state -> its piece

-- Puts the preset the bar's unit calls for on it, hiding the one before.
local function choose(s, p)
    local key = presetKey(s.unit)
    if p.key == key then return end
    local old = p.key and p.pieces[p.key]
    if old and old.on then BarFx.DEFS[p.key].show(s, old, false) end
    p.key, p.inner = key, BarFx.DEFS[key]
    p.pieces[key] = p.pieces[key] or p.inner.build(s)
    p.piece = p.pieces[key]
    p.anim = p.piece.anim
    local w, h = s.bar:GetWidth(), s.bar:GetHeight()
    if type(w) == "number" and w > 0 then p.inner.layout(s, p.piece, w, h) end
    if p.on then
        if p.colors then p.inner.paint(s, p.piece, p.colors[1], p.colors[2], p.colors[3]) end
        p.inner.show(s, p.piece, true)
    end
end

BarFx.Add("blastaclass", label("blastaclass", "By class (Blasta)"), {
    build = function(s)
        local p = { pieces = {} }
        byClass[s] = p
        s.bar:HookScript("OnShow", function()
            local piece = p.piece
            if s.style == "blastaclass" and piece and piece.on then
                if piece.anim then piece.anim:Stop() end
                p.inner.show(s, piece, true)
            end
        end)
        choose(s, p)
        return p
    end,
    layout = function(s, p, w, h) choose(s, p); p.inner.layout(s, p.piece, w, h) end,
    paint = function(s, p, lo, hi, alpha)
        p.colors = { lo, hi, alpha }
        choose(s, p)
        return p.inner.paint(s, p.piece, lo, hi, alpha)
    end,
    show = function(s, p, on)
        p.on = on
        choose(s, p)
        p.anim = p.piece.anim
        p.inner.show(s, p.piece, on)
    end,
    kick = function(s, p, dir, size) if p.inner.kick then p.inner.kick(s, p.piece, dir, size) end end,
})

-- Blasta's presets are picked on Blasta's own pages ("Blasta animation" on
-- each bar's card there), not in DaylightUI's "Bar animation" choice: they
-- stay registered (BarFx.STYLES, BarFx.DEFS), so bars can wear them, but
-- leave DaylightUI's list (BarFx.ORDER). Each bar keeps its pick next to its
-- own settings (base .. ".blastaStyle"); while one is set it plays instead of
-- DaylightUI's.
local OWN_KEY = "blastaStyle"
local OWN, ownOrder = {}, {}
do
    local kept = {}
    for _, key in ipairs(BarFx.ORDER) do
        if labels[key] then OWN[key] = true; ownOrder[#ownOrder + 1] = key else kept[#kept + 1] = key end
    end
    for i = #BarFx.ORDER, 1, -1 do BarFx.ORDER[i] = nil end
    for i, key in ipairs(kept) do BarFx.ORDER[i] = key end
end
local OFF_LABEL = "Off: DaylightUI's animation"
if extras.German then extras.German[OFF_LABEL] = "Aus: DaylightUIs Animation" end
local function ownChoices()
    local values, order = { none = extras.Translate(OFF_LABEL) }, { "none" }
    for _, key in ipairs(ownOrder) do values[key] = BarFx.STYLES[key]; order[#order + 1] = key end
    return values, order
end
local function ownStyle(s)
    if s.force then return nil end
    local own = BarFx.Get(s, OWN_KEY)
    if OWN[own] and DUI.Motion and DUI.Motion.On and DUI.Motion.On() then return own end
end

-- Bars that wore a Blasta preset from DaylightUI's list before: the pick
-- moves to Blasta's own setting, DaylightUI's goes back to none.
local function movePicks()
    for name, paths in pairs(BarFx.HOMES or {}) do
        local mod = DUI:GetModule(name)
        local db = mod and mod.db
        if type(db) == "table" then
            for _, path in ipairs(paths) do
                local t = DUI.DB.GetPath(db, path)
                if type(t) == "table" and OWN[t.style] then
                    if not OWN[t[OWN_KEY]] then t[OWN_KEY] = t.style end
                    t.style = "none"
                end
            end
        end
    end
    if BarFx.Refresh then pcall(BarFx.Refresh) end
end
DUI.On("Login", movePicks)

-- A new target, focus or group can put another player's class on a bar.
-- Many nameplates can appear in one frame: one recheck per frame is enough.
local recheckQueued
local function recheck()
    recheckQueued = nil
    for s, p in pairs(byClass) do
        if s.style == "blastaclass" then choose(s, p) end
    end
end
local function queueRecheck()
    if recheckQueued or not next(byClass) then return end
    recheckQueued = true
    C_Timer.After(0, recheck)
end
for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE",
    "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED" }) do
    DUI.RegisterEvent(event, queueRecheck)
end

-- Bars set up before Blasta registered its presets wore none: put every
-- tracked bar in step once now and once after login.
if BarFx.Refresh then
    pcall(BarFx.Refresh)
    DUI.RegisterEvent("PLAYER_LOGIN", function() pcall(BarFx.Refresh) end)
end

-- Only in combat: a bar's animation can rest outside a fight. Each bar's
-- setting sits next to its own (base .. "blastaCombat"); the previews on the
-- options pages always move, so the choice can still be seen.
local COMBAT_KEY = "blastaCombat"
local fighting = UnitAffectingCombat and UnitAffectingCombat("player") == true
local samples = setmetatable({}, { __mode = "k" })
local sampling = 0

if BarFx.SampleBar then
    local sampleBar = BarFx.SampleBar
    BarFx.SampleBar = function(...)
        sampling = sampling + 1
        local ok, bar = pcall(sampleBar, ...)
        sampling = sampling - 1
        if not ok then error(bar, 0) end
        if type(bar) == "table" then samples[bar.bar or bar] = true end
        return bar
    end
end

local pick = BarFx.Pick
BarFx.Pick = function(s)
    local style = ownStyle(s) or pick(s)
    if style and not fighting and sampling == 0 and not samples[s.bar] and BarFx.Get(s, COMBAT_KEY) == true then
        return nil
    end
    return style
end

local function combat(now)
    return function()
        if fighting == now then return end
        fighting = now
        if BarFx.Refresh then pcall(BarFx.Refresh) end
    end
end
DUI.RegisterEvent("PLAYER_REGEN_DISABLED", combat(true))
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", combat(false))

-- Blasta's rows on each bar's animation card, after its "Animation
-- strength": the card's live sample, the Blasta animation, the speed,
-- strength and colors it plays with (the same settings as DaylightUI's rows)
-- and "Only in combat". Blasta's menu takes them from there
-- (extras.CollectSettings), so DaylightUI's card stays as it is.
local function copyRow(row)
    local copy = {}
    for k, v in pairs(row) do copy[k] = v end
    return copy
end
function extras.PlaceBarFxCombat()
    for name, paths in pairs(BarFx.HOMES or {}) do
        local mod = DUI:GetModule(name)
        local homes = {}
        for _, path in ipairs(paths) do homes[path] = true end
        for _, page in ipairs(mod and mod.options and mod.options.pages or {}) do
            for _, group in ipairs(page.groups or {}) do
                local items = group.items or {}
                local i = 1
                while i <= #items do
                    local row = items[i]
                    local base = type(row.key) == "string" and row.key:match("^(.+)%.strength$")
                    if base and homes[base] and row.type == "slider" and not row.blastaCopy then
                        local key, ownKey = base .. "." .. COMBAT_KEY, base .. "." .. OWN_KEY
                        if mod.defaults and DUI.DB.GetPath(mod.defaults, key) == nil then
                            DUI.DB.SetPath(mod.defaults, key, false)
                        end
                        if mod.defaults and DUI.DB.GetPath(mod.defaults, ownKey) == nil then
                            DUI.DB.SetPath(mod.defaults, ownKey, "none")
                        end
                        if not (items[i + 1] and items[i + 1].blastaBarFx == base) then
                            local function find(k)
                                for _, r in ipairs(items) do if r.key == k and not r.blastaCopy then return r end end
                            end
                            local styleRow = find(base .. ".style")
                            local function off(get)
                                return (get(base .. ".style") or "none") == "none" and not OWN[get(ownKey)]
                            end
                            local add = {}
                            for _, r in ipairs(items) do
                                if r.type == "custom" and r.lockWith == base .. ".style" and not r.blastaCopy then
                                    local c = copyRow(r)
                                    c.blastaCopy = true
                                    add[#add + 1] = c
                                    break
                                end
                            end
                            add[#add + 1] = { type = "dropdown", key = ownKey, label = "Blasta animation",
                                choices = ownChoices, inPick = row.inPick, baseHidden = row.baseHidden,
                                hidden = styleRow and styleRow.hidden, disabled = styleRow and styleRow.disabled,
                                desc = "One of Blasta's animations for this bar, in place of DaylightUI's. Speed, strength and colors below go for both. Needs Motion effects.",
                                blastaBarFx = base, blastaCopy = true, blastaOwn = true }
                            for _, field in ipairs({ "speed", "strength", "colors", "colorA", "colorB" }) do
                                local r = find(base .. "." .. field)
                                if r then
                                    local c = copyRow(r)
                                    local hidden = r.hidden
                                    c.blastaCopy, c.disabled = true, off
                                    c.hidden = hidden
                                    add[#add + 1] = c
                                end
                            end
                            add[#add + 1] = { type = "toggle", key = key, label = "Only in combat",
                                desc = "The animation plays only while you're in a fight. Outside one the bar rests. The preview above always moves.",
                                hidden = row.hidden, disabled = off, inPick = row.inPick,
                                baseHidden = row.baseHidden, blastaCopy = true, blastaOwn = true }
                            for n, r in ipairs(add) do table.insert(items, i + n, r) end
                            i = i + #add + 1
                        else
                            i = i + 1
                        end
                    else
                        i = i + 1
                    end
                end
            end
        end
    end
end

extras.Loaded("BarFxPresets")
