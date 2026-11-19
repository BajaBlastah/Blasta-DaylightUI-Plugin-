local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("QoL")
local flight = ns and ns.Flight
if not (flight and flight.Update and flight.Tick and flight.Refresh and flight.Enable and flight.FormatTime and flight.Routes) then return end

local mod = DUI:GetModule("QoL")
local Edges, Pixel, Style = extras.Edges, DUI.Pixel, DUI.Style
local function nativeRight(db) return db.flightTimerSlant == false and "straight" or "top" end
local function disabled(get) return get("flightTimer") ~= true end
local function add(anchor, row)
    row.blastaRequires = "flightTimer"
    extras.AddSetting(mod, anchor, row)
end

mod.defaults.flightTimerTime = "remaining"
add("flightTimerSlant", Edges.Options(mod, "flightLeft", "Left edge direction", function() return "straight" end, disabled))
add("flightLeft", Edges.Options(mod, "flightRight", "Right edge direction",
    function(reset) return nativeRight(not reset and mod.db or mod.defaults) end, disabled))
add("flightRight", {
    type = "dropdown", key = "flightTimerTime", label = "Flight timer display",
    values = { remaining = "Remaining time", elapsed = "Elapsed time", arrival = "Arrival time" },
    order = { "remaining", "elapsed", "arrival" }, disabled = disabled,
})

local function holder()
    return _G.DaylightUIFlightTimer
end

local landingButton, requestedFor
local landingWidth, landingGap = 18, 4

local function placeTime(box, cut)
    local right = flight.PAD + cut
    local buttonInset = 2 + cut * 0.55
    local timeInset = right
    if landingButton then
        landingButton:SetPoint("TOPRIGHT", box, "TOPRIGHT", -buttonInset, -2)
        landingButton:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -buttonInset, 2)
        if landingButton:IsShown() then timeInset = buttonInset + landingWidth + landingGap end
    end
    box.time:SetPoint("RIGHT", box, "RIGHT", -timeInset, 0)
end

local function rightCut(box)
    local cfg = mod.db
    local _, right = Edges.Read(cfg, "flightLeft", "flightRight", "straight", nativeRight(cfg))
    return right == "straight" and 0 or Pixel.Snap(box, box:GetHeight() * flight.SLANT)
end

local function activeFlight()
    if UnitOnTaxi and UnitOnTaxi("player") == true then return DUI.DB.Character().flight end
end

local nativeHooked, nativeHidden, replaceNative
local function syncNativeButton()
    local button = _G.MainMenuBarVehicleLeaveButton
    if not button or InCombatLockdown() then return end
    if replaceNative and activeFlight() and not button.isInEditMode and not (DUI.Movers and DUI.Movers.unlocked) then
        if nativeHooked ~= button then
            nativeHooked = button
            button:HookScript("OnShow", function() C_Timer.After(0, syncNativeButton) end)
        end
        if button:IsShown() then
            button:Hide()
            nativeHidden = button
        end
    elseif nativeHidden == button then
        nativeHidden = nil
        if type(button.UpdateShownState) == "function" then
            button:UpdateShownState()
        elseif type(MainMenuBarVehicleLeaveButton_Update) == "function" then
            MainMenuBarVehicleLeaveButton_Update()
        elseif activeFlight() and CanExitVehicle and CanExitVehicle() == true then
            button:Show()
        end
    end
end

local function canRequestLanding(record)
    return type(record) == "table" and record ~= requestedFor and type(TaxiRequestEarlyLanding) == "function"
        and (type(CanExitVehicle) ~= "function" or CanExitVehicle() == true)
end

