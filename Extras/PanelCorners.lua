local ADDON, extras = ...
local DUI = DaylightUI
local Style, Pixel = DUI.Style, DUI.Pixel
local root = "Interface\\AddOns\\" .. ADDON .. "\\Media\\"
local choices = { off = "Off", left = "Bottom left", right = "Bottom right" }
local states = setmetatable({}, { __mode = "k" })
local reserves = setmetatable({}, { __mode = "k" })
local grips = setmetatable({}, { __mode = "k" })

extras.German["Chat panel corner"] = "Abgeschrägte Ecke am Chat"
extras.German["Damage meter corner"] = "Abgeschrägte Ecke am Schadensmesser"
extras.German["Applies to separate damage meter windows."] = "Gilt für separate Schadensmesser-Fenster."
extras.German["Bottom left"] = "Unten links"
extras.German["Bottom right"] = "Unten rechts"

local function option(module, key, label, desc)
    return { label = label, items = { {
        type = "dropdown", key = key, label = label, desc = desc, blastaSince = "2.0",
        values = choices, order = { "off", "left", "right" },
        get = function() return DUI:Get(module.name, key) or "off" end,
        set = function(value) return DUI:Set(module.name, key, value) end,
        default = function() return "off" end,
    } } }
end

local function paint(shell)
    local state = states[shell]
    if state and state.side then
        state.line:SetVertexColor(shell.border.BOTTOM:GetVertexColor())
        if state.band and shell.band.BOTTOM then
            state.band:SetVertexColor(shell.band.BOTTOM:GetVertexColor())
        end
    end
end

hooksecurefunc(Style, "PaintShellColors", paint)

local function detach(state)
    for texture in pairs(state.textures) do
        texture:RemoveMaskTexture(state.mask)
        state.textures[texture] = nil
    end
    state.line:Hide()
    if state.band then state.band:Hide() end
end

local function cut(frame, side, pixels, tile)
    local shell = frame and Style.GetShell(frame)
    if not (shell and shell.border.BOTTOM) then return 0 end
    if side ~= "left" and side ~= "right" then side = nil end
    local state = states[shell]
    local size = side and Pixel.Px(frame, pixels or 12) or 0
    local border = Pixel.Px(frame, Style.BorderPx(frame))
    local band = Style.IsHeavy(shell) and shell.band.BOTTOM and border - 2 * Pixel.Px(frame, 1) or 0
    if state and state.side == side and state.size == size and state.border == border and state.bandWidth == band then
        return size
    end
    if state and state.side then detach(state) end
    if not side then
        if state then state.side = nil end
        return 0
    end
    if not state then
        state = { mask = frame:CreateMaskTexture(), line = shell:CreateLine(nil, "BORDER", nil, 0), textures = {} }
        state.line:SetTexture("Interface\\Buttons\\WHITE8X8")
        states[shell] = state
    end
    state.side, state.size, state.border, state.bandWidth = side, size, border, band
    local edge = side == "left" and "LEFT" or "RIGHT"
    local corner = "BOTTOM" .. edge
    local direction = side == "left" and 1 or -1
    local mask = state.mask
    mask:SetTexture(root .. (side == "left" and "PanelCutLeft.tga" or "TooltipIconCut.tga"), "CLAMP", "CLAMP")
    mask:ClearAllPoints()
    mask:SetPoint(corner, shell, corner)
    mask:SetSize(size * 64 / 14, size * 64 / 14)
    local function clip(texture)
        if texture and not state.textures[texture] then
            texture:AddMaskTexture(mask)
            state.textures[texture] = true
        end
    end
    clip(shell.bg)
    clip(shell.bevelBottom)
    if tile then
        clip(frame.wash)
        clip(frame.glow)
        clip(frame.pin)
    end
    for _, group in ipairs({ shell.border, shell.band, shell.fillet, shell.shadow }) do
        clip(group.BOTTOM)
        clip(group[edge])
        clip(group[corner])
    end
    local function diagonal(line, width)
        local half = border / 2
        local reach = size + border / math.sqrt(2) - half
        line:SetStartPoint(corner, shell, direction * reach, half)
        line:SetEndPoint(corner, shell, direction * half, reach)
        line:SetThickness(width)
        line:Show()
    end
    if border > 0 then diagonal(state.line, border) end
    if band > 0 then
        if not state.band then
            state.band = shell:CreateLine(nil, "BORDER", nil, 1)
            state.band:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        diagonal(state.band, band)
    end
    paint(shell)
    return size
