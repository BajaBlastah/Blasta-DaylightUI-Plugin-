local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("QoL")
local mod = DUI:GetModule("QoL")
local flight = ns and ns.Flight
local Style, Widgets = DUI.Style, DUI.Widgets
if not (mod and mod.defaults and flight and flight.Update and flight.Tick and flight.Refresh
    and flight.Enable and flight.LandEarly and Style and Widgets and Widgets.IconButton
    and extras.FindSetting(mod, "flightTimer")) then return end

local KEY = "blastaFlightLanding"
local LABEL = "Integrated landing button"
local DESC = "Show a labeled landing button inside the flight timer and hide the separate game button while it is available."
local LAND = "Land at next stop"
local FOOTER = 21
extras.German[LABEL] = "Integrierter Landeknopf"
extras.German[DESC] = "Zeigt einen beschrifteten Landeknopf im Flugtimer. Solange er verfügbar ist, wird der separate WoW-Knopf ausgeblendet."
extras.German[LAND] = "Früher landen"
mod.defaults[KEY] = false

local function cfg() return mod.db or mod.defaults end
local function enabled() return cfg().flightTimer == true and cfg()[KEY] == true end

local function decorate(button, active, frame)
    local state = button.blastaFlightFace
    if not state then
        if not active or not button.icon then return end
        local label = Style.Text(button, Style.SIZE.small, "LEFT")
        Style.DressText(label, Style.SIZE.small, { outline = "OUTLINE" })
        Style.InkText(label, "LABEL")
        label:SetText(extras.Translate(LAND))
        label:SetPoint("LEFT", button.icon, "RIGHT", 5, 0)
        label:SetWordWrap(false)
        state = { label = label, width = button:GetWidth(), height = button:GetHeight(), anchor = { button:GetPoint(1) } }
        button.blastaFlightFace = state
        button:HookScript("OnEnter", function() Style.InkText(label, "pop") end)
        button:HookScript("OnLeave", function() Style.InkText(label, "LABEL") end)
    end
    if state.active == active then return end
    state.active = active
    button.icon:ClearAllPoints()
    if frame then
        button:ClearAllPoints()
        if active then
            button:SetPoint("TOP", frame, "BOTTOM", 0, -2)
        elseif state.anchor[1] then
            button:SetPoint(unpack(state.anchor))
        end
    end
    if active then
        button.icon:SetPoint("LEFT", button, "LEFT", 7, 0)
        button:SetSize(math.ceil(state.label:GetStringWidth()) + button.icon:GetWidth() + 19, FOOTER)
    else
        button.icon:SetPoint("CENTER", button, "CENTER")
        button:SetSize(state.width, state.height)
    end
    state.label:SetShown(active)
end

local hiding, hooked, replacement, fallback, requested
local function onTaxi()
    local mounted = UnitOnTaxi and UnitOnTaxi("player")
    return not (issecretvalue and issecretvalue(mounted)) and mounted == true
end
local function syncStock()
    local stock = _G.MainMenuBarVehicleLeaveButton
    if not stock or InCombatLockdown() then return end
    if replacement and onTaxi() and not stock.isInEditMode and not (DUI.Movers and DUI.Movers.unlocked) then
        if hooked ~= stock then
            hooked = stock
            stock:HookScript("OnShow", function() C_Timer.After(0, syncStock) end)
        end
        if stock:IsShown() then
            stock:Hide()
            hiding = stock
        end
    elseif hiding == stock then
        hiding = nil
        if type(stock.UpdateShownState) == "function" then
            stock:UpdateShownState()
        elseif type(MainMenuBarVehicleLeaveButton_Update) == "function" then
            MainMenuBarVehicleLeaveButton_Update()
        elseif CanExitVehicle and CanExitVehicle() == true then
            stock:Show()
        end
    end
end

local function stockCanLand()
    local stock = _G.MainMenuBarVehicleLeaveButton
    if not stock then return false end
    if hiding == stock or (stock:IsShown() and stock:IsEnabled()) then return true end
    local canExit = CanExitVehicle and CanExitVehicle()
    return not (issecretvalue and issecretvalue(canExit)) and canExit == true
end

