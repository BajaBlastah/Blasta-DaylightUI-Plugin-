-- SPDX-License-Identifier: GPL-3.0-or-later
-- Training page (DaylightUI's spellbook, What's Training): beside DaylightUI's
-- "Learn now costs", the cost of everything still ahead: learnable now, the next
-- levels and later, pet spells and spells that wait on a requirement. Spells
-- that need a talent, weapon skills, known and ignored spells don't count.
-- Red when it's more than you carry.
local _, extras = ...
local DUI = DaylightUI
local Training = DUI.Book and DUI.Book.Training
local Style = DUI.Style
if not (Training and type(Training.Render) == "function" and type(Training.Groups) == "function"
    and Style and DUI.Widgets and DUI.Widgets.Money) then return end

local T = extras.Translate
local COUNTED = { "now", "needs", "next", "pet", "later" }

local function cost(sp) return type(sp) == "table" and type(sp.cost) == "number" and sp.cost > 0 and sp.cost or 0 end

local function ahead(groups)
    local total = 0
    for _, key in ipairs(COUNTED) do
        local g = groups[key]
        if key == "later" then
            for _, list in pairs(g or {}) do
                for _, sp in ipairs(list) do total = total + cost(sp) end
            end
        else
            for _, sp in ipairs(g or {}) do total = total + cost(sp) end
        end
    end
    return total
end

hooksecurefunc(Training, "Render", function(page)
    if type(page) ~= "table" or not page.foot then return end
    if not page.blastaTotal then
        local value = Style.Text(page.foot, Style.SIZE.body, "RIGHT")
        value:SetPoint("RIGHT", page.foot, "RIGHT", -4, 0)
        local label = Style.Text(page.foot, Style.SIZE.small, "RIGHT")
        label:SetPoint("RIGHT", value, "LEFT", -8, 0)
        label:SetText(T("Everything ahead costs"))
        Style.InkText(label, "LABEL")
        page.blastaTotal, page.blastaTotalLabel = value, label
    end
    local list = Training.list
    local total = list and ahead(Training.Groups(list)) or 0
    local value = page.blastaTotal
    if total > 0 then
        value:SetText(DUI.Widgets.Money(total, { color = false }))
        local cash = type(GetMoney) == "function" and GetMoney() or 0
        Style.InkText(value, total > cash and "BAD" or "MONEY")
    else
        value:SetText(DUI.L["Nothing"])
        Style.InkText(value, "LABEL")
    end
end)

extras.Loaded("TrainingTotal")
