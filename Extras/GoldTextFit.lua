-- SPDX-License-Identifier: GPL-3.0-or-later
local _, extras = ...
local DUI = DaylightUI
local mod = DUI:GetModule("InfoPanel")
local DT = mod and mod.ns and mod.ns.DataTexts
if not (DT and DT.New and DT.ReadMoney and DUI.MoneyString) then return end
local wrapped = setmetatable({}, { __mode = "k" })
local function plain(v) if not (issecretvalue and issecretvalue(v)) then return v end end
local function exact()
    local settings = mod.db and mod.db.dataTextColors
    return settings and settings.exactMoney == true
end
local function fit(strip)
    if not exact() then return end
    for _, slot in ipairs(strip.slots or {}) do
        local fs = slot.text
        local room = plain(slot.textW)
        if slot.key == "gold" and fs and type(room) == "number" and room > 0 and not slot.rollText then
            local text = plain(slot.isShort and slot.short or slot.long)
            local amount = plain(DT.ReadMoney())
            if type(text) == "string" and type(amount) == "number" and amount >= 0 then
                local color = text:match("^(|c%x%x%x%x%x%x%x%x)")
                local function styled(s) return color and color .. s .. "|r" or s end
                local candidates = { text }
                if amount >= 100 then candidates[#candidates + 1] = styled(DUI.MoneyString(math.floor(amount / 100) * 100)) end
                if amount >= 10000 then candidates[#candidates + 1] = styled(DUI.MoneyString(math.floor(amount / 10000) * 10000)) end
                if amount >= 10000000 and DUI.CoinIcon then
                    local gold = math.floor(amount / 10000)
                    local scale, suffix = gold >= 1000000 and 1000000 or 1000, gold >= 1000000 and "m" or "k"
                    -- Truncate rather than rounding up an amount the player does not have.
                    candidates[#candidates + 1] = styled(string.format("%.1f%s", math.floor(gold / scale * 10) / 10, suffix) .. DUI.CoinIcon("gold"))
                    candidates[#candidates + 1] = styled(math.floor(gold / scale) .. suffix .. DUI.CoinIcon("gold"))
                end
                local chosen = text
                fs:SetWidth(0)
                for _, candidate in ipairs(candidates) do
                    fs:SetText(candidate)
                    local width = plain(fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth())
                    chosen = candidate
                    if type(width) == "number" and width <= room then break end
                end
                fs:SetText(chosen)
                fs:SetWidth(room)
            end
        end
    end
end
local function wrap(strip)
    if not strip or wrapped[strip] or not strip.Layout or not strip.Update then return strip end
    wrapped[strip] = true
    hooksecurefunc(strip, "Layout", function() fit(strip) end)
    -- CountGold may restore the unabridged string after Layout; fit once after
    -- the update has settled too. No relayout, timer or text-change hook.
    hooksecurefunc(strip, "Update", function() fit(strip) end)
    return strip
end
local new = DT.New
function DT.New(...)
    return wrap(new(...))
end
wrap(DT)
for _, strip in ipairs(DT.strips or {}) do wrap(strip) end
extras.German["Show gold, silver and copper when space permits. Hide copper, then silver in narrow slots; the tooltip keeps the exact amount."] =
    "Zeigt Gold, Silber und Kupfer, soweit Platz vorhanden ist. In schmalen Feldern entfallen zuerst Kupfer, dann Silber. Im Tooltip bleibt der genaue Betrag sichtbar."
extras.Loaded("GoldTextFit")
