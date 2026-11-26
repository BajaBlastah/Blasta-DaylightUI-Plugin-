-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
local DUI = DaylightUI
local bags = extras.Compatible("Bags")
local C = C_Container
local W = DUI.Widgets
if not (bags and bags.Items and bags.Categories and bags.Window and C
    and C.GetContainerNumSlots and C.PickupContainerItem and C_QuestLog
    and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo
    and bags.Window.Create and bags.Window.Tip and bags.Window.LayoutTools
    and W.Button and W.IconButton and W.Confirm and bags.Layout and bags.Layout.Apply
    and bags.Window.Relayout and bags.Window.FillAll and DUI.RegisterEvent) then return end
local T = extras.Translate
local words = {
    ["Old quest items"] = "Alte Questgegenstände",
    ["Review quest items"] = "Questgegenstände prüfen",
    ["Choose a stack. Its related quests are not in your quest log; you may still need it later."] =
        "Wähle einen Stapel. Seine Quests stehen nicht im Questlog; du könntest ihn später noch brauchen.",
    ["QuestieDB is required to identify related quests. Nothing was deleted."] =
        "QuestieDB wird für die Questzuordnung benötigt. Es wurde nichts gelöscht.",
    ["No matching quest items found. Unknown, active and protected items are skipped."] =
        "Keine passenden Questgegenstände gefunden. Unklare, aktive und geschützte Gegenstände werden übersprungen.",
    ["Delete selected stack"] = "Ausgewählten Stapel löschen",
    ["Confirm deletion"] = "Löschung bestätigen",
    ["The item or quest status changed. Review the list again."] =
        "Gegenstand oder Queststatus geändert. Prüfe die Liste erneut.",
    ["Finish the cursor action and leave combat before deleting items."] =
        "Beende die Cursoraktion und verlasse den Kampf, bevor du Gegenstände löschst.",
    ["The game may require its own deletion confirmation."] =
        "Das Spiel kann eine eigene Bestätigung zum Löschen verlangen.",
    ["Previous"] = "Zurück", ["Next"] = "Weiter", ["Refresh"] = "Aktualisieren",
    ["Related quests: %s"] = "Zugehörige Quests: %s",
    ["Related quest not in quest log"] = "Zugehörige Quest nicht im Questlog",
}
for key, value in pairs(words) do extras.German[key] = value end

local Cleanup = {}
extras.QuestCleanup = Cleanup
local function database()
    local db = _G.LibQuestieDB
    return db and db.Item and type(db.Item.Get) == "function" and db.Item or nil
end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function questState()
    local active, special = {}, {}
    local n = C_QuestLog.GetNumQuestLogEntries()
    if type(n) ~= "number" then return end
    for index = 1, n do
        local q = C_QuestLog.GetInfo(index)
        if not q then return end -- An incomplete log must never authorize deletion.
        if not q.isHeader then
            if type(q.questID) ~= "number" or q.questID <= 0 then return end
            active[q.questID] = true
            if GetQuestLogSpecialItemInfo then
                local link = GetQuestLogSpecialItemInfo(index)
                local id = link and tonumber(link:match("item:(%d+)"))
                if id then special[id] = true end
            end
        end
    end
    return active, special
end
local function query(db, id, key)
    local ok, value = pcall(db.Get, id, key)
    return ok, value
