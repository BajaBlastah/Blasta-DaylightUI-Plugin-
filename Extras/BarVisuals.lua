local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("UnitFrames")
local cast, swing, units = ns and ns.CastBar, ns and ns.Swing, ns and ns.UF
if not ns then return end

local mod = DUI:GetModule("UnitFrames")
local Style, Motion = DUI.Style, DUI.Motion
local portraitSupported = units and type(units.LayoutPortrait) == "function"
    and Style and Style.CropIcon and UnitCastingInfo and UnitChannelInfo
local waveSupported = Style and Style.ClipLike and Style.Clip and Style.LayoutSlant
    and Motion and Motion.On and Motion.Tween
local interruptSupported = waveSupported and cast and type(cast.Unkick) == "function"
    and type(Motion.Kick) == "function" and type(Motion.Unblade) == "function"
local swingSupported = waveSupported and swing and type(swing.Layout) == "function" and mod.defaults.swing

if swingSupported then
    mod.defaults.swing.blastaAutoShotWave = false
    extras.AddSetting(mod, "swing.slant", {
        type = "toggle", key = "swing.blastaAutoShotWave", label = "Auto Shot wind-up wave",
        disabled = function(get) return get("swing.enabled") ~= true end,
    })
end
local castSettings, portraitSettings = {}, {}
for _, kind in ipairs({ "player", "target", "focus", "party" }) do
    local prefix = kind .. "Castbar"
    local defaults = mod.defaults[prefix]
    if defaults then
        castSettings[kind] = prefix
        defaults.blastaInterruptWave = false
        local nativePortrait = extras.HasSetting(mod, prefix .. ".portraitIcon")
        if portraitSupported and not nativePortrait then defaults.portraitIcon = false end
        local anchor = prefix .. (kind == "player" and ".slant" or ".timeY")
        if not extras.FindSetting(mod, anchor) then anchor = prefix .. ".enabled" end
        if interruptSupported then extras.AddSetting(mod, anchor, {
            type = "toggle", key = prefix .. ".blastaInterruptWave", label = "Interrupt light pulse",
            desc = "Uses Blasta's light pulse in place of DaylightUI's interruption animation for this cast bar.",
            disabled = function(get) return get(prefix .. ".enabled") ~= true end,
        })
            anchor = prefix .. ".blastaInterruptWave"
        end
        if portraitSupported and not nativePortrait then
            extras.AddSetting(mod, anchor, {
                type = "toggle", key = prefix .. ".portraitIcon", label = "Spell icon in portrait",
                desc = "Shows the current spell in the portrait circle while casting.",
                disabled = function(get) return get(prefix .. ".enabled") ~= true end,
            })
            portraitSettings[kind] = prefix
        end
    end
end

if next(portraitSettings) then
    local portraitFrames = setmetatable({}, { __mode = "k" })
    local portraits = setmetatable({}, { __mode = "k" })
    local function updatePortrait(frame, prefix)
        local p = frame.portrait
        if not (p and p.top and p.mask) then return end
        local cfg = mod.db and mod.db[prefix]
        local icon = portraits[p]
        local unit = frame.unitToken
        local texture
        if cfg and cfg.enabled and cfg.portraitIcon and p:IsShown() and not frame.test and not frame.preview
            and type(unit) == "string" and not (issecretvalue and issecretvalue(unit)) then
            texture = select(3, UnitCastingInfo(unit))
            if type(texture) == "nil" then texture = select(3, UnitChannelInfo(unit)) end
        end
        if type(texture) == "nil" then
            -- Crafting several: between two crafts nothing is cast for a
            -- moment. While DaylightUI's cast bar still holds the batch, the
            -- icon stays until the last craft is done or the batch is stopped.
            local bar = ns.playerCastbar
            if icon and icon:IsShown() and unit == "player" and bar and bar.batch
                and cfg and cfg.enabled and cfg.portraitIcon then
                return
            end
            if icon then icon:Hide() end
            return
        end
        if not icon then
            icon = p.top:CreateTexture(nil, "ARTWORK", nil, 0)
            icon:SetAllPoints(p.mask)
            icon:AddMaskTexture(p.mask)
            Style.CropIcon(icon)
            portraits[p] = icon
        end
        icon:SetTexture(texture)
        icon:Show()
    end

    local events = CreateFrame("Frame")
    for _, event in ipairs({
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
        "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "GROUP_ROSTER_UPDATE",
    }) do
        events:RegisterEvent(event)
    end
    -- Spell cast events fire for every unit in range, nameplates included.
    -- Keep only the units with a portrait cast setting and their party slots.
    local portraitUnits = { party1 = true, party2 = true, party3 = true, party4 = true }
    for unit in pairs(portraitSettings) do portraitUnits[unit] = true end
    local portraitQueued
    local function flushPortraits()
        portraitQueued = nil
        for frame, prefix in pairs(portraitFrames) do updatePortrait(frame, prefix) end
    end
    events:SetScript("OnEvent", function(_, event, unit)
        if portraitQueued then return end
        if unit ~= nil and ((issecretvalue and issecretvalue(unit)) or not portraitUnits[unit]) then return end
        portraitQueued = true
        C_Timer.After(0, flushPortraits)
    end)
    -- The cast bar lets go of a batch (last craft done, stopped, or no next
    -- craft in time) through Refresh, so look at the portraits again then.
    if cast and type(cast.Refresh) == "function" then
        hooksecurefunc(cast, "Refresh", function(bar)
            if bar ~= ns.playerCastbar or portraitQueued then return end
            portraitQueued = true
            C_Timer.After(0, flushPortraits)
        end)
    end
    hooksecurefunc(units, "LayoutPortrait", function(frame)
        local kind = frame.group and frame.group.key or frame.spec and frame.spec.unit
        local prefix = portraitSettings[kind]
        if not prefix or frame.preview then return end
        portraitFrames[frame] = prefix
        updatePortrait(frame, prefix)
    end)
