local ADDON, extras = ...
local DUI = DaylightUI
local Style, Widgets = DUI.Style, DUI.Widgets
local Bags, Item = C_Container, C_Item
local addons = C_AddOns
local external = "DeleteCheapestItem"
local enabledKey, borderKey = "blastaLootSpace", "blastaLootIconBorder"
local T = extras.Translate
local german = extras.German
local labels = {
    ["Make room for loot"] = "Platz für Beute",
    ["Suggest bag stacks to replace when loot does not fit."] = "Schlägt Taschenstapel zum Ersetzen vor, wenn Beute nicht hineinpasst.",
    ["Loot item icon border"] = "Rahmen der Beute-Icons",
    ["Loot window"] = "Beutefenster",
    ["Square, 1 pixel"] = "Quadratisch, 1 Pixel",
    ["Default"] = "Standard",
    ["Choose loot space add-on"] = "Addon für volle Taschen wählen",
    ["Choose"] = "Auswählen",
    ["Blasta can help make room for loot. Which add-on do you want to use for this character?"] =
        "Blasta kann beim Plündern Platz in den Taschen schaffen. Welches Addon möchtest du für diesen Charakter verwenden?",
    ["Use Blasta"] = "Blasta verwenden",
    ["Use Delete Cheapest Item"] = "Delete Cheapest Item verwenden",
    ["Enable Delete Cheapest Item for this character?"] = "Delete Cheapest Item für diesen Charakter aktivieren?",
    ["Delete Cheapest Item is not installed."] = "Delete Cheapest Item ist nicht installiert.",
    ["Could not change Delete Cheapest Item for this character."] = "Delete Cheapest Item konnte für diesen Charakter nicht umgeschaltet werden.",
    ["Reload to switch the loot space add-on."] = "Lade die Oberfläche neu, um das Addon für volle Taschen zu wechseln.",
    ["Replace"] = "Ersetzen",
    ["No suitable common or poor stacks."] = "Keine passenden grauen oder weißen Stapel.",
    ["This stack is worth more at a vendor than the loot."] = "Dieser Stapel ist beim Händler mehr wert als die Beute.",
    ["The contents changed. Choose a stack again."] = "Die Inhalte haben sich geändert. Wähle den Stapel erneut aus.",
    ["The game did not confirm the deletion."] = "Das Spiel hat das Löschen nicht bestätigt.",
    ["The loot is still available in the loot list."] = "Die Beute liegt noch in der Beuteliste.",
    ["Available after combat"] = "Nach dem Kampf verfügbar",
    ["Waiting for the game to confirm the deletion."] = "Warte auf die Löschbestätigung des Spiels.",
}
for key, value in pairs(labels) do german[key] = value end

local function plain(value)
    if not DUI.IsSecret(value) then return value end
end

local function character()
    return DUI.DB.Character()
end

local function installed()
    if not addons then return end
    if addons.DoesAddOnExist then return addons.DoesAddOnExist(external) end
    return addons.GetAddOnInfo and addons.GetAddOnInfo(external) ~= nil
end

local function externalEnabled(guid)
    if not (guid and addons and addons.GetAddOnEnableState) then return end
    local ok, value = pcall(addons.GetAddOnEnableState, external, guid)
    if ok then
        value = plain(value)
        if type(value) == "number" then return value > 0 end
    end
end

local function useBlasta()
    if DUI:Get(ADDON, enabledKey) == false then return false end
    if not installed() then return true end
    return character().blastaLootSpaceProvider ~= "external"
        and not (addons.IsAddOnLoaded and addons.IsAddOnLoaded(external))
        and not externalEnabled(plain(UnitGUID("player")))
end

local function choose(blasta)
    local guid = plain(UnitGUID("player"))
    if type(guid) ~= "string" or guid == "" then return end
    local before = externalEnabled(guid)
    local wanted = not blasta
    if before ~= wanted then
        local change = wanted and addons.EnableAddOn or not wanted and addons.DisableAddOn
        if not (change and pcall(change, external, guid)) or externalEnabled(guid) ~= wanted then
            DUI.Print(T("Could not change Delete Cheapest Item for this character."))
            return
        end
    end
    character().blastaLootSpaceProvider = blasta and "blasta" or "external"
    if blasta then DUI:Set(ADDON, enabledKey, true) end
    if before ~= wanted then
        Widgets.Ask({ key = "blastaLootSpaceReload", reload = true,
            text = T("Reload to switch the loot space add-on."), yes = RELOADUI, no = LATER })
    end
