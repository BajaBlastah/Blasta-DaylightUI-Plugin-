local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("InfoPanel")
local ns = mod and mod.ns
local DT = ns and ns.DataTexts
if not (DT and DT.ORDER and DT.TEXTS and DT.Value and DT.Word and mod.defaults and mod.defaults.databar) then return end

local defaultColor = { 0.88, 0.72, 0.46 }
local defaults = {
    selected = "system",
    entries = {},
    -- Off by default; GoldTextFit adapts exact amounts to the available space.
    exactMoney = false,
    good = { 0.42, 0.87, 0.46 },
    medium = { 0.98, 0.78, 0.30 },
    bad = { 1, 0.36, 0.33 },
}
local root = "dataTextColors"
if extras.HasSetting(mod, root) then return end
mod.defaults[root] = defaults
-- Retain the old setting so profiles with the earlier FPS option migrate.
local nativeSystemColors = extras.HasSetting(mod, "databar.systemColors")
if not nativeSystemColors then mod.defaults.databar.systemColors = false end

local function config()
    return mod.db and mod.db[root] or defaults
end

local shortMoney = DT.ShortMoney
if type(shortMoney) == "function" and type(DUI.MoneyString) == "function" then
    function DT.ShortMoney(copper)
        if config().exactMoney == true then return DUI.MoneyString(copper) end
        return shortMoney(copper)
    end
end

local function paletteColor(state)
    return config()[state] or defaults[state]
end

local ids = {}
local function entryID(key)
    -- Broker object names can contain dots and arbitrary punctuation.
    if not ids[key] then
        ids[key] = key:gsub("([^%w])", function(c) return string.format("_%02x", c:byte()) end)
    end
    return ids[key]
end

local function entry(key)
    local entries = config().entries
    return entries and entries[entryID(key)]
end

local function defaultMode(key)
    local bar = mod.db and mod.db.databar
    if not nativeSystemColors and key == "system" and bar and bar.systemColors then return "status" end
    return "default"
end

local function modeOf(key)
    local current = entry(key)
    return current and current.mode or defaultMode(key)
end

local function rgb(color)
    local function byte(n) return math.floor(math.max(0, math.min(1, n)) * 255 + 0.5) end
    return string.format("%02x%02x%02x", byte(color[1]), byte(color[2]), byte(color[3]))
end

local function recolor(s, hex)
    if type(s) ~= "string" or (issecretvalue and issecretvalue(s)) or s == "" then return s end
    -- Keep inline icons and hyperlinks, and retain any original color alpha.
    local code = "|cff" .. hex
    s = s:gsub("|c(%x%x)%x%x%x%x%x%x", "|c%1" .. hex):gsub("|r", "|r" .. code)
    return code .. s .. "|r"
end

local function low(n, critical, warning)
    if type(n) ~= "number" then return end
    return n <= critical and "bad" or n <= warning and "medium" or "good"
end

local status = {
    durability = function(n)
        return low(n or DT.ReadDurability(), DT.GEAR_BAD or 20, DT.GEAR_WARN or 50)
    end,
    bags = function(n)
        return low(n or DT.ReadBags(), DT.BAGS_BAD or 0, DT.BAGS_WARN or 4)
    end,
    ammo = function(n)
        return low(n or DT.ReadAmmo(), DT.AMMO_BAD or 50, DT.AMMO_WARN or 200)
    end,
    shards = function(n) return low(n or DT.ReadShards(), 0, 4) end,
    combat = function() return DT.InFight() and "bad" or "good" end,
    volume = function()
        local channel = DT.Channel()
        return DT.SoundOn(channel) and DT.Volume(channel) > 0 and "good" or "medium"
    end,
    hearth = function()
        local _, left, have = DT.ReadHearth()
        return not have and "bad" or left > 0 and "medium" or "good"
    end,
}

local wrapped = setmetatable({}, { __mode = "k" })
local function wrap(key)
    local spec = DT.TEXTS[key]
    if not (spec and type(spec.text) == "function") or wrapped[spec] then return end
    wrapped[spec] = true
    local render = spec.text
    spec.text = function(n, ...)
        local mode = modeOf(key)
        if key == "system" and (mode == "status" or mode == "custom") then
            local fps, ms = DT.ReadSystem()
            local fpsColor, latencyColor
            if mode == "custom" then
                local current = entry(key)
                fpsColor, latencyColor = current.color or defaultColor, current.latency or defaultColor
            else
                fpsColor = paletteColor(fps >= 60 and "good" or fps >= 30 and "medium" or "bad")
                latencyColor = ms > 0 and paletteColor(ms <= 60 and "good" or ms <= 120 and "medium" or "bad") or nil
            end
            local f, m = DT.Value(tostring(fps), fpsColor), DT.Value(tostring(ms), latencyColor)
            return f .. DT.Word(" fps  ") .. m .. DT.Word(" ms"), f .. DT.Word(" fps · ") .. m .. DT.Word(" ms")
        end
        local long, short = render(n, ...)
        local color
        if mode == "custom" then
            color = entry(key).color or defaultColor
        elseif mode == "status" and status[key] then
            local state = status[key](n)
            color = state and paletteColor(state)
        end
        if not color then return long, short end
        local hex = rgb(color)
        return recolor(long, hex), recolor(short, hex)
    end
    return true
end

for _, key in ipairs(DT.ORDER) do wrap(key) end
local Broker = ns.Broker
if Broker and type(Broker.Add) == "function" then
    hooksecurefunc(Broker, "Add", function(name)
        if type(name) ~= "string" or type(Broker.PREFIX) ~= "string" then return end
        local key = Broker.PREFIX .. name
        if wrap(key) and modeOf(key) ~= "default" and DT.Redraw then DT.Redraw(key) end
    end)
