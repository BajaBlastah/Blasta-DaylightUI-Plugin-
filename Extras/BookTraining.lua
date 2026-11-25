local _, extras = ...
local DUI = DaylightUI
local training = DUI.Book and DUI.Book.Training
local data = extras.TrainingData
if not (training and training.On and training.Read and training.Soon and C_Spell and C_Spell.GetSpellInfo) then return end

local _, token = UnitClass("player")
local class = data.classes[token]
if not (class and class.spellsByLevel) then return end

local nativeOn, nativeRead = training.On, training.Read
local providerKey, external = "blastaTrainingProvider", "WhatsTraining"
local function character()
    return DUI.DB.Character()
end

function extras.UsingBlastaTraining()
    return not nativeOn() and character()[providerKey] ~= "external"
end
local function contains(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

local bank = Enum and Enum.SpellBookSpellBank
local function known(id, pet)
    if not id then return false end
    if C_SpellBook and bank then
        local spellBank = pet and bank.Pet or bank.Player
        if C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id, spellBank) then return true end
        if C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(id, spellBank, false) then return true end
    end
    return IsSpellKnown and IsSpellKnown(id, pet) == true
end

local requested = {}
local function spellInfo(id)
    local info = C_Spell.GetSpellInfo(id)
    if not info and not requested[id] and C_Spell.RequestLoadSpellData then
        requested[id] = true
        C_Spell.RequestLoadSpellData(id)
    end
    return info
end

function training.On() return nativeOn() or extras.UsingBlastaTraining() end

function training.Read()
    if not extras.UsingBlastaTraining() then
        if nativeOn() then return nativeRead() end
        return nil
    end

    local level = UnitLevel("player")
    local race = select(3, UnitRace("player"))
    local faction = UnitFactionGroup("player")
    local rows, added, replaced = {}, {}, {}
    local petAbilities = class.petAbilityIds or {}
    for _, group in ipairs(class.overriddenGroups or {}) do
        local learned
        for i = #group, 1, -1 do
            if not learned then learned = known(group[i]) end
            if learned then replaced[group[i]] = true end
        end
    end

    local function learned(id) return replaced[id] or known(id) end
    local function status(entry, requiredLevel)
        local id = entry.id
        if petAbilities[id] then return known(id, true) and "knownPet" or "pet" end
        if learned(id) then return "known" end
        if entry.requiredTalentId and not learned(entry.requiredTalentId) then return "missingTalent" end
        if requiredLevel > level then return requiredLevel == level + 1 and "nextLevel" or "notLevel" end
        for _, required in ipairs(entry.requiredIds or {}) do
            if not learned(required) then return "missingReqs" end
        end
        return "available"
    end

    local function addSpell(id, requiredLevel, cost, state, quest)
        if added[id] then return end
        local info = spellInfo(id)
        if not (info and info.name) then return end
        added[id] = true
        rows[#rows + 1] = {
            id = id, name = info.name, icon = info.iconID,
            subText = C_Spell.GetSpellSubtext and C_Spell.GetSpellSubtext(id),
            level = requiredLevel, cost = cost, status = state, quest = quest,
        }
    end

    for id, choices in pairs(data.QuestSpells[token] or {}) do
        for _, quest in ipairs(choices) do
            if contains(quest.races, race) then
                local state = status({ id = id }, quest.level)
                addSpell(id, quest.level, 0, state == "available" and "missingReqs" or state, true)
                break
            end
        end
    end

    for requiredLevel, entries in pairs(class.spellsByLevel) do
        for _, entry in ipairs(entries) do
            if (not entry.faction or entry.faction == faction)
                and (not entry.race or entry.race == race)
                and (not entry.races or contains(entry.races, race)) then
                addSpell(entry.id, requiredLevel, entry.cost, status(entry, requiredLevel))
            end
        end
    end

    for id, weapon in pairs(data.WeaponSkills) do
        if weapon.classes[token] then
            local requiredLevel = weapon.level or 1
            local state = known(id) and "weaponKnown" or requiredLevel <= level and "weaponAvailable"
                or requiredLevel == level + 1 and "weaponNextLevel" or "weaponNotLevel"
            addSpell(id, requiredLevel, weapon.cost or 1000, state)
        end
    end

    if C_Item and C_Item.GetItemInfo then
        for requiredLevel, tomes in pairs(class.tomesByLevel or {}) do
            for _, tome in ipairs(tomes) do
                local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(tome.itemId)
                if name then
                    rows[#rows + 1] = {
                        id = tome.id or ("item:" .. tome.itemId), itemId = tome.itemId,
                        name = name, icon = icon, isItem = true, level = requiredLevel, cost = tome.cost,
                        status = known(class.tomeTaughtSpells[tome.itemId], true) and "knownPet" or "pet",
                    }
                end
            end
        end
    end
    return rows
end

local function refresh()
    if extras.UsingBlastaTraining() then training.Soon() end
