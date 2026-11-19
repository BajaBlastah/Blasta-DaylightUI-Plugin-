local ADDON, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("UnitFrames")
local ns = mod and mod.ns
local parts, uf, group = ns and ns.GroupParts, ns and ns.UF, ns and ns.Group
if not (parts and parts.CreateDispel and parts.LayoutDispel and parts.CreateGlow
    and parts.StyleGlow and uf and uf.Layout) then return end

local key = "dispelOverlay"
local onlyMineKey = "blastaDispelOnlyMine"
local usableKey = "blastaDispelUsable"
local active, onlyMine, onlyUsable, selected = false, false, false, {}
local function enabled() return active == true end
local function readable(value)
    return not (issecretvalue and issecretvalue(value))
end

local function targetRelation()
    local attack = UnitCanAttack("player", "target")
    if not readable(attack) then return nil end
    if attack then return "hostile" end
    local assist = UnitCanAssist("player", "target")
    if readable(assist) and assist then return "friendly" end
end
local scopes = {
    { "player", "Player", true }, { "party", "Party", true },
    { "raid", "Raid", false }, { "target", "Friendly target", false },
}
local function readToggle(path, default)
    local value = DUI:Get(ADDON, path)
    if value == nil then return default end
    return value == true
end

local function toggle(path, label, default)
    return {
        type = "toggle", key = path, label = label, reload = true,
        get = function() return readToggle(path, default) end,
        set = function(value) return DUI:Set(ADDON, path, value) end,
        default = function() return default end,
    }
