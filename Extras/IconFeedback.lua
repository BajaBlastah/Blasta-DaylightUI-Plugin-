local _, extras = ...
local DUI = DaylightUI
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- A pixel outline on the artwork. The last segment follows a clipped corner.
function extras.IconOutline(frame)
    local lines = {}
    for i = 1, 5 do
        local line = frame:CreateLine(nil, "OVERLAY", nil, 7)
        line:SetTexture(WHITE)
        line:Hide()
        lines[i] = line
    end
    local oldCut, oldPixel
    return function(cut, shown, color)
        if not shown then
            for _, line in ipairs(lines) do line:Hide() end
            return
        end
        cut = cut or 0
        local pixel = DUI.Pixel.Px(frame, 1)
        if cut ~= oldCut or pixel ~= oldPixel then
            oldCut, oldPixel = cut, pixel
            local half = pixel / 2
            local function segment(i, a, ax, ay, b, bx, by)
                lines[i]:SetThickness(pixel)
                lines[i]:SetStartPoint(a, frame, ax, ay)
                lines[i]:SetEndPoint(b, frame, bx, by)
            end
            segment(1, "TOPLEFT", 0, -half, "TOPRIGHT", 0, -half)
            segment(2, "TOPLEFT", half, 0, "BOTTOMLEFT", half, 0)
            segment(3, "TOPRIGHT", -half, 0, "BOTTOMRIGHT", -half, math.max(0, cut - half))
            segment(4, "BOTTOMLEFT", 0, half, "BOTTOMRIGHT", -math.max(0, cut - half), half)
            if cut > 0 then segment(5, "BOTTOMRIGHT", -half, cut - half, "BOTTOMRIGHT", -cut + half, half) end
        end
        for i, line in ipairs(lines) do
            line:SetVertexColor(color and color.r or 1, color and color.g or 1, color and color.b or 1, 1)
            line:SetShown(i ~= 5 or cut > 0)
        end
    end
end

local quests = DUI:GetModule("Quests")
local items = quests and quests.ns and quests.ns.Items
if not (items and items.Place and items.buttons) then return end
local T = extras.Translate
extras.German["Quest item is out of range."] = "Questgegenstand ist außer Reichweite."
extras.German["Quest item is on cooldown."] = "Questgegenstand hat Abklingzeit."
extras.German["Quest item cannot be used right now."] = "Questgegenstand kann gerade nicht verwendet werden."
local hooked = setmetatable({}, { __mode = "k" })

local function tooltipStatus(button)
    if not (GameTooltip and button.link) then return end
    if not GameTooltip:IsOwned(button) then
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(button.link)
    end
    local status
    if button.tint == true then
        status = "Quest item is out of range."
    elseif type(button.cdStart) == "number" and type(button.cdDur) == "number"
        and button.cdStart + button.cdDur > GetTime() then
        status = "Quest item is on cooldown."
    elseif C_Item and C_Item.IsUsableItem then
        local ok, usable = pcall(C_Item.IsUsableItem, button.link)
        if ok and not DUI.IsSecret(usable) and usable == false then status = "Quest item cannot be used right now." end
    end
    if status then GameTooltip:AddLine(T(status), 1, 0.45, 0.35, true) end
    GameTooltip:Show()
end

local function attach()
    if InCombatLockdown() then return end
    for _, button in pairs(items.buttons) do
        if not hooked[button] then
            local outline = extras.IconOutline(button)
            button:HookScript("OnEnter", function(self)
                outline(nil, true)
                DUI.SafeCall(tooltipStatus, self)
            end)
            local function leave() outline(nil, false) end
            button:HookScript("OnLeave", leave)
            button:HookScript("OnHide", leave)
            hooked[button] = true
        end
    end
end
hooksecurefunc(items, "Place", attach)
DUI.On("Login", attach)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", attach)
