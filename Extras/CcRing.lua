local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Skins")
local Alert = ns and ns.CcAlert
local mod = DUI:GetModule("Skins")
if not (Alert and Alert.Layout and Alert.Paint and Alert.Bar and Alert.Land and mod and mod.defaults
    and DUI.Style and DUI.Style.GetShell and DUI.Motion and DUI.Pixel) then return end
local Style, Motion, Pixel = DUI.Style, DUI.Motion, DUI.Pixel

-- The crowd control alert as a ring: the icon round in the middle with the
-- time on it, a ring around it that runs down with the effect, the name under
-- it. DaylightUI's alert still does all the work (it mirrors the game's own
-- frame); Blasta only lays its pieces out differently and adds the ring. The
-- ring is a client Cooldown fed the effect's duration object, so it runs in
-- combat with secret values too. Name and time stay the game's text, passed
-- through untouched, so nothing here measures them: the name sits centered
-- under the ring.
local KEY = "blastaCcRing"
local K = {
    size = KEY .. "Size", line = KEY .. "Line", color = KEY .. "Color", custom = KEY .. "Custom",
    name = KEY .. "Name", alpha = KEY .. "Back", nameSize = KEY .. "NameSize", timeSize = KEY .. "TimeSize",
}
local BADGE, BADGE_SIZE = "blastaCcBadge", "blastaCcBadgeSize"
mod.defaults[BADGE], mod.defaults[BADGE_SIZE] = false, 42
mod.defaults[KEY] = false
mod.defaults[K.size] = 34
mod.defaults[K.line] = "normal"
mod.defaults[K.color] = "accent"
mod.defaults[K.custom] = { 1, 0.3, 0.3 }
mod.defaults[K.name] = true
mod.defaults[K.alpha] = 0.55
mod.defaults[K.nameSize] = 0 -- 0: DaylightUI's title size
mod.defaults[K.timeSize] = 0 -- 0: grows with the icon

local function off(get) return get("packs.system") == false or get("ccAlert") == false or get(BADGE) == true or get(KEY) ~= true end
local rows = {
    { type = "toggle", key = KEY, label = "Crowd control alert as a ring",
      desc = "The icon round in the middle, with the time on it and a ring around it that runs down with the effect. The name sits under it.",
      disabled = function(get) return get("packs.system") == false or get("ccAlert") == false end },
    { type = "slider", key = K.size, label = "Ring icon size", min = 24, max = 64, step = 2, unit = "px",
      desc = "How big the icon in the ring is. The ring grows with it.", disabled = off },
    { type = "dropdown", key = K.line, label = "Ring line", values = { normal = "Normal", thin = "Thin" },
      order = { "normal", "thin" }, desc = "How thick the ring is.", disabled = off },
    { type = "dropdown", key = K.color, label = "Ring color",
      values = { accent = "Accent color", class = "Class color", custom = "One color" }, order = { "accent", "class", "custom" },
      desc = "Your accent color, your class's color, or one you pick.", disabled = off },
    { type = "color", key = K.custom, label = "Custom ring color", desc = "The ring's color when Ring color is One color.",
      hidden = function(get) return get(K.color) ~= "custom" end, disabled = off },
    { type = "slider", key = K.alpha, label = "Ring track opacity", min = 0, max = 1, step = 0.05, unit = "%",
      desc = "How dark the part of the ring that has already run down is.", disabled = off },
    { type = "toggle", key = K.name, label = "Show the effect's name", desc = "The name (Stunned, Feared...) under the ring.",
      disabled = off },
    { type = "slider", key = K.nameSize, label = "Name text size", min = 0, max = 32, step = 1, unit = "px",
      desc = "How big the name under the ring is. 0 uses DaylightUI's size.",
      disabled = function(get) return off(get) or get(K.name) == false end },
    { type = "slider", key = K.timeSize, label = "Time text size", min = 0, max = 40, step = 1, unit = "px",
      desc = "How big the time on the icon is. 0 grows it with the icon.", disabled = off },
}
-- The rows get a card of their own on Blasta's World page, in a tab of their
-- own with the ring's preview over it (not over the flight and breath bars,
-- which share DaylightUI's card).
local card = { label = "Crowd control alert", blastaTab = "Crowd control alert", items = rows }
do
    local placed
    for _, page in ipairs(mod.options and mod.options.pages or {}) do
        for gi, group in ipairs(page.groups or {}) do
            for _, item in ipairs(group.items or {}) do
                if item.key == "ccAlert" and not placed then
                    table.insert(page.groups, gi + 1, card)
                    placed = true
                end
            end
        end
    end
    if not placed then
        for _, row in ipairs(rows) do extras.AddSetting(mod, "ccAlert", row) end
    end
