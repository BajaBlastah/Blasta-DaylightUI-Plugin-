-- SPDX-License-Identifier: GPL-3.0-or-later
local ADDON, extras = ...
local DUI = DaylightUI
local qos = DUI:GetModule("QoL")
local native = qos and qos.ns and qos.ns.LootFeed
local style = DUI.Style
local parts = DUI.Win and DUI.Win.Parts
if not (native and native.ParseItem and native.ItemOf and native.ParseMoney and native.SkillOf
    and DUI.MoneyString and parts and parts.QualityColor and style.Shell) then return end

local T = extras.Translate
local defaults = {
    enabled = false, width = 264, height = 27, gap = 3, cut = 12, reverse = false, down = false,
    lines = 5, duration = 5, alpha = 0.85, pulse = 0.55, textSize = 12, pause = true, quality = 0,
    items = true, money = true, skills = true, stackTime = 3, delta = true, historySize = 20, value = true,
    x = 0.76, y = 0.47, arrival = "right", elegantArrival = "rise", elegantGradient = .3, mode = "legacy", style = "blasta",
    coinColor = "highest",
}
extras.LootFeedDefaults = defaults
-- Settings are read many times per animation tick. Build each path once.
local optionPaths = setmetatable({}, { __index = function(paths, key)
    local path = "blastaLoot." .. key
    paths[key] = path
    return path
end })
local function option(key)
    local value = DUI:Get(ADDON, optionPaths[key])
    if value == nil then return defaults[key] end
    return value
end

local function feedMode()
    local mode = option("mode")
    if mode == "elegant" or mode == "blasta" or mode == "daylight" then return mode end
    return option("enabled") and "blasta" or "daylight"
end
local function blastaEnabled() return feedMode() ~= "daylight" end
local function arrivalMode()
    return option(feedMode() == "elegant" and "elegantArrival" or "arrival")
end

local active, history, sample, rows = {}, {}, {}, {}
local root, historyFrame, positioning
local preview, previewEnd, gradientPreview
local sweepPreviewAt
local hovered
local render, tick
local function secret(value) return issecretvalue and issecretvalue(value) end
local function clock() return GetTime() end

local function showsEntry(entry)
    if entry.money then return option("money") end
    if entry.rank then return option("skills") end
    return option("items") and (entry.quality or 0) >= option("quality")
end

local function place()
    root:ClearAllPoints()
    root:SetPoint("CENTER", UIParent, "BOTTOMLEFT",
        UIParent:GetWidth() * option("x"), UIParent:GetHeight() * option("y"))
end

local function text(parent, size, align)
    return style.Text(parent, size, align)
end

local function createRow()
    local row = CreateFrame("Frame", nil, root)
    row.edge = row:CreateTexture(nil, "BACKGROUND")
    row.edge:SetAllPoints()
    row.back = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", 2, 0)
    row.icon:SetTexCoord(.07, .93, .07, .93)
    row.iconEdge = row:CreateTexture(nil, "BORDER")
    row.rule = row:CreateTexture(nil, "ARTWORK")
    row.rule:SetColorTexture(1, 1, 1, 1)
    row.rule:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, .48), CreateColor(1, 1, 1, .07))
    row.iconEdge:Hide()
    row.rule:Hide()
    row.pulse = row:CreateTexture(nil, "BACKGROUND", nil, 4)
    row.pulse:SetColorTexture(1, 1, 1, 1)
    row.sweep = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.sweep:SetColorTexture(1, 1, 1, 1)
    row.sweep:Hide()
    row.name = text(row, 12, "LEFT")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
    row.name:SetWordWrap(false)
    row.value = text(row, 12, "RIGHT")
    row.value:SetShadowColor(0, 0, 0, 0)
    row.value:SetWordWrap(false)
    row:EnableMouse(true)
    row:RegisterForDrag("LeftButton")
    row:SetScript("OnDragStart", function() if positioning then root:StartMoving() end end)
    row:SetScript("OnDragStop", function()
        if not positioning then return end
        root:StopMovingOrSizing()
        local x, y = root:GetCenter()
        if x and y then
            DUI:Set(ADDON, "blastaLoot.x", math.max(0, math.min(1, x / UIParent:GetWidth())))
            DUI:Set(ADDON, "blastaLoot.y", math.max(0, math.min(1, y / UIParent:GetHeight())))
        end
        place()
    end)
    row:SetScript("OnEnter", function(self)
        local entry = self.entry
        if not entry then return end
        hovered = self
        if not entry.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetHyperlink(entry.link)
        local api = Auctionator and Auctionator.API and Auctionator.API.v1
        if option("value") and api and api.GetAuctionPriceByItemLink then
            local ok, price = pcall(api.GetAuctionPriceByItemLink, ADDON, entry.link)
            if ok and not secret(price) and type(price) == "number" and price > 0 then
                GameTooltip:AddDoubleLine(T("Estimated stack value"), DUI.MoneyString(price * (entry.count or 1)))
            end
        end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        if hovered == self then hovered = nil end
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row:SetScript("OnHide", row:GetScript("OnLeave"))
    return row
end

local SWEEP_DURATION, SWEEP_WIDTH = .32, 42

local function hideSweep(row)
    row.sweepActive = nil
    row.sweep:Hide()
end

local function stopSweep(row)
    if not row.sweepActive then return end
    DUI.Motion.Tween(row.sweep, 0, 0, 0)
    hideSweep(row)
end

local function settleArrival(row)
    DUI.Motion.Settle(row)
    stopSweep(row)
end

local function playSweep(row)
    local alpha = .85 * option("pulse") ^ 1.6
    if alpha <= 0 or not DUI.Motion.On() then return end
    local sweep = row.sweep
    local r, g, b = row.glowR, row.glowG, row.glowB
    r, g, b = .45 + .55 * r, .45 + .55 * g, .45 + .55 * b
    sweep:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, alpha))
    row.sweepActive = true
    DUI.Motion.Tween(sweep, 0, 1, SWEEP_DURATION, function(progress)
        local width = row.sweepWidth
        local start = progress * (width + SWEEP_WIDTH) - SWEEP_WIDTH
        local left = math.max(0, start)
        local right = math.min(width, start + SWEEP_WIDTH)
        if right <= left then sweep:Hide(); return end

        -- Clip both sides of the band to the same angled bounds as the row background.
        local top = math.min(right, row.sweepTop)
        local bottom = math.min(right, row.sweepBottom)
        sweep:SetVertexOffset(1, math.min(left, top), 0)
        sweep:SetVertexOffset(2, math.min(left, bottom), 0)
        sweep:SetVertexOffset(3, top - width, 0)
        sweep:SetVertexOffset(4, bottom - width, 0)
        sweep:Show()
    end, function() hideSweep(row) end)
