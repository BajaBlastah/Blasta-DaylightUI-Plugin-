local _, extras = ...
local DUI = DaylightUI

local function setting(module, row, default)
    local key = row.key
    row.get = function() return DUI:Get(module.name, key) end
    row.set = function(value) return DUI:Set(module.name, key, value) end
    row.default = function() return default end
    return row
end

local info = DUI:GetModule("InfoPanel")
local panel = info and info.ns and info.ns.Panel
if panel and type(panel.Layout) == "function" and type(panel.PAD) == "number" and info.defaults then
    local defaultPadding = panel.PAD
    info.defaults.blastaPanelPadding = defaultPadding
    info.defaults.blastaSquarePanel = false
    local overriddenShell, originalCorner
    local layout = panel.Layout
    function panel.Layout(db, ...)
        -- The resize grip and data strip also read PAD outside Layout.
        panel.PAD = math.max(0, math.min(16, tonumber(db.blastaPanelPadding) or defaultPadding))
        local shell = panel.panel and DUI.Style.GetShell(panel.panel)
        if shell and shell.opts then
            if db.blastaSquarePanel == true then
                if overriddenShell ~= shell then
                    overriddenShell, originalCorner = shell, shell.opts.cornerPx
                end
                shell.opts.cornerPx = 0
            elseif overriddenShell == shell then
                shell.opts.cornerPx = originalCorner
                overriddenShell, originalCorner = nil, nil
            end
        end
        return layout(db, ...)
    end
    function extras.InfoPanelSpacingPage()
        local rows = {
            setting(info, { type = "toggle", key = "blastaSquarePanel", label = "Square minimap info panel" }, false),
            setting(info, { type = "slider", key = "blastaPanelPadding", label = "Info panel padding",
                min = 0, max = 16, step = 1, unit = "px",
                desc = "Adjust the space inside the info panel around its contents." }, defaultPadding),
        }
        return extras.ShowDaylightRequirements({ groups = { { label = "Info panel", items = rows } } }, info)
    end
end

local module = DUI:GetModule("Buffs")
local buffs = module and module.ns
local bar, debuffs = buffs and buffs.Bar, buffs and buffs.DebuffBar
local widgets = buffs and buffs.Widgets
if not (bar and debuffs and widgets and widgets.Radius and bar.StyleButton and debuffs.StyleButton
    and bar.CurrentFlow and bar.LayoutWeapons and bar.ApplyAll and debuffs.ApplyAll and debuffs.ApplyAttach
    and bar.Restyle and debuffs.Restyle and bar.Scale and bar.Corner and bar.Height and debuffs.Corner
    and buffs.PlaceAnchor and buffs.On and module.defaults and module.defaults.settings
    and module.defaults.settings.debuff) then return end

local defaults = module.defaults.settings
defaults.blastaSquare = false
defaults.blastaEvenSpacing = true
local stableMotion = type(buffs.GetSetting) == "function" and buffs.Feel and buffs.Feel.TuneSlide
if stableMotion then
    defaults.blastaStableAuraIcons = true
    extras.German["Keep minimap aura icons still"] = "Einblendanimation an der Minikarte abschalten"
    extras.German["Suppress replayed slide animations when Daylight refreshes the buff and debuff bars."] =
        "Unterdrückt die wiederholte Einblendanimation, wenn Daylight die Buff- und Debuffleisten aktualisiert."
    local get = buffs.GetSetting
    function buffs.GetSetting(key, ...)
        if key == "newGlow" and get("blastaStableAuraIcons") ~= false then return false end
        return get(key, ...)
    end
end
extras.German["Even buff spacing"] = "Gleichmäßige Buff-Abstände"
extras.German["Use the same horizontal gap between all buffs, including category boundaries."] =
    "Verwendet zwischen allen Buffs denselben horizontalen Abstand, auch an Kategoriegrenzen."
defaults.debuff.blastaSquare = false
defaults.debuff.blastaUnderBuffs = false
defaults.debuff.blastaBuffGap = 14

local radius = widgets.Radius
local square
function widgets.Radius(...)
    if square then return 0 end
    return radius(...)
end

local function useSquare(target, method)
    local original = target[method]
    target[method] = function(self, ...)
        local previous = square
        square = self:Setting("blastaSquare") == true
        local ok, err = pcall(original, self, ...)
        square = previous
        if not ok then error(err, 0) end
    end
