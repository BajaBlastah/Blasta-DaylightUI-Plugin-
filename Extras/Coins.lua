-- SPDX-License-Identifier: GPL-3.0-or-later
-- Money in DaylightUI's coins wherever it shows, and one rule for prices in
-- item tooltips.
--
--   Daylight coins   DaylightUI swaps the game's coins in its own tooltip lines
--                    and skinned money frames. Blasta does the rest: lines other
--                    addons add (Auctionator's auction and vendor prices), every
--                    money frame the game updates, and Auctionator's own windows.
--   prices per piece Auctionator prices one item and the whole stack while Shift
--                    is held (or the other way round, its "Shift for stack"
--                    setting). The game's sell price is always the whole stack.
--                    Blasta makes the sell price follow Auctionator's rule:
--                    per piece, and "Verkaufspreis x20" with Shift.
--
-- Only the coins are swapped (and the amount moved to one piece); nothing is
-- added or removed, and a secret line is left as it is.
local ADDON, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Tooltip")
if not (DUI.CoinIcon and DUI.Widgets and DUI.Widgets.Money and hooksecurefunc) then return end

local function secret(v) return issecretvalue and issecretvalue(v) end
local function plain(v) if secret(v) then return nil end return v end

local function setting(key)
    local db = mod and mod.db
    return not (type(db) == "table" and db[key] == false)
end
local function coinsOn() return setting("blastaCoins") end
local function unitOn() return setting("blastaUnitPrice") end

if mod and extras.AddSetting then
    extras.AddSetting(mod, "stackSize", {
        type = "toggle", key = "blastaCoins", label = "Daylight coins everywhere",
        desc = "Prices from other addons (Auctionator) and the game's money boxes use DaylightUI's coins too.",
    })
    extras.AddSetting(mod, "blastaCoins", {
        type = "toggle", key = "blastaUnitPrice", label = "Sell price per piece",
        desc = "On a stack, the sell price is for one piece, like Auctionator's prices; hold Shift for the whole stack. Follows Auctionator's \"Shift for stack price\" setting when it's installed.",
    })
end

local COPPER = { gold = 10000, silver = 100, copper = 1 }
local function money(copper) return DUI.Widgets.Money(copper) end

-- The game's and other addons' coins: an atlas (|A:coin-gold:...|a) or the old
-- textures (|TInterface\MoneyFrame\UI-GoldIcon:...|t), each after its digits.
local NUM = "(%d[%d,%. \194\160]*)"
local ATLAS = NUM .. "%s*|A:coin%-(%a+):[^|]*|a"
local TEXTURE = NUM .. "%s*|T[Ii]nterface[\\/][Mm]oney[Ff]rame[\\/][Uu][Ii]%-(%a+)[Ii]con[^|]*|t"
local OWN = NUM .. "%s*|T[^|]*coin%-(%a+)%.png[^|]*|t"

local function digits(s) return tonumber((s:gsub("%D", ""))) end

-- Every coin of the game's in text as DaylightUI's, amount by amount.
local function recoin(text)
    if type(text) ~= "string" or secret(text) then return nil end
    if not (text:find("|A:coin-", 1, true) or text:find("[Mm]oney[Ff]rame")) then return nil end
    local out = text
    for _, pattern in ipairs({ ATLAS, TEXTURE }) do
        out = out:gsub(pattern, function(n, kind)
            local value = digits(n)
            local per = COPPER[kind:lower()]
            if not (value and per) then return nil end
            return money(value * per)
        end)
    end
    return out ~= text and out or nil
end

-- The amount in copper of every coin in a line, any of the three kinds.
local function amountOf(text)
    if type(text) ~= "string" then return nil end
    local s = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local total, found = 0, false
    for _, pattern in ipairs({ ATLAS, TEXTURE, OWN }) do
        for n, kind in s:gmatch(pattern) do
            local value, per = digits(n), COPPER[kind:lower()]
            if value and per then total, found = total + value * per, true end
        end
    end
    return found and total or nil
end

-- ---------------------------------------------------------------------
-- Tooltip lines
-- ---------------------------------------------------------------------

local function line(tip, i, side)
    local name = tip.GetName and tip:GetName()
    return type(name) == "string" and _G[name .. "Text" .. side .. i] or nil
end

-- Auctionator's rule: stack prices with Shift, or without it when its
-- "Shift for stack price" setting is off.
local function stackWanted()
    local shift = IsShiftKeyDown and IsShiftKeyDown() == true
    local A = _G.Auctionator
    local C = type(A) == "table" and A.Config
    if type(C) == "table" and type(C.Get) == "function" and type(C.Options) == "table" and C.Options.SHIFT_STACK_TOOLTIPS then
        local ok, on = pcall(C.Get, C.Options.SHIFT_STACK_TOOLTIPS)
        if ok and on == false then return not shift end
    end
    return shift
end

local function countText(n)
    local A = _G.Auctionator
    local U = type(A) == "table" and A.Utilities
    if type(U) == "table" and type(U.CreateCountString) == "function" then
        local ok, s = pcall(U.CreateCountString, n)
        if ok and type(s) == "string" then return s end
    end
    return " x" .. n
end

local function sellPriceOf(link)
    if type(link) ~= "string" or not (C_Item and C_Item.GetItemInfo) then return nil end
    local ok, price = pcall(function() return select(11, C_Item.GetItemInfo(link)) end)
    price = ok and plain(price) or nil
    return type(price) == "number" and price > 0 and price or nil
end

-- The game's "Sell price: <stack total>" as one piece, or the stack with its
-- count, by Auctionator's rule.
local function unitPrice(tip, n)
    if type(SELL_PRICE) ~= "string" or not tip.GetItem then return end
    local ok, _, link = pcall(tip.GetItem, tip)
    link = ok and plain(link) or nil
    local each = sellPriceOf(link)
    if not each then return end
    local label = SELL_PRICE
    for i = 2, n do
        local fs = line(tip, i, "Left")
        local text = fs and fs.GetText and plain(fs:GetText())
        if type(text) == "string" then
            local bare = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            if bare:sub(1, #label) == label then
                local total = amountOf(bare)
                if not total then return end
                local count = math.floor(total / each + 0.5)
                if count <= 1 then return end
                local shown = stackWanted() and (label .. countText(count) .. ": " .. money(total))
                    or (label .. ": " .. money(each))
                if shown ~= text then fs:SetText(shown) end
                return
            end
        end
    end
end

local function paintTip(tip)
    if type(tip) ~= "table" or not tip.NumLines then return end
    local n = plain(tip:NumLines())
    if type(n) ~= "number" or n < 2 then return end
    if coinsOn() then
        for i = 2, n do
            for _, side in ipairs({ "Left", "Right" }) do
                local fs = line(tip, i, side)
                local coins = fs and fs.GetText and recoin(plain(fs:GetText()))
                if coins then fs:SetText(coins) end
            end
        end
    end
    if unitOn() then unitPrice(tip, n) end
end

local function safe(tip) pcall(paintTip, tip) end

-- After every addon had its turn: Auctionator adds its lines and then calls Show.
local tips = setmetatable({}, { __mode = "k" })
local function hookTip(tip)
    if type(tip) ~= "table" or tips[tip] or type(tip.Show) ~= "function" then return end
    tips[tip] = true
    hooksecurefunc(tip, "Show", safe)
end

local function hookTips()
    for _, name in ipairs({ "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2",
        "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
        hookTip(_G[name])
    end
end

local TDP = TooltipDataProcessor
if TDP and TDP.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    -- The item's own lines (the game's sell price), right after DaylightUI's.
    TDP.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip) safe(tip) end)
end

-- ---------------------------------------------------------------------
-- Money frames and Auctionator's windows
-- ---------------------------------------------------------------------

local function coinArt(tex, coin)
    if type(tex) ~= "table" or not tex.SetTexture then return end
    tex:SetTexture(DUI.MEDIA .. "coin-" .. coin .. ".png")
    tex:SetTexCoord(-4 / 64, 60 / 64, 0, 1)
end

-- Any money frame the game updates (merchant, mail, quests, tooltips), not
-- only the ones DaylightUI's skins know. Left alone in colorblind mode, where
-- the game shows words instead of coins.
local function colorblind()
    if ENABLE_COLORBLIND_MODE == "1" then return true end
    if C_CVar and C_CVar.GetCVarBool then
        local ok, on = pcall(C_CVar.GetCVarBool, "colorblindMode")
        return ok and on == true
    end
    return false
end

if type(_G.MoneyFrame_Update) == "function" then
    hooksecurefunc("MoneyFrame_Update", function(frame)
        if not coinsOn() or colorblind() then return end
        if type(frame) == "string" then frame = _G[frame] end
        if type(frame) ~= "table" then return end
        for _, coin in ipairs({ "gold", "silver", "copper" }) do
            local b = frame[coin:gsub("^%l", string.upper) .. "Button"]
            if type(b) == "table" and b.GetNormalTexture then pcall(coinArt, b:GetNormalTexture(), coin) end
        end
    end)
end

-- Auctionator builds all its prices (tooltips, the auction house lists) with
-- one function; its coins swapped there, its layout kept.
local function wrapAuctionator()
    local A = _G.Auctionator
    local U = type(A) == "table" and A.Utilities
    if type(U) ~= "table" or type(U.CreatePaddedMoneyString) ~= "function" or U.blastaCoins then return end
    U.blastaCoins = true
    local padded = U.CreatePaddedMoneyString
    U.CreatePaddedMoneyString = function(...)
        local s = padded(...)
        if not coinsOn() or type(s) ~= "string" then return s end
        return (s:gsub("|T[Ii]nterface[\\/][Mm]oney[Ff]rame[\\/][Uu][Ii]%-(%a+)[Ii]con[^|]*|t", function(kind)
            kind = kind:lower()
            return COPPER[kind] and DUI.CoinIcon(kind) or nil
        end))
    end
end

hookTips()
wrapAuctionator()
DUI.RegisterEvent("ADDON_LOADED", function(_, name)
    if name == "Auctionator" then wrapAuctionator() end
    hookTips()
end)
DUI.On("Login", function() hookTips(); wrapAuctionator() end)

extras.Loaded("Coins")
