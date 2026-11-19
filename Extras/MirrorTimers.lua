local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Skins")
local Breath = ns and ns.Breath
if not (Breath and Breath.holders and Breath.Sync) then return end

local mod = DUI:GetModule("Skins")
local Edges, Pixel, Style = extras.Edges, DUI.Pixel, DUI.Style
local function oldRight(db) return db.breathSlant == false and "straight" or "top" end
local function add(anchor, row)
    row.blastaRequires = "packs.system"
    extras.AddSetting(mod, anchor, row)
end
add("breathSlant", Edges.Options(mod, "mirrorLeft", "Left edge direction", function() return "straight" end))
add("mirrorLeft", Edges.Options(mod, "mirrorRight", "Right edge direction",
    function(reset) return oldRight(not reset and mod.db or mod.defaults) end))

local applied = setmetatable({}, { __mode = "k" })
local function apply(h)
    if not mod.db then return end
    local left, right, custom = Edges.Read(mod.db, "mirrorLeft", "mirrorRight", "straight", oldRight(mod.db))
    if not (custom or applied[h]) then return end
    local height = h:GetHeight()
    if height <= 0 then return end
    local border = Pixel.Px(h, Style.BorderPx(h))
    local cut = Pixel.Snap(h, height * Breath.SLANT)
    if custom then
        Edges.Apply(h, left, right, cut)
    else
        Edges.Clear(h)
        Style.Slant(h, right == "straight" and nil or "right", right == "straight" and 0 or cut)
    end
    applied[h] = custom or nil
    Edges.Fill(h.bar, "right", cut * math.max(0, height - 2 * border) / height, right)
end

local queued
local function refresh()
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = nil
        for _, h in pairs(Breath.holders) do apply(h) end
    end)
end
local seen = setmetatable({}, { __mode = "k" })
hooksecurefunc(Breath, "Sync", function(h)
    if not seen[h] then seen[h] = true; refresh() end
end)
DUI.On("StyleChanged", refresh)
DUI.On("SettingChanged", function(scope, path)
    if scope == "general" or (scope == "Skins" and (path == "breathSlant" or path == "mirrorLeft" or path == "mirrorRight")) then
        refresh()
    end
end)

extras.Loaded("MirrorTimers")
