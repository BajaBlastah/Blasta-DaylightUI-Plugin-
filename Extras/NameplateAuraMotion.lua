local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Nameplates")
local Auras = ns and ns.Auras
if not (Auras and Auras.SetUnit and Auras.Layout and Auras.KINDS) then return end

local mod = DUI:GetModule("Nameplates")
local key = "blastaAuraMotion"
local rows = {
    { kind = "debuffs", anchor = "debuffs", label = "Nameplate debuffs" },
    { kind = "cc", anchor = "cc", label = "Nameplate crowd control" },
    { kind = "defensives", anchor = "defensives", label = "Nameplate defensives" },
    { kind = "buffs", anchor = "buffs", label = "Nameplate buffs" },
    { kind = "helps", anchor = "friendly.myBuffs", label = "Friendly nameplate buffs" },
}
local directions = { top = { 0, 1 }, bottom = { 0, -1 }, left = { -1, 0 }, right = { 1, 0 } }
local values = {
    off = "Off", zoom = "Grow and shrink", top = "Slide in from the top",
    bottom = "Slide in from the bottom", left = "Slide in from the left", right = "Slide in from the right",
}
local function settingKey(kind) return key .. "_" .. kind end
local function route(label) return { page = "Auras", tab = "Nameplates", label = label } end
local preview
mod.defaults[key] = false
for _, row in ipairs(rows) do mod.defaults[settingKey(row.kind)] = "zoom" end

