local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Professions")
local craft = DUI.Craft
local parts = DUI.Win and DUI.Win.Parts
local motion = DUI.Motion
if not (mod and craft and craft.Make and craft.List and parts and parts.Shine and motion and motion.Tween) then return end

mod.defaults.blastaCraftShine = false
extras.AddSetting(mod, "rarityNames", { type = "toggle", key = "blastaCraftShine", label = "Craft completion sweep",
    desc = "Sweep a golden highlight across the recipe row after each successful craft." })

local shine = parts.Shine
local overlays = setmetatable({}, { __mode = "k" })
function parts.Shine(row, ...)
    local state = craft.Make.state
    if not (row and state and mod.enabled and mod.db and mod.db.blastaCraftShine and motion.On()
        and craft.List.lines and craft.List.lines[state.id] == row) then
        return shine(row, ...)
    end

    local clip = overlays[row]
    if not clip then
        clip = CreateFrame("Frame", nil, row)
        clip:SetAllPoints()
        clip:SetClipsChildren(true)
        clip.light = clip:CreateTexture(nil, "OVERLAY")
        clip.light:SetBlendMode("ADD")
        clip.light:SetColorTexture(1, 1, 1, 1)
        local clear = CreateColor(1, 0.80, 0.50, 0)
        local gold = CreateColor(1, 0.88, 0.66, 0.20)
        clip.light:SetGradient("HORIZONTAL", clear, gold)
        clip.edge = clip:CreateTexture(nil, "OVERLAY")
        clip.edge:SetBlendMode("ADD")
        clip.edge:SetColorTexture(1, 1, 1, 1)
        clip.edge:SetGradient("HORIZONTAL", gold, clear)
        overlays[row] = clip
    end
    local width = row:GetWidth() * 0.18
    local recipeID = state.id
    clip.light:SetSize(width, row:GetHeight())
    clip.edge:SetSize(width, row:GetHeight())
    clip.edge:SetPoint("LEFT", clip.light, "RIGHT")
    clip:Show()
    motion.Tween(clip, 0, 1, 0.42, function(progress)
        if not row:IsVisible() or not craft.List.lines or craft.List.lines[recipeID] ~= row then
            clip:Hide()
            return
        end
        clip.light:ClearAllPoints()
        clip.light:SetPoint("RIGHT", clip, "LEFT", -width + progress * (clip:GetWidth() + width * 2), 0)
    end, function() clip:Hide() end)
end

extras.Loaded("CraftShine")
