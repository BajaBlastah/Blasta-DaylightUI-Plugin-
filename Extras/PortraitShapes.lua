local ADDON, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("UnitFrames")
local UF = ns and ns.UF
if not (UF and UF.LayoutPortrait and UF.PaintRing and UF.RingFiles) then return end

local mod = DUI:GetModule("UnitFrames")
local nativeShape = extras.HasSetting(mod, "player.portraitShape")
local values = {
    round = nativeShape and "Use DaylightUI's portrait shape" or "Round", rounded = "Rounded square",
    diamond = "Diamond", hexagon = "Hexagon", octagon = "Octagon",
}
local order = { "round" }
local replacements = {}
local nativeShapes = nativeShape and UF.PORTRAIT_SHAPES or {}
for _, shape in ipairs({
    { "square", "Square", "square" },
    { "slanted", "Parallelogram", "angled" },
}) do
    if nativeShapes[shape[3]] then
        replacements[shape[1]] = shape[3]
    else
        values[shape[1]] = shape[2]
        order[#order + 1] = shape[1]
    end
end
for _, shape in ipairs({ "rounded", "diamond", "hexagon", "octagon" }) do
    order[#order + 1] = shape
end
local supported = {}
for _, unit in ipairs({ "player", "target", "focus", "party" }) do
    if mod.defaults[unit] and extras.FindSetting(mod, unit .. ".portrait") then
        supported[unit] = true
    end
end
if not (supported.player and mod.defaults.portraits) then return end
local key = "blastaPortraitShape"
mod.defaults.portraits[key] = "round"
function extras.MigratePortraitShape(profile)
    local db = profile.modules and profile.modules.UnitFrames
    if type(db) ~= "table" then return end
    local player = type(db.player) == "table" and db.player or nil
    local previous = player and player[key]
    if values[previous] or replacements[previous] then
        if type(db.portraits) ~= "table" then db.portraits = {} end
        if db.portraits[key] == nil then db.portraits[key] = previous end
    end
    local looks = type(db.portraits) == "table" and db.portraits or nil
    -- Remove saved settings from the retired experimental portrait display.
    if looks then
        looks.blastaPortraitInBar = nil
        looks.blastaPortraitInBarOpacity = nil
        if looks[key] ~= nil and not values[looks[key]] and not replacements[looks[key]] then looks[key] = nil end
    end
    local replacement = looks and replacements[looks[key]]
    for unit in pairs(supported) do
        local settings = type(db[unit]) == "table" and db[unit] or nil
        if settings then settings[key] = nil end
        if replacement then
            local defaults = mod.defaults[unit]
            local mode = settings and settings.portrait or defaults.portrait
            local shape = settings and settings.portraitShape or defaults.portraitShape
            if (mode == "2d" or mode == "class") and (shape == nil or shape == "round") then
                if not settings then
                    settings = {}
                    db[unit] = settings
                end
                settings.portraitShape = replacement
            end
        end
    end
    if replacement then looks[key] = nil end
end
extras.AddSetting(mod, "player.portrait", {
    type = "dropdown", key = "portraits." .. key, label = "Global portrait shape", values = values, order = order,
    desc = "Applies to 2D portraits and class icons on player, target, focus and party frames. A square or angled shape selected in DaylightUI takes priority.",
    disabled = function(get)
        for unit in pairs(supported) do
            if get(unit .. ".enabled") ~= false then
                local mode = get(unit .. ".portrait")
                if mode == "2d" or mode == "class" then return false end
            end
        end
        return true
    end,
})

local media = "Interface\\AddOns\\" .. ADDON .. "\\Media\\PortraitShapes\\"
local disc = DUI.MEDIA .. "crest-disc.png"
local applied = setmetatable({}, { __mode = "k" })
local dragonMasks = setmetatable({}, { __mode = "k" })
hooksecurefunc(UF, "LayoutPortrait", function(frame, cfg)
    local p = frame.portrait
    local unit = frame.spec and (frame.spec.group or frame.spec.unit)
    if not (supported[unit] and p and p.mask and p.disc) then return end
    local looks = mod.db and mod.db.portraits
    local shape = looks and looks[key]
    if not (values[shape] and shape ~= "round" and p:IsShown() and not p.shapeArt
        and (frame.portraitMode == "2d" or frame.portraitMode == "class")) then
        if applied[p] then
            if dragonMasks[p] then p.elite:RemoveMaskTexture(dragonMasks[p]) end
            applied[p] = nil
            if not nativeShape then
                p.mask:SetTexture(disc, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                p.disc:SetTexture(disc)
                UF.PaintRing(frame)
            end
        end
        return
    end

    if nativeShape or applied[p] ~= shape then
        local mask = media .. shape .. "-mask.png"
        p.mask:SetTexture(mask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        p.disc:SetTexture(mask)
        if not applied[p] and p.elite and p.elite.AddMaskTexture and p.elite.RemoveMaskTexture
            and p.top and p.top.CreateMaskTexture then
            local cut = dragonMasks[p]
            if not cut then
                cut = p.top:CreateMaskTexture()
                cut:SetAllPoints(p.elite)
                cut:SetTexture(media .. "dragon-rim-cut.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                dragonMasks[p] = cut
            end
            p.elite:AddMaskTexture(cut)
        end
        applied[p] = shape
    end
    local width, line
    if nativeShape then
        width, line = cfg.portraitRingWidth, cfg.portraitRingLine
    else
        width, line = looks.ringWidth, looks.ringLine
    end
    if width ~= "thin" and width ~= "thick" then width = "normal" end
    local band = media .. shape .. "-" .. width
    if line == false then band = band .. "-smooth" end
    frame.ringFile, frame.ringLitFile = band .. ".png", band .. "-lit.png"
    UF.PaintRing(frame)
end)

extras.Loaded("PortraitShapes")
