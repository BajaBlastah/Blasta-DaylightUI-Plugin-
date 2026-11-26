local _, blasta = ...
local german = blasta.German
local DUI = DaylightUI
local module = DUI:GetModule("Bags")
local items = module and module.ns and module.ns.Items
if not (items and type(items.BORDER_PX) == "number" and type(items.SHELL) == "table"
    and type(module.defaults) == "table" and type(module.OnEnable) == "function") then return end

local options
for _, page in ipairs(module.options and module.options.pages or {}) do
    if page.id == "bags" then
        for _, group in ipairs(page.groups or {}) do
            if group.label == "Item icons" then options = group.items; break end
        end
        break
    end
end
if type(options) ~= "table" then return end

local key, label = "itemBorderOverride", "Item border thickness"
local desc = "Changes the shared slot borders in DaylightUI bags and bank. At 0, use Blasta's single-pixel outline."
german[label] = "Randdicke der Gegenstände"
german[desc] = "Ändert die Gegenstandsrahmen in Taschen und Bank. Bei 0 zeichnet Blasta eine einzelne Kontur mit einem Pixel."
module.defaults[key] = 0

-- Square slots: flat rings without rounded corners or the inner shadow.
-- Off gives DaylightUI's own slot look back (corners follow DaylightUI's
-- general corner setting).
local squareKey, squareLabel = "blastaSquareItems", "Square item icons"
local squareDesc = "Draws bag and bank slots as flat squares without rounded corners or inner shadow. Turn off for DaylightUI's own look."
german[squareLabel] = "Eckige Gegenstandssymbole"
german[squareDesc] = "Zeichnet Taschen- und Bankplätze als flache Quadrate ohne abgerundete Ecken und Innenschatten. Aus: DaylightUI-eigener Look."
module.defaults[squareKey] = true

local function square()
    return not (module.db and module.db[squareKey] == false)
end

if type(items.Parts) == "function" and type(items.Paint) == "function" then
    hooksecurefunc(items, "Paint", blasta.SafeHook("BagBorders.Paint", function(button)
        if not square() then return end
        local parts = items.Parts(button)
        if parts and parts.shade then parts.shade:Hide() end
    end))
end
-- The game's quest border is round-cornered art. Square slots get their own
-- square gold ring on top of the slot ring instead, plus a "!" for items
-- that start a quest.
local QUEST_COLOR = { 1, 0.82, 0.25 }
local questMarks = setmetatable({}, { __mode = "k" })

local function px(button, n)
    local pixel = DUI.Pixel
    if pixel and pixel.Px then return pixel.Px(button, n) end
    return n
end

local function questMark(button)
    local mark = questMarks[button]
    if mark then return mark end
    mark = CreateFrame("Frame", nil, button)
    mark:SetAllPoints(button)
    mark:SetFrameLevel(button:GetFrameLevel() + 6)
    mark.edges = {}
    for i = 1, 4 do
        local edge = mark:CreateTexture(nil, "OVERLAY", nil, 6)
        edge:SetColorTexture(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], 1)
        mark.edges[i] = edge
    end
    mark.bang = mark:CreateFontString(nil, "OVERLAY")
    mark.bang:SetFont(STANDARD_TEXT_FONT, 14, blasta.Outline("OUTLINE"))
    mark.bang:SetText("!")
    mark.bang:SetTextColor(QUEST_COLOR[1], QUEST_COLOR[2], QUEST_COLOR[3], 1)
    questMarks[button] = mark
    return mark
end

local function layoutMark(button, mark)
    local inset = px(button, items.EDGE_PX or 1)
    local width = px(button, items.BORDER_PX or 1)
    if mark.inset == inset and mark.width == width then return end
    mark.inset, mark.width = inset, width
    local top, bottom, left, right = unpack(mark.edges)
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", button, "TOPRIGHT", -inset, -inset)
    top:SetHeight(width)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(width)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
    left:SetWidth(width)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
    right:SetWidth(width)
    mark.bang:ClearAllPoints()
    mark.bang:SetPoint("TOPLEFT", button, "TOPLEFT", inset + width + px(button, 2), -(inset + width))
