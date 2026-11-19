local ADDON, extras = ...
local DUI = DaylightUI
local API = DUI and DUI.API
local me = API and API.major == 1 and (API.minor or 0) >= 3 and API.For and API.For(ADDON)
local mod = DUI:GetModule("UnitFrames")
local ns = extras.Compatible("UnitFrames")
local UF, power = ns and ns.UF, ns and ns.PowerBar
local edges, pixel, style = extras.Edges, DUI.Pixel, DUI.Style
local anchor = "party.showPower"
if not (me and UF and UF.FrameStyle and UF.StyleOf and UF.StyleDef and UF.StyleReach and UF.LayoutPowerExtras and UF.SLANT and ns.STYLES
    and power and power.LayoutLine and edges and pixel and extras.FindSetting(mod, anchor)) then return end

local enabledKey = "party.blastaPowerLine"
local cfgDefaults = mod.defaults.party
cfgDefaults.blastaPowerLine = false
cfgDefaults.blastaPowerWidth = 50
cfgDefaults.blastaPowerGap = 0
cfgDefaults.blastaPowerX = 0
cfgDefaults.blastaPowerHeight = 0
cfgDefaults.blastaPowerBorder = 1
cfgDefaults.blastaPowerLeft = "bottom"
cfgDefaults.blastaPowerRight = "top"

local destination = { page = "UnitFrames", tab = "Party", label = "Party resource bar" }
local function add(row)
    row.blastaDestination = destination
    extras.AddSetting(mod, anchor, row)
    anchor = row.key
end
local function disabled(get)
    return get(enabledKey) ~= true or get("party.showPower") == false
end

add({ type = "toggle", key = enabledKey, label = "Compact party resource bar",
    desc = "Give each party member a resource bar that can sit below or overlap the health bar. While it's on, its own height and offsets below set the bar, in place of DaylightUI's party power height and gap.",
    blastaRequires = "party.showPower" })
add({ type = "slider", key = "party.blastaPowerWidth", label = "Resource bar width", min = 0.2,
    max = 1, step = 0.01, unit = "%", disabled = disabled, onRelease = true,
    get = function() return (DUI:Get(mod.name, "party.blastaPowerWidth") or 50) / 100 end,
    set = function(value) return DUI:Set(mod.name, "party.blastaPowerWidth", math.floor(value * 100 + 0.5)) end,
    default = function() return cfgDefaults.blastaPowerWidth / 100 end })
add({ type = "slider", key = "party.blastaPowerHeight", label = "Bar height", min = 2,
    max = 24, step = 1, unit = "px", disabled = disabled,
    get = function()
        local height = tonumber(DUI:Get(mod.name, "party.blastaPowerHeight")) or 0
        return height > 0 and height or (DUI:Get(mod.name, "party.powerHeight") or 7)
    end,
    set = function(value)
        return DUI:Set(mod.name, "party.blastaPowerHeight", value == DUI:Get(mod.name, "party.powerHeight") and 0 or value)
    end,
    default = function() return DUI:Get(mod.name, "party.powerHeight") or 7 end })
add({ type = "slider", key = "party.blastaPowerBorder", label = "Border size", min = 1,
    max = 6, step = 1, unit = "px", disabled = disabled })
add({ type = "slider", key = "party.blastaPowerX", label = "Horizontal offset", min = -120,
    max = 120, step = 1, unit = "px", disabled = disabled })
-- Keep legacy saved gaps (positive means down) while showing positive Y as up.
add({ type = "slider", key = "party.blastaPowerGap", label = "Vertical offset", min = -40,
    max = 40, step = 1, unit = "px", disabled = disabled,
    get = function() return -(DUI:Get(mod.name, "party.blastaPowerGap") or 0) end,
    set = function(value) return DUI:Set(mod.name, "party.blastaPowerGap", -value) end,
    default = function() return 0 end })
add(edges.Options(mod, "party.blastaPowerLeft", "Left edge direction", function() return "bottom" end, disabled))
add(edges.Options(mod, "party.blastaPowerRight", "Right edge direction", function() return "top" end, disabled))

-- Keep the selected frame style's portrait and name layout. Only switch its
-- native power pieces to the line below the frame.
local variants = {}
local function compactStyle(key)
    local base = ns.STYLES[key]
    if not base or base.line then return key end
    if not variants[key] then
        local name = "DaylightBlasta:partyPower:" .. key
        ns.STYLES[name] = setmetatable({ line = true }, { __index = base })
        variants[key] = name
    end
    return variants[key]
end

-- DaylightUI's functions are changed through the plugin API (me.Wrap): other
-- plugins can wrap them too, and an error in Blasta's part falls back to
-- DaylightUI's own result instead of breaking the party frames.
me.Wrap(UF, "FrameStyle", function(original, frame, cfg)
    local key = original(frame, cfg)
    if cfg and cfg.blastaPowerLine and frame.spec and frame.spec.group == "party" then return compactStyle(key) end
    return key
end)

me.Wrap(UF, "StyleDef", function(original, cfg)
    if cfg and cfg.blastaPowerLine then return ns.STYLES[compactStyle(UF.StyleOf(cfg))] end
    return original(cfg)
end)

-- How far the compact bar really reaches below the frame (0 when it overlaps
-- the health bar). frame.foot keeps DaylightUI's full reservation for the
-- layout, but the dispel glow should wrap the bar where it actually sits.
local compactFoot = setmetatable({}, { __mode = "k" })

