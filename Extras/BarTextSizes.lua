local _, extras = ...
local DUI = DaylightUI
local widgets, options = DUI.Widgets, DUI.Options

function extras.AddBarTextSizes(mod, prefix, anchor, nameLabel, timeLabel)
    for _, setting in ipairs({
        { "blastaNameSize", nameLabel },
        { "blastaTimeSize", timeLabel },
    }) do
        local field, label = setting[1], setting[2]
        local key = prefix .. "." .. field
        mod.defaults[prefix][field] = 0
        extras.AddSetting(mod, anchor, {
            type = "slider", key = key, label = label, min = 0, max = 24, step = 1,
            desc = prefix == "swing"
                and "0 uses DaylightUI's size for this bar (group or detached hand). A nonzero value replaces it for this text. Values 1–5 use 6."
                or "At 0, use DaylightUI's text size. Values below 6 use 6.",
            blastaCommitOnBlur = true,
            disabled = function(get) return get(prefix .. ".enabled") ~= true end,
        })
        anchor = key
    end
end

function extras.ApplyBarTextSizes(cfg, name, time)
    local nameSize, timeSize = cfg.blastaNameSize or 0, cfg.blastaTimeSize or 0
    if nameSize > 0 then DUI.Style.SetTextSize(name, math.max(6, nameSize)) end
    if timeSize > 0 then DUI.Style.SetTextSize(time, math.max(6, timeSize)) end
end

function extras.AddBarTextOffsets(mod, prefix, anchor, nameXLabel, nameYLabel)
    for _, setting in ipairs({
        { "nameX", nameXLabel }, { "nameY", nameYLabel },
        { "timeX", "Timer left / right" }, { "timeY", "Timer up / down" },
    }) do
        local field, label = setting[1], setting[2]
        local key = prefix .. "." .. field
        if not extras.HasSetting(mod, key) then
            mod.defaults[prefix][field] = 0
            extras.AddSetting(mod, anchor, {
                type = "slider", key = key, label = label, min = -40, max = 40, step = 1, unit = "px",
                blastaCommitOnBlur = true,
                disabled = function(get) return get(prefix .. ".enabled") ~= true end,
            })
            anchor = key
        end
    end
    return anchor
end

local function secret(value)
    return issecretvalue and issecretvalue(value)
end

function extras.OffsetBarText(text, x, y, index)
    if x == 0 and y == 0 then return end
    local point, relative, relativePoint, left, top = text:GetPoint(index or 1)
    if secret(point) or secret(relative) or secret(relativePoint) or secret(left) or secret(top) then return end
    if not (point and relative) then return end
    text:SetPoint(point, relative, relativePoint, (left or 0) + x, (top or 0) + y)
end

if widgets and widgets.slider and widgets.ParseValue and widgets.SnapValue and options then
    hooksecurefunc(widgets, "slider", function(row, page, item)
        local box = item.blastaCommitOnBlur and row.control and row.control.box
        if not box then return end
        local focusLost = box:GetScript("OnEditFocusLost")
        local cancel = false
        box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        box:SetScript("OnEscapePressed", function(self)
            cancel = true
            self:ClearFocus()
            cancel = false
        end)
        box:SetScript("OnEditFocusLost", function(self)
            local value = not cancel and not row.disabled and widgets.ParseValue(item, self:GetText())
            if focusLost then focusLost(self) end
            if value then
                value = widgets.SnapValue(item, value)
                if options.Get(page, item) ~= value then options.Set(page, item, value) end
            end
        end)
    end)
end

local units = extras.Compatible("UnitFrames")
local cast = units and units.CastBar
if not (cast and cast.Layout) then return end
local mod = DUI:GetModule("UnitFrames")

local castSettings = {}
for _, kind in ipairs({ "player", "target", "focus", "party" }) do
    local prefix = kind .. "Castbar"
    local defaults = mod.defaults[prefix]
    if defaults then
        local legacyOffsets = {}
        for _, field in ipairs({ "nameX", "nameY", "timeX", "timeY" }) do
            legacyOffsets[field] = not extras.HasSetting(mod, prefix .. "." .. field)
        end
        castSettings[kind] = { prefix = prefix, offsets = legacyOffsets }
        local anchor = prefix .. ".enabled"
        for _, suffix in ipairs({ ".textSize", ".time.y" }) do
            if extras.FindSetting(mod, prefix .. suffix) then
                anchor = prefix .. suffix
                break
            end
        end
        extras.AddBarTextSizes(mod, prefix, anchor, "Spell name text size", "Cast time text size")
        extras.AddBarTextOffsets(mod, prefix, prefix .. ".blastaTimeSize", "Spell name left / right", "Spell name up / down")
    end
end

if not next(castSettings) then return end
hooksecurefunc(cast, "Layout", function(bar, cfg)
    local settings = bar and castSettings[bar.kind]
    if not (settings and bar.text and bar.text.GetNumPoints and bar.text.GetPoint
        and bar.text.SetPoint and bar.time and bar.time.GetPoint and bar.time.SetPoint) then return end
    -- Daylight builds separate layout tables for the inside and outside variants of these bars.
    local profile = mod.db and mod.db[settings.prefix] or cfg
    if not profile then return end
    extras.ApplyBarTextSizes(profile, bar.text, bar.time)
    local function offset(field)
        return settings.offsets[field] and profile[field] or 0
    end
    local nameX, nameY, timeY = offset("nameX"), offset("nameY"), offset("timeY")
    extras.OffsetBarText(bar.time, offset("timeX"), timeY)
    for index = 1, bar.text:GetNumPoints() do
        local _, relative = bar.text:GetPoint(index)
        if not secret(relative) and relative == bar.time then
            extras.OffsetBarText(bar.text, 0, nameY - timeY, index)
        else
            extras.OffsetBarText(bar.text, nameX, nameY, index)
        end
    end
end)

extras.Loaded("BarTextSizes")