end

local function askProvider(manual)
    if not installed() then
        if manual then DUI.Print(T("Delete Cheapest Item is not installed.")) end
        return
    end
    if not manual and character().blastaLootSpaceProvider then return end
    DUI.AfterCombat(function()
        Widgets.Ask({
            key = "blastaLootSpaceProvider",
            text = T("Blasta can help make room for loot. Which add-on do you want to use for this character?"),
            yes = T("Use Blasta"), no = T("Use Delete Cheapest Item"),
            onYes = function() choose(true) end,
            onNo = function()
                if externalEnabled(plain(UnitGUID("player"))) == true then
                    character().blastaLootSpaceProvider = "external"
                else
                    Widgets.Ask({ key = "blastaLootSpaceEnableExternal",
                        text = T("Enable Delete Cheapest Item for this character?"),
                        yes = T("Use Delete Cheapest Item"), no = LATER,
                        onYes = function() choose(false) end })
                end
            end,
        })
    end, "blasta:lootSpaceProvider")
end

function extras.LootSpaceGroups()
    return {
        { label = "Loot window", items = {
            { type = "dropdown", key = borderKey, label = "Loot item icon border", blastaSince = "2.1",
                values = { default = "Default", square = "Square, 1 pixel" }, order = { "default", "square" } },
        } },
        { label = "Make room for loot", items = {
            { type = "toggle", key = enabledKey, label = "Make room for loot", blastaSince = "2.1",
                desc = "Suggest bag stacks to replace when loot does not fit." },
            { type = "button", label = "Choose loot space add-on", text = "Choose", func = function() askProvider(true) end },
        } },
    }
end

if not (Bags and Bags.GetContainerItemInfo and Bags.GetContainerNumSlots and Bags.GetContainerNumFreeSlots
    and Item and Item.GetItemInfo and GetLootSlotLink and GetLootSlotInfo and GetNumLootItems) then return end

local waitingItems = {}
local function itemData(link)
    local name, _, quality, _, _, _, _, maxStack, _, _, price, class = Item.GetItemInfo(link)
    name = plain(name)
    if not name then
        local id = tonumber(link:match("item:(%d+)"))
        if id then waitingItems[id] = true end
    end
    return name, plain(quality), plain(maxStack), plain(price), plain(class)
end

local function incoming(slot)
    local link = plain(GetLootSlotLink(slot))
    if type(link) ~= "string" or not link:find("item:", 1, true) then return end
    local _, name, count, _, _, locked = GetLootSlotInfo(slot)
    if DUI.IsSecret(locked) or locked == true then return end
    count = plain(count)
    if type(count) ~= "number" or count < 1 then return end
    local cachedName, _, maxStack, price = itemData(link)
    if type(maxStack) ~= "number" or maxStack < 1 then
        if Item.RequestLoadItemDataByID then
            local id = tonumber(link:match("item:(%d+)"))
            if id then Item.RequestLoadItemDataByID(id) end
        end
        return
    end
    return { slot = slot, link = link, name = cachedName or plain(name) or link, count = count,
        maxStack = maxStack, value = type(price) == "number" and price * count or nil,
        id = tonumber(link:match("item:(%d+)")) }
end

local function itemGUID(bag, slot)
    if Item.GetItemGUID and ItemLocation and ItemLocation.CreateFromBagAndSlot then
        local ok, guid = pcall(Item.GetItemGUID, ItemLocation:CreateFromBagAndSlot(bag, slot))
        if ok then return plain(guid) end
    end
end

local function questItems()
    local protected = { [6948] = true }
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and GetQuestLogSpecialItemInfo) then return protected end
    local entries = plain(C_QuestLog.GetNumQuestLogEntries())
    for index = 1, type(entries) == "number" and entries or 0 do
        local ok, link = pcall(GetQuestLogSpecialItemInfo, index)
        link = ok and plain(link)
        local id = type(link) == "string" and tonumber(link:match("item:(%d+)"))
        if id then protected[id] = true end
    end
    return protected
end

