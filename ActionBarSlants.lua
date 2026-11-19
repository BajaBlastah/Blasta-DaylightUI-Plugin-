local ADDON, extras = ...
local Edges = extras.Edges
local DUI = DaylightUI
local module = DUI:GetModule("ActionBars")
local units = DUI:GetModule("UnitFrames")
local uf = units and units.ns and units.ns.UF
local ns = module and module.ns
local bars, skin, style = ns and ns.Bars, ns and ns.Skin, DUI.Style
if not (bars and skin and type(bars.Grid) == "function" and type(bars.Config) == "function"
    and type(skin.GetParts) == "function" and type(style.Slant) == "function"
    and type(style.Clip) == "function" and type(style.LayoutSlant) == "function"
    and type(style.GetSlant) == "function" and type(skin.StyleSwipe) == "function") then return end

local card
for _, page in ipairs(module.options and module.options.pages or {}) do
    if page.id == "barlayout" then
        for _, group in ipairs(page.groups or {}) do
            if group.label == "Bars" and type(group.Picked) == "function" then card = group; break end
        end
        break
    end
end
local defaults = module.defaults and module.defaults.bars
if not (card and type(card.items) == "table" and type(defaults) == "table") then return end

local function oldEdges(cfg)
    local direction = cfg.slantButtonDirection == "reverse" and "top" or "bottom"
    return cfg.slantFirstButton == 1 and direction or "straight",
        cfg.slantLastButton == 1 and direction or "straight"
end

local actionBars = {}
for _, def in ipairs(bars.DEFS or {}) do
    if def.kind == "action" and defaults[def.key] then
        local key = def.key
        actionBars[key] = def
        local prefix = "bars." .. key .. "."
        for i, edge in ipairs({ { "edgeLeft", "Left edge direction" }, { "edgeRight", "Right edge direction" } }) do
            local row = Edges.Options(module, prefix .. edge[1], edge[2], function(reset)
                local cfg = reset and defaults[key] or bars.Config(def)
                return select(i, oldEdges(cfg))
            end, function(get) return get(prefix .. "visible") == "hidden" end)
            card.items[#card.items + 1] = row
        end
    end
end

local media = "Interface\\AddOns\\" .. ADDON .. "\\ActionBarMedia\\"
local desired = setmetatable({}, { __mode = "k" })
local barKeys = setmetatable({}, { __mode = "k" })
local leftEdge = setmetatable({}, { __mode = "k" })
local rightEdge = setmetatable({}, { __mode = "k" })
local applied = setmetatable({}, { __mode = "k" })
local swipeFiles = setmetatable({}, { __mode = "k" })
local cooldownKeys = { "cooldown", "Cooldown", "chargeCooldown", "lossOfControlCooldown" }
local textureGetters = { "GetHighlightTexture", "GetPushedTexture", "GetCheckedTexture" }
local function clipSwipe(cd, file)
    pcall(cd.SetSwipeTexture, cd, file)
    -- The client's edge and finish flash are separate from the swipe texture.
    if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, false) end
    if cd.SetDrawBling then pcall(cd.SetDrawBling, cd, false) end
end

local function setSwipe(button, side, keepNativeShape, left, right, cut)
    local file
    if side then
        -- Swipe textures follow the same angle as the square button mask.
        local slope = math.max(1, math.min(13, math.floor(32 * cut / button:GetWidth() + 0.5)))
        local variant = side
        if side == "both" and left ~= right then
            variant = left == "bottom" and "both-bottom-top" or "both-top-bottom"
        elseif left == "top" or right == "top" then
            variant = side .. "-reverse"
        end
        file = media .. "swipe-" .. variant .. "-" .. slope .. ".png"
    end
    local icon = skin.IconOf(button)
    for _, key in ipairs(cooldownKeys) do
        local cd = button[key]
        if cd and cd.SetSwipeTexture and (key ~= "Cooldown" or cd ~= button.cooldown) then
            local previous = swipeFiles[cd]
            if file and not keepNativeShape then
                if not previous then
                    local points = {}
                    for i = 1, cd:GetNumPoints() do points[i] = { cd:GetPoint(i) } end
                    previous = { points = points }
                    swipeFiles[cd] = previous
                end
                previous.file = file
                if icon then
                    cd:ClearAllPoints()
                    cd:SetAllPoints(icon)
                end
                clipSwipe(cd, file)
            elseif previous then
                swipeFiles[cd] = nil
                cd:ClearAllPoints()
                for _, point in ipairs(previous.points) do cd:SetPoint(unpack(point)) end
                skin.StyleSwipe(cd, skin.LookFor(barKeys[button]))
            end
        end
    end
