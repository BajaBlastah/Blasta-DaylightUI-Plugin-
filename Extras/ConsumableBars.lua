-- SPDX-License-Identifier: GPL-3.0-or-later
local ADDON, extras = ...
local DUI = DaylightUI
local Style, Motion, Pixel = DUI.Style, DUI.Motion, DUI.Pixel
local scanAura = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
if not (scanAura and Motion.Slider and DUI.Options.MediaPick and DUI.Media.RegisterSlot) then return end

local key, moverKey, fontSlot = "consumableBars", "BlastaConsumableBars", "blasta.consumables.font"
local defaults = { enabled = false, position = "player", x = 0, y = 0, width = 180, height = 14, spacing = 3,
    font = DUI.Media.GENERAL, textSize = 12, nameX = 0, nameY = 0, timeX = 0, timeY = 0 }
extras.ConsumableBarDefaults = defaults

local units = DUI:GetModule("UnitFrames")
local ns = units and units.ns
local cast = ns and ns.UF and ns.UF.MEDIA and ns.UF.MEDIA.cast
local castFont = cast and cast.player and cast.player.font
DUI.Media.RegisterSlot(fontSlot, ADDON, key .. ".font", "font", castFont)

local kinds = {
    { label = "Food", spell = 433, color = { .39, .63, .38 } },
    { label = "Drink", spell = 430, color = { .34, .60, .85 } },
}
local function setting(field)
    local value = DUI:Get(ADDON, key .. "." .. field)
    if value == nil then return defaults[field] end
    return value
end

local function plain(value)
    if not issecretvalue or not issecretvalue(value) then return value end
end

local PAD = ns and ns.CastBar and ns.CastBar.PAD or 3
local root, freeAnchor, order, rows = nil, nil, {}, {}
local active, preview = {}, {}
local previewToken = 0
local width, height, gap
local attached -- the player frame while the bars hang under its column
local update, reconcile, hang

-- Rows overlap their borders when they hang under the player frame, like the
-- swing timers. In free position they keep the chosen spacing.
local function positionStack()
    local y = 0
    for _, row in ipairs(order) do
        local p = row.slide.p
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, -y)
        row:SetHeight(math.max(.01, height * p))
        row:SetShown(p > 0)
        row.overlay:SetShown(p > 0)
        row.overlay:SetAlpha(p)
        row.top = y
        y = y + p * (height + gap)
    end
    -- Whichever bar started first lies on top; each later bar slides out from
    -- under the one above it (food then drink, or drink then food).
    local base = root:GetFrameLevel()
    for i, row in ipairs(order) do
        local level = base + 1 + (#order - i) * 6
        if row:GetFrameLevel() ~= level then row:SetFrameLevel(level) end
    end
    if attached then hang() end
end

local function removeRow(row)
    for i, item in ipairs(order) do
        if item == row then table.remove(order, i); return end
    end
end

local function placeTexts(row, cut)
    local nameY, timeY = setting("nameY"), setting("timeY")
    row.time:ClearAllPoints()
    row.time:SetPoint("RIGHT", row.bar, "RIGHT", -(PAD + cut) + setting("timeX"), timeY)
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.bar, "LEFT", PAD + setting("nameX"), nameY)
    row.name:SetPoint("RIGHT", row.time, "LEFT", -5, nameY - timeY)
end

