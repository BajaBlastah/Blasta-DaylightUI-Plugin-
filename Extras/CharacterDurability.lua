-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
local DUI = DaylightUI
local Colors = DUI.Char and DUI.Char.Colors
local function number(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end
function extras.PaintCharacterDurability(slot, item, shown, repairAt)
    local warning = slot.blastaDurability
    if warning and not warning.mark then
        warning:Hide()
        slot.blastaDurability, warning = nil, nil
    end
    repairAt = number(repairAt) and math.max(0, math.min(1, repairAt)) or 0.25
    if not shown or not item or item.empty or not number(item.cur) or not number(item.max)
        or item.max <= 0 or item.cur >= item.max then
        -- The caller already applied the "show durability at or below"
        -- threshold. repairAt only picks the color.
        if warning then warning:Hide() end
        return
    end
    if not warning then
        warning = CreateFrame("Frame", nil, slot.icon)
        warning:EnableMouse(false) -- Keep the game's existing item tooltip/clicks.
        local file = DUI.MEDIA .. "crest-disc.png"
        warning.back = warning:CreateTexture(nil, "BACKGROUND")
        warning.back:SetTexture(file)
        warning.back:SetPoint("CENTER")
        warning.back:SetVertexColor(0, 0, 0, 0.9)
        warning.mark = warning:CreateTexture(nil, "OVERLAY")
        warning.mark:SetTexture(file)
        warning.mark:SetAllPoints()
        slot.blastaDurability = warning
    end
    local px = DUI.Pixel.Px(slot.icon, 1)
    warning:SetFrameLevel(slot.icon:GetFrameLevel() + 4)
    warning:SetSize(6 * px, 6 * px)
    warning:ClearAllPoints()
    warning:SetPoint("TOPRIGHT", slot.icon, "TOPRIGHT", -2 * px, -2 * px)
    warning.back:SetSize(8 * px, 8 * px)
    local r, g, b = 1, 0.38, 0.33
    if Colors and Colors.Durability then r, g, b = Colors.Durability(item.cur / item.max, repairAt) end
    warning.mark:SetVertexColor(r, g, b)
    warning:Show()
end
