local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("UnitFrames")
local UF = mod and mod.ns and mod.ns.UF
if not (UF and UF.LayoutStatus and UF.UpdateStatus) then return end
local Style = DUI.Style

local controls = {
    { field = "levelTextSize", default = 0, type = "slider", label = "Level text size",
        desc = "0 uses the automatic text size.", min = 0, max = 28, step = 1, unit = "px" },
    { field = "levelBadgeScale", default = 1, type = "slider", label = "Level circle size",
        min = 0.5, max = 2.5, step = 0.05, unit = "%" },
    { field = "levelBadge", default = true, type = "toggle", label = "Show level circle" },
    { field = "levelDifficultyColor", default = true, type = "toggle", label = "Level difficulty color" },
}
local byConfig = {}
for _, unit in ipairs({ "player", "target", "focus", "party", "arena" }) do
    local prefix = unit .. "."
    local position = extras.FindSetting(mod, prefix .. "levelPos")
    if position and mod.defaults[unit] then
        local supported = {}
        byConfig[unit] = supported
        for _, control in ipairs(controls) do
            local row = {}
            for key, value in pairs(control) do row[key] = value end
            row.key, row.disabled = prefix .. control.field, position.disabled
            row.field, row.default = nil, nil
            if not extras.HasSetting(mod, row.key) then
                supported[control.field] = true
                mod.defaults[unit][control.field] = control.default
                extras.AddSetting(mod, position.key, row, true)
            end
        end
        for axis, desc in pairs({ X = "Nudges the level badge sideways.", Y = "Nudges the level badge up or down." }) do
            local native, items = extras.FindSetting(mod, prefix .. "level" .. axis)
            if native then
                local row = {}
                for key, value in pairs(native) do row[key] = value end
                row.disabled, row.desc = position.disabled, desc
                items[#items + 1] = row
            end
        end
    end
end

local config = setmetatable({}, { __mode = "k" })
hooksecurefunc(UF, "LayoutStatus", function(frame, cfg)
    local st = frame.status
    local circle = st and st.icons.level
    if not circle then return end
    local unit = frame.group and frame.group.key or frame.spec and frame.spec.unit
    if type(unit) == "string" and unit:match("^arena%d+$") then unit = "arena" end
    local supported = byConfig[unit]
    if not supported then return end
    config[frame] = { cfg = cfg, supported = supported }
    local _, size = st.levelText:GetFont()
    local requested = supported.levelTextSize and tonumber(cfg.levelTextSize) or 0
    if requested > 0 then size = requested end
    if requested > 0 then Style.SetTextSize(st.levelText, requested) end
    local scale = supported.levelBadgeScale and tonumber(cfg.levelBadgeScale) or 1
    if size and size > 0 and (requested > 0 or scale ~= 1) then
        local diameter = math.max(circle:GetWidth(), size * 2 + 4) * scale
        circle:SetSize(diameter, diameter)
        st.skull:SetSize(diameter * UF.SKULL_SIZE, diameter * UF.SKULL_SIZE)
    end
    if not frame.levelSpot then
        local point, relative, at, x, y = circle:GetPoint()
        if point then
            circle:SetPoint(point, relative, at, x + (tonumber(cfg.levelX) or 0), y + (tonumber(cfg.levelY) or 0))
        end
    end
end)

hooksecurefunc(UF, "UpdateStatus", function(frame)
    local entry, st = config[frame], frame.status
    if not (entry and st) then return end
    local cfg, supported = entry.cfg, entry.supported
    if supported.levelBadge and cfg.levelBadge == false then st.icons.level:Hide() end
    if supported.levelDifficultyColor and cfg.levelDifficultyColor == false and st.levelText:IsShown() then
        st.levelText:SetTextColor(unpack(UF.LEVEL_SELF_COLOR))
    end
end)

extras.Loaded("LevelBadges")