local parts = ns.GroupParts
if parts and parts.LayoutTargetMark and parts.Reach then
    local healthOutline
    me.Wrap(parts, "Reach", function(original, frame)
        if frame == healthOutline then return 0, 0 end
        local up, down = original(frame)
        local foot = compactFoot[frame]
        if foot then down = foot end
        return up, down
    end)

    me.Wrap(parts, "LayoutTargetMark", function(original, frame, cfg)
        if not (cfg.blastaPowerLine == true and frame.spec.group == "party") then
            return original(frame, cfg)
        end
        -- The health bar takes up the base frame. Exclude the name row and
        -- resource line from this outline, as Blasta's dispel contour does.
        local previous = healthOutline
        healthOutline = frame
        local ok, err = pcall(original, frame, cfg)
        healthOutline = previous
        if not ok then error(err, 0) end
    end)
end

local castLift = setmetatable({}, { __mode = "k" })
local cast = ns.CastBar
if cast and cast.Lift then
    me.Wrap(cast, "Lift", function(original, frame, border)
        local lift = castLift[frame]
        if lift and frame.powerLine and frame.line and frame.line:IsShown() then return math.min(border, lift) end
        return original(frame, border)
    end)
end

me.Wrap(power, "LayoutLine", function(layoutLine, frame, cfg, text, side, cut, show)
    local line = frame.line
    castLift[frame] = nil
    compactFoot[frame] = nil
    if not line or frame.spec.group ~= "party" then return layoutLine(frame, cfg, text, side, cut, show) end
    edges.Clear(line)
    local shell = style.GetShell(line)
    local compact = cfg.blastaPowerLine == true
    -- UF.ApplyShell sets the line's border earlier in every layout pass (and
    -- honors a frame's own shell border). Only replace it for the compact bar.
    if shell and compact then
        shell.opts.borderPx = tonumber(cfg.blastaPowerBorder) or 1
    end
    local settings = cfg
    local customHeight = tonumber(cfg.blastaPowerHeight) or 0
    if compact and customHeight > 0 then
        settings = setmetatable({ powerHeight = customHeight }, { __index = cfg })
    end
    layoutLine(frame, settings, text, side, cut, show)
    if not (compact and show) then return end

    -- Reserve the same space as the native line in the party layout and sample.
    -- The resource offset affects only its own anchor and the attached cast bar.
    local _, reserved = UF.StyleReach(cfg, frame)
    frame.foot = reserved
    local width = math.max(20, math.min(100, tonumber(cfg.blastaPowerWidth) or 50))
    local x = pixel.Snap(frame, tonumber(cfg.blastaPowerX) or 0)
    local y = -pixel.Snap(frame, tonumber(cfg.blastaPowerGap) or 0)
    line:ClearAllPoints()
    line:SetPoint("TOP", frame, "BOTTOM", x, y)
    line:SetWidth(2 * pixel.Snap(frame, frame:GetWidth() * width / 200))
    line:SetFrameLevel(frame.health:GetFrameLevel() + 3)
    if shell then style.LayoutShell(shell) end

    local left, right = edges.Read(cfg, "blastaPowerLeft", "blastaPowerRight", "bottom", "top")
    local height = line:GetHeight()
    local edgeCut = math.min(line:GetWidth() / 4, pixel.Snap(line, height * UF.SLANT))
    edges.Apply(line, left, right, edgeCut)
    local fill = line.set.power
    local endSide = frame.growLeft and "left" or "right"
    -- The fill sits one border inside the line. Computed rather than read, since
    -- its anchors were just set and may not be resolved yet.
    local border = pixel.Px(line, style.BorderPx(line))
    local fillHeight = math.max(0, height - 2 * border)
    edges.Fill(fill, endSide, height > 0 and edgeCut * fillHeight / height or 0, frame.growLeft and left or right)
    UF.LayoutPowerExtras(frame, settings, text, nil, 0, height, true, edgeCut + 4)
    castLift[frame] = y - height + border
    compactFoot[frame] = math.max(0, height - y)
end)

-- With the compact bar on, DaylightUI's own party power line height and the
-- gap above it do nothing (the compact bar has its own height and offsets).
-- DaylightUI's rows stay as they are; Blasta's card says so.

-- Design mode: in DaylightUI's party preview the compact bar drags like a
-- native piece; dropping it sets its horizontal and vertical offsets.
function extras.AddPartyPowerMove(preview, parts)
    if DUI:Get(mod.name, enabledKey) ~= true or DUI:Get(mod.name, "party.showPower") == false then return end
    for _, part in ipairs(parts) do
        local frame = part.label == "Power bar" and part.region and part.region:GetParent()
        while frame and not frame.line do frame = frame:GetParent() end
        local region = part.region
        if frame and region and region:IsVisible() and frame:GetLeft() then
            local scale = region:GetEffectiveScale() / frame:GetEffectiveScale()
            local cx, cy = region:GetCenter()
            if cx and cy then
                local x0, y0 = cx * scale - frame:GetLeft(), frame:GetTop() - cy * scale
                local px0 = tonumber(DUI:Get(mod.name, "party.blastaPowerX")) or 0
                local gap0 = tonumber(DUI:Get(mod.name, "party.blastaPowerGap")) or 0
                local function clamp(v, lo, hi) return math.max(lo, math.min(hi, math.floor(v + 0.5))) end
                part.keys = part.keys or {}
                part.keys[#part.keys + 1] = "party.blastaPowerX"
                part.keys[#part.keys + 1] = "party.blastaPowerGap"
                part.move = { owner = frame, dots = {}, xKey = "party.blastaPowerX", yKey = "party.blastaPowerGap",
                    drop = function(x, y)
                        return nil, clamp(px0 + (x - x0), -120, 120), clamp(gap0 + (y - y0), -40, 40)
                    end }
            end
        end
    end
end

extras.Loaded("PartyPowerBar")
