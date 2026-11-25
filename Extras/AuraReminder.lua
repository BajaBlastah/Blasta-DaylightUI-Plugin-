local ADDON, extras = ...
local DUI = DaylightUI
local L, Style, Motion = extras.Translate, DUI.Style, DUI.Motion
local ROOT, MOVER = "auraReminder", "daylightextras.auras"
local MAX_CUSTOM, COLUMNS = 20, 8
local defaults = {
    enabled = false, presets = true, size = 36, spacing = 6, border = 2,
    animation = "pulse", underline = true, party = true, selected = "none", frameShape = "cut", entries = {},
}
local MASKS = "Interface\\AddOns\\" .. ADDON .. "\\Media\\XP\\"
local CUT_MASK = "Interface\\AddOns\\" .. ADDON .. "\\Media\\TooltipIconCut.tga"
extras.AuraReminderDefaults = defaults

-- The first learned action in each group is used; every listed alternative
-- satisfies the reminder, including party versions and ranks with the same name.
local presets = {
    PRIEST = { { { 588 } }, { { 1243 }, { 21562 } } },
    MAGE = { { { 1459 }, { 23028 } } },
    DRUID = { { { 1126 }, { 21849 } } },
    WARRIOR = { { { 6673 } } },
    HUNTER = { { { 13165 }, { 13163, 5118, 20043, 13161, 13159 } } },
    WARLOCK = { { { 706, 687 } } },
    SHAMAN = { { { 52127, 324 } } },
    PALADIN = { { { 19740 }, { 19834, 19742, 20217, 20911, 25782, 25894, 25898, 25899 } } },
}

-- Party equivalents use the rank of the single-target buff they provide.
local partyBuffs = {
    PRIEST = { ranks = { 1243, 1244, 1245, 2791, 10937, 10938 }, shared = { [21562] = 5, [21564] = 6 } },
    MAGE = { ranks = { 1459, 1460, 1461, 10156, 10157 }, shared = { [23028] = 5 } },
    DRUID = { ranks = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 }, shared = { [21849] = 6, [21850] = 7 } },
}

local function cfg()
    local settings = DUI:Get(ADDON, ROOT)
    return type(settings) == "table" and settings or defaults
