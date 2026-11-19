local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("UnitFrames")
local ns = mod and mod.ns
local Auras, Groups, Spots = ns and ns.Auras, ns and ns.AuraGroups, ns and ns.Spots
if not (Auras and Auras.Apply and Auras.Place and Auras.SetOwnSize and Auras.ShowSample
    and Auras.DrawSample and Groups and Groups.Box and Groups.Place and Spots and Spots.Layout) then return end

local MIN_SIZE, LEGACY_MAX, GROUP_MAX = 6, 36, 32
local function copy(source)
    local target = {}
    for key, value in pairs(source) do target[key] = value end
    return target
end

local function fitSize(width, perRow, gap, limit)
    -- Leave a fraction of a pixel for the client's wrap comparison.
    return math.max(MIN_SIZE, math.min(limit, (width - (perRow - 1) * gap - .001) / perRow))
end

local function horizontal(spot)
    return spot ~= "outleft" and spot ~= "outright"
end

local function fitKey(key)
    if type(key) ~= "string" then return end
    local prefix, kind = key:match("^([%w]+Auras)%.([%a]+)Size$")
    if prefix and (kind == "buff" or kind == "debuff") then return prefix .. "." .. kind .. "BlastaFit" end
    local group = key:match("^([%w]+%.auras%.[%w]+)%.size$")
    if group and not group:match("%.cc$") then return group .. ".blastaFit" end
end

for _, page in ipairs(mod.options and mod.options.pages or {}) do
    for _, group in ipairs(page.groups or {}) do
        for i = #group.items, 1, -1 do
            local size = group.items[i]
            local key = fitKey(size.key)
            if key then
                if DUI.DB.GetPath(mod.defaults, key) == nil then DUI.DB.SetPath(mod.defaults, key, false) end
                local row = {
                    type = "toggle", key = key, label = "Fit aura icons to frame width",
                    desc = "Uses the aura count, rows and spacing to size the icons. Rows above and below snap to the frame edges. Side positions use manual sizing.",
                    hidden = size.hidden, disabled = size.disabled, blastaJumpAnchor = size.key, blastaSince = "1.5",
                }
                if page.mapKey and key:match("^raid%.") then
                    local mapKey, locked = page.mapKey, page.locked
                    for _, raid in ipairs({ "raid20", "raid40" }) do
                        DUI.DB.SetPath(mod.defaults, key:gsub("^raid", raid), false)
                    end
                    local function get(path) return DUI:Get(mod.name, mapKey(path)) end
                    row.get = function() return get(key) end
                    row.set = function(value) return DUI:Set(mod.name, mapKey(key), value) end
                    row.default = function() return false end
                    row.hidden = size.hidden and function() return size.hidden(get) end
                    row.disabled = function()
                        return (locked and locked(key, row)) or (size.disabled and size.disabled(get)) or false
                    end
                end
                table.insert(group.items, i + 1, row)
            end
        end
    end
end

local configs = setmetatable({}, { __mode = "k" })
local apply = Auras.Apply
function Auras.Apply(set, cfg)
    if set then configs[set] = cfg end
    return apply(set, cfg)
end

local function auraCount(cfg, kind)
    if not cfg[kind .. "s"] then return 0 end
    if kind == "buff" then return tonumber(cfg.maxBuffs) or 0 end
    local others = cfg.debuffFilter == "all" and tonumber(cfg.maxOtherDebuffs) or 0
    return (tonumber(cfg.maxDebuffs) or 0) + (others or 0)
end

local function perRow(count, rows)
    return math.max(1, math.ceil(count / math.max(1, tonumber(rows) or 1)))
end

local function spansFrame(spot)
    return spot == "above" or spot == "below"
end

local function rowWidth(box, spot)
    return Spots.Layout(spot.spot, spot.grow, box, { line = box.w }).line
end

local function hasAuras(counts)
    if not counts then return false end
    for _, count in ipairs(counts) do
        if count > 0 then return true end
    end
    return false
end

-- Match the native Place call's own geometry, leaving other callers of Spots alone.
local layoutRow, frameBox = Spots.Layout, Groups.Box
local placement
function Groups.Box(frame, cfg)
    local box = frameBox(frame, cfg)
    if placement and placement.frame == frame then placement.box = box end
    return box
end