end

local RING_ART = { normal = DUI.MEDIA .. "cursor-ring.png", thin = DUI.MEDIA .. "cursor-ring-thin.png" }
local ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- The art's line, measured in frame widths from the middle: where its inner
-- and outer edges are. The round icon fills the ring up to the inner edge.
local EDGE = { normal = { inner = 0.371, outer = 0.449 }, thin = { inner = 0.391, outer = 0.426 } }
local SAMPLE_ICON = 135860

local function db() return mod.db or mod.defaults end
local function badgeOn() return db()[BADGE] == true end
local function on() return not badgeOn() and db()[KEY] == true end
local function art() return RING_ART[db()[K.line]] or RING_ART.normal end
local function edge() return EDGE[db()[K.line]] or EDGE.normal end
-- The ring's frame for an icon of this size: the icon reaches the line's
-- inner edge (a hair over, so no gap shows between them).
local function ringSize(icon) return math.floor(icon / (2 * edge().inner) - 0.5) end

local function ringColor()
    local d = db()
    if d[K.color] == "class" then
        local _, token = UnitClass("player")
        local r, g, b = Style.ClassColor(token)
        if r then return r, g, b end
    elseif d[K.color] == "custom" then
        local c = d[K.custom]
        if type(c) == "table" and type(c[1]) == "number" then return c[1], c[2], c[3] end
    end
    return Style.Accent()
end

local function ring(f)
    local r = f.blastaRing
    if r then return r end
    r = CreateFrame("Frame", nil, f)
    r:EnableMouse(false)
    r.back = r:CreateTexture(nil, "ARTWORK")
    r.back:SetAllPoints(r)
    local cd = CreateFrame("Cooldown", nil, r, "CooldownFrameTemplate")
    cd:SetAllPoints(r)
    cd:SetDrawEdge(false)
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    cd:SetHideCountdownNumbers(true)
    cd:SetReverse(false)
    cd:EnableMouse(false)
    r.cd = cd
    f.blastaRing = r
    return r
end

local function roundIcon(f, round)
    local m = f.blastaRound
    if round and not m then
        m = f.art:CreateMaskTexture()
        m:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(f.icon)
        f.blastaRound = m
    end
    if not m then return end
    if round and not f.blastaRoundOn then
        f.icon:AddMaskTexture(m)
        f.blastaRoundOn = true
    elseif not round and f.blastaRoundOn then
        f.icon:RemoveMaskTexture(m)
        f.blastaRoundOn = nil
    end
end

local function paintRing(f)
    local r = f.blastaRing
    if not r then return end
    local file = art()
    r.back:SetTexture(file)
    r.cd:SetSwipeTexture(file)
    local cr, cg, cb = ringColor()
    r.back:SetVertexColor(0, 0, 0, tonumber(db()[K.alpha]) or 0.55)
    r.cd:SetSwipeColor(cr or 1, cg or 1, cb or 1, 1)
end

local function layoutRing(f, still)
    local r = ring(f)
    local d = db()
    -- The fading copy after an effect ends sits on a frame of its own, placed
    -- anew and a pixel or two off: its ring goes exactly where the alert's was.
    local spot = f
    if f == Alert.ghost and Alert.frame then spot = Alert.frame end
    local icon = Pixel.Snap(spot, tonumber(d[K.size]) or 34)
    local size = ringSize(icon)
    local base = f:GetFrameLevel()
    r:ClearAllPoints()
    r:SetPoint("TOP", spot, "TOP", 0, 0)
    r:SetSize(size, size)
    r:SetFrameLevel(base + 1)
    r.cd:SetFrameLevel(base + 2)
    r:Show()
    -- The icon above the ring, round and without its square border.
    f.art:ClearAllPoints()
    f.art:SetPoint("CENTER", r, "CENTER", 0, 0)
    f.art:SetSize(icon, icon)
    f.art:SetFrameLevel(base + 4)
    local shell = Style.GetShell(f.art)
    if shell then shell:Hide() end
    f.icon:ClearAllPoints()
    f.icon:SetAllPoints(f.art)
    roundIcon(f, true)
    -- The words above the icon: the time on it, the name under the ring.
    f.words:SetFrameLevel(base + 6)
    f.time:ClearAllPoints()
    f.time:SetPoint("CENTER", f.art, "CENTER", 0, 0)
    f.time:SetWidth(size)
    f.time:SetJustifyH("CENTER")
    local timeSize = tonumber(d[K.timeSize]) or 0
    Style.SetTextSize(f.time, timeSize > 0 and timeSize or math.max(10, math.floor(icon * 0.42 + 0.5)))
    local nameSize = tonumber(d[K.nameSize]) or 0
    Style.SetTextSize(f.name, nameSize > 0 and nameSize or Style.SIZE.title)
    f.name:ClearAllPoints()
    f.name:SetPoint("TOP", r, "BOTTOM", 0, math.floor(size * (0.5 - edge().outer) + 0.5) - 4)
    f.name:SetWidth(math.max(40, spot:GetWidth()))
    f.name:SetJustifyH("CENTER")
    f.name:SetShown(d[K.name] ~= false)
    f.bar:SetAlpha(0)
    -- Test mode sample and options preview: a ring part way down, still.
    if still or (f ~= Alert.frame and f ~= Alert.ghost) then
        pcall(r.cd.SetCooldown, r.cd, GetTime() - 4, 10)
        if r.cd.Pause then pcall(r.cd.Pause, r.cd) end
    end
    paintRing(f)