end

-- The native gold tween formats its amount directly, outside the renderer.
local countGold = DT.CountGold
if type(countGold) == "function" then
    function DT.CountGold(slot, changed)
        if config().exactMoney == true then
            -- Exact money exposes every intermediate copper value. Use the
            -- native first-read path to settle the amount and stop the tween.
            slot.rollShown = nil
            return countGold(slot, false)
        end
        if modeOf("gold") ~= "custom" or not changed or slot.rollShown == nil
            or DT.Sample() or not DUI.Motion.On() then return countGold(slot, changed) end
        local from, now = slot.rollShown, DT.ReadMoney()
        slot.text:SetWidth(0)
        DUI.Motion.Tween(slot, from, now, DUI.Motion.SLOW, function(v)
            v = math.floor(v + 0.5)
            slot.rollShown = v
            local color = entry("gold") and entry("gold").color or defaultColor
            slot.rollText = recolor(DT.ShortMoney(v), rgb(color))
            slot.text:SetText(slot.rollText)
        end, function()
            slot.rollText = nil
            if slot.textW then slot.text:SetWidth(slot.textW) end
            slot.text:SetText(slot.isShort and slot.short or slot.long)
        end)
    end
end

local function selected()
    local key = config().selected
    return DT.TEXTS[key] and key or "system"
end

local function chooseText()
    local values, order = {}, {}
    for _, key in ipairs(DT.ORDER) do
        values[key] = DT.NAMES[key] or DT.TEXTS[key].name
        order[#order + 1] = key
    end
    return values, order
end

local function chooseMode()
    local values, order = { default = "Daylight default", custom = "Custom text color" }, { "default", "custom" }
    if selected() == "system" or status[selected()] then
        values.status = "Status colors"
        order[#order + 1] = "status"
    end
    return values, order
end

local function save(field, value)
    return DUI:Set(mod.name, root .. ".entries." .. entryID(selected()) .. "." .. field, value)
end

local function card()
    return { label = "Data text colors",
        desc = "These colors apply to the data bar and the minimap data texts.",
        items = {
            { type = "dropdown", key = root .. ".selected", label = "Data text to color", choices = chooseText },
            { type = "dropdown", key = root .. ".mode", label = "Color mode", choices = chooseMode,
                get = function() return modeOf(selected()) end,
                set = function(v) return save("mode", v) end,
                default = function() return "default" end },
            { type = "color", key = root .. ".custom", label = "Custom text color",
                hidden = function() return selected() == "system" or modeOf(selected()) ~= "custom" end,
                get = function()
                    local current = entry(selected())
                    return current and current.color or defaultColor
                end,
                set = function(v) return save("color", v) end,
                default = function() return defaultColor end },
            { type = "color", key = root .. ".fps", label = "FPS color",
                hidden = function() return selected() ~= "system" or modeOf("system") ~= "custom" end,
                get = function() local current = entry("system"); return current and current.color or defaultColor end,
                set = function(v) return save("color", v) end,
                default = function() return defaultColor end },
            { type = "color", key = root .. ".latency", label = "Latency color",
                hidden = function() return selected() ~= "system" or modeOf("system") ~= "custom" end,
                get = function() local current = entry("system"); return current and current.latency or defaultColor end,
                set = function(v) return save("latency", v) end,
                default = function() return defaultColor end },
            { type = "color", key = root .. ".good", label = "Good status color" },
            { type = "color", key = root .. ".medium", label = "Warning status color" },
            { type = "color", key = root .. ".bad", label = "Critical status color" },
        } }
end

local function redraw(keys)
    for _, strip in ipairs(DT.strips or {}) do strip.Update(false, keys) end
end

local onSetting = mod.OnSettingChanged
function mod.OnSettingChanged(self, path, ...)
    if path == root or (type(path) == "string" and path:match("^dataTextColors%.")) then return end
    if onSetting then return onSetting(self, path, ...) end
end

DUI.On("SettingChanged", function(scope, path)
    if scope ~= mod.name or type(path) ~= "string" then return end
    if path == root or path:match("^dataTextColors%.") then
        if path == root .. ".selected" then return end
        local id = path:match("^dataTextColors%.entries%.([^%.]+)")
        if path == root .. ".exactMoney" then
            redraw({ gold = true })
        elseif id then
            for _, key in ipairs(DT.ORDER) do
                if entryID(key) == id then redraw({ [key] = true }); break end
            end
        else
            redraw()
        end
    end
end)
DUI.On("Login", function() C_Timer.After(0, function() redraw() end) end)

function extras.DataTextColorPage()
    local group = card()
    local money = { label = "Gold", items = {
        { type = "toggle", key = root .. ".exactMoney", label = "Show exact money",
            desc = "Show gold, silver and copper when space permits. Hide copper, then silver in narrow slots; the tooltip keeps the exact amount." },
    } }
    for _, g in ipairs({ group, money }) do
        for _, row in ipairs(g.items) do
            if not row.get then
                local key = row.key
                row.default = function() return DUI.DB.GetPath(mod.defaults, key) end
                row.get = function()
                    local value = DUI:Get(mod.name, key)
                    if value == nil then return row.default() end
                    return value
                end
                row.set = function(v) return DUI:Set(mod.name, key, v) end
            end
        end
    end
    return extras.ShowDaylightRequirements({ id = "dataTextColors", label = "Data text colors", groups = { group, money } }, mod)
end

extras.Loaded("Databar")