end

extras.CutPanelCorner = cut

local function fitGrip(grip, frame, side, size)
    if not grip then return end
    local inset = side == "right" and size / 2 or 0
    if (grips[grip] or 0) == inset then return end
    grip:ClearAllPoints()
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2 - inset, 2 + inset)
    grips[grip] = inset
end

-- The native reserve hides partial rows and also supports the docked threat display.
local function fitMeter(view, size)
    if not (view and view.Reserve and view.Reserved) then return end
    local state = reserves[view]
    if not state then
        if size == 0 then return end
        local reserve = view.Reserve
        state = { native = view.Reserved(), extra = 0 }
        reserves[view] = state
        function view.Reserve(px)
            state.native = px
            reserve(px + state.extra)
        end
    end
    if state.extra ~= size then
        state.extra = size
        view.Reserve(state.native)
    end
end

local chatMod = DUI:GetModule("Chat")
local chat = chatMod and chatMod.ns and chatMod.ns.Chat
if chat and chat.Layout and chat.Panel and chat.Area then
    local key = "blastaPanelCorner"
    chatMod.defaults[key] = "off"
    local function chatSide()
        return DUI:Get(chatMod.name, key)
    end
    function extras.ApplyChatPanelCorner(frame)
        return cut(frame, chatSide())
    end
    local function apply(panel, area, grip)
        if not (panel and area) then return end
        local side = chatSide()
        local size = cut(panel, side)
        if size > 0 then
            local inset = chat.inset or 0
            local footer = chat.InputAt() == "bottom" and 6 or 0
            area:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, math.max(inset, size + footer))
        end
        fitGrip(grip, panel, side, size)
    end
    local tiles, convo = chatMod.ns.Tiles, chatMod.ns.Convo
    local function applyWhisperCorners()
        local side = chatSide()
        if tiles and tiles.Tiles then
            for _, tile in ipairs(tiles.Tiles()) do cut(tile, side, 6, true) end
        end
        local card = convo and convo.Card and convo.Card()
        if card then
            -- The reply controls already sit ten UI units inside the card.
            cut(card, side, 8)
        end
    end
    hooksecurefunc(chat, "Layout", function()
        apply(chat.Panel(), chat.Area(), chat.grip)
        applyWhisperCorners()
    end)
    if tiles and tiles.Refresh then hooksecurefunc(tiles, "Refresh", applyWhisperCorners) end
    if convo and convo.Open then hooksecurefunc(convo, "Open", applyWhisperCorners) end
    local box = chatMod.ns.Box
    if box and box.SideLayout then
        hooksecurefunc(box, "SideLayout", function()
            local side = box.side
            if side then apply(side.panel, side.area, side.grip) end
        end)
    end
    function extras.ChatCornerGroup()
        return option(chatMod, key, "Chat panel corner")
    end
end

local infoMod = DUI:GetModule("InfoPanel")
local info = infoMod and infoMod.ns
if info and info.Panel and info.Panel.Layout and info.MeterFrame and info.MeterFrame.Layout then
    local key = "meter.blastaPanelCorner"
    infoMod.defaults.meter.blastaPanelCorner = "off"
    local panel = info.Panel
    hooksecurefunc(panel, "Layout", function(db)
        local side = db.meter.detached and db.meter.blastaPanelCorner
        local size = cut(panel.meterFrame, side)
        fitMeter(info.Meter, size)
        fitGrip(panel.grip, panel.meterFrame, side, size)
    end)
    hooksecurefunc(info.MeterFrame, "Layout", function(db, host)
        if host.kind ~= "meter" then return end
        local side = db.meter.blastaPanelCorner
        local size = cut(host.body, side)
        fitMeter(host.view, size)
        fitGrip(host.grip, host.frame, side, size)
    end)
    function extras.MeterCornerGroup()
        return option(infoMod, key, "Damage meter corner", "Applies to separate damage meter windows.")
    end
end