end

local function plain(f)
    if not f.blastaRing then return end
    f.blastaRing:Hide()
    roundIcon(f, false)
    local shell = Style.GetShell(f.art)
    if shell then shell:Show() end
    f.name:SetJustifyH("LEFT")
    f.name:Show()
    Style.SetTextSize(f.name, Style.SIZE.title)
    f.time:SetJustifyH("RIGHT")
    Style.SetTextSize(f.time, Style.SIZE.title)
    f.bar:SetAlpha(1)
end

local function badgeSize() return math.max(28, math.min(72, tonumber(db()[BADGE_SIZE]) or 42)) end

local function layoutBadge(f)
    local scale = badgeSize() / 42
    local size, gap = Pixel.Snap(f, badgeSize()), Pixel.Snap(f, 8 * scale)
    local width = math.max(24, math.min(146 * scale, f:GetWidth() - size - gap))
    plain(f)
    local shell = Style.GetShell(f.art)
    if not shell then shell = Style.Shell(f.art, { noBackground = true, noBevel = true, cornerPx = 0 }) end
    shell.opts.cornerPx = 0
    shell:Show()
    f.art:SetSize(size, size)
    f.art:ClearAllPoints()
    f.art:SetPoint("LEFT", f, "CENTER", -(size + gap + width) / 2, 0)
    local inset = Pixel.Px(f.art, Style.BorderPx(f.art))
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f.art, "TOPLEFT", inset, -inset)
    f.icon:SetPoint("BOTTOMRIGHT", f.art, "BOTTOMRIGHT", -inset, inset)
    if not f.blastaBadgeShade then
        local shade = f.art:CreateTexture(nil, "OVERLAY")
        shade:SetAllPoints(f.icon)
        shade:SetColorTexture(0, 0, 0, 0.53)
        f.blastaBadgeShade = shade
    end
    f.blastaBadgeShade:Show()
    if Style.CutShell and Style.CutCorner then
        local corner = Pixel.Snap(f.art, 9 * scale)
        Style.CutShell(f.art, corner)
        Style.CutCorner(f.art, corner, f.icon, f.blastaBadgeShade)
    end
    f.words:SetFrameLevel(f.art:GetFrameLevel() + 2)
    f.time:ClearAllPoints()
    f.time:SetPoint("CENTER", f.art)
    f.time:SetWidth(size)
    f.time:SetJustifyH("CENTER")
    Style.SetTextSize(f.time, math.floor(16 * scale + 0.5))
    f.name:ClearAllPoints()
    f.name:SetPoint("TOPLEFT", f.art, "TOPRIGHT", gap, -7 * scale)
    f.name:SetWidth(width)
    f.name:SetJustifyH("LEFT")
    f.name:Show()
    Style.SetTextSize(f.name, math.floor(Style.SIZE.title * scale + 0.5))
    f.bar:ClearAllPoints()
    f.bar:SetPoint("TOPLEFT", f.art, "TOPRIGHT", gap, -29 * scale)
    f.bar:SetSize(width, Pixel.Px(f.bar, math.max(1, math.floor(2 * scale + 0.5))))
    f.bar:SetAlpha(1)
    if f.bar.SetFillStyle and Enum.StatusBarFillStyle.Standard then f.bar:SetFillStyle(Enum.StatusBarFillStyle.Standard) end
    f.blastaBadge = true
end