end
local setting = toggle(key, "Blasta dispel highlight", false)
setting.desc = "Show a pulsing border and glow in the dispel type color."
local items = { setting }
-- The dispel hint: only what your class removes (the client picks those),
-- and only while you can cast it (not in a form that can't, not out of mana).
local VERSION = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version") or nil
local onlyMineSetting = toggle(onlyMineKey, "Only what you can remove", true)
onlyMineSetting.desc = "Lights up only effects your class can remove, in their dispel type color."
onlyMineSetting.disabled = function() return not setting.get() end
items[#items + 1] = onlyMineSetting
local usableSetting = toggle(usableKey, "Only while you can cast it", true)
usableSetting.desc = "Hides the highlight while your dispel can't be cast right now: in a form without it, silenced or out of mana."
usableSetting.blastaSince = VERSION
usableSetting.disabled = function() return not (setting.get() and onlyMineSetting.get()) end
items[#items + 1] = usableSetting
extras.German["Only what you can remove"] = "Nur was du entfernen kannst"
extras.German["Lights up only effects your class can remove, in their dispel type color."] =
    "Hebt nur Effekte hervor, die deine Klasse entfernen kann, in der Farbe ihres Typs."
extras.German["Only while you can cast it"] = "Nur wenn du bannen kannst"
extras.German["Hides the highlight while your dispel can't be cast right now: in a form without it, silenced or out of mana."] =
    "Blendet die Hervorhebung aus, solange du deinen Bannzauber gerade nicht wirken kannst: in einer Gestalt ohne ihn, zum Schweigen gebracht oder ohne Mana."
for _, scope in ipairs(scopes) do
    local row = toggle("dispelFrames." .. scope[1], scope[2], scope[3])
    row.disabled = function() return not setting.get() end
    items[#items + 1] = row
end

if ns.PageSample and ns.PageSample.New and parts.MakeGlow and ns.Auras and ns.Auras.DISPEL_COLORS then
    items[#items + 1] = {
        type = "button", label = "Test dispel highlight", text = "Test dispel highlight",
        desc = "Shows pulsing dispel highlights on the frames in the preview above. Click again to hide them.",
        blastaSince = "1.5",
        func = function()
            extras.DispelPreviewActive = not extras.DispelPreviewActive
            DUI.OptionsPanel.Refresh()
        end,
    }
end

for _, page in ipairs(mod.options and mod.options.pages or {}) do
    if page.id == "extras" then
        page.groups[#page.groups + 1] = { label = "Blasta dispel highlight", items = items }
        break
    end
end

-- The native aura containers select and color the effect, including in combat.
local function highlight(cfg)
    -- Raid previews inherit layout settings such as spacing from their raid profile.
    return setmetatable({
        dispelHighlight = "none",
        blastaContour = true,
        dispelGlow = true,
        dispelOnlyMine = onlyMine,
    }, { __index = cfg })
end

-- The inner edge of the glow is also the contour. Every pair of strips
-- shares its diagonal join, with no separate corner texture.
local styleGlow = parts.StyleGlow
local GLOW_CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
local GLOW_EDGES = { "TOP", "BOTTOM", "LEFT", "RIGHT" }
local function readableNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function contourGeometry(frame)
    local w, h = frame:GetSize()
    if not (readableNumber(w) and readableNumber(h)) or w <= 0 or h <= 0 then return end
    local slant = DUI.Style.GetSlant(frame)
    if slant and not readableNumber(slant.cut) then return end
    if not readableNumber(frame:GetEffectiveScale()) then return end
    local depth = DUI.Pixel.Px(frame, parts.GLOW_PX or 6)
    local core = DUI.Pixel.Px(frame, 1)
    if not (readableNumber(depth) and readableNumber(core)) then return end
    return w, h, slant, depth, core
end

function parts.StyleGlow(glow, frame, cfg)
    if not cfg.blastaContour then return styleGlow(glow, frame, cfg) end
    local w, h, slant, depth, core = contourGeometry(frame)
    if not w then return styleGlow(glow, frame, cfg) end
    local function side(name, x, sign)
        local cut = slant and (slant.side == name or slant.side == "both") and slant.cut or 0
        local reversed = slant and (slant.under == name or slant.under == "both")
        local start = reversed and cut or 0
        local slope = (reversed and -cut or cut) / h
        local normal = math.sqrt(1 + slope * slope)
        local function point(y, offset)
            return { x + sign * (start - slope * y + offset * normal), y }
        end
        return point(-core, core), point(-h + core, core), point(depth, -depth), point(-h - depth, -depth)
    end
    local function strip(texture, tl, bl, tr, br)
        texture:ClearAllPoints()
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT")
        texture:SetSize(w, h)
        texture:SetBlendMode("BLEND")
        texture:SetSnapToPixelGrid(false)
        texture:SetTexelSnappingBias(0)
        texture:SetVertexOffset(1, tl[1], tl[2])
        texture:SetVertexOffset(2, bl[1], bl[2] + h)
        texture:SetVertexOffset(3, tr[1] - w, tr[2])
        texture:SetVertexOffset(4, br[1] - w, br[2] + h)
        texture:Show()
    end
    local tl, bl, otl, obl = side("left", 0, 1)
    local tr, br, otr, obr = side("right", w, -1)
    strip(glow.TOP, otl, tl, otr, tr)
    strip(glow.BOTTOM, bl, obl, br, obr)
    strip(glow.LEFT, otl, obl, tl, bl)
    strip(glow.RIGHT, tr, br, otr, obr)
    for _, key in ipairs(GLOW_CORNERS) do
        local corner = glow[key]
        corner:ClearAllPoints()
        corner:Hide()
    end
end

-- "Test dispel highlight" shows pulsing dispel glows on the frames in
-- DaylightUI's own unit frame previews (Settings.lua calls this after each
-- preview refresh).
local PREVIEW_KINDS = { "Magic", "Curse", "Poison", "Disease" }
local previewGlows = setmetatable({}, { __mode = "k" })
local previewPulse

local function previewGlow(frame, kind)
    local overlay = previewGlows[frame]
    if not overlay then
        overlay = CreateFrame("Frame", nil, frame)
        overlay:SetAllPoints(frame)
        overlay.glow = parts.MakeGlow(overlay)
        previewGlows[frame] = overlay
    end
    overlay:SetFrameLevel(frame:GetFrameLevel() + 2)
    parts.StyleGlow(overlay.glow, frame, { blastaContour = true })
    local color = ns.Auras.DISPEL_COLORS[kind]
    local r, g, b = DUI.Style.Soften(color[1], color[2], color[3])
    for _, edge in ipairs(GLOW_EDGES) do overlay.glow[edge]:SetVertexColor(r, g, b, 1) end
    overlay:Show()
end

function extras.PaintDispelPreview(preview)
    if not (parts and parts.MakeGlow and ns.Auras and ns.Auras.DISPEL_COLORS) then return end
    local on = extras.DispelPreviewActive == true and setting.get() == true
    local frames = preview.f and { preview.f } or preview.members or {}
    for frame, overlay in pairs(previewGlows) do
        if not on then overlay:Hide() end
    end
    if not on then return end
    for i, frame in ipairs(frames) do
        if frame.IsShown and frame:IsShown() then previewGlow(frame, PREVIEW_KINDS[(i - 1) % #PREVIEW_KINDS + 1]) end
    end
    if not previewPulse then
        previewPulse = CreateFrame("Frame")
        local elapsed = 0
        previewPulse:SetScript("OnUpdate", function(_, delta)
            elapsed = elapsed + delta
            if elapsed < 0.025 then return end
            elapsed = 0
            local motion = DUI.Motion and DUI.Motion.On()
            local phase = motion and (1 - math.cos(GetTime() * math.pi / (uf.PULSE_TIME or 0.6))) * 0.5 or 1
            for _, overlay in pairs(previewGlows) do
                if overlay:IsShown() then overlay:SetAlpha(.85 * (.45 + .55 * phase)) end
            end
        end)
    end
end

local watched = setmetatable({}, { __mode = "k" })
local halos = setmetatable({}, { __mode = "k" })
local canPurge
local function haloAlpha(relation, kind)
    return relation == kind and (kind == "friendly" or not onlyMine or canPurge) and 1 or 0
end

-- Set when a holder could not be updated, so the next poll retries it.
local haloRetry = false
local function updateHalo(holder, state, relation)
    local alpha = haloAlpha(relation, state.kind)
    if holder:IsForbidden() then
        -- The client can repaint its aura hierarchy while it is restricted.
        state.alpha = nil
        haloRetry = true
    elseif state.alpha ~= alpha then
        if pcall(holder.SetAlpha, holder, alpha) then
            state.alpha = alpha
        else
            haloRetry = true
        end
    end
end

local auraKind
local auras, style = ns.Auras, DUI.Style
if auras and auras.InitButton and style and style.AuraHalo then
    local initButton, auraHalo = auras.InitButton, style.AuraHalo
    function auras.InitButton(button, kind, ...)
        local previous = auraKind
        auraKind = kind == "buff" and "hostile" or kind == "debuff" and "friendly" or nil
        local ok, err = pcall(initButton, button, kind, ...)
        auraKind = previous
        if not ok then error(err, 0) end
    end

    function style.AuraHalo(button, ...)
        if not auraKind then return auraHalo(button, ...) end
        local holder = CreateFrame("Frame", nil, button)
        holder:SetAllPoints()
        holder:SetAlpha(0)
        -- The client owns the texture's visibility. Gate the independent parent.
        local proxy = {
            CreateTexture = function(_, ...) return holder:CreateTexture(...) end,
            AddDispelTypeTexture = button.AddDispelTypeTexture and function(_, ...)
                return button:AddDispelTypeTexture(...)
            end,
        }
        local halo = auraHalo(proxy, ...)
        if halo then
            local state = { kind = auraKind }
            halos[holder] = state
            updateHalo(holder, state, targetRelation())
        end
        return halo
    end
end

local offensiveDispels = { 370, 527, 19505, 19801, 23922, 30449 }
local function knowsOffensiveDispel()
    for _, id in ipairs(offensiveDispels) do
        if IsSpellKnown and (IsSpellKnown(id) or IsSpellKnown(id, true)) then return true end
    end
    return false
end

-- Your friendly dispels, by class (every rank this client has).
local FRIENDLY_DISPELS = {
    PRIEST = { 527, 988, 528, 552 }, PALADIN = { 1152, 4987 }, DRUID = { 2782, 8946, 2893 },
    SHAMAN = { 526, 2870 }, MAGE = { 475 }, WARLOCK = { 19505, 19731, 19734, 19736 },
}
local canCast = true
local function updateUsable()
    local _, class = UnitClass("player")
    local list = FRIENDLY_DISPELS[class]
    if not list then canCast = true; return end
    local any, usable = false, false
    for _, id in ipairs(list) do
        local known = (IsSpellKnown and (IsSpellKnown(id) or IsSpellKnown(id, true))) or false
        if known then
            any = true
            local ok, can = false, nil
            if C_Spell and C_Spell.IsSpellUsable then ok, can = pcall(C_Spell.IsSpellUsable, id)
            elseif IsUsableSpell then ok, can = pcall(IsUsableSpell, id) end
            if not ok or not readable(can) or can then usable = true; break end
        end
    end
    canCast = usable or not any
end

local lastRelation
local function updateHalos()
    if not next(halos) then return end
    local relation = targetRelation()
    lastRelation, haloRetry = relation, false
    for holder, state in pairs(halos) do
        updateHalo(holder, state, relation)
    end
end

-- The periodic duel check only walks the halos when the target relation
-- changed or a restricted holder still needs its alpha.
local function pollHalos()
    if not next(halos) then return end
    if not haloRetry and targetRelation() == lastRelation then return end
    updateHalos()
end

local function watch(container, frame, strength, layer)
    if not container then return end
    local level = frame:GetFrameLevel()
    if not readableNumber(level) then return end
    level = level + layer
    if frame.portrait and not frame.portraitFree then
        local portraitLevel = frame.portrait:GetFrameLevel()
        if readableNumber(portraitLevel) then level = math.min(level, portraitLevel - 1) end
    end
    container:SetFrameLevel(math.max(0, level))
    if not watched[container] then container:SetAlpha(0) end
    local entry = watched[container]
    if entry then
        entry.frame, entry.strength = frame, strength
    else
        watched[container] = { frame = frame, strength = strength, alpha = 0 }
    end
end

local layout = parts.LayoutDispel
function parts.LayoutDispel(frame, cfg)
    local scope = frame.spec and frame.spec.group
    local frames = ns.frames
    if frames and frame == frames.player then scope = "player" end
    if frames and frame == frames.target then scope = "target" end
    if not enabled() or not selected[scope] or not frame.dispel then return layout(frame, cfg) end
    if not frame.glowBox then parts.CreateGlow(frame) end
    layout(frame, highlight(cfg))
    watch(frame.glowBox, frame, 0.85, 2)
end

-- Register only the four strips so the client cannot re-show native corners.
local styleGlowParts = parts.StyleGlowParts
if styleGlowParts and ns.Auras and ns.Auras.RegisterDispelEdge then
    function parts.StyleGlowParts(button, frame, cfg)
        if not cfg.blastaContour or not contourGeometry(frame) then return styleGlowParts(button, frame, cfg) end
        parts.StyleGlow(button.glow, frame, cfg)
        if button.ClearDispelTypeTextures then button:ClearDispelTypeTextures() end
        for _, key in ipairs(GLOW_EDGES) do
            local c = parts.GLOW_COORDS[key]
            ns.Auras.RegisterDispelEdge(button, button.glow[key], button.withoutType, parts.GLOW_ART,
                { left = c[1], right = c[2], top = c[3], bottom = c[4] })
        end
    end
end

if group and group.LayoutSamples then
    local samples = group.LayoutSamples
    function group:LayoutSamples(list, holder, cfg, ...)
        if not enabled() or not selected[self.key] then return samples(self, list, holder, cfg, ...) end
        samples(self, list, holder, highlight(cfg), ...)
        for _, frame in ipairs(list or {}) do
            watch(frame.sampleGlowFrame, frame, 0.75, 2)
        end
    end
end

local personal = setmetatable({}, { __mode = "k" })
local personalConfig = { dispelSize = 12, showDispel = false }
hooksecurefunc(uf, "Layout", function(frame)
    if not enabled() then return end
    local frames = ns.frames
    local unit = frames and (frame == frames.player and "player" or frame == frames.target and "target")
    if not unit or not selected[unit] then return end
    DUI.AfterCombat(function()
        if personal[frame] then
            parts.LayoutDispel(frame, personalConfig)
            return
        end
        if frame.dispel then return end
        parts.CreateDispel(frame)
        if not frame.dispel then return end
        personal[frame] = true
        parts.LayoutDispel(frame, personalConfig)
        local container = frame.glowBox
        if container then
            if container.SetUnit then pcall(container.SetUnit, container, unit) end
            if container.UpdateAllAuras then pcall(container.UpdateAllAuras, container) end
        end
    end, "blasta:dispel:" .. unit)
end)

DUI.On("Login", function()
    active = DUI:Get(ADDON, key) == true
    if not mod.enabled then return end
    onlyMine = active and readToggle(onlyMineKey, true)
    onlyUsable = onlyMine and readToggle(usableKey, true)
    if onlyUsable then
        updateUsable()
        for _, event in ipairs({ "SPELL_UPDATE_USABLE", "UPDATE_SHAPESHIFT_FORM", "SPELLS_CHANGED" }) do
            DUI.RegisterEvent(event, updateUsable)
        end
    end
    local function updateSpells()
        canPurge = knowsOffensiveDispel()
        updateHalos()
    end
    for _, event in ipairs({ "SPELLS_CHANGED", "UNIT_PET" }) do
        DUI.RegisterEvent(event, updateSpells)
    end
    for _, event in ipairs({ "PLAYER_TARGET_CHANGED", "DUEL_REQUESTED", "DUEL_FINISHED" }) do
        DUI.RegisterEvent(event, updateHalos)
    end
    -- Only target and player matter: the client filters these unit events,
    -- so aura changes on nameplates and raid members never reach Lua here.
    for _, event in ipairs({ "UNIT_FACTION", "UNIT_FLAGS", "UNIT_AURA" }) do
        DUI.RegisterUnitEvent(event, pollHalos, "target", "player")
    end
    updateSpells()
    -- Duel attackability can change while the unit and its auras stay put.
    C_Timer.NewTicker(0.15, pollHalos)
    if not active then return end
    for _, scope in ipairs(scopes) do
        if readToggle("dispelFrames." .. scope[1], scope[3]) then selected[scope[1]] = true end
    end
    if not next(selected) then return end

    local driver = CreateFrame("Frame")
    local elapsed = 0
    driver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed < 0.025 then return end
        elapsed = 0
        local motion = DUI.Motion and DUI.Motion.On()
        local phase
        local targetFrame = ns.frames and ns.frames.target
        local friendlyTarget
        for container, entry in pairs(watched) do
            if not container:IsForbidden() and container:IsVisible() then
                local frame = entry.frame
                local anim = frame.portrait and frame.portrait.pulseAnim
                local alpha = motion and anim and anim:IsPlaying() and anim:GetAnimations()
                local progress = alpha and alpha.GetSmoothProgress and alpha:GetSmoothProgress()
                if not readableNumber(progress) then
                    if phase == nil then
                        phase = motion and (1 - math.cos(GetTime() * math.pi / (uf.PULSE_TIME or 0.6))) * 0.5 or 1
                    end
                    progress = phase
                end
                if frame == targetFrame and friendlyTarget == nil then friendlyTarget = targetRelation() == "friendly" end
                local friendly = frame ~= targetFrame or friendlyTarget
                if onlyUsable and not canCast then friendly = false end
                local opacity = friendly and entry.strength * (0.45 + 0.55 * progress) or 0
                if entry.alpha ~= opacity and pcall(container.SetAlpha, container, opacity) then
                    entry.alpha = opacity
                end
            else
                entry.alpha = nil
            end
        end
    end)
    if ns.Refresh then ns.Refresh(mod) end
end)

extras.Loaded("DispelHighlights")
