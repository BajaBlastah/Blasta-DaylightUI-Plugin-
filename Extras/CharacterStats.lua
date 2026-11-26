local _, extras = ...
local DUI = DaylightUI
local character = DUI.Char and DUI.Char.CharacterPage
if GetLocale() ~= "deDE" or not (character and type(character.RefreshStats) == "function") then return end

local shortLabels = {
    speed = "Angriffstempo",
    rspeed = "Angriffstempo",
    pet_atkspeed = "Angriffstempo",
    movespeed = "Lauftempo",
    pet_speed = "Lauftempo",
}

hooksecurefunc(character, "RefreshStats", extras.SafeHook("CharacterStats.RefreshStats", function(page)
    for _, group in pairs(page.stats.groups) do
        for _, row in ipairs(group.rows) do
            if row.row and row:IsShown() and row.label and row.value then
                local label = shortLabels[row.row.id]
                if label then row.label:SetText(label) end
                row.label:SetWordWrap(false)
                local valueWidth = row.value:GetStringWidth()
                if type(valueWidth) == "number" and not (issecretvalue and issecretvalue(valueWidth)) then
                    row.label:SetWidth(math.max(1, row:GetWidth() - 2 * (character.STAT_INSET or 0) - valueWidth - 8))
                end
            end
        end
    end
end))