local function createRow(kind)
    local row = CreateFrame("Frame", nil, root)
    row:SetClipsChildren(true)
    row:Hide()
    -- The bar is anchored at the bottom of its clipped row, so as the row opens
    -- it slides out from under whatever it hangs from.
    local panel = CreateFrame("Frame", nil, row)
    panel:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT")
    panel:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT")
    Style.Shell(panel)
    -- Set up the angled end before anything else is clipped to the panel, or
    -- the shell's border and background keep a square (black) end.
    Style.Slant(panel, nil, 0)
    local bar = Style.Bar(panel)
    Style.SetBarColor(bar, unpack(kind.color))
    Style.Clip(panel, bar:GetStatusBarTexture(), "inner")
    Style.Clip(panel, Style.BarBack(bar), "inner")
    -- The text sits above every bar, outside the row's clip, so it can be
    -- moved onto or past the bar's edge. Its own clip starts at the row's top
    -- edge, so while the bar slides out from under the one above (or the
    -- frame) its text stays hidden too. It fades with the row's slide.
    local textClip = CreateFrame("Frame", nil, root.textLayer)
    textClip:SetClipsChildren(true)
    textClip:SetPoint("TOPLEFT", row, "TOPLEFT", -60, 0)
    textClip:SetPoint("TOPRIGHT", row, "TOPRIGHT", 60, 0)
    textClip:SetHeight(300)
    local overlay = CreateFrame("Frame", nil, textClip)
    overlay:SetAllPoints(panel)
    overlay:Hide()
    row.overlay = overlay
    local name = Style.Text(overlay, defaults.textSize, "LEFT", fontSlot)
    name:SetWordWrap(false)
    local time = Style.Text(overlay, defaults.textSize, "RIGHT", fontSlot)
    row.panel, row.bar, row.name, row.time = panel, bar, name, time
    row.slide = Motion.Slider(positionStack, { parent = root, p = 0, dur = ns and ns.CastBar and ns.CastBar.SLIDE or .2,
        done = function(slider)
            if slider.p ~= 0 then return end
            row.overlay:Hide()
            removeRow(row)
            positionStack()
            if #order == 0 then root:Hide() end
        end })
    return row
end

local function playerFrame()
    local f = setting("position") == "player" and ns and ns.frames and ns.frames.player
    if f and f:IsShown() then return f end
end

local function borderPx()
    local swing = ns and ns.Swing
    local px = swing and swing.BorderOf and swing.BorderOf(ns.swing)
    if not px then px = DUI.DB and DUI.DB.General and DUI.DB.General().borderPx or 1 end
    return Pixel.Px(root, px)
end

-- How far below the player frame's top the lowest piece of its column ends:
-- the frame itself, the cast bar hanging under it, or the swing timers under
-- either. Mirrors DaylightUI's Swing.Hang, so the bars continue that column.
local function columnDepth(f, T)
    local fH = f:GetHeight()
    local lift = ns.CastBar and ns.CastBar.Lift and ns.CastBar.Lift(f, T) or T
    local depth, above = fH - lift + T, f
    local cb = ns.playerCastbar
    if cb and cb:IsShown() and cb.enabled and cb.column and ns.CastBar.Depth then
        depth, above = math.max(depth, ns.CastBar.Depth(cb) or depth), cb
    end
    local sw = ns.swing
    if sw and sw:IsShown() and sw.column and sw.slide then
        local top = depth - sw:GetHeight() * (1 - sw.slide.p)
        depth, above = math.max(depth, top - T + sw:GetHeight()), sw
    end
    return depth, above, fH
end

