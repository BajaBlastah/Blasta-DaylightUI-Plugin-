local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("Tooltip")
local Tip = mod and mod.ns and mod.ns.Tooltip
if not (Tip and Tip.Shell and Tip.Skin and Tip.Build and Tip.Refresh and Tip.BORDER) then return end
if extras.HasSetting(mod, "borderPx") then return end

mod.defaults.borderPx = Tip.BORDER
local nativeBorder = Tip.BORDER
extras.AddSetting(mod, "bgAlpha", { key = "borderPx", type = "slider", label = "Tooltip border thickness",
    min = 1, max = 12, step = 1, unit = "px" }, true)

local seen = setmetatable({}, { __mode = "k" })
local Style = DUI.Style
local function applyBorder(tip)
    local shell = Tip.Shell(tip)
    if not shell then return end
    seen[tip] = true
    if shell.opts.borderPx ~= Tip.BORDER then
        shell.opts.borderPx = Tip.BORDER
        Style.LayoutShell(shell)
    end
    local header = tip.CompareHeader and Style.GetShell(tip.CompareHeader)
    if header and header.opts.borderPx ~= Tip.BORDER then
        header.opts.borderPx = Tip.BORDER
        header:SetPoint("BOTTOMLEFT", tip, "TOPLEFT", 0, -DUI.Pixel.Px(tip, Tip.BORDER))
        Style.LayoutShell(header)
    end
end

local function readBorder(module)
    Tip.BORDER = math.max(1, math.min(12, tonumber(module.db.borderPx) or nativeBorder))
end

local build, refresh = Tip.Build, Tip.Refresh
function Tip.Build(module, ...)
    readBorder(module)
    return build(module, ...)
end
function Tip.Refresh(module, ...)
    readBorder(module)
    refresh(module, ...)
    for tip in pairs(seen) do applyBorder(tip) end
end
hooksecurefunc(Tip, "Skin", applyBorder)

extras.Loaded("Tooltip")
