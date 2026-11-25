local ADDON = ...
local DUI = DaylightUI
local panel, widgets = DUI.OptionsPanel, DUI.Widgets
if not (panel and panel.Refresh and panel.Current and panel.Frame and panel.Tabs and panel.PageFrame
    and widgets and widgets.TAB_H) then return end

local rowGap = 4

local function wrapTabs()
    local id = panel.Current()
    if not id or id:sub(1, #ADDON + 1) ~= ADDON .. "." then return end
    local row, page = panel.Tabs(), panel.PageFrame()
    if not (row and row.buttons and row:IsShown() and page) then return end
    local scroll = page:GetParent()
    if not (scroll and scroll:GetScrollChild() == page) then return end
    local available = row:GetWidth()
    if available <= 0 then return end

    local gap = DUI.Win and DUI.Win.TAB_GAP or 14
    local height = widgets.TAB_H
    local x, y = 0, 0
    for _, button in ipairs(row.buttons) do
        if button:IsShown() then
            local text = button.text
            text:SetWidth(0)
            button.FitWidth(8)
            local width = math.min(button:GetWidth(), available)
            if width < button:GetWidth() then
                button:SetWidth(width)
                text:SetWordWrap(false)
                text:SetWidth(math.max(1, width - 8))
            end
            if x > 0 and x + width > available then x, y = 0, y + height + rowGap end
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y)
            x = x + width + gap
        end
    end

    -- Daylight reserves one tab row. Move the scroll area's top down by the
    -- additional rows, keeping its original bottom and horizontal margins.
    row:SetHeight(y + height)
    if y > 0 then scroll:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -(panel.CHIPS_GAP or 10)) end
end

local watched
hooksecurefunc(panel, "Refresh", function()
    local frame = panel.Frame()
    if frame and frame ~= watched then
        watched = frame
        frame:HookScript("OnSizeChanged", wrapTabs)
    end
    wrapTabs()
end)