hang = function()
    local f = attached
    if not (f and root) then return end
    local T = borderPx()
    local depth, above, fH = columnDepth(f, T)
    local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if root:GetScale() ~= scale then root:SetScale(scale) end
    local w = f:GetWidth()
    if w ~= width then
        width = w
        root:SetWidth(w)
    end
    if root.depth ~= depth then
        root.depth = depth
        root:ClearAllPoints()
        root:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(depth - T))
    end
    local level = math.max(f:GetFrameLevel(), above:GetFrameLevel()) + 2
    if root:GetFrameLevel() ~= level then
        root:SetFrameLevel(level)
        root.textLayer:SetFrameLevel(level + 30)
        for i, row in ipairs(order) do row:SetFrameLevel(level + 1 + (#order - i) * 6) end
    end
    if root:GetFrameStrata() ~= f:GetFrameStrata() then root:SetFrameStrata(f:GetFrameStrata()) end
    local fCut = f.cut or 0
    for _, row in ipairs(order) do
        -- Each bar's angled end continues the frame's edge, cutting further in
        -- the lower it hangs, like the swing timers and the cast bar.
        local total = math.max(1, depth - T + row.top + height * row.slide.p)
        local cut = fCut * total / math.max(1, fH)
        if row.cut ~= cut or row.total ~= total then
            row.cut, row.total = cut, total
            local side = cut > 0 and "right" or nil
            local ref = row.slantRef or {}
            row.slantRef, ref.frame, ref.height = ref, f, total
            Style.Slant(row.panel, side, cut, ref)
            Style.AngleFill(row.bar, side, cut * (height - 2 * T) / total)
            placeTexts(row, cut)
        end
    end
end

local function layout()
    if not root then return end
    local f = playerFrame()
    attached = f or nil
    local T = borderPx()
    height = setting("height")
    if f then
        -- Width comes from the frame (hang); borders overlap like the swing timers.
        width, gap = nil, -T
        root:SetParent(UIParent)
    else
        width, gap = setting("width"), setting("spacing")
        root:SetParent(freeAnchor)
        root:SetScale(1)
        root:SetFrameStrata("MEDIUM")
        root:ClearAllPoints()
        root:SetPoint("TOP", freeAnchor, "TOP", setting("x"), setting("y"))
        root:SetWidth(width)
    end
    root:SetHeight(height)
    root.depth = nil
    freeAnchor:SetSize(setting("width"), setting("height"))
    DUI.Movers.Recheck(moverKey)
    for i, row in ipairs(rows) do
        local panel, bar, name, time = row.panel, row.bar, row.name, row.time
        local border = Pixel.Px(panel, Style.BorderPx(panel))
        panel:SetHeight(height)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", panel, "TOPLEFT", border, -border)
        bar:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -border, border)
        name:SetText(extras.Translate(kinds[i].label))
        Style.SetTextSize(name, setting("textSize"))
        Style.SetTextSize(time, setting("textSize"))
        row.cut, row.total = nil, nil
        if not f then
            local cut = Pixel.Snap(panel, height * .32)
            Style.Slant(panel, "right", cut)
            Style.AngleFill(bar, "right", cut * (height - 2 * border) / height)
            placeTexts(row, cut)
        end
    end
    positionStack()
end

local function build()
    if root then return end
    freeAnchor = CreateFrame("Frame", nil, UIParent)
    freeAnchor:SetSize(defaults.width, defaults.height)
    DUI.Movers.Register(freeAnchor, moverKey, "Food and drink", { "TOP", UIParent, "CENTER", 0, -180 },
        { active = function() return setting("enabled") and setting("position") == "free" end })
    root = CreateFrame("Frame", nil, freeAnchor)
    root:SetFrameStrata("MEDIUM")
    root:SetScript("OnUpdate", function() update() end)
    root:Hide()
    -- The text of both bars, above every bar and free to sit on or past a
    -- bar's edge, but cut off at the stack's top edge. So it slides behind the
    -- player frame together with its bar instead of fading out in front of it.
    local textLayer = CreateFrame("Frame", nil, root)
    textLayer:SetClipsChildren(true)
    textLayer:SetPoint("TOPLEFT", root, "TOPLEFT", -60, 0)
    textLayer:SetPoint("TOPRIGHT", root, "TOPRIGHT", 60, 0)
    textLayer:SetHeight(300)
    textLayer:SetFrameLevel(root:GetFrameLevel() + 30)
    root.textLayer = textLayer
    for i, kind in ipairs(kinds) do rows[i] = createRow(kind) end
    layout()
end

local function draw(row, effect, now)
    local left = math.max(0, effect.expires - now)
    row.bar:SetValue(math.min(1, left / effect.duration))
    local seconds = math.ceil(left)
    if row.seconds ~= seconds then
        row.seconds = seconds
        row.time:SetText(("%d:%02d"):format(math.floor(seconds / 60), seconds % 60))
    end
end

reconcile = function()
    local started = {}
    local now = GetTime()
    for i, row in ipairs(rows) do
        local effect = active[i] or preview[i]
        if effect and effect.expires <= now then
            active[i], preview[i], effect = nil, nil, nil
        end
        if effect then
            if not row.effect then started[#started + 1] = { index = i, start = effect.expires - effect.duration } end
            row.effect = effect
            draw(row, effect, now)
        elseif row.effect then
            row.effect = nil
            row.slide:To(0)
        end
    end
    table.sort(started, function(a, b)
        if a.start == b.start then return a.index < b.index end
        return a.start < b.start
    end)
    if #started > 0 and #order == 0 then layout() end
    for _, entry in ipairs(started) do
        local row = rows[entry.index]
        removeRow(row)
        order[#order + 1] = row
        root:Show()
        row.slide:To(1)
    end
end

update = function()
    local now = GetTime()
    -- The column above can change at any moment (a cast, the swing timers
    -- sliding out), so the bars follow it while they show.
    if attached then
        if not attached:IsShown() then layout() else hang() end
    end
    for _, row in ipairs(order) do
        local effect = row.effect
        if effect and effect.expires <= now then reconcile(); return end
        if effect then draw(row, effect, now) end
    end
end

local spellNames = {}
local fallbackNames = GetLocale() == "deDE" and { "Essen", "Trinken" } or { "Food", "Drink" }
local function identify(spell, name)
    for i, kind in ipairs(kinds) do
        local localized = spellNames[i]
        if not localized and C_Spell and C_Spell.GetSpellName then
            localized = plain(C_Spell.GetSpellName(kind.spell))
            spellNames[i] = localized
        end
        if spell == kind.spell or name == (localized or fallbackNames[i]) then return i end
    end
end

local function refreshAuras()
    wipe(active)
    if setting("enabled") and not DUI.Restricted() and plain(UnitIsDeadOrGhost("player")) == false then
        local now = GetTime()
        for index = 1, 255 do
            local ok, aura = pcall(scanAura, "player", index, "HELPFUL")
            if not ok or not plain(aura) or (issecrettable and issecrettable(aura))
                or (canaccesstable and not canaccesstable(aura)) then break end
            local duration, expires = plain(aura.duration), plain(aura.expirationTime)
            if type(duration) == "number" and duration > 0 and type(expires) == "number" and expires > now then
                local i = identify(plain(aura.spellId), plain(aura.name))
                if i and (not active[i] or expires > active[i].expires) then
                    active[i] = { duration = duration, expires = expires }
                end
            end
        end
    end
    if next(active) then wipe(preview) end
    if next(active) and not root then build() end
    if root then reconcile() end
end

local function playPreview()
    build()
    if next(active) then return end
    previewToken = previewToken + 1
    local token = previewToken
    wipe(preview)
    reconcile()
    local function sample(index, seconds)
        preview[index] = { expires = GetTime() + seconds, duration = seconds }
        reconcile()
    end
    sample(1, 5)
    C_Timer.After(.6, function()
        if token == previewToken and next(preview) and not next(active) then sample(2, 6) end
    end)
end

DUI.On("Login", function()
    -- Register the free-position mover before the player starts repositioning.
    build()
    DUI.RegisterUnitEvent("UNIT_AURA", refreshAuras, "player")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "PLAYER_DEAD", "PLAYER_ALIVE", "ADDON_RESTRICTION_STATE_CHANGED" }) do
        DUI.RegisterEvent(event, refreshAuras)
    end
    refreshAuras()
end)
DUI.On("SettingChanged", function(scope, path)
    if scope ~= ADDON or type(path) ~= "string" or path:sub(1, #key + 1) ~= key .. "." then return end
    layout()
    if path == key .. ".enabled" then refreshAuras() end
end)
DUI.On("StyleChanged", layout)

local function slider(field, label, low, high, step, freeOnly)
    return { type = "slider", key = key .. "." .. field, label = label, min = low, max = high, step = step or 1,
        unit = "px", blastaCommitOnBlur = true,
        disabled = freeOnly and function() return setting("position") ~= "free" end or nil }
end

function extras.ConsumableBarsGroup()
    return { label = "Food and drink", tab = "Food and drink", items = {
        { type = "toggle", key = key .. ".enabled", label = "Show food and drink bars", blastaSince = "1.6" },
        { type = "button", label = "Preview food and drink bars", text = "Preview", func = playPreview },
        { type = "dropdown", key = key .. ".position", label = "Bar position",
            desc = "Free position can be moved using DaylightUI's movers.",
            values = { player = "Below the player frame", free = "Free position" }, order = { "player", "free" } },
        slider("x", "Horizontal offset", -400, 400, 1, true),
        slider("y", "Vertical offset", -400, 400, 1, true),
        slider("width", "Bar width", 100, 350, 1, true),
        slider("height", "Bar height", 6, 36),
        slider("spacing", "Bar spacing", 0, 20, 1, true),
        DUI.Options.MediaPick("font", key .. ".font", "Bar font", nil,
            castFont and { follows = { slot = castFont, label = "Player cast bar" } }),
        slider("textSize", "Bar text size", 8, 24),
        slider("nameX", "Name left / right", -40, 40),
        slider("nameY", "Name up / down", -30, 30),
        slider("timeX", "Timer left / right", -40, 40),
        slider("timeY", "Timer up / down", -30, 30),
    } }
end

extras.Loaded("ConsumableBars")
