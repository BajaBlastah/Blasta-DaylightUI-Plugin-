local ADDON, extras = ...
local DUI = DaylightUI
local char = DUI.Char
local slots, pageAPI = char and char.Slots, char and char.CharacterPage
local style = DUI.Style
if not (slots and slots.Paint and slots.PaintEnchant and pageAPI and pageAPI.Build and pageAPI.Refresh
    and char.Gear and char.Gear.NO_LEVEL and style and style.LayoutShell) then return end

local tr = extras.Translate
local root = "characterPanel"
local function get(key) return DUI:Get(ADDON, root .. "." .. key) end
local function enabled() return get("enabled") == true end
extras.CharacterPanelDefaults = {
    enabled = false, square = true, border = 3, enchants = true,
    durability = true, durabilityThreshold = 50, itemLevel = true,
    qualityGradient = false, qualityGradientAlpha = 0.2, gearCheck = "always",
}
extras.CharacterPanelGroup = { label = "Appearance", items = {
    { type = "toggle", key = root .. ".enabled", label = "Enable Blasta Character Panel" },
    { type = "toggle", key = root .. ".square", label = "Square equipment icons",
        disabled = function() return not enabled() end },
    { type = "slider", key = root .. ".border", label = "Equipment border thickness",
        min = 0, max = 5, step = 1, unit = "px", disabled = function() return not enabled() end },
} }
for _, option in ipairs({
    { "enchants", "Show equipment enchantments" },
    { "durability", "Show equipment durability" },
    { "itemLevel", "Show item level on equipment icons" },
}) do
    extras.CharacterPanelGroup.items[#extras.CharacterPanelGroup.items + 1] = {
        type = "toggle", key = root .. "." .. option[1], label = option[2],
        disabled = function() return not enabled() end,
    }
end
extras.CharacterPanelGroup.items[#extras.CharacterPanelGroup.items + 1] = {
    type = "slider", key = root .. ".durabilityThreshold", label = "Show durability at or below",
    min = 0.25, max = 1, step = 0.05, unit = "%",
    get = function() return (get("durabilityThreshold") or 50) / 100 end,
    set = function(value) return DUI:Set(ADDON, root .. ".durabilityThreshold", math.floor(value * 100 + 0.5)) end,
    default = function() return 0.5 end,
    disabled = function() return not enabled() or get("durability") == false end,
}

local gradientSupported = DUI.Pixel and DUI.Pixel.Px and char.Gear.QualityColor
if gradientSupported then
    local items = extras.CharacterPanelGroup.items
    items[#items + 1] = { type = "toggle", key = root .. ".qualityGradient", label = "Equipment quality gradient",
        disabled = function() return not enabled() end }
    items[#items + 1] = { type = "slider", key = root .. ".qualityGradientAlpha", label = "Quality gradient opacity",
        min = 0, max = 1, step = 0.05, unit = "%",
        disabled = function() return not enabled() or get("qualityGradient") ~= true end }
end

local playerSlots = setmetatable({}, { __mode = "k" })
local page
local checkSupported = pageAPI.PaintFooter and GetInventoryItemLink
if checkSupported then
    local items = extras.CharacterPanelGroup.items
    items[#items + 1] = {
        type = "dropdown", key = root .. ".gearCheck", label = "Equipment check",
        values = { off = "Off", always = "Always", max = "Max level only" },
        order = { "off", "always", "max" },
        disabled = function() return not enabled() end,
    }
end

-- Common permanent enchant slots. Exclude profession-only and temporary enhancements.
local enchantSlots = { Back = true, Chest = true, Wrist = true, Hands = true, Feet = true, MainHand = true }
local function readable(value, kind)
    return type(value) == kind and not (issecretvalue and issecretvalue(value))
end

local function checkEnabled()
    if not enabled() then return false end
    local mode = get("gearCheck")
    if mode ~= "max" then return mode ~= "off" end
    local max = GetMaxPlayerLevel and GetMaxPlayerLevel()
    if not readable(max, "number") or max <= 0 then
        max = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion()
    end
    local level = UnitLevel("player")
    return readable(max, "number") and max > 0 and readable(level, "number") and level >= max
