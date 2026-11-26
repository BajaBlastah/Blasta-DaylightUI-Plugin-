local ADDON, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("UnitFrames")
local ns = mod and mod.ns
local Auras, Groups = ns and ns.Auras, ns and ns.AuraGroups
local Style, Pixel = DUI.Style, DUI.Pixel
if not (Auras and Auras.InitButton and Auras.SetOwnSize and Auras.Create and Auras.Apply
    and Auras.DrawSample and Auras.ShowSample and Auras.HolderFor and Auras.IsPlain
    and Groups and Groups.Place and Style.DispelEdge and Style.SetAuraTime and Pixel and Pixel.Px) then return end

local buffsModule = DUI:GetModule("Buffs")
local buffs = buffsModule and buffsModule.ns
local WHITE = "Interface\\Buttons\\WHITE8X8"
local MASKS = "Interface\\AddOns\\" .. ADDON .. "\\Media\\AuraBars\\"
-- Blasta's own angle masks. The diagonal spans the middle texels, and the
-- outer columns stay fully open or closed, so clamping never smears an edge.
local MASK_SIZE, MASK_MARGIN = 128, 4
local BORDER_COLOR = { 0, 0, 0, 0.95 }
local BACK_COLOR = { 0.07, 0.07, 0.09, 0.92 }
local defaults = { enabled = false, icon = "left", angle = "straight", alternate = false, height = 18, spacing = 6,
    swapText = false, reverse = false, style = "standard", lineThickness = 2, growth = "auto",
    extendLeft = 0, extendRight = 0, columns = 1, showNames = true }
-- Frames whose bars can reach past the frame's ends (not group frames).
local STRETCHABLE = { player = true, target = true, focus = true, pet = true }
-- Every frame keeps its own bar settings: blastaAuraBars.<frame>.<buff|debuff>.
-- The frame is the page id of the frame's options. Raid sizes share one set.
local FRAMES = {
    { id = "player", label = "Player", buff = "playerAuras.buffSize", debuff = "playerAuras.debuffSize",
        show = { buff = "playerAuras.buffs", debuff = "playerAuras.debuffs" }, timed = "playerAuras.blastaTimedBuffs" },
    { id = "target", label = "Target", buff = "targetAuras.buffSize", debuff = "targetAuras.debuffSize",
        show = { buff = "targetAuras.buffs", debuff = "targetAuras.debuffs" }, timed = "targetAuras.blastaTimedBuffs" },
    { id = "focus", label = "Focus", buff = "focusAuras.buffSize", debuff = "focusAuras.debuffSize",
        show = { buff = "focusAuras.buffs", debuff = "focusAuras.debuffs" }, timed = "focusAuras.blastaTimedBuffs" },
    { id = "pet", label = "Pet", buff = "petAuras.buffSize", debuff = "petAuras.debuffSize",
        show = { buff = "petAuras.buffs", debuff = "petAuras.debuffs" }, timed = "petAuras.blastaTimedBuffs" },
    { id = "party", label = "Party", buff = "party.auras.buffs.size", debuff = "party.auras.debuffs.size",
        show = { buff = "party.auras.buffs.show", debuff = "party.auras.debuffs.show" }, timed = "party.auras.buffs.blastaTimed" },
    { id = "raid", label = "Raid", buff = "raid.auras.buffs.size", debuff = "raid.auras.debuffs.size",
        show = { buff = "raid.auras.buffs.show", debuff = "raid.auras.debuffs.show" }, timed = "raid.auras.buffs.blastaTimed" },
}
mod.defaults.blastaAuraBars = {}
for _, frame in ipairs(FRAMES) do
    local entry = {}
    for _, kind in ipairs({ "buff", "debuff" }) do
        entry[kind] = {}
        for key, value in pairs(defaults) do entry[kind][key] = value end
    end
    mod.defaults.blastaAuraBars[frame.id] = entry
end

-- Earlier 1.5 builds kept one set for every frame. It moves to the player
-- and target, where the bars were meant to show; the groups start off.
local migrated
local function migrate()
    local db = mod.db
    if migrated or not db then return end
    migrated = true
    local settings = db.blastaAuraBars
    if type(settings) ~= "table" then return end
    for _, kind in ipairs({ "buff", "debuff" }) do
        local legacy = settings[kind]
        if type(legacy) == "table" then
            local copy = {}
            for key, value in pairs(legacy) do copy[key] = value end
            for _, frame in ipairs({ "player", "target" }) do
                for key, value in pairs(copy) do
                    DUI:Set(mod.name, "blastaAuraBars." .. frame .. "." .. kind .. "." .. key, value)
                end
            end
            DUI:Set(mod.name, "blastaAuraBars." .. kind, nil)
        end
    end
end

local function get(frame, kind)
    migrate()
    local settings = mod.db and mod.db.blastaAuraBars
    local entry = settings and frame and settings[frame]
    return type(entry) == "table" and type(entry[kind]) == "table" and entry[kind] or defaults
end

local ANGLES = { straight = true, top = true, bottom = true }
-- Earlier 1.5 builds stored an angled side. Any angled choice becomes the
-- top corner on the side opposite the icon.
local function angleOf(cfg)
    if ANGLES[cfg.angle] then return cfg.angle end
    if cfg.edge and cfg.edge ~= "straight" then return "top" end
    return "straight"
end

local function clampNumber(value, fallback, low, high)
    return math.max(low, math.min(high, math.floor((tonumber(value) or fallback) + .5)))
end
local function barHeight(frame, kind) return clampNumber(get(frame, kind).height, defaults.height, 12, 40) end
local function barSpacing(frame, kind) return clampNumber(get(frame, kind).spacing, defaults.spacing, 0, 20) end