local function candidate(bag, slot, row, protected)
    local link = plain(row.hyperlink)
    local count = plain(row.stackCount)
    if type(link) ~= "string" or type(count) ~= "number" or count < 1
        or plain(row.isLocked) ~= false or plain(row.hasNoValue) == true then return end
    local id = plain(row.itemID) or tonumber(link:match("item:(%d+)"))
    if not id or protected[id] then return end
    if Bags.GetContainerItemQuestInfo then
        local quest = plain(Bags.GetContainerItemQuestInfo(bag, slot))
        if type(quest) == "table" then
            local id = plain(quest.questID)
            if plain(quest.isQuestItem) == true or (type(id) == "number" and id > 0) then return end
        end
    end
    local name, quality, _, price, class = itemData(link)
    if type(name) ~= "string" or type(quality) ~= "number" or quality > 1 or type(class) ~= "number"
        or class == 12 or type(price) ~= "number" or price <= 0 then return end
    return { bag = bag, slot = slot, link = link, name = name, count = count, value = price * count,
        icon = plain(row.iconFileID), quality = quality }
end

local function bagSnapshot()
    local containers = {}
    local inv = Constants and Constants.InventoryConstants or {}
    local normal = inv.NumBagSlots or NUM_BAG_SLOTS or 4
    for bag = 0, normal + (inv.NumReagentBagSlots or 0) do
        local free, kind = Bags.GetContainerNumFreeSlots(bag)
        free, kind = plain(free), plain(kind)
        if type(free) == "number" and type(kind) == "number"
            and (kind ~= 0 or bag <= normal) then
            local container = { bag = bag, kind = kind, free = free, stacks = {} }
            containers[#containers + 1] = container
            local slots = plain(Bags.GetContainerNumSlots(bag))
            for slot = 1, type(slots) == "number" and slots or 0 do
                local row = plain(Bags.GetContainerItemInfo(bag, slot))
                if type(row) == "table" then
                    container.stacks[#container.stacks + 1] = { slot = slot, data = row }
                end
            end
        end
    end
    return containers
end

local function scan(loot, snapshot, roomOnly)
    local result, room = {}, 0
    local compatible = {}
    local family = Item.GetItemFamily and plain(Item.GetItemFamily(loot.link)) or 0
    for _, container in ipairs(snapshot or bagSnapshot()) do
        local kind = container.kind
        if kind == 0 or (type(family) == "number" and bit.band(kind, family) ~= 0) then
            compatible[#compatible + 1] = container
            room = room + container.free * loot.maxStack
            for _, stack in ipairs(container.stacks) do
                local row = stack.data
                if plain(row.itemID) == loot.id and plain(row.isLocked) == false then
                    local count = plain(row.stackCount)
                    if type(count) == "number" then room = room + math.max(0, loot.maxStack - count) end
                end
            end
        end
    end
    if roomOnly then return result, room end
    if room >= loot.count or room + loot.maxStack < loot.count then return {}, room end
    local protected = questItems()
    for _, container in ipairs(compatible) do
        for _, stack in ipairs(container.stacks) do
            if plain(stack.data.itemID) ~= loot.id then
                local at = candidate(container.bag, stack.slot, stack.data, protected)
                if at then result[#result + 1] = at end
            end
        end
    end
    table.sort(result, function(a, b)
        if a.value ~= b.value then return a.value < b.value end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return result, room
end

local panel, reveal = nil, 0
local active, target, pending, lastSlot = false, nil, nil, nil
local candidates, offset = {}, 0
local draw, refresh, replace

local function getPoints(region)
    local points = {}
    for i = 1, region:GetNumPoints() do points[i] = { region:GetPoint(i) } end
    return points
end

local function setPoints(region, points)
    region:ClearAllPoints()
    for _, point in ipairs(points) do region:SetPoint(unpack(point)) end
end

local function restoreLootShell()
    local join = panel and panel.join
    if not join then return end
    panel.join = nil
    setPoints(join.shell, join.shellPoints)
    if join.line then setPoints(join.line, join.linePoints) end
    panel.bodyShell:Show()
    if extras.CutPanelCorner then extras.CutPanelCorner(panel.lootFrame) end
    Style.LayoutShell(join.shell)
end

local function close()
    target, pending, lastSlot, offset = nil, nil, nil, 0
    if next(waitingItems) then wipe(waitingItems) end
    if panel then
        DUI.Motion.Tween(panel, reveal, 0, 0, function() reveal = 0 end)
        restoreLootShell()
        panel:Hide()
    end
end

local WIDTH, ROWS, ROW = 292, 5, 34
local function build(lootFrame)
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    panel:SetClipsChildren(true)
    panel:EnableMouseWheel(true)
    local body = CreateFrame("Frame", nil, panel)
    panel.body = body
    body:SetWidth(WIDTH)
    panel.bodyShell = Style.Shell(body, { window = true })
    local title = Style.Text(body, Style.SIZE.head, "LEFT")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(T("Make room for loot"))
    panel.summary = Style.Text(body, Style.SIZE.small, "LEFT")
    panel.summary:SetPoint("TOPLEFT", 12, -34)
    panel.summary:SetPoint("RIGHT", body, "RIGHT", -12, 0)
    panel.summary:SetWordWrap(false)
    panel.note = Style.Text(body, Style.SIZE.small, "LEFT")
    panel.note:SetPoint("TOPLEFT", 12, -59)
    panel.note:SetPoint("RIGHT", body, "RIGHT", -12, 0)
    panel.note:SetWordWrap(true)
    panel.page = Style.Text(body, Style.SIZE.tiny, "RIGHT")
    panel.page:SetPoint("BOTTOMRIGHT", -12, 7)
    local dismiss = Widgets.Button(body, "‹", 22)
    panel.dismiss = dismiss
    dismiss:SetWidth(23)
    dismiss:SetPoint("TOPRIGHT", -7, -6)
    dismiss:SetScript("OnClick", close)
    panel.rows = {}
    for i = 1, ROWS do
        local row = CreateFrame("Frame", nil, body)
        row:SetPoint("TOPLEFT", 12, -56 - (i - 1) * ROW)
        row:SetPoint("RIGHT", body, "RIGHT", -12, 0)
        row:SetHeight(ROW)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(24, 24)
        row.icon:SetPoint("LEFT")
        Style.CropIcon(row.icon)
        row.name = Style.Text(row, Style.SIZE.small, "LEFT")
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", 31, -3)
        row.name:SetWordWrap(false)
        row.price = Style.Text(row, Style.SIZE.tiny, "LEFT")
        row.price:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 31, 4)
        row.button = Widgets.Button(row, T("Replace"), 22)
        row.button:SetWidth(79)
        row.button:SetPoint("RIGHT")
        row.name:SetPoint("RIGHT", row.button, "LEFT", -5, 0)
        row.button:SetScript("OnClick", function() if row.entry then replace(row.entry) end end)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function()
            if row.entry and GameTooltip then
                GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
                GameTooltip:SetHyperlink(row.entry.link)
                if target and target.value and row.entry.value > target.value then
                    GameTooltip:AddLine(T("This stack is worth more at a vendor than the loot."), 1, 0.45, 0.35, true)
                end
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() if GameTooltip and GameTooltip:IsOwned(row) then GameTooltip:Hide() end end)
        panel.rows[i] = row
    end
    panel:SetScript("OnMouseWheel", function(_, delta)
        local nextOffset = math.max(0, math.min(math.max(0, #candidates - ROWS), offset - delta))
        if nextOffset ~= offset then offset = nextOffset; draw() end
    end)
    panel.lootFrame = lootFrame
end

local function joinLootShell(lootFrame, right)
    local native = Style.GetShell(lootFrame)
    if not (native and native:IsShown()) then
        restoreLootShell()
        return false
    end
    local join = panel.join
    if not (join and join.shell == native) then
        restoreLootShell()
        local skins = DUI:GetModule("Skins")
        local kit = skins and skins.ns and skins.ns.Kit
        local line = kit and kit.TopLineOf and kit.TopLineOf(lootFrame)
        join = { shell = native, shellPoints = getPoints(native), line = line,
            linePoints = line and getPoints(line) }
        panel.join = join
    end
    if join.right ~= right then
        join.right = right
        local near = right and "LEFT" or "RIGHT"
        local far = right and "RIGHT" or "LEFT"
        setPoints(native, {
            { "TOP" .. near, lootFrame, "TOP" .. near },
            { "BOTTOM" .. far, panel, "BOTTOM" .. far },
        })
        if join.line then
            setPoints(join.line, {
                { "TOPLEFT", native, "TOPLEFT", 6, -2 },
                { "TOPRIGHT", native, "TOPRIGHT", -6, -2 },
            })
        end
        if extras.CutPanelCorner then extras.CutPanelCorner(lootFrame, right and "right" or "left") end
        Style.LayoutShell(native)
    end
    panel.bodyShell:Hide()
    return true
end

local ABOVE_LOOT = {
    BACKGROUND = "LOW", LOW = "MEDIUM", MEDIUM = "HIGH", HIGH = "DIALOG",
    DIALOG = "FULLSCREEN", FULLSCREEN = "FULLSCREEN_DIALOG", FULLSCREEN_DIALOG = "TOOLTIP",
}

local function placeDrawerLayers(lootFrame)
    local base = lootFrame:GetFrameStrata()
    local strata = ABOVE_LOOT[base] or base
    local shell = Style.GetShell(lootFrame)
    local overlay = shell and shell.over
    local level = math.max(lootFrame:GetFrameLevel(), shell and shell:GetFrameLevel() or 0,
        overlay and overlay:GetFrameLevel() or 0) + 2
    if panel.layer == strata and panel.layerLevel == level then return end
    panel.layer, panel.layerLevel = strata, level
    panel:SetFrameStrata(strata)
    panel:SetFrameLevel(level)
    panel:SetAlpha(1)
    panel.body:SetFrameStrata(strata)
    panel.body:SetFrameLevel(level + 1)
    panel.body:SetAlpha(1)
    panel.bodyShell:SetFrameStrata(strata)
    panel.bodyShell:SetFrameLevel(level)
    panel.dismiss:SetFrameStrata(strata)
    panel.dismiss:SetFrameLevel(level + 3)
    for _, row in ipairs(panel.rows) do
        row:SetFrameStrata(strata)
        row:SetFrameLevel(level + 2)
        row.button:SetFrameStrata(strata)
        row.button:SetFrameLevel(level + 3)
    end
end

local function open()
    local lootFrame = _G.LootFrame
    if not (lootFrame and lootFrame:IsShown()) then return end
    if not panel then build(lootFrame) end
    local already = panel:IsShown()
    local scale = lootFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
    if panel:GetScale() ~= scale then panel:SetScale(scale) end
    placeDrawerLayers(lootFrame)
    local right = lootFrame:GetRight()
    local left = lootFrame:GetLeft()
    local space = type(right) == "number" and UIParent:GetWidth() / scale - right or WIDTH
    local dir = space >= WIDTH or type(left) ~= "number" or space >= left
    if not already or panel.right ~= dir then
        panel.right = dir
        panel:ClearAllPoints()
        panel:SetPoint(dir and "TOPLEFT" or "TOPRIGHT", lootFrame, dir and "TOPRIGHT" or "TOPLEFT")
        panel.body:ClearAllPoints()
        panel.body:SetPoint(dir and "TOPRIGHT" or "TOPLEFT", panel, dir and "TOPRIGHT" or "TOPLEFT")
        panel.dismiss.text:SetText(dir and "‹" or "›")
    end
    if not already then
        panel:SetSize(1, math.max(1, lootFrame:GetHeight()))
        panel:Show()
    end
    if not joinLootShell(lootFrame, dir) and extras.CutPanelCorner then
        extras.CutPanelCorner(panel.body, dir and "right" or "left")
    end
    if already then return end
    DUI.Motion.Tween(panel, 0, 1, DUI.Motion.On() and DUI.Motion.FAST or 0, function(v)
        reveal = v
        panel:SetWidth(math.max(1, WIDTH * v))
    end)
end

draw = function()
    if not (panel and target) then return end
    local loot = target
    local price = loot.value and ("  ·  " .. DUI.MoneyString(loot.value)) or ""
    panel.summary:SetText(loot.name .. " ×" .. loot.count .. price)
    local ready = pending and pending.ready
    local busy = InCombatLockdown()
    local rows = (not pending and not busy) and math.min(#candidates, ROWS) or 0
    offset = math.max(0, math.min(offset, #candidates - ROWS))
    local paging = rows > 0 and #candidates > ROWS
    panel.body:SetHeight(rows > 0 and 66 + rows * ROW + (paging and 10 or 0) or 99)
    local nativeHeight = panel.join and panel.lootFrame:GetHeight() or 0
    panel:SetHeight(math.max(panel.body:GetHeight(), nativeHeight))
    panel.page:SetShown(paging)
    if paging then panel.page:SetText(string.format("%d–%d / %d", offset + 1, offset + rows, #candidates)) end
    panel.note:SetText(busy and T("Available after combat") or
        (pending and not ready and T("Waiting for the game to confirm the deletion.")) or
        (pending and pending.finished and not pending.binding and T("The loot is still available in the loot list.")) or
        (rows == 0 and not pending and T("No suitable common or poor stacks.")) or "")
    for i, row in ipairs(panel.rows) do
        local entry = i <= rows and candidates[i + offset]
        row.entry = entry or nil
        row:SetShown(entry ~= nil and entry ~= false)
        if entry then
            if entry.guid == nil then entry.guid = itemGUID(entry.bag, entry.slot) or false end
            row.icon:SetTexture(entry.icon)
            row.name:SetText(entry.name .. " ×" .. entry.count)
            row.price:SetText(DUI.MoneyString(entry.value))
            local more = loot.value and entry.value > loot.value
            row.price:SetTextColor(1, more and 0.45 or 0.84, more and 0.35 or 0.68)
        end
    end
end

local function sameLoot(a, b)
    return a and b and a.slot == b.slot and a.link == b.link and a.count == b.count
end

refresh = function(snapshot)
    if not (active and useBlasta() and target) then close(); return end
    local loot = incoming(target.slot)
    if not sameLoot(loot, target) then close(); return end
    if InCombatLockdown() then candidates = {}; open(); draw(); return end
    local room
    candidates, room = scan(loot, snapshot, pending ~= nil)
    if pending then
        if not GetCursorInfo() and not Bags.GetContainerItemInfo(pending.bag, pending.slot) and room >= loot.count then
            pending.ready = true
            local action = pending
            if not action.attempted or (action.retry and not action.binding) then
                local retry = action.retry
                action.attempted, action.retry, action.finished = true, nil, retry
                pcall(LootSlot, loot.slot)
                if pending ~= action then return end
                if not retry and not action.binding then
                    -- Some clients expose the empty slot before the loot call
                    -- can use it. Recheck once after the inventory has settled.
                    C_Timer.After(0.2, function()
                        if pending ~= action or action.binding then return end
                        action.retry = true
                        refresh()
                    end)
                end
            end
        elseif pending.ready then
            close()
            return
        end
    elseif room >= loot.count then
        close()
        return
    end
    open()
    draw()
end

replace = function(entry)
    if not (active and target and not pending and useBlasta() and not InCombatLockdown() and not GetCursorInfo()
        and Bags.PickupContainerItem and DeleteCursorItem) then return end
    local loot = incoming(target.slot)
    if not sameLoot(loot, target) then close(); return end
    local current
    for _, at in ipairs(scan(loot)) do
        if at.bag == entry.bag and at.slot == entry.slot then current = at; break end
    end
    if not (current and current.link == entry.link and current.count == entry.count and current.value == entry.value
        and (not entry.guid or itemGUID(entry.bag, entry.slot) == entry.guid)) then
        DUI.Print(T("The contents changed. Choose a stack again."))
        refresh()
        return
    end
    local ok = pcall(Bags.PickupContainerItem, entry.bag, entry.slot)
    local kind, _, link = GetCursorInfo()
    if not ok or plain(kind) ~= "item" or plain(link) ~= entry.link then
        if kind and ClearCursor then ClearCursor() end
        return
    end
    if not pcall(DeleteCursorItem) then
        if ClearCursor then ClearCursor() end
        DUI.Print(T("The game did not confirm the deletion."))
        return
    end
    local action = { loot = loot, bag = entry.bag, slot = entry.slot }
    pending = action
    -- Try in the click first. If bag state arrives later, the bag/cursor
    -- refresh will take the exact same loot slot once space is verified.
    refresh()
    if pending ~= action or action.ready then return end
    C_Timer.After(1, function()
        if pending == action and not action.ready and not GetCursorInfo() then
            pending = nil
            DUI.Print(T("The game did not confirm the deletion."))
            refresh()
        end
    end)
end

local borders = setmetatable({}, { __mode = "k" })
local function skinKit()
    local skins = DUI:GetModule("Skins")
    return skins and skins.ns and skins.ns.Kit
end

local function hideIconArt(state, region)
    if not (region and region.GetAlpha and region.SetAlpha) then return end
    local alpha = plain(region:GetAlpha())
    if type(alpha) ~= "number" then return end
    if state.art[region] == nil then state.art[region] = alpha end
    if alpha ~= 0 then region:SetAlpha(0) end
end

local function isIconBorder(region)
    local ok, atlas
    if region.GetAtlas then ok, atlas = pcall(region.GetAtlas, region) end
    atlas = ok and plain(atlas)
    if type(atlas) == "string" then
        local key = atlas:lower()
        if key:find("itemicon%-border") or key:find("itemicon%-empty")
            or key:find("itembutton.-border") then return true end
    end
    local path
    if region.GetTextureFilePath then ok, path = pcall(region.GetTextureFilePath, region) end
    path = ok and plain(path)
    if type(path) == "string" then
        local key = path:lower()
        return key:find("whiteiconframe", 1, true) or key:find("ui-quickslot2", 1, true)
    end
end

local function hideSlotFrame(state, frame, kit)
    local shell = kit and kit.ShellOf and kit.ShellOf(frame) or Style.GetShell(frame)
    hideIconArt(state, shell)
    for _, child in ipairs({ frame:GetChildren() }) do
        local detail = Style.GetShell(child)
        local opts = detail and detail.opts
        if opts and opts.noBackground and opts.noBevel then hideIconArt(state, detail) end
    end
end

local function styleRow(row)
    local btn = row.Item
    if not (btn and btn.HookScript and row.GetSlotIndex) then return end
    local state = borders[btn]
    if not state then
        state = {}
        borders[btn] = state
        btn:HookScript("OnMouseDown", function()
            if active then lastSlot = plain(row:GetSlotIndex()) end
        end)
        -- Recycled rows can restore their original art without a list relayout.
        if type(row.Init) == "function" then
            hooksecurefunc(row, "Init", function(current) DUI.SafeCall(styleRow, current) end)
        end
    end
    local square = DUI:Get(ADDON, borderKey) == "square"
    if not square and not state.hidden then return end
    if square then
        if not state.lines then
            local overlay = CreateFrame("Frame", nil, btn)
            overlay:SetAllPoints(btn)
            overlay:EnableMouse(false)
            state.overlay = overlay
            state.lines = extras.IconOutline(overlay)
        end
        local slot = plain(row:GetSlotIndex())
        local quality, quest
        if type(slot) == "number" then
            local _, _, _, _, q, _, isQuestItem, questID = GetLootSlotInfo(slot)
            quality = plain(q)
            quest = plain(isQuestItem) == true or type(plain(questID)) == "number" and questID > 0
        end
        local level, strata = btn:GetFrameLevel() + 6, btn:GetFrameStrata()
        if state.overlay:GetFrameLevel() ~= level then state.overlay:SetFrameLevel(level) end
        if state.overlay:GetFrameStrata() ~= strata then state.overlay:SetFrameStrata(strata) end
        state.overlay:Show()
        state.lines(nil, true, ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality])
        state.art = state.art or {}
        state.hidden = true
        local icon = btn.icon or btn.Icon
        hideIconArt(state, btn.IconBorder)
        hideIconArt(state, btn.IconBorderDropShadow)
        hideIconArt(state, btn.ItemBorderGlow)
        hideIconArt(state, btn.ItemSlotBackground)
        hideIconArt(state, btn.EmptyBackground)
        local normal = btn.GetNormalTexture and btn:GetNormalTexture()
        if normal ~= icon then hideIconArt(state, normal) end
        if not quest then
            hideIconArt(state, row.IconQuestTexture)
        elseif state.art[row.IconQuestTexture] then
            row.IconQuestTexture:SetAlpha(state.art[row.IconQuestTexture])
            state.art[row.IconQuestTexture] = nil
        end
        hideSlotFrame(state, btn, skinKit())
        for _, region in ipairs({ btn:GetRegions() }) do
            if region ~= icon and isIconBorder(region) then hideIconArt(state, region) end
        end
    else
        for art, alpha in pairs(state.art) do art:SetAlpha(alpha) end
        state.lines(nil, false)
        state.overlay:Hide()
        state.hidden, state.art = nil, nil
    end
end

local watched
local function watch()
    local frame = _G.LootFrame
    local box = frame and frame.ScrollBox
    if not box then return end
    if watched ~= box then
        watched = box
        local kit = skinKit()
        if kit and kit.EachRow then
            kit.EachRow(box, styleRow, "blastaLootIcons")
        elseif box.ForEachFrame and (not box.GetView or box:GetView()) then
            box:ForEachFrame(styleRow)
        end
        frame:HookScript("OnHide", close)
        frame:HookScript("OnShow", function() if target then refresh() end end)
        return
    end
    if box.ForEachFrame and (not box.GetView or box:GetView()) then box:ForEachFrame(styleRow) end
end

local blocked
local function showBlocked()
    if not (blocked and active and useBlasta()) then return end
    local loot = type(lastSlot) == "number" and incoming(lastSlot)
    local snapshot
    if not loot then
        for i = 1, GetNumLootItems() do
            local found = incoming(i)
            if found then
                if InCombatLockdown() then loot = found; break end
                snapshot = snapshot or bagSnapshot()
                local _, room = scan(found, snapshot, true)
                if room < found.count and (not loot or (found.value or 0) > (loot.value or 0)) then loot = found end
            end
        end
    end
    if not loot then return end
    target, blocked, offset = loot, nil, 0
    refresh(snapshot)
end

local soon = DUI.Soon(function()
    if blocked then showBlocked() elseif target then refresh() end
end)
local queueStyle = DUI.Soon(watch)
local function opened()
    active = true
    queueStyle()
    if blocked then soon() end
end
DUI.RegisterEvent("LOOT_READY", opened)
DUI.RegisterEvent("LOOT_OPENED", opened)
DUI.RegisterEvent("LOOT_CLOSED", function()
    active, blocked = false, nil
    close()
end)
DUI.RegisterEvent("UI_ERROR_MESSAGE", function(_, code, message)
    code, message = plain(code), plain(message)
    if (LE_GAME_ERR_INV_FULL and code == LE_GAME_ERR_INV_FULL) or (LE_GAME_ERR_BAG_FULL and code == LE_GAME_ERR_BAG_FULL)
        or (ERR_INV_FULL and message == ERR_INV_FULL) or (ERR_BAG_FULL and message == ERR_BAG_FULL) then
        if active and not pending and useBlasta() then
            blocked = true
            soon()
        end
    end
end)
DUI.RegisterEvent("GET_ITEM_INFO_RECEIVED", function(_, id, ok)
    id = plain(id)
    if id and waitingItems[id] then
        waitingItems[id] = nil
        if ok and (blocked or target) then soon() end
    end
end)
DUI.RegisterEvent("BAG_UPDATE_DELAYED", function() if target then soon() end end)
DUI.RegisterEvent("LOOT_SLOT_CHANGED", function() if active then queueStyle() end end)
DUI.RegisterEvent("CURSOR_UPDATE", function()
    local action = pending
    if not action then return end
    C_Timer.After(0, function()
        if pending ~= action or GetCursorInfo() then return end
        refresh()
        if pending == action and not action.ready and Bags.GetContainerItemInfo(action.bag, action.slot) then
            pending = nil
            refresh()
        end
    end)
end)
DUI.RegisterEvent("LOOT_SLOT_CLEARED", function(_, slot)
    if target and target.slot == slot then close() end
    if active then queueStyle() end
end)
DUI.RegisterEvent("LOOT_BIND_CONFIRM", function(_, slot)
    if pending and pending.attempted and pending.loot.slot == slot then pending.binding = true end
end)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", function() if target then refresh() end end)
DUI.RegisterEvent("PLAYER_REGEN_DISABLED", function() if target then refresh() end end)
DUI.On("SettingChanged", function(scope, path)
    if scope ~= ADDON then return end
    if path == borderKey then watch() end
    if path == enabledKey and not useBlasta() then close() end
end)
DUI.On("Login", function() askProvider(false) end)
