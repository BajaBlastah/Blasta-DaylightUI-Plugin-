local _, extras = ...
local DUI = DaylightUI
local training = DUI.Book and DUI.Book.Training
local active = extras.UsingBlastaTraining
local reputation = C_Reputation and C_Reputation.GetFactionDataByID
if not (active and reputation and training and training.Build and training.Render) then return end

local data = extras.TrainingData
local factions = data.TrainerFactions
local _, class = UnitClass("player")
local style, tips = DUI.Style, DUI.Tips
local german = extras.German
german["Cheapest"] = "Am günstigsten"
german["Training discounts"] = "Trainerrabatte"
german["Lowest total by faction (estimate)"] = "Günstigste Fraktion (geschätzt)"

local function money(value)
    return DUI.Widgets.Money(value, { color = false })
end

local function estimate(faction, base)
    local info = reputation(faction)
    if not (info and info.name and type(info.reaction) == "number") then return end
    -- The Forever table documents no discount at Friendly and 10% from
    -- Honored. Keep this an estimate until checked against the live trainer.
    local pct = info.reaction >= 6 and 10 or 0
    return { name = info.name, pct = pct, price = math.floor((base * (100 - pct) + 50) / 100) }
end

local function pricesFor(row, side)
    local prices = {}
    if row.quest or row.isItem or not row.cost or row.cost <= 0 then return prices end
    if row.status:find("^weapon") then
        local weapon = data.WeaponSkills[row.id]
        for _, trainer in ipairs(weapon and weapon.trainers[side] or {}) do
            local faction = factions.npcs[trainer.npc]
            if faction and not prices[faction] then prices[faction] = estimate(faction, row.cost) end
        end
    else
        local pets = data.classes[class].petAbilityIds
        local role = pets and pets[row.id] and factions.roles.PET or factions.roles[class]
        for _, faction in ipairs(role and role[side] or {}) do
            prices[faction] = estimate(faction, row.cost)
        end
    end
    return prices
end

local function cheapestFirst(a, b)
    if a.price ~= b.price then return a.price < b.price end
    return a.name < b.name
end

local function showPrices(row, tooltip)
    local sorted = {}
    for _, price in pairs(pricesFor(row, UnitFactionGroup("player"))) do
        if price.price < row.cost then sorted[#sorted + 1] = price end
    end
    if #sorted == 0 then return end
    table.sort(sorted, cheapestFirst)
    tips.Clear()
    tips.Gap()
    tips.Sub(extras.Translate("Training discounts"))
    for _, entry in ipairs(sorted) do
        local best = entry.price == sorted[1].price
        local label = entry.name .. (" (−%d%%)"):format(entry.pct)
        if best then label = label .. " · " .. extras.Translate("Cheapest") end
        tips.Line(label, money(entry.price), best and style.INK.GOOD or style.INK.MONEY)
    end
    tips.Flush(tooltip)
    tooltip:Show()
end

local function bestTotal(rows)
    local side = UnitFactionGroup("player")
    local totals
    for _, row in ipairs(rows or {}) do
        if row.status == "available" and row.cost and row.cost > 0 then
            local prices = pricesFor(row, side)
            if not totals then
                totals = prices
            else
                -- Keep only factions with a price for every paid lesson.
                for faction, total in pairs(totals) do
                    local match = prices[faction]
                    if match then total.price = total.price + match.price else totals[faction] = nil end
                end
            end
            if not next(totals) then return end
        end
    end
    local best
    for _, total in pairs(totals or {}) do
        if not best or cheapestFirst(total, best) then best = total end
    end
    return best
end

local rowsByKey = {}
hooksecurefunc(training, "Build", function(page)
    local stack = page.stack
    if not (stack and stack.Line and stack.scroll and page.foot and page.totalLabel) then return end
    local line = stack.Line
    function stack:Line(spec)
        local row, original = rowsByKey[spec.id], spec.tooltip
        if row and original then
            spec.tooltip = function(button)
                original(button)
                local tooltip = GameTooltip
                if tooltip and tooltip:IsOwned(button) then showPrices(row, tooltip) end
            end
        end
        return line(self, spec)
    end
    local summary = style.Text(page.foot, style.SIZE.small, "LEFT")
    summary:SetPoint("BOTTOMLEFT", page.foot, "BOTTOMLEFT", 0, -5)
    summary:SetPoint("RIGHT", page.foot, "RIGHT", 0, 0)
    style.InkText(summary, "LABEL")
    summary:Hide()
    page.blastaTrainerPrice = summary
end)

local render = training.Render
function training.Render(page)
    wipe(rowsByKey)
    if active() and page.blastaTrainerPrice then
        for _, row in ipairs(training.list or {}) do rowsByKey["wt:" .. tostring(row.id)] = row end
    end
    local summary = page.blastaTrainerPrice
    if summary then
        local best = active() and bestTotal(training.list)
        if best then
            summary:SetText(extras.Translate("Lowest total by faction (estimate)")
                .. " · " .. best.name .. " · " .. money(best.price))
        end
        summary:SetShown(best and true or false)
        page.totalLabel:SetPoint("LEFT", page.foot, "LEFT", 0, best and 6 or 0)
        page.stack.scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -page.stack.side,
            training.FOOT + (best and 12 or 0))
    end
    return render(page)
end

DUI.RegisterEvent("UPDATE_FACTION", function()
    if active() then training.Soon() end
end)