local function barRows(frame, kind)
    local rows = {}
    do
        local prefix = "blastaAuraBars." .. frame.id .. "." .. kind .. "."
        local function value(key)
            local cfg = get(frame.id, kind)
            if key == "angle" then return angleOf(cfg) end
            local v = cfg[key]
            if v == nil then return defaults[key] end
            return v
        end
        -- Only while the frame shows this kind of aura in DaylightUI.
        local function shown()
            local key = frame.show and frame.show[kind]
            if not key then return true end
            local on = DUI:Get(mod.name, key)
            if on == nil then on = DUI.DB.GetPath(mod.defaults, key) end
            return on == true
        end
        local function off() return not shown() or value("enabled") ~= true end
        local function elegant() return value("style") == "elegant" end
        -- Own readers, so pages that map keys (raid sizes) leave these alone.
        local function row(spec)
            local key = spec.field
            spec.key = prefix .. key
            spec.field = nil
            spec.get = function() return value(key) end
            spec.set = function(v) return DUI:Set(mod.name, prefix .. key, v) end
            spec.default = function() return defaults[key] end
            spec.blastaJumpAnchor = frame[kind]
            spec.blastaAuraBarKind = kind
            spec.blastaAuraBarFrame = frame.id
            return spec
        end
        local items = {
            row({ type = "toggle", field = "enabled", label = kind == "buff" and "Show buffs as bars" or "Show debuffs as bars",
                desc = "Displays this frame's aura rows as duration bars. Reload to switch the live frames.",
                reload = true, blastaSince = "1.5", disabled = function() return not shown() end }),
            row({ type = "dropdown", field = "style", label = "Aura bar style",
                desc = "Elegant shows the remaining time as a fine line below the text.",
                values = { standard = "Blasta Standard", elegant = "Blasta Elegant" },
                order = { "standard", "elegant" }, blastaSince = "1.6", disabled = off }),
            row({ type = "slider", field = "lineThickness", label = "Duration line thickness",
                min = 1, max = 4, step = 1, unit = "px", disabled = off,
                hidden = function() return not elegant() end }),
            row({ type = "dropdown", field = "icon", label = "Aura icon side",
                values = { left = "Left", right = "Right" }, order = { "left", "right" }, disabled = off }),
            row({ type = "dropdown", field = "angle", label = "Angled end",
                desc = "Angles the end opposite the icon and sets which of its corners projects.",
                values = { straight = "Straight", top = "Top corner projects", bottom = "Bottom corner projects" },
                order = { "straight", "top", "bottom" }, disabled = off, hidden = elegant }),
            row({ type = "toggle", field = "alternate", label = "Alternate the angle",
                desc = "Every second bar angles the other corner.",
                disabled = function() return off() or value("angle") == "straight" end, hidden = elegant }),
            row({ type = "slider", field = "height", label = "Bar height", min = 12, max = 40, step = 1, unit = "px",
                desc = "How tall each aura bar is.", disabled = off }),
            row({ type = "slider", field = "spacing", label = "Bar spacing", min = 0, max = 20, step = 1, unit = "px",
                desc = "The gap between the aura bars.", disabled = off }),
            row({ type = "dropdown", field = "growth", label = "Aura bar growth",
                desc = "Choose whether aura bars grow below or above the unit frame, or follow the aura position.",
                values = { auto = "Follow aura position", up = "Grow upwards", down = "Grow downwards" },
                order = { "auto", "up", "down" }, blastaSince = "1.6", disabled = off }),
            row({ type = "toggle", field = "swapText", label = "Swap name and time",
                desc = "Shows the time on the left and the aura's name on the right.", disabled = off }),
            row({ type = "toggle", field = "reverse", label = "Reverse fill",
                desc = "The bar fills from the right, so it runs out toward the right end.", disabled = off }),
        }
        if STRETCHABLE[frame.id] then
            items[#items + 1] = row({ type = "slider", field = "columns", label = "Bars side by side",
                min = 1, max = 3, step = 1,
                desc = "How many bars share a row. More columns take less height; the row's width is shared between them.",
                blastaSince = "1.6", disabled = off })
            items[#items + 1] = row({ type = "toggle", field = "showNames", label = "Show aura names",
                desc = "The aura's name on each bar. With two or three columns, icon and time alone are often clearer.",
                blastaSince = "1.6", disabled = off })
            items[#items + 1] = row({ type = "slider", field = "extendLeft", label = "Extend bars to the left",
                min = -150, max = 200, step = 1, unit = "px",
                desc = "Lets the bars reach past the frame's left end, e.g. so the icons sit over the portrait. Negative values shorten them.",
                blastaSince = "1.6", disabled = off })
            items[#items + 1] = row({ type = "slider", field = "extendRight", label = "Extend bars to the right",
                min = -150, max = 200, step = 1, unit = "px",
                desc = "Lets the bars reach past the frame's right end. Negative values shorten them.",
                blastaSince = "1.6", disabled = off })
        end
        if kind == "buff" and frame.timed then
            -- The same switch as beside the buff size: filters the row itself.
            local timedKey = frame.timed
            table.insert(items, 2, {
                type = "toggle", key = timedKey, label = "Only buffs with a duration",
                desc = "Leaves out buffs that never run out, like auras and long-term effects.",
                blastaJumpAnchor = frame[kind], blastaAuraBarKind = kind, blastaAuraBarFrame = frame.id,
                get = function() return DUI:Get(mod.name, timedKey) == true end,
                set = function(v) return DUI:Set(mod.name, timedKey, v == true) end,
                default = function() return false end,
                disabled = function() return not shown() end,
            })
        end
        rows = items
    end
    return rows
end

