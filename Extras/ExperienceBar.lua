local ADDON, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("InfoPanel")
if not (ns and ns.XP and ns.Panel and ns.XP.Apply and ns.Panel.Layout) then return end

local XP, Panel, Style, Pixel = ns.XP, ns.Panel, DUI.Style, DUI.Pixel
local mod = DUI:GetModule("InfoPanel")
local ROOT, TEST = "experienceStyle", "blastaExperience"
local MASKS = "Interface\\AddOns\\" .. ADDON .. "\\Media\\XP\\"
local defaults = {
    border = -1, format = "native", rested = true, align = "CENTER",
    left = "straight", right = "straight",
    x = 0, y = 0, ownColor = false, color = { 1, 1, 1 },
    textZones = false, gainMotion = true, killEstimate = true,
    zones = {
        LEFT = { format = "off", x = 0, y = 0 },
        CENTER = { format = "existing", x = 0, y = 0 },
        RIGHT = { format = "eta", x = 0, y = 0 },
    },
}
extras.ExperienceDefaults = defaults
local function cfg() return DUI:Get(ADDON, ROOT) or defaults end

local shell, original
local masks, maskKey, halves
local sides = { "LEFT", "RIGHT" }
local attached = setmetatable({}, { __mode = "k" })
local function clip(tex)
    if not (tex and tex.AddMaskTexture) or attached[tex] == maskKey then return end
    if maskKey then
        if not attached[tex] then
            tex:AddMaskTexture(masks[1])
            tex:AddMaskTexture(masks[2])
        end
    elseif attached[tex] then
        tex:RemoveMaskTexture(masks[1])
        tex:RemoveMaskTexture(masks[2])
    end
    attached[tex] = maskKey
end
extras.ExperienceClip = clip

local function slantTexture(side, reverse, cut)
    local left = side == "LEFT"
    local suffix = (left ~= reverse) and "l" or "r"
    return DUI.MEDIA .. (reverse and "mask-trail-" or "mask-slant-") .. suffix
        .. (cut * 4 > 48 and "-sharp.png" or ".png")
end

-- The native shell can reverse one end. For the reverse trapezoid, draw
-- two native single-end shells, each clipped at the centre of the bar.
local function reverseShell(cut)
    local frame = XP.frame
    if not halves then
        halves = {}
        for i, side in ipairs(sides) do
            local clipper = CreateFrame("Frame", nil, frame)
            clipper:SetClipsChildren(true)
            clipper:SetFrameLevel(shell:GetFrameLevel())
            local pad = 64
            if i == 1 then
                clipper:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
                clipper:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 0, -pad)
            else
                clipper:SetPoint("TOPLEFT", frame, "TOP", 0, pad)
                clipper:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
            end
            local body = CreateFrame("Frame", nil, clipper)
            body:SetAllPoints(frame)
            body:SetFrameLevel(shell:GetFrameLevel() + 1)
            halves[i] = { clipper = clipper, body = body, side = side:lower() }
        end
    end
    shell:Hide()
    for _, half in ipairs(halves) do
        Style.Shell(half.body, shell.opts)
        Style.Slant(half.body, half.side, cut, nil, half.side)
        half.clipper:Show()
    end
end