end

local function paintQuest(button)
    local quest = button.IconQuestTexture or button.iconQuestTexture
    local holder = button:GetParent()
    local bag, slot = holder and holder.GetID and holder:GetID(), button.GetID and button:GetID()
    local info
    if bag and slot and C_Container and C_Container.GetContainerItemQuestInfo then
        local ok, result = pcall(C_Container.GetContainerItemQuestInfo, bag, slot)
        if ok and type(result) == "table" then info = result end
    end
    local starts = info and info.questID ~= nil and not info.isActive
    local isQuest = info and (info.isQuestItem or info.questID ~= nil)
    if not isQuest then
        if questMarks[button] then questMarks[button]:Hide() end
        return
    end
    if quest and quest.SetAlpha then quest:SetAlpha(0) end
    local mark = questMark(button)
    layoutMark(button, mark)
    local size = math.max(10, math.floor((button:GetHeight() or 37) * 0.42 + 0.5))
    if mark.size ~= size then
        mark.size = size
        mark.bang:SetFont(STANDARD_TEXT_FONT, size, blasta.Outline("OUTLINE"))
    end
    mark.bang:SetShown(starts and true or false)
    mark:Show()
end

if type(items.Fill) == "function" then
    hooksecurefunc(items, "Fill", blasta.SafeHook("BagBorders.Fill", function(button)
        if button:IsForbidden() then return end
        if square() then paintQuest(button) end
        -- The native item setters can repaint the slot when its contents change.
        local icon = button.icon or button.Icon
        if icon and icon.SetTexCoord then icon:SetTexCoord(unpack(items.CROP)) end
        local normal = button.GetNormalTexture and button:GetNormalTexture()
        if normal then normal:SetAlpha(0) end
        if button.IconBorder then button.IconBorder:SetAlpha(0) end
        if button.ItemSlotBackground then button.ItemSlotBackground:SetAlpha(0) end
        -- The quest border and quest-start mark stay: DaylightUI sizes them to
        -- the slot, and they are the only hint that an item belongs to a quest.
    end))
end
table.insert(options, 1, {
    type = "slider", key = key, label = label, desc = desc, reload = true,
    min = 0, max = 6, step = 1, unit = "px",
    disabled = function(get) return get("enabled") == false end,
})
table.insert(options, 2, {
    type = "toggle", key = squareKey, label = squareLabel, desc = squareDesc, reload = true, blastaSince = "1.6.3",
    disabled = function(get) return get("enabled") == false end,
})

local enable = module.OnEnable
function module.OnEnable(mod, ...)
    local override = tonumber(mod.db and mod.db[key]) or 0
    local px = override >= 1 and math.min(6, math.floor(override)) or 1
    items.BORDER_PX, items.SHELL.borderPx = px, px
    if square() then
        items.SHELL.flat, items.SHELL.cornerPx = true, 0
        items.SHELL.shadowAlpha = 0
    end
    return enable(mod, ...)
end

-- Recipes stayed red after a skill-up: DaylightUI checks again on the frame
-- after the skill changes, but the game can still describe the recipe with the
-- old skill then, and that answer is kept. Blasta asks once more a moment
-- later (also after a skill-up message and when a profession window closes),
-- so the red tint follows the new skill.
do
    local ns = module.ns
    local pending
    local function again()
        pending = nil
        if type(items.ForgetUsable) == "function" and type(ns.RecheckUnusable) == "function" then
            items.ForgetUsable()
            pcall(ns.RecheckUnusable)
        end
    end
    local function later()
        if pending or not (C_Timer and C_Timer.After) then return end
        pending = true
        C_Timer.After(1.5, again)
    end
    for _, event in ipairs({ "SKILL_LINES_CHANGED", "NEW_RECIPE_LEARNED", "CHAT_MSG_SKILL", "TRADE_SKILL_CLOSE", "CRAFT_CLOSE" }) do
        pcall(DUI.RegisterEvent, event, later)
    end
end

blasta.Loaded("BagBorders")