end

local paintGradient
local function highlightGear(footer, category)
    if not gradientSupported then return end
    for _, slot in pairs(footer.page.slots) do
        local state = playerSlots[slot]
        if state and state.item then
            local highlighted = category and state[category] == true
            if highlighted ~= state.highlighted then
                state.highlighted = highlighted
                paintGradient(slot, state.item, state.showGradient, highlighted)
            end
        end
    end
end

local function buildCheck(page)
    local foot = page.foot
    if not (foot and foot.dura and foot.sets) then return end
    local check = CreateFrame("Frame", nil, foot)
    check.page = page
    check:SetPoint("LEFT", foot.dura, "RIGHT", 20, 0)
    check:SetPoint("RIGHT", foot.sets, "LEFT", -12, 0)
    check:SetHeight(24)
    local previous
    for _, category in ipairs({ "missingEnchant", "lowDurability" }) do
        local region = CreateFrame("Frame", nil, check)
        region:SetHeight(24)
        if previous then region:SetPoint("LEFT", previous, "RIGHT", 12, 0)
        else region:SetPoint("LEFT", check, "LEFT", 0, 0) end
        region.text = style.Text(region, 11, "LEFT")
        region.text:SetPoint("LEFT")
        region.text:SetTextColor(0.92, 0.75, 0.48)
        region:EnableMouse(true)
        region:SetScript("OnEnter", function()
            check.hover = category
            region.text:SetTextColor(1, 0.88, 0.58)
            highlightGear(check, category)
        end)
        local function clear()
            region.text:SetTextColor(0.92, 0.75, 0.48)
            if check.hover == category then
                check.hover = nil
                highlightGear(check)
            end
        end
        region:SetScript("OnLeave", clear)
        region:SetScript("OnHide", clear)
        check[category], previous = region, region
    end
    check:Hide()
    foot.blastaGearCheck = check
end

if checkSupported then
    hooksecurefunc(pageAPI, "PaintFooter", function(current)
        local check = current.foot and current.foot.blastaGearCheck
        if not check then return end
        if not checkEnabled() then check:Hide(); return end
        local missing, worn = 0, 0
        for _, slot in pairs(current.slots) do
            local state = playerSlots[slot]
            if state and state.missingEnchant then missing = missing + 1 end
            if state and state.lowDurability then worn = worn + 1 end
        end
        local enchant, dura = check.missingEnchant, check.lowDurability
        enchant.text:SetText(tr("%d without enchant"):format(missing))
        dura.text:SetText(tr("%d low durability"):format(worn))
        local left, right = enchant.text:GetStringWidth(), dura.text:GetStringWidth()
        local width = check:GetWidth()
        if left + right + 12 > width then
            enchant.text:SetText(tr("Unenchanted: %d"):format(missing))
            dura.text:SetText(tr("Worn: %d"):format(worn))
            left, right = enchant.text:GetStringWidth(), dura.text:GetStringWidth()
        end
        enchant:SetWidth(math.max(1, left))
        dura:SetWidth(math.max(1, right))
        check:SetShown(left + right + 12 <= width)
        if check.hover then highlightGear(check, check.hover) end
    end)