local function layoutMasks()
    local bar = XP.bar
    local h, w = bar:GetHeight(), bar:GetWidth()
    if h <= 0 or w <= 0 then return end
    local inset = Pixel.Px(XP.frame, Style.BorderPx(XP.frame))
    local s = cfg()
    local left, right = s.left or "straight", s.right or "straight"
    if XP.vertical then left, right = "straight", "straight" end
    local l, r = left ~= "straight", right ~= "straight"
    local side = l and (r and "both" or "left") or (r and "right" or nil)
    local fullHeight = XP.frame:GetHeight()
    local cut = side and math.min(w / 4, fullHeight * 0.65) or 0
    local reverseBoth = l and r and left == "bottom" and right == "bottom"
    if reverseBoth then
        local old = Style.GetSlant(XP.frame)
        if old and old.side then Style.Slant(XP.frame, nil, 0) end
        reverseShell(cut)
    else
        if halves then
            for _, half in ipairs(halves) do half.clipper:Hide() end
            shell:Show()
        end
        local under = left == "bottom" and "left" or right == "bottom" and "right" or nil
        local old = Style.GetSlant(XP.frame)
        if (side or (old and old.side)) and (not old or old.side ~= side or old.cut ~= cut or old.under ~= under) then
            Style.Slant(XP.frame, side, cut, nil, under)
        end
    end
    local radius = math.max(0, math.min((shell.radius or 0) - inset, h / 2, w / 2))
    -- Each end mask is clamped to solid white toward the middle.
    -- Eight vertical ratios keep the radius circular as the bar height changes.
    local step = not XP.vertical and (side or extras.FrameCornerOverride(s) ~= nil or (s.border or -1) >= 0)
        and math.min(8, math.floor(radius * 16 / h + 0.5)) or 0
    local previous = maskKey
    maskKey = (side or step > 0) and true or nil
    if not maskKey and not previous then return end
    if maskKey then
        masks = masks or { XP.frame:CreateMaskTexture(), XP.frame:CreateMaskTexture() }
        for i, edge in ipairs(sides) do
            local m = masks[i]
            local direction = i == 1 and left or right
            m:ClearAllPoints()
            if direction ~= "straight" then
                local slope = math.sqrt(1 + (cut / fullHeight) ^ 2)
                local x = (i == 1 and 1 or -1) * inset * slope
                m:SetTexture(slantTexture(edge, direction == "bottom", cut), "CLAMP", "CLAMP")
                m:SetPoint(edge, XP.frame, edge, x, 0)
                m:SetSize(4 * cut, fullHeight)
            elseif step > 0 then
                m:SetTexture(MASKS .. edge .. step .. ".tga", "CLAMP", "CLAMP")
                m:SetPoint(edge, bar, edge)
                m:SetSize(h * step / 16, h)
            else
                m:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMP", "CLAMP")
                m:SetAllPoints(bar)
            end
        end
    elseif not maskKey and masks then
        for _, m in ipairs(masks) do m:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMP", "CLAMP") end
    end
    for _, b in ipairs({ XP.bar, XP.banked, XP.rested, XP.repBar }) do
        clip(b:GetStatusBarTexture())
        clip(Style.BarBack(b))
    end
    clip(XP.shimmer)
    clip(XP.repShine)
    if ns.XPGain then
        clip(ns.XPGain.flash)
        clip(ns.XPGain.band)
    end
    for _, part in ipairs(extras.ExperienceGainParts or {}) do clip(part) end
    for _, tick in ipairs(XP.tickList) do clip(tick) end
end

local function applyText()
    local s, text = cfg(), XP.text
    local align = s.align or defaults.align
    local anchor = XP.vertical and (align == "LEFT" and "BOTTOM" or align == "RIGHT" and "TOP" or "CENTER") or align
    local pad = align == "LEFT" and 3 or align == "RIGHT" and -3 or 0
    text:ClearAllPoints()
    text:SetPoint(anchor, XP.bar, anchor, (XP.vertical and 0 or pad) + (s.x or 0),
        (XP.vertical and pad or 0) + (s.y or 0))
    text:SetJustifyH(align)
    local color = s.ownColor and s.color or original.text
    if XP.tint then
        XP.tint = { color[1], color[2], color[3], color[4] or 1 }
    else
        text:SetTextColor(color[1], color[2], color[3], color[4] or 1)
    end
end

local nativeFormat = XP.Format
local function formatExisting(d, value)
    if d.rep or (issecretvalue and (issecretvalue(value) or issecretvalue(d.max))) then return nativeFormat(d, value) end
    local s = cfg()
    if (s.format == "native" or not s.format) and s.rested ~= false then return nativeFormat(d, value) end
    local current, max = BreakUpLargeNumbers(value), BreakUpLargeNumbers(d.max)
    local percent = math.floor(value / d.max * 100) .. "%"
    local result
    if s.format == "off" then return end
    if s.format == "percent" then result = percent
    elseif s.format == "values" then result = current .. " / " .. max
    elseif s.format == "both" then result = current .. " / " .. max .. "  ·  " .. percent
    elseif s.format == "remaining" then
        result = string.format(DUI.L["%s XP remaining"], BreakUpLargeNumbers(math.max(0, d.max - value)))
    else
        if XP.showText then result = current .. " / " .. max end
        if XP.showPercent then result = result and result .. "   " .. percent or percent end
    end
    if result and s.rested ~= false and d.rested > 0 and s.format ~= "percent" then
        result = result .. "   (+" .. BreakUpLargeNumbers(d.rested) .. ")"
    end
    return result
end

function XP.Format(d, value)
    if cfg().textZones and not d.rep then return nil end
    return formatExisting(d, value)
end

