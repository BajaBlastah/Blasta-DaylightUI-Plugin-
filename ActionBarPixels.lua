local _, blasta = ...
local german = blasta.German
local DUI = DaylightUI
local module = DUI:GetModule("ActionBars")
local bars = module and module.ns and module.ns.Bars
local pixel = DUI.Pixel
if not (bars and pixel and type(bars.Grid) == "function" and type(bars.MoverKey) == "function"
    and type(bars.Config) == "function" and type(pixel.Unit) == "function") then return end

local card
for _, page in ipairs(module.options and module.options.pages or {}) do
    if page.id == "barlayout" then
        for _, group in ipairs(page.groups or {}) do
            if group.label == "Bars" and type(group.Picked) == "function" then card = group; break end
        end
        break
    end
end
if not (card and type(card.items) == "table") then return end

local defaults = module.defaults and module.defaults.bars
if type(defaults) ~= "table" then return end

local key = "pixelGrid"
local label = "Pixel-aligned buttons"
local desc = "Snaps buttons and gaps to screen pixels and centers shorter rows."
german[label] = "Buttons am Pixelraster ausrichten"
german[desc] = "Richtet Buttons und Abstände am Bildschirmraster aus und zentriert kürzere Reihen."

local definitions, moverBars, revealKeys = {}, {}, {}
for _, def in ipairs(bars.DEFS or {}) do
    if def.kind == "action" and type(defaults[def.key]) == "table" then
        local name = def.key
        local prefix = "bars." .. name .. "."
        defaults[name][key] = false
        definitions[name], moverBars[bars.MoverKey(def)] = def, name
        revealKeys[prefix .. key] = prefix .. "size"
        card.items[#card.items + 1] = {
            type = "toggle", key = prefix .. key, label = label, desc = desc, inPick = true,
            hidden = function() return card.Picked() ~= name end,
            disabled = function(get) return get(prefix .. "visible") == "hidden" end,
        }
    end
end
if type(card.reveal) == "function" then
    local reveal = card.reveal
    card.reveal = function(setting) return reveal(revealKeys[setting] or setting) end
end

local function layout(name)
    local def = definitions[name]
    if not def or InCombatLockdown() then return end
    local cfg = bars.Config(def)
    if not cfg then return end
    local holder, buttons = bars.holders[name], bars.buttons[name]
    local kind = bars.KINDS[def.kind]
    if not (holder and buttons and kind and kind.Base and kind.Count and not kind.Layout) then return end
    if not cfg[key] then return end
    local count = math.min(#buttons, kind.Count(def, cfg))
    if count < 1 then return end

    local one = pixel.Unit(holder)
    local base = kind.Base(def)
    local scale = cfg.size / 100
    local shape = module.ns.Shape
    local aspect = kind.Caps and kind.Caps.height and shape and shape.Tall and shape.Tall(cfg) or 1
    local buttonSize = math.max(one, pixel.Snap(holder, base * scale))
    local buttonHeight = math.max(one, pixel.Snap(holder, base * scale * aspect))
    local spacing = pixel.Snap(holder, cfg.pad)
    local pitchX = math.max(one, buttonSize + spacing)
    local pitchY = math.max(one, buttonHeight + spacing)
    scale = buttonSize / base
    local width, height, rows = 0, 0, {}
    for i = 1, count do
        local col, row = bars.Grid(i, count, cfg)
        rows[row] = math.max(rows[row] or 0, col + 1)
        width, height = math.max(width, col + 1), math.max(height, row + 1)
    end
    holder:SetSize(math.max(1, (width - 1) * pitchX + buttonSize), math.max(1, (height - 1) * pitchY + buttonHeight))

    -- Use the same physical pixel origin for each row of this holder.
    local corner = bars.Corner and bars.Corner(def, cfg) or (def.up and not cfg.vertical and "bottomleft" or "topleft")
    local up = corner:find("bottom", 1, true) ~= nil
    local right = corner:find("right", 1, true) ~= nil
    local anchor = corner:upper()
    local left = right and holder:GetRight() or holder:GetLeft()
    local vertical = up and holder:GetBottom() or holder:GetTop()
    local offsetX = left and pixel.Snap(holder, left) - left or 0
    local offsetY = vertical and pixel.Snap(holder, vertical) - vertical or 0
    for i = 1, count do
        local button = buttons[i]
        local col, row = bars.Grid(i, count, cfg)
        local indent = not cfg.vertical and pixel.Snap(holder, (width - rows[row]) * pitchX / 2) or 0
        local x = offsetX + (right and -1 or 1) * (indent + col * pitchX)
        local y = offsetY + (up and 1 or -1) * row * pitchY
        button:SetScale(scale)
        if shape and kind.Caps and kind.Caps.height then
            button:SetHeight(buttonHeight / scale)
            module.ns.Skin.SetAspect(button, buttonHeight / buttonSize)
        end
        button:ClearAllPoints()
        button:SetPoint(anchor, holder, anchor, x / scale, y / scale)
    end
end

DUI.On("ActionBarLaidOut", layout)
DUI.On("MoverApplied", function(mover)
    local name = moverBars[mover]
    local cfg = name and bars.Config(definitions[name])
    if cfg and cfg[key] then DUI.Fire("ActionBarLaidOut", name) end
end)
DUI.On("StyleChanged", function()
    DUI.AfterCombat(function()
        for name, def in pairs(definitions) do
            local cfg = bars.Config(def)
            if cfg and cfg[key] then DUI.Fire("ActionBarLaidOut", name) end
        end
    end, "daylight-addon-skins:pixel-grid")
end)

blasta.Loaded("ActionBarPixels")
