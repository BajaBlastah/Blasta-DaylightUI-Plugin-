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

    -- Recent DaylightUI versions paint profit through the same method as chance.
    if list.profits then paint(row, recipe) end
    if row.chance then row.chance:Hide() end
    if list.chances then list.chances[recipe.id] = nil end
    if row.profit and row.profit:IsShown() and row.block then
        local point, relative, relativePoint, _, y = row.profit:GetPoint()
        if point then
            row.profit:ClearAllPoints()
            row.profit:SetPoint(point, relative, relativePoint, -8, y)
        end
        local gap = list.CORNER_GAP or 6
        local inset = math.max(0, row.profit:GetStringWidth() - row.value:GetStringWidth()) + gap
        row.sub:SetPoint("BOTTOMRIGHT", row.block, "BOTTOMRIGHT", -inset, 0)
    else
        row.value:ClearAllPoints()
        row.value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        if row.block and list.profits then
            row.sub:SetPoint("BOTTOMRIGHT", row.block, "BOTTOMRIGHT", 0, 0)
        else
            row.sub:SetPoint("RIGHT", row.value, "LEFT", -10, 0)
        end
    end

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

-- The recipe detail already renders DaylightUI's full Profit section.
-- Fill gaps in its price source from Auctionator on clients with both addons.
local function addAuctionatorPrices()
    local source = DUI.AuctionPrices
    local ah = DUI:GetModule("AuctionHouse")
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (source and ah and ah.ns and source == ah.ns.Bridge and type(source.Item) == "function"
        and api and type(api.GetAuctionPriceByItemID) == "function") then return end

    local nativeItem = source.Item
    function source.Item(itemID)
        local price, seenAt = nativeItem(itemID)
        if price ~= nil then return price, seenAt end
        local ok, fallback = pcall(api.GetAuctionPriceByItemID, "DaylightUI_Blasta", itemID)
        if ok and type(fallback) == "number" and fallback > 0 then return fallback end
    end

    local function pricesChanged() DUI.Fire("AuctionPricesChanged") end
    DUI.RegisterEvent("AUCTION_HOUSE_CLOSED", pricesChanged)
    pricesChanged()
end

if DUI.loggedIn then addAuctionatorPrices() else DUI.On("Login", addAuctionatorPrices) end

extras.Loaded("RecipeChance")
