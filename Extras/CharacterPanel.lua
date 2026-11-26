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
local function gridSelected()
    local layout = get("layout")
    if layout == "classic" then return false end
    if layout == "grid" then return true end
    return get("refined") ~= false -- Preserve the earlier toggle on old profiles.
end
local function refined() return enabled() and gridSelected() end
extras.CharacterPanelDefaults = {
    enabled = false, square = true, border = 3, enchants = true,
    durability = true, durabilityThreshold = 50, itemLevel = true, itemLevelSize = 11,
    qualityGradient = false, qualityGradientAlpha = 0.2, qualityGradientStyle = "auto", gearCheck = "always", refined = true,
}
extras.CharacterPanelGroup = { label = "Appearance", items = {
    { type = "toggle", key = root .. ".enabled", label = "Enable Blasta Character Panel" },
    { type = "dropdown", key = root .. ".layout", label = "Character sheet layout",
        values = { classic = "Classic", grid = "Equipment grid" }, order = { "classic", "grid" },
        desc = "Choose the classic equipment around the model or the equipment grid. Both keep your existing appearance settings.",
        get = function() return gridSelected() and "grid" or "classic" end,
        set = function(value) if value == "classic" or value == "grid" then return DUI:Set(ADDON, root .. ".layout", value) end end,
        default = function() return "grid" end,
        disabled = function() return not enabled() end },
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
extras.German["Item level text size"] = "Textgröße der Gegenstandsstufe"
extras.German["The item level on the equipment icons."] = "Die Gegenstandsstufe auf den Ausrüstungssymbolen."
extras.CharacterPanelGroup.items[#extras.CharacterPanelGroup.items + 1] = {
    type = "slider", key = root .. ".itemLevelSize", label = "Item level text size",
    desc = "The item level on the equipment icons.", min = 6, max = 20, step = 1,
    disabled = function() return not enabled() or get("itemLevel") == false end,
}
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
    items[#items + 1] = { type = "dropdown", key = root .. ".qualityGradientStyle", label = "Quality gradient style", blastaSince = "2.2",
        desc = "Automatic uses the cut corner in the equipment grid and the fading gradient in the classic layout.",
        values = { auto = "Automatic", fade = "Fade out", cut = "Cut corner" }, order = { "auto", "fade", "cut" },
        disabled = function() return not enabled() or get("qualityGradient") ~= true end }
end
extras.German["Quality gradient style"] = "Stil des Qualitätsverlaufs"
extras.German["Automatic uses the cut corner in the equipment grid and the fading gradient in the classic layout."] =
    "Automatisch nutzt im Ausrüstungsraster die abgeschrägte Ecke und im klassischen Aufbau den auslaufenden Verlauf."
extras.German["Automatic"] = "Automatisch"
extras.German["Fade out"] = "Auslaufend"
extras.German["Cut corner"] = "Abgeschrägte Ecke"

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
    hooksecurefunc(pageAPI, "PaintFooter", extras.SafeHook("CharacterPanel.PaintFooter", function(current)
        local check = current.foot and current.foot.blastaGearCheck
        if not check then return end
        if current.foot.blastaGrid then
            -- The sets button and gear summary live below the model in the
            -- grid view. Reserve this entire footer for warnings and ammo.
            local ammo = current.foot.ammo
            local text = ammo and ammo:GetText()
            local width = type(text) == "string" and text ~= "" and ammo:GetStringWidth() or 0
            width = readable(width, "number") and width or 0
            check:ClearAllPoints()
            check:SetPoint("LEFT", current.foot, "LEFT", width > 0 and width + 14 or 0, 0)
            check:SetPoint("RIGHT", current.foot, "RIGHT", 0, 0)
        end
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
    end))
end
function paintGradient(slot, item, show, highlighted)
    local gradient = slot.blastaQualityGradient
    local alpha = highlighted and 0.32 or (get("qualityGradientAlpha") or 0.2)
    if not (show or highlighted) or alpha <= 0 or slot:GetWidth() <= slot.size + 8 then
        if gradient then gradient:Hide(); gradient.blastaCorner:Hide() end
        return
    end
    local right = slot.side == "right"
    if not gradient then
        gradient = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
        gradient:SetColorTexture(1, 1, 1, 1)
        -- The lower strip with one corner cut off at the far end. The rest of
        -- the gradient stays square; only that one corner is slanted.
        gradient.blastaCorner = slot:CreateTexture(nil, "BACKGROUND", nil, -1)
        gradient.blastaCorner:SetColorTexture(1, 1, 1, 1)
        slot.blastaQualityGradient = gradient
    end
    local corner = gradient.blastaCorner
    local edge = get("square") ~= false and slot.edge and slot.edge.frame or slot.icon
    local shell = edge ~= slot.icon and slot.edge.shell
    local border = shell and shell.border
    local top = border and border.TOP or edge
    local bottom = border and border.BOTTOM or edge
    local extension = DUI.Pixel.Px(slot, 2)
    -- "fade": the earlier look, fully transparent toward the model with a
    -- slanted end. "cut": square, a faint tint at the end and one cut corner.
    local style = get("qualityGradientStyle")
    local cutStyle = style == "cut" or (style ~= "fade" and refined())
    local cut = cutStyle and DUI.Pixel.Px(slot, 8) or 0
    if gradient.blastaEdge ~= edge or gradient.blastaExtension ~= extension or gradient.blastaCut ~= cut
        or gradient.blastaSide ~= right or gradient.blastaCutStyle ~= cutStyle then
        gradient.blastaCutStyle = cutStyle
        gradient.blastaEdge, gradient.blastaExtension = edge, extension
        gradient.blastaCut, gradient.blastaSide = cut, right
        local overlap = edge ~= slot.icon and extension / 2 or 0
        gradient:ClearAllPoints()
        for vertex = 1, 4 do
            gradient:SetVertexOffset(vertex, 0, 0)
            corner:SetVertexOffset(vertex, 0, 0)
        end
        if right then
            gradient:SetPoint("LEFT", slot, "LEFT", -extension, 0)
            gradient:SetPoint("TOPRIGHT", top, "TOPLEFT", overlap, 0)
            gradient:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMLEFT", overlap, cut)
        else
            gradient:SetPoint("TOPLEFT", top, "TOPRIGHT", -overlap, 0)
            gradient:SetPoint("BOTTOMLEFT", bottom, "BOTTOMRIGHT", -overlap, cut)
            gradient:SetPoint("RIGHT", slot, "RIGHT", extension, 0)
        end
        corner:ClearAllPoints()
        -- Vertex 2 is the lower left, 4 the lower right: pull the far one in.
        if cutStyle then
            corner:SetPoint("TOPLEFT", gradient, "BOTTOMLEFT")
            corner:SetPoint("TOPRIGHT", gradient, "BOTTOMRIGHT")
            corner:SetHeight(cut)
            if right then corner:SetVertexOffset(2, cut, 0)
            else corner:SetVertexOffset(4, -cut, 0) end
        elseif right then gradient:SetVertexOffset(2, 8, 0)
        else gradient:SetVertexOffset(4, -8, 0) end
        gradient.blastaR = nil -- Repaint the colors for the new style.
    end
    local r, g, b
    if highlighted then r, g, b = 1, 0.65, 0.15
    else r, g, b = char.Gear.QualityColor(item.quality) end
    if gradient.blastaR ~= r or gradient.blastaG ~= g or gradient.blastaB ~= b
        or gradient.blastaAlpha ~= alpha or gradient.blastaRight ~= right then
        -- End on a faint tint instead of nothing, so the far edge and its
        -- cut corner stay readable against the window.
        local start, finish = CreateColor(r, g, b, alpha), CreateColor(r, g, b, cutStyle and alpha * 0.4 or 0)
        if right then start, finish = finish, start end
        gradient:SetGradient("HORIZONTAL", start, finish)
        corner:SetGradient("HORIZONTAL", start, finish)
        gradient.blastaR, gradient.blastaG, gradient.blastaB = r, g, b
        gradient.blastaAlpha, gradient.blastaRight = alpha, right
    end
    if not gradient:IsShown() then gradient:Show() end
    corner:SetShown(cutStyle)
end

local ENCHANT_INK = { 1, 0.82, 0.38 }

local function durability(item)
    if get("durability") == false or not item.max or item.max <= 0 then return end
    local percent = math.floor(item.cur * 100 / item.max + 0.5)
    if percent > (get("durabilityThreshold") or 50) and not item.wear then return end
    local color = percent <= 25 and slots.RED or percent <= 50 and slots.AMBER or slots.DIM
    -- The key is only a lookup name; English needs its own readable text.
    local key = "Gear durability short: %d%%"
    local text = tr(key)
    if text == key then text = "Durability %d%%" end
    return text:format(percent), color, percent
end
-- For a grid line that has no room for the full word.
extras.German["Durability abbreviated: %d%%"] = "Haltb. %d%%"
local function shortDurability(percent)
    local key = "Durability abbreviated: %d%%"
    local text = tr(key)
    if text == key then text = "Dur. %d%%" end
    return text:format(percent)
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
        local background = badge:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0.72)
        badge.text = style.Text(badge, 11, "CENTER")
        badge.text:SetPoint("CENTER")
        slot.blastaItemLevel = badge
    end
    local size = math.max(6, math.min(20, tonumber(get("itemLevelSize")) or 11))
    if badge.size ~= size then
        badge.size = size
        style.SetTextSize(badge.text, size)
        badge:SetHeight(size + 2)
    end
    badge.text:SetText(tostring(item.level))
    badge:Show()
end

hooksecurefunc(slots, "Paint", extras.SafeHook("CharacterPanel.Paint", function(slot, item)
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
    if extras.PaintCharacterDurability then
        local wear = on and equipment and durability(item)
        -- Grid with names: the percentage sits in the text line below the
        -- name. Icons only: the dot on the icon is the only room left.
        extras.PaintCharacterDurability(slot, item, refined() and not slot.names and wear ~= nil and wear ~= false,
            char.Setting and char.Setting("repairAt"))
    end
    slot.blastaLine = nil
    if not on or not equipment then
        if refined() and on and not item.empty and not item.ammo then
            slot.line:SetText("")
            slot.lineFull = ""
            if slots.FitText then slots.FitText(slot) end
        end
        return
    end
    slot.corner:SetText("")
    if slot.cornerBg then slot.cornerBg:Hide() end
    local wear, color, percent = durability(item)
    local enchant = get("enchants") ~= false and item.enchant
    local text = enchant or wear or ""
    slot.blastaLine = nil
    if refined() and enchant and wear then
        -- One line in the grid: the enchant, then the colored durability.
        -- Without room, FitText shortens the durability and then the enchant.
        local code = ("|cff%02x%02x%02x"):format(
            math.floor(color[1] * 255 + 0.5), math.floor(color[2] * 255 + 0.5), math.floor(color[3] * 255 + 0.5))
        text = enchant .. "  " .. code .. wear .. "|r"
        slot.blastaLine = { full = text, enchant = enchant, short = code .. shortDurability(percent) .. "|r" }
    end
    slot.line:SetText(text)
    slot.lineFull = text
    -- Enchantments in a soft enchanting gold: apart from the quality-colored
    -- item names and from the durability colors.
    local ink = (enchant and ENCHANT_INK) or color or slots.DIM
    slot.line:SetTextColor(ink[1], ink[2], ink[3])
    slot.dot:SetShown(not refined() and wear ~= nil and item.wear ~= nil)
    if slots.FitText then slots.FitText(slot) end
end))

-- A name a little too long for the room beside its icon: DaylightUI breaks it
-- onto a second line although the space toward the model is free. Such a name
-- keeps one line and reaches up to NAME_REACH further toward the model. Only
-- the two side columns; the weapons below sit next to each other.
local NAME_REACH = 60
if slots.FitText then
    local fitText = slots.FitText
    local function natural(fs)
        local ok, w = pcall(function()
            local v = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth()
            if type(v) ~= "number" then v = fs:GetStringWidth() end
            return v
        end)
        return ok and readable(w, "number") and w or nil
    end
    -- Main hand, off hand and ranged stand side by side under the model.
    local bottom = {}
    for _, key in ipairs(char.Gear.BOTTOM or { "MainHand", "SecondaryHand", "Ranged" }) do bottom[key] = true end
    -- Enchant and durability always stay on one line: the full text if it
    -- fits, else "Dur. 42%", else the enchant cut short with "..." in front of
    -- it (the tooltip keeps the whole enchant). The durability is never cut.
    local CHAR = "[%z\1-\127\194-\244][\128-\191]*"
    local function fitLine(h, ...)
        local line = h.blastaLine
        if not line then return fitText(h, ...) end
        h.line:SetText(line.full)
        local width = h.line:GetWidth()
        local function fits(text)
            h.line:SetText(text)
            local own = natural(h.line)
            return own ~= nil and own <= width + 0.5
        end
        if readable(width, "number") and width > 0 and not fits(line.full) then
            local short = line.enchant .. "  " .. line.short
            if not fits(short) then
                local chars = {}
                for c in line.enchant:gmatch(CHAR) do chars[#chars + 1] = c end
                local lo, hi, best = 1, #chars - 1, nil
                while lo <= hi do
                    local mid = math.floor((lo + hi) / 2)
                    local cut = table.concat(chars, "", 1, mid):gsub("[%s,]+$", "") .. "...  " .. line.short
                    if fits(cut) then best, lo = cut, mid + 1 else hi = mid - 1 end
                end
                h.line:SetText(best or line.short)
            end
        end
        return fitText(h, ...)
    end
    function slots.FitText(h, ...)
        if playerSlots[h] and h.names and h.name and h.px and not bottom[h.key] then
            local width = h:GetWidth()
            if readable(width, "number") then
                local room = math.max(0, width - h.px - (h.gap or slots.GAP or 10))
                local want = natural(h.name)
                local reach = not refined() and want and want > room and want <= room + NAME_REACH and math.ceil(want) + 1 or room
                if math.abs((h.name:GetWidth() or 0) - reach) > 0.5 then h.name:SetWidth(reach) end
            end
        end
        return fitLine(h, ...)
    end
end

local paintEnchant = slots.PaintEnchant
function slots.PaintEnchant(slot, item, ...)
    if playerSlots[slot] and enabled() and not item.empty then
        local enchant = get("enchants") ~= false and item.enchant
        local wear, color = durability(item)
        if refined() then wear = nil end
        local display = {}
        for key, value in pairs(item) do display[key] = value end
        display.enchant = slot.names and enchant and wear or (not slot.names and enchant or nil)
        paintEnchant(slot, display)
        if slot.names and enchant and wear then
            slot.enchant:SetTextColor(color[1], color[2], color[3])
        end
        return
    end
    return paintEnchant(slot, item, ...)
end

hooksecurefunc(pageAPI, "Build", extras.SafeHook("CharacterPanel.Build", function(built)
    page = built
    for _, slot in pairs(page.slots or {}) do
        local shell = slot.edge and slot.edge.shell
        local opts = shell and shell.opts
        playerSlots[slot] = { border = opts and opts.borderPx, corner = opts and opts.cornerPx }
    end
    if checkSupported then buildCheck(page) end
end))

DUI.On("SettingChanged", function(scope, key)
    if scope == ADDON and type(key) == "string" and key:sub(1, #root + 1) == root .. "." and page and page:IsVisible() then
        if key == root .. ".enabled" and pageAPI.Place then pageAPI.Place(page) end
        pageAPI.Refresh(page)
    end
end)

extras.Loaded("CharacterPanel")