end
useSquare(bar, "StyleButton")
useSquare(debuffs, "StyleButton")
useSquare(bar, "LayoutWeapons")

-- Each bar's icon height (Blasta's AuraSizes). The native size stays the
-- width. Widgets.Height has no bar argument, so every bar method marks which
-- bar is working; calls from the bars' own callbacks use the last one.
local Sizes = extras.AuraSizes
local SIZE_KEYS = { buff = "settings.iconSize", debuff = "settings.debuff.iconSize" }
local sizeNames = {}
for scope, key in pairs(SIZE_KEYS) do
    local path, names = Sizes.Names(key)
    sizeNames[scope] = { path = path, names = names }
end
local activeScope, lastScope
local nativeHeight = widgets.Height
function widgets.Height(size, ...)
    local scope = activeScope or lastScope
    local info = scope and sizeNames[scope]
    if not (info and tonumber(size)) then return nativeHeight(size, ...) end
    local function read(field) return DUI:Get(module.name, info.path .. info.names[field]) end
    return Sizes.Height(read, size, widgets.ASPECT or 1)
end
hooksecurefunc(widgets, "Fit", function(button, width)
    if button.Icon and button.edgeShape then
        button.Icon:SetTexCoord(Sizes.IconCoords(width, button.edgeShape.h, button.edgeShape.T))
    end
end)

local function finish(previous, ...)
    activeScope = previous
    return ...
end
local function track(instance)
    if type(instance) ~= "table" or instance.blastaSized then return instance end
    instance.blastaSized = true
    local scope = instance.scope == "debuff" and "debuff" or "buff"
    for key, fn in pairs(instance) do
        if type(fn) == "function" then
            instance[key] = function(...)
                local previous = activeScope
                activeScope, lastScope = scope, scope
                return finish(previous, fn(...))
            end
        end
    end
    return instance
end
track(bar)
track(debuffs)
if bar.Setting then
    local settingOf = bar.Setting
    function bar:Setting(key)
        if key == "categoryGap" and settingOf(self, "blastaEvenSpacing") ~= false then return 0 end
        return settingOf(self, key)
    end
end

-- Discovering a spell normally rewrites every candidate filter, which makes
-- the client re-show the whole bar. Update only the affected categories.
if buffs.Fire and buffs.Spells and buffs.Spells.Sets and buffs.Auras and buffs.Auras.BuffFilters
    and buffs.Categories and buffs.Categories.Order and bar.ApplyGroups and bar.MarkDirty and bar.RefreshCounts then
    local applied, frame, learning, queued = {}, nil, false, false
    local function filters()
        local sets = buffs.Spells.Sets()
        local out = {}
        for _, id in ipairs(buffs.Categories.Order()) do
            if bar.groups and bar.groups[id] then out[id] = buffs.Auras.BuffFilters(id, sets) end
        end
        return out
    end
    local function sameSet(a, b)
        if a == b then return true end
        if not (a and b) then return false end
        for id in pairs(a) do if not b[id] then return false end end
        for id in pairs(b) do if not a[id] then return false end end
        return true
    end
    hooksecurefunc(bar, "ApplyGroups", function()
        frame, applied = bar.frame, filters()
    end)
    local fire, markDirty = buffs.Fire, bar.MarkDirty
    function buffs.Fire(event, ...)
        if event ~= "SPELLS_CHANGED" then return fire(event, ...) end
        local previous = learning
        learning = true
        local ok, err = pcall(fire, event, ...)
        learning = previous
        if not ok then error(err, 0) end
    end
    function bar:MarkDirty()
        if not learning or not frame or frame ~= self.frame or not frame.SetAuraGroupCandidateFilters then
            return markDirty(self)
        end
        if queued then return end
        queued = true
        C_Timer.After(0, function()
            queued = false
            if not self.frame or self.scheduled then return end
            if frame ~= self.frame then markDirty(self); return end
            self:InvalidateMembers()
            local nextFilters = filters()
            for id, nextFilter in pairs(nextFilters) do
                local old = applied[id]
                if not old then markDirty(self); return end
                if not (sameSet(old.includeSpellIDs, nextFilter.includeSpellIDs)
                    and sameSet(old.excludeSpellIDs, nextFilter.excludeSpellIDs)) then
                    if buffs.Feel and buffs.Feel.Hush then buffs.Feel.Hush() end
                    if not pcall(frame.SetAuraGroupCandidateFilters, frame, id, nextFilter) then
                        markDirty(self)
                        return
                    end
                end
            end
            applied = nextFilters
            self:RefreshCounts()
        end)
    end