end

local waves = setmetatable({}, { __mode = "k" })
local function readableNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function raiseCastPreview(bar)
    if not (bar and bar.preview and bar.kind == "target" and bar.bar and bar.text) then return end
    local fill, overlay = bar.bar, bar.text:GetParent()
    if not overlay then return end

    -- The designer shows the finished cast. A higher frame level cannot
    -- draw through the slide animation's clipping rectangle.
    local owner = bar.column and bar.column.f or bar.attached
    if bar.column and bar.clip then bar.clip:SetClipsChildren(false) end
    local level = bar:GetFrameLevel()
    local ownerLayer = owner and (owner.overlay or owner)
    local ownerLevel = ownerLayer and ownerLayer:GetFrameLevel() or level
    local fillLevel, textLevel = fill:GetFrameLevel(), overlay:GetFrameLevel()
    if not (readableNumber(level) and readableNumber(ownerLevel)
        and readableNumber(fillLevel) and readableNumber(textLevel)) then return end
    local front = math.max(level + 1, ownerLevel + 1, fillLevel)
    if front ~= fillLevel then fill:SetFrameLevel(front) end
    local fx = waves[bar]
    if fx then fx.layer:SetFrameLevel(front + 1) end
    if textLevel < front + 3 then overlay:SetFrameLevel(front + 3) end
end

if cast and type(cast.Layout) == "function" then
    hooksecurefunc(cast, "Layout", raiseCastPreview)
end
if cast and type(cast.ShowSample) == "function" then
    hooksecurefunc(cast, "ShowSample", raiseCastPreview)
end
if cast and type(cast.Hang) == "function" then
    hooksecurefunc(cast, "Hang", function(bar)
        if bar and bar.kind == "target" and bar.preview then
            raiseCastPreview(bar)
            return
        end
        local column = bar and bar.kind == "target" and bar.column
        if not (column and column.f and bar.bar and bar.text and bar.text.GetParent
            and bar.slide and readableNumber(bar.slide.p)) then return end
        local strata, columnStrata = bar:GetFrameStrata(), column.f:GetFrameStrata()
        if issecretvalue and (issecretvalue(strata) or issecretvalue(columnStrata)) then return end
        if strata ~= columnStrata then return end
        local level = column.f:GetFrameLevel()
        local fill, overlay = bar.bar, bar.text:GetParent()
        if not overlay then return end
        local fillLevel, overlayLevel = fill:GetFrameLevel(), overlay:GetFrameLevel()
        local current = bar:GetFrameLevel()
        if not (readableNumber(level) and readableNumber(fillLevel) and readableNumber(overlayLevel)
            and readableNumber(current)) then return end
        local topOffset = math.max(fillLevel + 1, overlayLevel, current) - current
        local desired = bar.slide.p < 1 and math.max(0, level - topOffset - 1) or level + 4
        local delta = desired - current
        if delta == 0 then return end
        local fx = waves[bar]
        bar:SetFrameLevel(desired)
        fill:SetFrameLevel(math.max(0, fillLevel + delta))
        overlay:SetFrameLevel(math.max(0, overlayLevel + delta))
        if fx then fx.layer:SetFrameLevel(math.max(0, fillLevel + delta) + 1) end
    end)