end
function paintGradient(slot, item, show, highlighted)
    local gradient = slot.blastaQualityGradient
    local alpha = highlighted and 0.32 or (get("qualityGradientAlpha") or 0.2)
    if not (show or highlighted) or alpha <= 0 or slot:GetWidth() <= slot.size + 8 then
        if gradient then gradient:Hide() end
        return
    end
    local right = slot.side == "right"
    if not gradient then
        gradient = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
        gradient:SetColorTexture(1, 1, 1, 1)
        slot.blastaQualityGradient = gradient
    end
    local edge = get("square") ~= false and slot.edge and slot.edge.frame or slot.icon
    local shell = edge ~= slot.icon and slot.edge.shell
    local border = shell and shell.border
    local top = border and border.TOP or edge
    local bottom = border and border.BOTTOM or edge
    local extension = DUI.Pixel.Px(slot, 2)
    if gradient.blastaEdge ~= edge or gradient.blastaExtension ~= extension then
        gradient.blastaEdge, gradient.blastaExtension = edge, extension
        local overlap = edge ~= slot.icon and extension / 2 or 0
        gradient:ClearAllPoints()
        if right then
            gradient:SetPoint("LEFT", slot, "LEFT", -extension, 0)
            gradient:SetPoint("TOPRIGHT", top, "TOPLEFT", overlap, 0)
            gradient:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMLEFT", overlap, 0)
            gradient:SetVertexOffset(2, 8, 0)
        else
            gradient:SetPoint("TOPLEFT", top, "TOPRIGHT", -overlap, 0)
            gradient:SetPoint("BOTTOMLEFT", bottom, "BOTTOMRIGHT", -overlap, 0)
            gradient:SetPoint("RIGHT", slot, "RIGHT", extension, 0)
            gradient:SetVertexOffset(4, -8, 0)
        end
    end
    local r, g, b
    if highlighted then r, g, b = 1, 0.65, 0.15
    else r, g, b = char.Gear.QualityColor(item.quality) end
    if gradient.blastaR ~= r or gradient.blastaG ~= g or gradient.blastaB ~= b
        or gradient.blastaAlpha ~= alpha or gradient.blastaRight ~= right then
        local start, finish = CreateColor(r, g, b, alpha), CreateColor(r, g, b, 0)
        if right then start, finish = finish, start end
        gradient:SetGradient("HORIZONTAL", start, finish)
        gradient.blastaR, gradient.blastaG, gradient.blastaB = r, g, b
        gradient.blastaAlpha, gradient.blastaRight = alpha, right
    end
    if not gradient:IsShown() then gradient:Show() end
end

local function durability(item)
    if get("durability") == false or not item.max or item.max <= 0 then return end
    local percent = math.floor(item.cur * 100 / item.max + 0.5)
    if percent > (get("durabilityThreshold") or 50) and not item.wear then return end
    local color = percent <= 25 and slots.RED or percent <= 50 and slots.AMBER or slots.DIM
    return tr("Gear durability short: %d%%"):format(percent), color
end

if pageAPI.Rects and pageAPI.Place then
    local rects = pageAPI.Rects
    function pageAPI.Rects(width, height, names, ammo)
        local layout = rects(width, height, names, ammo)
        if not enabled() or not names then return layout end
        local extra = math.min(18, math.max(0, math.floor((layout.model.w - 110) / 2)))
        layout.left.w = layout.left.w + extra
        layout.right.x, layout.right.w = layout.right.x - extra, layout.right.w + extra
        layout.model.x, layout.model.w = layout.model.x + extra, layout.model.w - 2 * extra
        local bottom = layout.bottom
        local first = bottom[1]
        if first then first.x, first.w = first.x - extra, first.w + extra end
        for i = 2, #bottom do
            local row = bottom[i]
            local limit = bottom[i + 1] and bottom[i + 1].x - 6 or layout.right.x + layout.right.w
            row.w = math.min(row.w + extra, limit - row.x)
        end
        return layout
    end
end
local function paintLevel(slot, item, show)
    local badge = slot.blastaItemLevel
    if not show then
        if badge then badge:Hide() end
        return
    end
    if not badge then
        badge = CreateFrame("Frame", nil, slot.icon)
        badge:SetPoint("BOTTOMLEFT", slot.icon, "BOTTOMLEFT")
        badge:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT")
        badge:SetHeight(13)
        local background = badge:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.72)
        badge.text = style.Text(badge, 11, "CENTER")
        badge.text:SetPoint("CENTER")
        slot.blastaItemLevel = badge
    end
    badge.text:SetText(tostring(item.level))
    badge:Show()
end

