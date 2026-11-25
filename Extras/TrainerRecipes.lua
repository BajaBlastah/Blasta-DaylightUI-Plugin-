-- SPDX-License-Identifier: GPL-3.0-or-later
-- Recipes you can still learn, right in DaylightUI's profession window: a
-- "Learnable" group under the recipe list (it folds like the others) and,
-- for the one you click, a page on the right with what it needs, where to
-- learn it and its materials. It replaces the trip to What's Training's own
-- window; DaylightUI's link to it hides while this is on.
--
-- The recipe data (Data/Recipes) comes from What's Training? under the MIT
-- license (THIRD-PARTY.md). The rows use DaylightUI's own list pieces
-- (Win.Parts Stack lines and sections), so they look like the recipes above.
local ADDON, extras = ...
local DUI = DaylightUI
local craft = DUI.Craft
local list, window, data = craft and craft.List, craft and craft.Window, craft and craft.Data
local spellsRow = craft and craft.Spells
local Win, Style = DUI.Win, DUI.Style
local parts = Win and Win.Parts
local mod = DUI:GetModule("Professions")
local RECIPES = extras.TrainerRecipes
if not (mod and mod.defaults and RECIPES and list and list.Render and list.PaintPick and window and window.Pick
    and window.Refill and window.Close and window.Picked and data and data.Profession and data.Materials
    and parts and parts.Stack and parts.PickLine and parts.Hex and Style and Style.INK and Style.SIZE
    and DUI.MoneyString and extras.FindSetting(mod, "rarityNames")) then return end

local T = extras.Translate
local german = extras.German
local KEY = "blastaLearnable"
local FOLD, FOLD_SOON = "professionLearnFolded", "professionSoonFolded"
local SORT = "professionLearnSort"   -- "skill" (default) or "category"
mod.defaults[KEY] = true

for en, de in pairs({
    ["Learnable recipes in the window"] = "Lernbare Rezepte im Fenster",
    ["Recipes you can still learn show in their own group under the recipe list, with where to learn them and their materials. Replaces What's Training's window."] =
        "Rezepte, die du noch lernen kannst, stehen in einer eigenen Gruppe unter der Rezeptliste, mit Lernort und Materialien. Ersetzt das Fenster von What's Training.",
    ["Learnable"] = "Lernbar", ["Show"] = "Zeigen", ["Hide"] = "Ausblenden",
    ["Learn now"] = "Jetzt lernbar", ["Missing requirement"] = "Voraussetzung fehlt",
    ["Soon"] = "Bald", ["Later"] = "Später",
    ["Trainer"] = "Lehrer", ["Vendor"] = "Händler", ["Drop"] = "Beute", ["Quest"] = "Quest",
    ["Crafted"] = "Hergestellt", ["World object"] = "Weltobjekt", ["Discovery"] = "Entdeckung",
    ["from %d"] = "ab %d", ["Level %d"] = "Stufe %d", ["Reputation"] = "Ruf",
    ["%d now"] = "%d jetzt", ["Requirements"] = "Voraussetzungen", ["Where to learn"] = "Wo lernen",
    ["Materials"] = "Materialien", ["Skill %d (you: %d)"] = "Fertigkeit %d (du: %d)",
    ["Character level %d (you: %d)"] = "Charakterstufe %d (du: %d)",
    ["%s: %s"] = "%s: %s", ["Any trainer of this profession."] = "Bei jedem Lehrer dieses Berufs.",
    ["Sold in: %s"] = "Verkauft in: %s", ["Quest in: %s"] = "Quest in: %s", ["from level %d"] = "ab Stufe %d",
    ["Drops from enemies."] = "Beute von Gegnern.", ["Not known yet"] = "Noch nicht gelernt",
    ["Price before reputation discounts."] = "Preis vor Rabatt durch Ruf.",
    ["Materials show once the game has loaded this recipe."] = "Materialien erscheinen, sobald das Spiel das Rezept geladen hat.",
    ["Can't be learned by your faction."] = "Für deine Fraktion nicht lernbar.",
    ["Learnable soon"] = "Bald lernbar",
    ["Sorted: skill"] = "Sortiert: Fertigkeit", ["Sorted: category"] = "Sortiert: Kategorie",
    ["By skill"] = "Fertigkeit", ["By category"] = "Kategorie",
    ["Sorted by skill. Click to sort by category."] = "Nach Fertigkeit sortiert. Klicken, um nach Kategorie zu sortieren.",
    ["Sorted by category. Click to sort by skill."] = "Nach Kategorie sortiert. Klicken, um nach Fertigkeit zu sortieren.",
    ["Ranks"] = "Ränge", ["Other"] = "Sonstiges",
    ["Skill points: yellow from %s, green from %s, gray from %s"] = "Fertigkeitspunkte: gelb ab %s, grün ab %s, grau ab %s",
    ["Skill-up chance at %d: %s"] = "Chance auf einen Punkt bei %d: %s",
}) do german[en] = de end

