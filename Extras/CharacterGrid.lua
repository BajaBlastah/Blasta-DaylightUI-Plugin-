-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
-- Pure geometry. Every equipment slot has its own rectangle and game button.
function extras.CharacterGrid(width, height, statsWidth, ammo, groupHeight, border)
    local edge, gap, top, footer = 16, 14, 12, 44
    local statsX = width - edge - statsWidth
    local modelW = math.min(230, math.max(175, math.floor(width * 0.205)))
    local gridX, gridRight = edge + modelW + gap, statsX - gap
    local gridW = math.max(160, gridRight - gridX)
    local cellGap = 10
    local colW = math.floor((gridW - cellGap) / 2)
    local available = height - footer - top - 8
    -- Leave real breathing room below each heading rule, including the
    -- equipment icon's outer quality border.
    local headH, groupGap = (groupHeight or 26) + 12, 6
    local pitch = math.min(46, (available - 3 * headH - 2 * groupGap) / 10)
    local tileH = pitch - 2
    -- Count the visible quality border, not just the icon texture. Otherwise
    -- neighbouring outlines touch even though their slot rectangles don't.
    local outline = math.max(0, tonumber(border) or 3)
    local icon = math.min(32, math.floor(pitch - 2 * outline - 6))
    local out = {
        model = { x = edge, y = -top, w = modelW, h = available - 130 },
        stats = { x = statsX, y = -top, w = statsWidth, h = available },
        summary = { x = edge, y = -top - available + 78, w = modelW, h = 42 },
        slots = {}, groups = {}, icon = icon, gridX = gridX, gridW = gridW,
    }
    local y = -top
    local function heading(key)
        out.groups[#out.groups + 1] = { key = key, x = gridX, y = y, w = gridW }
        y = y - headH
    end
    local function cell(key, col, wide)
        out.slots[key] = { x = gridX + (col - 1) * (colW + cellGap), y = y,
            w = wide and gridW or colW, h = tileH, icon = icon }
    end
    heading("Armor")
    for _, pair in ipairs({ { "Head", "Shoulder" }, { "Chest", "Back" }, { "Hands", "Wrist" }, { "Waist", "Legs" } }) do
        cell(pair[1], 1); cell(pair[2], 2); y = y - pitch
    end
    cell("Feet", 1)
    -- Cosmetics are icon-only, under the model; no names crowd the armor grid.
    local cosmeticGap = 2 * outline + 6
    local cosmeticX = edge + math.floor((modelW - 56 - cosmeticGap) / 2)
    out.slots.Shirt = { x = cosmeticX, y = -top - available + 122, w = 28, h = 28, icon = 28, cosmetic = true }
    out.slots.Tabard = { x = cosmeticX + 28 + cosmeticGap, y = -top - available + 122, w = 28, h = 28, icon = 28, cosmetic = true }
    y = y - pitch - groupGap
    heading("Jewelry")
    -- Pairs first, the single neck last on the left: every group then ends
    -- the same way (Feet, Neck, Ranged), with no gap right under another gap.
    cell("Finger0", 1); cell("Finger1", 2); y = y - pitch
    cell("Trinket0", 1); cell("Trinket1", 2); y = y - pitch
    cell("Neck", 1); y = y - pitch - groupGap
    heading("Weapons")
    cell("MainHand", 1); cell("SecondaryHand", 2); y = y - pitch
    cell("Ranged", 1)
    out.ammo = ammo or 0
    return out
end
