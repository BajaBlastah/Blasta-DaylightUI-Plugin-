local ADDON, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Tooltip")
local Tip = mod and mod.ns and mod.ns.Tooltip
if not (Tip and Tip.OnUpdate and Tip.Line and Tip.ItemLink) then return end

local Style, L = DUI.Style, DUI.L
local font = mod.ns.MEDIA and mod.ns.MEDIA.font
local defaults = mod.defaults
defaults.blastaStyle = "daylight"
defaults.blastaDensity = "standard"
defaults.blastaDetails = true
defaults.blastaDisenchant = true
defaults.blastaCompare = true
defaults.blastaOriginal = "alt"
defaults.blastaPreview = "item"
defaults.blastaIcon = true
defaults.blastaItemIconSize = 36
defaults.blastaSpellIconSize = 30
defaults.blastaTitleSize = 16
defaults.blastaBodySize = 12
defaults.blastaMetaSize = 11
defaults.blastaStatSize = 14
defaults.blastaBonusSize = 14
defaults.blastaEnchantSize = 12
defaults.blastaEffectSize = 12
extras.German["Tooltip stat size"] = "Größe der Grundwerte"
extras.German["Tooltip bonus stat size"] = "Größe der Zusatzwerte (Angriffskraft, Zaubermacht …)"
extras.German["Tooltip enchantment size"] = "Größe der Verzauberungen"
extras.German["Tooltip effect size"] = "Größe sonstiger Effekte"
extras.German["Blasta tooltips"] = "Blasta-Tooltips"
extras.German["Tooltip text sizes"] = "Schriftgrößen im Tooltip"
extras.German["From top to bottom, in the order the lines appear in a tooltip. Click a line in the preview to jump to its size."] = "Von oben nach unten, in der Reihenfolge der Zeilen im Tooltip. Klick in der Vorschau auf eine Zeile, um zu ihrer Größe zu springen."
extras.German["Name"] = "Name"
extras.German["The item, spell or unit name at the top."] = "Der Name ganz oben: Gegenstand, Zauber oder Einheit."
extras.German["Small print"] = "Kleingedrucktes"
extras.German["Item type, binding, item level, the weapon's damage and speed, and the item ID."] = "Gegenstandstyp, Bindung, Gegenstandsstufe, Waffenschaden und Tempo sowie die Gegenstands-ID."
extras.German["Base stats"] = "Grundwerte"
extras.German["Stamina, Intellect, Armor and the other plain stats."] = "Ausdauer, Intelligenz, Rüstung und die anderen einfachen Werte."
extras.German["Bonus stats"] = "Bonuswerte"
extras.German["Attack power, spell power, hit and crit from equip effects."] = "Angriffskraft, Zaubermacht, Treffer- und kritische Trefferchance aus Anlegen-Effekten."
extras.German["Enchantments"] = "Verzauberungen"
extras.German["The enchantment on the item."] = "Die Verzauberung auf dem Gegenstand."
extras.German["Effects and descriptions"] = "Effekte und Beschreibungen"
extras.German["Equip and use effects, and the text of spells and auras."] = "Anlegen- und Benutzen-Effekte sowie die Texte von Zaubern und Auren."
extras.German["Everything else"] = "Übriger Text"
extras.German["Prices, sources, disenchant results and other addons' lines. Damage per second is a little larger."] = "Preise, Quellen, Entzauberungsergebnisse und Zeilen anderer Addons. Schaden pro Sekunde ist etwas größer."
extras.German["Reset text sizes"] = "Schriftgrößen zurücksetzen"
extras.German["Reset"] = "Zurücksetzen"
extras.German["Puts every text size back to Blasta's default."] = "Setzt alle Schriftgrößen auf Blastas Standard zurück."
extras.German["Tooltip icon and header"] = "Symbol und Kopfzeile"
extras.German["Tooltip icon"] = "Symbol"
extras.German["Item"] = "Gegenstand"
extras.German["Item comparison"] = "Vergleich"
extras.German["Your item"] = "Dein Gegenstand"
extras.German["Spell"] = "Zauber"
extras.German["Buff"] = "Buff"
extras.German["Player"] = "Spieler"
extras.German["Enemy"] = "Gegner"
extras.German["Quest"] = "Quest"
extras.German["Recipe"] = "Rezept"
extras.German["Quest item"] = "Questgegenstand"
extras.German["Unit"] = "Einheit"

defaults.blastaGradient = "daylight"
defaults.blastaGradientStrength = 20
defaults.blastaGradientHeight = 70
defaults.blastaGradientColor = { 0.32, 0.58, 0.8 }

local function selected(get) return get("blastaStyle") ~= "blasta" end
local function slider(key, label, min, max, desc)
    return { type = "slider", key = key, label = label, min = min, max = max, step = 1, desc = desc, disabled = selected }
end
local textSizeKeys = { "blastaTitleSize", "blastaMetaSize", "blastaStatSize", "blastaBonusSize",
    "blastaEnchantSize", "blastaEffectSize", "blastaBodySize" }

-- Three cards of their own on DaylightUI's Tooltips page (placed at login,
-- extras.PlaceTooltipCards): the layout, the text sizes in the order they
-- appear in a tooltip, and the icon and header. Each size names the lines it
-- changes, and the live preview above shows them; a click on a line there
-- jumps to its slider.
extras.TooltipCards = {
    { label = "Blasta tooltips", items = {
        { type = "dropdown", key = "blastaStyle", label = "Tooltip style",
            values = { daylight = "Daylight", blasta = "Blasta Tooltips" }, order = { "daylight", "blasta" },
            desc = "Uses Daylight placement. Disable PrettyTooltip to use the Blasta layout." },
        { type = "dropdown", key = "blastaDensity", label = "Tooltip density",
            values = { compact = "Compact", standard = "Standard", detailed = "Detailed" },
            order = { "compact", "standard", "detailed" }, disabled = selected },
        { type = "toggle", key = "blastaDetails", label = "Show tooltip details",
            desc = "Show prices, IDs and supplementary details.", disabled = selected },
        { type = "toggle", key = "blastaDisenchant", label = "Show disenchant results",
            desc = "Show disenchant information added by addons such as DisenchantBuddy or Auctionator.",
            disabled = function(get) return selected(get) or get("blastaDetails") == false end },
        { type = "toggle", key = "blastaCompare", label = "Use Blasta for item comparisons", disabled = selected },
        { type = "dropdown", key = "blastaOriginal", label = "Original tooltip modifier",
            values = { alt = "Alt", shift = "Shift", ctrl = "Ctrl", off = "Off" },
            order = { "alt", "shift", "ctrl", "off" }, disabled = selected },
    } },
    { label = "Tooltip text sizes",
      desc = "From top to bottom, in the order the lines appear in a tooltip. Click a line in the preview to jump to its size.",
      items = {
        slider("blastaTitleSize", "Name", 9, 32, "The item, spell or unit name at the top."),
        slider("blastaMetaSize", "Small print", 8, 24,
            "Item type, binding, item level, the weapon's damage and speed, and the item ID."),
        slider("blastaStatSize", "Base stats", 8, 24, "Stamina, Intellect, Armor and the other plain stats."),
        slider("blastaBonusSize", "Bonus stats", 8, 24, "Attack power, spell power, hit and crit from equip effects."),
        slider("blastaEnchantSize", "Enchantments", 8, 24, "The enchantment on the item."),
        slider("blastaEffectSize", "Effects and descriptions", 8, 24,
            "Equip and use effects, and the text of spells and auras."),
        slider("blastaBodySize", "Everything else", 8, 24,
            "Prices, sources, disenchant results and other addons' lines. Damage per second is a little larger."),
        { type = "button", label = "Reset text sizes", text = "Reset", disabled = selected,
            desc = "Puts every text size back to Blasta's default.",
            func = function()
                for _, key in ipairs(textSizeKeys) do DUI:Set("Tooltip", key, defaults[key]) end
            end },
    } },
    { label = "Tooltip icon and header", items = {
        { type = "toggle", key = "blastaIcon", label = "Show tooltip icon", disabled = selected },
        slider("blastaItemIconSize", "Item icon size", 16, 56),
        slider("blastaSpellIconSize", "Spell and aura icon size", 16, 56),
        { type = "dropdown", key = "blastaGradient", label = "Header gradient",
            values = { daylight = "Daylight", sunrise = "Blasta sunrise", custom = "Custom", off = "Off" },
            order = { "daylight", "sunrise", "custom", "off" }, disabled = selected },
        { type = "color", key = "blastaGradientColor", label = "Header gradient color",
            disabled = function(get) return selected(get) or get("blastaGradient") ~= "custom" end },
        slider("blastaGradientStrength", "Header gradient strength", 0, 100),
        slider("blastaGradientHeight", "Header gradient height", 16, 140),
    } },
}

-- Hands the cards to DaylightUI's Tooltips page for a moment, so they read and save in its settings.
function extras.PlaceTooltipCards()
    local page
    for _, candidate in ipairs(mod.options and mod.options.pages or {}) do
        if candidate.id == "tooltip" then page = candidate end
    end
    if not (page and page.groups) or extras.TooltipCardsPlaced then return end
    extras.TooltipCardsPlaced = true
    local at = #page.groups + 1
    for i, group in ipairs(page.groups) do
        if group.label == "Look" then at = i + 1 end
    end
    -- They go on Blasta's Tooltips page from there (extras.CollectSettings),
    -- with the live preview on top.
    local sample = extras.TooltipSample and function(parent) return extras.TooltipSample(parent) end
    for i, group in ipairs(extras.TooltipCards) do
        group.blastaSample = sample
        table.insert(page.groups, at + i - 1, group)
    end
    return extras.TooltipCards
end

local function config() return mod.db or defaults end
local sampleEnglish = {
    ["Blasta sample spell"] = "Power Word: Shield",
    ["Blasta sample spell description"] = "Absorbs 233 damage for 30 sec. The target cannot be shielded again for 15 sec.",
    ["Blasta sample aura"] = "Inner Fire",
    ["Blasta sample aura duration"] = "Time remaining: 28 min",
    ["Blasta sample aura description"] = "Increases armor.",
    ["Blasta sample quest"] = "War of the Elements",
    ["Blasta sample objective"] = "Collect pyrophores",
    ["Blasta sample player"] = "Baja Blasta",
    ["Blasta sample enemy"] = "Deepmoss Creeper",
    ["Blasta sample player details"] = "Level 25 · Undead · Priest",
    ["Blasta sample enemy details"] = "Level 36 · Elemental",
    ["Blasta sample equipped"] = "Watchkeeper's Blade",
    ["Blasta sample item"] = "Dawnblade",
    ["Blasta sample item type"] = "Sword · One-Hand",
    ["Blasta sample item effect"] = "Equip: Increases spell damage and healing by up to 3.",
    ["Blasta sample dust"] = "Strange Dust",
}
local function sampleText(key)
    local value = extras.Translate(key)
    return value ~= key and value or sampleEnglish[key] or key
end
local function enabled()
    return mod.enabled and config().blastaStyle == "blasta"
        and not (DUI.PrettyAside and DUI.PrettyAside.Draws())
end
local modifiers = { alt = IsAltKeyDown, shift = IsShiftKeyDown, ctrl = IsControlKeyDown }
local function allowed(tip)
    if not enabled() or (tip and tip.IsForbidden and tip:IsForbidden()) then return false end
    local key = modifiers[config().blastaOriginal]
    return not (key and key())