end

local function animateArrival(row, stacked)
    local motion = DUI.Motion
    if stacked or not motion.On() then return end

    local arrival = arrivalMode()
    if arrival == "rise" then
        motion.SlideIn(row, 0, row.elegant and -6 or -12, motion.NORMAL)
    elseif arrival == "fade" then
        motion.SlideIn(row, 0, 0, motion.NORMAL)
    elseif arrival == "sweep" then
        motion.SlideIn(row, 0, 0, motion.FAST)
        playSweep(row)
    else
        motion.SlideIn(row, row.elegant and 18 or 48, 0, motion.NORMAL)
    end
end

local function detail(entry, now, elegant)
    if entry.money then return (elegant and "+" or "") .. DUI.MoneyString(entry.money) end
    if entry.rank then return entry.max and entry.rank .. " / " .. entry.max or tostring(entry.rank) end
    if not entry.count then return "" end
    -- Plain "x" instead of "×": most UI fonts draw that glyph small and raised.
    -- A single item shows no quantity, only the bag total.
    local parts = {}
    if (tonumber(entry.count) or 1) > 1 or not entry.bagTotal then
        parts[1] = "x" .. entry.count
    end
    if option("delta") and entry.delta and now - entry.updated < 0.9 then
        parts[#parts + 1] = (elegant and "|cffb6b6b6+" or "|cffd3ff52+") .. entry.delta .. "|r"
    end
    if entry.bagTotal then
        local progress = math.min(1, math.max(0, (now - entry.updated) / .45))
        local start = entry.bagFrom or entry.bagTotal
        local total = entry.bagTotal
        if progress < 1 and not gradientPreview and DUI.Motion.On() then
            total = math.floor(start + (total - start) * progress + .5)
        end
        parts[#parts + 1] = "|cffc8cdd3(" .. total .. ")|r"
    end
    return table.concat(parts, " ")
end

-- Coin rows: the gradient in the coins' own colors. "highest": the highest
-- coin looted (gold as soon as there is gold). "all": from the highest to the
-- lowest coin looted, skipping coins at zero. "gold": always gold, as before.
local COIN_INK = {
    gold = { 1, 0.82, 0 },
    silver = { 0.80, 0.82, 0.88 },
    copper = { 0.93, 0.56, 0.30 },
}
local function coinInks(money)
    local mode = option("coinColor")
    if mode == "gold" or type(money) ~= "number" then return nil end
    local present = {}
    if money >= 10000 then present[#present + 1] = COIN_INK.gold end
    if math.floor(money / 100) % 100 > 0 then present[#present + 1] = COIN_INK.silver end
    if money % 100 > 0 then present[#present + 1] = COIN_INK.copper end
    if #present == 0 then return nil end
    if mode ~= "all" then return { present[1] } end
    return present
end

-- Coin rows over several colors: each coin gets an equal share of the bar
-- (half each for two, a third each for three), held in its color, with a
-- short soft blend between two coins. A texture gradient has only two colors,
-- so the bar is pieces after row.pulse: coin, blend, coin, blend, coin. The
-- alpha falls a little along the bar and fades out over its last quarter.
local BLEND = .08   -- share of the bar each blend between two coins takes
local function pulsePieces(row, count)
    local pieces = row.pulsePieces
    if not pieces then
        pieces = {}
        row.pulsePieces = pieces
    end
    for i = #pieces + 1, 2 * count - 2 do
        local t = row:CreateTexture(nil, "BACKGROUND", nil, 4)
        t:SetColorTexture(1, 1, 1, 1)
        pieces[i] = { texture = t, from = CreateColor(0, 0, 0, 0), to = CreateColor(0, 0, 0, 0) }
    end
    return pieces
end

-- Where piece k (1 = row.pulse) starts and ends along the bar, 0 to 1.
local function pieceSpan(k, count)
    local solid = (1 - (count - 1) * BLEND) / count
    local coin = math.floor((k - 1) / 2)       -- coins before this piece
    local start = coin * (solid + BLEND) + ((k - 1) % 2 == 1 and solid or 0)
    return start, start + ((k - 1) % 2 == 1 and BLEND or solid)
end

local function layoutPulse(row, width)
    local inks = row.glowInks
    local count = inks and #inks or 1
    local used = count > 1 and 2 * count - 1 or 1
    local pieces = row.pulsePieces
    if used == 1 then
        row.pulse:SetWidth(width)
    else
        local a, b = pieceSpan(1, count)
        row.pulse:SetWidth(math.max(1, (b - a) * width))
    end
    for i, piece in ipairs(pieces or {}) do
        local t = piece.texture
        t:ClearAllPoints()
        if i + 1 <= used then
            local before = i == 1 and row.pulse or pieces[i - 1].texture
            local a, b = pieceSpan(i + 1, count)
            t:SetPoint("TOPLEFT", before, "TOPRIGHT")
            t:SetPoint("BOTTOMLEFT", before, "BOTTOMRIGHT")
            t:SetWidth(math.max(1, (b - a) * width))
        else
            t:Hide()
        end
    end
end

local function paintGlow(row, age, strength, animate)
    local flash = animate and math.max(0, 1 - age / .65) or 0
    local alpha = strength * (.72 + .28 * flash)
    if row.glowAlpha ~= alpha then
        -- Reuse the two gradient colors. The flash repaints them on every tick.
        local from, to = row.glowFrom, row.glowTo
        if not from then
            from, to = CreateColor(0, 0, 0, 0), CreateColor(0, 0, 0, 0)
            row.glowFrom, row.glowTo = from, to
        end
        local inks = row.glowInks
        local count = inks and #inks or 1
        if count > 1 then
            -- Alpha along the bar: down to 75% over the first three quarters,
            -- then out over the last quarter.
            local function at(x)
                if x <= .75 then return alpha * (1 - .25 * x / .75) end
                return alpha * .75 * math.max(0, 1 - x) / .25
            end
            local pieces = row.pulsePieces
            for k = 1, 2 * count - 1 do
                local coin = math.floor((k - 1) / 2) + 1
                local c = inks[coin]
                local n = (k - 1) % 2 == 1 and inks[coin + 1] or c   -- a blend runs to the next coin
                local x1, x2 = pieceSpan(k, count)
                local texture, cFrom, cTo = row.pulse, from, to
                if k > 1 then
                    local piece = pieces[k - 1]
                    texture, cFrom, cTo = piece.texture, piece.from, piece.to
                end
                cFrom:SetRGBA(c[1], c[2], c[3], at(x1))
                cTo:SetRGBA(n[1], n[2], n[3], at(x2))
                texture:SetGradient("HORIZONTAL", cFrom, cTo)
                texture:SetShown(alpha > 0)
            end
        else
            from:SetRGBA(row.glowR, row.glowG, row.glowB, alpha)
            to:SetRGBA(row.glowR, row.glowG, row.glowB, 0)
            row.pulse:SetGradient("HORIZONTAL", from, to)
            row.pulse:SetShown(alpha > 0)
        end
        row.glowAlpha = alpha
    end
end

local RULE_REVEAL = .28

local function hideRule(row)
    if row.ruleStart then DUI.Motion.Tween(row.rule, 0, 0, 0) end
    row.ruleStart = nil
    row.rule:Hide()
end

local function paintRule(row, entry, now, width, pixel)
    local motion = DUI.Motion
    local animate = not gradientPreview and not positioning and motion.On()
    if not entry.ruleStart then entry.ruleStart = animate and now or now - RULE_REVEAL end
    if row.ruleStart ~= entry.ruleStart or row.ruleWidth ~= width or row.ruleMotion ~= animate then
        row.ruleStart, row.ruleWidth, row.ruleMotion = entry.ruleStart, width, animate
        local progress = math.min(1, math.max(0, (now - entry.ruleStart) / RULE_REVEAL))
        local shownWidth = width * (1 - (1 - progress) ^ 3)
        motion.Tween(row.rule, shownWidth, width, animate and RULE_REVEAL * (1 - progress) or 0,
            function(value) row.rule:SetWidth(math.max(pixel, value)) end)
    end
    row.rule:Show()
end

local function paintRow(row, entry, index, count, now, elegant)
    local width, height, cut = option("width"), option("height"), option("cut")
    local down = option("down")
    local offset = (index - 1) * (height + option("gap"))
    row:ClearAllPoints()
    row:SetPoint(down and "TOP" or "BOTTOM", root, down and "TOP" or "BOTTOM", 0, down and -offset or offset)
    row:SetSize(width, height)
    row.elegant = elegant
    local visualIndex = down and index or count - index + 1
    local topInset = (visualIndex % 2 == 1) ~= option("reverse")
    local pixel = DUI.Pixel.Px(row, 1)
    if elegant then
        row.edge:Hide()
        row.back:Hide()
        if count == 1 or visualIndex < count then
            local left = 2 - pixel
            row.rule:ClearAllPoints()
            row.rule:SetPoint("LEFT", row, "BOTTOMLEFT", left, -option("gap") * .5)
            row.rule:SetHeight(pixel)
            paintRule(row, entry, now, width - left - 2, pixel)
        else
            hideRule(row)
        end
        row.iconEdge:ClearAllPoints()
        row.iconEdge:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -pixel, pixel)
        row.iconEdge:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", pixel, -pixel)
    else
        row.edge:Show()
        row.back:Show()
        hideRule(row)
        local top, bottom = topInset and cut or 0, topInset and 0 or cut
        local slope = (bottom - top) / height
        local inset = pixel * math.sqrt(1 + slope * slope)
        row.edge:SetVertexOffset(3, -top, 0)
        row.edge:SetVertexOffset(4, -bottom, 0)
        row.back:ClearAllPoints()
        row.back:SetPoint("TOPLEFT", pixel, -pixel)
        row.back:SetPoint("BOTTOMRIGHT", -inset, pixel)
        row.back:SetVertexOffset(3, -top - slope * pixel, 0)
        row.back:SetVertexOffset(4, -bottom + slope * pixel, 0)
        row.sweep:ClearAllPoints()
        row.sweep:SetPoint("TOPLEFT", pixel, -pixel)
        row.sweep:SetPoint("BOTTOMRIGHT", -inset, pixel)
        row.sweepWidth = width - pixel - inset
        row.sweepTop = row.sweepWidth - top - slope * pixel
        row.sweepBottom = row.sweepWidth - bottom + slope * pixel
    end
    row.iconEdge:SetShown(elegant and not entry.money)
    local iconSize = elegant and math.min(18, height - 4) or height - 4
    row.icon:SetSize(iconSize, iconSize)
    row.icon:SetTexture(entry.icon or 134400)
    local size = option("textSize")
    if row.textSize ~= size then
        style.SetTextSize(row.name, size)
        style.SetTextSize(row.value, size)
        row.textSize = size
    end
    row.value:ClearAllPoints()
    if entry.money then
        row.value:SetPoint("LEFT", row.icon, "RIGHT", elegant and 7 or 10, 0)
    else
        row.value:SetPoint("RIGHT", row, "RIGHT", DUI.Pixel.Snap(row, elegant and -6 or -cut - 8), 0)
    end
    row.value:SetText(detail(entry, now, elegant))
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 7, 0)
    row.name:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
    row.name:SetText(entry.money and "" or entry.name)
    local r, g, b
    local inks = entry.money and coinInks(entry.money)
    if entry.money then
        r, g, b = unpack(style.INK.MONEY)
        row.value:SetTextColor(r, g, b)
        if inks then r, g, b = unpack(inks[1]) end
    elseif entry.rank then
        r, g, b = style.Accent()
        style.InkText(row.name, "VALUE")
    else
        r, g, b = parts.QualityColor(entry.quality)
        if elegant and (entry.quality or 0) == 0 then r, g, b = .72, .72, .72 end
        row.name:SetTextColor(r, g, b)
    end
    if not entry.money then style.InkText(row.value, "VALUE") end
    local gradientStrength
    row.pulse:ClearAllPoints()
    if elegant then
        gradientStrength = 0
        if not entry.money and not entry.rank and (entry.quality or 0) >= 2 then
            row.iconEdge:SetColorTexture(r, g, b, 1)
        else
            row.iconEdge:SetColorTexture(.85, .85, .85, .45)
        end
        if not entry.rank then gradientStrength = option("elegantGradient") * .35 end
        local iconBounds = entry.money and row.icon or row.iconEdge
        row.pulse:SetPoint("TOPLEFT", iconBounds, "TOPRIGHT")
        row.pulse:SetPoint("BOTTOMLEFT", iconBounds, "BOTTOMRIGHT")
        row.pulseWidth = width * .65
    else
        local opacity = option("alpha")
        local border, background = style.BORDER, style.BACKGROUND
        row.edge:SetColorTexture(border[1], border[2], border[3], opacity)
        row.back:SetColorTexture(background[1], background[2], background[3], opacity)
        -- Fade continuously from the icon to the start of the angled edge.
        row.pulse:SetPoint("TOPLEFT", 1, -1)
        row.pulse:SetPoint("BOTTOMLEFT", 1, 1)
        row.pulseWidth = width - cut - 3
        gradientStrength = option("pulse")
    end
    local inkKey = inks and #inks > 1 and entry.money .. ":" .. #inks or nil
    if row.glowR ~= r or row.glowG ~= g or row.glowB ~= b or row.glowInkKey ~= inkKey then
        row.glowR, row.glowG, row.glowB = r, g, b
        row.glowInkKey = inkKey
        row.glowInks = inkKey and inks or nil
        if inkKey then pulsePieces(row, #inks) end
        row.glowAlpha = nil
    end
    layoutPulse(row, row.pulseWidth)
    row.gradientStrength = gradientStrength
    paintGlow(row, now - entry.updated, gradientStrength, not gradientPreview and DUI.Motion.On())
    row.entry = entry
    row:Show()
end

local function showHistory()
    if historyFrame:IsShown() then historyFrame:Hide(); return end
    local limit = math.min(#history, option("historySize"))
    local lines = historyFrame.lines
    for i = 1, option("historySize") do
        if not lines[i] then
            local line = text(historyFrame, 11, "LEFT")
            line:SetPoint("TOPLEFT", 12, -36 - (i - 1) * 16)
            line:SetPoint("RIGHT", -12, 0)
            line:SetWordWrap(false)
            lines[i] = line
        end
        local entry = history[i]
        lines[i]:SetText(entry and ((entry.name or T("Coins")) .. "  " .. detail(entry, math.huge))
            or (i == 1 and T("No recent loot") or ""))
        lines[i]:SetShown(i <= math.max(1, limit))
    end
    for i = option("historySize") + 1, #lines do lines[i]:Hide() end
    historyFrame:SetHeight(46 + math.max(1, limit) * 16)
    historyFrame:Show()
end

local function build()
    if root then return end
    root = CreateFrame("Frame", nil, UIParent)
    root:SetSize(1, 1)
    root:SetFrameStrata("MEDIUM")
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    place()
    historyFrame = CreateFrame("Frame", nil, root)
    historyFrame:SetFrameLevel(root:GetFrameLevel() + 10)
    historyFrame:SetWidth(260)
    historyFrame:SetPoint("TOPLEFT", root, "TOPRIGHT", 8, 0)
    historyFrame:SetClampedToScreen(true)
    historyFrame:EnableMouse(true)
    style.Shell(historyFrame, { window = true })
    local close = DUI.Widgets.Close(historyFrame, function() historyFrame:Hide(); render() end)
    close:SetPoint("TOPRIGHT", -6, -6)
    local title = text(historyFrame, 12, "LEFT")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText(T("Loot history"))
    historyFrame.lines = {}
    historyFrame:Hide()
    local accumulated = 0
    root:SetScript("OnUpdate", function(_, dt)
        accumulated = accumulated + dt
        if accumulated < .04 then return end
        tick(accumulated)
        accumulated = 0
    end)
    root:Hide()
end

function render(hideUnused)
    if not root then return end
    if #active == 0 and not preview and not positioning and not historyFrame:IsShown()
        and not (rows[1] and rows[1]:IsShown()) then root:Hide(); return end
    local strata = (preview or positioning or historyFrame:IsShown()) and "FULLSCREEN_DIALOG" or "MEDIUM"
    if root:GetFrameStrata() ~= strata then root:SetFrameStrata(strata) end
    root:Show()
    local list = preview and sample or active
    local width, height = option("width"), option("height")
    root:SetSize(width, height)
    local n = math.min(#list, option("lines"))
    local now = clock()
    local elegant = feedMode() == "elegant"
    for i = 1, n do
        rows[i] = rows[i] or createRow()
        local row = rows[i]
        if row.entry ~= list[i] then
            settleArrival(row)
            row.countAnimating = nil
        end
        if row.fading then
            DUI.Motion.AlphaTo(row, 1, 0)
            row.fading = nil
        end
        paintRow(row, list[i], i, n, now, elegant)
    end
    for i = n + 1, #rows do
        local row = rows[i]
        if row:IsShown() and (hideUnused or not row.fading) then
            settleArrival(row)
            row.fading = true
            DUI.Motion.AlphaTo(row, 0, hideUnused and 0 or DUI.Motion.CLOSE, true)
        end
    end
end

local function add(list, entry, record, previewStack)
    local now = clock()
    entry.key = entry.money and (entry.coinKey or "coins") or entry.key
    if not entry.key then return end
    build()
    if record then
        local copy = {}
        for k, v in pairs(entry) do copy[k] = v end
        table.insert(history, 1, copy)
        while #history > option("historySize") do table.remove(history) end
    end
    local stacked = previewStack == true
    local position = 1
    local stackTime = option("stackTime")
    for index, old in ipairs(list) do
        if old.key == entry.key and stackTime > 0 and now - old.updated <= stackTime then
            if entry.money then entry.money = entry.money + old.money
            elseif entry.count then entry.delta, entry.count = entry.count, entry.count + old.count end
            table.remove(list, index)
            if feedMode() == "elegant" then
                position = index
                entry.ruleStart = old.ruleStart
            end
            stacked = true
            break
        end
    end
    entry.updated = now
    entry.remaining = option("duration") + ((entry.quality or 0) >= 3 and 2 or 0)
    table.insert(list, position, entry)
    while #list > option("lines") do table.remove(list) end
    if list == sample and gradientPreview then return end
    render()
    local row = rows[position]
    if not positioning and not gradientPreview and row and row.entry == entry then
        animateArrival(row, stacked)
    end
end

local previewID = 0
local function playPreview(static)
    build()
    previewID = previewID + 1
    local id = previewID
    preview, previewEnd = true, clock() + option("duration") + 2
    gradientPreview = static == true
    sweepPreviewAt = nil
    wipe(sample)
    if not gradientPreview then render(true) end
    local function item(key, label, icon, quality, count)
        local total = key == "silk" and 20 or count
        return { key = key, name = T(label), icon = icon, quality = quality, count = count,
            bagTotal = total, bagFrom = total - count }
    end
    local entries = {
        item("epic", "Venomspitter", 135317, 4, 1),
        { key = "tailoring", name = T("Tailoring"), icon = 136249, rank = 154, max = 225 },
        item("ring", "Ring of the Webweaver", 133356, 3, 1),
        -- One row per coin color: copper alone, silver with copper, and gold
        -- with silver and copper (all three colors for "All coins"). Kept
        -- apart (coinKey) so the preview doesn't stack them into one row.
        { money = 67, icon = 133784, coinKey = "coins:copper" },
        { money = 161, icon = 133784, coinKey = "coins:silver" },
        { money = 23456, icon = 133784, coinKey = "coins:gold" },
        item("silk", "Spider Silk", 132905, 1, 4),
        item("silk", "Spider Silk", 132905, 1, 4),
    }
    if feedMode() == "elegant" then
        entries[2] = item("feather", "Light Feather", 132917, 0, 1)
    end
    for i = #entries, 1, -1 do
        if not showsEntry(entries[i]) then table.remove(entries, i) end
    end
    local hasStack = #entries >= 2 and entries[#entries].key == "silk"
        and entries[#entries - 1].key == "silk"
    local interval = arrivalMode() == "sweep" and SWEEP_DURATION + .04 or .22
    for i, entry in ipairs(entries) do
        if gradientPreview then
            if i < #entries or not hasStack then add(sample, entry, false) end
        else
            C_Timer.After((i - 1) * interval, function()
                if id == previewID and preview then
                    if hasStack and i == #entries then
                        -- The demo shows stacking even when live stacking is off.
                        local previous = sample[1]
                        if previous and previous.key == entry.key then
                            entry.count, entry.delta = 8, 4
                            entry.bagTotal, entry.bagFrom = 24, 20
                            entry.ruleStart = previous.ruleStart
                            table.remove(sample, 1)
                        end
                    end
                    add(sample, entry, false, hasStack and i == #entries)
                end
            end)
        end
    end
    if gradientPreview then render(true) end
end

function tick(elapsed)
    local changed
    if preview and clock() >= previewEnd and not positioning then
        preview, gradientPreview, changed = false, false, true
    end
    if not (option("pause") and hovered and not preview) then
        for i = #active, 1, -1 do
            local entry = active[i]
            entry.remaining = entry.remaining - elapsed
            if entry.remaining <= 0 then table.remove(active, i); changed = true end
        end
    end
    if changed then render() end
    if #active == 0 and not preview and not positioning and not historyFrame:IsShown()
        and not (rows[1] and rows[1]:IsShown()) then root:Hide(); return end
    local now = clock()
    if sweepPreviewAt and now >= sweepPreviewAt then
        sweepPreviewAt = nil
        local row = rows[1]
        if gradientPreview and option("arrival") == "sweep"
            and row and row:IsShown() and row.entry == sample[1] then
            playSweep(row)
        end
    end
    local animate = not gradientPreview and DUI.Motion.On()
    for _, row in ipairs(rows) do
        if row:IsShown() and row.entry and not row.fading then
            local age = now - row.entry.updated
            if row.gradientStrength > 0 then paintGlow(row, age, row.gradientStrength, animate) end
            if animate and row.entry.bagTotal and age <= .55 then
                row.value:SetText(detail(row.entry, now, row.elegant))
                row.countAnimating = true
            elseif row.countAnimating or (row.entry.delta and age >= .9) then
                row.countAnimating = nil
                if age >= .9 then row.entry.delta = nil end
                row.value:SetText(detail(row.entry, now, row.elegant))
            end
        end
    end
end

local function plainMessage(msg)
    return not secret(msg) and type(msg) == "string"
end

local moneyBalance, lootTime
local MONEY_MATCH = 2
local moneyFromChat, moneyFromBalance = 0, 0
local chatMoneyTime, balanceMoneyTime = -math.huge, -math.huge
local function resetMoney()
    moneyFromChat, moneyFromBalance = 0, 0
    chatMoneyTime, balanceMoneyTime = -math.huge, -math.huge
end

local function recordMoney(amount)
    if amount > 0 then add(active, { money = amount, icon = 133784 }, true) end
end

local function expireMoneyMatches(now)
    if now - chatMoneyTime > MONEY_MATCH then moneyFromChat = 0 end
    if now - balanceMoneyTime > MONEY_MATCH then moneyFromBalance = 0 end
end

local skillPatterns = {}
local function buildSkillPattern(format)
    local parts, offset = { "^" }, 1
    local function literal(value)
        return (value:gsub("(%W)", "%%%1"))
    end
    while true do
        local first, last, token = format:find("%%[%d]*%$?([sd])", offset)
        if not first then break end
        parts[#parts + 1] = literal(format:sub(offset, first - 1))
        parts[#parts + 1] = token == "s" and "(.+)" or "(%d+)"
        offset = last + 1
    end
    parts[#parts + 1] = literal(format:sub(offset))
    parts[#parts + 1] = "$"
    return table.concat(parts)
end
-- The client's skill-up formats never change during a session.
local function skillPattern(format)
    local pattern = skillPatterns[format]
    if not pattern then
        pattern = buildSkillPattern(format)
        skillPatterns[format] = pattern
    end
    return pattern
end

local function balanceChanged()
    local balance = GetMoney()
    if secret(balance) or type(balance) ~= "number" then return end
    local gain = moneyBalance and balance - moneyBalance or 0
    moneyBalance = balance
    if not blastaEnabled() or not option("money") or gain <= 0 then return end
    local now = clock()
    expireMoneyMatches(now)
    local matched = math.min(moneyFromChat, gain)
    moneyFromChat = moneyFromChat - matched
    local remainder = gain - matched
    if remainder > 0 and lootTime and now <= lootTime then
        moneyFromBalance = moneyFromBalance + remainder
        balanceMoneyTime = now
        recordMoney(remainder)
    end
end

local function readBagCounts()
    if not (C_Container and C_Container.GetContainerItemInfo and C_Container.GetContainerNumSlots) then return end
    local counts = {}
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4) do
        for slot = 1, C_Container.GetContainerNumSlots(bag) or 0 do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info then
                local id, count = info.itemID, info.stackCount
                if secret(id) then return end
                if type(id) == "number" and counts[id] ~= false then
                    counts[id] = not secret(count) and type(count) == "number" and ((counts[id] or 0) + count) or false
                end
            end
        end
    end
    return counts
end

local function bagCount(counts, id)
    if counts and id and counts[id] ~= false then return counts[id] or 0 end
end

local function receive(kind, msg)
    if not blastaEnabled() or not plainMessage(msg) then return end
    if kind == "CHAT_MSG_LOOT" and option("items") then
        local ok, link, count = pcall(native.ParseItem, msg)
        if ok and link then
            local entry = native.ItemOf(link)
            if showsEntry(entry) then
                entry.count = count or 1
                entry.bagID = tonumber(link:match("item:(%d+)"))
                if entry.bagID then entry.bagTotal = bagCount(readBagCounts(), entry.bagID) end
                if entry.bagTotal then entry.bagFrom = math.max(0, entry.bagTotal - entry.count) end
                add(active, entry, true)
            end
        end
    elseif kind == "CHAT_MSG_MONEY" and option("money") then
        local ok, coins = pcall(native.ParseMoney, msg)
        if ok and coins and coins > 0 then
            -- The chat line can arrive after the loot window or its fallback timer has closed.
            local now = clock()
            expireMoneyMatches(now)
            local matched = math.min(moneyFromBalance, coins)
            moneyFromBalance = moneyFromBalance - matched
            local remainder = coins - matched
            if remainder > 0 then
                moneyFromChat = moneyFromChat + remainder
                chatMoneyTime = now
                recordMoney(remainder)
            end
        end
    elseif kind == "CHAT_MSG_SKILL" and option("skills") then
        if native.ParseSkill then
            local name, rank = native.ParseSkill(msg)
            if name then add(active, native.SkillOf(name, rank), true) end
            return
        end
        for _, key in ipairs({ "SKILL_RANK_UP", "ERR_SKILL_UP_SI" }) do
            local format = _G[key]
            if type(format) == "string" then
                local ok, a, b = pcall(string.match, msg, skillPattern(format))
                if ok and a and b then
                    if tonumber(a) then a, b = b, a end
                    if tonumber(b) then add(active, native.SkillOf(a, tonumber(b)), true); return end
                end
            end
        end
    end
end

DUI.On("Login", function()
    DUI.RegisterEvent("BAG_UPDATE_DELAYED", function()
        local now = clock()
        local changed
        local counts, scanned
        for _, entry in ipairs(active) do
            if entry.bagID and now - entry.updated < .8 then
                if not scanned then counts, scanned = readBagCounts(), true end
                local total = bagCount(counts, entry.bagID)
                if total and total ~= entry.bagTotal then
                    entry.bagTotal = total
                    entry.bagFrom = math.max(0, total - (entry.delta or entry.count))
                    changed = true
                end
            end
        end
        if changed then render() end
    end)
    for _, event in ipairs({ "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_SKILL" }) do
        DUI.RegisterEvent(event, receive)
    end
    DUI.RegisterEvent("PLAYER_MONEY", balanceChanged)
    DUI.RegisterEvent("LOOT_OPENED", function()
        lootTime = math.huge
    end)
    DUI.RegisterEvent("LOOT_CLOSED", function() lootTime = clock() + 1 end)
    balanceChanged()
    render()
end)

-- The native feed keeps its own settings, samples and mover when Blasta takes over live loot.
for _, method in ipairs({ "OnLoot", "OnSkill", "OnMoney", "OnMoneyChanged", "OnLootWindow" }) do
    local original = native[method]
    if original then
        native[method] = function(...)
            if not blastaEnabled() then return original(...) end
        end
    end
end

-- Native preview timers call Add directly, even after the layout is switched.
if native.Add then
    local original = native.Add
    function native.Add(...)
        if option("mode") == "legacy" or not blastaEnabled() then return original(...) end
    end
end

local mode = {
    type = "dropdown", key = "blastaLoot.mode", label = "Loot feed style", blastaSince = "1.6",
    order = { "daylight", "blasta", "elegant" },
    values = { daylight = "Daylight Standard", blasta = "Blasta Standard", elegant = "Blasta Elegant" },
    get = feedMode,
    default = function() return "daylight" end,
    set = function(value)
        local ok = DUI:Set(ADDON, "blastaLoot.mode", value)
        if not ok then return ok end
        previewID = previewID + 1
        preview, gradientPreview, sweepPreviewAt, positioning = nil, nil, nil, nil
        if root then root:StopMovingOrSizing() end
        wipe(sample)
        if historyFrame then historyFrame:Hide() end
        resetMoney()
        local useDaylight = value == "daylight"
        if useDaylight then wipe(active) end
        for _, row in ipairs(rows) do settleArrival(row) end
        render(true)
        DUI:Set("QoL", "lootFeed", useDaylight)
        if useDaylight and native.OnLootWindow then native.OnLootWindow(false) end
        return ok
    end,
}

-- Shown as a switch (Daylight's feed or Blasta's) and, with Blasta's on, a
-- choice between its two looks. Both write the one saved mode.
local useBlasta = {
    type = "toggle", key = "blastaLoot.useBlasta", label = "Use Blasta loot feed", blastaSince = "1.7",
    desc = "Off uses DaylightUI's loot feed. On replaces it with Blasta's, in the look picked below.",
    get = function() return blastaEnabled() end,
    default = function() return false end,
    set = function(on)
        local style = option("style") == "elegant" and "elegant" or "blasta"
        return mode.set(on and style or "daylight")
    end,
}
local style = {
    type = "dropdown", key = "blastaLoot.style", label = "Blasta loot feed look", blastaSince = "1.7",
    order = { "blasta", "elegant" },
    values = { blasta = "Blasta Standard", elegant = "Blasta Elegant" },
    get = function() return feedMode() == "elegant" and "elegant" or "blasta" end,
    default = function() return "blasta" end,
    hidden = function() return not blastaEnabled() end,
    set = function(value)
        DUI:Set(ADDON, "blastaLoot.style", value)
        return mode.set(value)
    end,
}
local german = extras.German
if german then
    german["Use Blasta loot feed"] = "Blasta-Beutefeed verwenden"
    german["Off uses DaylightUI's loot feed. On replaces it with Blasta's, in the look picked below."] =
        "Aus: DaylightUIs Beutefeed. An: Blastas Beutefeed im darunter gewählten Stil."
    german["Blasta loot feed look"] = "Stil des Blasta-Beutefeeds"
    german["Blasta's loot feed is on. Turn off \"Use Blasta loot feed\" to use this one."] =
        "Der Blasta-Beutefeed ist an. Schalte „Blasta-Beutefeed verwenden“ aus, um diesen zu nutzen."
end


local function testFeed()
    if blastaEnabled() then
        playPreview()
    elseif native.Preview and qos.enabled then
        if not DUI:Get("QoL", "lootFeed") then DUI:Set("QoL", "lootFeed", true) end
        native.Preview()
    end
end

local function control(kind, key, label, min, max, step)
    return { type = kind, key = "blastaLoot." .. key, label = label, min = min, max = max, step = step,
        get = function() return option(key) end, default = function() return defaults[key] end,
        set = function(value)
            local ok = DUI:Set(ADDON, "blastaLoot." .. key, value)
            if ok and (key == "pulse" or key == "elegantGradient" or key == "textSize") then
                if gradientPreview then previewEnd = clock() + option("duration") + 2
                else playPreview(true) end
                if key == "pulse" and option("arrival") == "sweep" then
                    local row = rows[1]
                    if row then stopSweep(row) end
                    sweepPreviewAt = value > 0 and clock() + .12 or nil
                end
            end
            if ok and (key == "items" or key == "money" or key == "skills" or key == "quality") then
                if key == "money" then resetMoney() end
                for i = #active, 1, -1 do
                    if not showsEntry(active[i]) then table.remove(active, i) end
                end
                if preview then playPreview(true) end
            end
            render()
            return ok
        end }
end

local gradientStrength = control("slider", "pulse", "Quality gradient strength", 0, 1, .05)
gradientStrength.unit = "%"
gradientStrength.desc = "Sets the intensity of the quality gradient and the quality light sweep."

local elegantGradient = control("slider", "elegantGradient", "Quality gradient strength", 0, 1, .05)
elegantGradient.unit = "%"
elegantGradient.desc = "Adds a gradient in the item quality or coin color, starting at the right edge of the icon. Set to zero to turn it off."
elegantGradient.hidden = function() return feedMode() ~= "elegant" end

local arrival = control("dropdown", "arrival", "Loot arrival animation")
arrival.blastaSince = "1.5"
arrival.desc = "Choose how new loot rows appear."
arrival.order = { "right", "rise", "sweep" }
arrival.values = { right = "Slide in from the right", rise = "Rise from below", sweep = "Quality light sweep" }
arrival.hidden = function() return feedMode() ~= "blasta" end
local elegantArrival = control("dropdown", "elegantArrival", "Loot arrival animation")
elegantArrival.desc = arrival.desc
elegantArrival.order = { "rise", "right", "fade" }
elegantArrival.values = { rise = "Rise from below", right = "Slide in from the right", fade = "Fade in" }
elegantArrival.hidden = function() return feedMode() ~= "elegant" end

local function standardOnly(row)
    row.hidden = function() return feedMode() ~= "blasta" end
    return row
end

local coinColor = control("dropdown", "coinColor", "Coin color")
coinColor.blastaSince = "2.3"
coinColor.desc = "Colors the gradient of looted coins: the highest coin looted, or every coin from the highest to the lowest."
coinColor.order = { "highest", "all", "gold" }
coinColor.values = { highest = "Highest coin", all = "All coins", gold = "Always gold" }
coinColor.disabled = function() return not option("money") end
coinColor.hidden = function() return not blastaEnabled() end
extras.German["Coin color"] = "Münzfarbe"
extras.German["Colors the gradient of looted coins: the highest coin looted, or every coin from the highest to the lowest."] =
    "Färbt den Verlauf erbeuteter Münzen: in der höchsten erbeuteten Münze oder in allen, von der höchsten bis zur niedrigsten."
extras.German["Highest coin"] = "Höchste Münze"
extras.German["All coins"] = "Alle Münzen"
extras.German["Always gold"] = "Immer Gold"

local quality = control("dropdown", "quality", "Minimum item quality")
quality.disabled = function() return not option("items") end
quality.order = { 0, 1, 2, 3, 4 }
quality.values = {
    [0] = ITEM_QUALITY0_DESC or "Poor", ITEM_QUALITY1_DESC or "Common",
    ITEM_QUALITY2_DESC or "Uncommon", ITEM_QUALITY3_DESC or "Rare", ITEM_QUALITY4_DESC or "Epic",
}

function extras.LootFeedPage()
    local groups = {
        { label = "Blasta loot feed", items = {
            useBlasta, style, arrival, elegantArrival, coinColor,
            { type = "button", label = "Preview loot feed", func = testFeed,
                disabled = function() return not blastaEnabled() and not (qos.enabled and native.Preview) end },
            { type = "button", label = "Move loot feed", desc = "Drag a preview row to move the feed. Click this button again to finish.",
                hidden = function() return not blastaEnabled() end, func = function()
                positioning = not positioning
                if positioning then playPreview() else render() end
            end },
        } },
        { label = "Layout", items = {
            control("slider", "width", "Feed width", 190, 420, 1),
            control("slider", "height", "Row height", 20, 42, 1),
            control("slider", "gap", "Row spacing", 0, 12, 1),
            standardOnly(control("slider", "cut", "Corner depth", 0, 28, 1)),
            standardOnly(control("toggle", "reverse", "Reverse first corner")),
            control("toggle", "down", "Grow downwards"),
        } },
        { label = "Display", items = {
            control("slider", "lines", "Visible rows", 1, 10, 1),
            control("slider", "duration", "Display duration (seconds)", 2, 20, 1),
            standardOnly(control("slider", "alpha", "Background opacity", 0, 1, .05)),
            control("slider", "textSize", "Loot feed text size", 10, 18, 1),
            standardOnly(gradientStrength),
            elegantGradient,
            control("toggle", "pause", "Pause on mouseover"),
        } },
        { label = "Loot", items = {
            control("toggle", "items", "Show loot items"),
            quality,
            control("toggle", "money", "Show coins"),
            control("toggle", "skills", "Show skill-ups"),
            control("slider", "stackTime", "Stacking window (seconds)", 0, 10, 1),
            control("toggle", "delta", "Show added quantity"),
        } },
        { label = "History", items = {
            { type = "button", label = "Open loot history", func = function() build(); showHistory(); render() end },
            control("slider", "historySize", "Recent entries", 5, 30, 1),
            control("toggle", "value", "Show Auctionator stack value"),
        } },
    }
    for i = 2, #groups do
        for _, row in ipairs(groups[i].items) do
            if not row.hidden then row.hidden = function() return not blastaEnabled() end end
        end
    end
    return { id = "blastaLoot", label = "Loot feed", groups = groups }
end

extras.Loaded("LootFeed")