function Spots.Layout(spot, grow, box, opts)
    local layout = layoutRow(spot, grow, box, opts)
    if not placement or placement.box ~= box then return layout end
    local row = placement.rows[placement.next]
    if not row then return layout end
    placement.next = placement.next + 1
    if row.width then
        layout.line = row.width
        -- Centered on the frame, moved by a bar row's own left/right stretch.
        layout.x = row.shift or 0
    end
    return layout
end

local placeRows = Auras.Place
-- Shared, read-only lists. Placement runs whenever the shown auras change.
local AURA_KINDS, AURA_SETS = { "buff", "debuff" }, { "buffs", "debuffs" }
function Auras.Place(set, frame, frameCfg)
    local cfg = set and configs[set]
    if not cfg or not set.spots then return placeRows(set, frame, frameCfg) end
    local buff, debuff = set.spots.buff, set.spots.debuff
    local buffs, debuffs = auraCount(cfg, "buff"), auraCount(cfg, "debuff")
    local barWidth = extras.AuraBarWidth
    local buffBar = barWidth and barWidth(set.buffs)
    local debuffBar = barWidth and barWidth(set.debuffs)
    if buffBar or debuffBar then
        for _, kind in ipairs(AURA_KINDS) do
            local isBar = kind == "buff" and buffBar or kind == "debuff" and debuffBar
            if isBar and set.spots[kind] then
                local c = set[kind .. "s"]
                local spot = set.spots[kind]
                spot.spot = extras.AuraBarSpot(c, cfg[kind .. "Spot"])
                -- One column: centered on the frame. Several: rows start at a
                -- frame end (DaylightUI's grow direction), so a part-filled
                -- row lines up with the full ones instead of sitting centered.
                local cols = extras.AuraBarColumns and extras.AuraBarColumns(c) or 1
                spot.grow = cols > 1 and (cfg[kind .. "Grow"] == "left" and "left" or "right") or "center"
                spot.x = 0
            end
        end
        -- Bars side by side: fewer rows hold the same number of auras.
        local function barRows(c, count)
            local cols = extras.AuraBarColumns and extras.AuraBarColumns(c) or 1
            return math.max(1, math.ceil(count / cols))
        end
        set.rows = { buff = buffBar and barRows(set.buffs, buffs) or cfg.buffRows,
            debuff = debuffBar and barRows(set.debuffs, debuffs) or cfg.debuffRows }
    end
    local paired = set.buffs and set.want and hasAuras(set.want.buff) and hasAuras(set.want.debuff) and buff and debuff
        and buff.spot == debuff.spot and spansFrame(buff.spot)
        and buff.grow == "right" and debuff.grow == "left"
    if not paired and extras.IsUnitFramePreview(frame) then
        set.rows = {
            buff = buffBar and math.max(1, math.ceil(buffs / (extras.AuraBarColumns and extras.AuraBarColumns(set.buffs) or 1)))
                or not buffBar and cfg.buffBlastaFit == true and cfg.buffRows or buffs,
            debuff = debuffBar and math.max(1, math.ceil(debuffs / (extras.AuraBarColumns and extras.AuraBarColumns(set.debuffs) or 1)))
                or not debuffBar and cfg.debuffBlastaFit == true and cfg.debuffRows or debuffs,
        }
    end
    if not (buffBar or debuffBar or cfg.buffBlastaFit == true or cfg.debuffBlastaFit == true) then
        return placeRows(set, frame, frameCfg)
    end
    local box = frameBox(frame, frameCfg or set.frameCfg)
    local buffLine, sharedWidth
    if paired then
        local left = cfg.buffBlastaFit ~= true and box[buff.spot .. "InL"] or 0
        local right = cfg.debuffBlastaFit ~= true and box[buff.spot .. "InR"] or 0
        sharedWidth = box.w - left - right
        buffLine = math.max(1, math.floor(sharedWidth / 2) - Auras.GAP)
    end

    local rows = {}
    for _, kind in ipairs(AURA_KINDS) do
        local c, spot = set[kind .. "s"], set.spots[kind]
        local count = kind == "buff" and buffs or debuffs
        local manual = tonumber(cfg[kind .. "Size"]) or (kind == "buff" and 18 or 30)
        local size = manual
        local gap = tonumber(cfg[kind .. "Spacing"]) or Auras.SPACING[kind]
        local per = perRow(count, cfg[kind .. "Rows"])
        local row = {}
        if c and spot then rows[#rows + 1] = row end
        local width = kind == "buff" and buffBar or kind == "debuff" and debuffBar
        if width and c and spot then
            Auras.SetOwnSize(c, manual, gap)
            row.width = width
            row.shift = extras.AuraBarShift and extras.AuraBarShift(c, spot.grow) or 0
        elseif c and spot and count > 0 and cfg[kind .. "BlastaFit"] == true and horizontal(spot.spot) then
            local width = rowWidth(box, spot)
            if paired then width = kind == "buff" and buffLine or sharedWidth - buffLine - 2 * Auras.GAP end
            size = fitSize(width, per, gap, LEGACY_MAX)
            Auras.SetOwnSize(c, size, gap)
            if spansFrame(spot.spot) then row.width = math.max(size, width) end
        elseif c and cfg[kind .. "BlastaFit"] == true then
            Auras.SetOwnSize(c, manual, gap)
        end
        if paired and kind == "buff" then buffLine = math.min(buffLine, per * (size + gap) - gap) end
    end
    local previous = placement
    placement = { frame = frame, rows = rows, next = 1 }
    local ok, top, bottom = pcall(placeRows, set, frame, frameCfg)
    placement = previous
    if not ok then error(top, 0) end
    return top, bottom
end

local function fitGroup(group, box)
    if type(group) ~= "table" or group.blastaFit ~= true or group.show ~= true or not horizontal(group.spot) then return end
    local gap = tonumber(group.spacing) or 2
    local rows = math.max(1, tonumber(group.rows) or 1)
    local count = tonumber(group.max) or 0
    if count < 1 then return end
    local width = rowWidth(box, group)
    local effective = copy(group)
    effective.size = fitSize(width, perRow(count, rows), gap, GROUP_MAX)
    if spansFrame(group.spot) then
        local layout = layoutRow(group.spot, group.grow, box)
        effective.x = -layout.x
    end
    local room = math.max(1, math.floor((width + gap) / (effective.size + gap)))
    effective.max = math.min(count, room * rows)
    return effective
end

local function repeatSamples(list, count, filter)
    if not list or count <= #list and not filter then return list end
    local source = list
    if filter then
        source = {}
        for _, sample in ipairs(list) do
            if sample[filter] then source[#source + 1] = sample end
        end
    end
    if #source == 0 or count <= #source then return list end
    local result = {}
    for i = 1, count do result[i] = source[(i - 1) % #source + 1] end
    return result
end

local showRows = Auras.ShowSample
function Auras.ShowSample(set, frame, cfg, samples)
    if set and extras.IsUnitFramePreview(frame) then
        samples = copy(samples)
        samples.buffs = repeatSamples(samples.buffs, auraCount(cfg, "buff"), cfg.buffFilter == "purge" and "purge")
        samples.debuffs = repeatSamples(samples.debuffs, auraCount(cfg, "debuff"),
            set.side == "right" and cfg.debuffFilter == "dispel" and "cure")
        cfg = copy(cfg)
        cfg.buffRows, cfg.debuffRows = nil, nil
    end
    return showRows(set, frame, cfg, samples)
end

local previewCounts = setmetatable({}, { __mode = "k" })
function extras.AuraBarPreviewCount(container)
    return previewCounts[container]
end
local placeGroups = Groups.Place
function Groups.Place(set, frame, all, box)
    if not set or type(all) ~= "table" then return placeGroups(set, frame, all, box) end
    local config
    for key, group in pairs(all) do
        local effective = key ~= "cc" and fitGroup(group, box)
        if effective then
            config = config or copy(all)
            config[key] = effective
        end
    end
    placeGroups(set, frame, config or all, box)
    if not set.plain or not extras.IsUnitFramePreview(frame) then return end
    for _, key in ipairs(AURA_SETS) do
        local group = all[key]
        if set[key] then previewCounts[set[key]] = type(group) == "table" and tonumber(group.max) or nil end
    end
    for key, slot in pairs(set.extra or {}) do
        local group = all[key]
        for _, c in pairs(slot) do previewCounts[c] = type(group) == "table" and tonumber(group.max) or nil end
    end
end

local drawSample = Auras.DrawSample
function Auras.DrawSample(c, list, count, kind, flow)
    local wanted = previewCounts[c]
    if wanted and count > 0 and wanted > count then
        list, count = repeatSamples(list, wanted), wanted
    end
    return drawSample(c, list, count, kind, flow)
end

extras.Loaded("AuraFit")
