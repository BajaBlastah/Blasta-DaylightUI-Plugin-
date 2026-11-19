local _, blasta = ...
local german = blasta.German
local DUI = DaylightUI
if type(UnitChannelInfo) ~= "function" then return end

local label = "Channel tick markers"
local desc = "Shows thin lines at the expected ticks of known channeled spells."
german[label] = "Kanal-Ticks anzeigen"
german[desc] = "Zeigt bei bekannten kanalisierten Zaubern dünne Linien an den erwarteten Ticks."

local function addOption(module, pageID, groupLabel)
    if not (module and type(module.defaults) == "table") then return end
    for _, page in ipairs(module.options and module.options.pages or {}) do
        if page.id == pageID then
            for _, group in ipairs(page.groups or {}) do
                if group.label == groupLabel and type(group.items) == "table" then
                    module.defaults.channelTickMarks = false
                    group.items[#group.items + 1] = {
                        type = "toggle", key = "channelTickMarks", label = label, desc = desc,
                    }
                    return true
                end
            end
            return
        end
    end
end

-- Classic spell families with regular ticks. Arcane Missiles uses explicit
-- rank IDs because early ranks fire fewer missiles.
local families = {
    [10] = 8, [136] = 5, [689] = 5, [740] = 5, [755] = 10, [1120] = 5,
    [1510] = 6, [1949] = 15, [5138] = 5, [5740] = 4, [10797] = 6,
    [15407] = 3, [16914] = 10,
}
local missiles = {
    [5143] = 3, [5144] = 4, [5145] = 5, [8416] = 5, [8417] = 5,
    [10211] = 5, [10212] = 5, [25345] = 5,
}
local names
local function known(value)
    return not issecretvalue or not issecretvalue(value)
end
local function tickCount(unit)
    if type(unit) ~= "string" or not known(unit) then return end
    local name, _, _, _, _, tradeskill, _, spell, empowered = UnitChannelInfo(unit)
    if not (known(spell) and known(tradeskill) and known(empowered))
        or type(spell) ~= "number" or tradeskill == true or empowered == true then return end
    local count = missiles[spell] or families[spell]
    if count then return count end
    if not known(name) or type(name) ~= "string" then return end
    if not names then
        names = {}
        local getName = C_Spell and C_Spell.GetSpellName or GetSpellInfo
        if type(getName) == "function" then
            for id, ticks in pairs(families) do
                local familyName = getName(id)
                if type(familyName) == "string" then names[familyName] = ticks end
            end
        end
    end
    return names[name]
end

local marks = setmetatable({}, { __mode = "k" })
local function draw(holder, count)
    local state = marks[holder]
    if not count or count < 2 then
        if state and state.count then
            for _, line in ipairs(state.lines) do line:Hide() end
            state.count = nil
        end
        return
    end
    local bar = holder.bar
    if not (bar and bar.CreateTexture) then return end
    local width = bar:GetWidth()
    if not known(width) or type(width) ~= "number" or width <= 0 then return end
    local pixel = DUI.Pixel.Px(bar, 1)
    if state and state.count == count and state.width == width and state.pixel == pixel then return end
    if not state then
        state = { lines = {} }
        marks[holder] = state
    end
    state.count, state.width, state.pixel = count, width, pixel
    for i = 1, count - 1 do
        local line = state.lines[i]
        if not line then
            line = bar:CreateTexture(nil, "OVERLAY", nil, 2)
            line:SetColorTexture(0, 0, 0, 0.72)
            state.lines[i] = line
        end
        local offset = DUI.Pixel.Snap(bar, width * i / count)
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", bar, "TOPLEFT", offset, -pixel)
        line:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", offset, pixel)
        line:SetWidth(pixel)
        line:Show()
    end
    for i = count, #state.lines do state.lines[i]:Hide() end
end

local function enabled(module)
    return module.db and module.db.channelTickMarks == true
end
local function relayout(holder)
    local state = marks[holder]
    if state then draw(holder, state.count) end
end

local units = DUI:GetModule("UnitFrames")
local cb = units and units.ns and units.ns.CastBar
if cb and type(cb.Refresh) == "function" and addOption(units, "castbars", "Player cast bar") then
    -- This setting is shared by all bars using the unit-frame cast engine.
    hooksecurefunc(cb, "Refresh", function(holder)
        draw(holder, enabled(units) and holder.channel and holder.duration and not holder.test and tickCount(holder.unit) or nil)
    end)
    if type(cb.Layout) == "function" then hooksecurefunc(cb, "Layout", relayout) end
    for _, name in ipairs({ "Stop", "Interrupted", "ShowSample" }) do
        if type(cb[name]) == "function" then hooksecurefunc(cb, name, function(holder) draw(holder) end) end
    end
end

local plates = DUI:GetModule("Nameplates")
local cast = plates and plates.ns and plates.ns.Cast
if cast and type(cast.Update) == "function" and addOption(plates, "cast", "Cast bar") then
    hooksecurefunc(cast, "Update", function(plate)
        local holder = plate.cast
        if holder then
            draw(holder, enabled(plates) and holder.duration and not plate.friendly and tickCount(plate.unit) or nil)
        end
    end)
    if type(cast.Layout) == "function" then
        hooksecurefunc(cast, "Layout", function(plate) if plate.cast then relayout(plate.cast) end end)
    end
    for _, name in ipairs({ "Stop", "Forget", "Interrupted", "ShowSample" }) do
        if type(cast[name]) == "function" then
            hooksecurefunc(cast, name, function(plate) if plate.cast then draw(plate.cast) end end)
        end
    end
end

blasta.Loaded("ChannelTicks")