extras.AddSetting(mod, "rarityNames", {
    type = "toggle", key = KEY, label = "Learnable recipes in the window",
    desc = "Recipes you can still learn show in their own group under the recipe list, with where to learn them and their materials. Replaces What's Training's window.",
})

local function on() return DUI:Get(mod.name, KEY) ~= false end
local function readable(v) return v ~= nil and not (issecretvalue and issecretvalue(v)) end
local function hex(c) return parts.Hex(c) end

-- What the list shows: now, missing a requirement, within reach soon. Later
-- ones show only while searching.
local NOW, MISSING, SOON, LATER = 1, 2, 3, 4
local SOON_SKILL = 15
local CATEGORY = {
    [NOW] = { label = "Learn now", ink = "GOOD" },
    [MISSING] = { label = "Missing requirement", ink = "WARN" },
    [SOON] = { label = "Soon", ink = "LABEL" },
    [LATER] = { label = "Later", ink = "OFF" },
}
local SOURCES = { trainer = "Trainer", vendor = "Vendor", drop = "Drop", quest = "Quest",
    crafted = "Crafted", world_object = "World object", discovery = "Discovery" }
local RANK_LIMIT = { Journeyman = 150, Expert = 225, Artisan = 300 }
local SOURCE_ORDER = { trainer = 1, quest = 2, vendor = 3, drop = 5 }
local RANKS = { Journeyman = "Journeyman", Expert = "Expert", Artisan = "Artisan" }
german["Journeyman"], german["Expert"], german["Artisan"] = german["Journeyman"] or "Geselle",
    german["Expert"] or "Experte", german["Artisan"] or "Fachmann"

-- Game data, guarded: the calls differ between clients.

local function playerFaction() return UnitFactionGroup and UnitFactionGroup("player") or nil end
local function playerLevel() local l = UnitLevel and UnitLevel("player"); return readable(l) and l or 0 end

local function knownSpell(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id, bank)
        if ok and readable(known) then return known == true end
    end
    if IsSpellKnown then
        local ok, known = pcall(IsSpellKnown, id)
        return ok and known == true
    end
    return false
end

local waiting = {}   -- spell ids whose names were requested
local function spellInfo(id)
    local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id)
    if type(info) ~= "table" and not waiting[id] and C_Spell and C_Spell.RequestLoadSpellData then
        waiting[id] = true
        pcall(C_Spell.RequestLoadSpellData, id)
    end
    return type(info) == "table" and info or nil
end