hooksecurefunc(slots, "Paint", function(slot, item)
    if not playerSlots[slot] then return end
    local on = enabled()
    local edge = slot.edge
    local shell = edge and edge.shell
    if shell and shell.opts and edge.frame then
        local original = playerSlots[slot]
        local px = on and (get("border") or 3) or original.border
        local corner = original.corner
        if on and get("square") ~= false then corner = 0 end
        if shell.opts.borderPx ~= px or shell.opts.cornerPx ~= corner then
            shell.opts.borderPx, shell.opts.cornerPx = px, corner
            local pad = px or slots.EDGE
            edge.frame:ClearAllPoints()
            edge.frame:SetPoint("TOPLEFT", slot.icon, "TOPLEFT", -pad, pad)
            edge.frame:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", pad, -pad)
            style.LayoutShell(shell)
        end
    end
    local equipment = not item.empty and not item.ammo and not char.Gear.NO_LEVEL[item.key]
    if checkSupported then
        local state = playerSlots[slot]
        state.missingEnchant, state.lowDurability = false, false
        if equipment and checkEnabled() then
            if enchantSlots[item.key] and item.id then
                local link = GetInventoryItemLink("player", item.id)
                if readable(link, "string") then
                    local enchant = link:match("item:%-?%d+:([^:]*)")
                    state.missingEnchant = enchant == "0" or enchant == ""
                end
            end
            if readable(item.cur, "number") and readable(item.max, "number") and item.max > 0 then
                state.lowDurability = math.floor(item.cur * 100 / item.max + 0.5)
                    <= (get("durabilityThreshold") or 50)
            end
        end
    end
    if gradientSupported then
        local state = playerSlots[slot]
        state.item = item
        state.showGradient = on and equipment and slot.names and get("qualityGradient") == true
        local check = page and page.foot and page.foot.blastaGearCheck
        local category = check and check.hover
        state.highlighted = category and state[category] == true
        paintGradient(slot, item, state.showGradient, state.highlighted)
    end
    paintLevel(slot, item, on and equipment and get("itemLevel") ~= false and item.level ~= nil)
    if not on or not equipment then return end
    slot.corner:SetText("")
    local wear, color = durability(item)
    local enchant = get("enchants") ~= false and item.enchant
    slot.line:SetText(enchant or wear or "")
    local ink = enchant and slots.ENCHANT or color or slots.DIM
    slot.line:SetTextColor(ink[1], ink[2], ink[3])
    slot.dot:SetShown(wear ~= nil and item.wear ~= nil)
end)

local paintEnchant = slots.PaintEnchant
function slots.PaintEnchant(slot, item)
    if playerSlots[slot] and enabled() and not item.empty then
        local enchant = get("enchants") ~= false and item.enchant
        local wear, color = durability(item)
        local display = {}
        for key, value in pairs(item) do display[key] = value end
        display.enchant = slot.names and enchant and wear or (not slot.names and enchant or nil)
        paintEnchant(slot, display)
        local ink = slot.names and enchant and color or slots.ENCHANT
        slot.enchant:SetTextColor(ink[1], ink[2], ink[3])
        return
    end
    if playerSlots[slot] then slot.enchant:SetTextColor(unpack(slots.ENCHANT)) end
    return paintEnchant(slot, item)
end

hooksecurefunc(pageAPI, "Build", function(built)
    page = built
    for _, slot in pairs(page.slots or {}) do
        local shell = slot.edge and slot.edge.shell
        local opts = shell and shell.opts
        playerSlots[slot] = { border = opts and opts.borderPx, corner = opts and opts.cornerPx }
    end
    if checkSupported then buildCheck(page) end
end)

DUI.On("SettingChanged", function(scope, key)
    if scope == ADDON and type(key) == "string" and key:sub(1, #root + 1) == root .. "." and page and page:IsVisible() then
        if key == root .. ".enabled" and pageAPI.Place then pageAPI.Place(page) end
        pageAPI.Refresh(page)
    end
end)

extras.Loaded("CharacterPanel")
