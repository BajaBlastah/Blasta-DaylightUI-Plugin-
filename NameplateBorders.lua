local _, blasta = ...
local german = blasta.German
local DUI = DaylightUI
local module = DUI:GetModule("Nameplates")
local ns = module and module.ns
local pages = module and module.options and module.options.pages
local plate, cast = ns and ns.Plate, ns and ns.Cast
if not (plate and type(plate.BORDER) == "function" and cast
    and type(cast.Layout) == "function" and type(module.defaults) == "table") then return end

local groups
for _, page in ipairs(pages or {}) do
    if page.id == "plates" then groups = page.groups; break end
end
if not groups then return end

german["Health bar border thickness"] = "Randdicke der Gesundheitsleiste"
german["Cast bar border thickness"] = "Randdicke der Zauberleiste"
german["Border thickness in screen pixels. At 0, use DaylightUI's default."] =
    "Randdicke in Bildschirmpixeln. Bei 0 gilt die bisherige DaylightUI-Einstellung."

local function addBorderOption(key, label)
    module.defaults[key] = 0
    return {
        type = "slider", key = key, label = label, min = 0, max = 8, step = 1, unit = "px",
        desc = "Border thickness in screen pixels. At 0, use DaylightUI's default.",
    }
end

table.insert(groups, math.min(2, #groups + 1), {
    label = "Borders and shadows",
    items = {
        addBorderOption("healthBorderOverride", "Health bar border thickness"),
        addBorderOption("castBorderOverride", "Cast bar border thickness"),
    },
})

local function customWidth(key, height)
    local px = ns.cfg and tonumber(ns.cfg[key])
    if not px or px < 1 then return nil end
    local limit = type(height) == "number" and height > 0 and math.max(1, math.floor((height - 2) / 2)) or 8
    return math.min(math.floor(px), 8, limit)
end

local healthBorder = plate.BORDER
function plate.BORDER(px, height)
    return customWidth("healthBorderOverride", height) or healthBorder(px, height)
end

local layoutCast = cast.Layout
function cast.Layout(unitPlate, cut)
    local body = unitPlate.cast and unitPlate.cast.body
    if body and body.opts and ns.cfg then
        body.opts.borderPx = customWidth("castBorderOverride", ns.cfg.castHeight) or cast.BORDER
    end
    return layoutCast(unitPlate, cut)
end

-- The glow has its own frame, independent of the outline and threat glow.
if type(plate.UpdateTarget) ~= "function" then return end
for _, page in ipairs(pages) do
    if page.id == "target" then
        for _, group in ipairs(page.groups or {}) do
            if group.label == "Target highlight" and type(group.items) == "table" then
                module.defaults.targetGlowStrength = 1
                german["Target glow strength"] = "Stärke des Ziel-Glows"
                german["How strongly the target glow shines. At 100%, use DaylightUI's default strength."] =
                    "Stärke des Leuchtens am Ziel. 100 % entsprechen der bisherigen DaylightUI-Stärke."
                group.items[#group.items + 1] = {
                    type = "slider", key = "targetGlowStrength", label = "Target glow strength",
                    min = 0, max = 1, step = 0.05, unit = "%",
                    desc = "How strongly the target glow shines. At 100%, use DaylightUI's default strength.",
                    disabled = function(get) return get("targetStyle") ~= "glow" end,
                }
                hooksecurefunc(plate, "UpdateTarget", function(unitPlate)
                    if unitPlate.markStyle ~= "glow" then return end
                    local glow = unitPlate.glow
                    if not (glow and glow.pieces and plate.GLOW_ALPHA) then return end
                    local strength = math.max(0, math.min(1, tonumber(ns.cfg and ns.cfg.targetGlowStrength) or 1))
                    -- The ring frame's alpha belongs to its entrance/exit
                    -- animation. Scale the native opacity of its pieces.
                    local opacity = plate.GLOW_ALPHA * strength
                    for _, texture in pairs(glow.pieces) do
                        local r, g, b = texture:GetVertexColor()
                        texture:SetVertexColor(r, g, b, opacity)
                    end
                end)
                return
            end
        end
    end
end

blasta.Loaded("NameplateBorders")
