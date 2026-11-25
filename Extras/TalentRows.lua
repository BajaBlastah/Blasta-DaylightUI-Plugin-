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

local function decorate(box, t, pitch, size)
    if not (box and t and type(t.rows) == "number" and type(pitch) == "number" and pitch > 0) then return end
    local p = parts(box)
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
