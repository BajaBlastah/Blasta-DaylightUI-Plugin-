local ADDON, extras = ...
local DUI = DaylightUI
local spells = DUI.Book and DUI.Book.Spells
if not (spells and type(spells.Pickup) == "function") then return end

local function passive(cell)
    if cell.passive then return true end
    local check = C_Spell and C_Spell.IsSpellPassive
    local id = cell.spellID
    if not check or type(id) ~= "number" or (issecretvalue and issecretvalue(id)) then return false end
    local value = check(id)
    return not (issecretvalue and issecretvalue(value)) and value == true
end

local pickup = spells.Pickup
function spells.Pickup(cell, ...)
    if cell and passive(cell) then return end
    return pickup(cell, ...)
end

local widgets = DUI.Widgets
if not (GetActionInfo and spells.Soon and spells.Build and spells.Render and spells.Freeze and spells.Fill
    and widgets and widgets.Chip) then return end

local assigned, macroNames, dirty = {}, {}, true
local slotCount = math.max(180, tonumber(Constants and Constants.ActionBarConsts and Constants.ActionBarConsts.NUM_ACTIONBAR_SLOTS) or 0)

local function plain(value)
    return not (issecretvalue and issecretvalue(value))
end

local function macroSpell(id)
    if not GetMacroSpell then return end
    local spell, _, legacyID = GetMacroSpell(id)
    if plain(legacyID) and type(legacyID) == "number" and legacyID > 0 then return legacyID end
    if not plain(spell) then return end
    if type(spell) == "number" and spell > 0 then return spell end
    if type(spell) == "string" and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        return info and info.spellID
    end
end

local function recordMacro(id, name)
    local spellID = id and macroSpell(id)
    if plain(spellID) and type(spellID) == "number" then assigned[spellID] = true end
    local key = id or name
    if not key then return end
    local body = GetMacroBody and GetMacroBody(key)
    if (not plain(body) or type(body) ~= "string") and GetMacroInfo then
        local _, _, text = GetMacroInfo(key)
        body = text
    end
    if (not plain(body) or type(body) ~= "string") and id and name and GetMacroBody then
        body = GetMacroBody(name)
    end
    if not plain(body) or type(body) ~= "string" then return end
    -- Read each /cast option without evaluating its current mouseover or target.
    local commands = { ["/cast"] = true }
    for i = 1, 16 do
        local alias = _G["SLASH_CAST" .. i]
        if not alias then break end
        commands[alias:lower()] = true
    end
    for line in body:gmatch("[^\r\n]+") do
        local command, options = line:match("^%s*(/%S+)%s+(.+)$")
        if command and commands[command:lower()] then
            for option in options:gmatch("[^;]+") do
                local name = option:gsub("%b[]", ""):match("^%s*!?(.-)%s*$")
                if name ~= "" then
                    -- A rankless cast uses the highest known rank. The spell
                    -- API can return a different ID when resolving only a name.
                    local base, rank = name:match("^(.-)%s*%(([^()]*%d[^()]*)%)$")
                    local key = (base or name):lower()
                    local ranks = macroNames[key] or {}
                    macroNames[key] = ranks
                    ranks[rank and rank:match("%d+") or "highest"] = true
                end
            end
        end
    end
end

local function macroForSlot(slot, id)
    -- Action text is the macro name. Prefer the macro index resolved from it
    -- when GetActionInfo omits the index or reports a different numeric ID.
    local name = GetActionText and GetActionText(slot)
    if not plain(name) or type(name) ~= "string" or name == "" then name = nil end
    local index = name and GetMacroIndexByName and GetMacroIndexByName(name)
    if plain(index) and type(index) == "number" and index > 0 then return index, name end
    if plain(id) and type(id) == "number" and id > 0 then return id, name end
    return nil, name
end

