local _, extras = ...
local DUI = DaylightUI
local Talents = DUI.Book and DUI.Book.Talents
local Style = DUI.Style
if not (Talents and type(Talents.FillTree) == "function" and Style and Style.Text and Style.InkText and Style.Accent) then return end

local T = extras.Translate
local G = extras.German

-- Talent trees with their rows spelled out: each row's band across the
-- tree, the points it takes on the left (0, 5, 10 ...), and under the tree's
-- name how many more points open the next row. Reached rows read normally,
-- the next one in the accent, the rest dimmed. DaylightUI still draws the
-- trees; Blasta adds the rows around its tiles after every fill (the
-- inspect window's trees too).
local PER_ROW = 5          -- classic rule: each row needs 5 more points in the tree
local GUTTER = 22          -- room kept for the row numbers left of the grid

G["%d more to open row %d"] = "Noch %d Punkte bis Reihe %d"
G["1 more to open row %d"] = "Noch 1 Punkt bis Reihe %d"
G["All rows open"] = "Alle Reihen offen"

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function parts(box)
    local p = box.blastaRows
    if p then return p end
    p = { bands = {}, labels = {}, lines = {} }
    -- The next row's marker: a short accent bar at the tree's left edge.
    p.mark = box:CreateTexture(nil, "ARTWORK")
    p.mark:SetTexture(WHITE)
    p.mark:SetWidth(2)
    -- Under the tree name, small: what the next row still needs.
    p.sub = Style.Text(box, Style.SIZE.tiny, "LEFT")
    p.sub:SetWordWrap(false)
    box.blastaRows = p
    return p
end

local function band(box, p, i)
    local b = p.bands[i]
    if not b then
        b = box:CreateTexture(nil, "BACKGROUND", nil, 2)
        b:SetTexture(WHITE)
        p.bands[i] = b
    end
    return b
end

local function line(box, p, i)
    local l = p.lines[i]
    if not l then
        l = box:CreateTexture(nil, "BACKGROUND", nil, 3)
        l:SetTexture(WHITE)
        l:SetHeight(1)
        p.lines[i] = l
    end
    return l
end

local function label(box, p, i)
    local l = p.labels[i]
    if not l then
        l = Style.Text(box, Style.SIZE.tiny, "CENTER")
        l:SetWidth(GUTTER)
        p.labels[i] = l
    end
    return l
end

-- A row newly reached in Blasta's talent layout: its number lights up in the
-- accent and fades back, and one light runs across the row. Found by
-- comparing the tree's points with the last fill (one number per tree), only
-- for the same tree of the same talent set, and only going up. The light is
-- made the first time; both run on DaylightUI's tween driver and stop when
-- done. With motion off, nothing.
local Motion = DUI.Motion
local GLOW = DUI.MEDIA and DUI.MEDIA .. "glow.png"
local function rowLight(box, row, pitch, size)
    local grid = box.grid
    if not (grid and grid.GetFrameLevel and GLOW and Motion and Motion.Sweep) then return end
    local light = box.blastaRowLight
    if not light then
        local holder = CreateFrame("Frame", nil, box)
        local tex = holder:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(GLOW)
        tex:SetBlendMode("ADD")
        tex:Hide()
        light = { holder = holder, tex = tex }
        box.blastaRowLight = light
    end
    local holder, tex = light.holder, light.tex
    holder:SetFrameLevel((grid:GetFrameLevel() or 1) + 10)
    holder:ClearAllPoints()
    holder:SetPoint("TOPLEFT", grid, "TOPLEFT", 0, -(row * pitch))
    holder:SetPoint("TOPRIGHT", grid, "TOPRIGHT", 0, -(row * pitch))
    holder:SetHeight(size)
    tex:SetHeight(size * 1.6)
    local ar, ag, ab = Style.Accent()
    Motion.Sweep(tex, holder, { width = pitch * 2.2, dur = .6, alpha = .45, color = { ar, ag, ab }, key = light })
end
local function labelPulse(l)
    if not (Motion and Motion.Tween) then return end
    local ar, ag, ab = Style.Accent()
    local off = Style.INK and Style.INK.OFF or { .5, .5, .5 }
    l.blastaPulse = l.blastaPulse or {}
    Motion.Tween(l.blastaPulse, 1, 0, .9, function(v)
        l:SetTextColor(off[1] + (ar - off[1]) * v, off[2] + (ag - off[2]) * v, off[3] + (ab - off[3]) * v, 1)
    end, function() Style.InkText(l, "OFF") end)
end
local function newRow(box, t, p, pitch, size)
    local spent = tonumber(t.spent) or 0
    local key = tostring(t.name) .. ":" .. tostring(Talents.group)
    local seen = box.blastaRowsSeen
    if not seen then
        box.blastaRowsSeen = { key = key, spent = spent }
        return
    end
    local before, same = seen.spent, seen.key == key
    seen.key, seen.spent = key, spent
    if not (same and spent > before and Motion and Motion.On and Motion.On()) then return end
    -- The highest row this change opened (one step opens one row).
    local row
    for r = 1, t.rows - 1 do
        local need = r * PER_ROW
        if need > before and need <= spent then row = r end
    end
    if not row then return end
    rowLight(box, row, pitch, size)
    if p.labels[row + 1] then labelPulse(p.labels[row + 1]) end
end

local function decorate(box, t, pitch, size)
    if not (box and t and type(t.rows) == "number" and type(pitch) == "number" and pitch > 0) then return end
    local p = parts(box)
    if box.blastaTalentStyle then
        for _, region in ipairs(p.bands) do region:Hide() end
        for _, region in ipairs(p.lines) do region:Hide() end
        p.sub:Hide(); p.mark:Hide()
        for i = 1, t.rows do
            local l = label(box, p, i)
            l:ClearAllPoints()
            l:SetPoint("CENTER", box, "TOPLEFT", 10, -((Talents.HEAD or 48) + (i - 1) * pitch + size / 2))
            l:SetText(tostring((i - 1) * PER_ROW))
            Style.InkText(l, "OFF"); l:Show()
        end
        for i = t.rows + 1, #p.labels do p.labels[i]:Hide() end
        newRow(box, t, p, pitch, size)
        return
    end
    box.blastaRowsSeen = nil
    p.sub:Show()
    local spent = tonumber(t.spent) or 0
    local head = Talents.HEAD or 38
    local ar, ag, ab = Style.Accent()
    local nextRow
    for r = 0, t.rows - 1 do
        local need = r * PER_ROW
        local open = spent >= need
        if not open and not nextRow then nextRow = r end
        local top = head + r * pitch + size / 2 - pitch / 2
        -- Quiet rows: a faint line between them, and only the next row tinted.
        local b = band(box, p, r + 1)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -top)
        b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -1, -top)
        b:SetHeight(pitch)
        if r == nextRow then
            b:SetVertexColor(ar, ag, ab, 0.05)
            b:Show()
            p.mark:ClearAllPoints()
            p.mark:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -(top + 4))
            p.mark:SetHeight(math.max(4, pitch - 8))
            p.mark:SetVertexColor(ar, ag, ab, 0.9)
        else
            b:Hide()
        end
        local sep = line(box, p, r + 1)
        if r > 0 then
            sep:ClearAllPoints()
            sep:SetPoint("TOPLEFT", box, "TOPLEFT", 4, -top)
            sep:SetPoint("TOPRIGHT", box, "TOPRIGHT", -4, -top)
            sep:SetVertexColor(1, 1, 1, 0.05)
            sep:Show()
        else
            sep:Hide()
        end
        local l = label(box, p, r + 1)
        l:ClearAllPoints()
        l:SetPoint("CENTER", box, "TOPLEFT", 4 + GUTTER / 2, -(head + r * pitch + size / 2))
        l:SetText(tostring(need))
        if r == nextRow then
            l:SetTextColor(Style.Pop())
        else
            Style.InkText(l, open and "LABEL" or "OFF")
        end
        l:Show()
    end
    for i = t.rows + 1, #p.bands do p.bands[i]:Hide() end
    for i = t.rows + 1, #p.lines do p.lines[i]:Hide() end
    p.mark:SetShown(nextRow ~= nil)
    for i = t.rows + 1, #p.labels do p.labels[i]:Hide() end
    -- Under the name: the next row's need, in the header's left column.
    p.sub:ClearAllPoints()
    if box.name then
        p.sub:SetPoint("TOPLEFT", box.name, "BOTTOMLEFT", 0, -1)
        p.sub:SetPoint("RIGHT", box, "RIGHT", -(Talents.PAD or 8), 0)
    end
    if nextRow then
        local more = nextRow * PER_ROW - spent
        p.sub:SetText(more == 1 and string.format(T("1 more to open row %d"), nextRow + 1)
            or string.format(T("%d more to open row %d"), more, nextRow + 1))
        Style.InkText(p.sub, "LABEL")
    else
        p.sub:SetText(T("All rows open"))
        Style.InkText(p.sub, "OFF")
    end
    -- The name moves up a little so both lines fit the header.
    if box.name and box.icon then
        box.name:ClearAllPoints()
        box.name:SetPoint("LEFT", box.icon, "RIGHT", 7, 6)
        if box.pts then box.name:SetPoint("RIGHT", box.pts, "LEFT", -6, 0) end
    end
    -- Keep the grid clear of the row numbers.
    if box.grid then
        local gw = box.grid:GetWidth() or 0
        local room = (box:GetWidth() or 0) - gw
        if room < 2 * (GUTTER + 4) then
            box.grid:ClearAllPoints()
            box.grid:SetPoint("TOPRIGHT", box, "TOPRIGHT", -(Talents.PAD or 8), -head)
            box.grid:SetSize(gw, box.grid:GetHeight())
        end
    end
end

local fill = Talents.FillTree
function Talents.FillTree(box, t, pitch, size, data, px, ...)
    local a, b = fill(box, t, pitch, size, data, px, ...)
    pcall(decorate, box, t, pitch, size)
    return a, b
end

extras.Loaded("TalentRows")