local function areaName(id)
    if C_Map and C_Map.GetAreaInfo then
        local ok, name = pcall(C_Map.GetAreaInfo, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
end

local function factionName(id)
    if C_Reputation and C_Reputation.GetFactionDataByID then
        local ok, f = pcall(C_Reputation.GetFactionDataByID, id)
        if ok and type(f) == "table" then return f.name, f.reaction end
    end
end

-- Reputation: { faction, standing, label, ... } in threes; any one is enough.
local function reputation(recipe)
    local rep = recipe.reputation
    if type(rep) ~= "table" then return true, nil end
    local met, names = false, {}
    for i = 1, #rep, 3 do
        local name, reaction = factionName(rep[i])
        if readable(reaction) and reaction >= rep[i + 1] then met = true end
        local standing = _G["FACTION_STANDING_LABEL" .. tostring(rep[i + 1])]
        names[#names + 1] = (name or T("Reputation")) .. (standing and (" (" .. standing .. ")") or "")
    end
    return met, table.concat(names, " / ")
end

-- Quest and vendor sources whose every place is the other faction's are left out.
local function usableSources(recipe)
    local mine, out = playerFaction(), {}
    for _, source in ipairs(recipe.source or {}) do
        local places = (source == "quest" and recipe.quests) or (source == "vendor" and recipe.vendors) or nil
        local keep = not places or #places == 0
        for _, p in ipairs(places or {}) do
            if not p.faction or p.faction == mine then keep = true end
        end
        if keep then out[#out + 1] = source end
    end
    return out
end

local function recipeName(recipe)
    local info = spellInfo(recipe.spell)
    local name = info and info.name or nil
    if recipe.rank then
        local rank = C_Spell and C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(recipe.spell)
        if type(rank) ~= "string" or rank == "" then rank = T(RANKS[recipe.rank] or recipe.rank) end
        if name then name = name .. " (" .. rank .. ")" end
    end
    return name, info
end

local function recipeIcon(recipe, info)
    if recipe.creates and C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(recipe.creates)
        if icon then return icon end
    end
    return info and info.iconID or 134400
end

-- Skill-up color and chance, from DaylightUI's ranges (the game's own data,
-- Craft/SkillUps.lua). A recipe not reachable yet is measured at the skill it
-- needs: the color it will have once learned.
local function skillUp(e)
    local range = data.Range and data.Range(e.recipe.spell)
    if not (range and data.ColorAt) then return end
    local at = math.max(e.skill, e.recipe.skill)
    e.range, e.at = range, at
    e.difficulty = data.ColorAt(range, at)
    if data.Chance then
        local ok, chance = pcall(data.Chance, { id = e.recipe.spell, difficulty = e.difficulty }, at)
        if ok then e.chance = chance end
    end
end

local function nameColor(e)
    if e.difficulty and data.Color then return data.Color(e.difficulty) end
    return Style.INK.VALUE
end

-- A recipe's category, as near to the list above as the game lets us get:
-- the game's own recipe category when it hands it out for an unlearned
-- recipe, else what the name starts with ("Brust - ..." for enchants), else
-- the slot or kind of the item it makes.
local categoryCache = {}
local function categoryOf(e)
    local r = e.recipe
    if r.rank then return T("Ranks") end
    local cached = categoryCache[r.spell]
    if cached then return cached end
    local name
    local api = C_TradeSkillUI
    if api and api.GetRecipeInfo and api.GetCategoryInfo then
        local ok, info = pcall(api.GetRecipeInfo, r.spell)
        if ok and type(info) == "table" and info.categoryID then
            local ok2, cat = pcall(api.GetCategoryInfo, info.categoryID)
            if ok2 and type(cat) == "table" and type(cat.name) == "string" and cat.name ~= "" then name = cat.name end
        end
    end
    if not name and e.name then
        local head = e.name:match("^(.-)%s+%-%s+")
        if head and head ~= "" then name = head end
    end
    if not name and r.creates and C_Item and C_Item.GetItemInfoInstant then
        local _, itemType, subType, equipLoc = C_Item.GetItemInfoInstant(r.creates)
        local slot = type(equipLoc) == "string" and equipLoc ~= "" and _G[equipLoc]
        name = (slot and subType and (subType .. " · " .. slot)) or subType or itemType
    end
    name = name or T("Other")
    if e.name then categoryCache[r.spell] = name end   -- keep it once the name is in
    return name
end

local function sortMode() return DUI:Get(ADDON, SORT) == "category" and "category" or "skill" end

-- The learnable recipes of a profession for this character, sorted:
-- category, required skill, name.
local function learnable(prof, learned)
    local recipes = RECIPES[prof.id]
    if type(recipes) ~= "table" then return {} end
    local skill = (prof.skill or 0) + (prof.bonus or 0)
    local max, level, mine = prof.max or 0, playerLevel(), playerFaction()
    -- A higher rank takes the lower ones out of the spellbook. The limit says
    -- it too (Expert gives 225), so ranks at or under it are held already.
    local knownRank = 0
    for _, r in ipairs(recipes) do
        local gives = r.rank and RANK_LIMIT[r.rank]
        if gives and gives <= max and r.skill > knownRank then knownRank = r.skill end
    end
    for _, r in ipairs(recipes) do
        if r.rank and r.skill > knownRank and knownSpell(r.spell) then knownRank = r.skill end
    end
    local out = {}
    for _, r in ipairs(recipes) do
        if (not r.faction or r.faction == mine) and not (r.rank and r.skill <= knownRank)
            and not (learned and learned[r.spell]) and not knownSpell(r.spell) then
            local sources = usableSources(r)
            if #sources > 0 then
                local repMet, repText = reputation(r)
                local cat
                if r.skill <= skill then
                    cat = ((r.level and r.level > 0 and r.level > level) or not repMet) and MISSING or NOW
                elseif r.skill <= skill + SOON_SKILL and r.skill <= math.max(max, skill) then
                    cat = SOON
                else
                    cat = LATER
                end
                local name, info = recipeName(r)
                local e = { recipe = r, cat = cat, sources = sources, name = name, info = info,
                    repMet = repMet, repText = repText, skill = skill }
                skillUp(e)
                out[#out + 1] = e
            end
        end
    end
    -- Within a category: trainer first, then quests and vendors, drops last.
    for _, e in ipairs(out) do
        local best = 9
        for _, s in ipairs(e.sources) do best = math.min(best, SOURCE_ORDER[s] or 4) end
        e.order = best
    end
    table.sort(out, function(a, b)
        if a.cat ~= b.cat then return a.cat < b.cat end
        if a.order ~= b.order then return a.order < b.order end
        if a.recipe.skill ~= b.recipe.skill then return a.recipe.skill < b.recipe.skill end
        return (a.name or "") < (b.name or "")
    end)
    return out
end

-- For the profession overview (ProfessionOverview.lua): how many recipes a
-- profession can learn now, are missing a requirement or come soon, what
-- the trainer ones cost, and its next rank. prof: { id, skill, bonus, max }.
-- Ranks are counted apart (rank = the next one, its entry).
local function trainerCostOf(entry)
    for _, s in ipairs(entry.sources) do
        if s == "trainer" and type(entry.recipe.cost) == "number" then return entry.recipe.cost end
    end
end

function extras.LearnableSummary(prof)
    local out = { now = 0, missing = 0, soon = 0, cost = 0, known = RECIPES[prof.id] ~= nil }
    for _, e in ipairs(learnable(prof, nil)) do
        if e.recipe.rank then
            if not out.rank or e.recipe.skill < out.rank.recipe.skill then out.rank = e end
        elseif e.cat == NOW then
            out.now = out.now + 1
            out.cost = out.cost + (trainerCostOf(e) or 0)
        elseif e.cat == MISSING then
            out.missing = out.missing + 1
        elseif e.cat == SOON then
            out.soon = out.soon + 1
        end
    end
    return out
end

local function trainerCost(entry)
    for _, s in ipairs(entry.sources) do
        if s == "trainer" and type(entry.recipe.cost) == "number" then return entry.recipe.cost end
    end
end

local function sourceText(entry)
    local bits = {}
    for _, s in ipairs(entry.sources) do bits[#bits + 1] = T(SOURCES[s] or s) end
    return table.concat(bits, ", ")
end

-- The sub line: skill-up chance (in its color), the skill it needs, where
-- from, then what's missing (orange).
local function subText(entry)
    local r, bits, ink = entry.recipe, {}, Style.INK
    -- Gray ones show no chance, like DaylightUI's own rows.
    local chance = entry.difficulty ~= data.TRIVIAL and data.ChanceText and data.ChanceText(entry.chance)
    if chance then bits[#bits + 1] = hex(nameColor(entry)) .. chance .. "|r" end
    local need = string.format(T("from %d"), r.skill)
    if r.skill > entry.skill then need = need .. " " .. hex(ink.WARN) .. "(+" .. (r.skill - entry.skill) .. ")|r" end
    bits[#bits + 1] = need
    bits[#bits + 1] = sourceText(entry)
    if entry.cat == MISSING then
        if r.level and r.level > 0 and r.level > playerLevel() then
            bits[#bits + 1] = hex(ink.WARN) .. string.format(T("Level %d"), r.level) .. "|r"
        end
        if not entry.repMet then bits[#bits + 1] = hex(ink.WARN) .. T("Reputation") .. "|r" end
    end
    return table.concat(bits, " · ")
end

-- The detail page on the right

local detail, detailStack, pickedSpell, pickedProf
local lines = {}   -- spell id -> the row showing it

local function recipePage()
    local f = window.frame
    return f and f.pages and f.pages.recipes
end

local function hideDetail()
    pickedSpell, pickedProf = nil, nil
    if detail then detail:Hide() end
    local page = recipePage()
    if page and page.recipe then page.recipe:Show() end
    for _, b in pairs(lines) do if b.lineSpec then parts.PickLine(b, false) end end
end

local function itemTip(owner, entry)
    if not GameTooltip then return end
    local r = entry.recipe
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok = false
    if r.teach and GameTooltip.SetItemByID then ok = pcall(GameTooltip.SetItemByID, GameTooltip, r.teach) end
    if not ok and r.creates and GameTooltip.SetItemByID then ok = pcall(GameTooltip.SetItemByID, GameTooltip, r.creates) end
    if not ok and GameTooltip.SetSpellByID then pcall(GameTooltip.SetSpellByID, GameTooltip, r.spell) end
    GameTooltip:Show()
end

local function places(list, mine)
    local seen, out = {}, {}
    for _, p in ipairs(list or {}) do
        if not p.faction or p.faction == mine then
            local name = p.area and areaName(p.area)
            if name and not seen[name] then seen[name] = true; out[#out + 1] = name end
        end
    end
    return out
end

-- What the detail page shows, as one string: a list repaint (every bag
-- update) only repaints the page when it changed, so a tooltip on it stays.
local detailSig
local function detailSignature(entry)
    local bits = { entry.recipe.spell, entry.cat, entry.skill, entry.name or "", tostring(entry.repMet), tostring(entry.chance) }
    local ok, mats = pcall(data.Materials, entry.recipe.spell)
    if ok and type(mats) == "table" then
        for _, m in ipairs(mats) do bits[#bits + 1] = tostring(m.itemID) .. "=" .. tostring(m.have) .. "/" .. tostring(m.need) end
    end
    return table.concat(bits, "|")
end

local function fillDetail(entry, keepScroll)
    local sig = detailSignature(entry)
    if keepScroll and sig == detailSig then return end
    detailSig = sig
    local s = detailStack
    local r, ink = entry.recipe, Style.INK
    local cat = CATEGORY[entry.cat]
    local at = keepScroll and s:Scrolled() or 0
    s:Begin()
    s:Line({ icon = recipeIcon(r, entry.info), text = entry.name or T("Not known yet"), color = nameColor(entry),
        sub = T(cat.label), subColor = ink[cat.ink], tooltip = function(b) itemTip(b, entry) end,
        id = "blasta:learnDetail" })
    local desc = C_Spell and C_Spell.GetSpellDescription and C_Spell.GetSpellDescription(r.spell)
    if type(desc) == "string" and desc ~= "" and readable(desc) then s:Text(desc, { color = ink.TEXT }) end

    s:Section(T("Requirements"))
    local skillOk = r.skill <= entry.skill
    s:Text(hex(skillOk and ink.GOOD or ink.WARN) .. string.format(T("Skill %d (you: %d)"), r.skill, entry.skill) .. "|r")
    if r.level and r.level > 0 then
        local lvl = playerLevel()
        s:Text(hex(r.level <= lvl and ink.GOOD or ink.WARN) .. string.format(T("Character level %d (you: %d)"), r.level, lvl) .. "|r")
    end
    if entry.repText then
        s:Text(hex(entry.repMet and ink.GOOD or ink.WARN) .. string.format(T("%s: %s"), T("Reputation"), entry.repText) .. "|r")
    end
    local range = entry.range
    if range and data.Color then
        local function at(v, d) return hex(data.Color(d)) .. v .. "|r" end
        s:Text(string.format(T("Skill points: yellow from %s, green from %s, gray from %s"),
            at(range.yellow, data.MEDIUM), at(range.green, data.EASY), at(range.gray, data.TRIVIAL)),
            { size = Style.SIZE.small, color = ink.LABEL })
        local chance = data.ChanceText and data.ChanceText(entry.chance)
        if chance then
            s:Text(string.format(T("Skill-up chance at %d: %s"), entry.at, hex(nameColor(entry)) .. chance .. "|r"),
                { size = Style.SIZE.small, color = ink.LABEL })
        end
    end

    s:Section(T("Where to learn"))
    local mine = playerFaction()
    for _, source in ipairs(entry.sources) do
        local label = hex(ink.VALUE) .. T(SOURCES[source] or source) .. "|r"
        if source == "trainer" then
            s:Text(label .. "  " .. hex(ink.LABEL) .. T("Any trainer of this profession.") .. "|r")
            if type(r.cost) == "number" and r.cost > 0 then
                s:Money(r.cost)
                s:Text(T("Price before reputation discounts."), { size = Style.SIZE.small, color = ink.LABEL })
            end
        elseif source == "vendor" then
            local where = places(r.vendors, mine)
            s:Text(label .. (#where > 0 and ("  " .. hex(ink.LABEL) .. string.format(T("Sold in: %s"), table.concat(where, ", ")) .. "|r") or ""))
        elseif source == "quest" then
            local where, lvl = places(r.quests, mine), nil
            for _, q in ipairs(r.quests or {}) do
                if (not q.faction or q.faction == mine) and q.level then lvl = math.min(lvl or q.level, q.level) end
            end
            local text = #where > 0 and string.format(T("Quest in: %s"), table.concat(where, ", ")) or ""
            if lvl then text = text .. (text ~= "" and ", " or "") .. string.format(T("from level %d"), lvl) end
            s:Text(label .. (text ~= "" and ("  " .. hex(ink.LABEL) .. text .. "|r") or ""))
        elseif source == "drop" then
            s:Text(label .. "  " .. hex(ink.LABEL) .. T("Drops from enemies.") .. "|r")
        else
            s:Text(label)
        end
    end

    -- A rank (Journeyman, Expert...) is taught, not made: no materials.
    local ok, mats = false, nil
    if not r.rank then
        s:Section(T("Materials"))
        ok, mats = pcall(data.Materials, r.spell)
    end
    if r.rank then
        -- nothing to list
    elseif ok and type(mats) == "table" and #mats > 0 then
        for i, m in ipairs(mats) do
            local enough = (m.have or 0) >= (m.need or 1)
            s:Line({ icon = m.icon, text = m.name or "…", value = string.format("%d / %d", m.have or 0, m.need or 1),
                valueColor = enough and ink.GOOD or ink.BAD, id = "blasta:learnMat:" .. i,
                tooltip = function(b)
                    if GameTooltip and GameTooltip.SetItemByID then
                        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                        pcall(GameTooltip.SetItemByID, GameTooltip, m.itemID)
                        GameTooltip:Show()
                    end
                end })
        end
    else
        s:Text(T("Materials show once the game has loaded this recipe."), { color = ink.LABEL })
    end
    s:End()
    if at > 0 then s:ScrollTo(at) end
end

local function showDetail(entry, prof)
    local page = recipePage()
    if not (page and page.recipe) then return end
    if not detail then
        detail = CreateFrame("Frame", nil, page)
        detail:SetAllPoints(page.recipe)
        detail.win = window.frame
        detailStack = parts.Stack(detail, { top = 12, bottom = 12 })
    end
    pickedSpell, pickedProf = entry.recipe.spell, prof.id
    page.recipe:Hide()
    detail:Show()
    fillDetail(entry)
    list.PaintPick(nil)
    for spell, b in pairs(lines) do parts.PickLine(b, spell == pickedSpell) end
end

-- The group in the list

local current = {}   -- spell id -> entry, for the rows shown

local function folded(key) return DUI:Get(ADDON, key) == true end

local function rowTip(b)
    local entry = b.lineSpec and b.lineSpec.blastaLearn
    if entry then itemTip(b, entry) end
end

local function addRow(s, e, prof)
    local r = e.recipe
    local value = trainerCost(e)
    local b = s:Line({ icon = recipeIcon(r, e.info), text = e.name or "…", color = nameColor(e), sub = subText(e),
        value = value and value > 0 and (hex(Style.INK.MONEY) .. DUI.MoneyString(value) .. "|r") or "",
        picked = pickedSpell == r.spell, tooltip = rowTip, blastaLearn = e,
        onClick = function() showDetail(e, prof) end, id = "blasta:learn:" .. tostring(r.spell) })
    -- DaylightUI can reuse a learned recipe row with its chance or profit still visible.
    if b.chance then b.chance:Hide() end
    if b.profit then b.profit:Hide() end
    b.value:ClearAllPoints()
    b.value:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    lines[r.spell] = b
    current[r.spell] = e
end

-- One foldable group: its heading (with a value), the sort switch on the
-- first one, and its rows; by category, each category gets a small heading.
local sortLinks = setmetatable({}, { __mode = "k" })
local function sortLink(b, shown)
    if not (DUI.Widgets and DUI.Widgets.Link) then return end
    local l = sortLinks[b]
    if not l and shown then
        l = DUI.Widgets.Link(b, Style.SIZE.small)
        l:SetScript("OnClick", function()
            DUI:Set(ADDON, SORT, sortMode() == "category" and "skill" or "category")
            list.Render(list.pane, true)
        end)
        -- One word on the header; what it means on hover.
        l:HookScript("OnEnter", function(self)
            if not GameTooltip then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(T(sortMode() == "category" and "Sorted by category. Click to sort by skill."
                or "Sorted by skill. Click to sort by category."), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        l:HookScript("OnLeave", function(self)
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        sortLinks[b] = l
    end
    if not l then return end
    l:SetShown(shown)
    if not shown then return end
    l.SetLabel(T(sortMode() == "category" and "By category" or "By skill"))
    l:ClearAllPoints()
    if b.action:IsShown() then l:SetPoint("BOTTOMRIGHT", b.action, "BOTTOMLEFT", -12, 0)
    else l:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0) end
end

local function group(s, label, key, rows, value, prof, search, first)
    if #rows == 0 then return 0 end
    local isFolded = folded(key) and not search
    local head = s:Section(label, { value = value, action = { text = isFolded and T("Show") or T("Hide"), onClick = function()
        DUI:Set(ADDON, key, not folded(key))
        list.Render(list.pane, true)
    end } })
    if head and head.action then sortLink(head, first == true) end
    if isFolded then return #rows end
    if sortMode() == "category" then
        local byCat, order = {}, {}
        for _, e in ipairs(rows) do
            local c = categoryOf(e)
            if not byCat[c] then byCat[c] = {}; order[#order + 1] = c end
            table.insert(byCat[c], e)
        end
        table.sort(order, function(a, b)
            if a == T("Ranks") then return true elseif b == T("Ranks") then return false end
            return a < b
        end)
        for i, c in ipairs(order) do
            if i > 1 and s.Gap then s:Gap(4) end
            s:Text(hex(Style.INK.LABEL) .. (Style.Upper and Style.Upper(c) or c) .. "|r", { size = Style.SIZE.small })
            table.sort(byCat[c], function(a, b)
                if a.recipe.skill ~= b.recipe.skill then return a.recipe.skill < b.recipe.skill end
                return (a.name or "") < (b.name or "")
            end)
            for _, e in ipairs(byCat[c]) do addRow(s, e, prof) end
        end
    else
        for _, e in ipairs(rows) do addRow(s, e, prof) end
    end
    return #rows
end

local function addGroup(s)
    wipe(lines)
    wipe(current)
    local prof = list.data and list.data.prof
    if not prof or (data.Viewing and data.Viewing()) then return 0 end
    local chips = list.chipOn or {}
    if chips.mats or list.slot then return 0 end
    local search = list.filter
    local now, soon, ready, cost = {}, {}, 0, 0
    for _, e in ipairs(learnable(prof, list.data.byID)) do
        local match = not search or (e.name and string.find(string.lower(e.name), search, 1, true))
        if match then
            if e.cat == NOW or e.cat == MISSING then now[#now + 1] = e
            elseif e.cat == SOON or search then soon[#soon + 1] = e end
        end
        if e.cat == NOW then
            ready = ready + 1
            cost = cost + (trainerCost(e) or 0)
        end
    end
    -- Just the count: with the price the header ran out of room (the price
    -- of each recipe is in its details when you click it).
    local value = string.format(T("%d now"), ready)
    local n = group(s, T("Learnable"), FOLD, now, value, prof, search, true)
    if n > 0 and #soon > 0 and s.Gap then s:Gap(8) end
    return n + group(s, T("Learnable soon"), FOLD_SOON, soon, nil, prof, search, n == 0)
end

-- DaylightUI fills its list in List.Render; the group goes in just before
-- the stack closes, so it sits under the learned recipes and scrolls with them.
local render = list.Render
function list.Render(pane, keepScroll)
    pane = pane or list.pane
    local s = pane and pane.stack
    local prof = list.data and list.data.prof
    if pickedProf and (not prof or prof.id ~= pickedProf) then hideDetail() end
    if not (s and on()) then
        wipe(lines)
        if detail and detail:IsShown() then hideDetail() end
        return render(pane, keepScroll)
    end
    local count = 0
    local finish = s.End
    s.End = function(self, ...)
        if #(self.pieces or {}) > 0 and self.Gap then self:Gap(12) end
        local ok, n = pcall(addGroup, self)
        count = ok and n or 0
        if not ok then geterrorhandler()(n) end
        return finish(self, ...)
    end
    local ok, err = pcall(render, pane, keepScroll)
    s.End = nil
    if not ok then error(err, 0) end
    if count > 0 and pane.note then pane.note:Hide() end
    -- The picked recipe was learned or left the list: back to the game's page.
    if pickedSpell and not current[pickedSpell] then hideDetail()
    elseif pickedSpell and current[pickedSpell] and detail and detail:IsShown() then
        pcall(fillDetail, current[pickedSpell], true)
    end
end

-- Picking a learned recipe brings DaylightUI's page back. The same recipe as
-- before is a no-op in DaylightUI, so its highlight is put back here.
local pick = window.Pick
function window.Pick(id, ...)
    local wasOurs = detail and detail:IsShown()
    hideDetail()
    local result = pick(id, ...)
    if wasOurs then list.PaintPick(window.Picked()) end
    return result
end

local refill = window.Refill
function window.Refill(...)
    hideDetail()
    return refill(...)
end

local close = window.Close
function window.Close(...)
    hideDetail()
    return close(...)
end

-- DaylightUI links to What's Training's window under the list; with the
-- recipes here that link isn't needed.
if spellsRow and spellsRow.Training then
    local training = spellsRow.Training
    function spellsRow.Training(...)
        if on() then return nil end
        return training(...)
    end
end

-- Names arrive later for spells the client hadn't cached, and a level-up or
-- reputation change can move a recipe up.
local function soon() if list.Soon then list.Soon(0.2) end end
pcall(DUI.RegisterEvent, "SPELL_DATA_LOAD_RESULT", function(_, id)
    if waiting[id] then waiting[id] = nil; soon() end
end)
-- pcall: an event this client doesn't have would raise an error.
for _, event in ipairs({ "PLAYER_LEVEL_UP", "UPDATE_FACTION", "SKILL_LINES_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE" }) do
    pcall(DUI.RegisterEvent, event, soon)
end
DUI.On("SettingChanged", function(scope, path)
    if scope == mod.name and path == KEY then
        if not on() then hideDetail() end
        if list.pane then list.Render(list.pane, true) end
        if spellsRow and spellsRow.Fill then pcall(spellsRow.Fill) end
    end
end)

extras.Loaded("TrainerRecipes")