local function clearBadge(f)
    if not f.blastaBadge then return end
    f.blastaBadge = nil
    f.blastaBadgeShade:Hide()
    if Style.GetCut and Style.GetCut(f.art) > 0 and Style.CutShell then Style.CutShell(f.art, 0) end
    f.bar:SetFillStyle(Enum.StatusBarFillStyle.Center)
    f.time:SetJustifyH("RIGHT")
    Style.SetTextSize(f.time, Style.SIZE.title)
end

local layout = Alert.Layout
function Alert.Layout(f, ...)
    local a, b = layout(f, ...)
    if badgeOn() then
        layoutBadge(f)
    else
        clearBadge(f)
        if on() then layoutRing(f) else plain(f) end
    end
    return a, b
end

local paint = Alert.Paint
function Alert.Paint(f, ...)
    local a, b = paint(f, ...)
    if on() then paintRing(f) end
    return a, b
end

-- The ring runs from the same duration object DaylightUI gives its line.
-- Short alerts (an interrupt lockout notice) have none: the ring stays empty.
local bar = Alert.Bar
function Alert.Bar(h, ...)
    local a, b = bar(h, ...)
    local r = on() and h.blastaRing
    if r then
        h.bar:SetAlpha(0)
        local ok = pcall(function()
            local index = Constants.LossOfControlConsts.LOSS_OF_CONTROL_ACTIVE_INDEX
            local data = C_LossOfControl.GetActiveLossOfControlData(index)
            local duration
            if type(data) == "table" and data.displayType == Alert.FULL then
                duration = C_LossOfControl.GetActiveLossOfControlDuration("player", index)
            end
            if type(duration) ~= "nil" then
                r.cd:SetCooldownFromDurationObject(duration)
            else
                r.cd:Clear()
            end
        end)
        if not ok then pcall(r.cd.Clear, r.cd) end
    end
    return a, b
end

-- Landing: the ring pops with the icon.
local land = Alert.Land
function Alert.Land(h, ...)
    if badgeOn() then
        Motion.SlideIn(h.words, -4, 0, Motion.FAST)
        return
    end
    local a, b = land(h, ...)
    if on() and h.blastaRing then Motion.Pop(h.blastaRing, Alert.POP, Motion.FAST) end
    return a, b
end

-- Options preview: a stand-in alert built from the same pieces, always as a
-- ring, so the settings can be judged before switching it on.
local refreshPreview
local function previewAlert(host)
    local f = CreateFrame("Frame", nil, host)
    f:SetSize(256, 1)
    f:EnableMouse(false)
    f.art = CreateFrame("Frame", nil, f)
    f.icon = f.art:CreateTexture(nil, "ARTWORK")
    Style.CropIcon(f.icon)
    f.icon:SetTexture(SAMPLE_ICON)
    f.words = CreateFrame("Frame", nil, f)
    f.words:SetAllPoints(f)
    f.name = Style.Text(f.words, Style.SIZE.title, "CENTER")
    Style.DressText(f.name, Style.SIZE.title, { outline = "OUTLINE" })
    Style.InkText(f.name, "VALUE")
    f.name:SetWordWrap(false)
    f.name:SetText(LOSS_OF_CONTROL_DISPLAY_STUN or "Stunned")
    f.time = Style.Text(f.words, Style.SIZE.title, "CENTER")
    Style.DressText(f.time, Style.SIZE.title, { outline = "OUTLINE" })
    Style.InkText(f.time, "pop")
    f.time:SetText(Alert.SAMPLE_TIME or "4.2")
    f.bar = Style.Bar(f)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(Alert.SAMPLE_FILL or 0.6)
    Style.PaintAccentBar(f.bar)
    return f
end

local function previewHeight()
    local d = db()
    local icon = tonumber(d[K.size]) or 34
    local size = ringSize(icon)
    local nameSize = tonumber(d[K.nameSize]) or 0
    return size + 14 + (nameSize > 0 and nameSize or (Style.SIZE.title or 16)) + 6
end

local badgeLabel = "Cut-corner control-loss icon"
local badgeDesc = "Show the remaining time inside the icon, with the effect name and a thin countdown line beside it."
local ringUnavailable = rows[1].disabled
extras.German[badgeLabel] = "Kontrollverlust-Icon mit Anschnitt"
extras.German[badgeDesc] = "Zeigt die Restzeit im Icon. Daneben stehen der Effektname und eine dünne ablaufende Linie."
table.insert(rows, 1, { type = "toggle", key = BADGE, label = badgeLabel, desc = badgeDesc,
    blastaSince = "1.9.4", disabled = ringUnavailable })