end
local function plain(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

-- Blasta's own full-icon mask. The diagonal removes 14 of its 64 pixels.
local iconCutMask = "Interface\\AddOns\\" .. ADDON .. "\\Media\\TooltipIconCut.tga"
local panelCut, factsCut, iconCut = 16, 8, 16
local function cutIcon(frame, art)
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(iconCutMask, "CLAMP", "CLAMP")
    mask:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT")
    art:AddMaskTexture(mask)
    return mask
end

local function outlineIcon(frame, size, pixel, color)
    if frame.cutSize ~= size or frame.cutPixel ~= pixel then
        frame.cutSize, frame.cutPixel = size, pixel
        local inner = size * iconCut / 14
        -- Both cuts are parallel, one screen pixel apart across the diagonal.
        local outer = inner + pixel * (2 - math.sqrt(2)) * 64 / 14
        frame.cutMask:SetSize(inner, inner)
        frame.borderMask:SetSize(outer, outer)
    end
    frame.border:SetVertexColor(color[1], color[2], color[3], 1)
end

local function newPanel(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:Hide()
    f.rows = {}
    f.rules = {}
    -- The frame of DaylightUI's tooltip cards: square corners, its border,
    -- and the bottom-right corner cut away.
    f.shell = Style.Shell(f, { cornerPx = 0, noBevel = true,
        borderPx = type(Tip.BorderPx) == "function" and Tip.BorderPx or 3,
        bgAlpha = Tip.BackAlpha and Tip.BackAlpha("rich") or 0.92 })
    if Style.CutShell then pcall(Style.CutShell, f, panelCut) end
    f.glow = f.shell:CreateTexture(nil, "BACKGROUND", nil, -6)
    f.glow:SetColorTexture(1, 1, 1, 1)
    -- DaylightUI's top light instead of a colored frame all around.
    f.light = f:CreateTexture(nil, "ARTWORK", nil, 3)
    f.light:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.iconFrame = CreateFrame("Frame", nil, f)
    local border = f.iconFrame:CreateTexture(nil, "BACKGROUND")
    border:SetTexture("Interface\\Buttons\\WHITE8X8")
    border:SetAllPoints(f.iconFrame)
    f.iconFrame.border = border
    f.iconFrame.borderMask = cutIcon(f.iconFrame, border)
    f.icon = f.iconFrame:CreateTexture(nil, "ARTWORK")
    Style.CropIcon(f.icon)
    f.iconFrame.cutMask = cutIcon(f.iconFrame, f.icon)
    f.title = Style.Text(f, 15, "LEFT", font)
    f.rank = Style.Text(f, 15, "RIGHT", font)
    f.rank:SetTextColor(0.67, 0.68, 0.70)
    f.itemLevel = Style.Text(f, 11, "CENTER", font)
    f.itemLevel:SetTextColor(0.72, 0.76, 0.82)
    f.subtitle = Style.Text(f, 11, "LEFT", font)
    f.subtitle:SetTextColor(0.72, 0.76, 0.82)
    f.binding = Style.Text(f, 11, "LEFT", font)
    f.measure = Style.Text(f, 12, "LEFT", font)
    f.measure:Hide()
    f.health = Style.Bar(f)
    f.health:SetMinMaxValues(0, 1)
    return f
end

local densities = { compact = { 275, 9, 3 }, standard = { 330, 13, 5 }, detailed = { 375, 15, 7 } }

local function placeRule(rule, panel, x, y, length)
    local pixel = DUI.Pixel.Px(panel, 1)
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", panel, "TOPLEFT", DUI.Pixel.Snap(panel, x), -DUI.Pixel.Snap(panel, y))
    rule:SetSize(length, pixel)
end

local function divider(panel, index, pad, y, width)
    local rule = panel.rules[index]
    if not rule then
        rule = panel:CreateTexture(nil, "ARTWORK")
        rule:SetColorTexture(0.76, 0.54, 0.28, 0.5)
        panel.rules[index] = rule
    end
    placeRule(rule, panel, pad, y, width)
    rule:Show()
end

local function fontRow(panel, i)
    local row = panel.rows[i]
    if not row then
        row = { left = Style.Text(panel, 12, "LEFT", font), right = Style.Text(panel, 12, "RIGHT", font) }
        panel.rows[i] = row
    end
    return row
end

local function coloredText(text, color)
    return ("|cff%02x%02x%02x%s|r"):format(math.floor(color[1] * 255),
        math.floor(color[2] * 255), math.floor(color[3] * 255), text)
end

local function textWidth(measure, text)
    if not text or text == "" then return 0 end
    measure:SetText(text)
    return measure:GetStringWidth()
end

local germanVowels = {
    a = true, e = true, i = true, o = true, u = true, y = true,
    ["ä"] = true, ["ö"] = true, ["ü"] = true, ["Ä"] = true, ["Ö"] = true, ["Ü"] = true,
}
local function vowel(letter) return germanVowels[letter:lower()] end

-- Normal line wrapping stays with FontString. Split German words only when
-- the whole word would exceed the column. Leave WoW markup intact.
local function hyphenate(text, measure, width, naturalWidth)
    if not text or GetLocale() ~= "deDE" or naturalWidth <= width then return text end
    return (text:gsub("%S+", function(word)
        if #word < 10 or word:find("[|%d]") or textWidth(measure, word) <= width then return word end
        local letters = {}
        for char in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do letters[#letters + 1] = char end
        for i = #letters - 2, 3, -1 do
            if not vowel(letters[i]) and not vowel(letters[i + 1]) then
                local cluster = table.concat(letters, "", math.max(1, i - 2), math.min(#letters, i + 3)):lower()
                if not (cluster:find("sch", 1, true) or cluster:find("ch", 1, true) or cluster:find("ck", 1, true)) then
                    local left = table.concat(letters, "", 1, i) .. "-"
                    if textWidth(measure, left) <= width then
                        return left .. "\n" .. table.concat(letters, "", i + 1)
                    end
                end
            elseif vowel(letters[i]) and not vowel(letters[i + 1]) and vowel(letters[i + 2]) then
                local left = table.concat(letters, "", 1, i) .. "-"
                if textWidth(measure, left) <= width then return left .. "\n" .. table.concat(letters, "", i + 1) end
            end
        end
        return word
    end))
end

local function showRow(cfg, section)
    if section == "disenchant" then return cfg.blastaDetails ~= false and cfg.blastaDisenchant ~= false end
    return cfg.blastaDetails ~= false or (section ~= "footer" and section ~= "price")
end

local function statValue(stat)
    if stat.color then return coloredText(stat.value, stat.color) end
    local tips = DUI.Tips
    local power = stat.cost and tips and tips.PowerIn and tips.PowerIn(stat.value)
    if power and Style.PowerColor then
        return coloredText(stat.value, { Style.PowerColor(power) })
    end
    return stat.value
end

local function factText(stat, item)
    local value = statValue(stat)
    if item then return coloredText(stat.label .. ":", stat.color or { 0.67, 0.68, 0.70 }) .. " " .. value end
    if stat.cooldown then return value .. " " .. coloredText("CD", { 0.67, 0.68, 0.70 }) end
    return value
end

local function renderFacts(panel, cells, pad, y, width, textSize, minimum, item)
    local strip = panel.spellFacts
    if not strip then
        strip = CreateFrame("Frame", nil, panel)
        strip.shell = Style.Shell(strip, {
            borderPx = 1, cornerPx = 0, flat = true, noBevel = true,
            shadowAlpha = 0, bgAlpha = 0.46,
        })
        strip.columns = {}
        panel.spellFacts = strip
    end
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
    strip:SetWidth(width)
    strip:Show()
    local pixel = DUI.Pixel.Px(panel, 1)
    local height, x = textSize + 10, 0
    local spare = math.max(0, width - minimum) / #cells
    local ratio = math.min(1, width / minimum)
    for i, cell in ipairs(cells) do
        local column = strip.columns[i]
        if not column then
            column = CreateFrame("Frame", nil, strip)
            column.value = Style.Text(column, textSize, "CENTER", font)
            column.value:SetWordWrap(false)
            column.value:SetPoint("CENTER", column, "CENTER")
            if i > 1 then
                local rule = column:CreateTexture(nil, "ARTWORK")
                rule:SetColorTexture(0.62, 0.64, 0.68, 0.22)
                rule:SetPoint("TOPLEFT", column, "TOPLEFT", 0, -5)
                rule:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 0, 5)
                column.rule = rule
            end
            strip.columns[i] = column
        end
        local columnWidth = cell.width * ratio + spare
        column:ClearAllPoints()
        column:SetPoint("TOPLEFT", strip, "TOPLEFT", x, 0)
        column:SetWidth(columnWidth)
        column:SetHeight(height)
        x = x + columnWidth
        if column.rule then column.rule:SetWidth(pixel) end
        column:Show()
        Style.SetTextSize(column.value, math.max(8, math.floor(textSize * ratio + 0.5)))
        column.value:SetWidth(math.max(1, columnWidth - 10))
        column.value:SetText(cell.text)
    end
    for i = #cells + 1, #strip.columns do strip.columns[i]:Hide() end
    strip:SetHeight(height)
    if item then
        if not strip.itemBorder then
            strip.itemBorder = strip:CreateTexture(nil, "BACKGROUND")
            strip.itemBorder:SetColorTexture(0.28, 0.29, 0.32, 1)
            strip.itemBorder:SetAllPoints()
            strip.itemBorderMask = cutIcon(strip, strip.itemBorder)
            strip.itemFill = strip:CreateTexture(nil, "BACKGROUND", nil, 1)
            strip.itemFill:SetColorTexture(0.09, 0.09, 0.10, 0.96)
            strip.itemFillMask = cutIcon(strip, strip.itemFill)
        end
        -- Parallel masks keep the diagonal one pixel thick, like the straight edges.
        local cut = math.floor(factsCut / pixel + 0.5) * pixel
        strip.itemBorderMask:SetSize(cut * 64 / 14, cut * 64 / 14)
        local fillCut = (cut - pixel * (2 - math.sqrt(2))) * 64 / 14
        strip.itemFillMask:SetSize(fillCut, fillCut)
        strip.itemFill:ClearAllPoints()
        strip.itemFill:SetPoint("TOPLEFT", strip, "TOPLEFT", pixel, -pixel)
        strip.itemFill:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", -pixel, pixel)
        strip.itemBorder:Show()
        strip.itemFill:Show()
        strip.shell:Hide()
    else
        if strip.itemBorder then
            strip.itemBorder:Hide()
            strip.itemFill:Hide()
        end
        strip.shell:Show()
        Style.SetShellColors(strip.shell, { 0.28, 0.29, 0.32 })
        Style.LayoutShell(strip.shell)
        if Style.CutShell then Style.CutShell(strip, factsCut) end
    end
    return height
end
local function render(panel, model, maxWidth)
    local cfg = config()
    local density = densities[cfg.blastaDensity] or densities.standard
    local limit, pad, gap = math.min(density[1], maxWidth or density[1]), density[2], density[3]
    local r, g, b = unpack(model.color)
    -- The frame as DaylightUI's tooltips have it (its thickness and
    -- background); the color sits only in the light along the top.
    panel.shell.opts.borderPx = type(Tip.BorderPx) == "function" and Tip.BorderPx or (cfg.borderPx or 3)
    panel.shell.opts.bgAlpha = Tip.BackAlpha and Tip.BackAlpha("rich") or math.max(0.75, cfg.bgAlpha or 0.92)
    if not panel.neutral then
        panel.neutral = true
        Style.SetShellColors(panel.shell, nil)
    end
    local light = model.light or { RichItems and RichItems.Lift and RichItems.Lift(model.color) or model.color, model.color }
    do
        local one = DUI.Pixel.Px(panel, 1)
        local lo, hi = light[1], light[2]
        panel.light:ClearAllPoints()
        panel.light:SetPoint("TOPLEFT", panel, "TOPLEFT", one, -one)
        panel.light:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -one, -one)
        panel.light:SetHeight(2)
        panel.light:SetVertexColor(1, 1, 1, 1)
        if Style.Gradient then
            Style.Gradient(panel.light, "HORIZONTAL", lo[1], lo[2], lo[3], 1, hi[1], hi[2], hi[3], 1)
        else
            panel.light:SetGradient("HORIZONTAL", CreateColor(lo[1], lo[2], lo[3], 1), CreateColor(hi[1], hi[2], hi[3], 1))
        end
        panel.light:Show()
    end
    local iconSize = model.icon and cfg.blastaIcon ~= false
        and (model.kind == "Item" and cfg.blastaItemIconSize or cfg.blastaSpellIconSize) or 0
    iconSize = iconSize or 0
    local textSize, metaSize = cfg.blastaBodySize or 12, cfg.blastaMetaSize or 11
    local sizes = { values = cfg.blastaStatSize or 14, bonus = cfg.blastaBonusSize or 14,
        enchant = cfg.blastaEnchantSize or 12, effects = cfg.blastaEffectSize or 12 }
    local function sizeOf(line)
        if line.section == "dps" then return line.small and textSize or textSize + 4 end
        if line.small then return metaSize end
        if line.sizeKind then return sizes[line.sizeKind] or textSize end
        if line.section == "values" then return sizes.values end
        if line.section == "effects" then return sizes.effects end
        return textSize
    end
    local titleSize = cfg.blastaTitleSize or 16
    local facts = model.stats and #model.stats > 0 and model.stats
    local statValueSize = math.max(8, sizes.values - 2)
    local cells, minimum
    local rankSize = model.kind == "Spell" and metaSize or titleSize
    local subtitle, binding = model.schoolLabel or model.subtitle, model.binding
    local level = not model.itemFacts and model.level and (L["iLvl"] .. " " .. model.level)
    local levelUnderIcon = level and iconSize > 0 and ("GS " .. model.level) or nil
    local levelSize = math.max(8, math.min(metaSize, math.floor(iconSize * 0.34)))
    if level and not levelUnderIcon then
        subtitle = subtitle and (subtitle .. " · " .. level) or level
    end
    if model.kind == "Item" and binding then
        subtitle = subtitle and (subtitle .. " · " .. binding) or binding
        binding = nil
    end
    local inlineRequirement
    if model.requirement and not model.requirementInFacts then
        local requirement = coloredText(model.requirement, model.requirementColor or { 0.89, 0.84, 0.73 })
        if model.kind == "Item" and subtitle then
            inlineRequirement = subtitle .. " · " .. requirement
        end
        binding = binding and (binding .. " · " .. requirement) or requirement
    end
    local measure = panel.measure
    local caption = model.rank or (model.equipped and L["Equipped"] or nil)
    Style.SetTextSize(measure, rankSize)
    local rankWidth = caption and textWidth(measure, caption) + 8 or 0
    -- A scaled preview draws its letters a touch wider than measured; its
    -- panels carry some slack so no column wraps early.
    local slack = panel.slack or 0
    local function wide(text)
        local w = textWidth(measure, text)
        return w > 0 and w + slack or 0
    end
    Style.SetTextSize(measure, titleSize)
    local titleWidth = wide(model.title)
    Style.SetTextSize(measure, metaSize)
    local subtitleWidth, bindingWidth = wide(subtitle), wide(binding)
    local inlineWidth = wide(inlineRequirement)
    Style.SetTextSize(measure, levelSize)
    local one = DUI.Pixel.Px(panel, 1)
    local iconFrameSize = iconSize > 0 and (iconSize + 2 * one) or 0
    local iconColumn = math.max(iconFrameSize, wide(levelUnderIcon))
    local lead = iconColumn > 0 and iconColumn + gap + 3 or 0
    local closeRoom = panel.close and 24 or 0
    local content = lead + closeRoom + math.max(titleWidth + rankWidth, subtitleWidth, bindingWidth)
    if facts then
        cells, minimum = {}, 0
        Style.SetTextSize(measure, statValueSize)
        for _, stat in ipairs(facts) do
            local text = factText(stat, model.itemFacts)
            local width = wide(text) + 13
            cells[#cells + 1] = { text = text, width = width }
            minimum = minimum + width
        end
        content = math.max(content, minimum)
    end
    Style.SetTextSize(measure, textSize)
    local measured, disenchantWidth = 0, 0
    for _, line in ipairs(model.lines) do
        if showRow(cfg, line.section) then
            measured = measured + 1
            local row = fontRow(panel, measured)
            Style.SetTextSize(measure, sizeOf(line))
            row.leftWidth = wide(line.text) + (line.bar and 76 or 0)
            row.rightWidth = wide(line.right)
            Style.SetTextSize(measure, textSize)
            row.indent = line.icon and (math.max(12, textSize) + 5) or 0
            local rowWidth = row.leftWidth + row.indent + (line.right and row.rightWidth + 12 or 0)
            if line.columns then rowWidth = 2 * math.max(row.leftWidth, row.rightWidth) + 16 end
            content = math.max(content, rowWidth)
            if line.section == "disenchant" then disenchantWidth = math.max(disenchantWidth, rowWidth) end
        end
    end
    if not maxWidth and disenchantWidth > 0 then
        local screenLimit = UIParent:GetWidth() * 0.8 / math.max(1, panel:GetScale())
        limit = math.max(limit, math.min(screenLimit, math.ceil(disenchantWidth + 2 * pad + 2)))
    end
    local width = math.min(limit, math.max(110, math.ceil(content + 2 * pad + 2)))
    local inner = math.max(1, width - 2 * pad)
    local metaRoom = math.max(1, inner - lead - closeRoom)
    if inlineRequirement and inlineWidth <= metaRoom then
        subtitle, subtitleWidth = inlineRequirement, inlineWidth
        binding, bindingWidth = nil, 0
    end
    panel:SetWidth(width)
    Style.SetTextSize(panel.title, titleSize)
    Style.SetTextSize(panel.rank, rankSize)
    Style.SetTextSize(panel.subtitle, metaSize)
    Style.SetTextSize(panel.binding, metaSize)
    panel.iconFrame:SetShown(iconSize > 0)
    if iconSize > 0 then
        panel.iconFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -pad)
        panel.iconFrame:SetSize(iconFrameSize, iconFrameSize)
        panel.icon:SetPoint("TOPLEFT", panel.iconFrame, "TOPLEFT", one, -one)
        panel.icon:SetSize(iconSize, iconSize)
        if model.unit then SetPortraitTexture(panel.icon, model.unit) else panel.icon:SetTexture(model.icon) end
        outlineIcon(panel.iconFrame, iconSize, one,
            model.kind == "Item" and (model.iconColor or model.color) or { 0.32, 0.33, 0.36 })
    end
    -- The quality frame runs around the icon alone. The level sits on a dark
    -- band hanging right under it, in a black frame of its own whose top is
    -- the icon frame's bottom line.
    local levelHeight = levelUnderIcon and levelSize + 4 or 0
    Style.SetTextSize(panel.itemLevel, levelSize)
    panel.itemLevel:ClearAllPoints()
    panel.itemLevel:SetPoint("TOP", panel.icon, "BOTTOM", 0, -2)
    panel.itemLevel:SetTextColor(unpack(model.levelColor or model.color))
    panel.itemLevel:SetText(levelUnderIcon)
    panel.itemLevel:SetShown(levelUnderIcon ~= nil)
    panel.title:ClearAllPoints()
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + lead, -pad)
    panel.rank:ClearAllPoints()
    if panel.close then
        panel.close:ClearAllPoints()
        panel.close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -pad)
    end
    if model.kind == "Spell" then
        panel.rank:SetPoint("RIGHT", panel.title, "RIGHT", rankWidth, 0)
    else
        panel.rank:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad - closeRoom, -pad)
    end
    panel.rank:SetText(caption)
    panel.rank:SetShown(caption ~= nil)
    local titleRoom = math.max(1, inner - lead - rankWidth - closeRoom)
    panel.title:SetWidth(titleRoom)
    local titleInk = model.titleColor or model.color
    panel.title:SetTextColor(titleInk[1], titleInk[2], titleInk[3])
    Style.SetTextSize(measure, titleSize)
    panel.title:SetText(hyphenate(model.title, measure, titleRoom, titleWidth))
    Style.SetTextSize(measure, metaSize)
    panel.subtitle:ClearAllPoints()
    panel.subtitle:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -3)
    panel.subtitle:SetWidth(metaRoom)
    local labelInk = model.schoolColor
    if labelInk then panel.subtitle:SetTextColor(unpack(labelInk))
    else panel.subtitle:SetTextColor(0.72, 0.76, 0.82) end
    panel.subtitle:SetText(hyphenate(subtitle, measure, metaRoom, subtitleWidth))
    panel.binding:ClearAllPoints()
    panel.binding:SetPoint("TOPLEFT", subtitle and panel.subtitle or panel.title, "BOTTOMLEFT", 0, -2)
    panel.binding:SetWidth(metaRoom)
    panel.binding:SetText(hyphenate(binding, measure, metaRoom, bindingWidth))
    local header = panel.title:GetStringHeight() + (subtitle and panel.subtitle:GetStringHeight() + 2 or 0)
        + (binding and panel.binding:GetStringHeight() + 2 or 0)
    local iconHeight = iconFrameSize + (levelUnderIcon and levelHeight + one or 0)
    local y = pad + math.max(iconHeight, header) + gap
    local mode = cfg.blastaGradient or "daylight"
    local strength = (cfg.blastaGradientStrength or 20) / 100
    panel.glow:SetShown(mode ~= "off" and strength > 0)
    if mode ~= "off" and strength > 0 then
        local inset = DUI.Pixel.Px(panel, Style.BorderPx(panel))
        local color = mode == "custom" and cfg.blastaGradientColor
            or mode == "sunrise" and { 0.95, 0.53, 0.23 } or { r, g, b }
        panel.glow:ClearAllPoints()
        panel.glow:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
        panel.glow:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -inset)
        panel.glow:SetGradient("VERTICAL", CreateColor(color[1], color[2], color[3], 0),
            CreateColor(color[1], color[2], color[3], strength))
    end
    local rules = 0
    if facts then
        y = y + renderFacts(panel, cells, pad, y, inner, statValueSize, minimum, model.itemFacts) + gap + 3
    else
        if panel.spellFacts then panel.spellFacts:Hide() end
        rules = 1
        divider(panel, rules, pad, y, inner)
        y = y + gap + 3
    end
    local used, section = 0, nil
    for _, line in ipairs(model.lines) do
        if line.always or showRow(cfg, line.section) then
            if section and line.section ~= section and not (section == "dps" and line.section == "values") then
                y = y + gap
                rules = rules + 1
                divider(panel, rules, pad, y, inner)
                y = y + gap + 3
            end
            section = line.section
            used = used + 1
            local row = fontRow(panel, used)
            -- Kept for the options preview, which maps each line to its size.
            panel.shownLines = panel.shownLines or {}
            panel.shownLines[used] = line
            local left, right = row.left, row.right
            Style.SetTextSize(left, sizeOf(line))
            Style.SetTextSize(right, sizeOf(line))
            left:ClearAllPoints()
            right:ClearAllPoints()
            left:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
            right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -pad, -y)
            local rightRoom = 0
            if line.right then
                local available = math.max(1, inner - row.indent - 8)
                local leftNeeded, rightNeeded = row.leftWidth + 2, row.rightWidth + 2
                rightRoom = math.min(rightNeeded, available * 0.55)
                if line.section == "disenchant" then
                    rightRoom = math.min(rightNeeded, available * rightNeeded / (leftNeeded + rightNeeded))
                end
            end
            local leftRoom = math.max(1, inner - row.indent - (line.right and rightRoom + 8 or 0))
            if line.columns then
                -- Stat changes in two columns: gains left, losses from the middle.
                local half = math.max(1, (inner - 12) / 2)
                leftRoom, rightRoom = half, half
                right:ClearAllPoints()
                right:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + half + 12, -y)
                right:SetJustifyH("LEFT")
            else
                right:SetJustifyH("RIGHT")
            end
            right:SetWidth(math.max(1, rightRoom))
            left:SetWidth(leftRoom)
            left:SetTextColor(unpack(line.color))
            right:SetTextColor(unpack(line.rightColor or line.color))
            Style.SetTextSize(measure, sizeOf(line))
            if line.bar then
                -- Durability: a short bar with the numbers after it.
                if not row.barBack then
                    row.barBack = panel:CreateTexture(nil, "ARTWORK")
                    row.barFill = panel:CreateTexture(nil, "ARTWORK", nil, 1)
                end
                local fraction = math.max(0, math.min(1, line.bar))
                local ink = fraction > 0.5 and { 0.45, 0.85, 0.45 } or fraction > 0.25 and { 1, 0.75, 0.25 } or { 1, 0.35, 0.3 }
                row.barBack:SetColorTexture(1, 1, 1, 0.12)
                row.barFill:SetColorTexture(ink[1], ink[2], ink[3], 1)
                row.barBack:ClearAllPoints()
                row.barBack:SetPoint("LEFT", panel, "TOPLEFT", pad, -y - math.max(6, textSize / 2 + 1))
                row.barBack:SetSize(68, 4)
                row.barFill:ClearAllPoints()
                row.barFill:SetPoint("LEFT", row.barBack, "LEFT")
                row.barFill:SetSize(math.max(1, 68 * fraction), 4)
                row.barBack:Show(); row.barFill:Show()
                left:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + 76, -y)
                leftRoom = math.max(1, leftRoom - 76)
                left:SetWidth(leftRoom)
            elseif row.barBack then
                row.barBack:Hide(); row.barFill:Hide()
            end
            left:SetText(hyphenate(line.text, measure, leftRoom, row.leftWidth))
            right:SetText(hyphenate(line.right, measure, rightRoom, row.rightWidth))
            Style.SetTextSize(measure, textSize)
            if line.icon then
                if not row.icon then
                    row.icon = CreateFrame("Frame", nil, panel)
                    row.icon.art = row.icon:CreateTexture(nil, "ARTWORK")
                    row.icon.art:SetAllPoints(row.icon)
                    cutIcon(row.icon, row.icon.art)
                end
                local size = math.max(12, textSize)
                row.icon:ClearAllPoints()
                row.icon:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
                row.icon:SetSize(size, size)
                row.icon.art:SetTexture(line.icon)
                row.icon:Show()
                left:ClearAllPoints()
                left:SetPoint("TOPLEFT", panel, "TOPLEFT", pad + size + 5, -y)
            elseif row.icon then row.icon:Hide() end
            left:Show()
            right:SetShown(line.right ~= nil)
            y = y + math.max(left:GetStringHeight(), line.right and right:GetStringHeight() or 0, 12) + gap
        end
    end
    if panel.shownLines then for i = #panel.shownLines, used + 1, -1 do panel.shownLines[i] = nil end end
    for i = used + 1, #panel.rows do
        panel.rows[i].left:Hide()
        panel.rows[i].right:Hide()
        if panel.rows[i].icon then panel.rows[i].icon:Hide() end
    end
    panel.health:SetShown(model.health ~= nil)
    if model.health then
        panel.health:ClearAllPoints()
        panel.health:SetPoint("TOPLEFT", panel, "TOPLEFT", pad, -y)
        panel.health:SetSize(inner, 4)
        Style.SetBarColor(panel.health, r, g, b)
        panel.health:SetValue(model.health)
        y = y + 4 + gap
    end
    for i = rules + 1, #panel.rules do panel.rules[i]:Hide() end
    if panel.glow:IsShown() then panel.glow:SetHeight(math.min(cfg.blastaGradientHeight or 70, y)) end
    panel:SetHeight(y + pad)
    Style.LayoutShell(panel.shell)
    -- DaylightUI's cut bottom-right corner (its cards cut 12). Applied once the
    -- card has a size and its frame pieces exist; at creation they don't yet.
    if Style.CutShell then pcall(Style.CutShell, panel, panelCut) end
    panel:Show()
end

local function line(text, section, color, right)
    return { text = text, section = section, color = color or { 0.88, 0.90, 0.93 }, right = right }
end
local types = Enum and Enum.TooltipDataType or {}
local kinds = {}
for key, label in pairs({ Item = "Item", Spell = "Spell", UnitAura = "Aura", UnitBuff = "Buff", UnitDebuff = "Debuff",
    Unit = "Unit", Quest = "Quest", QuestPartyProgress = "Quest" }) do
    if types[key] ~= nil then kinds[types[key]] = label end
end
kinds.blastaQuest = "Quest"

local function readLine(tip, i, right, source)
    local fs = Tip.Line(tip, i, right and "Right" or "Left")
    if not fs then return nil end
    if fs.IsShown and plain(fs:IsShown()) == false then return nil end
    local raw = fs:GetText()
    local text = plain(raw)
    if issecretvalue and issecretvalue(raw) then
        text = source and plain(source[right and "rightText" or "leftText"])
        if type(text) ~= "string" then return nil, nil, true end
    end
    local r, g, b = fs:GetTextColor()
    if type(text) == "string" and text:match("%S") then
        return text, (plain(r) and plain(g) and plain(b)) and { r, g, b } or { 0.88, 0.90, 0.93 }
    end
end

local function comparisonFrames(tip)
    if tip == ShoppingTooltip1 or tip == ShoppingTooltip2 then
        return GameTooltip, ShoppingTooltip1, ShoppingTooltip2
    elseif tip == ItemRefShoppingTooltip1 or tip == ItemRefShoppingTooltip2 then
        return ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2
    end
end

local function restrictionInk(label, left, leftInk, right, rightInk)
    if label == "" then return end
    if left == label and leftInk and leftInk[1] > 0.7 and leftInk[2] < 0.45 and leftInk[3] < 0.45 then
        return leftInk
    end
    if right == label and rightInk and rightInk[1] > 0.7 and rightInk[2] < 0.45 and rightInk[3] < 0.45 then
        return rightInk
    end
end

local function wearableItem(slot, class)
    return (class == 2 or class == 4) and type(slot) == "string" and slot:match("^INVTYPE_")
        and not slot:match("^INVTYPE_NON_EQUIP") and not slot:match("^INVTYPE_PROFESSION")
end

