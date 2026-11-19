local _, blasta = ...
local DUI = DaylightUI
local craft = DUI.Craft
local window = craft and craft.Window
local data = craft and craft.Data
local win = DUI.Win
local feel = win and win.Feel
if not (window and window.Switch and window.Refill and window.Changed
    and window.TradeSkillShown and window.Settled and window.Refreshed and window.Close
    and data and data.Profession and data.Changing and feel and feel.Stagger) then return end

local pending, suppressStagger
local switch, refill, changed = window.Switch, window.Refill, window.Changed
local shown, settled, refreshed, close = window.TradeSkillShown, window.Settled, window.Refreshed, window.Close
local stagger = feel.Stagger
local open = window.Open

function feel.Stagger(pieces, delay)
    if not suppressStagger then return stagger(pieces, delay) end
end

local function withoutStagger(callback, ...)
    local previous = suppressStagger
    suppressStagger = true
    local ok, result = pcall(callback, ...)
    suppressStagger = previous
    if not ok then error(result, 0) end
    return result
end

-- The window itself still fades in. Its recipe rows should stay opaque even
-- when the trade skill events refill the list during that fade.
if type(open) == "function" then
    function window.Open(...)
        return withoutStagger(open, ...)
    end
end

function window.Refill(...)
    return withoutStagger(refill, ...)
end

local function finish()
    local game = window.Game()
    if not (pending and win.IsOpen(window.frame) and game and game:IsShown()) or data.Changing() then return end
    local profession = data.Profession()
    if not profession or profession.id ~= pending.id or window.PageFor(game) ~= "recipes" then return end
    pending = nil
    window.Refill()
end

function window.Switch(id)
    local profession = data.Profession()
    if not window.frame or not win.IsOpen(window.frame) or (profession and profession.id == id) then return switch(id) end
    local request = { id = id }
    pending = request
    -- The game can temporarily hide its source window or report the overview
    -- before the new recipe list arrives. Keep the current page during that gap.
    C_Timer.After(0.8, function()
        if pending ~= request then return end
        finish()
        if pending ~= request then return end
        pending = nil
        local game = window.Game()
        if not game or not game:IsShown() then
            changed("craft", false)
        elseif window.PageFor(game) ~= "recipes" then
            changed("craft", true)
        end
    end)
    switch(id)
    finish()
end

function window.Changed(kind, visible, away)
    if pending and not away then return finish() end
    if away then pending = nil end
    return changed(kind, visible, away)
end

function window.TradeSkillShown()
    if pending then return finish() end
    return shown()
end

function window.Settled()
    if pending then return finish() end
    return settled()
end

function window.Refreshed()
    if pending then return finish() end
    return refreshed()
end

function window.Close(...)
    pending = nil
    return close(...)
end

blasta.Loaded("ProfessionTabs")