end
local function candidate(bag, slot, db, active, special)
    local info = bags.Items.InfoAt(bag, slot)
    if not info or info.isLocked or not info.itemID or not info.hyperlink
        or special[info.itemID] or not bags.Categories.Guarded
        or bags.Categories.Guarded(bag, slot, info) then return end
    if bags.ItemTree and bags.ItemTree.Keeps and bags.ItemTree.Keeps(info, bag) then return end
    local ok, class = query(db, info.itemID, "class")
    if not ok or class ~= 12 then return end -- Quest class only; never ordinary crafting materials.
    local starterOK, starter = query(db, info.itemID, "startQuest")
    if not starterOK or (starter ~= nil and starter ~= 0) then return end
    local relatedOK, related = query(db, info.itemID, "relatedQuests")
    if not relatedOK or type(related) ~= "table" or not next(related) then return end
    local quests = {}
    for _, id in pairs(related) do
        if type(id) ~= "number" or id <= 0 or active[id] then return end
        -- Check the live log as well, including quests absent from a collapsed UI.
        if not C_QuestLog.IsOnQuest or C_QuestLog.IsOnQuest(id) ~= false then return end
        quests[#quests + 1] = id
    end
    table.sort(quests)
    local names = {}
    local questDB = _G.LibQuestieDB and _G.LibQuestieDB.Quest
    if questDB and questDB.Get then
        for _, id in ipairs(quests) do
            local nameOK, name = pcall(questDB.Get, id, "name")
            if nameOK and type(name) == "string" then names[#names + 1] = name end
        end
    end
    return { bag = bag, slot = slot, id = info.itemID, link = info.hyperlink,
        count = info.stackCount or 1, quests = table.concat(quests, ", "), names = table.concat(names, ", "),
        guid = C_Item and C_Item.GetItemGUID and ItemLocation
            and C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(bag, slot)) or nil }
end
function Cleanup.Scan()
    local db = database()
    if not db then return {}, "database" end
    local active, special = questState()
    if not active then return {}, "log" end
    local result = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C.GetContainerNumSlots(bag) do
            local entry = candidate(bag, slot, db, active, special)
            if entry then result[#result + 1] = entry end
        end
    end
    return result
end
local tooltipSlots = setmetatable({}, { __mode = "k" })
local function tooltipEntry(bag, slot)
    local db = database()
    local active, special = questState()
    return db and active and candidate(bag, slot, db, active, special)
end
function Cleanup.AppendTooltipModel(tip, data, model)
    local at = tooltipSlots[tip]
    if not at or (tip.GetOwner and tip:GetOwner() ~= at.owner) then return end
    local entry = tooltipEntry(at.bag, at.slot)
    if not entry or data.id ~= entry.id then return end
    local label = T("Related quest not in quest log")
    local names = entry.names ~= "" and T("Related quests: %s"):format(entry.names) or nil
    -- An original-tooltip modifier can leave our native fallback rows behind.
    -- Keep just the model's copy when switching back to the Blasta card.
    for i = #model.lines, 1, -1 do
        if model.lines[i].text == label or (names and model.lines[i].text == names) then
            table.remove(model.lines, i)
        end
    end
    model.lines[#model.lines + 1] = { text = label, section = "footer", color = { 1, 0.65, 0.2 } }
    if names then model.lines[#model.lines + 1] = { text = names, section = "footer", color = { 0.8, 0.8, 0.8 } } end
    local hint = Cleanup.ActionHint and Cleanup.ActionHint(at.bag, at.slot)
    if hint then
        for i = #model.lines, 1, -1 do
            if model.lines[i].section == "questCleanupAction" then table.remove(model.lines, i) end
        end
        model.lines[#model.lines + 1] = { text = hint, section = "questCleanupAction", color = { 1, 0.65, 0.2 } }
    end
end
function Cleanup.Tooltip(tip, bag, slot)
    tooltipSlots[tip] = { bag = bag, slot = slot, owner = tip.GetOwner and tip:GetOwner() }
    -- Never AddLine to the native tooltip while Blasta draws its own card:
    -- that changes the measured line count after processing and triggers refits.
    if extras.QuestCleanupTooltipCard and extras.QuestCleanupTooltipCard(tip) then return end
    local entry = tooltipEntry(bag, slot)
    if not entry then return end
    local label = T("Related quest not in quest log")
    -- SetBagItem may be called repeatedly while the pointer stays over a slot.
    local name = tip.GetName and tip:GetName()
    if name and tip.NumLines then
        for i = 1, tip:NumLines() do
            local fs = _G[name .. "TextLeft" .. i]
            local text = fs and fs:GetText()
            if not (issecretvalue and issecretvalue(text)) and text == label then return end
        end
    end
    tip:AddLine(label, 1, 0.65, 0.2, true)
    if entry.names ~= "" then tip:AddLine(T("Related quests: %s"):format(entry.names), 0.8, 0.8, 0.8, true) end
    local hint = Cleanup.ActionHint and Cleanup.ActionHint(bag, slot)
    if hint then tip:AddLine(hint, 1, 0.65, 0.2, true) end
end
if GameTooltip and GameTooltip.SetBagItem then
    hooksecurefunc(GameTooltip, "SetBagItem", extras.SafeHook("QuestCleanup.SetBagItem", Cleanup.Tooltip))
end
function Cleanup.Delete(entry)
    if combat() or not GetCursorInfo or GetCursorInfo() then return false, "busy" end
    local db = database()
    local active, special = questState()
    local now = entry and db and active and candidate(entry.bag, entry.slot, db, active, special)
    if not now or now.id ~= entry.id or now.link ~= entry.link or now.count ~= entry.count
        or now.quests ~= entry.quests or (entry.guid and now.guid ~= entry.guid) then return false, "changed" end
    local ok = pcall(C.PickupContainerItem, entry.bag, entry.slot)
    local kind, id, link = GetCursorInfo()
    if not ok or kind ~= "item" or id ~= entry.id or link ~= entry.link then
        if kind and ClearCursor then ClearCursor() end
        return false, "changed"
    end
    local deleted = DeleteCursorItem and pcall(DeleteCursorItem)
    if not deleted and ClearCursor then ClearCursor() end
    return deleted == true, "game"
end

-- Cleanup is a temporary view in the existing bag, never a separate window.
local mode, selected = false, nil
local indexed, covers = {}, setmetatable({}, { __mode = "k" })
local strings = {
    ["Click an item to select it. Click it again to delete that stack."] =
        "Gegenstand zum Löschen auswählen. Erneut anklicken, um den Stapel zu löschen.",
    ["Click to select this stack for deletion"] = "Klicken: Diesen Stapel zum Löschen auswählen",
    ["Click again to delete this stack"] = "Erneut klicken: Diesen Stapel löschen",
    ["Click to return to all bag items"] = "Klicken: Zurück zu allen Taschengegenständen",
}
for key, value in pairs(strings) do extras.German[key] = value end
local function key(bag, slot) return bag .. ":" .. slot end
local function same(a, b)
    return a and b and a.bag == b.bag and a.slot == b.slot and a.id == b.id
        and a.link == b.link and a.count == b.count and a.guid == b.guid and a.quests == b.quests
end
function Cleanup.Click(entry)
    if not mode or combat() or GetCursorInfo() then return false end
    local now = entry and tooltipEntry(entry.bag, entry.slot)
    if not same(now, entry) then selected = nil; return false end
    if selected and same(selected.entry, now) then
        -- A normal double-click is selection, never accidental confirmation.
        if GetTime() - selected.at < 0.5 then return false end
        selected = nil
        return Cleanup.Delete(entry)
    end
    selected = { entry = now, at = GetTime() }
    return false
end
function Cleanup.ActionHint(bag, slot)
    if not mode then return end
    local entry = indexed[key(bag, slot)]
    if not entry then return end
    return T(selected and same(selected.entry, entry) and "Click again to delete this stack"
        or "Click to select this stack for deletion")
end
local function refreshIndex()
    indexed = {}
    local entries, reason = Cleanup.Scan()
    for _, entry in ipairs(entries) do indexed[key(entry.bag, entry.slot)] = entry end
    return #entries, reason
end
local function hideCovers()
    for _, cover in pairs(covers) do cover:Hide() end
end
local function updateButton()
    local b = bags.window and bags.window.blastaQuestCleanup
    if b then
        b.active = mode
        if b.Paint then b.Paint() end
    end
end
local function relayout()
    local f = bags.window
    if f and f:IsShown() then
        f.laid = nil
        bags.Window.Relayout(f)
        bags.Window.FillAll(f)
    end
end
local function endMode()
    mode, selected, indexed = false, nil, {}
    hideCovers()
    updateButton()
end
local useOver = bags.Items.UseOver
if useOver then
    function bags.Items.UseOver(...)
        if mode then
            if bags.Items.UseOff then bags.Items.UseOff() end
            return
        end
        return useOver(...)
    end
end
function Cleanup.Open()
    if combat() then return end
    if mode then endMode(); relayout(); return end
    local count, reason = refreshIndex()
    if reason or count == 0 then
        DUI.Print(T(reason == "database" and "QuestieDB is required to identify related quests. Nothing was deleted."
            or "No matching quest items found. Unknown, active and protected items are skipped."))
        return
    end
    -- Only with the bag window built and its close hook in place, so the mode
    -- always ends with the window.
    local f = bags.window
    if not (f and f.blastaQuestCleanup) then return end
    mode, selected = true, nil
    if extras.ResetBagFilter then extras.ResetBagFilter() end
    if f.search then f.search:SetText("") end
    if not f:IsShown() then
        -- DaylightUI's own way to show its bag without the game's bags.
        local oc = bags.OpenClose
        if not (oc and oc.Hold and oc.Hold()) then f:Show() end
    end
    updateButton()
    relayout()
end
local function coverItem(button, entry)
    local cover = covers[button]
    if not cover then
        cover = CreateFrame("Button", nil, button)
        covers[button] = cover
        cover:SetAllPoints(button)
        cover:RegisterForClicks("LeftButtonUp")
        cover:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.entry.bag, self.entry.slot)
            GameTooltip:Show()
        end)
        cover:SetScript("OnLeave", function() GameTooltip:Hide() end)
        cover:SetScript("OnClick", function(self)
            if not mode or combat() then return end
            Cleanup.Click(self.entry)
            -- Revalidate from the bags after every click. A native deletion
            -- confirmation keeps the item/cursor until the game resolves it.
            refreshIndex()
            relayout()
            if self:IsShown() and self:IsMouseOver() then self:GetScript("OnEnter")(self) end
        end)
        local ring = cover:CreateTexture(nil, "OVERLAY")
        ring:SetAllPoints()
        ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        ring:SetBlendMode("ADD")
        ring:SetVertexColor(1, 0.35, 0.15)
        cover.ring = ring
    end
    cover.entry = entry
    cover:SetFrameLevel(button:GetFrameLevel() + 15)
    cover.ring:SetShown(selected ~= nil and same(selected.entry, entry))
    cover:Show()
end
local apply = bags.Layout.Apply
local function reviewing(frame, cfg)
    refreshIndex()
    hideCovers()
    if bags.Items.UseOff then bags.Items.UseOff() end
    local slots = frame.set.Slots
    local visible = {}
    for _, at in ipairs(slots()) do
        local entry = indexed[key(at.bag, at.button:GetID())]
        if entry then visible[#visible + 1] = at else at.button:Hide() end
    end
    frame.set.Slots = function() return visible, false end
    local ok, w, h = pcall(apply, frame, cfg)
    frame.set.Slots = slots
    frame.laid = nil
    if not ok then error(w, 0) end
    -- Grouped stacks can hide individual slots. Only cover visible tiles;
    -- every confirmation still deletes exactly the tile's actual bag stack.
    for _, at in ipairs(visible) do
        if at.button:IsShown() then coverItem(at.button, indexed[key(at.bag, at.button:GetID())]) end
    end
    return w, h
end
-- If the review fails, the bag leaves it and DaylightUI lays it out as usual.
function bags.Layout.Apply(frame, cfg)
    if not mode or frame ~= bags.window then return apply(frame, cfg) end
    local slots = frame.set and frame.set.Slots
    local ok, w, h = pcall(reviewing, frame, cfg)
    if ok and type(w) == "number" and type(h) == "number" then return w, h end
    extras.ReportOnce("QuestCleanup.Apply", ok and "Blasta quest item review returned no size" or w)
    if slots then frame.set.Slots = slots end
    frame.laid = nil
    mode, selected, indexed = false, nil, {}
    pcall(hideCovers)
    pcall(updateButton)
    return apply(frame, cfg)
end
local function attach(frame)
    if not frame or frame.kind ~= "bag" or frame.blastaQuestCleanup or not frame.tools then return end
    local b = W.IconButton(frame, "ui-section-quests.png", nil, nil, bags.Window.ROW)
    b.hover = b.Paint
    b:SetScript("OnClick", Cleanup.Open)
    bags.Window.Tip(b, T("Old quest items"), function()
        return T(mode and "Click to return to all bag items"
            or "Click an item to select it. Click it again to delete that stack.")
    end)
    frame.blastaQuestCleanup = b
    frame.tools[#frame.tools + 1] = b
    bags.Window.LayoutTools(frame)
    frame:HookScript("OnHide", extras.SafeHook("QuestCleanup.OnHide", endMode))
end
local create = bags.Window.Create
function bags.Window.Create(...)
    local frame = create(...)
    local ok, err = pcall(attach, frame)
    if not ok then extras.ReportOnce("QuestCleanup.Create", err) end
    return frame
end
if bags.window then attach(bags.window) end
DUI.On("Login", function() attach(bags.window) end)
DUI.RegisterEvent("PLAYER_REGEN_DISABLED", endMode)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", relayout)
DUI.RegisterEvent("BAG_UPDATE_DELAYED", function() if mode and not combat() then relayout() end end)
local mod = DUI:GetModule("Bags")
if mod then
    extras.AddSetting(mod, "combineStacks", { type = "button", label = "Old quest items",
        text = "Review quest items", func = Cleanup.Open }, true)
end
