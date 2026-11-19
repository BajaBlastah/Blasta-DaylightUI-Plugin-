local _, extras = ...
local DUI = DaylightUI
local units = extras.Compatible("UnitFrames")
local swing = units and units.Swing
if not (swing and swing.Layout and swing.UpdateShown and swing.Place and swing.PlaceTimes) then return end

local mod = DUI:GetModule("UnitFrames")
local defaults = mod.defaults.swing
if not defaults then return end

local offsets = {}
for _, field in ipairs({ "nameX", "nameY", "timeX", "timeY" }) do
    offsets[field] = not extras.HasSetting(mod, "swing." .. field)
end
local function offset(cfg, field)
    return offsets[field] and cfg[field] or 0
end
local anchor = "swing.enabled"
local nativeHide = extras.HasSetting(mod, "swing.hideDuringCast")
if not nativeHide then
    defaults.hideDuringCast = true
    extras.AddSetting(mod, anchor, {
        type = "toggle", key = "swing.hideDuringCast", label = "Retract swing timer while casting",
        desc = "Starts retracting the swing timer as soon as the player cast bar appears. Not while your cast bar sits between your frame and the target's: there the swing timers fan out under it.",
        disabled = function(get) return get("swing.enabled") ~= true end,
    })
    anchor = "swing.hideDuringCast"
end
anchor = extras.AddBarTextOffsets(mod, "swing", anchor, "Swing name left / right", "Swing name up / down")
extras.AddBarTextSizes(mod, "swing", anchor, "Swing name text size", "Swing time text size")

-- Both callbacks run directly after Daylight has rebuilt the relevant anchor.
hooksecurefunc(swing, "Place", function(holder)
    local cfg = holder and holder.cfg
    if not cfg then return end
    for _, row in ipairs(holder.rows) do
        extras.OffsetBarText(row.label, offset(cfg, "nameX"), offset(cfg, "nameY"))
    end
end)

hooksecurefunc(swing, "PlaceTimes", function(holder)
    local cfg = holder and holder.cfg
    if not cfg then return end
    for _, row in ipairs(holder.rows) do
        extras.OffsetBarText(row.time, offset(cfg, "timeX"), offset(cfg, "timeY"))
    end
end)

local settling = setmetatable({}, { __mode = "k" })
local function number(value)
    return type(value) == "number" and not (issecretvalue and issecretvalue(value))
end

local function settleHiddenRows(holder)
    local now = GetTime()
    for _, row in ipairs(holder.rows) do
        local update = row.GetScript and row:GetScript("OnUpdate")
        local held = row.held
        if update and not row:IsVisible() and not (issecretvalue and issecretvalue(held)) and not held then
            local grace, start, duration = row.graceUntil, row.start, row.dur
            if number(grace) and grace <= now then
                update(row, 0)
            elseif not (issecretvalue and issecretvalue(grace)) and grace == nil
                and number(start) and number(duration) and start + duration <= now then
                -- Hidden rows don't tick. Let Daylight clear the expired swing
                -- without starting a fresh grace period for a swing nobody saw.
                row.graceUntil = now
                update(row, 0)
            end
        end
    end
end

local function retractDuringCast(updateShown, holder)
    local cast = holder and holder.castbar
    -- With the cast bar between the frames, DaylightUI fans the swing timers
    -- out under it while casting: retracting them would undo that.
    if not (cast and not holder.fan and holder.enabled and holder.cfg and holder.cfg.hideDuringCast ~= false
        and not holder.test and cast.enabled
        and (cast:IsShown() or (settling[holder] and settling[holder].cast == cast))) then
        return updateShown(holder)
    end

    -- Let the native sliders finish from their current position. Swing data
    -- and the native visibility rules take over again when the cast bar hides.
    for _, row in ipairs(holder.rows) do
        if row.alone and row.pod:IsShown() then row.pop:To(0) end
    end
    if holder:IsShown() then
        if (holder.column or holder.together or holder.fan) and holder:IsVisible() then
            holder.slide:To(0)
        else
            holder:Hide()
        end
    end
end
if not nativeHide then
    local updateShown = swing.UpdateShown
    function swing.UpdateShown(holder)
        return retractDuringCast(updateShown, holder)
    end
end

local listeners = setmetatable({}, { __mode = "k" })
hooksecurefunc(swing, "Layout", function(holder, cfg, cast)
    if holder and cfg then
        for _, row in ipairs(holder.rows) do
            extras.ApplyBarTextSizes(cfg, row.label, row.time)
        end
    end
    if nativeHide or not (holder and cast) then return end
    if listeners[cast] then
        listeners[cast].holder = holder
        return
    end
    local listener = { holder = holder }
    listeners[cast] = listener
    local function sync()
        local current = listener.holder
        if current.castbar == cast then swing.UpdateShown(current) end
    end
    cast:HookScript("OnShow", function()
        settling[listener.holder] = nil
        sync()
    end)
    cast:HookScript("OnHide", function()
        local current = listener.holder
        if current.castbar ~= cast then return end
        if not current.cfg or current.cfg.hideDuringCast == false or current.test or not cast.enabled then
            return sync()
        end
        -- The swing state can settle a tick after the cast bar hides.
        local pending = { cast = cast }
        settling[current] = pending
        C_Timer.After(0.12, function()
            if settling[current] ~= pending then return end
            if current.castbar == cast and current.enabled and not current.test and not cast:IsShown()
                and current.cfg and current.cfg.hideDuringCast ~= false then
                settleHiddenRows(current)
            end
            settling[current] = nil
            if current.castbar == cast then swing.UpdateShown(current) end
        end)
    end)
end)

extras.Loaded("SwingTimer")
