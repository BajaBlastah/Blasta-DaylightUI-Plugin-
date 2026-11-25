local ADDON, extras = ...
local DUI = DaylightUI
local key = "auraIconCorners"
local file = "Interface\\AddOns\\" .. ADDON .. "\\Media\\TooltipIconCut.tga"

extras.German["Aura icon shape"] = "Form der Aura-Icons"
extras.German["Cut player buff display icon corners"] = "Buff-Symbole an der Minikarte unten rechts abschrägen"
function extras.AuraIconCornersGroup()
    return { label = "Aura icon shape", items = {
        { type = "toggle", key = key, blastaSince = "2.0", label = "Cut player buff display icon corners" },
    } }
end

local mod = DUI:GetModule("Buffs")
local widgets = mod and mod.ns and mod.ns.Widgets
if not (widgets and widgets.Dress) then return end

local buttons = setmetatable({}, { __mode = "k" })
local pending = setmetatable({}, { __mode = "k" })
local enabled

local function makeMask(button)
    local mask = button:CreateMaskTexture()
    mask:SetTexture(file, "CLAMP", "CLAMP")
    return mask
end

local function fitMask(mask, region, previousSide)
    local ok, w, h = pcall(region.GetSize, region)
    local side = false
    if ok and not (DUI.IsSecret(w) or DUI.IsSecret(h)) and type(w) == "number" and type(h) == "number"
        and w > 0 and h > 0 then
        side = math.min(w, h)
    end
    if side == previousSide then return side end
    mask:ClearAllPoints()
    if side then
        mask:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT")
        mask:SetSize(side, side)
    else
        mask:SetAllPoints(region)
    end
    return side
end

local function add(state, texture, mask)
    if texture and not state.on[texture] then
        texture:AddMaskTexture(mask)
        state.on[texture] = mask
    end
end

local function apply(button, state)
    if not enabled then
        for texture, mask in pairs(state.on) do
            texture:RemoveMaskTexture(mask)
            state.on[texture] = nil
        end
        return
    end
    if not button.Icon then return end
    state.inner = state.inner or makeMask(button)
    state.outer = state.outer or makeMask(button)
    state.iconSide = fitMask(state.inner, button.Icon, state.iconSide)
    state.buttonSide = fitMask(state.outer, button, state.buttonSide)
    add(state, button.Icon, state.inner)
    add(state, button.Shade, state.inner)
    add(state, button.Edge, state.outer)
    add(state, button.EdgeR, state.outer)
    add(state, button.Caps and button.Caps.BOTTOMRIGHT, state.outer)
end

local function flush()
    for button in pairs(pending) do
        pending[button] = nil
        pcall(apply, button, buttons[button])
    end
end

local function style(button)
    local state = buttons[button]
    if not state then
        state = { on = {} }
        buttons[button] = state
    end
    if not enabled and not next(state.on) then return end
    if not pcall(apply, button, state) and DUI.Restricted() then
        pending[button] = true
        DUI.AfterRestrictions(flush, "blasta:auraIconCorners")
    end
end

hooksecurefunc(widgets, "Dress", style)
if widgets.Fit then hooksecurefunc(widgets, "Fit", style) end

local function sync()
    enabled = DUI:Get(ADDON, key) == true
    for button in pairs(buttons) do style(button) end
end
DUI.On("Login", sync)
DUI.On("ProfileKept", sync)
DUI.On("SettingChanged", function(scope, path)
    if scope == ADDON and path == key then sync() end
end)