local ringLabel = rows[2].label
rows[2].disabled = function(get) return get(BADGE) == true or ringUnavailable(get) end
extras.German["Control-loss indicator size"] = "Größe des Kontrollverlust-Indikators"
extras.German["Test the control-loss indicator"] = "Kontrollverlust-Indikator testen"
extras.German["Test"] = "Testen"
table.insert(rows, 2, { type = "slider", key = BADGE_SIZE, label = "Control-loss indicator size",
    min = 28, max = 72, step = 1, unit = "px", blastaSince = "1.9.4" })
local worldTest, testStart
local TEST_DURATION = 5.3
local function layoutWorldTest()
    local game = Alert.game or _G.LossOfControlFrame
    if not (worldTest and game) then return end
    worldTest:ClearAllPoints()
    worldTest:SetPoint("CENTER", game, "CENTER")
    worldTest:SetScale(game:GetEffectiveScale() / UIParent:GetEffectiveScale())
    worldTest:SetSize(game:GetWidth(), game:GetHeight())
    if on() then
        clearBadge(worldTest)
        layoutRing(worldTest, true)
        local cooldown = worldTest.blastaRing.cd
        cooldown:SetCooldown(testStart, TEST_DURATION)
        if cooldown.Resume then cooldown:Resume() end
    else
        layoutBadge(worldTest)
    end
    Alert.Paint(worldTest)
end

local function testInWorld()
    local game = Alert.game or _G.LossOfControlFrame
    if not game or game:IsVisible() or InCombatLockdown() then return end
    if not worldTest then
        worldTest = previewAlert(UIParent)
        worldTest:SetFrameStrata("TOOLTIP")
        worldTest:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
    end
    testStart = GetTime()
    layoutWorldTest()
    local lastTenth
    local german = GetLocale() == "deDE"
    local function tick(self)
        local remaining = math.max(0, TEST_DURATION - (GetTime() - testStart))
        if remaining == 0 or game:IsVisible() then self:Hide(); return end
        self.bar:SetValue(remaining / TEST_DURATION)
        local tenth = math.ceil(remaining * 10)
        if lastTenth ~= tenth then
            lastTenth = tenth
            local text = ("%.1f"):format(tenth / 10)
            self.time:SetText(german and (text:gsub("%.", ",")) or text)
        end
    end
    worldTest:Show()
    worldTest:SetScript("OnUpdate", tick)
    tick(worldTest)
end

local testDesc = "Show a sample stun at the in-game control-loss position."
extras.German[testDesc] = "Zeigt eine Beispielbetäubung an der Kontrollverlust-Position im Spiel."
table.insert(rows, 3, { type = "button", label = "Test the control-loss indicator", text = "Test",
    desc = testDesc, func = testInWorld })

local function sample(parent)
    local host = CreateFrame("Frame", nil, parent)
    local badge, ringPreview = previewAlert(host), previewAlert(host)
    local lastWidth
    local function refresh(width)
        lastWidth = width
        local showRing = on()
        local size = badgeSize()
        local height = showRing and previewHeight() or size + 12
        host:SetSize(width, height)
        badge:SetShown(not showRing)
        ringPreview:SetShown(showRing)
        if showRing then
            ringPreview:SetPoint("TOP", host, "TOP", 0, -6)
            layoutRing(ringPreview, true)
        else
            badge:SetSize(math.min(width, math.floor(196 * size / 42 + 0.5)), size)
            badge:SetPoint("TOP", host, "TOP", 0, -6)
            layoutBadge(badge)
            Alert.Paint(badge)
        end
        return height
    end
    refreshPreview = function() if lastWidth then refresh(lastWidth) end end
    return { frame = host, Refresh = refresh, Parts = function()
        if on() then
            return { { region = ringPreview.art, label = extras.Translate(ringLabel), keys = { KEY, K.size } } }
        end
        return { { region = badge.art, label = extras.Translate(badgeLabel), keys = { BADGE, BADGE_SIZE } } }
    end }
end

card.blastaSample = sample

-- Settings apply at once: the live alert, its ghost and sample, the preview.
DUI.On("SettingChanged", function(scope, path)
    if scope ~= "Skins" or type(path) ~= "string" or (path ~= BADGE and path ~= BADGE_SIZE and path:sub(1, #KEY) ~= KEY) then return end
    for _, f in pairs({ Alert.frame, Alert.ghost, Alert.sample }) do
        Alert.Layout(f)
        Alert.Paint(f)
    end
    if refreshPreview then refreshPreview() end
    if worldTest and worldTest:IsShown() then layoutWorldTest() end
end)

-- The alert may already be built (Blasta loaded late): lay it out again.
if Alert.frame then
    Alert.Layout(Alert.frame)
    Alert.Paint(Alert.frame)
end

extras.Loaded("CcRing")