end

local function wave(frame, bar, r, g, b)
    if not (bar and bar.GetStatusBarTexture and Motion.On() and frame:IsVisible()) then return end
    local width, height = bar:GetWidth(), bar:GetHeight()
    if not (readableNumber(width) and readableNumber(height)) or width <= 0 or height <= 0 then return end
    local fx = waves[frame]
    if not fx then
        local level = bar:GetFrameLevel()
        if not readableNumber(level) then return end
        local layer = CreateFrame("Frame", nil, frame)
        layer:SetAllPoints(bar)
        layer:SetClipsChildren(true)
        layer:SetFrameLevel(level + 1)
        fx = { layer = layer, trail = layer:CreateTexture(nil, "ARTWORK"), front = layer:CreateTexture(nil, "ARTWORK") }
        for _, tex in ipairs({ fx.trail, fx.front }) do
            tex:SetColorTexture(1, 1, 1, 1)
            tex:SetBlendMode("ADD")
            if frame.into then
                Style.ClipLike(tex, bar:GetStatusBarTexture())
            else
                Style.Clip(frame, tex, "inner")
            end
        end
        if not frame.into then Style.LayoutSlant(frame) end
        waves[frame] = fx
    end
    local target = frame.kind == "target"
    local trail, front = width * (target and 0.22 or 0.34), width * (target and 0.09 or 0.13)
    fx.trail:SetSize(trail, height)
    fx.front:SetSize(front, height)
    fx.front:SetPoint("LEFT", fx.trail, "RIGHT")
    local clear = CreateColor(r, g, b, 0)
    local crest = CreateColor(r, g, b, 0.88)
    fx.trail:SetGradient("HORIZONTAL", clear, crest)
    fx.front:SetGradient("HORIZONTAL", crest, clear)
    fx.layer:Show()
    Motion.Tween(fx, 0, 1, target and 0.20 or 0.32, function(progress)
        fx.trail:SetPoint("RIGHT", fx.layer, "LEFT", -front + progress * (width + trail + front), 0)
        fx.layer:SetAlpha(1 - progress * progress)
    end, function() fx.layer:Hide() end)
    return true
end

local function lightPulseEnabled(bar)
    local prefix = bar and castSettings[bar.kind]
    local cfg = prefix and mod.db and mod.db[prefix]
    return cfg and cfg.blastaInterruptWave == true
end

if interruptSupported then
    local nativeKick = Motion.Kick
    function Motion.Kick(blade, bar, ...)
        if blade and bar and bar.blade == blade and lightPulseEnabled(bar) then
            local ok, shown = pcall(wave, bar, bar.bar, 1, 0.34, 0.18)
            if ok and shown then return Motion.Unblade(blade) end
        end
        return nativeKick(blade, bar, ...)
    end

    hooksecurefunc(cast, "Unkick", function(bar)
        local fx = waves[bar]
        if fx then
            Motion.Tween(fx, 0, 0, 0)
            fx.layer:Hide()
        end
    end)
end

if swingSupported then
    local watched = setmetatable({}, { __mode = "k" })
    hooksecurefunc(swing, "Layout", function(holder)
        if not (holder and not holder.test and holder.rows and holder.cfg and holder.cfg.blastaAutoShotWave) then return end
        for _, row in ipairs(holder.rows) do
            if row.def and row.def.key == "ranged" and not watched[row] then
                watched[row] = true
                local heldSwing
                row:HookScript("OnUpdate", function(self)
                    if holder.test or not holder.cfg or not holder.cfg.blastaAutoShotWave then return end
                    local held, start = self.held, self.start
                    if issecretvalue and issecretvalue(held) then return end
                    if not held or not readableNumber(start) or start == heldSwing then return end
                    heldSwing = start
                    wave(self, self.bar, 1, 0.68, 0.23)
                end)
            end
        end
    end)
end

extras.Loaded("BarVisuals")