local function buildLandingButton(box)
    local overlay = box.time:GetParent()
    local button = CreateFrame("Button", nil, overlay)
    button:SetWidth(landingWidth)
    local label = Style.Text(button, flight.TEXT, "CENTER")
    label:SetPoint("CENTER")
    label:SetText("X")
    Style.InkText(label, "VALUE")
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function leave(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end
    button:SetScript("OnEnter", function(self)
        DUI.Widgets.Tooltip(self, extras.Translate("Land early"), extras.Translate("Request landing at the next flight point."))
    end)
    button:SetScript("OnLeave", leave)
    button:SetScript("OnHide", leave)
    button:SetScript("OnClick", function()
        if canRequestLanding(activeFlight()) then TaxiRequestEarlyLanding() end
    end)
    button:Hide()
    return button
end

local function syncLanding()
    local frame = holder()
    local cfg = mod.db
    local record = activeFlight()
    if not record then requestedFor = nil end
    local box = frame and frame.box
    local visible = box and cfg and cfg.flightTimer and frame:IsShown() and canRequestLanding(record) or false
    if visible and not landingButton then landingButton = buildLandingButton(box) end
    if landingButton and landingButton:IsShown() ~= visible then
        landingButton:SetShown(visible)
        if box and cfg then placeTime(box, rightCut(box)) end
    end
    replaceNative = visible or (record ~= nil and requestedFor == record and box ~= nil and cfg and cfg.flightTimer
        and frame:IsVisible())
    syncNativeButton()
end

local applied
local function layout()
    local frame = holder()
    local box = frame and frame.box
    local cfg = mod.db
    if not (box and box.bar and box.time and box.name and cfg) then return end
    local left, right, custom = Edges.Read(cfg, "flightLeft", "flightRight", "straight", nativeRight(cfg))
    if not (custom or applied == box) then
        if landingButton then placeTime(box, rightCut(box)) end
        return
    end
    local height = box:GetHeight()
    if height <= 0 then return end
    local cut = Pixel.Snap(box, height * flight.SLANT)
    local border = Pixel.Px(box, Style.BorderPx(box))
    local fillCut = cut * math.max(0, height - 2 * border) / height
    if custom then
        applied = box
        Edges.Apply(box, left, right, cut)
    else
        applied = nil
        Edges.Clear(box)
        Style.Slant(box, right == "straight" and nil or "right", right == "straight" and 0 or cut)
    end
    Edges.Fill(box.bar, "right", fillCut, right)
    placeTime(box, right == "straight" and 0 or cut)
    box.name:SetPoint("LEFT", box, "LEFT", flight.PAD + (left == "straight" and 0 or cut), 0)
end

local function displayTime()
    local cfg = mod.db
    local frame = holder()
    local text = frame and frame.box and frame.box.time
    if not (cfg and cfg.flightTimer and text and frame:IsShown()) then return end
    local mode = cfg.flightTimerTime
    local value = text.flightText
    if mode == "arrival" or mode == "elapsed" then
        local record = activeFlight()
        local now = time()
        local elapsed, arrival
        if type(record) == "table" and type(record.wall) == "number" then
            elapsed = math.max(0, now - record.wall)
            local total = record.key and flight.Routes()[record.key]
            if type(total) == "number" and total > 0 then arrival = record.wall + total end
        elseif (DUI.testMode and DUI.TestPartShown(flight.TEST_PART)) or (DUI.Movers and DUI.Movers.unlocked) then
            local sample = flight.SAMPLE
            if sample then elapsed, arrival = sample.elapsed, now + sample.total - sample.elapsed end
        end
        if mode == "elapsed" and elapsed then
            value = flight.FormatTime(elapsed)
        elseif mode == "arrival" and arrival then
            value = date("%H:%M", arrival)
        end
    end
    if value and text:GetText() ~= value then text:SetText(value) end
end

local function update()
    syncLanding()
    displayTime()
end

if type(TaxiRequestEarlyLanding) == "function" then
    hooksecurefunc("TaxiRequestEarlyLanding", function()
        requestedFor = activeFlight()
        syncLanding()
    end)
end
hooksecurefunc(flight, "Update", update)
hooksecurefunc(flight, "Tick", update)
hooksecurefunc(flight, "Enable", layout)
hooksecurefunc(flight, "Refresh", layout)
DUI.RegisterEvent("PLAYER_REGEN_ENABLED", syncNativeButton)
DUI.On("UnlockChanged", syncNativeButton)
DUI.On("StyleChanged", function() C_Timer.After(0, layout) end)
DUI.On("SettingChanged", function(scope)
    if scope == "general" then C_Timer.After(0, layout) end
end)

extras.Loaded("FlightTimer")
