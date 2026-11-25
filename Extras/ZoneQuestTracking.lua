local ADDON, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Quests")
local mod = DUI:GetModule("Quests")
local data, log, maps = ns and ns.Data, C_QuestLog, C_Map
if not (data and data.Snapshot and log and log.AddQuestWatch and log.RemoveQuestWatch
    and log.GetNumQuestWatches and log.GetQuestIDForQuestWatchIndex and maps and maps.GetBestMapForUnit
    and maps.GetMapInfo and extras.FindSetting(mod, "filter")) then return end

local key = "blastaZoneQuestTracking"
local german = extras.German
german["Automatically track quests in this zone"] = "Quests der aktuellen Zone automatisch verfolgen"
german["Track local quests first. Frees space by untracking quests elsewhere. Waits until you land."] =
    "Verfolgt zuerst lokale Quests und gibt bei Bedarf Plätze frei. Wartet während eines Flugs bis zur Landung."
german["Keep tracked during zone changes"] = "Bei Zonenwechsel weiterverfolgen"
german["Allow untracking during zone changes"] = "Bei Zonenwechsel Entfolgen erlauben"
german["Local quests tracked: %d"] = "Lokale Quests verfolgt: %d"
mod.defaults[key] = false
extras.AddSetting(mod, "filter", {
    type = "toggle", key = key, label = "Automatically track quests in this zone",
    desc = "Track local quests first. Frees space by untracking quests elsewhere. Waits until you land.",
})

local function enabled()
    return mod.enabled and mod.db and mod.db[key] == true
end

local function pins()
    local char = DUI.DB.Character()
    if type(char.blastaZoneQuestPins) ~= "table" then char.blastaZoneQuestPins = {} end
    return char.blastaZoneQuestPins
end

local function number(value)
    return not DUI.IsSecret(value) and type(value) == "number" and value or nil
end

local function mapZone(id)
    id = number(id)
    for _ = 1, 10 do
        if not id or id <= 0 then return end
        local info = maps.GetMapInfo(id)
        if not info then return end
        local kind = number(info.mapType)
        if kind == 3 or kind == 4 then return id end -- Zone or Dungeon
        id = number(info.parentMapID)
    end
end

local function questZone(id)
    local getMap = log.GetQuestUiMapID or GetQuestUiMapID
    if not getMap then return end
    local ok, map = pcall(getMap, id, true)
    if ok then return mapZone(map) end
end

local function watches()
    local count = number(log.GetNumQuestWatches())
    if not count then return end
    local set = {}
    for i = 1, count do
        local id = number(log.GetQuestIDForQuestWatchIndex(i))
        if id then set[id] = true end
    end
    return set, count
end

local function watched(id)
    local set = watches()
    return set and set[id] == true or false
end

local function airborne()
    return (UnitOnTaxi and UnitOnTaxi("player")) or (IsFlying and IsFlying())
end

local lastPlan
local function reconcile(force)
    local zone = mapZone(maps.GetBestMapForUnit("player"))
    local current, count = watches()
    if not (zone and current) then return end
    local snapshot = data.Snapshot("log")
    local limit = number(MAX_QUEST_WATCHES) or ns.Journal and ns.Journal.WATCH_MAX or 25
    local pinned, nearby, remote, localActive = pins(), {}, {}, {}
    local plan = { tostring(zone) }
    for _, group in ipairs(snapshot.groups) do
        for _, q in ipairs(group.quests) do
            local home = questZone(q.id)
            local here = snapshot.here[group.name] or home == zone
            local protected = q.focus or pinned[q.id]
            plan[#plan + 1] = table.concat({ q.id, home or 0, q.state, here and 1 or 0,
                q.focus and 1 or 0, pinned[q.id] and 1 or 0 }, ":")
            if q.state ~= "failed" and (here or pinned[q.id]) and not current[q.id] then
                nearby[#nearby + 1] = q
            elseif here and current[q.id] and not protected and q.state ~= "ready" then
                localActive[#localActive + 1] = q.id
            elseif current[q.id] and not here and not protected and home and home ~= zone then
                remote[#remote + 1] = q.id
            end
        end
    end
    -- Watching a quest can itself trigger QUEST_LOG_UPDATE. Only retry on
    -- new quest or location data, or after an explicit scheduling trigger.
    local signature = table.concat(plan, ";")
    if not force and signature == lastPlan then return end
    lastPlan = signature
    table.sort(nearby, function(a, b)
        if pinned[a.id] ~= pinned[b.id] then return pinned[a.id] == true end
        if (a.state == "ready") ~= (b.state == "ready") then return a.state == "ready" end
        return a.logIndex < b.logIndex
    end)

    local added = 0
    for _, q in ipairs(nearby) do
        if airborne() or InCombatLockdown() then break end
        local displaced
        if count >= limit then
            displaced = table.remove(remote)
            if not displaced and (q.state == "ready" or pinned[q.id]) then displaced = table.remove(localActive) end
            if not displaced then break end
            pcall(log.RemoveQuestWatch, displaced)
            if watched(displaced) then break end
            count = count - 1
        end
        pcall(log.AddQuestWatch, q.id)
        if watched(q.id) then
            count = count + 1
            added = added + 1
        else
            -- A rejected watch must not leave a previously tracked quest displaced.
            if displaced then pcall(log.AddQuestWatch, displaced) end
            break
        end
    end
    if added > 0 then
        DEFAULT_CHAT_FRAME:AddMessage("Blasta: " .. extras.Translate("Local quests tracked: %d"):format(added))
    end
end

local pending, forcePending
local function update()
    pending = nil
    if not enabled() then return end
    if airborne() then
        -- During a flight check only flight state, never the log or the watch list.
        pending = true
        C_Timer.After(1, update)
    else
        DUI.AfterCombat(function()
            if not enabled() or pending then return end
            if airborne() then update(); return end
            local force = forcePending
            forcePending = nil
            reconcile(force)
        end, "blasta:zoneQuestTracking")
    end
end

local function schedule(passive)
    if not enabled() then return end
    if passive ~= true then forcePending = true end
    if pending then return end
    pending = true
    C_Timer.After(0.25, update)
end

local api = DUI.API and DUI.API.For and DUI.API.For(ADDON)
if api and api.AddQuestMenu then
    api.AddQuestMenu("zoneQuestPin", {
        show = enabled,
        label = function(q)
            return extras.Translate(pins()[q.questID] and "Allow untracking during zone changes"
                or "Keep tracked during zone changes")
        end,
        onClick = function(q)
            local set = pins()
            set[q.questID] = not set[q.questID] or nil
            schedule()
        end,
    })
end

DUI.On("Login", schedule)
DUI.On("ProfileKept", schedule)
DUI.On("SettingChanged", function(scope, path)
    if scope == "Quests" and path == key then schedule() end
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED" }) do
    DUI.RegisterEvent(event, function(_, id)
        if (event == "QUEST_TURNED_IN" or event == "QUEST_REMOVED") and number(id) then pins()[id] = nil end
        schedule()
    end)
end
for _, event in ipairs({ "QUEST_LOG_UPDATE", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }) do
    DUI.RegisterEvent(event, function() schedule(true) end)
end
