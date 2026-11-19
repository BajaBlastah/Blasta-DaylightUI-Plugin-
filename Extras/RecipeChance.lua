local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Professions")
local craft = DUI.Craft
local data, list, window = craft and craft.Data, craft and craft.List, craft and craft.Window
local parts = DUI.Win and DUI.Win.Parts
if not (mod and data and data.Chance and data.ChanceText and data.Skill
    and data.Color and parts and parts.Hex and list and list.PaintChance and window and window.Refill) then return end

local key = "blastaRecipeChance"
mod.defaults[key] = false
extras.AddSetting(mod, "rarityNames", {
    type = "toggle", key = key, label = "Recipe chance in the subtitle",
    desc = "Show DaylightUI's skill-up chance below each recipe name.",
})

local paint = list.PaintChance
function list.PaintChance(row, recipe)
    if DUI:Get(mod.name, key) ~= true then return paint(row, recipe) end

    -- Restore the count and subtitle anchors when a pooled row previously
    -- showed DaylightUI's right-hand badge.
    if row.chance then row.chance:Hide() end
    if list.chances then list.chances[recipe.id] = nil end
    row.value:ClearAllPoints()
    row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.sub:SetPoint("RIGHT", row.value, "LEFT", -10, 0)

    local skill = data.Skill(list.data and list.data.prof)
    local chance = data.ChanceText(data.Chance(recipe, skill))
    local subtitle = recipe.sub or ""
    if chance then
        chance = parts.Hex(data.Color(recipe.difficulty)) .. chance .. "|r"
        subtitle = subtitle ~= "" and (chance .. " · " .. subtitle) or chance
    end
    row.sub:SetText(subtitle)
end

DUI.On("SettingChanged", function(scope, path)
    if scope == mod.name and path == key then window.Refill() end
end)

extras.Loaded("RecipeChance")
