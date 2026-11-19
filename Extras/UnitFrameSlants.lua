local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("UnitFrames")
local UF = ns and ns.UF
if not (UF and UF.Layout and UF.LayoutPrediction) then return end

local Style = DUI.Style
local mod = DUI:GetModule("UnitFrames")
for _, unit in ipairs({ "player", "target", "targettarget", "focus", "pet", "party", "partyPet", "raid", "arena" }) do
    local cfg = mod.defaults[unit]
    local anchor = unit .. ".slant"
    if cfg and extras.FindSetting(mod, anchor) then
        cfg.reverseSlant = false
        extras.AddSetting(mod, anchor, { type = "toggle", key = unit .. ".reverseSlant", label = "Reverse unit frame slant",
            blastaRequires = unit ~= "raid" and anchor or nil,
            disabled = function(get) return unit ~= "raid" and get(anchor) == false end })
    end
end

local reversed = setmetatable({}, { __mode = "k" })
local flat = setmetatable({}, { __mode = "k" })
local function mark(frame, value)
    if frame then reversed[frame] = value end
end

local layout = UF.Layout
function UF.Layout(frame, cfg, ...)
    local settings = cfg
    if frame.spec and frame.spec.group == "raid" and mod.db then settings = mod.db.raid or cfg end
    local enabled = settings.reverseSlant == true and true or nil
    mark(frame, enabled)
    mark(frame.tab, enabled)
    mark(frame.freePower, enabled)
    mark(frame.health, enabled)
    mark(frame.heals, enabled)
    mark(frame.absorbs, enabled)
    mark(frame.power, enabled)
    mark(frame.altMana, enabled)
    local inside = frame.insidePower
    if inside then
        mark(inside.power, enabled)
        mark(inside.altMana, enabled)
    end
    local free = frame.freePower and frame.freePower.set
    if free then
        mark(free.power, enabled)
        mark(free.altMana, enabled)
    end
    return layout(frame, cfg, ...)
end

local slant = Style.Slant
function Style.Slant(frame, side, cut, ref, under)
    flat[frame] = nil
    if side and cut and cut > 0 then
        if ref and reversed[ref.frame] then
            -- A reversed edge reaches the full frame width at the join.
            -- Attached bars can continue from there without protruding.
            flat[frame] = true
            return slant(frame, nil, 0)
        elseif not ref and reversed[frame] then
            -- "both" leans both ends under: the trapezoid turned upside down.
            return slant(frame, side, cut, nil, side)
        end
    end
    return slant(frame, side, cut, ref, under)
end

local angleFill = Style.AngleFill
function Style.AngleFill(bar, side, cut, under)
    if side and cut and cut > 0 then
        if flat[bar:GetParent()] then return angleFill(bar, nil, 0) end
        if reversed[bar] then return angleFill(bar, side, cut, true) end
    end
    return angleFill(bar, side, cut, under)
end

hooksecurefunc(UF, "LayoutPrediction", function(frame, side)
    if not (reversed[frame] and side and not frame.flipped and frame.health:GetOrientation() == "HORIZONTAL") then return end
    local file = DUI.MEDIA .. (frame.growLeft and "mask-slant-r.png" or "mask-slant-l.png")
    for _, bar in ipairs({ frame.heals, frame.absorbs }) do
        if bar.wedge then bar.wedge.mask:SetTexture(file, "CLAMP", "CLAMP") end
    end
end)