local function unassigned(cell, lowerRank)
    local id = cell.spellID
    if cell.future or not plain(id) or type(id) ~= "number" or passive(cell) then return false end
    if dirty then
        dirty = false
        wipe(assigned)
        wipe(macroNames)
        local macros = {}
        for slot = 1, slotCount do
            local kind, spellID = GetActionInfo(slot)
            if plain(kind) and kind == "macro" then
                local id, name = macroForSlot(slot, spellID)
                local key = id or name
                if key and not macros[key] then
                    macros[key] = true
                    recordMacro(id, name)
                end
            elseif plain(kind) and kind == "spell" and plain(spellID) and type(spellID) == "number" then
                assigned[spellID] = true
            end
        end
    end
    local ranks = cell.name and macroNames[cell.name:lower()]
    local rank = cell.rank and cell.rank:match("%d+")
    return not (assigned[id] or (ranks and not cell.pet and
        ((not lowerRank and not cell.low and ranks.highest) or (rank and ranks[rank]))))
end

local function repaint()
    if spells.page and spells.page:IsVisible() then spells.Soon() end
end

for _, event in ipairs({ "ACTIONBAR_SLOT_CHANGED", "SPELLS_CHANGED", "UPDATE_MACROS",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED" }) do
    DUI.RegisterEvent(event, function()
        dirty = true
        repaint()
    end)
end

local style = DUI.Style
local squareKey = "squareSpellbookIcons"
if style and style.GetShell and style.LayoutShell and spells.PaintCell then
    extras.SpellbookGroup = { label = "Appearance", items = {
        { type = "toggle", key = squareKey, label = "Square spellbook icons",
            desc = "Show spell icons without rounded corners." },
    } }
    hooksecurefunc(spells, "PaintCell", function(button)
        local shell = style.GetShell(button.well)
        if not shell then return end
        local corner = DUI:Get(ADDON, squareKey) == true and 0 or nil
        if shell.opts.cornerPx ~= corner then
            shell.opts.cornerPx = corner
            style.LayoutShell(shell)
        end
    end)
    DUI.On("SettingChanged", function(scope, key)
        if scope ~= ADDON or key ~= squareKey then return end
        spells.Soon()
    end)
end

local filterLabel = "Missing from action bars"
local function filterUsable()
    return not (spells.frozen or spells.binding or InCombatLockdown())
end

hooksecurefunc(spells, "Build", function(page)
    local button = widgets.Chip(page, extras.Translate(filterLabel))
    button.FitWidth()
    button:SetPoint("BOTTOM", page, "BOTTOM", 0, 10)
    button:SetScript("OnClick", function()
        if not filterUsable() then return end
        page.blastaOnlyUnassigned = not page.blastaOnlyUnassigned
        spells.Fill(page)
    end)
    page.blastaUnassignedFilter = button
end)

local function refreshFilter(page)
    local button = page and page.blastaUnassignedFilter
    if not button then return end
    local usable = filterUsable()
    button:EnableMouse(usable)
    button:SetAlpha(usable and 1 or 0.45)
    local on = page.blastaOnlyUnassigned and true or false
    if (button.on == true) ~= on then button.SetOn(on) end
end

hooksecurefunc(spells, "Freeze", function() refreshFilter(spells.page) end)

local function copyCell(cell)
    local copy = {}
    for key, value in pairs(cell) do copy[key] = value end
    copy.lows = {}
    return copy
end

local render = spells.Render
function spells.Render(page)
    refreshFilter(page)
    local sections = spells.data and spells.data.sections
    if not (page.blastaOnlyUnassigned and filterUsable() and sections) then return render(page) end

    -- Keep the original section objects so school chips still jump to the right rows.
    local originals = {}
    for i, section in ipairs(sections) do
        local cells = {}
        originals[i] = section.spells
        for _, cell in ipairs(section.spells) do
            if unassigned(cell) then
                local copy = copyCell(cell)
                for _, low in ipairs(cell.lows) do
                    if unassigned(low, true) then copy.lows[#copy.lows + 1] = low end
                end
                cells[#cells + 1] = copy
            else
                for _, low in ipairs(cell.lows) do
                    if unassigned(low, true) then
                        cells[#cells + 1] = copyCell(low)
                    end
                end
            end
        end
        section.spells = cells
    end
    local search = spells.filter
    spells.filter = search or ""
    local ok, err = pcall(render, page)
    spells.filter = search
    for i, section in ipairs(sections) do section.spells = originals[i] end
    if not ok then error(err, 0) end
    if not next(spells.sectionAt) and not search then
        page.note:SetText(extras.Translate("No spells missing from action bars."))
    end
end

extras.Loaded("Spellbook")