-- Every DaylightUI window (character, talents and spellbook, professions,
-- social, group finder, mail, vendor, bags and bank ...) can carry the same
-- cut corner at the bottom right as the chat and the damage meter. A window is
-- a shell built as a window that has DaylightUI's header with its X; that
-- leaves out tour cards, roll cards and other window-colored panels.
local Win = DUI.Win
local windowKey = "windowCorners"
extras.German["Window corner"] = "Fensterecke"
extras.German["Cut corner on all windows"] = "Abgeschrägte Ecke an allen Fenstern"
extras.German["Cuts the bottom right corner of every DaylightUI window, bags included, like the chat and the damage meter."] =
    "Schrägt die Ecke unten rechts an allen DaylightUI-Fenstern ab, Taschen eingeschlossen, wie bei Chat und Schadensmesser."
if Win and Win.Header and Style.GetShell and Style.Shells and Style.LayoutShell then
    local WINDOW_CUT = 16   -- a little more than the chat's 12, for the larger windows
    local cutWindows = setmetatable({}, { __mode = "k" })
    local gripSpots = setmetatable({}, { __mode = "k" })
    local function windowSide()
        return DUI:Get(ADDON, windowKey) == true and "right" or nil
    end
    local function isWindow(frame)
        local shell = type(frame) == "table" and Style.GetShell(frame)
        return shell and shell.opts and shell.opts.window and frame.close ~= nil
    end
    -- A resize grip in that corner: its strokes run parallel to the cut. With a
    -- 16 px cut DaylightUI's own spot (4 px in) puts the long stroke just inside
    -- the cut, so the grip stays there and never moves toward the window's
    -- buttons. A grip closer to the corner (the bags, 1 px in) moves in only as
    -- far as that spot, and back when the corner is turned off.
    local function fitWindowGrip(frame, size)
        local grip = frame.grip
        if not (grip and grip.GetPoint) then return end
        local spot = gripSpots[grip]
        if size == 0 then
            if spot and spot.inset ~= 0 then
                grip:ClearAllPoints()
                grip:SetPoint(spot.point, spot.relative, spot.relativePoint, spot.x, spot.y)
                spot.inset = 0
            end
            return
        end
        if not spot then
            local point, relative, relativePoint, x, y = grip:GetPoint(1)
            if point ~= "BOTTOMRIGHT" then return end
            spot = { point = point, relative = relative, relativePoint = relativePoint, x = x or 0, y = y or 0, inset = 0 }
            gripSpots[grip] = spot
        end
        local reach = math.max(0, size / 2 - 4)
        local x, y = math.min(spot.x, -reach), math.max(spot.y, reach)
        local inset = x .. ":" .. y
        if spot.inset == inset then return end
        grip:ClearAllPoints()
        grip:SetPoint(spot.point, spot.relative, spot.relativePoint, x, y)
        spot.inset = inset
    end
    local function applyWindow(frame)
        if not isWindow(frame) then return end
        local side = windowSide()
        if not side and not cutWindows[frame] then return end
        cutWindows[frame] = true
        fitWindowGrip(frame, cut(frame, side, WINDOW_CUT))
    end
    local function sweep()
        for shell in Style.Shells() do
            local frame = shell.GetParent and shell:GetParent()
            if frame then applyWindow(frame) end
        end
    end
    -- New windows get it once their header (and X) exists, open windows again
    -- whenever their shell is laid out anew (border, scale, look).
    hooksecurefunc(Win, "Header", extras.SafeHook("WindowCorners.Header", applyWindow))
    hooksecurefunc(Style, "LayoutShell", extras.SafeHook("WindowCorners.LayoutShell", function(shell)
        local frame = shell and shell.GetParent and shell:GetParent()
        if frame and cutWindows[frame] then applyWindow(frame) end
    end))
    DUI.On("Login", extras.SafeHook("WindowCorners.Login", sweep))
    DUI.On("SettingChanged", extras.SafeHook("WindowCorners.Setting", function(scope, setting)
        if scope == ADDON and setting == windowKey then sweep() end
    end))
    extras.WindowCornerGroup = { label = "Window corner", items = {
        { type = "toggle", key = windowKey, label = "Cut corner on all windows", blastaSince = "2.3",
            desc = "Cuts the bottom right corner of every DaylightUI window, bags included, like the chat and the damage meter." },
    } }
end