local function itemHeader(tip, data)
    local link = plain(Tip.ItemLink(tip, data))
    local id = type(link) == "string" and tonumber(link:match("item:(%d+)")) or plain(data.id)
    local item = link or (type(id) == "number" and id)
    if not item or not C_Item or not C_Item.GetItemInfo then return nil end
    local _, _, quality, level, minLevel, category, subtype, maxStack, slot, icon, price, class, subclass = C_Item.GetItemInfo(item)
    slot, class = plain(slot), plain(class)
    local wearable = wearableItem(slot, class)
    local title = wearable and plain(_G[slot]) or nil
    local detail = plain(subtype) or plain(category)
    local actualLevel = link and Tip.ItemLevel and plain(Tip.ItemLevel(link)) or plain(level)
    return plain(icon), detail, plain(price), actualLevel, title, plain(quality), item, plain(maxStack),
        plain(minLevel), class, plain(subclass), wearable, slot
end

local statOrder = { { 2, "Cast" }, { 1, "Cost" }, { 4, "Range" }, { 3, "Cooldown" } }
local function cleanText(text)
    return text and text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\194\160", " ")
        :gsub("%s+", " "):match("^%s*(.-)%s*$")
end

local function itemTooltipRowKey(left)
    -- RestedXP prefixes its first guide with a heading in the same font string.
    -- Compare the guide itself so a later bare copy shares the same key.
    local guide = left:match("^Item used in guide:%s+(.+)$")
        or left:match("^指南中使用的物品：%s+(.+)$")
    if guide and guide:match("^|TInterface/GossipFrame/ActiveQuestIcon:0|t") then return guide end
    return left
end

local function matchText(text)
    return (cleanText(text) or ""):lower()
end

local function requiredLevel(model, minLevel)
    if model.requirement then
        return tonumber((cleanText(model.requirement) or ""):match("(%d+)%s*$"))
    end
    if type(minLevel) == "number" and minLevel > 0 then return minLevel end
end