-- One card on Blasta's Auras page: pick a frame, then its buff and its debuff
-- bars. The page's preview shows the picked frame (Settings.lua).
function extras.AuraBarCard()
    local options = DUI.Options
    if not (options and options.PickCard) then return end
    local choices = {}
    for _, frame in ipairs(FRAMES) do
        local items = {}
        for _, kind in ipairs({ "buff", "debuff" }) do
            items[#items + 1] = { type = "text", label = kind == "buff" and "Buff bars" or "Debuff bars" }
            for _, row in ipairs(barRows(frame, kind)) do items[#items + 1] = row end
        end
        choices[#choices + 1] = { id = frame.id, label = frame.label, items = items }
    end
    return options.PickCard({ label = "Aura bars", tab = "Aura bars", choices = choices,
        pickDesc = "The unit frame whose buff and debuff bars the rows below set." })
end

-- The settings frame of a container: its unit frame's page id.
local function frameOf(c)
    local parent = c and c:GetParent()
    local spec = parent and parent.spec
    if not spec then return end
    local id = spec.group or spec.unit
    if type(id) ~= "string" then return end
    return id:match("^raid") and "raid" or id
end

local buffKinds = { buff = "buff", selfbuff = "buff", tilebuff = "buff",
    debuff = "debuff", selfdebuff = "debuff", gdebuff = "debuff" }
local containers = setmetatable({}, { __mode = "k" })
local liveButtons = setmetatable({}, { __mode = "k" })
local liveModes = {}
local creating

local function mode(c, kind)
    local parent = c and c:GetParent()
    if not (kind and parent and parent.spec) then return end
    local state = containers[c]
    if not state then
        state = { kind = kind, frame = frameOf(c), plain = Auras.IsPlain(c), container = c,
            buttons = setmetatable({}, { __mode = "k" }), count = 0 }
        containers[c] = state
    end
    local on = get(state.frame, kind).enabled == true
    if state.plain then return on and state or nil end
    -- Live frames switch after a reload, as the client builds their buttons once.
    local live = (state.frame or "?") .. ":" .. kind
    if liveModes[live] == nil then liveModes[live] = on end
    if liveModes[live] and not state.failed then return state end
end

local function prepare(set)
    if not set then return end
    mode(set.buffs, "buff")
    mode(set.debuffs, "debuff")
end

-- How many bars share a row (1 to 3), on the frames that support it.
local function columnsOf(state)
    if not (state and STRETCHABLE[state.frame]) then return 1 end
    return clampNumber(get(state.frame, state.kind).columns, 1, 1, 3)
end

function extras.AuraBarColumns(c)
    local state = c and containers[c]
    if not (state and mode(c, state.kind)) then return 1 end
    return columnsOf(state)
end

-- How far a frame's bars reach past its left and right ends.
local function stretch(state)
    if not (state and STRETCHABLE[state.frame]) then return 0, 0 end
    local cfg = get(state.frame, state.kind)
    return clampNumber(cfg.extendLeft, 0, -150, 200), clampNumber(cfg.extendRight, 0, -150, 200)
end

function extras.AuraBarWidth(c)
    local state = c and containers[c]
    if state and mode(c, state.kind) then
        local left, right = stretch(state)
        return math.max(40, c:GetParent():GetWidth() + left + right)
    end
end

-- How far a bar row moves sideways so its extra length lands on the chosen
-- side (DaylightUI centers it on the frame). Read by AuraFit's placement.
function extras.AuraBarShift(c, grow)
    local state = c and containers[c]
    if not (state and mode(c, state.kind)) then return 0 end
    local left, right = stretch(state)
    -- Pinned to the frame's left end (grow right) or right end (grow left),
    -- else centered on the frame.
    if grow == "right" then return -left end
    if grow == "left" then return right end
    return (right - left) / 2
end

function extras.AuraBarSpot(c, spot)
    local state = containers[c]
    local growth = get(state.frame, state.kind).growth
    if growth == "down" then return "below", true end
    if growth == "up" then return "above", true end
    if spot == "above" or spot == "below" then return spot end
    return state.kind == "buff" and "below" or "above"
end

local function stackHeight(state, count)
    if count == 0 then return 0 end
    local rows = math.ceil(count / columnsOf(state))
    return rows * barHeight(state.frame, state.kind) + (rows - 1) * barSpacing(state.frame, state.kind)
end

-- The native stack measurement includes space for icon timers and uses icon spacing.
-- Bar stacks put one aura on each row and keep the timer inside the bar.
local auraHeight = Auras.Height
if auraHeight then
    function Auras.Height(set, kind)
        local c = set and set[kind .. "s"]
        if not extras.AuraBarWidth(c) then return auraHeight(set, kind) end
        local count = 0
        for _, groupCount in ipairs(set.counts and set.counts[kind] or {}) do count = count + groupCount end
        return stackHeight(containers[c], count)
    end
end

local function dispelColor(key)
    return Auras.DISPEL_COLORS[key] or Auras.DEBUFF_BORDER
end

local function setColor(parts, category, dispel)
    local bar = parts.bar
    parts.category = category
    if parts.kind == "debuff" then
        local color = dispelColor(dispel)
        bar:SetStatusBarColor(color[1], color[2], color[3], 1)
    elseif parts.elegant then
        bar:SetStatusBarColor(.96, .96, .96, 1)
    elseif category and buffs and buffs.DB and buffs.Categories and buffs.Categories.IsClass(category) and buffs.Widgets then
        local r, g, b = buffs.Widgets.CategoryColor(category)
        bar:SetStatusBarColor(r, g, b, 1)
    else
        bar:SetStatusBarColor(.37, .49, .56, 1)
    end
end

local function newMask(face)
    local mask = face:CreateMaskTexture()
    mask:SetTexture(WHITE, "CLAMP", "CLAMP")
    mask:SetAllPoints(face)
    return mask
end

local function solid(parent, layer, sublevel, color)
    local texture = parent:CreateTexture(nil, layer, nil, sublevel)
    texture:SetTexture(WHITE)
    texture:SetVertexColor(color[1], color[2], color[3], color[4])
    return texture
end

-- A bar drawn from Blasta's own pieces: a pixel-thin border, the icon on one
-- end, and the duration bar on the other. Both masks are this face's, so the
-- angled end stays exact at any width and height.
local function makeFace(owner, kind, frame)
    local face = CreateFrame("Frame", nil, owner)
    face:SetAllPoints(owner)
    local border = solid(face, "BACKGROUND", 0, BORDER_COLOR)
    border:SetAllPoints(face)
    local back = solid(face, "BACKGROUND", 1, BACK_COLOR)
    local bar = CreateFrame("StatusBar", nil, face)
    bar:SetStatusBarTexture(Style.BAR.fill)
    bar:SetMinMaxValues(0, 1)
    local fill = bar:GetStatusBarTexture()
    local icon = face:CreateTexture(nil, "ARTWORK")
    icon:SetTexCoord(.08, .92, .08, .92)
    if icon.SetSnapToPixelGrid then icon:SetSnapToPixelGrid(true) end
    local labels = CreateFrame("Frame", nil, face)
    labels:SetFrameLevel(bar:GetFrameLevel() + 1)
    local name = labels:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetWordWrap(false)
    name:SetMaxLines(1)
    name:SetJustifyH("LEFT")
    local time = labels:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    time:SetJustifyH("RIGHT")
    local count = face:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
    local outer, inner = newMask(face), newMask(face)
    border:AddMaskTexture(outer)
    back:AddMaskTexture(inner)
    fill:AddMaskTexture(inner)
    local parts = { face = face, border = border, back = back, bar = bar, fill = fill, icon = icon, name = name,
        time = time, count = count, kind = kind, frame = frame, outer = outer, inner = inner, labels = labels }
    setColor(parts)
    return parts
end

-- Places an angle mask over one end. inset is the distance from that end of
-- the face to the outer edge of the diagonal, span its width.
local function placeMask(mask, face, file, side, inset, y, span, height)
    local pad = span * MASK_MARGIN / (MASK_SIZE - 2 * MASK_MARGIN)
    mask:SetTexture(MASKS .. file, "CLAMP", "CLAMP")
    mask:ClearAllPoints()
    if side == "right" then
        mask:SetPoint("TOPRIGHT", face, "TOPRIGHT", pad - inset, y)
    else
        mask:SetPoint("TOPLEFT", face, "TOPLEFT", inset - pad, y)
    end
    mask:SetSize(span + 2 * pad, height)
end

local function openMask(mask, face)
    mask:SetTexture(WHITE, "CLAMP", "CLAMP")
    mask:ClearAllPoints()
    mask:SetAllPoints(face)
end


local function layout(parts, index, width, height)
    local cfg = get(parts.frame, parts.kind)
    local face = parts.face
    local W = tonumber(width) or parts.width or 0
    local H = tonumber(height) or barHeight(parts.frame, parts.kind)
    if W <= 0 or H <= 0 then return end
    local b = Pixel.Px(face, 1)
    local iconRight = cfg.icon == "right"
    -- The angle belongs to the end without the icon.
    local side = iconRight and "left" or "right"
    local elegant = cfg.style == "elegant"
    local lineHeight = elegant and b * clampNumber(cfg.lineThickness, defaults.lineThickness, 1, 4) or nil
    local angle = elegant and "straight" or angleOf(cfg)
    if angle ~= "straight" and cfg.alternate == true and index and index % 2 == 0 then
        angle = angle == "top" and "bottom" or "top"
    end
    local swap, reverse = cfg.swapText == true, cfg.reverse == true
    if parts.width == W and parts.height == H and parts.pixel == b and parts.angle == angle
        and parts.iconRight == iconRight and parts.swap == swap and parts.reverse == reverse
        and parts.elegant == elegant
        and parts.lineHeight == lineHeight and parts.names == (cfg.showNames ~= false) then return end
    parts.names = cfg.showNames ~= false
    parts.name:SetShown(parts.names)
    local styleChanged = parts.elegant ~= elegant
    parts.width, parts.height, parts.pixel, parts.angle = W, H, b, angle
    parts.iconRight, parts.swap, parts.reverse = iconRight, swap, reverse
    parts.elegant, parts.lineHeight = elegant, lineHeight
    if styleChanged then
        if parts.kind == "buff" then setColor(parts, parts.category) end
        local font, size, flags = GameFontHighlightSmall:GetFont()
        if font and size then
            local fontFlags = elegant and "OUTLINE" or (flags or "")
            parts.name:SetFont(font, size, fontFlags)
            parts.time:SetFont(font, elegant and size + 1 or size, fontFlags)
        end
    end
    parts.border:SetShown(not elegant)
    if elegant then
        parts.back:SetVertexColor(.85, .85, .85, .34)
    else
        parts.back:SetVertexColor(unpack(BACK_COLOR))
    end
    local cut = angle ~= "straight" and math.min(W / 4, math.floor(H / 3 + .5)) or 0
    local inner = b
    if cut > 0 then
        -- The inner diagonal runs parallel to the outer one, one pixel in.
        local slope = cut / H
        inner = b * slope + b * math.sqrt(1 + slope * slope)
        local file = side .. "-" .. angle .. ".png"
        placeMask(parts.outer, face, file, side, 0, 0, cut, H)
        placeMask(parts.inner, face, file, side, inner, -b, cut * (H - 2 * b) / H, H - 2 * b)
    else
        openMask(parts.outer, face)
        openMask(parts.inner, face)
    end
    -- Use the same whole physical-pixel width and height at any UI scale.
    local iconSize = b * math.max(1, math.floor(H / b - 2 + 0.0001))
    parts.icon:ClearAllPoints()
    parts.icon:SetSize(iconSize, iconSize)
    parts.icon:SetPoint(iconRight and "TOPRIGHT" or "TOPLEFT", face, iconRight and "TOPRIGHT" or "TOPLEFT",
        iconRight and -b or b, -b)
    local near = 2 * b + iconSize
    local left, right = iconRight and inner or near, iconRight and near or inner
    local labels = parts.labels
    labels:ClearAllPoints()
    labels:SetPoint("TOPLEFT", face, "TOPLEFT", left, -b)
    labels:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", -right, b)
    parts.bar:ClearAllPoints()
    if elegant then
        parts.bar:SetPoint("BOTTOMLEFT", labels, "BOTTOMLEFT")
        parts.bar:SetPoint("BOTTOMRIGHT", labels, "BOTTOMRIGHT")
        parts.bar:SetHeight(lineHeight)
    else
        parts.bar:SetAllPoints(labels)
    end
    parts.back:ClearAllPoints()
    parts.back:SetAllPoints(parts.bar)
    local pad = 4
    local angledPad = pad + cut * .6
    local leftPad, rightPad = iconRight and angledPad or pad, iconRight and pad or angledPad
    local textY = elegant and lineHeight * .5 or 0
    parts.time:ClearAllPoints()
    parts.name:ClearAllPoints()
    if swap then
        parts.time:SetJustifyH("LEFT")
        parts.time:SetPoint("LEFT", labels, "LEFT", leftPad, textY)
        parts.name:SetJustifyH("RIGHT")
        parts.name:SetPoint("RIGHT", labels, "RIGHT", -rightPad, textY)
        parts.name:SetPoint("LEFT", parts.time, "RIGHT", 5, 0)
    else
        parts.time:SetJustifyH("RIGHT")
        parts.time:SetPoint("RIGHT", labels, "RIGHT", -rightPad, textY)
        parts.name:SetJustifyH("LEFT")
        parts.name:SetPoint("LEFT", labels, "LEFT", leftPad, textY)
        parts.name:SetPoint("RIGHT", parts.time, "LEFT", -5, 0)
    end
    parts.bar:SetReverseFill(reverse)
end

local function plainValue(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

-- The client sorts its bars (by time left, for one) and moves buttons between
-- rows, so the alternating corner follows each bar's current row, read from
-- its position. Checked ten times a second, only while a frame alternates.
local rowWatch = CreateFrame("Frame")
rowWatch:Hide()
local alternating = setmetatable({}, { __mode = "k" })
local sinceRows = 0
local function watchRows(state)
    local cfg = get(state.frame, state.kind)
    alternating[state] = not state.plain and not state.failed and next(state.buttons)
        and cfg.style ~= "elegant" and cfg.alternate == true and angleOf(cfg) ~= "straight" or nil
    rowWatch:SetShown(next(alternating) ~= nil)
end
-- The client keeps its bars' visibility secret, so every bar is checked.
-- A position that can't be read leaves that bar's corner as it was.
rowWatch:SetScript("OnUpdate", function(_, elapsed)
    sinceRows = sinceRows + elapsed
    if sinceRows < .1 then return end
    sinceRows = 0
    for state in pairs(alternating) do
        local ok, top = pcall(state.container.GetTop, state.container)
        local step = (state.height or defaults.height) + (state.spacing or defaults.spacing)
        if ok and plainValue(top) and step > 0 then
            for button, parts in pairs(state.buttons) do
                local read, own = pcall(button.GetTop, button)
                if read and plainValue(own) then
                    local row = math.floor(math.abs(top - own) / step + .5)
                    if parts.row ~= row then
                        parts.row = row
                        layout(parts, row + 1, state.width, state.height)
                    end
                end
            end
        end
    end
    if not next(alternating) then rowWatch:Hide() end
end)

local function refresh(state, resize)
    local height = barHeight(state.frame, state.kind)
    local retry
    for button, parts in pairs(state.buttons) do
        if not resize or pcall(button.SetSize, button, state.width, height) then
            layout(parts, (parts.row or (parts.index - 1)) + 1, state.width, height)
        else
            retry = true
        end
    end
    return retry
end

-- Puts the bar size and spacing on every aura group the container has.
local lists = ns.AuraLists

-- Boosted Rest (the hour after a Camp Tent) sits on you as a debuff, and on
-- your own debuffs the game won't match a hide list by spell id. It does
-- filter by time left, so while a row's hide list holds Boosted Rest, that row
-- leaves out debuffs with more than two minutes left (and ones that never run
-- out). Taking Boosted Rest off the list turns this off. A row's own
-- longest-debuff setting wins when it's set.
local BOOSTED_REST, LONG_DEBUFF_CUTOFF = 1229451, 120
local SELF_DEBUFFS = { selfdebuff = true, gdebuff = true }
if lists and lists.Filters and lists.Ids and lists.ModeOf then
    local filters = lists.Filters
    function lists.Filters(c, g, ...)
        local cand = filters(c, g, ...)
        local picks = c and c.dluiPicks
        if c and SELF_DEBUFFS[c.dluiKind] and type(picks) == "table" and lists.ModeOf(picks.hide) == "hide" then
            local ids = lists.Ids(picks.hide)
            if ids and ids[BOOSTED_REST] and not (cand and cand.maxDuration) then
                cand = cand or {}
                cand.maxDuration = LONG_DEBUFF_CUTOFF
            end
        end
        return cand
    end
end

local function layoutGroups(c, state)
    local kind = Auras.KINDS[c.dluiKind]
    for _, group in ipairs(kind and kind.groups or {}) do
        if c.dluiGroups and c.dluiGroups[group.key] then
            pcall(c.SetAuraGroupLayout, c, group.key, {
                layoutIndex = group.index, elementWidth = state.width, elementHeight = state.height,
                elementSpacing = state.gap or 2, lineSpacing = state.spacing,
            })
        end
    end
    -- Put DaylightUI's aura lists (hide list, show-only list, boss, duration)
    -- back on every group, so the bars filter exactly like the icons.
    if lists and lists.Push then lists.Push(c) end
end

local size = Auras.SetOwnSize
function Auras.SetOwnSize(c, width, gap)
    if c and creating and not containers[c] and c:GetParent() == creating then mode(c, buffKinds[c.dluiKind]) end
    local state = containers[c]
    local rowWidth = extras.AuraBarWidth(c)
    if not rowWidth then return size(c, width, gap) end
    -- Side by side: the row's width is shared, with the bar spacing between.
    local cols = columnsOf(state)
    if cols > 1 then gap = math.max(2, barSpacing(state.frame, state.kind)) end
    local barWidth = math.max(20, math.floor((rowWidth - (cols - 1) * gap) / cols))
    local dimensions = size(c, barWidth, gap)
    local height, spacing = barHeight(state.frame, state.kind), barSpacing(state.frame, state.kind)
    local changed = dimensions[2] ~= height or state.gap ~= gap or state.height ~= height
        or state.spacing ~= spacing or state.width ~= barWidth
    dimensions[2] = height
    state.width, state.gap, state.manualWidth = barWidth, gap, width
    state.height, state.spacing = height, spacing
    if changed and not state.plain then layoutGroups(c, state) end
    if not state.plain then
        watchRows(state)
        state.resize = state.resize or changed
        DUI.AfterRestrictions(function()
            state.resize = refresh(state, state.resize)
        end, "blasta:aura-bar:" .. tostring(c))
    end
    return dimensions
end


-- A filter switch (all, purge, mine) can add a group later. It starts with
-- the native icon layout, so the bar size and spacing go on it right away.
if type(Auras.AddGroup) == "function" then
    hooksecurefunc(Auras, "AddGroup", function(c)
        local state = c and containers[c]
        if state and not state.plain and state.width and state.height and mode(c, state.kind) then
            layoutGroups(c, state)
        end
    end)
end

local create = Auras.Create
function Auras.Create(frame, ...)
    if not frame.spec then return create(frame, ...) end
    local previous = creating
    creating = frame
    local ok, set = pcall(create, frame, ...)
    creating = previous
    if not ok then error(set, 0) end
    prepare(set)
    return set
end

local function refreshLook(state, button, parts)
    local formatter
    if state.timers == false then
        formatter = Style.DurationFormatter(0)
    elseif Auras.TimeFormatter then
        formatter = Auras.TimeFormatter(state.shortTimers)
    end
    pcall(Style.SetAuraTime, button, parts.time, nil, formatter)
    pcall(parts.count.SetAlpha, parts.count, state.counts == false and 0 or 1)
    local tips = state.tips ~= false
    pcall(button.EnableMouse, button, tips)
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
    if button.SetMouseMotionEnabled then pcall(button.SetMouseMotionEnabled, button, tips) end
end

for method, field in pairs({ SetTimers = "timers", SetShortTimers = "shortTimers", SetCounts = "counts", SetTips = "tips" }) do
    if Auras[method] then
        hooksecurefunc(Auras, method, function(c, value)
            local state = containers[c]
            if not (state and mode(c, state.kind)) or state[field] == value then return end
            state[field] = value
            if not state.plain and next(state.buttons) then
                DUI.AfterRestrictions(function()
                    for button, parts in pairs(state.buttons) do refreshLook(state, button, parts) end
                end, "blasta:aura-look:" .. tostring(c))
            end
        end)
    end
end

local apply = Auras.Apply
function Auras.Apply(set, cfg)
    prepare(set)
    return apply(set, cfg)
end

local place = Groups.Place
local AURA_SETS = { "buffs", "debuffs" }
local function timerPadding(group, key)
    if group.timers ~= true then return 0 end
    local kind = key == "buffs" and "tilebuff" or "gdebuff"
    return (tonumber(group.timeSize) or Auras.TIME_SIZE[kind]) * .6
end

function Groups.Place(set, frame, all, box)
    prepare(set)
    if not set or type(all) ~= "table" then return place(set, frame, all, box) end
    local updated
    local sides, bars, chosen = {}, {}, {}
    for _, key in ipairs(AURA_SETS) do
        local group = all[key]
        if type(group) == "table" and group.show == true then
            bars[key] = extras.AuraBarWidth(set[key]) ~= nil
            sides[key] = group.spot
            if bars[key] then sides[key], chosen[key] = extras.AuraBarSpot(set[key], sides[key]) end
        end
    end
    local offsetKey, offset
    if sides.buffs and sides.buffs == sides.debuffs and (bars.buffs or bars.debuffs) then
        if chosen.buffs or chosen.debuffs then
            -- Group frames use independent anchors. Reserve the inner row's
            -- configured maximum so the outer row stays clear as auras change.
            offsetKey = bars.debuffs and "debuffs" or "buffs"
            local innerKey = offsetKey == "debuffs" and "buffs" or "debuffs"
            local inner = all[innerKey]
            local count = math.max(1, math.floor(tonumber(inner.max) or 1))
            if bars[innerKey] then
                offset = stackHeight(containers[set[innerKey]], count)
            else
                local rows = math.min(count, math.max(1, math.floor(tonumber(inner.rows) or 1)))
                offset = rows * (tonumber(inner.size) or 14) + (rows - 1) * ((tonumber(inner.spacing) or 2) + 4)
            end
            offset = offset + Auras.GAP
            if sides[offsetKey] == "below" then
                offset = -offset - timerPadding(inner, innerKey) + timerPadding(all[offsetKey], offsetKey)
            elseif not bars[innerKey] then
                offset = offset + timerPadding(inner, innerKey)
            end
            offset = (tonumber(inner.y) or 0) + offset
        else
            local split = bars.buffs and "buffs" or "debuffs"
            sides[split] = sides[split] == "above" and "below" or "above"
        end
    end
    for _, key in ipairs(AURA_SETS) do
        if bars[key] then
            if not updated then
                updated = {}
                for slot, value in pairs(all) do updated[slot] = value end
            end
            local group = {}
            for field, value in pairs(all[key]) do group[field] = value end
            group.rows, group.grow, group.x, group.blastaFit = group.max, "center", 0, false
            group.spot = sides[key]
            if key == offsetKey then group.y = (tonumber(group.y) or 0) + offset end
            updated[key] = group
        end
    end
    return place(set, frame, updated or all, box)
end

local function readable(value)
    if not issecretvalue or not issecretvalue(value) then return value end
end

local observing
local function watchBuffColors()
    local util = AuraContainerUtil
    if observing or not (util and util.SetIconTextureForAura) then return end
    observing = true
    hooksecurefunc(util, "SetIconTextureForAura", function(button, _, aura)
        local parts = liveButtons[readable(button)]
        if not parts or parts.kind ~= "buff" then return end
        local category
        if buffs and buffs.DB and type(aura) == "table" and readable(aura)
            and (not issecrettable or not issecrettable(aura)) and (not canaccesstable or canaccesstable(aura)) then
            local spell, name = readable(aura.spellId), readable(aura.name)
            category = spell and buffs.Spells and buffs.Spells.Sets().category[spell]
            if not category and name and buffs.Classify then category = buffs.Classify.Resolve({ name = name }) end
        end
        if parts.category ~= category then pcall(setColor, parts, category) end
    end)
end

-- The client loads its aura container code on its own schedule, so the buff
-- color hook is tried again once the world is up.
do
    local retry = CreateFrame("Frame")
    retry:RegisterEvent("PLAYER_ENTERING_WORLD")
    retry:RegisterEvent("ADDON_LOADED")
    retry:SetScript("OnEvent", function()
        if next(liveButtons) then pcall(watchBuffColors) end
    end)
end

local init = Auras.InitButton
local function useIcons(state, button, kind, c, cure)
    state.failed = true
    watchRows(state)
    size(c, state.manualWidth or 18, state.gap or 2)
    return init(button, kind, c, cure)
end

function Auras.InitButton(button, kind, c, cure)
    local known = containers[c]
    if not known and creating and c and c:GetParent() == creating then
        mode(c, buffKinds[kind])
        known = containers[c]
    end
    local state = known and mode(c, known.kind)
    if not state then return init(button, kind, c, cure) end
    if not (button.SetDurationBar and button.SetSpellName) then return useIcons(state, button, kind, c, cure) end
    local width = state.width or extras.AuraBarWidth(c)
    local height = barHeight(state.frame, state.kind)
    button:SetSize(width, height)
    local parts = makeFace(button, state.kind, state.frame)
    local direction = Enum and Enum.StatusBarTimerDirection
    local interpolation = Enum and Enum.StatusBarInterpolation
    -- The client rebinds a button's timer whenever the container re-sorts or
    -- refreshes (entering or leaving combat, looting, any aura change). With
    -- the default easing the bar then glides up from empty each time, which
    -- read as a replayed entrance animation. Snap like DaylightUI's cast bar.
    local function barOptions(snap)
        local options = { direction = direction and direction.RemainingTime }
        if snap and interpolation then options.interpolation = interpolation.Immediate end
        local process = C_AuraContainerUtil and C_AuraContainerUtil.ProcessCustomAuraButtonDurationBarOptions
        local ok, prepared = pcall(process, options)
        if ok and type(prepared) == "table" then
            if snap and interpolation then prepared.interpolation = interpolation.Immediate end
            options = prepared
        end
        return options
    end
    local bound = pcall(button.SetDurationBar, button, parts.bar, barOptions(true))
        or pcall(button.SetDurationBar, button, parts.bar, barOptions(false))
    if not bound then
        parts.face:Hide()
        return useIcons(state, button, kind, c, cure)
    end
    pcall(button.SetIcon, button, parts.icon)
    pcall(button.SetSpellName, button, parts.name)
    pcall(button.SetApplicationCount, button, parts.count)
    pcall(button.SetTooltipAnchorPoint, button, Auras.TOOLTIP_ANCHOR)
    refreshLook(state, button, parts)
    if state.kind == "debuff" then
        pcall(Style.DispelEdge, button, parts.fill, dispelColor, { asset = Style.BAR.fill })
    else
        watchBuffColors()
    end
    state.count = state.count + 1
    parts.index = state.count
    state.width = width
    state.buttons[button], liveButtons[button] = parts, parts
    parts.state, parts.button = state, button
    layout(parts, parts.index, width, height)
    watchRows(state)
end

local listFiltered
local previewPools = setmetatable({}, { __mode = "k" })
local previewSpells = {
    spell_holy_wordfortitude = { 1243, "priest" }, spell_holy_renew = { 139, "priest" },
    spell_holy_powerwordshield = { 17, "priest" }, spell_holy_magicalsentry = { 1459, "mage" },
    spell_nature_regeneration = { 1126, "druid" }, spell_nature_resistnature = { 1126, "druid" },
    spell_nature_rejuvenation = { 774, "druid" }, ability_warrior_battleshout = { 6673, "warrior" },
    spell_shadow_shadowwordpain = { 589 }, spell_shadow_curseofsargeras = { 980 },
    ability_gouge = { 1776 }, spell_nature_corrosivebreath = { 2818 },
}

local function sampleBars(holder, list, count, state, anchor, up)
    local pool = previewPools[holder] or {}
    previewPools[holder] = pool
    local width, height = state.width or holder:GetWidth(), barHeight(state.frame, state.kind)
    local gap = barSpacing(state.frame, state.kind)
    local cols = columnsOf(state)
    local colGap = cols > 1 and math.max(2, gap) or 0
    count = #list == 0 and 0 or count
    for i = 1, count do
        local parts = pool[i]
        if not parts then
            local button = CreateFrame("Frame", nil, holder)
            button:Hide()
            parts = makeFace(button, state.kind, state.frame)
            parts.button = button
            pool[i] = parts
        end
        local button, sample = parts.button, list[(i - 1) % #list + 1]
        button:SetSize(width, height)
        button:ClearAllPoints()
        local col, line = (i - 1) % cols, math.floor((i - 1) / cols)
        local dx = (anchor:find("RIGHT") and -1 or 1) * col * (width + colGap)
        button:SetPoint(anchor, holder, anchor, dx, (up and 1 or -1) * line * (height + gap))
        layout(parts, i, width, height)
        parts.icon:SetTexture(sample.icon)
        local file = type(sample.icon) == "string" and sample.icon:match("[^\\]+$")
        local spell = file and previewSpells[file:lower()]
        local name = spell and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spell[1])
        parts.name:SetText(name or extras.Translate(state.kind == "buff" and "Buff" or "Debuff"))
        parts.time:SetText(state.timers ~= false and not (state.shortTimers and sample.long) and (sample.time or "") or "")
        parts.count:SetText(state.counts ~= false and (sample.count or "") or "")
        parts.bar:SetValue(sample.left or .65)
        setColor(parts, spell and spell[2], sample.dispel)
        button:SetAlpha(1)
        button:Show()


    end
    for i = count + 1, #pool do pool[i].button:Hide() end
    local rows = math.ceil(count / cols)
    local shown = math.min(count, cols)
    return math.max(width, shown * width + (shown - 1) * colGap), math.max(1, rows * height + (rows - 1) * gap)
end

local function hideBars(holder)
    for _, parts in ipairs(previewPools[holder] or {}) do parts.button:Hide() end
end

-- The preview follows the row's aura lists too: a sample whose spell is on
-- the hide list (or missing from a show-only list) is left out.
local function sampleSpell(sample)
    local file = type(sample.icon) == "string" and sample.icon:match("[^\\]+$")
    local spell = file and previewSpells[file:lower()]
    return spell and spell[1]
end

function listFiltered(list, cfg, kind)
    if not (lists and lists.ModeOf and lists.Ids and type(cfg) == "table") then return list end
    local hideId, onlyId = cfg[kind .. "Hide"], cfg[kind .. "Only"]
    local hide = lists.ModeOf(hideId) == "hide" and lists.Ids(hideId) or nil
    local only = lists.ModeOf(onlyId) == "only" and lists.Ids(onlyId) or nil
    if not (hide or only) then return list end
    local out = {}
    for _, sample in ipairs(list) do
        local spell = sampleSpell(sample)
        if not (spell and hide and hide[spell]) and not (only and not (spell and only[spell])) then
            out[#out + 1] = sample
        end
    end
    return out
end

local drawSample = Auras.DrawSample
function Auras.DrawSample(c, list, count, kind, flow)
    local state = containers[c]
    if not (state and extras.AuraBarWidth(c)) then
        hideBars(c)
        return drawSample(c, list, count, kind, flow)
    end
    for _, button in ipairs(c.pool or {}) do button:Hide() end
    if count > 0 and extras.AuraBarPreviewCount then count = extras.AuraBarPreviewCount(c) or count end
    local w, h = sampleBars(c, list, count, state, flow.anchor, flow.vDir == "Up")
    c:SetSize(w, h)
    c:SetShown(count > 0)
    return w, h
end

local showSample = Auras.ShowSample
function Auras.ShowSample(set, frame, cfg, samples)
    if not set then return showSample(set, frame, cfg, samples) end
    local visible = { buffs = samples.buffs, debuffs = samples.debuffs }
    for _, key in ipairs({ "buffs", "debuffs" }) do
        if extras.AuraBarWidth(set[key]) then visible[key] = {} end
    end
    showSample(set, frame, cfg, visible)
    set.sample = { cfg = cfg, list = samples }
    for _, key in ipairs({ "buffs", "debuffs" }) do
        local c = set[key]
        local holder = c and Auras.HolderFor(c)
        if holder and extras.AuraBarWidth(c) then
            local state = containers[c]
            local flow = set.flow and set.flow[state.kind]
            local count = 0
            for _, n in ipairs(set.counts and set.counts[state.kind] or {}) do count = count + n end
            local list = samples[key]
            local filter = state.kind == "buff" and cfg.buffFilter == "purge" and "purge"
                or state.kind == "debuff" and set.side == "right" and cfg.debuffFilter == "dispel" and "cure"
            if filter then
                list = {}
                for _, sample in ipairs(samples[key]) do if sample[filter] then list[#list + 1] = sample end end
            end
            list = listFiltered(list, cfg, state.kind)
            if flow then sampleBars(holder, list, count, state, flow.flowAnchor, flow.vDir == "Up") end
        elseif holder then
            hideBars(holder)
        end
    end
end

function extras.AppendAuraBarPreviewParts(parts, preview, source)
    local set = preview.f and preview.f.sampleAuras
    if not set then return end
    local frame = preview.f
    local cfg = mod.db and ns.ConfigFor(mod.db, frame.spec)
    local def = ns.PageSample and ns.PageSample.AURA_SETS[source.id]
    if not def then return end
    for _, kind in ipairs({ "buff", "debuff" }) do
        local c = set[kind .. "s"]
        local holder = c and Auras.HolderFor(c)
        for _, entry in ipairs(holder and previewPools[holder] or {}) do
            if entry.button:IsVisible() then
                local prefix = def.key .. "." .. kind
                local move
                if cfg and extras.HasSetting(mod, prefix .. "Spot") then
                    local dots = ns.Spots.Dots(Groups.Box(frame, cfg))
                    move = { owner = frame, dots = dots, spotKey = prefix .. "Spot",
                        xKey = prefix .. "X", yKey = prefix .. "Y",
                        drop = function(x, y) return ns.Spots.Drop(dots, x, y) end }
                end
                -- A stack moves as one piece, including when it has several bars.
                parts[#parts + 1] = {
                    label = kind == "buff" and "Buffs" or "Debuffs", region = holder,
                    keys = { prefix .. "Size", prefix .. "Spot", prefix .. "X", prefix .. "Y" },
                    scale = frame:GetScale(), move = move,
                }
                break
            end
        end
    end
end

extras.Loaded("AuraBars")