end
for _, event in ipairs({ "PLAYER_LEVEL_UP", "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "UNIT_PET", "QUEST_TURNED_IN" }) do
    DUI.RegisterEvent(event, refresh)
end
DUI.RegisterEvent("SPELL_DATA_LOAD_RESULT", function(_, id)
    if requested[id] then refresh() end
end)
if class.tomesByLevel then DUI.RegisterEvent("GET_ITEM_INFO_RECEIVED", refresh) end

local addons, widgets = C_AddOns, DUI.Widgets
if not (addons and (addons.DoesAddOnExist or addons.GetAddOnInfo) and addons.GetAddOnEnableState and addons.DisableAddOn
    and addons.EnableAddOn and widgets and widgets.Ask) then return end

local german = extras.German
german["Blasta can provide the Training tab in DaylightUI's spellbook. Which add-on should provide it for this character?"] =
    "Blasta kann den Ausbildungsreiter im Daylight-Zauberbuch selbst bereitstellen. Welches Add-on möchtest du für diesen Charakter verwenden?"
german["Use Blasta"] = "Blasta verwenden"
german["Use What's Training?"] = "What’s Training? verwenden"
german["Reload to switch the Training tab's data source."] = "Lade die Oberfläche neu, um die Datenquelle für Ausbildung zu wechseln."
german["Could not change What's Training? for this character."] = "What’s Training? konnte für diesen Charakter nicht umgeschaltet werden."
german["What's Training? is not installed."] = "What’s Training? ist nicht installiert."
german["Enable What's Training? for this character and use it for the Training tab?"] =
    "What’s Training? für diesen Charakter aktivieren und für den Ausbildungsreiter verwenden?"

local function enabledFor(guid)
    local ok, state = pcall(addons.GetAddOnEnableState, external, guid)
    if ok and not DUI.IsSecret(state) and type(state) == "number" then return state > 0 end
end

local function askReload()
    widgets.Ask({
        key = "blastaTrainingReload", reload = true,
        text = extras.Translate("Reload to switch the Training tab's data source."),
        yes = RELOADUI or DUI.L["Reload"], no = LATER or DUI.L["Later"],
    })
end

local function selectProvider(useBlasta)
    local guid = UnitGUID("player")
    if DUI.IsSecret(guid) or type(guid) ~= "string" or guid == "" then return end
    local wanted = not useBlasta
    local previous = enabledFor(guid)
    if previous ~= wanted then
        local change = wanted and addons.EnableAddOn or addons.DisableAddOn
        local ok = pcall(change, external, guid)
        if not ok or enabledFor(guid) ~= wanted then
            DUI.Print(extras.Translate("Could not change What's Training? for this character."))
            return
        end
    end
    local preference = useBlasta and "blasta" or "external"
    local char = character()
    local changed = char[providerKey] ~= preference
    char[providerKey] = preference
    if previous ~= wanted or (changed and not nativeOn()) then askReload() end
end

local prompted
local function askEnableExternal()
    widgets.Ask({
        key = "blastaTrainingProvider",
        text = extras.Translate("Enable What's Training? for this character and use it for the Training tab?"),
        yes = extras.Translate("Use What's Training?"),
        no = LATER or DUI.L["Later"],
        onYes = function() selectProvider(false) end,
    })
end

local function askProvider(manual)
    local installed
    if addons.DoesAddOnExist then installed = addons.DoesAddOnExist(external)
    else installed = addons.GetAddOnInfo(external) end
    if not installed then
        if manual and character()[providerKey] == "external" then
            widgets.Ask({
                key = "blastaTrainingProvider",
                text = extras.Translate("What's Training? is not installed."),
                yes = extras.Translate("Use Blasta"), no = LATER or DUI.L["Later"],
                onYes = function() character()[providerKey] = "blasta"; askReload() end,
            })
        elseif manual then
            DUI.Print(extras.Translate("What's Training? is not installed."))
        end
        return
    end
    local guid = UnitGUID("player")
    if DUI.IsSecret(guid) or type(guid) ~= "string" or guid == "" then return end
    if not manual and (prompted or character()[providerKey] == "external"
        or not (nativeOn() or enabledFor(guid))) then return end
    DUI.AfterCombat(function()
        if not manual and (prompted or character()[providerKey] == "external"
            or not (nativeOn() or enabledFor(guid))) then return end
        prompted = true
        if manual and enabledFor(guid) == false and extras.UsingBlastaTraining() then
            askEnableExternal()
            return
        end
        widgets.Ask({
            key = "blastaTrainingProvider",
            text = extras.Translate("Blasta can provide the Training tab in DaylightUI's spellbook. Which add-on should provide it for this character?"),
            yes = extras.Translate("Use Blasta"),
            no = extras.Translate("Use What's Training?"),
            onYes = function() selectProvider(true) end,
            onNo = function()
                -- Daylight also routes closing the dialog to No. At login No
                -- keeps the already-enabled add-on and needs no reload.
                if not manual or enabledFor(guid) == true then character()[providerKey] = "external"
                else askEnableExternal() end
            end,
        })
    end, "blasta:trainingProvider")
end

DUI.On("Login", function() C_Timer.After(1, function() askProvider(false) end) end)
extras.SlashHandlers = extras.SlashHandlers or {}
table.insert(extras.SlashHandlers, function(message)
    if not message:lower():match("^%s*training%s*$") then return false end
    askProvider(true)
    return true
end)
