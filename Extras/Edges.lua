local _, extras = ...
local DUI = DaylightUI
local Style = DUI.Style
local Edges = {}
extras.Edges = Edges

local choices = { straight = "Straight", top = "Top corner projects", bottom = "Bottom corner projects" }
local order = { "straight", "top", "bottom" }
local shapes = setmetatable({}, { __mode = "k" })

function Edges.Options(mod, key, label, fallback, disabled)
    return { type = "dropdown", key = key, label = label, values = choices, order = order, disabled = disabled,
        get = function()
            local value = DUI:Get(mod.name, key)
            return choices[value] and value or fallback()
        end,
        set = function(value) return DUI:Set(mod.name, key, value) end,
        default = function() return fallback(true) end }
end

function Edges.Read(cfg, leftKey, rightKey, left, right)
    local l, r = cfg[leftKey], cfg[rightKey]
    return choices[l] and l or left, choices[r] and r or right, choices[l] ~= nil or choices[r] ~= nil
end

local function reversedTexture(side, stop, sharp)
    return DUI.MEDIA .. (stop and "mask-slant-" or "mask-trail-")
        .. (side == "left" and "r" or "l") .. (sharp and "-sharp.png" or ".png")
end

local function flipClip(clip, side, sharp)
    local keep = clip.masked and clip.masked[side]
    local stop = clip.stopped and clip.stopped[side]
    if keep then keep:SetTexture(reversedTexture(side, false, sharp), "CLAMP", "CLAMP") end
    if stop then stop:SetTexture(reversedTexture(side, true, sharp), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE") end
end

-- The native shell knows one reversed end. Its mask positions already fit
-- either orientation, including a shared reference. Swap the remaining
-- masks after the native layout, without allocating additional masks.
hooksecurefunc(Style, "LayoutSlant", function(frame)
    local s = shapes[frame]
    if not (s and (s.flipLeft or s.flipRight)) then return end
    local slant = Style.GetSlant(frame)
    if not slant or not slant.side then return end
    local sharp = slant.ref ~= nil or 4 * slant.cut > 48
    for _, clip in ipairs(slant.clips) do
        if s.flipLeft then flipClip(clip, "left", sharp) end
        if s.flipRight then flipClip(clip, "right", sharp) end
    end
    local shell = Style.GetShell(frame)
    if shell and shell.shadow then
        local shadow = shell.shadow
        if s.flipLeft then shadow.LEFT:Hide(); shadow.TOPLEFT:Hide(); shadow.BOTTOMLEFT:Hide() end
        if s.flipRight then shadow.RIGHT:Hide(); shadow.TOPRIGHT:Hide(); shadow.BOTTOMRIGHT:Hide() end
        if shell.lit then shell.lit:Hide() end
    end
end)

function Edges.Apply(frame, left, right, cut, ref, keepRight)
    local l, r = left ~= "straight" and cut > 0, right ~= "straight" and cut > 0
    local side = l and (r and "both" or "left") or (r and "right" or nil)
    if not side then ref = nil end
    local under = not ref and (l and left == "bottom" and "left" or r and right == "bottom" and "right" or nil) or nil
    local s = shapes[frame] or {}
    shapes[frame] = s
    s.left, s.right, s.cut, s.ref = l and left or "straight", r and right or "straight", cut, ref
    s.keepRight = keepRight
    s.flipLeft = l and left == "bottom" and under ~= "left"
    s.flipRight = r and right == "bottom" and under ~= "right"
    Style.Slant(frame, side, cut, ref, under)
end

function Edges.Clear(frame)
    shapes[frame] = nil
end

function Edges.Fill(bar, side, cut, direction)
    Style.AngleFill(bar, direction ~= "straight" and side or nil, cut, direction == "bottom" or nil)
end

function Edges.Contour(frame, shape, width, height)
    local s = shapes[frame]
    if not s then return end
    local ref = s.ref
    local h, w, dx, dy = height, width, 0, 0
    if ref then
        h, w = ref.height, ref.frame:GetWidth()
        dx = ref.x or 0
        dy = ref.y or 0
    end
    local slope = math.sqrt(1 + (s.cut / h)^2)
    local function insetAt(direction, y, inset)
        if direction == "straight" then return inset end
        local t = math.max(0, math.min(1, (dy + y) / h))
        if direction == "bottom" then t = 1 - t end
        return t * s.cut + inset * slope
    end
    shape.left = function(y, inset)
        return math.max(0, math.min(width, insetAt(s.left, y, inset) - (s.left == "straight" and 0 or dx)))
    end
    if not s.keepRight then
        shape.right = function(y, inset)
            if s.right == "straight" then return width - inset end
            return math.max(0, math.min(width, w - dx - insetAt(s.right, y, inset)))
        end
    end
    return shape
end
