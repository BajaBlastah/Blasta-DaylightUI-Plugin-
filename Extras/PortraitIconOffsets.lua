local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("UnitFrames")
local UF = mod and mod.ns and mod.ns.UF
if not (UF and UF.LayoutStatus and UF.UpdateStatus) then return end

local icons = {
    { icon = "leader", show = "showLeader", native = "leader", field = "blastaLeader",
        horizontal = "Leader crown left / right", vertical = "Leader crown up / down" },
    { icon = "pvp", show = "showPvP", native = "pvp", field = "blastaPvP",
        horizontal = "PvP flag left / right", vertical = "PvP flag up / down" },
    { icon = "rest", show = "showResting", native = "rest", field = "blastaRest",
        horizontal = "Resting icon left / right", vertical = "Resting icon up / down" },
}

local byUnit = {}
for _, unit in ipairs({ "player", "target", "focus", "party", "raid", "raid20", "raid40", "arena" }) do
    local defaults = mod.defaults[unit]
    if defaults then
        local prefix = unit .. "."
        for _, spec in ipairs(icons) do
            local toggle = extras.FindSetting(mod, prefix .. spec.show)
            local size = extras.FindSetting(mod, prefix .. spec.native .. "Size")
            if toggle and size then
                local fields = { icon = spec.icon, show = spec.show }
                local function disabled(get)
                    return get(toggle.key) == false or (toggle.disabled and toggle.disabled(get)) or false
                end
                for _, axis in ipairs({ "Y", "X" }) do
                    if not extras.HasSetting(mod, prefix .. spec.native .. axis) then
                        local field = spec.field .. axis
                        fields[axis] = field
                        defaults[field] = 0
                        extras.AddSetting(mod, size.key, {
                            type = "slider", key = prefix .. field, min = -50, max = 50, step = 1, unit = "px",
                            label = axis == "X" and spec.horizontal or spec.vertical,
                            blastaSince = "1.5",
                            desc = "Moves this icon from its DaylightUI position. 0 uses the default offset.",
                            disabled = disabled,
                        })
                    end
                end
                if fields.X or fields.Y then
                    byUnit[unit] = byUnit[unit] or {}
                    table.insert(byUnit[unit], fields)
                end
            end
        end
    end
end

local function fieldsFor(frame)
    local spec = frame.spec
    local unit = spec and (spec.group or spec.unit)
    if type(unit) == "string" and unit:match("^arena%d+$") then unit = "arena" end
    return byUnit[unit]
end

hooksecurefunc(UF, "LayoutStatus", function(frame, cfg)
    local fields = fieldsFor(frame)
    if not (fields and frame.status) then return end
    for _, entry in ipairs(fields) do
        local icon = frame.status.icons[entry.icon]
        local dx = entry.X and tonumber(cfg[entry.X]) or 0
        local dy = entry.Y and tonumber(cfg[entry.Y]) or 0
        if icon and (dx ~= 0 or dy ~= 0) then
            local point, anchor, relativePoint, x, y = icon:GetPoint()
            if point then icon:SetPoint(point, anchor, relativePoint, x + dx, y + dy) end
        end
    end
end)

hooksecurefunc(UF, "UpdateStatus", function(frame, sample)
    local fields = sample and fieldsFor(frame)
    if not (fields and frame.status and not frame.cornerMode) then return end
    if not extras.IsUnitFramePreview(frame) then return end

    for _, entry in ipairs(fields) do
        local icon = frame.status.icons[entry.icon]
        if icon and frame[entry.show] and (entry.icon ~= "leader" or not frame.leaderSpot) then
            DUI.Motion.AlphaTo(icon, 1, 0)
        end
    end
end)

extras.Loaded("PortraitIconOffsets")