local function fallbackButton(frame)
    if fallback then return fallback end
    fallback = Widgets.IconButton(frame.box, "ui-leave.png", flight.LeaveTip, function()
        if onTaxi() and not requested and stockCanLand() then flight.LandEarly() end
    end)
    fallback:SetFrameLevel(frame.leave:GetFrameLevel())
    fallback:SetPoint("TOPRIGHT", frame.box, "TOPRIGHT", -(flight.LEAVE_INSET or 4), -(flight.LEAVE_INSET or 4))
    decorate(fallback, true, frame)
    return fallback
end

local function refresh()
    local holder = _G.DaylightUIFlightTimer
    local frame = holder and holder.f
    local button = frame and frame.leave
    local active = enabled() and button ~= nil and button.icon ~= nil
    local taxi = onTaxi()
    if not taxi then requested = nil end
    local wasReplacing = replacement
    local landing
    if button then
        decorate(button, active, frame)
        if active and holder:IsVisible() then
            if button.want == true then
                landing = button
            elseif taxi and not requested and not button:IsShown() and stockCanLand() then
                -- DaylightUI hides its button when it knows of no intermediate
                -- stop. The client can still offer its own early-landing action.
                landing = fallbackButton(frame)
            end
        end
        local footer = landing ~= nil
        if frame.blastaLandingFooter ~= footer then
            frame.blastaLandingFooter = footer
            frame.box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", flight.PAD_X or 0,
                -(flight.PAD_Y or 0) - (footer and FOOTER or 0))
        end
    end
    if fallback then fallback:SetShown(landing == fallback) end
    replacement = active and taxi and holder:IsVisible() and (landing ~= nil or requested == true)
    if replacement ~= wasReplacing then syncStock() end
end

if type(TaxiRequestEarlyLanding) == "function" then
    hooksecurefunc("TaxiRequestEarlyLanding", function()
        if onTaxi() then requested = true; refresh() end
    end)
end

local function sample(parent)
    local host = CreateFrame("Frame", nil, parent)
    local banner = CreateFrame("Frame", nil, host)
    banner:SetPoint("TOP", host, "TOP", 0, -6)
    Style.Shell(banner, { window = true })
    local name = Style.Text(banner, 17, "CENTER")
    name:SetPoint("TOP", banner, "TOP", 0, -9)
    name:SetText(flight.SAMPLE and flight.SAMPLE.name or "Stormwind")
    name:SetWordWrap(false)
    local bar = Style.Bar(banner)
    bar:SetPoint("TOPLEFT", banner, "TOPLEFT", 12, -36)
    bar:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -12, -36)
    bar:SetHeight(4)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.42)
    local from = Style.Text(banner, Style.SIZE.small, "LEFT")
    from:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -8)
    from:SetText(flight.SAMPLE and flight.SAMPLE.from or "Ironforge")
    local clock = Style.Text(banner, Style.SIZE.small, "RIGHT")
    clock:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -8)
    clock:SetText(flight.FormatTime and flight.FormatTime(61) or "1:01")
    Style.InkText(clock, "pop")
    local button = Widgets.IconButton(banner, "ui-leave.png")
    button:SetPoint("TOPRIGHT", banner, "TOPRIGHT", -5, -5)
    button:EnableMouse(false)
    return { frame = host, Parts = function() return {} end, Refresh = function(width)
        local active = cfg()[KEY] == true
        local height = 68 + (active and FOOTER or 0)
        host:SetSize(width, height + 12)
        banner:SetSize(math.min(width, 340), height)
        decorate(button, active, banner)
        if active then button:SetPoint("TOP", banner, "TOP", 0, -64) end
        return height + 12
    end }
end

local row = { type = "toggle", key = KEY, label = LABEL, desc = DESC, blastaSince = "1.9.4",
    disabled = function(get) return get("flightTimer") ~= true end }
for _, page in ipairs(mod.options and mod.options.pages or {}) do
    if page.id == "flight" then
        table.insert(page.groups, 1, { label = "Flight timer", blastaTab = "Flight timer",
            blastaSample = sample, items = { row } })
        break
    end
end

for _, method in ipairs({ "Update", "Tick", "Refresh", "Enable" }) do hooksecurefunc(flight, method, refresh) end
DUI.On("Login", refresh)
DUI.On("UnlockChanged", syncStock)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", syncStock)
DUI.On("SettingChanged", function(scope, path)
    if scope == mod.name and (path == KEY or path == "flightTimer") then refresh() end
end)

extras.Loaded("FlightBanner")