end
local function plain(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function positiveID(id)
    return type(id) == "number" and id > 0 and id <= 4294967295 and id % 1 == 0
end

local entriesSource, validEntries, watchedItems
local function entries(settings)
    local source = (settings or cfg()).entries
    if not validEntries or entriesSource ~= source then
        entriesSource, validEntries, watchedItems = source, {}, {}
        if type(source) == "table" then
            for i = 1, MAX_CUSTOM do
                local e = source[i]
                if type(e) == "table" and (e.kind == "spell" or e.kind == "item") and positiveID(e.id)
                    and (positiveID(e.aura) or (type(e.aura) == "string" and #e.aura <= 256))
                    and (e.class == nil or (type(e.class) == "string" and #e.class <= 24)) then
                    validEntries[#validEntries + 1] = e
                    if e.kind == "item" then watchedItems[e.id] = true end
                end
            end
        end
    end
    return validEntries
end

local function spellInfo(id)
    local info = C_Spell and C_Spell.GetSpellInfo and plain(C_Spell.GetSpellInfo(id))
    if info then return plain(info.name), plain(info.iconID), plain(info.spellID) end
    if GetSpellInfo then
        local name, _, icon, _, _, _, spellID = GetSpellInfo(id)
        return plain(name), plain(icon), plain(spellID)
    end
end

local function itemInfo(id)
    local item = C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)
    local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
    return item, icon
end

local function learned(id)
    if IsSpellKnown and plain(IsSpellKnown(id)) == true then return true end
    if IsPlayerSpell and plain(IsPlayerSpell(id)) == true then return true end
    local book = C_SpellBook and C_SpellBook.IsSpellKnown
    return book and plain(book(id)) == true or false
end

local function auraKey(value)
    if type(value) ~= "string" or #value > 256 then return end
    local id = tonumber(value) or tonumber(value:match("|Hspell:(%d+)"))
    if id then return positiveID(id) and id or nil end
    return value:lower()
end

local KEY_BUTTON = "DaylightBlastaAuraReminderKey"
local CAST_REMINDER = "Cast the next missing buff"
_G.BINDING_HEADER_DAYLIGHTBLASTA = "Blasta (DaylightUI Plugin)"
_G["BINDING_NAME_CLICK " .. KEY_BUTTON .. ":LeftButton"] = L(CAST_REMINDER)

local host, secure, keyButton
local visuals, clicks, previously = {}, {}, {}
local ready, queued, layoutEnabled, queue
local function underline(parent)
    local line = CreateFrame("Frame", nil, parent)
    line:SetHeight(DUI.Pixel.Px(parent, 1))
    line.halves = {}
    for i = 1, 2 do
        local texture = line:CreateTexture(nil, "ARTWORK")
        local side = i == 1 and "LEFT" or "RIGHT"
        texture:SetPoint("TOP" .. side, line, "TOP" .. side)
        texture:SetPoint("BOTTOM" .. (i == 1 and "RIGHT" or "LEFT"), line, "CENTER", 0, -line:GetHeight() / 2)
        texture:SetColorTexture(1, 1, 1, 1)
        line.halves[i] = texture
    end
    line.haze = line:CreateTexture(nil, "BACKGROUND")
    line.haze:SetTexture(DUI.MEDIA .. "char-glow.png")
    line.haze:SetBlendMode("ADD")
    line.haze:SetPoint("CENTER")
    line:Hide()
    return line
end

local function paintLine(line)
    local accentAt = Style.AccentAt or Style.Accent
    local r, g, b = accentAt(0)
    local m, n, o = accentAt(0.5)
    local x, y, z = accentAt(1)
    local middle = CreateColor(m, n, o, 0.9)
    line.halves[1]:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), middle)
    line.halves[2]:SetGradient("HORIZONTAL", middle, CreateColor(x, y, z, 0))
    line.haze:SetVertexColor(accentAt(0.85))
    line.haze:SetAlpha(0.30)
end

local function layoutLine(line, parent, width, height, shown)
    line:SetShown(shown)
    if not shown or (line.width == width and line.offset == height) then return end
    line.width, line.offset = width, height
    line:ClearAllPoints()
    line:SetPoint("TOP", parent, "TOP", 0, -height - 3)
    line:SetWidth(math.max(1, width - 8))
    line.haze:SetSize(math.max(1, width), 14)
    paintLine(line)
end

local function build()
    host = CreateFrame("Frame", "DaylightExtrasAuraReminder", UIParent)
    host:SetSize(36, 36)
    host.line = underline(host)
    DUI.Movers.Register(host, MOVER, L("Aura reminders"), { "CENTER", nil, "CENTER", 0, -110 })
    secure = CreateFrame("Frame", nil, UIParent)
    secure:SetAllPoints(host)
    RegisterStateDriver(secure, "visibility", "[combat] hide; show")

    keyButton = CreateFrame("Button", KEY_BUTTON, UIParent, "SecureActionButtonTemplate,SecureHandlerStateTemplate")
    keyButton:RegisterForClicks("AnyDown")
    keyButton:SetAttribute("useOnKeyDown", true)
    keyButton:SetAttribute("_onstate-combat", [[
        if newstate == "combat" then self:SetAttribute("type1", nil) end
    ]])
    RegisterStateDriver(keyButton, "combat", "[combat] combat; ready")
    keyButton:Hide()
end

local function bindReminder(entry)
    if not keyButton then return end
    keyButton:SetAttribute("type1", entry and entry.kind)
    keyButton:SetAttribute("spell", entry and entry.kind == "spell" and (entry.party and entry.id or entry.name) or nil)
    keyButton:SetAttribute("item", entry and entry.kind == "item" and ("item:" .. entry.id) or nil)
    keyButton:SetAttribute("unit", entry and entry.kind == "spell" and (entry.unit or "player") or nil)
end

local function card(parent)
    local f = CreateFrame("Frame", nil, parent)
    f.shell = Style.Shell(f, { flat = true, borderPx = defaults.border, noBevel = true })
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    Style.CropIcon(f.icon)
    f.flash = f:CreateTexture(nil, "OVERLAY")
    f.flash:SetAllPoints(f.icon)
    f.flash:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.flash:SetBlendMode("ADD")
    f.flash:Hide()
    f.count = Style.Text(f, 11, "RIGHT")
    f.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", -1, 1)
    return f
end

local function hasCut(settings)
    return settings.frameShape == "cut" or (settings.frameShape == nil and settings.radius == nil)
end

local function shapeOption()
    local option = extras.FrameShapeOption(ADDON, ROOT, cfg)
    local previous = option.get
    option.blastaSince = "2.0"
    option.values.cut = "Cut bottom-right corner"
    option.order[#option.order + 1] = "cut"
    option.get = function() return hasCut(cfg()) and "cut" or previous() end
    option.default = function() return defaults.frameShape end
    return option
end

extras.German["Cut bottom-right corner"] = "Ecke unten rechts abschrägen"

local function styleCut(f, cut, border)
    if cut and not f.cutMask then
        f.cutBack = f:CreateTexture(nil, "BACKGROUND")
        f.cutBack:SetAllPoints(f)
        f.cutBack:SetColorTexture(Style.BORDER[1], Style.BORDER[2], Style.BORDER[3], 1)
        local outer = f:CreateMaskTexture()
        outer:SetTexture(CUT_MASK, "CLAMP", "CLAMP")
        outer:SetAllPoints(f)
        f.cutBack:AddMaskTexture(outer)
        f.cutMask = f:CreateMaskTexture()
        f.cutMask:SetTexture(CUT_MASK, "CLAMP", "CLAMP")
        f.cutMask:SetAllPoints(f.icon)
    end
    if f.cutBack then f.cutBack:SetShown(cut and border > 0) end
    if cut ~= (f.cut == true) then
        for _, texture in ipairs({ f.icon, f.flash }) do
            if cut then texture:AddMaskTexture(f.cutMask) else texture:RemoveMaskTexture(f.cutMask) end
        end
    end
    f.cut = cut
end

local function styleCard(f, settings, size)
    local border, radius = settings.border or defaults.border, extras.FrameCornerOverride(settings)
    if not f.shell then return end
    local inset = DUI.Pixel.Px(f, border)
    local general = radius or DUI.DB.General().cornerPx
    local cut = hasCut(settings)
    if f.cardSize == size and f.border == border and f.corner == general and f.inset == inset and f.cut == cut then return end
    f.cardSize, f.border, f.corner, f.inset = size, border, general, inset
    local opts = f.shell.opts
    opts.borderPx, opts.cornerPx, opts.noBorder = border, radius, border == 0
    Style.LayoutShell(f.shell)
    f.shell:SetShown(not cut)
    f.icon:ClearAllPoints()
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", inset, -inset)
    f.icon:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -inset, inset)
    local inner = math.max(1, size - 2 * inset)
    f.count:SetPoint("BOTTOMRIGHT", f.icon, "BOTTOMRIGHT", cut and -math.max(1, inner * 14 / 64 - 3) or -1, 1)
    styleCut(f, cut, border)
    local r = cut and 0 or math.max(0, (f.shell.radius or 0) - inset)
    local step = math.min(8, math.floor(r * 16 / inner + 0.5))
    if step == 0 and not f.masked then return end
    f.masks = f.masks or { f:CreateMaskTexture(), f:CreateMaskTexture() }
    for i, side in ipairs({ "LEFT", "RIGHT" }) do
        local m = f.masks[i]
        if step > 0 then
            m:SetTexture(MASKS .. side .. step .. ".tga", "CLAMP", "CLAMP")
            m:ClearAllPoints()
            m:SetPoint(side, f.icon, side)
            m:SetSize(inner * step / 16, inner)
        else
            m:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMP", "CLAMP")
        end
        if (step > 0) ~= (f.masked == true) then
            for _, tex in ipairs({ f.icon, f.flash }) do
                if step > 0 then tex:AddMaskTexture(m) else tex:RemoveMaskTexture(m) end
            end
        end
    end
    f.masked = step > 0
end

local function visual(i)
    if not visuals[i] then visuals[i] = card(host) end
    return visuals[i]
end

local function reveal(f, mode)
    Motion.Tween(f, 0, 0)
    f:SetAlpha(1)
    f:SetScale(1)
    if not Motion.On() or mode == "off" then return end
    local dawn = mode ~= "pop"
    if dawn then
        Motion.SlideIn(f, 0, -3, 0.26)
        Style.PaintAccent(f.flash, 0.30)
        Motion.Flash(f.flash, 0.38)
    else
        Motion.SlideIn(f, 0, -6, 0.28)
    end
end

local function revealLine(line, mode)
    if not line:IsShown() or mode == "off" or not Motion.On() then return end
    local group = line.reveal
    if not group then
        group = line:CreateAnimationGroup()
        local scale = group:CreateAnimation("Scale")
        scale:SetScaleFrom(0.18, 1)
        scale:SetScaleTo(1, 1)
        scale:SetDuration(0.36)
        scale:SetSmoothing("OUT")
        local fade = group:CreateAnimation("Alpha")
        fade:SetFromAlpha(0)
        fade:SetToAlpha(1)
        fade:SetDuration(0.28)
        line.reveal = group
    end
    group:Stop()
    group:Play()
end

local preview, previewTimer
local function finishPreview()
    if previewTimer then previewTimer:Cancel(); previewTimer = nil end
    if preview and preview:IsShown() then
        Motion.Tween(preview, 0, 0)
        preview:Hide()
        if cfg().enabled ~= true then
            layoutEnabled = false
            DUI.Movers.Suspend(MOVER, true)
        end
        queue()
    end
end

local function testReminder()
    if InCombatLockdown() then return end
    local settings = cfg()
    if not host then build() end
    if settings.enabled ~= true then DUI.Movers.Suspend(MOVER, false) end
    if not preview then
        preview = CreateFrame("Frame", nil, host)
        preview.line = underline(preview)
        preview.cards = { card(preview), card(preview) }
        preview:SetFrameStrata("TOOLTIP")
        preview:SetPoint("TOP", host, "TOP")
    end
    for _, f in ipairs(visuals) do f:Hide() end
    for _, b in ipairs(clicks) do b:Hide() end
    host.line:Hide()
    bindReminder(nil)
    local size = settings.size or defaults.size
    local spacing = settings.spacing or defaults.spacing
    local width = size * 2 + spacing
    preview:SetSize(width, size + 4)
    layoutLine(preview.line, preview, width, size, settings.underline ~= false)
    Motion.Tween(preview, 0, 0)
    preview:SetAlpha(1)
    preview:Show()
    for i, f in ipairs(preview.cards) do
        f:ClearAllPoints()
        f:SetPoint("TOP", preview, "TOP", (i - 1.5) * (size + spacing), 0)
        f:SetSize(size, size)
        styleCard(f, settings, size)
        local spell = i == 1 and 588 or 1243
        f.icon:SetTexture(select(2, spellInfo(spell)) or (i == 1 and 135926 or 135987))
        f.count:SetText(i == 2 and settings.party ~= false and "2/5" or nil)
        reveal(f, settings.animation)
    end
    revealLine(preview.line, settings.animation)
    if previewTimer then previewTimer:Cancel() end
    previewTimer = C_Timer.NewTimer(2.4, function()
        previewTimer = nil
        if Motion.On() and cfg().animation ~= "off" then
            Motion.Tween(preview, preview:GetAlpha(), 0, 0.3, function(a) preview:SetAlpha(a) end,
                finishPreview)
        else
            finishPreview()
        end
    end)
end

-- Secure name casts use the highest learned rank. Party entries cast an exact ID.
local function tooltipSpell(entry)
    local data = DUI.Book and DUI.Book.SpellData
    if not (data and data.Read and data.RankOf) then return end
    local best
    for _, section in ipairs(data.Read(entry.party == true).sections) do
        if not section.pet then
            for _, spell in ipairs(section.spells) do
                if not spell.future and spell.name == entry.name then
                    if entry.party then
                        if spell.spellID == entry.id then return spell end
                        for _, lower in ipairs(spell.lows) do
                            if not lower.future and lower.spellID == entry.id then return lower end
                        end
                    elseif not best or data.RankOf(spell) > data.RankOf(best) then
                        best = spell
                    end
                end
            end
        end
    end
    return best
end

local function button(i)
    if clicks[i] then return clicks[i] end
    local b = CreateFrame("Button", nil, secure, "SecureActionButtonTemplate")
    b:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    b:SetScript("OnEnter", function(self)
        local e = self.reminder
        if not e then return end
        local f = visuals[i]
        if f and extras.IconOutline then
            f.hoverOutline = f.hoverOutline or extras.IconOutline(f)
            f.hoverOutline(f.cut and f:GetWidth() * 14 / 64 or nil, true)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if e.kind == "item" then
            GameTooltip:SetItemByID(e.id)
        else
            local spell = tooltipSpell(e)
            if spell and GameTooltip.SetSpellBookItem then
                GameTooltip:SetSpellBookItem(spell.slot, spell.bank)
            else
                GameTooltip:SetSpellByID(spell and spell.spellID or e.id)
            end
        end
        GameTooltip:AddLine(L("Click to refresh this buff."), 0.9, 0.75, 0.45)
        GameTooltip:Show()
    end)
    local function clearHover()
        local f = visuals[i]
        if f and f.hoverOutline then f.hoverOutline(nil, false) end
    end
    b:SetScript("OnLeave", function() clearHover(); GameTooltip:Hide() end)
    b:SetScript("OnHide", clearHover)
    b:Hide()
    clicks[i] = b
    return b
end

local function scanAuras(unit)
    local ids, names = {}, {}
    local indexed = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    for index = 1, 255 do
        local name, id
        if indexed then
            local data = indexed(unit, index, "HELPFUL")
            if issecretvalue and issecretvalue(data) then return end
            if not data then break end
            name, id = plain(data.name), plain(data.spellId)
        elseif UnitBuff then
            local n, _, _, _, _, _, _, _, _, spell = UnitBuff(unit, index)
            name, id = plain(n), plain(spell)
            if not name and not id then
                if issecretvalue and (issecretvalue(n) or issecretvalue(spell)) then return end
                break
            end
        else
            return
        end
        if not name and not id then return end
        if type(name) == "string" then names[name:lower()] = true end
        if type(id) == "number" then ids[id] = true end
    end
    return ids, names
end

local auraCache = {}
local function unitAuras(unit)
    local cached = auraCache[unit]
    if cached then return cached.ids, cached.names end
    local ids, names = scanAuras(unit)
    if ids then auraCache[unit] = { ids = ids, names = names } end
    return ids, names
end

local function hasAura(key, ids, names)
    if type(key) == "string" then return names[key] == true end
    if ids[key] then return true end
    local name = spellInfo(key)
    return name and names[name:lower()] == true or false
end

local function itemCount(id)
    local count = C_Item and C_Item.GetItemCount or GetItemCount
    return count and (plain(count(id)) or 0) or 0
end

local function partyStatus(family, rank, ids, names, familyNames)
    if not ids then return nil end
    local known
    for i, id in ipairs(family.ranks) do
        if ids[id] then
            if i >= rank then return true end
            known = true
        end
    end
    for id, equivalent in pairs(family.shared) do
        if ids[id] then
            if equivalent >= rank then return true end
            known = true
        end
    end
    if not known then
        for _, name in ipairs(familyNames) do
            if names[name] then return true end
        end
    end
    return false
end

local function partyReminder(family, ids, names, overrides)
    local action, rank
    for i = #family.ranks, 1, -1 do
        if learned(family.ranks[i]) then action, rank = family.ranks[i], i; break end
    end
    if not action or overrides[action] or overrides[family.ranks[1]] then return end
    local name, icon = spellInfo(action)
    if not name then return end
    local familyNames = { name:lower() }
    for id in pairs(family.shared) do
        local sharedName = spellInfo(id)
        if sharedName then familyNames[#familyNames + 1] = sharedName:lower() end
    end
    local covered, total, nextUnit = 0, 0, nil
    for i = 0, 4 do
        local unit = i == 0 and "player" or ("party" .. i)
        if i == 0 or (plain(UnitExists(unit)) == true and plain(UnitIsConnected(unit)) == true
            and plain(UnitIsDeadOrGhost(unit)) == false) then
            total = total + 1
            local uids, unames = ids, names
            if i > 0 then uids, unames = unitAuras(unit) end
            local status = partyStatus(family, rank, uids, unames, familyNames)
            if status == true then
                covered = covered + 1
            elseif status == false and not nextUnit and (i == 0 or plain(UnitGUID(unit))) then
                nextUnit = unit
            end
        end
    end
    if nextUnit then
        return { kind = "spell", id = action, name = name, icon = icon, usable = true,
            unit = nextUnit, party = true, count = covered .. "/" .. total }
    end
end

local function collect(settings, ids, names)
    local _, class = UnitClass("player")
    local missing, seen, overrides = {}, {}, {}
    local function add(e)
        local key = e.kind .. ":" .. e.id
        if seen[key] then return end
        seen[key] = true
        missing[#missing + 1] = e
        e.key = key
    end
    -- Custom entries take priority if they use the same action as a preset.
    for _, e in ipairs(entries(settings)) do
        if not e.class or e.class == "all" or e.class == class then
            if e.kind == "spell" then overrides[e.id] = true end
            if not hasAura(e.aura, ids, names) then
                if e.kind == "spell" and learned(e.id) then
                    local name, icon = spellInfo(e.id)
                    if name then add({ kind = "spell", id = e.id, name = name, icon = icon, usable = true }) end
                elseif e.kind == "item" then
                    local _, icon = itemInfo(e.id)
                    add({ kind = "item", id = e.id, icon = icon, usable = itemCount(e.id) > 0 })
                end
            end
        end
    end
    if settings.presets then
        local family = settings.party ~= false and IsInGroup() and not IsInRaid() and partyBuffs[class]
        if family then
            local reminder = partyReminder(family, ids, names, overrides)
            if reminder then add(reminder) end
        end
        for _, preset in ipairs(presets[class] or {}) do
            local active, action
            for _, list in ipairs(preset) do
                for _, id in ipairs(list) do
                    if hasAura(id, ids, names) then active = true end
                end
            end
            for _, id in ipairs(preset[1]) do
                if learned(id) then action = id; break end
            end
            if action and not active and not overrides[action] and not (family and preset[1][1] == family.ranks[1]) then
                local name, icon = spellInfo(action)
                if name then add({ kind = "spell", id = action, name = name, icon = icon, usable = true }) end
            end
        end
    end
    return missing
end

local function position(f, anchor, i, count, size, spacing)
    local row, col = math.floor((i - 1) / COLUMNS), (i - 1) % COLUMNS
    local columns = math.min(COLUMNS, count - row * COLUMNS)
    local x, y = (col - (columns - 1) / 2) * (size + spacing), -row * (size + spacing)
    if f.auraX == x and f.auraY == y and f.auraSize == size then return end
    f.auraX, f.auraY, f.auraSize = x, y, size
    f:ClearAllPoints()
    f:SetPoint("TOP", anchor, "TOP", x, y)
    f:SetSize(size, size)
end

local function showReminder(f, entry)
    f.icon:SetTexture(entry.icon or 134400)
    f.icon:SetDesaturated(not entry.usable)
    f.count:SetText(entry.count)
    f:Show()
end

local function stopExit(region)
    if region.combatExit then region.combatExit:Stop() end
end

local function hideForCombat(region, mode, isLine)
    if not region:IsShown() then return end
    if mode == "off" or not Motion.On() then
        region:Hide()
        return
    end
    local exit = region.combatExit
    if not exit then
        exit = region:CreateAnimationGroup()
        region.combatExit = exit
        exit.fade = exit:CreateAnimation("Alpha")
        exit.fade:SetFromAlpha(1)
        exit.fade:SetToAlpha(0)
        if isLine then
            exit.move = exit:CreateAnimation("Scale")
            exit.move:SetScaleFrom(1, 1)
            exit.move:SetScaleTo(0.18, 1)
        else
            exit.move = exit:CreateAnimation("Translation")
        end
        exit.move:SetSmoothing("IN")
        exit:SetScript("OnFinished", function() region:Hide() end)
    end
    local duration = isLine and 0.36 or (mode == "pop" and 0.28 or 0.26)
    exit.fade:SetDuration(duration)
    exit.move:SetDuration(duration)
    if isLine then
        if region.reveal then region.reveal:Stop() end
    else
        Motion.Settle(region)
        region:SetAlpha(1)
        exit.move:SetOffset(0, mode == "pop" and -6 or -3)
    end
    exit:Play()
end

local combatHidden = false
local function render()
    queued = nil
    if not ready then return end
    local settings = cfg()
    local combat = InCombatLockdown()
    if not host then
        if combat or not settings.enabled then return end
        build()
    end
    if combat then
        if not combatHidden then
            combatHidden = true
            for _, f in ipairs(visuals) do hideForCombat(f, settings.animation) end
            hideForCombat(host.line, settings.animation, true)
            finishPreview()
            previously = {}
        end
        return
    end
    if combatHidden then
        combatHidden = false
        for _, f in ipairs(visuals) do stopExit(f) end
        stopExit(host.line)
    end
    if preview and preview:IsShown() then return end
    if layoutEnabled ~= settings.enabled then
        layoutEnabled = settings.enabled
        DUI.Movers.Suspend(MOVER, not settings.enabled)
    end
    local ids, names
    if settings.enabled and not (UnitIsDeadOrGhost and plain(UnitIsDeadOrGhost("player")) == true) then
        ids, names = unitAuras("player")
    end
    local missing = ids and collect(settings, ids, names) or {}
    local size = settings.size or defaults.size
    local spacing = settings.spacing or defaults.spacing
    local width = math.max(1, math.min(COLUMNS, #missing)) * (size + spacing) - spacing
    local height = math.max(1, math.ceil(#missing / COLUMNS)) * (size + spacing) - spacing
    layoutLine(host.line, host, width, height, #missing > 0 and settings.underline ~= false)
    local scale = host:GetScale()
    if secure.auraScale ~= scale then
        secure.auraScale = scale
        secure:SetScale(scale)
    end
    if host.auraWidth ~= width or host.auraHeight ~= height then
        host.auraWidth, host.auraHeight = width, height
        host:SetSize(width, height + 4)
    end
    local now, appeared, nextBuff = {}, false, nil
    for i, e in ipairs(missing) do
        local f = visual(i)
        position(f, host, i, #missing, size, spacing)
        styleCard(f, settings, size)
        showReminder(f, e)
        if not previously[e.key] then
            reveal(f, settings.animation)
            appeared = true
        elseif f.reminderKey ~= e.key then
            Motion.Tween(f, 0, 0)
            f:SetAlpha(1)
        end
        f.reminderKey = e.key
        now[e.key] = true

        local b = button(i)
        position(b, secure, i, #missing, size, spacing)
        e.unit = e.kind == "spell" and (e.unit or "player") or nil
        b.reminder = e
        local spell = e.kind == "spell" and (e.party and e.id or e.name) or nil
        if b.auraKey ~= e.key or b.auraSpell ~= spell or b.auraUnit ~= e.unit then
            b.auraKey, b.auraSpell, b.auraUnit = e.key, spell, e.unit
            b:SetAttribute("type1", e.kind)
            b:SetAttribute("spell", spell)
            b:SetAttribute("item", e.kind == "item" and ("item:" .. e.id) or nil)
            b:SetAttribute("unit", e.unit)
        end
        b:SetShown(e.usable)
        if not nextBuff and e.usable then nextBuff = e end
    end
    if appeared then revealLine(host.line, settings.animation) end
    for i = #missing + 1, #visuals do visuals[i]:Hide() end
    for i = #missing + 1, #clicks do
        clicks[i]:Hide()
        clicks[i].reminder = nil
    end
    bindReminder(nextBuff)
    previously = now
end

function queue()
    if queued then return end
    queued = true
    C_Timer.After(0, render)
end

DUI.On("Login", function()
    ready = true
    _G["BINDING_NAME_CLICK " .. KEY_BUTTON .. ":LeftButton"] = L(CAST_REMINDER)
    local events = CreateFrame("Frame")
    events:RegisterEvent("UNIT_AURA")
    for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "SPELLS_CHANGED",
        "BAG_UPDATE_DELAYED", "GET_ITEM_INFO_RECEIVED", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST",
        "GROUP_ROSTER_UPDATE", "UNIT_CONNECTION", "UNIT_FLAGS" }) do
        pcall(events.RegisterEvent, events, event)
    end
    -- UNIT_AURA fires for every unit in range. Drop foreign units first.
    local unitEvents = { UNIT_AURA = true, UNIT_CONNECTION = true, UNIT_FLAGS = true }
    local trackedUnits = { player = true, party1 = true, party2 = true, party3 = true, party4 = true }
    events:SetScript("OnEvent", function(_, event, unit, success)
        local unitEvent = unitEvents[event]
        if unitEvent and ((issecretvalue and issecretvalue(unit)) or not trackedUnits[unit]) then return end
        if InCombatLockdown() and event ~= "PLAYER_REGEN_DISABLED" and event ~= "PLAYER_ENTERING_WORLD" then return end
        if unitEvent then
            auraCache[unit] = nil
        elseif event ~= "BAG_UPDATE_DELAYED" and event ~= "GET_ITEM_INFO_RECEIVED" then
            wipe(auraCache)
        end
        local settings = cfg()
        if unitEvent and unit ~= "player" and settings.party == false then return end
        if not settings.enabled and not (preview and preview:IsShown()) and (not host or event ~= "PLAYER_REGEN_ENABLED") then return end
        if event == "BAG_UPDATE_DELAYED" or event == "GET_ITEM_INFO_RECEIVED" then
            entries(settings)
            if event == "BAG_UPDATE_DELAYED" then
                if not next(watchedItems) then return end
            elseif success == false or not watchedItems[plain(unit)] then return end
        end
        queue()
    end)
    queue()
end)
DUI.On("LoginReveal", function()
    local settings = cfg()
    if not host or (preview and preview:IsShown()) or not Motion.On() or settings.animation == "off" or InCombatLockdown() then return end
    local delay = DUI.Fade and DUI.Fade.RippleDelay and DUI.Fade.RippleDelay(host) or 0
    local offset = 0
    for _, f in ipairs(visuals) do
        if f:IsShown() then
            local key = f.reminderKey
            f:SetAlpha(0)
            C_Timer.After(delay + offset, function()
                if f.reminderKey == key then
                    if f:IsShown() and not InCombatLockdown() then reveal(f, settings.animation) else f:SetAlpha(1) end
                end
            end)
            offset = offset + 0.045
        end
    end
    C_Timer.After(delay, function() if not InCombatLockdown() and host.line:IsShown() then revealLine(host.line, settings.animation) end end)
end)
DUI.On("SettingChanged", function(scope, path)
    if scope == ADDON and type(path) == "string" and path:match("^auraReminder%.") then queue() end
end)
DUI.On("StyleChanged", function()
    if host then paintLine(host.line) end
    if preview then paintLine(preview.line) end
    queue()
end)
DUI.On("MoverApplied", function(key) if key == MOVER then queue() end end)

local function current()
    return entries()[tonumber(cfg().selected) or 0]
end

local function save(e)
    local list = {}
    for i, old in ipairs(entries()) do list[i] = old end
    for i, old in ipairs(list) do
        if old.kind == e.kind and old.id == e.id and old.class == e.class then
            list[i] = e
            DUI:Set(ADDON, ROOT .. ".entries", list)
            DUI:Set(ADDON, ROOT .. ".selected", tostring(i))
            return
        end
    end
    if #list >= MAX_CUSTOM then return DUI.Print(L("Aura reminder list is full.")) end
    list[#list + 1] = e
    DUI:Set(ADDON, ROOT .. ".entries", list)
    DUI:Set(ADDON, ROOT .. ".selected", tostring(#list))
end

local function addSpell()
    DUI.Widgets.Prompt(L("Enter the buff spell name or spell ID:"), "", function(value)
        local query = tonumber(value) or tonumber(value:match("|Hspell:(%d+)")) or value
        local name, _, id = spellInfo(query)
        id = id or (type(query) == "number" and query or nil)
        if not (name and positiveID(id)) then return DUI.Print(L("Spell not found.")) end
        save({ kind = "spell", id = id, aura = id, class = select(2, UnitClass("player")) })
    end)
end

local function addItem()
    DUI.Widgets.Prompt(L("Enter the item ID or paste its item link:"), "", function(value)
        local id = tonumber(value) or tonumber(value:match("|Hitem:(%d+)"))
        if not positiveID(id) then return DUI.Print(L("Enter a valid item ID.")) end
        DUI.Widgets.Prompt(L("Enter the resulting buff name or spell ID:"), "", function(aura)
            local key = auraKey(aura)
            if not key then return DUI.Print(L("Enter a valid buff name or spell ID.")) end
            save({ kind = "item", id = id, aura = key, class = "all" })
        end)
    end)
end

local function remove()
    local selected = tonumber(cfg().selected)
    local list = {}
    for i, e in ipairs(entries()) do if i ~= selected then list[#list + 1] = e end end
    DUI:Set(ADDON, ROOT .. ".entries", list)
    DUI:Set(ADDON, ROOT .. ".selected", "none")
end

local englishClasses = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue",
    PRIEST = "Priest", DEATHKNIGHT = "Death Knight", SHAMAN = "Shaman", MAGE = "Mage",
    WARLOCK = "Warlock", MONK = "Monk", DRUID = "Druid", DEMONHUNTER = "Demon Hunter",
    EVOKER = "Evoker",
}

local function classLabel(class, localized)
    if extras.Language == "enUS" then return englishClasses[class] or localized or class end
    return localized or class
end

local function choices()
    local labels, order = { none = "None" }, { "none" }
    for i, e in ipairs(entries()) do
        local name
        if e.kind == "item" then name = itemInfo(e.id) else name = spellInfo(e.id) end
        local key = tostring(i)
        local classes = LOCALIZED_CLASS_NAMES_MALE or {}
        labels[key] = (name or tostring(e.id))
            .. (e.class and e.class ~= "all" and (" · " .. classLabel(e.class, classes[e.class])) or "")
        order[#order + 1] = key
    end
    return labels, order
end

local function classChoices()
    local labels, order = { all = "All classes" }, { "all" }
    for class, label in pairs(LOCALIZED_CLASS_NAMES_MALE or {}) do
        labels[class] = classLabel(class, label)
        order[#order + 1] = class
    end
    return labels, order
end

function extras.AuraReminderPage()
    return { id = "auraReminder", label = "Aura reminders", groups = {
        { label = "Aura reminders", desc = "Missing buffs appear as clickable icons outside combat. The reminders hide when combat starts.", items = {
            { type = "toggle", key = ROOT .. ".enabled", label = "Show aura reminders" },
            { type = "button", label = CAST_REMINDER, text = "Key Bindings", blastaSince = "1.5",
                desc = "Bind this under Blasta (DaylightUI Plugin) in WoW's Key Bindings. Each press uses one missing buff outside combat.",
                func = function()
                    if Settings and Settings.OpenToCategory then Settings.OpenToCategory(Settings.KEYBINDINGS_CATEGORY_ID) end
                end },
            { type = "toggle", key = ROOT .. ".presets", label = "Use class presets" },
            { type = "toggle", key = ROOT .. ".party", label = "Track supported party buffs",
                desc = "Counts party members covered by Fortitude, Arcane Intellect, or Mark of the Wild." },
            { type = "slider", key = ROOT .. ".size", label = "Icon size", min = 22, max = 64, step = 1, unit = "px" },
            { type = "slider", key = ROOT .. ".spacing", label = "Aura reminder spacing", min = 0, max = 32, step = 1, unit = "px" },
            { type = "slider", key = ROOT .. ".border", label = "Aura reminder border thickness", min = 0, max = 6, step = 1, unit = "px" },
            shapeOption(),
            { type = "dropdown", key = ROOT .. ".animation", label = "Reminder animation",
                values = { pulse = "Dawn sweep", pop = "Soft bloom", off = "Off" }, order = { "pulse", "pop", "off" } },
            { type = "toggle", key = ROOT .. ".underline", label = "Accent underline" },
            { type = "button", label = "Test aura reminder", text = "Test aura reminder", func = testReminder },
        } },
        { label = "Custom reminders", items = {
            { type = "button", label = "Add spell", text = "Add spell", func = addSpell },
            { type = "button", label = "Add buff item", text = "Add buff item", func = addItem },
            { type = "dropdown", key = ROOT .. ".selected", label = "Edit reminder", choices = choices },
            { type = "dropdown", key = ROOT .. ".class", label = "Class restriction", choices = classChoices,
                get = function() local e = current(); return e and e.class or "all" end,
                set = function(value)
                    local index = tonumber(cfg().selected)
                    if not current() then return false end
                    local list = {}
                    for i, e in ipairs(entries()) do
                        list[i] = i == index and { kind = e.kind, id = e.id, aura = e.aura, class = value } or e
                    end
                    return DUI:Set(ADDON, ROOT .. ".entries", list)
                end,
                disabled = function() return not current() end },
            { type = "button", label = "Remove reminder", text = "Remove", func = remove,
                disabled = function() return not current() end },
        } },
    } }
end