local function equipmentFacts(model, subtype, slot, slotText, minLevel, class, subclass, slotKey)
    if not (slot and type(subtype) == "string" and subtype ~= "") then return end
    local german = extras.Language == "deDE"
    if slotKey == "INVTYPE_FINGER" or slotKey == "INVTYPE_TRINKET" then
        subtype = german and "Schmuck" or "Jewelry"
    end
    local armor = class == 4 and type(subclass) == "number" and subclass >= 1 and subclass <= 4
    local facts = { { value = subtype, color = model.itemTypeColor,
        label = armor and (german and "RK" or "AC") or (german and "TYP" or "TYPE") } }
    if type(model.level) == "number" and model.level > 0 then
        facts[#facts + 1] = { value = tostring(model.level), label = "GS", color = model.levelColor or model.color }
    end
    local required = requiredLevel(model, minLevel)
    if required then
        facts[#facts + 1] = { value = tostring(required), label = "LVL", color = model.requirementColor }
    end
    if #facts < 2 then return end
    model.stats, model.itemFacts = facts, true
    model.requirementInFacts = required ~= nil
    model.subtitle = matchText(slot) ~= matchText(subtype) and slotText or nil
end

local function hasAveragePrefix(text)
    local visible = cleanText(text) or ""
    return visible:sub(1, 2) == "Ø" or visible:sub(1, 2) == "ø"
end

local function disenchantHeading(text)
    local heading = text:gsub("%s*:%s*$", "")
    return heading == "disenchant results" or heading == "disenchanting results" or heading == "disenchantment results"
        or heading == "entzauberungsergebnisse" or heading == "disenchanted from" or heading == "entzaubert von"
end

local function priceDisenchantResults(rows, auctionAPI)
    local daylightPrices = DUI.AuctionPrices
    local lookup = C_Item and C_Item.GetItemInfoInstant
    if not (lookup and DUI.MoneyString) then return end

    local total, outcomes, missing = 0, 0, false
    for _, row in ipairs(rows) do
        -- DisenchantBuddy uses a material icon and a chance with a quantity.
        local name = cleanText(row.text):match("^|T.-|t%s+(.+)$")
        local right = row.right and cleanText(row.right):gsub("–", "-") or ""
        local chance, low, high = right:match("^(%d+[.,]?%d*)%%%s*%((%d+)%s*%-%s*(%d+)")
        if not chance then chance, low = right:match("^(%d+[.,]?%d*)%%%s*%((%d+)") end
        if name and chance then
            outcomes = outcomes + 1
            local id = plain(lookup(name))
            local price
            if type(id) == "number" then
                if auctionAPI and auctionAPI.GetAuctionPriceByItemID then
                    local ok, value = pcall(auctionAPI.GetAuctionPriceByItemID, "DaylightUI_Blasta", id)
                    price = ok and plain(value) or nil
                end
                if not (type(price) == "number" and price > 0) and daylightPrices and daylightPrices.Item then
                    price = plain(daylightPrices.Item(id))
                end
            end
            if type(price) == "number" and price > 0 then
                total = total + tonumber((chance:gsub(",", "."))) / 100 * (tonumber(low) + tonumber(high or low)) / 2 * price
                if not right:find("|T", 1, true) and not right:find("|A", 1, true) then
                    row.right = row.right .. " · " .. DUI.MoneyString(price)
                end
            else
                missing = true
            end
        end
    end
    if outcomes > 0 and not missing then return math.floor(total + 0.5), false end
    if total > 0 then return math.floor(total), true end
    return nil, missing
end

local function auctionLabels()
    local labels = {}
    for _, key in ipairs({ "VENDOR", "AUCTION", "AUCTION_MEAN", "AUCTION_AGE", "DISENCHANT", "PROSPECT", "MILL" }) do
        local label = _G["AUCTIONATOR_L_" .. key]
        if type(label) == "string" and label ~= "" then labels[key] = matchText(label) end
    end
    return labels
end

local function auctionRow(text, labels)
    for key, label in pairs(labels) do
        if text == label or text == label .. ":" or (text:sub(1, #label + 2) == label .. " x"
            and text:sub(#label + 3):match("^%d")) then
            return key
        end
    end
end

-- DaylightUI adds its market quote and freshness hint to the source tooltip.
local function daylightAuctionRow(text, right, native)
    if text:match("^seen .+ ago") or text:match("^zuletzt gesehen") or text:match("^shift: the whole stack")
        or text:match("^umschalt: gesamter stapel") or matchText(right) == "the whole stack"
        or matchText(right) == "gesamter stapel" then
        return "hint"
    end
    if not right then return end
    local quote = native and native.L and matchText(native.L["Auction"])
    if text == quote or text == "auction" or text == "auction:" or text == "auktionspreis" or text == "auktionspreis:" then
        return "quote"
    end
    local usual = native and native.L and matchText(native.L["Usual"])
    if usual and usual ~= "" then
        local sample = native.L["Usual, stack of %d"]
        local prefix = type(sample) == "string" and matchText(sample):match("^(.-)%%d")
        if text == usual or (prefix and prefix ~= "" and text:sub(1, #prefix) == prefix) then return "usual" end
    end
end

local function bagPriceCount(tip, item, maxStack)
    if tip ~= GameTooltip or not item then return end
    local info = plain(tip.processingInfo) or plain(tip.info)
    if type(info) ~= "table" and tip.GetPrimaryTooltipInfo then info = plain(tip:GetPrimaryTooltipInfo()) end
    if type(info) ~= "table" or plain(info.getterName) ~= "GetBagItem" then return end
    local args = plain(info.getterArgs)
    local bag = type(args) == "table" and plain(args[1])
    local inv = Constants and Constants.InventoryConstants or {}
    local last = (inv.NumBagSlots or NUM_BAG_SLOTS or 4) + (inv.NumReagentBagSlots or 0)
    local keyring = KEYRING_CONTAINER
    if type(bag) ~= "number" or ((bag < 0 or bag > last) and bag ~= keyring) then return end
    if not IsShiftKeyDown() then return 1 end
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
    local link = type(item) == "string" and item:match("item:[^|]+")
    local id = link and tonumber(link:match("^item:(%d+)")) or item
    if type(id) ~= "number" then return end
    local matchID = not link or (type(maxStack) == "number" and maxStack > 1)
    local total = 0
    local function addContainer(container)
        local slots = plain(C_Container.GetContainerNumSlots(container))
        for slot = 1, type(slots) == "number" and slots or 0 do
            local row = plain(C_Container.GetContainerItemInfo(container, slot))
            if type(row) == "table" and plain(row.itemID) == id then
                local other, count = plain(row.hyperlink), plain(row.stackCount)
                if type(count) == "number" and (matchID or (type(other) == "string" and other:match("item:[^|]+") == link)) then
                    total = total + count
                end
            end
        end
    end
    for container = 0, last do addContainer(container) end
    if keyring and keyring < 0 then addContainer(keyring) end
    return total > 0 and total or nil
end

local bulletGlyphs = { "•", "·", "▪", "▫", "■", "□", "◆", "◇", "◦", "●", "○", "‣" }
local function stripBullet(text)
    local visible = cleanText(text)
    if not visible then return text end
    for _, glyph in ipairs(bulletGlyphs) do
        if visible:sub(1, #glyph) == glyph then
            local pos = text:find(glyph, 1, true)
            return text:sub(1, pos - 1) .. text:sub(pos + #glyph):gsub("^%s+", "")
        end
    end
    return text
end

local function unitHeaderContains(text, header)
    local rest = matchText(text)
    if rest == "" then return false end
    for _, value in ipairs(header) do
        local field = matchText(value):gsub("(%W)", "%%%1")
        if field ~= "" then rest = rest:gsub("%f[%w]" .. field .. "%f[%W]", " ") end
    end
    rest = rest:gsub("%(spieler%)", ""):gsub("%(player%)", "")
    return not rest:gsub("·", ""):match("[^%s,%-]")
end

local function isRank(text)
    local lower = matchText(text)
    return lower:match("^rang %d+$") or lower:match("^rank %d+$")
end

local function isLevelRequirement(text)
    local lower = matchText(text)
    return lower:match("^requires level %d+$") or lower:match("^benötigt stufe %d+$") or lower:match("^erfordert stufe %d+$")
end

local function spellStat(text)
    local lower = text:lower():match("^%s*(.-)%s*$")
    if lower:match("^%d[%d,. ]*%s+mana$") or lower:match("^%d[%d,. ]*%s+[%a]+$")
        and (lower:find("rage", 1, true) or lower:find("wut", 1, true) or lower:find("energ", 1, true)) then return 1 end
    if lower:match("^zauberzeit:") or lower:match("^wirkzeit:") or lower:match("^%d.* cast time$")
        or lower:match("^%d[%d,.]*%s+sec cast$") or lower:match("^%d[%d,.]*%s+min cast$")
        or lower:match("^wirken in %d[%d,.]*%s+sek%.?$")
        or lower == "instant" or lower == "instant cast" or lower == "sofort" or lower == "spontan"
        or lower == "wirken: sofort" then return 2 end
    if lower:match("^abklingzeit:") or lower:match("^%d.* cooldown$") or lower:match("^%d.* abklingzeit$") then return 3 end
    if lower:match("^reichweite:") or lower:match("^%d.* reichweite$") or lower:match("^%d.* yd range$")
        or lower:match("^%d+ yd$") or lower:match("^%d+ m$") or lower == "melee range" or lower == "nahkampfreichweite" then return 4 end
end

local function recordSpellStat(stats, text)
    text = cleanText(text)
    local lower = text and text:lower()
    if lower and (lower:find("global cooldown", 1, true) or lower:find("globale abklingzeit", 1, true)
        or lower:find("globalen abklingzeit", 1, true)) then return true end
    if lower == "kanalisiert" or lower == "channeled" or lower == "channelled" then
        stats[2] = text
        return true
    end
    local index = text and spellStat(text)
    if index then
        stats[index] = stats[index] or text:gsub("^Reichweite: ", ""):gsub(" Reichweite$", ""):gsub(" range$", "")
            :gsub(" cast time$", ""):gsub(" cast$", ""):gsub("^Zauberzeit: ", ""):gsub("^Wirkzeit: ", "")
            :gsub("^[Ww]irken in ", "")
            :gsub(" cooldown$", ""):gsub("^Abklingzeit: ", ""):gsub(" Abklingzeit$", "")
        return true
    end
end

local function fillSpellStats(stats, id)
    if type(id) ~= "number" then return end
    local seconds = GetLocale() == "deDE" and "Sek." or "sec"
    local distance = GetLocale() == "deDE" and "m" or "yd"
    local info = C_Spell and C_Spell.GetSpellInfo and plain(C_Spell.GetSpellInfo(id))
    if info then
        local cast = plain(info.castTime)
        if not stats[2] and type(cast) == "number" then
            local duration = ("%g %s"):format(cast / 1000, seconds)
            if seconds == "Sek." then duration = duration:gsub("(%d)%.(%d)", "%1,%2") end
            stats[2] = cast == 0 and L["Instant cast"] or duration
        end
        local range = plain(info.maxRange)
        if not stats[4] and type(range) == "number" and range > 0 then
            stats[4] = ("%g %s"):format(range, distance)
        end
    end
    if GetSpellBaseCooldown then
        local cooldown, gcd = GetSpellBaseCooldown(id)
        cooldown, gcd = plain(cooldown), plain(gcd)
        if type(cooldown) == "number" and cooldown > 0 and not stats[3] then
            stats[3] = ("%g %s"):format(cooldown / 1000, seconds)
        elseif cooldown == 0 and type(gcd) == "number" and gcd > 0 and stats[3] then
            local duration, unit = stats[3]:lower():match("^%s*(%d+[.,]?%d*)%s+(%S+)%s*$")
            if (unit == "sec" or unit == "sek." or unit == "sek" or unit == "s")
                and tonumber((duration:gsub(",", "."))) == gcd / 1000 then stats[3] = nil end
        end
    end
end


-- Equip effects the client still writes out in full become short values. A
-- condition (against Beasts, in Cat Form...) always stays, dimmed, after the
-- value; such values are never merged with plain ones. Unknown effects keep
-- their text without the "Equip:" prefix. Shift shows the original text.
local SPELL, HEAL, ATTACK, MANA, PLAIN = { 0.74, 0.56, 1 }, { 0.45, 0.95, 0.5 }, { 1, 0.66, 0.35 }, { 0.45, 0.7, 1 }, { 0.88, 0.90, 0.93 }
local DIM = { 0.62, 0.64, 0.68 }
local EFFECTS = {
    { "^increases damage and healing done by magical spells and effects by up to (%d+)", "+%s Spell Power", SPELL },
    { "^increases healing done by spells and effects by up to (%d+)", "+%s Healing", HEAL },
    { "^increases damage done to (.-) by magical spells and effects by up to (%d+)", "+%2 Spell Damage", SPELL, "against %1" },
    { "^increases damage done by (%a+) spells and effects by up to (%d+)", "+%2 %1 Damage", SPELL },
    { "^%+(%d+) attack power when fighting (.-)%.?$", "+%1 Attack Power", ATTACK, "against %2" },
    { "^increases your attack power by (%d+) in (.-) forms? only", "+%1 Attack Power", ATTACK, "only in %2 forms" },
    { "^%+(%d+) attack power%.?$", "+%s Attack Power", ATTACK },
    { "^%+(%d+) ranged attack power%.?$", "+%s Ranged Attack Power", ATTACK },
    { "^improves your chance to get a critical strike with spells by (%d+)%%", "+%s%% Spell Crit", SPELL },
    { "^improves your chance to hit with spells by (%d+)%%", "+%s%% Spell Hit", SPELL },
    { "^improves your chance to get a critical strike by (%d+)%%", "+%s%% Crit", PLAIN },
    { "^improves your chance to hit by (%d+)%%", "+%s%% Hit", PLAIN },
    { "^restores (%d+) mana per 5 sec", "+%s Mana per 5 sec.", MANA },
    { "^increased defense %+(%d+)", "+%s Defense", PLAIN },
    { "^erhöht durch sämtliche zauber und magische effekte verursachten schaden und heilung um bis zu (%d+)", "+%s Zaubermacht", SPELL },
    { "^erhöht durch zauber und effekte verursachte heilung um bis zu (%d+)", "+%s Heilung", HEAL },
    { "^erhöht den durch magische zauber und effekte verursachten schaden gegen (.-) um bis zu (%d+)", "+%2 Zauberschaden", SPELL, "gegen %1" },
    { "^erhöht durch (%a+)zauber und %a+effekte zugefügten schaden um bis zu (%d+)", "+%2 %1schaden", SPELL },
    { "^%+(%d+) angriffskraft im kampf gegen (.-)%.?$", "+%1 Angriffskraft", ATTACK, "gegen %2" },
    { "^%+(%d+) angriffskraft nur in (.-)%.?$", "+%1 Angriffskraft", ATTACK, "nur in %2" },
    { "^%+(%d+) angriffskraft%.?$", "+%s Angriffskraft", ATTACK },
    { "^%+(%d+) distanzangriffskraft%.?$", "+%s Distanzangriffskraft", ATTACK },
    { "^erhöht eure chance, einen kritischen treffer durch zauber zu erzielen, um (%d+)%%", "+%s%% kritische Zaubertreffer", SPELL },
    { "^verbessert eure chance, einen kritischen treffer zu erzielen, um (%d+)%%", "+%s%% kritische Treffer", PLAIN },
    { "^verbessert eure trefferchance um (%d+)%%", "+%s%% Trefferchance", PLAIN },
    { "^stellt alle 5 sek%. (%d+) punkt%(e%) mana wieder her", "+%s Mana alle 5 Sek.", MANA },
    { "^erhöht verteidigung um (%d+)", "+%s Verteidigung", PLAIN },
    { "^verteidigung %+(%d+)", "+%s Verteidigung", PLAIN },
}

-- "%1"/"%2" refer to captures; "%s" to the only one. Captured words keep the
-- original letters (same byte positions: Lua lowers ASCII only).
local function fill(template, original, lower, captures)
    if not template then return nil end
    return (template:gsub("%%(%d)", function(n)
        local value = captures[tonumber(n)]
        if not value then return "" end
        local first = lower:find(value, 1, true)
        local word = first and original:sub(first, first + #value - 1) or value
        if word:match("^%l") and not word:match("^%d") then word = word:gsub("^%l", string.upper) end
        return word
    end):gsub("%%s", function() return captures[1] or "" end):gsub("%%%%", "%%"))
end

-- The magic school an effect names ("Schattenzauber", "-schaden", "Shadow
-- spells"), wherever the wording puts it: German clients word these lines in
-- several ways, not always "durch Schattenzauber". Returns the word as the
-- tooltip should show it, or nil for no single school.
local SCHOOLS = {
    { de = "schatten", en = "shadow", German = "Schatten", English = "Shadow" },
    { de = "feuer", en = "fire", German = "Feuer", English = "Fire" },
    { de = "frost", en = "frost", German = "Frost", English = "Frost" },
    { de = "natur", en = "nature", German = "Natur", English = "Nature" },
    { de = "arkan", en = "arcane", German = "Arkan", English = "Arcane" },
    { de = "heilig", en = "holy", German = "Heilig", English = "Holy" },
}
local function schoolOf(lower, german)
    local found
    for _, s in ipairs(SCHOOLS) do
        local hit
        if german then
            hit = lower:find(s.de .. "zauber", 1, true) or lower:find(s.de .. "schaden", 1, true)
                or lower:find(s.de .. "effekt", 1, true) or lower:find(s.de .. "magie", 1, true)
        else
            hit = lower:find(s.en .. " spells", 1, true) or lower:find(s.en .. " damage", 1, true)
        end
        if hit then
            if found and found ~= s then return nil end -- two schools: no single one
            found = s
        end
    end
    return found and (german and found.German or found.English) or nil
end
local function schoolDamage(amount, school, german)
    return "+" .. amount .. " " .. school .. (german and "schaden" or " Damage")
end

-- Every "by up to N" of an effect with the kind of the clause before it:
-- healing items name healing and damage separately ("healing by up to 8 and
-- damage by up to 3"), which is not spell power.
local function amounts(lower)
    local list, from = {}, 1
    while true do
        local s, e, n = lower:find("um bis zu (%d+)", from)
        if not s then s, e, n = lower:find("by up to (%d+)", from) end
        if not s then break end
        local clause = lower:sub(from, s)
        list[#list + 1] = {
            n = n,
            heal = clause:find("heilung", 1, true) or clause:find("healing", 1, true),
            hurt = clause:find("schaden", 1, true) or clause:find("damage", 1, true),
        }
        from = e + 1
    end
    return list
end

-- Returns the short text and its color, and for an effect with two values
-- (healing and damage) the second one's text and color.
local function shortEffect(text)
    local original = cleanText(text) or ""
    original = original:gsub("^[Ee]quip:%s*", ""):gsub("^[Aa]nlegen:%s*", "")
    local lower = original:lower()
    local split = amounts(lower)
    if #split == 2 and not lower:find("gegen ", 1, true) and not lower:find("done to ", 1, true) then
        local german = lower:find("um bis zu", 1, true) ~= nil
        local a, b = split[1], split[2]
        local school = schoolOf(lower, german)
        local function one(v)
            if v.heal and not v.hurt then return "+" .. v.n .. (german and " Heilung" or " Healing"), HEAL end
            if v.hurt and not v.heal then
                if school then return schoolDamage(v.n, school, german), SPELL end
                return "+" .. v.n .. (german and " Zauberschaden" or " Spell Damage"), SPELL
            end
        end
        local s1, c1 = one(a)
        local s2, c2 = one(b)
        if s1 and s2 then return s1, c1, s2, c2 end
    end
    for _, rule in ipairs(EFFECTS) do
        local captures = { lower:match(rule[1]) }
        if captures[1] then
            local short = fill(rule[2], original, lower, captures)
            local condition = fill(rule[4], original, lower, captures)
            if condition then short = short .. " " .. coloredText("· " .. condition, DIM) end
            return short, rule[3]
        end
    end
    -- Wordings differ between clients: fall back to key words.
    local amount = lower:match("um bis zu (%d+)") or lower:match("by up to (%d+)")
    if amount then
        local german = lower:find("um bis zu", 1, true) ~= nil
        local heal = lower:find("heilung", 1, true) or lower:find("healing", 1, true)
        local hurt = lower:find("schaden", 1, true) or lower:find("damage", 1, true)
        local against = lower:match("gegen ([%a\128-\255]+)") or lower:match("done to (%a+)")
        local school = schoolOf(lower, german)
        local function word(value)
            local first = value and lower:find(value, 1, true)
            return first and original:sub(first, first + #value - 1):gsub("^%l", string.upper) or value
        end
        local short, color
        if school and not heal then
            -- "Schattenzauber ... Schaden", "Shadow spells ... damage": the
            -- school's damage, never plain spell damage or spell power.
            short, color = schoolDamage(amount, school, german), SPELL
        elseif heal and hurt and not against then
            short, color = "+" .. amount .. (german and " Zaubermacht" or " Spell Power"), SPELL
        elseif heal then
            short, color = "+" .. amount .. (german and " Heilung" or " Healing"), HEAL
        elseif hurt then
            short, color = "+" .. amount .. (german and " Zauberschaden" or " Spell Damage"), SPELL
        end
        if short then
            if against then
                short = short .. " " .. coloredText("· " .. (german and "gegen " or "against ") .. word(against), DIM)
            end
            return short, color
        end
    end
    return original, nil
end

local function polish(model, blocks, slotName)
    if model.kind ~= "Item" then return end
    local original = false
    local stats, info, tail = {}, {}, {}
    local oldFooter = blocks.footer
    for _, row in ipairs(blocks.values) do
        local text, right = matchText(row.text), row.right and matchText(row.right)
        if right and slotName and (text == matchText(slotName) or right == matchText(slotName)) then
            -- "Two-Hand / Staff": the subtitle says it already.
        elseif right and (text:match("^%d+ %- %d+ ") or text:match("^%d+ %- %d+$"))
            and (right:find("^speed") or right:find("^tempo")) then
            local core = line(row.text .. "  ·  " .. row.right, "dps", { 0.70, 0.72, 0.76 })
            core.small = true
            blocks.dps[#blocks.dps + 1] = core
        elseif not right and (text:match("^[+%-]%d") or text:match("^−%d")) then
            stats[#stats + 1] = row
        elseif text:match("^verzaubert") or text:match("^enchanted") or text:match("^anlegen") or text:match("^equip:")
            or text:match("^benutzen") or text:match("^use:") or text:match("^chance") then
            -- Enchantments and item effects stay whole lines among the effects.
            row.section = "effects"
            blocks.effects[#blocks.effects + 1] = row
        else
            -- Other addons' "Label: value" lines read as a small table.
            local label, value = (cleanText(row.text) or ""):match("^([^:|]+):%s+(.+)$")
            if not right and label and #label <= 30 and not label:match("^%d") then
                row.text, row.right = label, value
                row.rightColor = row.color
                row.color = { 1, 0.82, 0.25 }
            end
            if text:match("^haltbarkeit") or text:match("^durability") then
                local cur, max = text:match("(%d+)%s*/%s*(%d+)")
                cur, max = tonumber(cur), tonumber(max)
                if not (cur and max and max > 0 and cur >= max) then
                    local share = cur and max and max > 0 and cur / max or 1
                    row.color = share < 0.25 and { 1, 0.35, 0.3 } or share < 0.5 and { 1, 0.78, 0.25 } or row.color
                    row.section, row.always = "price", true
                    tail[#tail + 1] = row
                end
            else
                row.section = "info"
                info[#info + 1] = row
            end
        end
    end
    blocks.values = stats
    -- Effects keep only real item effects; other addons' lines that landed
    -- there (item trees, badges, notes) join the addon information.
    local effects, moved = {}, {}
    for _, row in ipairs(blocks.effects) do
        local short, color, second, secondColor = shortEffect(row.text)
        local text = matchText(row.text)
        local effect = color or text:match("^anlegen") or text:match("^equip") or text:match("^benutzen")
            or text:match("^use:") or text:match("^chance") or text:match("^verzaubert") or text:match("^enchanted")
            or text:match("^set:") or text:match("^%(%d+%)") or text:match("^<") or text:match("^[+%-]%d")
        if effect then
            if not original then
                row.text = short
                if color then row.color = color end
            end
            if color or text:match("^[+%-]%d") then row.sizeKind = "bonus"
            elseif text:match("^verzaubert") or text:match("^enchanted") then row.sizeKind = "enchant" end
            effects[#effects + 1] = row
            if second and not original then
                local extra = {}
                for k, v in pairs(row) do extra[k] = v end
                extra.text, extra.color = second, secondColor
                effects[#effects + 1] = extra
            end
        else
            row.section = "info"
            moved[#moved + 1] = row
        end
    end
    blocks.effects = effects
    for i = #moved, 1, -1 do table.insert(info, 1, moved[i]) end
    for _, row in ipairs(oldFooter) do info[#info + 1] = row end
    -- Other addons' key hints ("Ctrl + right click…") are left out.
    local kept = {}
    for _, row in ipairs(info) do
        local text = matchText(row.text)
        local hint = (text:find("ctrl", 1, true) or text:find("strg", 1, true) or text:find("alt%-") or text:find("shift", 1, true))
            and (text:find("click", 1, true) or text:find("klick", 1, true) or text:find(" for ", 1, true) or text:find(" für ", 1, true))
        if not hint then kept[#kept + 1] = row end
    end
    info = kept
    blocks.footer = info
    local ids = {}
    for _, row in ipairs(blocks.footer) do
        local text = matchText(row.text)
        if text:find("item id", 1, true) or text:find("gegenstands%-id") or text:find("spell id", 1, true) then
            ids[#ids + 1] = row
        end
    end
    for _, row in ipairs(tail) do blocks.price[#blocks.price + 1] = row end
    -- Where the item comes from closes the tooltip as its own part: the
    -- dungeon journal source, other addons' source paths (ATT > ...), and the
    -- item ID last, small and dimmed.
    local source = {}
    for _, row in ipairs(blocks.origin) do row.section = "origin"; source[#source + 1] = row end
    for i = #blocks.footer, 1, -1 do
        local row = blocks.footer[i]
        if matchText(row.text):match("^att%s*>") then
            table.remove(blocks.footer, i)
            row.section = "origin"
            table.insert(source, #blocks.origin + 1, row)
        end
    end
    for _, row in ipairs(ids) do
        for i, other in ipairs(blocks.footer) do
            if other == row then table.remove(blocks.footer, i); break end
        end
        row.section, row.small = "origin", true
        row.color, row.rightColor = DIM, DIM
        source[#source + 1] = row
    end
    blocks.origin = source
end

-- DaylightUI 2.0's text colors, as on its rich cards: a number stands out
-- in its stat's color (or the accent), the words read in DaylightUI's text
-- color, effects and set bonuses in its green, damage and healing numbers in
-- a description in theirs. A line the game shows in red (a requirement you
-- don't meet, armor or a weapon you can't use) keeps its red.
local RichItems, RichSpells, Rich = mod.ns.RichItems, mod.ns.RichSpells, mod.ns.Rich
local INK = Style.INK or {}
local INK_TEXT = INK.TEXT or { 0.95, 0.93, 0.90 }
local INK_GOOD = INK.GOOD or { 0.55, 0.85, 0.55 }
local INK_LOSS = INK.DAMAGE or { 0.93, 0.50, 0.44 }
local INK_VALUE = INK.VALUE or { 1, 1, 1 }
local INK_LABEL = INK.LABEL or { 0.76, 0.71, 0.62 }
local function popInk()
    local r, g, b = (Style.Pop or Style.Accent)()
    return { r or 1, g or 1, b or 1 }
end
local function isRed(c)
    return type(c) == "table" and type(c[1]) == "number" and c[1] > 0.85 and c[2] < 0.45 and c[3] < 0.45
end
local function isGreenish(c)
    return type(c) == "table" and type(c[2]) == "number" and c[2] > c[1] + 0.3 and c[2] > c[3] + 0.3
end
-- Blasta's own short names (German and English) to DaylightUI's stat keys.
local STAT_KEYS = {
    { "schatten", "Shadow Damage" }, { "shadow", "Shadow Damage" }, { "feuer", "Fire Damage" }, { "fire", "Fire Damage" },
    { "frost", "Frost Damage" }, { "natur", "Nature Damage" }, { "nature", "Nature Damage" },
    { "arkan", "Arcane Damage" }, { "arcane", "Arcane Damage" }, { "heilig", "Holy Damage" }, { "holy", "Holy Damage" },
    { "zaubermacht", "Spell Power" }, { "spell power", "Spell Power" },
    { "zauberschaden", "Spell Damage" }, { "spell damage", "Spell Damage" },
    { "heilung", "Healing" }, { "healing", "Healing" },
    { "distanzangriffskraft", "Ranged Attack Power" }, { "ranged attack power", "Ranged Attack Power" },
    { "angriffskraft", "Attack Power" }, { "attack power", "Attack Power" },
    { "kritische zaubertreffer", "Spell Crit" }, { "spell crit", "Spell Crit" }, { "spell hit", "Spell Hit" },
    { "kritische treffer", "Crit" }, { "crit", "Crit" }, { "trefferchance", "Hit" }, { "hit", "Hit" },
    { "mana", "Mana per 5 sec" }, { "verteidigung", "Defense" }, { "defense", "Defense" },
}
local function statInk(text, word)
    if Tip.ReadStat then
        local ok, num, _, c = pcall(Tip.ReadStat, text)
        if ok and num and type(c) == "table" then return c end
    end
    if not (Tip.StatColor and type(word) == "string") then return nil end
    local lower = word:lower():gsub("|c%x%x%x%x%x%x%x%x.-|r", "")
    for _, pair in ipairs(STAT_KEYS) do
        if lower:find(pair[1], 1, true) then
            local ok, c = pcall(Tip.StatColor, pair[2])
            if ok and type(c) == "table" then return c end
        end
    end
end
local function triggerWord(text)
    for _, w in ipairs({ ITEM_SPELL_TRIGGER_ONUSE or "Use:", ITEM_SPELL_TRIGGER_ONPROC or "Chance on hit:",
        ITEM_SPELL_TRIGGER_ONEQUIP or "Equip:", "Benutzen:", "Use:", "Anlegen:", "Equip:" }) do
        if type(w) == "string" and w ~= "" and text:sub(1, #w) == w then return w, (text:sub(#w + 1):gsub("^%s+", "")) end
    end
end

-- The card's top light: an item's quality, a unit's class or reaction, a
-- spell's school, else the accent (DaylightUI's Rich.Light).
local function lightFor(model, tip, data)
    local kind = model.kind == "Item" and "item" or model.kind == "Unit" and "unit" or "spell"
    if kind == "spell" and RichSpells and RichSpells.School and RichSpells.Light then
        for _, row in ipairs(model.lines) do
            if row.section == "effects" then
                local ok, school = pcall(RichSpells.School, row.text)
                local pair = ok and school and RichSpells.Light(school)
                if pair then return pair, nil, school end
                break
            end
        end
    end
    if Rich and Rich.Light and tip and data then
        local ok, pair, quality = pcall(Rich.Light, tip, data, kind)
        if ok and type(pair) == "table" then return pair, quality end
    end
    local c = model.color or INK_VALUE
    local lift = RichItems and RichItems.Lift and RichItems.Lift(c) or c
    return { lift, c }
end

local function levelRequirementInk(model, minLevel)
    local required = requiredLevel(model, minLevel)
    local playerLevel = required and plain(UnitLevel("player"))
    if type(playerLevel) == "number" and playerLevel > 0 then
        model.requirementColor = playerLevel >= required and INK_GOOD or (INK.BAD or INK_LOSS)
    elseif model.requirement and not isRed(model.requirementColor) then
        model.requirementColor = INK_LABEL
    end
end

local function daylightInk(model, tip, data)
    local numbers = DUI.Tips and DUI.Tips.Numbers
    local pop = popInk()
    local light, quality, school = lightFor(model, tip, data)
    model.light = light
    if model.kind == "Item" and quality and type(light[1]) == "table" then
        -- The name and the item level in the quality's light end.
        model.titleColor, model.levelColor = light[1], model.levelColor or light[1]
    end
    if model.binding and not model.binding:find("|c") and RichItems and RichItems.BadgeColor then
        local ok, c = pcall(RichItems.BadgeColor, cleanText(model.binding) or model.binding)
        if ok and type(c) == "table" then model.binding = coloredText(model.binding, c) end
    end
    local schoolInk = school and school.color or nil
    if model.kind == "Spell" and school then
        model.schoolLabel, model.schoolColor = school.word, schoolInk
    end
    for _, row in ipairs(model.lines) do
        local text, section = row.text, row.section
        if type(text) == "string" and text ~= "" and not isRed(row.color) then
            if section == "comparison" then
                if row.columns then
                    row.color, row.rightColor = INK_GOOD, INK_LOSS
                elseif matchText(text):match("^%+") then
                    row.color = INK_GOOD
                elseif matchText(text):match("^[-−]") then
                    row.color = INK_LOSS
                end
            elseif (section == "values" or (section == "effects" and row.sizeKind == "bonus")) and not text:find("^|c") then
                local num, word = text:match("^([+%-]?%d[%d%.,]*%%?)%s+(.+)$")
                if num then
                    local c = statInk(text, word) or (num:sub(1, 1) == "-" and INK_LOSS)
                        or (section == "effects" and INK_GOOD) or INK_VALUE
                    row.text, row.color = coloredText(num, c) .. " " .. word, INK_TEXT
                end
            elseif section == "dps" and not text:find("|c") then
                row.text = text:gsub("(%d[%d%.,]*)", function(n) return coloredText(n, pop) end)
                row.color = INK_TEXT
            elseif section == "effects" and numbers then
                if model.kind == "Item" then
                    if row.sizeKind == "enchant" or isGreenish(row.color) then
                        local word, rest = triggerWord(text)
                        if word then
                            row.text, row.color = coloredText(word, INK_GOOD) .. " " .. numbers(rest), INK_TEXT
                        else
                            row.text, row.color = numbers(text), INK_GOOD
                        end
                    end
                elseif model.kind ~= "Unit" and model.kind ~= "Quest" then
                    row.text, row.color = numbers(text, schoolInk), INK_TEXT
                    if model.kind == "Spell" and schoolInk and not text:find("|[cC]") then
                        local lower = text:lower()
                        if lower:find("heil", 1, true) or lower:find("heal", 1, true) then
                            row.text = row.text:gsub("|c%x%x%x%x%x%x%x%x([%d.,]+)|r(%s*%%)", function(value, percent)
                                return coloredText(value .. percent, schoolInk)
                            end)
                        end
                    end
                end
            end
        end
    end
end

local function questPlayerNames()
    local names = {}
    local function add(unit)
        local name = plain(UnitName(unit))
        if type(name) == "string" and name ~= "" then names[matchText(name)] = name end
    end
    add("player")
    for i = 1, GetNumSubgroupMembers() do add("party" .. i) end
    return names
end

local questProgressCache
local function ownQuestProgress()
    if questProgressCache then return questProgressCache end
    local log, progress = C_QuestLog, {}
    if not (log and log.GetQuestObjectives and log.GetNumQuestLogEntries and log.GetInfo) then return progress end
    for index = 1, plain(log.GetNumQuestLogEntries()) or 0 do
        local info = plain(log.GetInfo(index))
        local id = type(info) == "table" and plain(info.questID)
        if type(id) == "number" and id > 0 then
            local objectives = plain(log.GetQuestObjectives(id))
            for _, objective in ipairs(objectives or {}) do
                local text, have, need = plain(objective.text), plain(objective.numFulfilled), plain(objective.numRequired)
                if type(text) == "string" and type(have) == "number" and type(need) == "number" and need > 0 then
                    local key = matchText(text):gsub("^%s*%d+%s*/%s*%d+%s+", "")
                        :gsub("[:%s]+%d+%s*/%s*%d+%s*$", ""):match("^%s*(.-)%s*$")
                    local prior = progress[key]
                    local value = ("%d/%d"):format(have, need)
                    if prior == nil or (prior and prior.value == value) then
                        progress[key] = { value = value, complete = have >= need }
                    else
                        progress[key] = false
                    end
                end
            end
        end
    end
    questProgressCache = progress
    return progress
end

local function questRowText(text)
    return cleanText((text or ""):gsub("|cn[%w_]+:", ""):gsub("|[Tt].-|[Tt]", ""))
end

local function questCount(text)
    local title, count = text:match("^(.-):%s*(%d+%s*/%s*%d+)$")
    if count then return title, count end
    count, title = text:match("^(%d+%s*/%s*%d+)%s+(.+)$")
    return title, count
end

local function layoutQuestProgress(rows, sourceRows, headings, names, own, player, expanded)
    local summary, groups, byName, removed = {}, {}, {}, {}
    local hasDetails = false
    for _, heading in ipairs(headings) do
        local row, progress = heading.row, own[heading.key]
        if progress then
            local title = questCount(questRowText(row.text):gsub("%s+%b()$", ""))
            if title and title:lower() == heading.key then row.text = title end
            local ink = progress.complete and INK_GOOD or INK_TEXT
            row.right = coloredText(progress.value, ink) .. "   " .. row.right
        end
        summary[#summary + 1], removed[row] = row, true
    end
    local identified = {}
    for _, heading in ipairs(headings) do identified[heading.key] = heading end
    local pending, pendingRow
    for _, row in ipairs(sourceRows) do
        local text, right = questRowText(row.text), questRowText(row.right)
        local title, count = questCount(text)
        if not count and right:match("^%d+%s*/%s*%d+$") then title, count = text:gsub(":%s*$", ""), right end
        local key = title and title:lower()
        local heading = key and identified[key]
        if heading and not removed[row] then
            if pendingRow then removed[pendingRow] = true end
            removed[row] = true
            local progress = own[key]
            local isOwn = pending ~= nil and pending == player
            if not (isOwn and progress) then
                hasDetails = true
                if expanded or not progress then
                    local groupName = pending or (GetLocale() == "deDE" and "Ohne Zuordnung" or "Unassigned")
                    local group = byName[groupName]
                    if not group then
                        group = { name = groupName, rows = {} }
                        byName[groupName], groups[#groups + 1] = group, group
                    end
                    local entry = line(title, "values", INK_LABEL, count)
                    local have, need = count:match("^(%d+)%s*/%s*(%d+)$")
                    if tonumber(have) >= tonumber(need) then entry.rightColor = INK_GOOD end
                    group.rows[#group.rows + 1] = entry
                end
            end
        else
            pending = not removed[row] and (row.questPlayer or (not row.right and names[text:lower()]))
            pendingRow = pending and row or nil
        end
    end
    if #groups > 0 then
        for _, group in ipairs(groups) do
            summary[#summary + 1] = line(group.name, "values", INK_LABEL)
            for _, row in ipairs(group.rows) do summary[#summary + 1] = row end
        end
    elseif hasDetails and not expanded then
        local hint = line(GetLocale() == "deDE" and "Shift für Gruppenfortschritt" or "Shift for party progress", "values", INK_LABEL)
        hint.small = true
        summary[#summary + 1] = hint
    end
    local output, inserted = {}, false
    for _, row in ipairs(rows) do
        if removed[row] then
            if not inserted then
                for _, summaryRow in ipairs(summary) do output[#output + 1] = summaryRow end
                inserted = true
            end
        else
            output[#output + 1] = row
        end
    end
    return output
end

local function mergeQuestDrops(blocks, guid, seen)
    local profile = _G.Questie and _G.Questie.db and _G.Questie.db.profile
    local loader = _G.QuestieLoader
    -- Questie can supply data even when its own tooltip display is off.
    if not (profile and profile.enableTooltipDroprates and loader) then return end
    if type(guid) ~= "string" then return end
    local kind, npc = guid:match("^(%a+)%-[^%-]+%-[^%-]+%-[^%-]+%-[^%-]+%-(%d+)%-")
    if not npc or (kind ~= "Creature" and kind ~= "Vehicle") then return end
    local ok, questTips = pcall(loader.ImportModule, loader, "QuestieTooltips")
    if not (ok and questTips and questTips.GetTooltip) then return end
    local found, objectives = pcall(questTips.GetTooltip, "m_" .. npc)
    if not found or type(objectives) ~= "table" then return end
    local existing = {}
    for _, section in ipairs({ "values", "effects", "footer" }) do
        for _, row in ipairs(blocks[section]) do
            local key = matchText(row.text):match("^%s*(.-)%s*$")
            if key ~= "" and not existing[key] and not row.right then existing[key] = row end
        end
    end
    local shown, headings = {}, {}
    for _, text in ipairs(objectives) do
        local visible = type(text) == "string" and cleanText(stripBullet(text))
        local withoutIcons = visible and visible:gsub("|[Tt].-|[Tt]", "")
        local objective, chance
        if withoutIcons then
            objective, chance = withoutIcons:match("^(.-)%s*%[%s*(%d+[.,]?%d*%%)%]")
        end
        if chance and not seen[visible .. "\31"] then
            local progress = matchText(objective):match("^%s*(.-)%s*$")
            local title = progress:gsub("%s+%b()$", ""):gsub("^%d+%s*/%s*%d+%s+", "")
                :gsub("[:%s]+%d+%s*/%s*%d+%s*.*$", "")
            if title ~= "" and not shown[title] then
                local row = existing[title] or existing[progress]
                if not row then
                    row = line(objective, "values")
                    blocks.values[#blocks.values + 1] = row
                end
                row.right, row.rightColor = chance, popInk()
                headings[#headings + 1] = { key = title, row = row }
                shown[title] = true
            end
        end
    end
    return headings
end

local function modelFor(tip, data)
    local kind = kinds[plain(data.type)]
    if not kind then return end
    local count = plain(tip:NumLines())
    local source = plain(data.lines)
    if type(source) ~= "table" or plain(#source) ~= count then source = nil end
    local header = source and plain(source[1])
    local title, color = readLine(tip, 1, false, type(header) == "table" and header or nil)
    local spellID = kind == "Spell" and plain(data.id)
    if type(spellID) ~= "number" then spellID = nil end
    local displayID, spellIDLabel
    if config().showIDs and (kind == "Spell" or kind == "Aura" or kind == "Buff" or kind == "Debuff") then
        local id = plain(data.id)
        if type(id) == "number" then
            displayID = tostring(id)
            spellIDLabel = Tip.SPELL_ID or L["Spell ID"]
        end
    end
    if not title and spellID and C_Spell and C_Spell.GetSpellName then
        title = plain(C_Spell.GetSpellName(spellID))
    end
    if not (title and count and count >= 1 and count <= 64) then return end
    color = color or { 0.88, 0.90, 0.93 }
    local icon, subtitle, price, level, slotName, itemQuality, item, maxStack, minLevel, itemClass, itemSubclass, wearable, slotKey
    if kind == "Item" then
        icon, subtitle, price, level, slotName, itemQuality, item, maxStack, minLevel, itemClass, itemSubclass, wearable, slotKey =
            itemHeader(tip, data)
    elseif C_Spell and C_Spell.GetSpellTexture and type(plain(data.id)) == "number" then
        icon = plain(C_Spell.GetSpellTexture(data.id))
    end
    local model = { kind = kind, title = title, color = color, icon = icon, subtitle = subtitle,
        level = wearable and level or nil, lines = {}, stats = {} }
    if type(itemQuality) == "number" and DUI.Win and DUI.Win.Parts and DUI.Win.Parts.QualityColor then
        model.iconColor = { DUI.Win.Parts.QualityColor(itemQuality) }
    end
    if subtitle and slotName and matchText(subtitle) ~= matchText(slotName) then model.subtitle = subtitle .. " · " .. slotName end
    -- What it is and where it goes in DaylightUI's colors (cloth, leather,
    -- mail, plate, weapons, jewelry...).
    local itemInfo
    if kind == "Item" and RichItems and RichItems.Info then
        local ok, info = pcall(RichItems.Info, plain(Tip.ItemLink(tip, data)))
        if ok and type(info) == "table" then itemInfo = info end
    end
    local slotText = slotName and itemInfo and itemInfo.slotColor and coloredText(slotName, itemInfo.slotColor) or slotName
    if itemInfo then
        model.levelColor = itemInfo.light
    end
    if itemInfo and subtitle then
        local typeInk = itemInfo.armor or itemInfo.subColor or itemInfo.kindColor
        model.itemTypeColor = typeInk
        model.subtitle = typeInk and coloredText(subtitle, typeInk) or subtitle
        if slotName and matchText(subtitle) ~= matchText(slotName) then model.subtitle = model.subtitle .. " · " .. slotText end
    end
    if kind == "Spell" then
        local titleRank = readLine(tip, 1, true, type(header) == "table" and header or nil)
        if isRank(titleRank) then model.rank = cleanText(titleRank) end
        local id = plain(data.id)
        if not model.rank and type(id) == "number" and C_Spell and C_Spell.GetSpellSubtext then
            local subtext = plain(C_Spell.GetSpellSubtext(id))
            if type(subtext) == "string" and subtext:match("%d") then model.rank = subtext end
        end
    elseif kind == "Aura" or kind == "Buff" or kind == "Debuff" then
        model.subtitle = L[kind]
    end
    model.equipped = kind == "Item" and comparisonFrames(tip) ~= nil
    local unitFields, questZone, questGUID
    if kind == "Quest" then
        local quest = plain(data.quest)
        questZone = type(quest) == "table" and plain(quest.zone)
        model.subtitle = questZone or L["Quest"]
        model.icon = 134328
    elseif kind == "Unit" and tip.GetUnit then
        questGUID = plain(data.guid)
        local _, unit = tip:GetUnit()
        unit = plain(unit)
        if type(unit) == "string" then
            local level = plain(UnitLevel(unit))
            local player = plain(UnitIsPlayer(unit))
            local race = plain(player and UnitRace(unit) or UnitCreatureType(unit))
            local class = player and plain(UnitClass(unit))
            local fields = {}
            if type(level) == "number" and level > 0 then fields[#fields + 1] = L["Level"] .. " " .. level end
            if type(race) == "string" then fields[#fields + 1] = race end
            if type(class) == "string" then fields[#fields + 1] = class end
            if #fields > 0 then
                unitFields = fields
                model.subtitle = table.concat(fields, " · ")
            end
            if not questGUID and not player then questGUID = plain(UnitGUID(unit)) end
            if player and SetPortraitTexture then model.unit, model.icon = unit, true end
            local hp, max = plain(UnitHealth(unit)), plain(UnitHealthMax(unit))
            if type(hp) == "number" and type(max) == "number" and max > 0 then
                model.health = math.max(0, math.min(1, hp / max))
            end
        end
    end
    local blocks = { dps = {}, values = {}, effects = {}, trainingDiscount = {}, comparison = {}, footer = {}, price = {}, reagent = {}, disenchant = {}, origin = {} }
    local auctionator = kind == "Item" and _G.Auctionator
    local auctionAPI = auctionator and auctionator.API and auctionator.API.v1
    local labels = auctionator and auctionLabels()
    local auctionConfig = auctionator and auctionator.Config
    local enchantOption = auctionConfig and auctionConfig.Options and auctionConfig.Options.ENCHANT_TOOLTIPS
    local auctionMaterials = enchantOption and auctionConfig.Get and auctionConfig.Get(enchantOption)
    local hasAuctionPrice, auctionVendorPrice
    local auctionModule = kind == "Item" and DUI:GetModule("AuctionHouse")
    local native = auctionModule and auctionModule.ns
    local bagCount = kind == "Item" and bagPriceCount(tip, item, maxStack)
    local countSuffix = bagCount and bagCount > 1 and (" ×" .. bagCount) or ""
    local nativeStack = countSuffix ~= "" and (not native or not native.Setting or native.Setting("tooltipStack") ~= false)
    local nativeRows
    if bagCount and native and native.Tooltip and native.Tooltip.Lines then
        nativeRows = native.Tooltip.Lines(item, nativeStack, bagCount)
    end
    local function auctionatorValue()
        if not (item and type(item) == "string" and auctionAPI and auctionAPI.GetAuctionPriceByItemLink) then return end
        local ok, value = pcall(auctionAPI.GetAuctionPriceByItemLink, "DaylightUI_Blasta", item)
        value = ok and plain(value) or nil
        if type(value) == "number" and value > 0 then return value end
    end
    local stats = {}
    local questNames = questGUID and tip == GameTooltip and questPlayerNames()
    local questRows, questHeadings = {}
    local sale, comparing, inDisenchant, disenchantAverage, seen = nil, false, false, nil, {}
    local threat, selfTarget
    local discountHeading = kind == "Spell" and extras.Translate("Training discounts")
    for i = 2, count do
        local sourceLine = source and plain(source[i])
        if type(sourceLine) ~= "table" then sourceLine = nil end
        local text, ink, hidden = readLine(tip, i, false, sourceLine)
        local right, rightInk, hiddenRight = readLine(tip, i, true, sourceLine)
        if (hidden or hiddenRight) and kind ~= "Spell" then return end
        -- The native ID line can already be present on the source tooltip.
        if displayID and text == spellIDLabel and right == displayID then
            text, right = nil, nil
        end
        if kind == "Spell" then
            if recordSpellStat(stats, text) then text = nil end
            if recordSpellStat(stats, right) then right = nil end
            if isRank(text) then model.rank, text = cleanText(text), nil end
            if isRank(right) then model.rank, right = cleanText(right), nil end
        elseif unitFields and i <= 6 then
            if unitHeaderContains(text, unitFields) then text = nil end
            if unitHeaderContains(right, unitFields) then right = nil end
        elseif kind == "Quest" and questZone and i == 2 and not right then
            local lower = matchText(text)
            local zone = lower:match("^stufe %d+ · (.+)$") or lower:match("^level %d+ · (.+)$")
            if zone == matchText(questZone) then model.subtitle, text = cleanText(text), nil end
        elseif kind == "Item" and i <= 8 then
            local lower = matchText(text)
            local other = matchText(right)
            local itemType, itemSlot = matchText(subtitle), matchText(slotName)
            local restriction = restrictionInk(itemType, lower, ink, other, rightInk)
                or restrictionInk(itemSlot, lower, ink, other, rightInk)
            if slotName and itemType ~= "" and restriction then
                model.itemTypeColor = restriction
                model.subtitle = coloredText(subtitle, restriction)
                if slotName and itemType ~= itemSlot then model.subtitle = model.subtitle .. " · " .. slotText end
            end
            if (lower == itemType or lower == itemSlot) and (other == "" or other == itemType or other == itemSlot) then
                text, right = nil, nil
            elseif not text and other ~= "" and (other == itemType or other == itemSlot) then
                right = nil
            end
            if lower:match("^binds ") or lower:match("^soulbound$") or lower:match("^wird beim ")
                or lower:match("^seelengebunden$") or lower:match("^gebunden$") then
                model.binding, text = text, nil
            elseif level and (lower == "item level " .. level or lower == "gegenstandsstufe " .. level
                or lower == "ilvl " .. level or lower == "gs " .. level) then
                text = nil
            end
        end
        if kind == "Item" then
            if isLevelRequirement(text) then model.requirement, model.requirementColor, text = text, ink, nil end
            if isLevelRequirement(right) then model.requirement, model.requirementColor, right = right, rightInk, nil end
        end
        text = stripBullet(text)
        local leftKey = cleanText(text) or ""
        if kind == "Item" and not right then leftKey = itemTooltipRowKey(leftKey) end
        local rowKey = leftKey .. "\31" .. (cleanText(right) or "")
        local ownerLabel = questNames and not right and questNames[questRowText(text):lower()]
        local playerLineType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestPlayer
        if questNames and sourceLine and playerLineType and plain(sourceLine.type) == playerLineType then
            ownerLabel = ownerLabel or questRowText(text)
        end
        if (text or right) and (ownerLabel or not seen[rowKey]) then
            seen[rowKey] = true
            local section = "values"
            local lower = matchText(text)
            local delta = comparing and (lower:match("^[+-]%s*%d") or lower:match("^−%s*%d"))
            local isPrice = lower:match("^sell price") or lower:match("^vendor price") or lower:match("^verkaufspreis") or lower:match("^händlerpreis")
            local market = kind == "Item" and daylightAuctionRow(lower, right, native)
            local auctionKey = labels and right and auctionRow(lower, labels)
            local breakdown = auctionMaterials and not right and lower:match("^%d+[.,]?%d*%%%s+%d[^%s]*%s+%S")
            local heading = kind == "Item" and not right and disenchantHeading(lower)
            local average = kind == "Item" and ((lower == "" and hasAveragePrefix(right))
                or (not right and hasAveragePrefix(text)))
            local material = inDisenchant and right and (right:find("%%") or lower:find("^item level")
                or lower:find("^gegenstandsstufe"))
            if discountHeading and not right and text == discountHeading then
                section = "trainingDiscount"
            elseif discountHeading and right and #blocks.trainingDiscount > 0 and lower:find("%(−%d+%%%)") then
                section = "trainingDiscount"
            elseif average then
                disenchantAverage = line(text or "", "values", ink, right)
                disenchantAverage.rightColor = rightInk or ink
                section = nil
            elseif heading or material or auctionKey == "DISENCHANT" or breakdown then
                section = "disenchant"
                inDisenchant = heading or (material and lower ~= "")
                if lower == "item level" then text = extras.Translate("Item Level") end
            elseif market == "hint" or auctionKey == "AUCTION_AGE" then
                section = nil
            elseif market == "quote" then
                section = "price"
                text, hasAuctionPrice = extras.Translate("Auction price"), true
                if nativeRows and nativeRows[1] then
                    right = nativeRows[1][2]
                    if nativeStack then text = text .. countSuffix end
                end
            elseif market == "usual" then
                section = "price"
                if nativeRows and nativeRows[2] and nativeRows[2][2] then
                    text, right = nativeRows[2][1], nativeRows[2][2]
                end
            elseif kind == "Item" and not right and (lower == "crafting reagent" or lower == "handwerksmaterial") then
                section = "reagent"
                if lower == "crafting reagent" then text = extras.Translate("Crafting Reagent") end
            elseif auctionKey then
                section = auctionKey ~= "VENDOR" and "price" or nil
                if auctionKey == "AUCTION" then
                    hasAuctionPrice = true
                    local each = bagCount and auctionatorValue()
                    if each and DUI.MoneyString then
                        text = extras.Translate("Auction price") .. countSuffix
                        right = DUI.MoneyString(each * bagCount)
                    end
                end
                if auctionKey == "VENDOR" then auctionVendorPrice = auctionVendorPrice or right end
            elseif isPrice then
                local inline = text and text:match(":%s*(.+)")
                if inline and not inline:gsub("|r", ""):match("%S") then inline = nil end
                sale = sale or inline or right
                section = nil
            elseif kind == "Item" and not right and lower:find("|tinterface\\icons\\inv_misc_book_09:", 1, true) == 1 then
                -- Forever Dungeon Journal prefixes its item source with a journal icon.
                section = "origin"
            elseif kind == "Item" and (lower:match("^wenn ihr diesen gegenstand ersetzt")
                or lower:match("^wenn ihr diesen gegenstand anlegt") or lower:match("^if you replace this item")
                or lower:match("^if you equip this item")) then
                section, comparing = "comparison", true
                text = extras.Translate("Stat changes")
            elseif comparing and delta then
                section = "comparison"
            elseif lower:find("item id", 1, true) or lower:find("spell id", 1, true) or lower:find("f6", 1, true)
                or lower:find("gegenstands%-id") or lower:find("zauber%-id") then
                section = "footer"
            elseif kind == "Item" and (lower:find("damage per second", 1, true) or lower:find("schaden pro sekunde", 1, true)
                or lower:match("^%d+ armor$") or lower:match("^%d+ rüstung$")) then
                section = "dps"
            elseif (kind == "Spell" and #lower > 35) or (ink and (ink[2] > ink[1] + 0.2 or #lower > 65)) then
                section = "effects"
            end
            if section ~= "disenchant" then inDisenchant = false end
            if section then
                local row = line(text or "", section, ink, right)
                if section == "dps" then row.text = row.text:gsub("^%((.*)%)$", "%1") end
                row.rightColor = rightInk
                if kind == "Unit" and right and lower == matchText(Tip.TARGET_LABEL or L["Target:"]) then
                    if matchText(right) == matchText(L[">> You <<"]) then
                        right = L["You"]
                        selfTarget = row
                    end
                    row.text = row.text .. " " .. coloredText(right, rightInk or row.color)
                    row.right, row.rightColor = nil, nil
                end
                if kind == "Unit" and not right and (lower:match("^%d+[,.]?%d*%%%s+bedrohung$")
                    or lower:match("^%d+[,.]?%d*%%%s+threat$")) then threat = row end
                if section ~= "comparison" then comparing = false end
                blocks[section][#blocks[section] + 1] = row
                if questNames then
                    row.questPlayer = ownerLabel or nil
                    questRows[#questRows + 1] = row
                end
            end
        end
    end
    if questGUID and tip == GameTooltip then
        questHeadings = mergeQuestDrops(blocks, questGUID, seen)
    end
    if auctionator and not hasAuctionPrice then
        local each = auctionatorValue()
        if each and DUI.MoneyString then
            table.insert(blocks.price, 1, line(extras.Translate("Auction price") .. countSuffix, "price", nil,
                DUI.MoneyString(each * (bagCount or 1))))
        end
    end
    local saleLabel = L["Sell price"]
    local hasUnitPrice = type(price) == "number" and price > 0 and DUI.MoneyString
    if bagCount and hasUnitPrice and config().blastaUnitPrice ~= false then
        saleLabel = saleLabel .. countSuffix
        sale = DUI.MoneyString(price * bagCount)
    end
    sale = sale or auctionVendorPrice or (hasUnitPrice and DUI.MoneyString(price))
    if sale then table.insert(blocks.price, 1, line(saleLabel, "price", nil, sale)) end
    -- Stat changes: gains in the left column, losses in the right, each in the
    -- order the game lists them. Halves the height of the block.
    if #blocks.comparison > 1 then
        local heading, gains, losses = blocks.comparison[1], {}, {}
        for i = 2, #blocks.comparison do
            local row = blocks.comparison[i]
            local start = matchText(row.text)
            if start:match("^[-−]") then losses[#losses + 1] = row else gains[#gains + 1] = row end
        end
        local paired = { heading }
        for i = 1, math.max(#gains, #losses) do
            local gain, loss = gains[i], losses[i]
            local row = line(gain and gain.text or "", "comparison", gain and gain.color or (loss and loss.color), loss and loss.text)
            row.rightColor = loss and loss.color or nil
            row.columns = true
            paired[#paired + 1] = row
        end
        blocks.comparison = paired
    end
    if spellID and #blocks.effects == 0 and (not source or count == 1) and C_Spell and C_Spell.GetSpellDescription then
        local description = plain(C_Spell.GetSpellDescription(spellID))
        if type(description) == "string" and description ~= "" and not seen[description .. "\31"] then
            blocks.effects[1] = line(description, "effects")
        end
    end
    if kind == "Spell" then
        fillSpellStats(stats, plain(data.id))
        if next(stats) then
            for _, stat in ipairs(statOrder) do
                local i, label = stat[1], stat[2]
                if stats[i] then
                    model.stats[#model.stats + 1] = {
                        value = stats[i], label = (label == "Range" and extras.Translate(label) or L[label]) or label,
                        cost = i == 1, cooldown = i == 3,
                    }
                end
            end
        end
    end
    local estimatedDisenchant, partial = priceDisenchantResults(blocks.disenchant, auctionAPI)
    if estimatedDisenchant then
        local label = partial and "Average disenchant value (at least)" or "Average disenchant value"
        blocks.disenchant[#blocks.disenchant + 1] = line(extras.Translate(label), "disenchant", nil, DUI.MoneyString(estimatedDisenchant))
    elseif partial then
        blocks.disenchant[#blocks.disenchant + 1] = line(extras.Translate("Average disenchant value"),
            "disenchant", nil, extras.Translate("No material prices"))
    elseif disenchantAverage then
        local rows = blocks.values
        if #blocks.disenchant > 0 then
            rows = blocks.disenchant
            disenchantAverage.section = "disenchant"
            local value = disenchantAverage.right or disenchantAverage.text
            disenchantAverage.text = extras.Translate("Average disenchant value")
            disenchantAverage.right = value:gsub("Ø%s*", "", 1):gsub("ø%s*", "", 1)
        end
        rows[#rows + 1] = disenchantAverage
    end
    polish(model, blocks, slotName)
    local order = kind == "Spell" and { "effects", "values", "trainingDiscount", "footer" }
        or { "dps", "values", "effects", "footer", "disenchant", "comparison", "reagent", "price", "origin" }
    for _, section in ipairs(order) do
        for _, row in ipairs(blocks[section]) do
            if row == threat and selfTarget then
                row.text = row.text .. " · " .. coloredText(selfTarget.text, selfTarget.color)
            end
            if row ~= selfTarget or not threat then model.lines[#model.lines + 1] = row end
        end
    end
    if questHeadings and #questHeadings > 0 then
        model.lines = layoutQuestProgress(model.lines, questRows, questHeadings, questNames,
            ownQuestProgress(), plain(UnitName("player")), IsShiftKeyDown())
    end
    if displayID then
        local row = line(spellIDLabel, "spellID", { Style.Accent() }, displayID)
        row.rightColor = Tip.ID_VALUE
        model.lines[#model.lines + 1] = row
    end
    if kind == "Item" then levelRequirementInk(model, minLevel) end
    daylightInk(model, tip, data)
    if wearable then equipmentFacts(model, subtitle, slotName, slotText, minLevel, itemClass, itemSubclass, slotKey) end
    if kind ~= "Spell" and #model.lines == 0 and #model.stats == 0 and not (model.health or unitFields) then return end
    return model
end

local states, queued, revision = {}, false, 0
-- DaylightUI 2.0's way for its own cards: the hidden game tooltip is padded
-- to exactly the card's size and the card lies on it. So the game and
-- DaylightUI place it (beside a recipe row, flipped where the screen runs out,
-- compare tooltips beside it) as if it were the tooltip itself. Returns false
-- when the size can't be read (a secret line in a fight): then the card is
-- placed by hand as before.
local function fitNative(tip, panel, state)
    if not (tip.SetPadding and tip.GetPadding) then return false end
    local w, h = plain(tip:GetWidth()), plain(tip:GetHeight())
    local pw, ph = panel:GetWidth(), panel:GetHeight()
    local ts, ps = plain(tip:GetEffectiveScale()), panel:GetEffectiveScale()
    if type(w) ~= "number" or type(h) ~= "number" or type(ts) ~= "number" or ts <= 0
        or not (pw and ph and pw > 0 and ph > 0) then return false end
    local k = ps / ts
    local dw, dh = pw * k - w, ph * k - h
    if math.abs(dw) < 0.5 and math.abs(dh) < 0.5 then
        state.padded = true
        return true
    end
    -- Asked once for this size and the client didn't move: leave it.
    local tried = state.fitTried
    if tried and math.abs(tried[1] - w) < 0.5 and math.abs(tried[2] - h) < 0.5 then return state.padded == true end
    local ok, r, b, l, t = pcall(tip.GetPadding, tip)
    if not ok then return false end
    r, b, l, t = tonumber(plain(r)) or 0, tonumber(plain(b)) or 0, tonumber(plain(l)) or 0, tonumber(plain(t)) or 0
    if not pcall(tip.SetPadding, tip, r + dw, b + dh, l, t) then return false end
    state.fitTried, state.padded = { w, h }, true
    return true
end

local function unfit(tip, state)
    if state.padded and tip.GetPadding and tip.SetPadding then
        local ok, _, _, l, t = pcall(tip.GetPadding, tip)
        if ok then pcall(tip.SetPadding, tip, 0, 0, tonumber(plain(l)) or 0, tonumber(plain(t)) or 0) end
    end
    state.padded, state.fitTried = nil, nil
end

local function restore(tip, state, keepNativeAlpha)
    state.awaitAlpha, state.refill = nil, nil
    if state.panel and not state.fading then state.panel:Hide() end
    unfit(tip, state)
    if state.alpha ~= nil then
        if not keepNativeAlpha then pcall(tip.SetAlpha, tip, state.alpha) end
        state.alpha = nil
    end
end

local function comparisonRequested(tip)
    if config().blastaCompare == false then return false end
    local first, second
    if tip == GameTooltip then first, second = ShoppingTooltip1, ShoppingTooltip2
    elseif tip == ItemRefTooltip then first, second = ItemRefShoppingTooltip1, ItemRefShoppingTooltip2
    else return comparisonFrames(tip) ~= nil end
    return (first and first:IsShown()) or (second and second:IsShown())
        or (IsShiftKeyDown and IsShiftKeyDown())
        or (C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("alwaysCompareItems"))
end

local function tooltipOwner(tip)
    return tip and tip.GetOwner and plain(tip:GetOwner())
end

local function auctionRecipeOwner(tip, state)
    if tip ~= GameTooltip or not state.data or plain(state.data.type) ~= types.Item then return end
    local auction = _G.AuctionHouseFrame or _G.AuctionFrame
    if not auction or not auction:IsShown() or not (C_Item and C_Item.GetItemInfoInstant) then return end
    local owner = tooltipOwner(tip)
    local parent = owner
    while parent and parent ~= auction do
        parent = parent.GetParent and plain(parent:GetParent())
    end
    if parent ~= auction then return end

    local id = plain(state.data.id) or plain(Tip.ItemLink(tip, state.data))
    if type(id) ~= "number" and type(id) ~= "string" then return end
    local ok, _, _, _, _, _, class = pcall(C_Item.GetItemInfoInstant, id)
    local recipe = Enum and Enum.ItemClass and Enum.ItemClass.Recipe or 9
    if ok and plain(class) == recipe then return owner end
end

-- Auction rows refill the primary tooltip and the shopping tooltips separately.
-- Keep the entire recipe hover on one renderer through those rebuilds.
local function nativeAuctionRecipe(tip)
    local root = comparisonFrames(tip) or tip
    local state = states[root]
    return state and state.auctionRecipeOwner and state.auctionRecipeOwner == tooltipOwner(root)
end

local corners = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 },
    LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 }, RIGHT = { 1, 0.5 },
    BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

local function nativePosition(tip)
    local ok, x, y, w, h = pcall(tip.GetRect, tip)
    x, y, w, h = plain(x), plain(y), plain(w), plain(h)
    local pointOK, point, relative, relativePoint, dx, dy = pcall(tip.GetPoint, tip, 1)
    point, relative, relativePoint, dx, dy = plain(point), plain(relative), plain(relativePoint), plain(dx), plain(dy)
    local scale = plain(tip:GetEffectiveScale())
    if ok and x and y and w and h and scale and w > 0 and h > 0 and (x ~= 0 or y ~= 0)
        and x + w > 0 and y + h > 0 then
        point = pointOK and corners[point] and point or "BOTTOMRIGHT"
        local corner = corners[point]
        return point, UIParent, "BOTTOMLEFT", x + corner[1] * w, y + corner[2] * h
    end
    if x == 0 and y == 0 then return end
    if pointOK and corners[point] and relative and relative ~= tip and corners[relativePoint]
        and type(dx) == "number" and type(dy) == "number" and (relative ~= UIParent or relativePoint ~= "BOTTOMLEFT"
            or dx > 0 or dy > 0) then
        return point, relative, relativePoint, dx, dy
    end
end

local function setPanelPoint(panel, point, relative, relativePoint, x, y)
    if panel.anchorPoint == point and panel.anchorFrame == relative and panel.anchorRelativePoint == relativePoint
        and panel.anchorX == x and panel.anchorY == y then return end
    panel:ClearAllPoints()
    panel:SetPoint(point, relative, relativePoint, x, y)
    panel.anchorPoint, panel.anchorFrame, panel.anchorRelativePoint = point, relative, relativePoint
    panel.anchorX, panel.anchorY = x, y
end

-- A card hanging on its hidden game tooltip stays where it is when the
-- tooltip goes: the game drops the hidden tooltip's position then, and a card
-- still held (a refill's grace, its fade) would fall with it to the bottom left
-- corner, over the chat. Pinned to the screen spot it has; the next place
-- hangs it on the tooltip again.
local function pinPanel(panel)
    if not (panel and panel:IsShown()) then return end
    local left, bottom = panel:GetLeft(), panel:GetBottom()
    if type(left) ~= "number" or type(bottom) ~= "number" then return end
    panel:ClearAllPoints()
    panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
    panel.anchorPoint, panel.anchorFrame, panel.anchorRelativePoint = nil, nil, nil
    panel.anchorX, panel.anchorY = nil, nil
end

-- A tooltip its owner anchored to itself (SetOwner(row, "ANCHOR_RIGHT"): the
-- profession window's recipes, loot rows...) gets the card at the same corner
-- of the owner, so it grows away from the owner like DaylightUI's tooltip.
-- Copying the hidden tooltip's spot instead put the wider card back over the
-- owner. The anchors whose corners are sure come from the anchor type; others
-- from where the hidden tooltip touches its owner.
local OWNER_ANCHORS = {
    ANCHOR_RIGHT = { "BOTTOMLEFT", "TOPRIGHT" }, ANCHOR_LEFT = { "BOTTOMRIGHT", "TOPLEFT" },
    ANCHOR_TOP = { "BOTTOM", "TOP" }, ANCHOR_BOTTOM = { "TOP", "BOTTOM" },
}
local FREE_ANCHORS = { ANCHOR_NONE = true, ANCHOR_CURSOR = true, ANCHOR_PRESERVE = true,
    ANCHOR_CURSOR_LEFT = true, ANCHOR_CURSOR_RIGHT = true }
local MIRRORED = { TOPLEFT = "TOPRIGHT", TOPRIGHT = "TOPLEFT", BOTTOMLEFT = "BOTTOMRIGHT",
    BOTTOMRIGHT = "BOTTOMLEFT", LEFT = "RIGHT", RIGHT = "LEFT" }

-- A frame's rectangle in UIParent's units (nil if unknown or secret).
local function rectOf(frame)
    if type(frame) ~= "table" or not frame.GetRect then return nil end
    local ok, x, y, w, h = pcall(frame.GetRect, frame)
    x, y, w, h = plain(x), plain(y), plain(w), plain(h)
    local s = plain(frame:GetEffectiveScale())
    local u = UIParent:GetEffectiveScale()
    if not (ok and type(x) == "number" and type(y) == "number" and type(w) == "number" and type(h) == "number"
        and type(s) == "number" and s > 0 and w > 0 and h > 0) then return nil end
    local k = s / u
    return x * k, y * k, w * k, h * k
end

local function touchingCorners(tip, owner)
    local tx, ty, tw, th = rectOf(tip)
    local ox, oy, ow, oh = rectOf(owner)
    if not (tx and ox) then return nil end
    local best, bestPoint, bestRelative = 2 -- under 2 units counts as touching
    for point, c in pairs(corners) do
        local px, py = tx + c[1] * tw, ty + c[2] * th
        for relative, r in pairs(corners) do
            -- a corner on the owner's far side: the tooltip sits beside it
            if point ~= "CENTER" and relative ~= "CENTER" and point ~= relative then
                local d = math.abs(px - (ox + r[1] * ow)) + math.abs(py - (oy + r[2] * oh))
                if d < best then best, bestPoint, bestRelative = d, point, relative end
            end
        end
    end
    return bestPoint, bestRelative
end

-- Widths of the comparison cards that hang off this card.
local function comparisonWidth(tip)
    local need = 0
    local pair = tip == GameTooltip and { ShoppingTooltip1, ShoppingTooltip2 }
        or tip == ItemRefTooltip and { ItemRefShoppingTooltip1, ItemRefShoppingTooltip2 } or {}
    for _, shop in ipairs(pair) do
        local state = shop and states[shop]
        local panel = state and state.panel
        if panel and panel:IsShown() then need = need + panel:GetWidth() * panel:GetScale() + 6 end
    end
    return need
end

local function ownerPosition(tip, panel)
    local owner = tooltipOwner(tip)
    if type(owner) ~= "table" or owner == UIParent or not owner.GetLeft then return nil end
    local anchor = tip.GetAnchorType and plain(tip:GetAnchorType())
    if type(anchor) ~= "string" or FREE_ANCHORS[anchor] then return nil end
    local point, relative
    local known = OWNER_ANCHORS[anchor]
    if known then point, relative = known[1], known[2] else point, relative = touchingCorners(tip, owner) end
    if not point then return nil end
    -- Beside the owner: the side with room for the card and its comparison
    -- cards, as DaylightUI turns its own tooltip (Tip.FitSide).
    local right = point:find("LEFT") and relative:find("RIGHT")
    local left = point:find("RIGHT") and relative:find("LEFT")
    if right or left then
        local ox, _, ow = rectOf(owner)
        local screen = UIParent:GetWidth()
        if ox and screen then
            local need = panel:GetWidth() * panel:GetScale() + comparisonWidth(tip)
            local roomRight, roomLeft = screen - (ox + ow), ox
            local room, other = right and roomRight or roomLeft, right and roomLeft or roomRight
            if room < need and other > room then point, relative = MIRRORED[point], MIRRORED[relative] end
        end
    end
    -- The card's scale is the tooltip's; SetPoint offsets are in its units.
    return point, owner, relative, 0, 0
end

-- Comparison cards: in a row beside the main card, away from what was
-- hovered, on the side with room for all of them. The game picks the compare
-- tooltips' side once, from the hidden tooltips' size before they were padded
-- to the cards, which let wide cards run into the screen edge and over each
-- other. Their hidden tooltips are still padded, so DaylightUI's own side
-- check for the main tooltip counts their real width.
local function placeComparison(tip, panel, main, first, second)
    local parent = states[main] and states[main].panel
    if not (parent and parent:IsShown()) then return false end
    local state = states[tip]
    if state then fitNative(tip, panel, state) end
    local previous = tip == second and first and states[first] and states[first].panel
    if previous and not previous:IsShown() then previous = nil end
    local otherTip = tip == first and second or first
    local other = otherTip and states[otherTip] and states[otherTip].panel
    if other and not other:IsShown() then other = nil end
    local left, bottom, width, height = rectOf(parent)
    if not left then return false end
    local right, top = left + width, bottom + height
    local scale, gap = panel:GetScale(), 6
    local cardWidth, cardHeight = panel:GetWidth() * scale, panel:GetHeight() * scale
    local otherWidth = other and other:GetWidth() * other:GetScale() or 0
    local otherHeight = other and other:GetHeight() * other:GetScale() or 0
    local roomRight, roomLeft = UIParent:GetWidth() - right, left
    local owner = tooltipOwner(main)
    local ox, _, ow = rectOf(owner)
    local onRight = main == ItemRefTooltip or owner == UIParent or not ox or right > ox + ow + 1
    local need = cardWidth + otherWidth + (other and 2 or 1) * gap
    local room, opposite = onRight and roomRight or roomLeft, onRight and roomLeft or roomRight
    if room < need and opposite > room then onRight = not onRight end
    room = onRight and roomRight or roomLeft

    local x, y = left, top
    if room >= need then
        local offset = gap + (previous and otherWidth + gap or 0)
        x = onRight and right + offset or left - offset - cardWidth
    elseif room >= math.max(cardWidth, otherWidth) + gap then
        local stackHeight = cardHeight + (other and otherHeight + gap or 0)
        x = onRight and right + gap or left - gap - cardWidth
        y = math.min(UIParent:GetHeight(), math.max(top, stackHeight))
        if previous then y = y - otherHeight - gap end
    else
        local aboveRoom = UIParent:GetHeight() - top
        local stackHeight = cardHeight + gap + (other and otherHeight + gap or 0)
        local offset = gap + (previous and otherHeight + gap or 0)
        y = bottom < stackHeight and aboveRoom > bottom and top + offset + cardHeight or bottom - offset
        x = math.min(left, math.max(0, UIParent:GetWidth() - cardWidth))
    end
    setPanelPoint(panel, "TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    return true
end

local function screenPosition(left, bottom, width, height)
    if not left or left + width <= 0 or bottom + height <= 0
        or left >= UIParent:GetWidth() or bottom >= UIParent:GetHeight() then return false end
    -- During a reset the client can report a rectangle just inside the origin.
    return math.abs(left) > 1 or math.abs(bottom) > 1
end

local function place(tip, panel)
    local main, first, second = comparisonFrames(tip)
    local parent = main and states[main] and states[main].panel
    if parent and parent:IsShown() then return placeComparison(tip, panel, main, first, second) end
    local state = states[tip]
    -- A tooltip with no place yet (being set up again): the card stays put
    -- rather than follow it to the screen's corner.
    local nativeLeft, nativeBottom, nativeWidth, nativeHeight = rectOf(tip)
    -- DaylightUI also parks muted tooltips outside the screen. A clamped
    -- replacement would turn those coordinates into the bottom-left corner.
    if nativeLeft and not screenPosition(nativeLeft, nativeBottom, nativeWidth, nativeHeight) then return false end
    if nativeLeft and tip:GetNumPoints() > 0
        and state and fitNative(tip, panel, state) then
        -- The card takes the tooltip's spot on the screen, read each frame,
        -- but never hangs on the tooltip itself: a tooltip being set up again
        -- loses its place for a moment, and a card hanging on it went along to
        -- the screen's bottom left corner.
        local left, bottom, width, height = rectOf(tip)
        if not screenPosition(left, bottom, width, height) then return false end
        if panel:GetScale() > 0 then
            local k = 1 / panel:GetScale()
            local top = bottom + height
            setPanelPoint(panel, "TOPLEFT", UIParent, "BOTTOMLEFT",
                math.floor(left * k * 100 + 0.5) / 100, math.floor(top * k * 100 + 0.5) / 100)
            return true
        end
    end
    local point, relative, relativePoint, x, y = ownerPosition(tip, panel)
    if not point then point, relative, relativePoint, x, y = nativePosition(tip) end
    if not point then return false end
    if relative ~= UIParent or relativePoint ~= "BOTTOMLEFT" then
        local left, bottom, width, height = rectOf(relative)
        if not left or (relative ~= UIParent and left == 0 and bottom == 0) then return false end
        local corner = corners[relativePoint]
        local k = 1 / panel:GetScale()
        x, y = (left + corner[1] * width) * k + x, (bottom + corner[2] * height) * k + y
    end
    local corner, scale = corners[point], panel:GetScale()
    local width, height = panel:GetWidth() * scale, panel:GetHeight() * scale
    if not screenPosition(x * scale - corner[1] * width, y * scale - corner[2] * height, width, height) then
        return false
    end
    setPanelPoint(panel, point, UIParent, "BOTTOMLEFT", x, y)
    return true
end

local function handled(tip)
    if tip == GameTooltip or tip == ItemRefTooltip then return true end
    -- The tooltip DaylightUI keeps for buffs and debuffs (it skins and scales
    -- it like the others). The aura buttons the client draws itself show a
    -- tooltip of the client's own instead, which no addon can reach.
    if tip ~= nil and tip == _G.BuffFrameTooltip then return true end
    return config().blastaCompare ~= false and (tip == ShoppingTooltip1 or tip == ShoppingTooltip2
        or tip == ItemRefShoppingTooltip1 or tip == ItemRefShoppingTooltip2)
end

local function refresh(tip, state)
    local hidden = state.data and plain(state.data.type) == types.Unit and Tip.HideNow and Tip.HideNow(tip)
    if not (allowed(tip) and handled(tip)) or hidden or nativeAuctionRecipe(tip) then
        restore(tip, state, hidden)
        return
    end
    local root = comparisonFrames(tip) or tip
    local owner = tooltipOwner(root)
    if state.refill and owner and state.owner and owner ~= state.owner then state.refill = nil end
    if not (state.data and tip:IsShown()) then
        if not state.refill then restore(tip, state) end
        return
    end
    local alpha = state.alpha or plain(tip:GetAlpha())
    if not alpha or alpha <= 0 then state.awaitAlpha = true; return end
    state.awaitAlpha = nil
    local ok, model = pcall(modelFor, tip, state.data)
    state.lineCount = plain(tip:NumLines())
    local itemID = plain(state.data.id)
    if not ok or not model then
        if not state.refill or (state.itemID and itemID and state.itemID ~= itemID) then restore(tip, state) end
        return
    end
    local sameOwner = state.owner == owner
    state.owner, state.itemID, state.refill = owner, itemID, nil
    local panel = state.panel
    if not panel then
        panel = newPanel(UIParent)
        if tip == ItemRefTooltip and DUI.Widgets and DUI.Widgets.Close then
            -- Blasta hides the original tooltip, including its close button.
            panel.close = DUI.Widgets.Close(panel, function() tip:Hide() end, 18, 10)
        end
        panel:SetClampedToScreen(true)
        state.panel = panel
    end
    local strata, level, scale = plain(tip:GetFrameStrata()), plain(tip:GetFrameLevel()), plain(tip:GetEffectiveScale())
    strata, level = strata or "TOOLTIP", (level or 0) + 2
    local parentScale = UIParent:GetEffectiveScale()
    scale = type(scale) == "number" and scale > 0 and scale / parentScale or state.scale or 1
    if state.strata ~= strata then panel:SetFrameStrata(strata); state.strata = strata end
    if state.level ~= level then panel:SetFrameLevel(level); state.level = level end
    if state.scale ~= scale then panel:SetScale(scale); state.scale = scale end
    if not place(tip, panel) and not (sameOwner and state.alpha and panel:IsShown()) then
        local left, bottom, width, height = rectOf(owner)
        if model.kind == "Spell" and owner ~= UIParent and screenPosition(left, bottom, width, height) then
            local k = 1 / panel:GetScale()
            setPanelPoint(panel, "BOTTOM", UIParent, "BOTTOMLEFT", (left + width / 2) * k, (bottom + height) * k + 6)
        else
            state.awaitPosition = true
            restore(tip, state)
            return
        end
    end
    state.awaitPosition = nil
    local fingerprint = { model.title, model.subtitle or "", tostring(model.icon or ""), model.binding or "",
        tostring(model.level or ""), table.concat(model.color, ","), model.requirement or "",
        table.concat(model.requirementColor or {}, ","), tostring(model.health or ""), model.unit or "", model.rank or "",
        model.equipped and "equipped" or "" }
    fingerprint[#fingerprint + 1] = model.schoolLabel or ""
    fingerprint[#fingerprint + 1] = model.iconColor and table.concat(model.iconColor, ",") or ""
    for _, stat in ipairs(model.stats) do fingerprint[#fingerprint + 1] = stat.label .. ":" .. statValue(stat) end
    for _, row in ipairs(model.lines) do
        fingerprint[#fingerprint + 1] = row.text
        fingerprint[#fingerprint + 1] = row.right or ""
        fingerprint[#fingerprint + 1] = row.section .. ":" .. table.concat(row.color, ",")
        fingerprint[#fingerprint + 1] = row.rightColor and table.concat(row.rightColor, ",") or ""
        fingerprint[#fingerprint + 1] = tostring(row.icon or "")
    end
    local signature = table.concat(fingerprint, "\31")
    if state.fading then
        state.fading = nil
        panel:SetAlpha(1)
    end
    if state.signature ~= signature or state.revision ~= revision then
        render(panel, model)
        state.signature, state.revision = signature, revision
        state.fitTried = nil
        -- Its new size can change the side it fits on.
        pcall(place, tip, panel)
    else
        panel:Show()
    end
    state.alpha = alpha
    if not pcall(tip.SetAlpha, tip, 0) then restore(tip, state) end
end

local tooltipOrder = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ItemRefShoppingTooltip1",
    "ShoppingTooltip2", "ItemRefShoppingTooltip2", "BuffFrameTooltip" }
local function flush()
    queued = false
    for _, name in ipairs(tooltipOrder) do
        local tip = _G[name]
        local state = states[tip]
        if state and state.dirty then
            state.dirty = nil
            if not pcall(refresh, tip, state) then restore(tip, state) end
        end
    end
    for i = 3, #tooltipOrder do
        local tip = _G[tooltipOrder[i]]
        local state = states[tip]
        if state and state.alpha and state.panel and not state.refill then
            if not pcall(place, tip, state.panel) then restore(tip, state) end
        end
    end
end

local function schedule(state)
    state.dirty = true
    if not queued then queued = true; C_Timer.After(0, flush) end
end

local function keepNativeHidden(tip, state)
    if not state.alpha and not state.awaitAlpha then return end
    if not allowed(tip) or not handled(tip) or nativeAuctionRecipe(tip) then
        if state.alpha then restore(tip, state) end
        return
    end
    if state.alpha then
        if plain(tip:GetAlpha()) ~= 0 and not pcall(tip.SetAlpha, tip, 0) then restore(tip, state) end
    elseif state.awaitAlpha and (plain(tip:GetAlpha()) or 0) > 0 then
        state.awaitAlpha = nil
        schedule(state)
    end
end

local function syncComparisonAlpha(tip)
    local state = tip and states[tip]
    if state and state.alpha and state.panel and state.panel:IsShown() then
        keepNativeHidden(tip, state)
        if state.alpha then
            local root, first, second = comparisonFrames(tip)
            if root then placeComparison(tip, state.panel, root, first, second) end
        end
    end
end

local function syncComparisonPair(root)
    if root == GameTooltip then
        syncComparisonAlpha(ShoppingTooltip1)
        syncComparisonAlpha(ShoppingTooltip2)
    elseif root == ItemRefTooltip then
        syncComparisonAlpha(ItemRefShoppingTooltip1)
        syncComparisonAlpha(ItemRefShoppingTooltip2)
    end
end

-- A macro on an action button (a @mouseover heal...) comes as "Macro": its
-- lines are the spell's, so it reads as that spell. The spell is the one the
-- macro would cast now, from the button's action or the macro itself.
-- Several ways, since clients differ: the current client's GetActionInfo
-- already gives the spell's ID for a spell macro (subtype "spell"); older ones
-- give the macro's index for GetMacroSpell. Last, the spell named in the
-- tooltip's own lines.
local function isSpell(id)
    if type(id) ~= "number" or id <= 0 then return false end
    local name = C_Spell and C_Spell.GetSpellName and plain(C_Spell.GetSpellName(id))
    if name == nil and GetSpellInfo then name = plain((GetSpellInfo(id))) end
    return type(name) == "string" and name ~= ""
end
local function macroIndexSpell(index)
    if type(index) ~= "number" or not GetMacroSpell then return nil end
    local ok, found = pcall(GetMacroSpell, index)
    found = ok and plain(found) or nil
    return isSpell(found) and found or nil
end
local function spellNamed(name)
    if type(name) ~= "string" or name == "" then return nil end
    if C_Spell and C_Spell.GetSpellIDForSpellIdentifier then
        local ok, id = pcall(C_Spell.GetSpellIDForSpellIdentifier, name)
        id = ok and plain(id) or nil
        if isSpell(id) then return id end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, name)
        info = ok and plain(info) or nil
        local id = type(info) == "table" and plain(info.spellID) or nil
        if isSpell(id) then return id end
    end
    if GetSpellInfo then
        local ok, _, _, _, _, _, _, id = pcall(GetSpellInfo, name)
        id = ok and plain(id) or nil
        if isSpell(id) then return id end
    end
end
local function macroSpell(tip, data)
    if types.Macro == nil or type(data) ~= "table" or plain(data.type) ~= types.Macro then return data end
    local spell
    local owner = tooltipOwner(tip)
    local slot = owner and (plain(owner.action) or (owner.GetAttribute and plain(owner:GetAttribute("action"))))
    if type(slot) ~= "number" and owner and owner.CalculateAction then
        local ok, found = pcall(owner.CalculateAction, owner)
        slot = ok and plain(found) or nil
    end
    if type(slot) == "number" and GetActionInfo then
        local ok, kind, id, subType = pcall(GetActionInfo, slot)
        kind, id, subType = ok and plain(kind), ok and plain(id), ok and plain(subType)
        if kind == "macro" then
            if subType == "spell" and isSpell(id) then spell = id end
            spell = spell or macroIndexSpell(id)
        end
    end
    spell = spell or macroIndexSpell(plain(data.id))
    if not spell and tip.GetSpell then
        local ok, name, id = pcall(tip.GetSpell, tip)
        id = ok and plain(id) or nil
        if isSpell(id) then spell = id elseif ok then spell = spellNamed(plain(name)) end
    end
    if not spell then
        -- The spell's name line of the macro's data (the first line where
        -- the client doesn't type its lines).
        local lines = type(data.lines) == "table" and data.lines or nil
        local nameType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.SpellName
        local name
        for i = 1, lines and #lines or 0 do
            local row = lines[i]
            if type(row) == "table" and nameType ~= nil and plain(row.type) == nameType then
                name = plain(row.leftText)
                break
            end
        end
        if not name and nameType == nil and lines and type(lines[1]) == "table" then name = plain(lines[1].leftText) end
        spell = spellNamed(name)
    end
    if not spell then return data end
    return { type = types.Spell, id = spell, lines = data.lines, blastaMacro = true }
end

local function onData(tip, data)
    data = macroSpell(tip, data)
    if not enabled() or not handled(tip) or (tip.IsForbidden and tip:IsForbidden()) then return end
    local state = states[tip]
    if not state then
        state = {}
        states[tip] = state
        local comparison = comparisonFrames(tip) ~= nil
        local function refilling()
            local wasItem = state.data and plain(state.data.type) == types.Item
            state.data = nil
            -- Reward and bag buttons can refill their comparison across
            -- frames. Give an already visible pair one short grace period.
            if state.alpha and (comparison or wasItem) and comparisonRequested(tip) and not nativeAuctionRecipe(tip) then
                if not state.refill then
                    local token = {}
                    state.refill = token
                    C_Timer.After(0.05, function()
                        if state.refill == token then
                            state.refill = nil
                            schedule(state)
                        end
                    end)
                end
            end
            schedule(state)
        end
        local function watch(script, callback)
            return pcall(tip.HookScript, tip, script, function(...)
                if states[tip] == state then callback(...) end
            end)
        end
        local function hidden()
            pinPanel(state.panel)
            -- Its comparison cards hang on this card: pinned with it.
            local _, first, second = comparisonFrames(tip)
            for _, shop in ipairs({ first, second }) do
                local other = shop and states[shop]
                if other then pinPanel(other.panel) end
            end
            refilling()
        end
        if not (watch("OnHide", hidden) and watch("OnTooltipCleared", refilling)
            and watch("OnShow", function()
                keepNativeHidden(tip, state)
                if not state.data and state.refill and tip.GetPrimaryTooltipData then
                    local ok, data = pcall(tip.GetPrimaryTooltipData, tip)
                    data = ok and plain(data) or nil
                    if type(data) == "table" and plain(data.type) == types.Item then state.data = data end
                end
                if state.data then schedule(state) end
            end)
            and (tip == GameTooltip or watch("OnUpdate", function() keepNativeHidden(tip, state) end))) then
            states[tip] = nil
            return
        end
    end
    state.data = type(plain(data)) == "table" and kinds[plain(data.type)] and data or nil
    if tip == GameTooltip then
        local previous = state.auctionRecipeOwner
        state.auctionRecipeOwner = auctionRecipeOwner(tip, state)
        if previous ~= state.auctionRecipeOwner then
            if states[ShoppingTooltip1] then schedule(states[ShoppingTooltip1]) end
            if states[ShoppingTooltip2] then schedule(states[ShoppingTooltip2]) end
        end
    end
    if state.data and plain(state.data.type) ~= types.Item then state.refill = nil end
    schedule(state)
    if not (state.data and plain(data.type) == types.Item) or nativeAuctionRecipe(tip) then return end
    local item = plain(data.hyperlink) or plain(data.id)
    local owner = tooltipOwner(tip)
    if item == nil or (state.retryItem == item and state.retryOwner == owner) then return end
    state.retryItem, state.retryOwner = item, owner
    C_Timer.After(0.12, function()
        if state.data and plain(state.data.type) == types.Item and tooltipOwner(tip) == owner
            and (plain(state.data.hyperlink) or plain(state.data.id)) == item then schedule(state) end
    end)
end

-- DaylightUI 2.0 fades a tooltip out with a copy of the game's own lines
-- (its ghost). Under a Blasta card that copy showed the hidden game tooltip
-- for a moment, a little off to the side. The Blasta card fades out itself
-- instead, the same way and for the same time.
local Ghost = mod.ns.TipGhost
local function fadeOut(state)
    local panel = state.panel
    local M = DUI.Motion
    if not (M and M.On and M.Tween and M.On()) or InCombatLockdown() then return end
    local run, from = {}, panel:GetAlpha()
    state.fading = run
    M.Tween(run, 0, 1, M.NORMAL, function(e)
        if state.fading == run then panel:SetAlpha(from * (1 - e)) end
    end, function()
        if state.fading ~= run then return end
        state.fading = nil
        panel:Hide()
        panel:SetAlpha(1)
    end)
end
if Ghost and Ghost.Take then
    local take = Ghost.Take
    function Ghost.Take(tip, ...)
        local state = states[tip]
        if state and state.alpha and state.panel and state.panel:IsShown() then
            -- A window refilling its tooltip (the profession window does)
            -- hides and shows it in one go: the card stays. Only a tooltip
            -- still gone a frame later fades.
            local token = {}
            state.fading = token
            pinPanel(state.panel)
            C_Timer.After(0, function()
                if state.fading ~= token then return end
                state.fading = nil
                if tip:IsShown() and state.alpha then return end
                if state.panel:IsShown() then fadeOut(state) end
            end)
            return
        end
        return take(tip, ...)
    end
end

-- DaylightUI 2.0's own rich cards stay off under Blasta's: one card at a time.
local Rich = mod.ns.Rich
if Rich and Rich.On then
    local on = Rich.On
    function Rich.On(tip, ...)
        if enabled() and handled(tip) then return false end
        return on(tip, ...)
    end
end

local fadeIn = Tip.FadeIn
function Tip.FadeIn(tip, ...)
    local state = states[tip]
    if allowed(tip) and state and state.alpha and handled(tip) and not nativeAuctionRecipe(tip) then return end
    return fadeIn(tip, ...)
end

if Tip.Mute then
    hooksecurefunc(Tip, "Mute", function(tip)
        local state = states[tip]
        if state then restore(tip, state, true) end
    end)
end

-- GetPrimaryTooltipData builds a new table on every call. While a tooltip
-- shows content without data, probe again only after its owner or line count
-- changed, and otherwise at most every 0.1 seconds.
local PROBE_INTERVAL = 0.1
local function probeSpellData(tip, state)
    local now = GetTime()
    local lines, owner = plain(tip:NumLines()), tooltipOwner(tip)
    if state.probeLines == lines and state.probeOwner == owner and now < (state.nextProbe or 0) then return end
    state.probeLines, state.probeOwner, state.nextProbe = lines, owner, now + PROBE_INTERVAL
    local ok, data = pcall(tip.GetPrimaryTooltipData, tip)
    data = ok and macroSpell(tip, plain(data))
    if type(data) == "table" and kinds[plain(data.type)] == "Spell" then onData(tip, data) end
end

hooksecurefunc(Tip, "OnUpdate", function(tip)
    local state = states[tip]
    if state and not state.data and tip.GetPrimaryTooltipData and allowed(tip) then
        probeSpellData(tip, state)
    end
    if state and state.awaitAlpha and (plain(tip:GetAlpha()) or 0) > 0 then
        state.awaitAlpha = nil
        schedule(state)
    end
    if state and state.awaitPosition and state.panel and place(tip, state.panel) then
        state.awaitPosition = nil
        schedule(state)
    end
    if state and state.data and plain(state.data.type) == types.Item and state.lineCount then
        local now = GetTime()
        if not state.nextLineCheck or now >= state.nextLineCheck then
            state.nextLineCheck = now + 0.05
            local count = plain(tip:NumLines())
            if count and count ~= state.lineCount then
                state.lineCount = count
                schedule(state)
            end
        end
    end
    if state and state.alpha then
        if not allowed(tip) or nativeAuctionRecipe(tip) then restore(tip, state)
        else
            local panel = state.panel
            if panel then pcall(place, tip, panel) end
            if plain(tip:GetAlpha()) ~= 0 then pcall(tip.SetAlpha, tip, 0) end
        end
    end
    -- Comparison cards can be shown again without a shopping tooltip
    -- OnShow or OnUpdate. The root has a reliable before-draw update.
    syncComparisonPair(tip)
end)

DUI.On("Login", function()
    local processor = TooltipDataProcessor
    if processor and processor.AllTypes then processor.AddTooltipPostCall(processor.AllTypes, onData) end
    local auctionTips = _G.Auctionator and _G.Auctionator.Tooltip
    if auctionTips and auctionTips.ShowTipWithPricingDBKey then
        hooksecurefunc(auctionTips, "ShowTipWithPricingDBKey", function(tip)
            local state = states[tip]
            if state and state.data and plain(state.data.type) == types.Item then schedule(state) end
        end)
    end
    if type(GameTooltip_ShowCompareItem) == "function" then
        -- The client restores alpha on Show(), even when the tooltip was
        -- already shown. Reapply ownership after the whole compare rebuild.
        hooksecurefunc("GameTooltip_ShowCompareItem", syncComparisonPair)
    end
    local quests = extras.Compatible("Quests")
    if quests and quests.Clicks and quests.Clicks.QuestTip then
        hooksecurefunc(quests.Clicks, "QuestTip", function(quest)
            onData(GameTooltip, { type = "blastaQuest", quest = quest })
        end)
    end
    local function repaint()
        for _, state in pairs(states) do schedule(state) end
    end
    DUI.RegisterEvent("MODIFIER_STATE_CHANGED", function(_, key)
        local modifier = config().blastaOriginal
        if key and (key:lower():find(modifier or "alt", 1, true) or key:find("SHIFT", 1, true)) then repaint() end
    end)
    DUI.RegisterEvent("BAG_UPDATE_DELAYED", function()
        local state = states[GameTooltip]
        if state and state.data and plain(state.data.type) == types.Item and IsShiftKeyDown() then schedule(state) end
    end)
    DUI.RegisterEvent("QUEST_LOG_UPDATE", function()
        questProgressCache = nil
        local state = states[GameTooltip]
        if state and state.data and plain(state.data.type) == types.Unit then schedule(state) end
    end)
    DUI.RegisterEvent("PLAYER_REGEN_DISABLED", repaint)
    DUI.RegisterEvent("PLAYER_LEVEL_UP", repaint)
    DUI.RegisterEvent("PLAYER_REGEN_ENABLED", function()
        questProgressCache = nil
        repaint()
    end)
    DUI.On("SettingChanged", function(scope)
        if scope == "Tooltip" then revision = revision + 1; repaint() end
    end)
    DUI.On("StyleChanged", function() revision = revision + 1; repaint() end)
end)

local GREEN, GOLD, GREY = { 0.12, 1, 0.12 }, { 1, 0.82, 0.25 }, { 0.62, 0.64, 0.68 }
-- A sample line with extra fields (small print, a progress bar).
local function row5(text, section, color, right, fields)
    local row = line(text, section, color, right)
    for k, v in pairs(fields or {}) do row[k] = v end
    return row
end

local function sample(kind, second)
    local german = extras.Language == "deDE"
    local function t(de, en) return german and de or en end
    if kind == "spell" then
        local description = t(
            "Belegt Euer Ziel mit Schattenenergie, die alle Gruppenmitglieder 30 Sek. lang um 10 % Eures verursachten Schattenzauberschadens heilt. Ihr erhaltet von Euch selbst 100 % mehr Heilung durch diesen Effekt.",
            "Afflicts your target with Shadow energy, causing all party members to be healed for 10% of any Shadow spell damage you deal for 30 sec. You receive 100% more healing from this effect.")
        local model = { kind = "Spell", title = t("Vampirumarmung", "Vampiric Embrace"), icon = 136230,
            color = { 0.88, 0.90, 0.93 }, schoolLabel = t("Schatten", "Shadow"), schoolColor = { 0.72, 0.50, 1 },
            stats = {
                { value = t("Spontan", "Instant"), label = t("Wirken", "Cast") },
                { value = "20 " .. sampleText("Mana"), label = t("Kosten", "Cost"), cost = true },
                { value = t("30 m", "30 yd"), label = t("Reichweite", "Range") },
                { value = t("30 Sek.", "30 sec"), label = t("Abklingzeit", "Cooldown"), cooldown = true },
            },
            lines = { line(description, "effects") } }
        if config().showIDs then
            model.lines[#model.lines + 1] = line(t("Zauber-ID", "Spell ID"), "spellID", { Style.Accent() }, "15286")
        end
        return model
    elseif kind == "aura" then
        -- A buff: its dispel type as the caption, time left and who cast it.
        return { kind = "Aura", title = t("Inneres Feuer", "Inner Fire"), subtitle = t("Buff · Magie", "Buff · Magic"),
            rank = t("Magie", "Magic"), icon = 135926, color = { 0.2, 0.6, 1 },
            lines = { row5(t("Erhöht die Rüstung um 315. Die nächsten 20 Angriffe gegen euch verursachen Schaden.",
                    "Increases armor by 315. The next 20 attacks against you deal damage."), "effects"),
                row5(t("Verbleibend: 28 Min.", "Time remaining: 28 min"), "values"),
                row5(t("Von: Baja Blasta", "From: Baja Blasta"), "footer", GREY, nil, { small = true }) } }
    elseif kind == "player" then
        -- Another player: class color, guild, faction, PvP and their target.
        return { kind = "Unit", title = sampleText("Blasta sample player"), subtitle = sampleText("Blasta sample player details"),
            color = { 1, 1, 1 }, health = 0.82,
            lines = { row5(t("<Die Morgenröte>", "<The Daybreak>"), "values", { 0.25, 1, 0.25 }),
                row5(t("Horde · PvP", "Horde · PvP"), "values", { 0.85, 0.3, 0.3 }),
                row5(sampleText("Health"), "values", nil, "82%"),
                row5(t("Ziel: ", "Target: ") .. coloredText(t("Du", "You"), { 1, 0.82, 0 }), "footer") } }
    elseif kind == "quest" then
        -- A quest: zone, objectives with their progress, reward money.
        return { kind = "Quest", title = sampleText("Blasta sample quest"), subtitle = t("Stufe 26 · Steinkrallengebirge", "Level 26 · Stonetalon Mountains"),
            icon = 134328, color = { 1, 0.82, 0 },
            lines = { row5(t("Sammelt Pyrophore aus den Elementaren am Ufer und bringt sie zurück.",
                    "Collect pyrophores from the elementals at the shore and bring them back."), "effects"),
                row5(sampleText("Blasta sample objective"), "values", nil, "6/10", { bar = 0.6 }),
                row5(t("Getötete Steinwüter", "Stone ragers killed"), "values", nil, "8/8", { bar = 1 }),
                row5(t("Belohnung", "Reward"), "price", nil, DUI.MoneyString and DUI.MoneyString(3500) or "35s") } }
    elseif kind == "recipe" then
        -- A recipe: the skill it needs, what it makes, the reagents.
        return { kind = "Item", icon = 134939, color = { 0.12, 1, 0 },
            title = t("Muster: Grünes Leinenhemd", "Pattern: Green Linen Shirt"), subtitle = t("Rezept · Schneiderei", "Recipe · Tailoring"),
            requirement = t("Benötigt Schneiderei (40)", "Requires Tailoring (40)"),
            lines = { row5(t("Benutzen: Lehrt Euch, wie man ein Grünes Leinenhemd herstellt.", "Use: Teaches you how to sew a Green Linen Shirt."), "effects", GREEN),
                row5(t("Grünes Leinenhemd", "Green Linen Shirt"), "values"),
                row5(t("Benötigt: Leinenstoff (3), Grobes Garn, Grüner Farbstoff", "Requires: Linen Cloth (3), Coarse Thread, Green Dye"), "values",
                    { 0.70, 0.72, 0.76 }, nil, { small = true }),
                row5(sampleText("Sell price"), "price", nil, DUI.MoneyString and DUI.MoneyString(50) or "50c") } }
    elseif kind == "questItem" then
        -- A quest item: it starts a quest, and has no price.
        return { kind = "Item", icon = 133470, color = { 0.88, 0.90, 0.93 },
            title = t("Eingerissene Schatzkarte", "Torn Treasure Map"), subtitle = t("Questgegenstand", "Quest Item"),
            binding = sampleText("Binds when picked up"),
            lines = { row5(t("Dieser Gegenstand startet eine Quest", "This Item Begins a Quest"), "effects", GOLD),
                row5(t("Benötigt für", "Needed for"), "footer", GOLD, t("1 Quest", "1 quest")),
                row5(t("Quelle", "Source"), "origin", GOLD, t("Defias-Bandit", "Defias Bandit")) } }
    elseif kind == "enemy" then
        return { title = sampleText("Blasta sample enemy"), subtitle = sampleText("Blasta sample enemy details"),
            color = { 0.93, 0.45, 0.33 }, health = 1,
            lines = { line(sampleText("Health"), "values", nil, "100%"),
                line(t("Zielt auf: Baja Blasta", "Targeting: Baja Blasta"), "footer") } }
    end
    -- An item with one line of every kind, so each text size shows somewhere.
    local item = { kind = "Item", equipped = second == true, icon = 135350, color = { 0.58, 0.78, 1 },
        title = sampleText(second and "Blasta sample equipped" or "Blasta sample item"),
        subtitle = sampleText("Blasta sample item type"), binding = sampleText("Binds when picked up"),
        level = second and 23 or 29, lines = {} }
    local slot = t("Zweihändig", "Two-Hand")
    local slotInk = RichItems and RichItems.SLOT_COLORS and RichItems.SLOT_COLORS.INVTYPE_2HWEAPON
    item.itemTypeColor = RichItems and RichItems.WEAPON_COLOR
    item.levelColor = RichItems and RichItems.Lift and RichItems.Lift(item.color) or item.color
    local minLevel = second and 18 or 24
    levelRequirementInk(item, minLevel)
    equipmentFacts(item, t("Stab", "Staff"), slot, slotInk and coloredText(slot, slotInk) or slot, minLevel, 2)
    local lines = item.lines
    local function add(text, section, color, right, fields)
        local row = line(text, section, color, right)
        for k, v in pairs(fields or {}) do row[k] = v end
        lines[#lines + 1] = row
    end
    add(second and t("17,7 Schaden pro Sekunde", "17.7 damage per second")
        or t("29,0 Schaden pro Sekunde", "29.0 damage per second"), "dps")
    add(second and t("24 – 42 Schaden  ·  Tempo 1,90", "24 – 42 Damage  ·  Speed 1.90")
        or t("32 – 48 Schaden  ·  Tempo 2,40", "32 – 48 Damage  ·  Speed 2.40"), "dps", { 0.70, 0.72, 0.76 }, nil, { small = true })
    add(t("+5 Ausdauer", "+5 Stamina"), "values")
    add(t("+4 Intelligenz", "+4 Intellect"), "values")
    add(t("+12 Zaubermacht", "+12 Spell Power"), "effects", GREEN, nil, { sizeKind = "bonus" })
    add(t("Verzaubert: +3 Beweglichkeit", "Enchanted: +3 Agility"), "effects", GREEN, nil, { sizeKind = "enchant" })
    add(t("Benutzen: Stellt 120 Mana wieder her.", "Use: Restores 120 mana."), "effects", GREEN)
    add(t("Benötigt für", "Needed for"), "footer", GOLD, t("2 Quests", "2 quests"))
    if kind == "compare" and second then
        add(sampleText("Stat changes"), "comparison")
        add(t("+2 Ausdauer", "+2 Stamina"), "comparison", { 0.48, 0.91, 0.58 }, t("−4 Intelligenz", "−4 Intellect"),
            { columns = true, rightColor = { 1, 0.45, 0.4 } })
    end
    add(sampleText("Disenchant results"), "disenchant")
    add(sampleText("Blasta sample dust"), "disenchant", nil, "75% · 4–6")
    add(sampleText("Sell price"), "price", nil, DUI.MoneyString(12500))
    add(t("Quelle", "Source"), "origin", GOLD, t("Die Todesminen", "The Deadmines"))
    add(t("Gegenstands-ID 2176", "Item ID 2176"), "origin", GREY, nil, { small = true })
    return item
end

-- Which text size a shown line takes, the same way render's sizeOf picks it.
local function sizeKeyOf(line)
    if line.small then return "blastaMetaSize", "Small print" end
    if line.sizeKind == "bonus" then return "blastaBonusSize", "Bonus stats" end
    if line.sizeKind == "enchant" then return "blastaEnchantSize", "Enchantments" end
    if line.section == "values" then return "blastaStatSize", "Base stats" end
    if line.section == "effects" then return "blastaEffectSize", "Effects and descriptions" end
    return "blastaBodySize", "Everything else"
end

local GAP, CHIPS, CHIP_ROW = 12, 470, 30   -- between two tooltips; room the view chips take
-- The kinds the preview shows. Clicking "Item" again while it's showing
-- goes through the item kinds: an ordinary item, a recipe, a quest item.
local VIEWS = { { key = "item", label = "Item" }, { key = "mine", label = "Your item" },
    { key = "spell", label = "Spell" }, { key = "aura", label = "Buff" }, { key = "player", label = "Player" },
    { key = "enemy", label = "Enemy" }, { key = "quest", label = "Quest" } }
local ITEM_KINDS = { { key = "item", label = "Item" }, { key = "recipe", label = "Recipe" }, { key = "questItem", label = "Quest item" } }
local KNOWN_VIEW = {}
for _, v in ipairs(VIEWS) do KNOWN_VIEW[v.key] = true end
local itemKind = 1   -- which of ITEM_KINDS, kept for the session
local ZOOM_MIN, ZOOM_MAX, ZOOM_STEP = 0.6, 1.6, 0.1
local zoom = 1   -- the strip's Zoom, kept for the session

-- "Your item": something you wear, read through a hidden tooltip of Blasta's
-- own the same way a real tooltip is, so the preview shows your real gear.
-- Weapon first, then chest, head, off hand and shoulders.
local MY_SLOTS = { 16, 5, 1, 17, 3 }
local scanTip
local function myItem(slots)
    if not (CreateFrame and GetInventoryItemLink) then return end
    scanTip = scanTip or CreateFrame("GameTooltip", "BlastaPreviewScanTooltip", UIParent, "GameTooltipTemplate")
    for _, slot in ipairs(slots or MY_SLOTS) do
        if GetInventoryItemLink("player", slot) then
            scanTip:SetOwner(UIParent, "ANCHOR_NONE")
            scanTip:SetInventoryItem("player", slot)
            local data = scanTip.GetPrimaryTooltipData and scanTip:GetPrimaryTooltipData()
            if type(data) ~= "table" and C_TooltipInfo and C_TooltipInfo.GetInventoryItem then
                data = C_TooltipInfo.GetInventoryItem("player", slot)
            end
            local ok, model = false, nil
            if type(data) == "table" then ok, model = pcall(modelFor, scanTip, data) end
            scanTip:Hide()
            if ok and model then return model end
        end
    end
end

-- The other views read real tooltips too, through the same hidden tooltip,
-- so the preview shows exactly what Blasta draws in the game: something from
-- your bags, a spell from your bars, one of your buffs, yourself, your
-- target, a quest from your log. Only when there's nothing of that kind (no
-- buff, no hostile target) does the made-up sample stand in.
local function scan(set, info)
    if not CreateFrame then return end
    scanTip = scanTip or CreateFrame("GameTooltip", "BlastaPreviewScanTooltip", UIParent, "GameTooltipTemplate")
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    local shown = pcall(set, scanTip)
    local data = shown and scanTip.GetPrimaryTooltipData and scanTip:GetPrimaryTooltipData()
    if type(data) ~= "table" and info then
        local ok, got = pcall(info)
        if ok then data = got end
    end
    local ok, model = false, nil
    if shown and type(data) == "table" and plain(scanTip:NumLines()) then ok, model = pcall(modelFor, scanTip, data) end
    scanTip:Hide()
    if ok and model then return model end
end

-- Bag items by kind: equipment (the best quality first), recipes (class 9),
-- quest items (class 12).
local function bagItem(want)
    local container = C_Container
    if not (container and container.GetContainerNumSlots and C_Item and C_Item.GetItemInfoInstant) then return end
    local best, bestBag, bestSlot = -1, nil, nil
    for bag = 0, 4 do
        for slot = 1, container.GetContainerNumSlots(bag) or 0 do
            local info = container.GetContainerItemInfo(bag, slot)
            local link = type(info) == "table" and plain(info.hyperlink)
            if type(link) == "string" then
                local _, _, _, equipLoc, _, classID = C_Item.GetItemInfoInstant(link)
                local quality = plain(info.quality) or 0
                local match = (want == "recipe" and classID == 9) or (want == "questItem" and classID == 12)
                    or (want == "item" and type(equipLoc) == "string" and equipLoc ~= "" and equipLoc ~= "INVTYPE_BAG")
                if match and quality > best then best, bestBag, bestSlot = quality, bag, slot end
            end
        end
    end
    if bestBag then
        return scan(function(t) t:SetBagItem(bestBag, bestSlot) end,
            C_TooltipInfo and C_TooltipInfo.GetBagItem and function() return C_TooltipInfo.GetBagItem(bestBag, bestSlot) end)
    end
end

-- The design sample when available, followed by a spell on your own bar.
local function barSpell()
    local model = scan(function(t) t:SetSpellByID(15286) end,
        C_TooltipInfo and C_TooltipInfo.GetSpellByID and function() return C_TooltipInfo.GetSpellByID(15286) end)
    if model then return model end
    for slot = 1, 72 do
        local kind, id = GetActionInfo and GetActionInfo(slot)
        if kind == "spell" and type(id) == "number" then
            local model = scan(function(t) t:SetSpellByID(id) end,
                C_TooltipInfo and C_TooltipInfo.GetSpellByID and function() return C_TooltipInfo.GetSpellByID(id) end)
            if model then return model end
        end
    end
    local id = DUI.Interrupt and DUI.Interrupt.Spell and DUI.Interrupt.Spell()
    if id then return scan(function(t) t:SetSpellByID(id) end) end
end

local function myBuff()
    for i = 1, 40 do
        local model = scan(function(t) t:SetUnitBuff("player", i) end,
            C_TooltipInfo and C_TooltipInfo.GetUnitBuff and function() return C_TooltipInfo.GetUnitBuff("player", i) end)
        if model then return model end
        if not (C_UnitAuras and C_UnitAuras.GetBuffDataByIndex) then break end
        local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, "player", i)
        if not ok or aura == nil then break end
    end
end

local function unitModel(unit)
    if not (UnitExists and UnitExists(unit)) then return end
    return scan(function(t) t:SetUnit(unit) end,
        C_TooltipInfo and C_TooltipInfo.GetUnit and function() return C_TooltipInfo.GetUnit(unit) end)
end

local function hostileTarget()
    local ok, attack = pcall(UnitCanAttack, "player", "target")
    if ok and not (issecretvalue and issecretvalue(attack)) and attack then return unitModel("target") end
end

local function logQuest()
    local log = C_QuestLog
    if not (log and log.GetNumQuestLogEntries and log.GetInfo) then return end
    for i = 1, log.GetNumQuestLogEntries() or 0 do
        local info = log.GetInfo(i)
        local id = type(info) == "table" and not info.isHeader and plain(info.questID)
        if type(id) == "number" and id > 0 then
            local model = scan(function(t) t:SetHyperlink("quest:" .. id) end)
            if model then
                model.kind = "Quest"
                return model
            end
        end
    end
end

local REAL = {
    item = function() return bagItem("item") end,
    recipe = function() return bagItem("recipe") end,
    questItem = function() return bagItem("questItem") end,
    mine = function() return myItem() end,
    spell = barSpell, aura = myBuff, player = function() return unitModel("player") end,
    enemy = hostileTarget, quest = logQuest,
}
local function previewModel(kind)
    local real = REAL[kind]
    local ok, model = false, nil
    if real then ok, model = pcall(real) end
    if not (ok and model) then
        model = sample(kind == "mine" and "item" or kind)
        if model and not model.light then pcall(daylightInk, model) end
    end
    return model
end

-- The live preview on DaylightUI's Tooltips page. It redraws with every
-- change, even while a slider is dragged. Each line is a hotspot: hover names
-- its text size, a click jumps to that slider. Chips at the top right pick
-- the kind of tooltip. A tall tooltip is scaled down to fit the strip.
function extras.TooltipSample(parent)
    local host = CreateFrame("Frame", nil, parent)
    local first, second = newPanel(host), newPanel(host)
    first.slack, second.slack = 10, 10
    -- DaylightUI redraws a page's preview when a setting changes, not while
    -- its window is resized: follow the strip's width and the window's
    -- height here, so the tooltip grows and shrinks with the window.
    local window = parent.GetParent and parent:GetParent()
    local lastWidth, lastWindow, queued
    local function relayout()
        queued = nil
        if not host:IsVisible() then return end
        -- A full refresh, so the settings below move with the new height.
        local panel = DUI.OptionsPanel
        if panel and panel.Refresh then panel.Refresh()
        elseif parent.Redraw then parent.Redraw(parent:GetWidth(), parent.lastRoom) end
    end
    local function follow()
        if not host:IsVisible() then return end
        local w = parent:GetWidth()
        local h = window and window:GetHeight()
        if w == lastWidth and h == lastWindow then return end
        lastWidth, lastWindow = w, h
        if not queued then
            queued = true
            C_Timer.After(0, relayout)
        end
    end
    -- A new height (a chip picked another kind, a size changed) needs the
    -- settings below to move too: DaylightUI only lays them out again on a
    -- full refresh, so ask for one, once.
    local lastHeight
    local function settle(height)
        if lastHeight and math.abs(height - lastHeight) > 0.5 and not queued then
            queued = true
            C_Timer.After(0, relayout)
        end
        lastHeight = height
    end
    if parent.HookScript then parent:HookScript("OnSizeChanged", follow) end
    if window and window.HookScript then window:HookScript("OnSizeChanged", follow) end
    local view = config().blastaPreview
    if not KNOWN_VIEW[view] then view = "item" end
    local scale = 1
    local T = extras.Translate
    -- DaylightUI outlines a text by its string width, which for a wrapped
    -- line is the whole text on one line, far past the tooltip. Each text
    -- gets a plain frame over just its box instead.
    local boxes = setmetatable({}, { __mode = "k" })
    local function boxOf(region)
        if region:GetObjectType() ~= "FontString" then return region end
        local box = boxes[region]
        if not box then
            box = CreateFrame("Frame", nil, region:GetParent())
            box:EnableMouse(false)
            boxes[region] = box
        end
        local w, h = tonumber(region:GetStringWidth()) or 0, tonumber(region:GetStringHeight()) or 0
        local room = tonumber(region:GetWidth()) or 0
        if room > 0 then w = math.min(w, room) end
        box:ClearAllPoints()
        box:SetSize(math.max(w, 12) + 6, math.max(h, 10) + 4)
        local j = region:GetJustifyH()
        local point = (j == "LEFT" or j == "RIGHT") and j or "CENTER"
        box:SetPoint(point, region, point, j == "LEFT" and -3 or j == "RIGHT" and 3 or 0, 0)
        return box
    end
    local function parts(panel, list)
        if not panel:IsShown() then return end
        local function part(region, label, keys)
            if region and region:IsShown() then
                list[#list + 1] = { region = boxOf(region), label = T(label), keys = keys, scale = scale }
            end
        end
        part(panel.title, "Name", { "blastaTitleSize" })
        part(panel.icon, "Tooltip icon", { "blastaIcon", "blastaItemIconSize", "blastaSpellIconSize" })
        part(panel.subtitle, "Small print", { "blastaMetaSize" })
        part(panel.binding, "Small print", { "blastaMetaSize" })
        part(panel.itemLevel, "Small print", { "blastaMetaSize" })
        for i, line in ipairs(panel.shownLines or {}) do
            local key, label = sizeKeyOf(line)
            if line.section == "dps" and not line.small then key, label = "blastaBodySize", "Everything else" end
            part(panel.rows[i] and panel.rows[i].left, label, { key })
        end
    end
    return {
        frame = host,
        Views = function()
            local out = {}
            -- DaylightUI lays the chips out from the right: last first, so
            -- they read left to right in VIEWS' order.
            for i = #VIEWS, 1, -1 do
                local v = VIEWS[i]
                local label = v.key == "item" and ITEM_KINDS[itemKind].label or v.label
                out[#out + 1] = { key = v.key, label = T(label), on = v.key == view }
            end
            return out
        end,
        SetView = function(key)
            if key == "item" and view == "item" then itemKind = itemKind % #ITEM_KINDS + 1 end
            view = key
        end,
        Zoom = function() return zoom end,
        SetZoom = function(v)
            v = tonumber(v) or 1
            zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, v))
        end,
        zoomRange = { min = ZOOM_MIN, max = ZOOM_MAX, step = ZOOM_STEP },
        Parts = function()
            local list = {}
            parts(first, list)
            parts(second, list)
            return list
        end,
        Refresh = function(width, room)
            if config().blastaStyle ~= "blasta" then
                host:Hide()
                settle(0)
                return 0
            end
            host:Show()
            host:SetScale(1)
            local kind = view == "item" and ITEM_KINDS[itemKind].key or view
            -- Laid out exactly like in the game (no narrower width), then
            -- scaled down to fit below if it's too wide.
            render(first, previewModel(kind))
            second:Hide()
            local natural, span = first:GetHeight(), first:GetWidth()
            -- A little taller than DaylightUI's usual strip is fine for a
            -- tooltip; past that it shrinks, never below 85 %.
            local windowHeight = window and window.GetHeight and tonumber(window:GetHeight()) or 0
            local fit = math.max((tonumber(room) or 0) * 1.5, math.min(620, windowHeight * 0.5), 220)
            -- The strip's Zoom then makes it smaller or larger from there.
            scale = (natural > fit and math.max(0.6, fit / natural) or 1) * zoom
            host:SetScale(scale)
            -- Never wider than the strip either.
            if span * scale > width then scale = math.max(0.4, width / span) end
            host:SetScale(scale)
            local inner = width / scale
            -- Centered, unless the view chips at the top right would cover
            -- it: then it starts at the left, and moves under the chips
            -- only when even that is too narrow.
            local x = math.max(0, (inner - span) / 2)
            local top = 0
            if x + span > inner - CHIPS / scale then
                x = 0
                if span > inner - CHIPS / scale then top = CHIP_ROW / scale end
            end
            host:SetSize(inner, natural + top)
            first:ClearAllPoints()
            first:SetPoint("TOPLEFT", host, "TOPLEFT", x, -top)
            natural = natural + top
            settle(natural * scale)
            return natural * scale
        end,
    }
end

extras.Loaded("BlastaTooltips")
