local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Skins")
local mod = DUI:GetModule("Skins")
local card, kit = ns and ns.RollCard, ns and ns.Kit
local Style, Pixel = DUI.Style, DUI.Pixel
if not (mod and mod.defaults and card and card.Fill and kit and kit.ShellOf and Style and Style.LayoutShell and Pixel) then return end

local KEY = "blastaSquareRollIcon"
local anchor = "rolls.width"
if not extras.FindSetting(mod, anchor) then return end

mod.defaults[KEY] = false
extras.German["Square loot roll icon"] = "Quadratisches Würfel-Icon"
extras.German["Give the item icon square corners and a one-pixel quality border."] =
    "Zeigt das Beute-Icon mit eckigen Kanten und einem 1-Pixel-Rahmen in der Qualitätsfarbe."
local rollLabel = "Loot Roll Window"
extras.German[rollLabel] = "Würfelfenster"
for _, page in ipairs(mod.options and mod.options.pages or {}) do
    if page.id == "rolls" then
        page.groups[#page.groups + 1] = { label = rollLabel, blastaTab = rollLabel, items = {
            { type = "toggle", key = KEY, label = "Square loot roll icon", blastaSince = "1.9.4",
                desc = "Give the item icon square corners and a one-pixel quality border.",
                disabled = function(get) return get("rolls.enabled") == false end },
        } }
        break
    end
end

local icons = setmetatable({}, { __mode = "k" })
local function paint(icon, shell)
    local saved = icons[icon]
    local square = (mod.db or mod.defaults)[KEY] == true
    if not saved and not square then return end
    local edge = shell:GetParent()
    local inset = square and Pixel.Px(edge, 1)
    if square then
        if not saved then
            saved = { corner = shell.opts.cornerPx, border = shell.opts.borderPx, points = {} }
            for i = 1, edge:GetNumPoints() do saved.points[i] = { edge:GetPoint(i) } end
            icons[icon] = saved
        end
        if saved.inset == inset and shell.opts.cornerPx == 0 and shell.opts.borderPx == 1 then return end
        saved.inset = inset
        shell.opts.cornerPx, shell.opts.borderPx = 0, 1
        edge:ClearAllPoints()
        edge:SetPoint("TOPLEFT", icon, "TOPLEFT", -inset, inset)
        edge:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", inset, -inset)
    else
        shell.opts.cornerPx, shell.opts.borderPx = saved.corner, saved.border
        edge:ClearAllPoints()
        for _, point in ipairs(saved.points) do edge:SetPoint(unpack(point)) end
        icons[icon] = false
    end
    Style.LayoutShell(shell)
end

local CORNER_CUT = 12 -- Same bottom-right cut as BlastaTooltips.
local function shapeCard(frame)
    local shell = Style.GetShell and Style.GetShell(frame)
    if shell and shell.opts and Style.CutShell then
        local opts = shell.opts
        if opts.cornerPx ~= 0 or not opts.noBevel or not Style.GetCut or Style.GetCut(frame) ~= CORNER_CUT then
            opts.cornerPx, opts.noBevel = 0, true
            Style.CutShell(frame, CORNER_CUT)
            Style.LayoutShell(shell)
        end
    end
    local ticks, summary = frame.ticks, frame.sumBox
    if not (ticks and summary) or frame.blastaRollTickInset then return end
    local inset = (card.PAD or 8) + CORNER_CUT
    ticks:SetPoint("TOPRIGHT", summary, "TOPRIGHT", -inset, 0)
    ticks:SetPoint("BOTTOMRIGHT", summary, "BOTTOMRIGHT", -inset, 0)
    frame.blastaRollTickInset = true
end

-- The settings preview and the live roll stack render through the same card.
hooksecurefunc(card, "Fill", function(frame)
    local icon = frame.icon
    local shell = icon and kit.ShellOf(icon)
    if shell and shell.opts then
        if icons[icon] == nil then icons[icon] = false end
        paint(icon, shell)
    end
end)

-- The preview scales and places both cards after filling them. Apply the
-- shape once more to the actual cards returned by the preview factory.
local sample = ns.RollSample
if sample and sample.New then
    local new = sample.New
    function sample.New(...)
        local preview = new(...)
        if preview and preview.Refresh and preview.Parts then
            hooksecurefunc(preview, "Refresh", function()
                local seen = {}
                for _, part in ipairs(preview.Parts()) do
                    local frame = part.region
                    while frame and frame ~= preview.frame do
                        if frame.icon and frame.ticks and frame.sumBox then
                            if not seen[frame] then shapeCard(frame); seen[frame] = true end
                            break
                        end
                        frame = frame:GetParent()
                    end
                end
            end)
        end
        return preview
    end
end

local function refresh()
    for icon in pairs(icons) do
        local shell = kit.ShellOf(icon)
        if shell and shell.opts then paint(icon, shell) end
    end
    if ns.RollStack and ns.RollStack.Refresh then ns.RollStack.Refresh() end
end
DUI.On("SettingChanged", function(scope, key)
    if scope == mod.name and key == KEY then refresh() end
end)
DUI.On("StyleChanged", refresh)

extras.Loaded("LootRollIcon")