end

local function dress(button, afterSkin)
    local side, state = desired[button], applied[button]
    if not side and not state then return end
    local parts = skin.GetParts(button)
    if not (parts and parts.back) then return end
    if parts.shape then side = nil end
    if not side then
        if state and state.side then
            state.side, state.cut = nil, nil
            Edges.Clear(button)
            style.Slant(button, nil, 0)
            setSwipe(button, nil, parts.shape)
        end
        return
    end
    local angle = uf and uf.SLANT or 0.21
    local cut = DUI.Pixel.Snap(button, button:GetHeight() * angle)
    if cut <= 0 then return end
    if not state then
        state = { textures = {} }
        applied[button] = state
    end
    local left, right = leftEdge[button], rightEdge[button]
    local width = button:GetWidth()
    local changed = state.side ~= side or state.cut ~= cut or state.left ~= left or state.right ~= right
        or state.width ~= width
    if changed then
        state.side, state.cut, state.left, state.right, state.width = side, cut, left, right, width
        Edges.Apply(button, left, right, cut)
    end

    if changed or afterSkin then
        local added = false
        local function clip(tex)
            if tex and tex.AddMaskTexture and not state.textures[tex] then
                style.Clip(button, tex, "inner")
                state.textures[tex], added = true, true
            end
        end
        clip(skin.IconOf(button))
        clip(parts.shade)
        clip(parts.press)
        clip(parts.back.lit)
        for _, getter in ipairs(textureGetters) do
            if button[getter] then clip(button[getter](button)) end
        end
        if added then style.LayoutSlant(button) end
        setSwipe(button, side, nil, left, right, cut)
    end
end

DUI.On("ActionBarLaidOut", function(key)
    local def, list = actionBars[key], bars.buttons[key]
    if not (def and list) then return end
    local cfg = bars.Config(def)
    local left, right = Edges.Read(cfg, "edgeLeft", "edgeRight", oldEdges(cfg))
    local first, last = left ~= "straight", right ~= "straight"
    local count = (first or last) and math.min(#list, bars.KINDS.action.Count(def, cfg)) or 0
    local ends = {}
    for i = 1, count do
        local col, row = bars.Grid(i, count, cfg)
        local lane = cfg.vertical and col or row
        local edge = ends[lane]
        if edge then edge.last = i else ends[lane] = { first = i, last = i } end
    end
    for i, button in ipairs(list) do
        local side
        if i <= count then
            local col, row = bars.Grid(i, count, cfg)
            local edge = ends[cfg.vertical and col or row]
            local l, r = first and i == edge.first, last and i == edge.last
            side = l and (r and "both" or "left") or (r and "right" or nil)
        end
        desired[button], barKeys[button] = side, key
        leftEdge[button] = (side == "left" or side == "both") and left or "straight"
        rightEdge[button] = (side == "right" or side == "both") and right or "straight"
        dress(button, false)
    end
end)

hooksecurefunc(skin, "Apply", function(button) dress(button, true) end)
hooksecurefunc(skin, "StyleSwipe", function(cd)
    local state = swipeFiles[cd]
    if state then clipSwipe(cd, state.file) end
end)
DUI.On("SettingChanged", function(scope, key)
    if scope == "UnitFrames" and key == "look.slant" then
        DUI.AfterCombat(bars.Relayout, "daylight-addon-skins:action-bar-slants")
    end
end)

extras.Loaded("ActionBarSlants")