local zoneOrder = { "LEFT", "CENTER", "RIGHT" }
local zoneLabels = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }
local zoneText = {}
local gains, baseline = {}, nil
local window, idleLimit = 900, 300

local function sampleGain()
    local now, level, value, max = GetTime(), UnitLevel("player"), UnitXP("player"), UnitXPMax("player")
    if type(value) ~= "number" or type(max) ~= "number" or type(level) ~= "number"
        or (issecretvalue and (issecretvalue(value) or issecretvalue(max) or issecretvalue(level))) or max <= 0 then return end
    local old = baseline
    baseline = { level = level, value = value, max = max }
    if not old then return end
    local gain
    if level == old.level and max == old.max then
        gain = value - old.value
    elseif level == old.level + 1 then
        gain = old.max - old.value + value
    end
    if not gain or gain < 0 then wipe(gains); return end
    if gain == 0 then return end
    while gains[1] and gains[1].time < now - window do table.remove(gains, 1) end
    gains[#gains + 1] = { time = now, xp = gain }
end

local function estimate(remaining)
    local now = GetTime()
    local last = gains[#gains]
    if not last or now - last.time > idleLimit then return end
    local first, total
    for _, gain in ipairs(gains) do
        if gain.time >= now - window then
            if first then total = total + gain.xp else first, total = gain.time, 0 end
        end
    end
    if not first or total == 0 or last.time - first < 30 then return end
    return math.max(1, math.ceil(remaining * (now - first) / total / 60))
end

local function formatEstimate(minutes)
    if minutes < 60 then return extras.Translate("Level in ~%d min"):format(minutes) end
    return extras.Translate("Level in ~%d h %02d min"):format(math.floor(minutes / 60), minutes % 60)
end

local function stopEstimate(text)
    if not text.estimateTarget then return end
    text.estimateTarget, text.estimateShown = nil, nil
    DUI.Motion.Tween(text, 0, 0)
end

local function setZoneText(text, value)
    if type(value) ~= "number" then
        stopEstimate(text)
        text:SetText(value)
        return
    end
    local from = text.estimateShown
    if text.estimateTarget == value and DUI.Motion.On() then return end
    text.estimateTarget = value
    DUI.Motion.Tween(text, from or value, value, 0.32, function(current)
        local minutes = math.floor(current + 0.5)
        text.estimateShown = minutes
        text:SetText(formatEstimate(minutes))
    end)
end

local function zoneValue(format, d)
    if format == "existing" then return formatExisting(d, d.value) end
    local remaining = math.max(0, d.max - d.value)
    if format == "eta" then return estimate(remaining) end
    if format == "remaining" then return extras.Translate("%s XP remaining"):format(BreakUpLargeNumbers(remaining)) end
    if format == "percent" then return math.floor(d.value / d.max * 100) .. "%" end
    if format == "values" then return BreakUpLargeNumbers(d.value) .. " / " .. BreakUpLargeNumbers(d.max) end
    if format == "rested" and d.rested > 0 then return "(+" .. BreakUpLargeNumbers(d.rested) .. ")" end
end

local function updateZones()
    if not XP.frame then return end
    local s = cfg()
    local d = s.textZones and XP.frame:IsShown() and XP.Read()
    if not d or d.rep or (issecretvalue and (issecretvalue(d.value) or issecretvalue(d.max)))
        or d.max <= 0 then
        for _, text in pairs(zoneText) do
            stopEstimate(text)
            text:Hide()
        end
        return
    end
    local color = s.ownColor and s.color or (original and original.text)
    local width = XP.vertical and XP.bar:GetHeight() or XP.bar:GetWidth()
    local zones, values = s.zones or defaults.zones, {}
    for _, side in ipairs(zoneOrder) do
        values[side] = zoneValue((zones[side] or defaults.zones[side]).format, d)
    end
    for _, side in ipairs(zoneOrder) do
        local zone = zones[side] or defaults.zones[side]
        local value = values[side]
        local text = zoneText[side]
        if value and width > 12 then
            if not text then
                text = Style.Text(XP.bar, 9, side, ns.MEDIA and ns.MEDIA.fonts and ns.MEDIA.fonts.xp)
                text:SetWordWrap(false)
                zoneText[side] = text
            end
            local x = zone.x or 0
            local edge = side == "LEFT" and 3 or side == "RIGHT" and -3 or 0
            local y = zone.y or 0
            if text.zoneX ~= x or text.zoneY ~= y or text.zoneVertical ~= XP.vertical then
                local anchor = XP.vertical and (side == "LEFT" and "BOTTOM" or side == "RIGHT" and "TOP" or "CENTER") or side
                text:ClearAllPoints()
                text:SetPoint(anchor, XP.bar, anchor, x + (XP.vertical and 0 or edge), y + (XP.vertical and edge or 0))
                text:SetRotation(XP.vertical and XP.TURN or 0)
                text.zoneX, text.zoneY, text.zoneVertical = x, y, XP.vertical
            end
            local span
            if side == "CENTER" then
                span = (values.LEFT or values.RIGHT) and width / 2 or width
            elseif values.CENTER then
                span = width / 4
            else
                local other = side == "LEFT" and "RIGHT" or "LEFT"
                span = values[other] and width / 2 or width
            end
            local available = math.max(1, span - 6 - math.abs(x))
            if text.zoneWidth ~= available then
                text:SetWidth(available)
                text.zoneWidth = available
            end
            Style.SetTextSize(text, mod.db.xp.textSize or 9)
            if color then text:SetTextColor(unpack(color)) end
            setZoneText(text, value)
            text:Show()
        elseif text then
            stopEstimate(text)
            text:Hide()
        end
    end
end

local nativeLayout = Panel.Layout
function Panel.Layout(db)
    if XP.frame and not shell then
        shell = Style.GetShell(XP.frame)
        original = { border = shell.opts.borderPx, radius = shell.opts.cornerPx, text = { XP.text:GetTextColor() } }
    end
    if shell then
        local s = cfg()
        local border = s.border or -1
        shell.opts.borderPx = border >= 0 and border or original.border
        shell.opts.cornerPx = extras.FrameCornerOverride(s) or original.radius
    end
    return nativeLayout(db)
end

hooksecurefunc(Panel, "ApplyAlpha", function()
    if not shell then return end
    local border = cfg().border or -1
    if border < 0 then return end
    shell.opts.noBorder = border == 0
    shell.opts.noBevel = border == 0
    shell.opts.shadowAlpha = border == 0 and 0 or nil
end)

hooksecurefunc(XP, "Apply", function()
    if not shell then return end
    layoutMasks()
    applyText()
end)
hooksecurefunc(XP, "Update", function()
    updateZones()
    if not (shell and maskKey) then return end
    -- Gain textures are allocated by the native bar on its first gain.
    if ns.XPGain then clip(ns.XPGain.flash); clip(ns.XPGain.band) end
end)

DUI.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, initialLogin, reload)
    if initialLogin or reload then baseline = nil; wipe(gains) end
    sampleGain()
end)
DUI.RegisterEvent("PLAYER_XP_UPDATE", function(_, unit)
    if unit ~= "player" then return end
    sampleGain()
    if cfg().textZones then updateZones() end
end)
DUI.RegisterEvent("PLAYER_LEVEL_UP", function()
    C_Timer.After(0, function()
        sampleGain()
        if cfg().textZones then updateZones() end
    end)
end)
local ticker
local function updateTicker()
    if cfg().textZones then
        if not ticker then ticker = C_Timer.NewTicker(30, updateZones) end
    elseif ticker then
        ticker:Cancel()
        ticker = nil
    end
