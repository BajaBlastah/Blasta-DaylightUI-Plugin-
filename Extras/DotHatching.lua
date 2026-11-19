-- SPDX-License-Identifier: GPL-3.0-or-later
local ADDON, extras = ...
local DUI = DaylightUI
local dots = DUI.Dots
local mod = DUI:GetModule("UnitFrames")
local api = DUI.API
local plugin = api and api.For and api.For(ADDON)
local colorKey = "colors.dotTint"
if not (plugin and plugin.Hook and dots and dots.TintVeil
    and mod and mod.defaults and mod.defaults.colors and extras.FindSetting(mod, colorKey)) then return end

local key = "colors.blastaDotFill"
local label = "Remaining DoT damage fill"
local desc = "Choose a fill pattern for remaining DoT damage on the target and enemy nameplates."
local section = "Remaining DoT damage"
extras.German[label] = "Füllung für verbleibenden DoT-Schaden"
extras.German[desc] = "Wählt das Füllmuster für verbleibenden DoT-Schaden am Ziel und auf gegnerischen Namensplaketten."
extras.German[section] = "Verbleibender DoT-Schaden"
extras.German["Solid fill"] = "Flächig"
extras.German["Diagonal hatching"] = "Diagonale Schraffur"
extras.German["Wide diagonal bands"] = "Breite Diagonalstreifen"
extras.German["Fine dots"] = "Feines Punktraster"
extras.German["Crosshatching"] = "Kreuzschraffur"

mod.defaults.colors.blastaDotFill = "solid"
extras.AddSetting(mod, colorKey, {
    type = "dropdown", key = key, label = label, desc = desc,
    values = { solid = "Solid fill", hatched = "Diagonal hatching", wide = "Wide diagonal bands",
        dots = "Fine dots", cross = "Crosshatching" },
    order = { "solid", "hatched", "wide", "dots", "cross" },
    blastaCompanion = colorKey,
    blastaDestination = { page = "Auras", tab = "General", label = section },
})

local white = "Interface\\Buttons\\WHITE8x8"
local media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local patterns = { hatched = "DotHatch.tga", wide = "DotWide.tga", dots = "DotDotted.tga", cross = "DotCross.tga" }
local sizes = { hatched = 8, wide = 16, dots = 8, cross = 16 } -- texture pixels
local veils = setmetatable({}, { __mode = "k" })
local pattern, size

local function number(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end

-- A tiled texture ignores masks, so the pattern can't go on the veil's own
-- fill: it lost the plate's slanted ends and the angled edges. The fill stays
-- a plain masked bar (made invisible), and the pattern is a separate texture
-- as wide as the veil, repeated through its texture coordinates, clipped to
-- the fill's rect and masked by the very same masks as the fill.
local function syncMasks(state)
    local o, fill = state.overlay, state.fill
    for i = #o.masks, 1, -1 do
        o.tex:RemoveMaskTexture(o.masks[i])
        o.masks[i] = nil
    end
    for i = 1, fill:GetNumMaskTextures() do
        local m = fill:GetMaskTexture(i)
        if m then
            o.tex:AddMaskTexture(m)
            o.masks[#o.masks + 1] = m
        end
    end
end

local function fit(state)
    local o, v = state.overlay, state.bar
    if not (o and pattern) then return end
    local w, h = v:GetWidth(), v:GetHeight()
    if not (number(w) and w > 0) then return end
    if not (number(h) and h > 0) then h = w end
    local px = DUI.Pixel and DUI.Pixel.Px
    local tile = px and px(v, size) or size
    if not (number(tile) and tile > 0) then tile = size end
    o.tex:SetTexCoord(0, w / tile, 0, h / tile)
end

local function overlayFor(state, v, fill)
    local o = state.overlay
    if o then return o end
    local clip = CreateFrame("Frame", nil, v)
    clip:SetClipsChildren(true)
    clip:SetPoint("TOPLEFT", fill, "TOPLEFT")
    clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    local tex = clip:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(v)
    o = { clip = clip, tex = tex, masks = {} }
    state.overlay = o
    v:HookScript("OnSizeChanged", function() fit(state) end)
    return o
end

local probe = UIParent:CreateTexture()
probe:Hide()
local canMask = probe.GetNumMaskTextures and probe.GetMaskTexture and true or false

local function paint(veil, tint)
    local bar = veil and veil.bar
    local fill = bar and bar:GetStatusBarTexture()
    if not fill then return end
    local state = veils[veil]
    if not state or state.fill ~= fill then
        state = { fill = fill, bar = bar }
        veils[veil] = state
    end
    state.tint = tint
    local color = type(tint) == "table" and tint or dots.TINT
    local r, g, b, a = color[1] or 0, color[2] or 0, color[3] or 0, color[4] or dots.TINT[4]

    if canMask then
        if state.pattern ~= pattern then
            state.pattern = pattern
            if pattern then
                local o = overlayFor(state, bar, fill)
                o.tex:SetTexture(media .. pattern, "REPEAT", "REPEAT")
            end
        end
        local o = state.overlay
        if pattern then
            -- Keeps the fill's shape (and the DoT estimate) without drawing it.
            fill:SetAlpha(0)
            syncMasks(state)
            fit(state)
            o.tex:SetVertexColor(r, g, b, a)
            o.clip:Show()
        else
            fill:SetAlpha(1)
            if o then o.clip:Hide() end
        end
        return
    end

    -- Older clients without mask lookups: tile the fill itself.
    if not (fill.SetHorizTile and fill.SetVertTile) then return end
    local changed = pattern ~= state.pattern
    if changed then
        if pattern then fill:SetTexture(media .. pattern, "REPEAT", "REPEAT") else fill:SetTexture(white) end
        fill:SetHorizTile(pattern ~= nil)
        fill:SetVertTile(pattern ~= nil)
        state.pattern = pattern
    end
    if pattern or changed then fill:SetVertexColor(r, g, b, a) end
end

-- Layouts swap the fill's masks (angle, plate ends): follow them right after.
local function relayout(veil)
    local state = veil and veils[veil]
    if not (state and state.overlay and pattern) then return end
    syncMasks(state)
    fit(state)
    C_Timer.After(0, function()
        if state.overlay and pattern then syncMasks(state); fit(state) end
    end)
end

local function refresh()
    local choice = DUI:Get("UnitFrames", key)
    local selected = patterns[choice]
    if selected == pattern then return end
    pattern, size = selected, sizes[choice]
    for veil, state in pairs(veils) do dots.TintVeil(veil, state.tint) end
end

-- Both the native overlay and Blasta's separate finisher segment use this
-- painter, including sample frames and reused enemy nameplates.
plugin.Hook(dots, "TintVeil", paint)
if canMask and dots.LayoutVeil then plugin.Hook(dots, "LayoutVeil", relayout) end
DUI.On("Login", refresh)
DUI.On("RepaintCore", refresh)
DUI.On("SettingChanged", function(scope, path)
    if scope ~= "UnitFrames" then return end
    if path == key then
        refresh()
    elseif path == colorKey then
        -- Plates listen for this setting natively. Repaint the target as well,
        -- even if DaylightUI defers the next unit-frame layout until after combat.
        local frames = mod.ns and mod.ns.frames
        local target = frames and frames.target
        if target and target.dotVeil then dots.TintVeil(target.dotVeil, dots.Tint()) end
    end
end)

extras.Loaded("DotHatching")