-- Blasta's own nameplate aura switches get a card of their own on DaylightUI's
-- Nameplates > Auras page; each row's animation sits beside that row's size.
local SIZE_ANCHOR = { debuffs = "debuffSize", cc = "ccSize", defensives = "defensiveSize", buffs = "buffSize" }
for _, page in ipairs(mod.options and mod.options.pages or {}) do
    if page.id == "auras" and page.groups then
        local card = extras.NameplateAuraCard
        if not card then
            card = { label = "Nameplate auras", items = {} }
            page.groups[#page.groups + 1] = card
            extras.NameplateAuraCard = card
        end
        local items = card.items
        items[#items + 1] = { type = "toggle", key = key, label = "Animate nameplate auras",
            desc = "Enable separate animation styles for each nameplate aura row." }
        for _, row in ipairs(rows) do
            local animation = { type = "dropdown", key = settingKey(row.kind), label = "Icon animation",
                desc = "Icons slide in from and out toward the chosen side.",
                values = values, order = { "off", "zoom", "top", "bottom", "left", "right" }, fallback = "zoom",
                disabled = function(get) return get(key) ~= true end }
            local anchor = SIZE_ANCHOR[row.kind] or row.anchor
            if extras.FindSetting(mod, anchor) then
                extras.AddSetting(mod, anchor, animation)
            else
                animation.label = row.label .. ": " .. animation.label
                items[#items + 1] = animation
            end
        end
        if Auras.ShowSample then
            items[#items + 1] = { type = "button", label = "Preview nameplate aura animations", text = "Preview",
                desc = "Plays the entrance animations on the visible nameplate preview icons.",
                disabled = function(get) return get(key) ~= true or not DUI.Motion.On() end,
                func = function() preview() end }
        end
        break
    end
end

local states = setmetatable({}, { __mode = "k" })
local units, pending = setmetatable({}, { __mode = "v" }), {}
local event = CreateFrame("Frame")
local modes, active, queued = {}, false
local IN, OUT = .20, .18
local function plain(value) return not issecretvalue or not issecretvalue(value) end

local function offset(mode, w, h)
    local dir = directions[mode]
    if not dir then return 0, 0 end
    return dir[1] * math.max(12, w * .8), dir[2] * math.max(12, h * .8)
end

local function entrance(frame, state)
    if state.intro then return state.intro end
    local group = frame:CreateAnimationGroup()
    local intro = { group = group }
    intro.jump = group:CreateAnimation("Translation")
    intro.jump:SetOrder(1)
    intro.jump:SetDuration(0)
    intro.hide = group:CreateAnimation("Alpha")
    intro.hide:SetOrder(1)
    intro.hide:SetDuration(0)
    intro.slide = group:CreateAnimation("Translation")
    intro.slide:SetOrder(2)
    intro.slide:SetSmoothing("OUT")
    intro.fade = group:CreateAnimation("Alpha")
    intro.fade:SetOrder(2)
    intro.scale = group:CreateAnimation("Scale")
    intro.scale:SetOrder(2)
    intro.scale:SetScaleTo(1, 1)
    intro.scale:SetSmoothing("OUT")
    state.intro = intro
    return intro
end

local function tune(intro, mode, w, h)
    if intro.mode == mode and intro.w == w and intro.h == h then return end
    intro.group:Stop()
    local slide = directions[mode] ~= nil
    local x, y = offset(mode, w, h)
    local alpha = slide and 0 or 1
    local scale = mode == "zoom" and .52 or 1
    intro.jump:SetOffset(x, y)
    intro.hide:SetFromAlpha(alpha)
    intro.hide:SetToAlpha(alpha)
    intro.slide:SetOffset(-x, -y)
    intro.slide:SetDuration(slide and IN or 0)
    intro.fade:SetFromAlpha(alpha)
    intro.fade:SetToAlpha(1)
    intro.fade:SetDuration(slide and IN * .8 or 0)
    intro.scale:SetScaleFrom(scale, scale)
    intro.scale:SetDuration(mode == "zoom" and IN or 0)
    intro.mode, intro.w, intro.h = mode, w, h
end

local function size(button)
    local w, h = button:GetSize()
    if plain(w) and plain(h) and w and h and w > 0 and h > 0 then return w, h end
    return 20, 20
end

local function hideGhost(state)
    if not state.ghost then return end
    state.ghost.out:Stop()
    state.ghost:Hide()
end

local function exit(plate, state, mode)
    local ghost = state.ghost
    if not ghost then
        local level = plate:GetFrameLevel()
        if not plain(level) then return end
        ghost = CreateFrame("Frame", nil, plate)
        ghost:SetFrameLevel(level + 15)
        ghost.icon = ghost:CreateTexture(nil, "ARTWORK")
        ghost.icon:SetAllPoints(ghost)
        DUI.Style.CropIcon(ghost.icon)
        ghost.out = ghost:CreateAnimationGroup()
        ghost.scale = ghost.out:CreateAnimation("Scale")
        ghost.scale:SetScaleFrom(1, 1)
        ghost.scale:SetSmoothing("IN")
        ghost.slide = ghost.out:CreateAnimation("Translation")
        ghost.slide:SetSmoothing("IN")
        local fade = ghost.out:CreateAnimation("Alpha")
        fade:SetFromAlpha(.85)
        fade:SetToAlpha(0)
        fade:SetDuration(OUT)
        ghost.out:SetScript("OnFinished", function() ghost:Hide() end)
        state.ghost = ghost
    end
    ghost.out:Stop()
    local x, y = offset(mode, state.w, state.h)
    ghost.slide:SetOffset(x, y)
    ghost.slide:SetDuration(directions[mode] and OUT or 0)
    local scale = mode == "zoom" and .22 or 1
    ghost.scale:SetScaleTo(scale, scale)
    ghost.scale:SetDuration(mode == "zoom" and OUT or 0)
    ghost:ClearAllPoints()
    ghost:SetPoint("CENTER", plate, "CENTER", state.x, state.y)
    ghost:SetSize(state.w, state.h)
    ghost.icon:SetTexture(state.icon)
    ghost:Show()
    ghost.out:Play()
end

local function configure(button, state, mode)
    if not mode and not state.intro then return end
    local w, h = 20, 20
    if directions[mode] then w, h = size(button) end
    local intro = entrance(button, state)
    tune(intro, mode, w, h)
    if mode and not state.attempted then
        state.attempted = true
        local assign = button.AddAuraAssignedAnimation
        local add = assign or button.AddAuraShownAnimation
        -- The client can run its own assignment callback without exposing aura data.
        if add and pcall(add, button, intro.group) then
            state.remove = assign and "RemoveAuraAssignedAnimation" or "RemoveAuraShownAnimation"
        end
    elseif not mode and state.remove and type(button[state.remove]) == "function"
        and pcall(button[state.remove], button, intro.group) then
        state.remove, state.attempted = nil, nil
    end
    return intro
end

local function inspect(plate, button, container, kind, mode, px, py)
    local state = states[button]
    if not state then
        state = { kind = kind }
        states[button] = state
    end
    local registered = state.remove ~= nil
    local intro = configure(button, state, mode)
    local shown = button:IsShown()
    if not plain(shown) then state.icon = nil; return end
    if shown then
        if not state.shown then
            hideGhost(state)
            if not registered then intro.group:Play() end
        end
        local region = button.GetIcon and button:GetIcon()
        local icon = region and region:GetTexture()
        state.icon = nil
        if plain(icon) and (type(icon) == "number" or type(icon) == "string") then
            local x, y = button:GetCenter()
            local w, h = button:GetSize()
            if plain(x) and plain(y) and plain(px) and plain(py) and plain(w) and plain(h)
                and x and y and px and py and w and h and w > 0 and h > 0 then
                state.icon, state.x, state.y, state.w, state.h = icon, x - px, y - py, w, h
            end
        end
    elseif state.shown and state.icon then
        local visible = container:IsVisible()
        if plain(visible) and visible then exit(plate, state, mode) end
        state.icon = nil
    end
    state.shown = shown
end

local function flush()
    queued = nil
    for unit in pairs(pending) do
        pending[unit] = nil
        local plate = units[unit]
        if active and plate and plate:IsVisible() then
            local ok, px, py = pcall(plate.GetCenter, plate)
            if not ok then px, py = nil, nil end
            for kind, container in pairs(plate.auras or {}) do
                local mode = modes[kind]
                if mode then
                    for _, button in ipairs(container.buttons or {}) do
                        pcall(inspect, plate, button, container, kind, mode, px, py)
                    end
                end
            end
        end
    end
end

local function schedule(unit)
    if not active or not plain(unit) or not unit or not units[unit] then return end
    pending[unit] = true
    if not queued then queued = true; C_Timer.After(0, flush) end
end

local attached = setmetatable({}, { __mode = "k" })
hooksecurefunc(Auras, "SetUnit", function(plate, unit)
    if not plain(unit) then unit = nil end
    local previous = attached[plate]
    if previous and previous ~= unit then
        if units[previous] == plate then units[previous] = nil end
        for _, container in pairs(plate.auras or {}) do
            for _, button in ipairs(container.buttons or {}) do
                local state = states[button]
                if state then
                    state.shown, state.icon = nil, nil
                    hideGhost(state)
                end
            end
        end
    end
    attached[plate] = unit
    if unit then units[unit] = plate; schedule(unit) end
end)
hooksecurefunc(Auras, "Layout", function(plate) schedule(attached[plate]) end)
event:SetScript("OnEvent", function(_, _, unit) schedule(unit) end)

local samples, previews = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
if Auras.ShowSample then
    -- The row is stored on the sample plate; use the public return value.
    local showSample = Auras.ShowSample
    function Auras.ShowSample(plate, kind, ...)
        local row = showSample(plate, kind, ...)
        if row then samples[row] = kind end
        return row
    end
end

function preview()
    for row, kind in pairs(samples) do
        local mode = modes[kind]
        if mode and row:IsVisible() then
            for _, button in ipairs(row.icons or {}) do
                if button:IsShown() then
                    local state = previews[button] or {}
                    previews[button] = state
                    local intro = entrance(button, state)
                    tune(intro, mode, size(button))
                    intro.group:Stop()
                    intro.group:Play()
                end
            end
        end
    end
end

local function sync()
    local on = mod.db and mod.db[key] == true and DUI.Motion.On()
    local nextModes = {}
    for _, row in ipairs(rows) do
        local mode = on and mod.db[settingKey(row.kind)]
        if on and mode ~= "off" then
            nextModes[row.kind] = directions[mode] and mode or "zoom"
        end
    end
    local changed = false
    for _, row in ipairs(rows) do
        if modes[row.kind] ~= nextModes[row.kind] then changed = true; break end
    end
    if not changed then return end

    local previous = modes
    modes = nextModes
    active = next(modes) ~= nil
    if active then event:RegisterEvent("UNIT_AURA") else event:UnregisterEvent("UNIT_AURA") end
    for button, state in pairs(states) do
        local mode = modes[state.kind]
        if mode ~= previous[state.kind] then
            hideGhost(state)
            pcall(configure, button, state, mode)
            state.icon = nil
        end
    end
    for _, state in pairs(previews) do state.intro.group:Stop() end
    for unit in pairs(units) do schedule(unit) end
end
DUI.On("Login", sync)
DUI.On("StyleChanged", sync)
DUI.On("SettingChanged", function(scope, path)
    if path == "motion" or (scope == "Nameplates" and (path == key or type(path) == "string"
        and path:find(key .. "_", 1, true) == 1)) then sync() end
end)

extras.Loaded("NameplateAuraMotion")