end

local nativeRead = XP.Read
function XP.Read()
    if DUI.testMode and DUI.TestPartShown(TEST) then
        return { value = 6400, max = 10000, rested = 1800, banked = 700, color = XP.COLOR, label = DUI.L["Experience"] }
    end
    return nativeRead()
end
local function refreshGeometry()
    if mod.enabled and XP.frame then
        local inset = Panel.Layout(mod.db)
        XP.Apply(mod.db.xp, inset)
    end
end
local function refreshTest()
    if not XP.frame then return end
    -- A preview must not look like a real gain to the native gain counter.
    if ns.XPGain then ns.XPGain.last = nil end
    if extras.ExperienceGainReset then extras.ExperienceGainReset() end
    XP.shown = nil
    XP.Update()
end
DUI.RegisterTestPart(TEST, "Experience bar", 91, function()
    return mod.enabled and mod.db.xp.enabled == true
end)
DUI.On("TestModeChanged", refreshTest)
DUI.On("TestPartChanged", function(key) if key == TEST then refreshTest() end end)
DUI.On("Login", function()
    updateTicker()
    DUI.AfterCombat(refreshGeometry, "blastaExperienceGeometry")
end)
DUI.On("SettingChanged", function(scope, path)
    if scope ~= ADDON or type(path) ~= "string" or not path:match("^experienceStyle%.") then return end
    if path == ROOT .. ".textZones" then updateTicker() end
    if not shell then return end
    if path == ROOT .. ".border" then
        DUI.AfterCombat(refreshGeometry, "blastaExperienceGeometry")
    elseif path == ROOT .. ".frameShape" or path == ROOT .. ".left" or path == ROOT .. ".right" then
        shell.opts.cornerPx = extras.FrameCornerOverride(cfg()) or original.radius
        Style.LayoutShell(shell)
        layoutMasks()
    else
        applyText()
        XP.Update()
    end
end)