end
if type(buffs.CreateBar) == "function" then
    local createBar = buffs.CreateBar
    function buffs.CreateBar(...) return track(createBar(...)) end
end
local placeAnchor = buffs.PlaceAnchor
function buffs.PlaceAnchor(...)
    -- Only the debuffs' first row height is read here.
    local previous = activeScope
    activeScope = "debuff"
    return finish(previous, placeAnchor(...))
end

local function restyleSizes()
    for _, instance in ipairs({ bar, debuffs }) do
        if instance.frame then
            pcall(instance.ApplyAll, instance)
            pcall(instance.Restyle, instance)
        end
    end
    pcall(buffs.PlaceAnchor)
end

local function underBuffs()
    return DUI:Get(module.name, "settings.debuff.blastaUnderBuffs") == true
end

local function readableNumber(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function visibleBuffDepth()
    local top = bar.holder:GetTop()
    local scale = bar.holder:GetEffectiveScale()
    if not (readableNumber(top) and readableNumber(scale) and scale > 0) then return 0 end
    local depth = 0
    for _, buttons in pairs(bar.buttons or {}) do
        for _, button in ipairs(buttons) do
            local visible = button:IsVisible()
            if not (issecretvalue and issecretvalue(visible)) and visible then
                local bottom, buttonScale = button:GetBottom(), button:GetEffectiveScale()
                if readableNumber(bottom) and readableNumber(buttonScale) then
                    depth = math.max(depth, top - bottom * buttonScale / scale)
                end
            end
        end
    end
    return depth
end

local lastHeight, queued = 0, false
local function reservedBuffDepth()
    local columns = math.max(1, math.floor(tonumber(DUI:Get(module.name, "settings.columns")) or 8))
    local rows = math.ceil(21 / columns)
    if bar.GroupLayout then
        local layout = bar:GroupLayout(1)
        return layout.elementHeight * rows + (layout.lineSpacing or 0) * (rows - 1)
    end
    return bar:Height() * rows
end

local function placeDebuffs()
    queued = false
    if not underBuffs() then return end
    if InCombatLockdown() then
        DUI.AfterCombat(placeDebuffs, "blasta:debuffAnchor")
        return
    end
    if not (bar.holder and debuffs.holder and module.enabled) then return end
    local flow = bar:CurrentFlow()
    local down = bar.ContainerOffset and select(2, bar:ContainerOffset()) or 0
    local scale = bar:Scale()
    local weaponHeight = (bar.weaponWidth or 0) > 0 and bar:Height() or 0
    if flow and (flow.height or 0) > 0 then
        lastHeight = (flow.height + down) * scale
    elseif flow then
        lastHeight = 0
    end
    local measured, depth = pcall(visibleBuffDepth)
    local reservedHeight = (reservedBuffDepth() + down) * scale
    local height = math.max(reservedHeight, lastHeight, measured and depth or 0, weaponHeight * scale)
    local gap = tonumber(DUI:Get(module.name, "settings.debuff.blastaBuffGap")) or 14
    local point, anchor, relative, x, y = debuffs.holder:GetPoint(1)
    local corner, attach = debuffs:Corner(), bar:Corner()
    local offset = -height - gap
    if point == corner and anchor == bar.holder and relative == attach and readableNumber(x) and x == 0
        and readableNumber(y) and math.abs(y - offset) < 0.05 then return end
    debuffs.holder:ClearAllPoints()
    debuffs.holder:SetPoint(corner, bar.holder, attach, 0, offset)
end

local function queuePlacement()
    if underBuffs() and not queued then
        queued = true
        C_Timer.After(0, placeDebuffs)
    end
end

if DUI.RegisterCommand then
    DUI.RegisterCommand("blastaauracheck", function()
        local flow = bar.holder and bar:CurrentFlow()
        local ok, depth = pcall(visibleBuffDepth)
        local _, relative, _, _, y
        if debuffs.holder then _, relative, _, _, y = debuffs.holder:GetPoint(1) end
        DUI.Print(("Blasta auras: enabled=%s, rows=%s, height=%s, measured=%s, attached=%s, offset=%s"):format(
            tostring(underBuffs()), tostring(flow and flow.lines), tostring(flow and flow.height),
            tostring(ok and depth or nil), tostring(bar.holder ~= nil and relative == bar.holder),
            tostring(readableNumber(y) and y or nil)))
    end, "/dui blastaauracheck")
end

local applyAttach = debuffs.ApplyAttach
function debuffs:ApplyAttach()
    if not underBuffs() then return applyAttach(self) end
    DUI.Movers.Suspend(self.moverKey, true)
    queuePlacement()
end

hooksecurefunc(buffs, "PlaceAnchor", queuePlacement)
hooksecurefunc(bar, "ApplyAll", queuePlacement)
hooksecurefunc(debuffs, "ApplyAll", queuePlacement)
hooksecurefunc(bar, "LayoutWeapons", queuePlacement)
if bar.InvalidateMembers then hooksecurefunc(bar, "InvalidateMembers", queuePlacement) end
buffs.On("AURAS_CHANGED", queuePlacement)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", queuePlacement)
DUI.On("SettingChanged", function(scope, key)
    if scope ~= module.name then return end
    if key == "settings.blastaSquare" then bar:Restyle() end
    if key == "settings.debuff.blastaSquare" then debuffs:Restyle() end
    if key == "settings.blastaStableAuraIcons" then
        bar:Restyle()
        debuffs:Restyle()
    end
    if key == "settings.debuff.blastaUnderBuffs" then
        buffs.PlaceAnchor()
        if not underBuffs() then lastHeight = 0 end
        if debuffs.holder then debuffs:ApplyAttach() end
    end
    if key == "settings.debuff.blastaBuffGap" or key == "settings.columns" then queuePlacement() end
end)
DUI.On("MoverApplied", function(key)
    if key == bar.moverKey or key == debuffs.moverKey then queuePlacement() end
end)

function extras.PlayerAuraLayoutPage()
    local rows = {
        setting(module, { type = "toggle", key = "settings.blastaSquare", label = "Square player buff borders" }, false),
        setting(module, { type = "toggle", key = "settings.blastaEvenSpacing", blastaSince = "2.0", label = "Even buff spacing",
            desc = "Use the same horizontal gap between all buffs, including category boundaries." }, true),
        setting(module, { type = "toggle", key = "settings.debuff.blastaSquare", label = "Square player debuff borders" }, false),
        setting(module, { type = "toggle", key = "settings.debuff.blastaUnderBuffs", label = "Place debuffs under buffs" }, false),
        setting(module, { type = "slider", key = "settings.debuff.blastaBuffGap", label = "Gap below buffs",
            min = 0, max = 80, step = 1, unit = "px", disabled = function() return not underBuffs() end }, 14),
    }
    if stableMotion then
        table.insert(rows, 1, setting(module, { type = "toggle", key = "settings.blastaStableAuraIcons", blastaSince = "2.0",
            label = "Keep minimap aura icons still",
            desc = "Suppress replayed slide animations when Daylight refreshes the buff and debuff bars." }, true))
    end
    local groups = { { label = "Player buffs and debuffs", items = rows } }
    for _, scope in ipairs({ "buff", "debuff" }) do
        local widthRow = setting(module, { type = "slider", key = SIZE_KEYS[scope], label = "Icon width",
            min = 12, max = 64, step = 1, unit = "px", desc = "How wide each icon is." },
            DUI.DB.GetPath(module.defaults, SIZE_KEYS[scope]))
        local widthSet = widthRow.set
        widthRow.set = function(value) local ok = widthSet(value); restyleSizes(); return ok end
        local heightRow, keepRow = Sizes.Rows(widthRow, {
            scope = module.name, since = "1.5", defaults = module.defaults,
            base = function() return widgets.ASPECT or 1 end,
            onChange = restyleSizes,
        })
        if heightRow then
            widthRow.label, widthRow.blastaDynamicLabel = heightRow.blastaWidthLabel, true
            groups[#groups + 1] = { label = scope == "buff" and "Player buff size" or "Player debuff size",
                items = { widthRow, heightRow, keepRow } }
        end
    end
    return extras.ShowDaylightRequirements({ id = "playerAuraLayout", label = "Player buffs and debuffs",
        groups = groups }, module)
end

extras.Loaded("TopRightLayout")