function extras.ExperiencePage()
    local directions = { straight = "Straight", top = "Top corner projects", bottom = "Bottom corner projects" }
    local order = { "straight", "top", "bottom" }
    local page = { id = "experienceStyle", label = "Experience bar", preview = { TEST }, groups = {
        { label = "Appearance", items = {
            { type = "slider", key = ROOT .. ".border", label = "Experience border thickness", min = -1, max = 12, step = 1, unit = "px",
                desc = "Minus one follows Daylight. Zero hides the border." },
            extras.FrameShapeOption(ADDON, ROOT, cfg),
            { type = "dropdown", key = ROOT .. ".left", label = "Left edge direction", values = directions, order = order },
            { type = "dropdown", key = ROOT .. ".right", label = "Right edge direction", values = directions, order = order },
            { type = "slider", key = ROOT .. ".height", label = "Experience bar height",
                min = Panel.XP_MIN[2], max = Panel.XP_MAX[2], step = 1, unit = "px",
                get = function() return mod.db.xp.height end,
                set = function(v) return DUI:Set("InfoPanel", "xp.height", v) end,
                default = function() return mod.defaults.xp.height end },
        } },
        { label = "Text", items = {
            { type = "toggle", key = ROOT .. ".textZones", label = "Use three experience text positions",
                desc = "Choose content and offsets independently for the left, center and right of the experience bar." },
            { type = "dropdown", key = ROOT .. ".format", label = "Experience text format",
                values = { native = "Daylight default", off = "Off", percent = "Percent only",
                    values = "Current / maximum", both = "Values and percent", remaining = "Remaining XP" },
                order = { "native", "off", "percent", "values", "both", "remaining" } },
            { type = "toggle", key = ROOT .. ".rested", label = "Include rested XP" },
            { type = "slider", key = ROOT .. ".textSize", label = "Experience text size", min = 7, max = 40, step = 1,
                get = function() return mod.db.xp.textSize end,
                set = function(v) return DUI:Set("InfoPanel", "xp.textSize", v) end,
                default = function() return mod.defaults.xp.textSize end },
            { type = "dropdown", key = ROOT .. ".align", label = "Experience text alignment",
                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" }, order = { "LEFT", "CENTER", "RIGHT" } },
            { type = "slider", key = ROOT .. ".x", label = "Text left / right", min = -100, max = 100, step = 1, unit = "px" },
            { type = "slider", key = ROOT .. ".y", label = "Text up / down", min = -40, max = 40, step = 1, unit = "px" },
            { type = "toggle", key = ROOT .. ".ownColor", label = "Use custom experience text color" },
            { type = "color", key = ROOT .. ".color", label = "Custom text color",
                disabled = function(get) return get(ROOT .. ".ownColor") ~= true end },
        } },
    } }
    if extras.ExperienceGainGroup then table.insert(page.groups, 2, extras.ExperienceGainGroup()) end
    local function zonesOff(get) return get(ROOT .. ".textZones") ~= true end
    for _, side in ipairs(zoneOrder) do
        local key = ROOT .. ".zones." .. side
        page.groups[#page.groups + 1] = { label = zoneLabels[side], items = {
            { type = "dropdown", key = key .. ".format", label = "Experience text content",
                values = { off = "Off", existing = "Existing experience text", eta = "Estimated time to level up",
                    percent = "Percent only", values = "Current / maximum", remaining = "Remaining XP", rested = "Rested XP" },
                order = { "off", "existing", "eta", "percent", "values", "remaining", "rested" }, disabled = zonesOff },
            { type = "slider", key = key .. ".x", label = "Text left / right", min = -60, max = 60,
                step = 1, unit = "px", disabled = zonesOff },
            { type = "slider", key = key .. ".y", label = "Text up / down", min = -40, max = 40,
                step = 1, unit = "px", disabled = zonesOff },
        } }
    end
    return extras.ShowDaylightRequirements(page, mod, "xp.enabled")
end

extras.Loaded("ExperienceBar")
