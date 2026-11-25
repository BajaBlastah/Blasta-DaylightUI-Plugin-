-- SPDX-License-Identifier: GPL-3.0-or-later
-- More parts to drag in DaylightUI's Design mode:
--   * the raid marker on the target and focus frames (DaylightUI keeps it at
--     the name; its own nudge, markerX/Y, works there but has no setting);
--   * the time on a nameplate's cast bar.
local ADDON, extras = ...
local DUI = DaylightUI
local VERSION = "1.9.8"
local german = extras.German

german["Raid marker left / right"] = "Zielmarkierung links / rechts"
german["Raid marker up / down"] = "Zielmarkierung hoch / runter"
german["Moves the raid marker from its place by the name. In Design mode, drag it on the preview."] =
    "Verschiebt die Zielmarkierung von ihrem Platz am Namen. Im Design-Modus kannst du sie in der Vorschau ziehen."
german["Cast time left / right"] = "Zauberzeit links / rechts"
german["Cast time up / down"] = "Zauberzeit hoch / runter"
german["Cast time"] = "Zauberzeit"
german["Moves the remaining time on enemy cast bars. In Design mode, drag it on the preview."] =
    "Verschiebt die Restzeit auf gegnerischen Zauberleisten. Im Design-Modus kannst du sie in der Vorschau ziehen."

local any = false

-- Raid marker nudge on frames whose marker sits at the name.
local units = DUI:GetModule("UnitFrames")
if units and units.defaults then
    for _, unit in ipairs({ "target", "focus" }) do
        local defaults = units.defaults[unit]
        local prefix = unit .. "."
        local size = extras.FindSetting(units, prefix .. "markerSize")
        if defaults and size and not extras.HasSetting(units, prefix .. "markerX")
            and not extras.HasSetting(units, prefix .. "markerPos") then
            defaults.markerX, defaults.markerY = 0, 0
            local function off(get) return get(prefix .. "showMarker") == false end
            local anchor = size.key
            for _, axis in ipairs({ "X", "Y" }) do
                local row = { type = "slider", key = prefix .. "marker" .. axis, min = -40, max = 40, step = 1, unit = "px",
                    label = axis == "X" and "Raid marker left / right" or "Raid marker up / down",
                    desc = "Moves the raid marker from its place by the name. In Design mode, drag it on the preview.",
                    blastaSince = VERSION, disabled = off }
                extras.AddSetting(units, anchor, row)
                anchor = row.key
            end
            any = true
        end
    end
    -- Settings.lua turns a part with these keys into a drag (portraitMove).
    if extras.PortraitOffsets then
        extras.PortraitOffsets["Raid marker"] = { "showMarker", "marker", "marker", "markerPos" }
    end
end

-- The time on nameplate cast bars.
local plates = DUI:GetModule("Nameplates")
local ns = plates and plates.ns
local Cast = ns and ns.Cast
if Cast and Cast.Layout and plates.defaults and extras.FindSetting(plates, "castHeight")
    and not extras.HasSetting(plates, "castTimeX") then
    plates.defaults.castTimeX, plates.defaults.castTimeY = 0, 0
    -- After the spell name's rows on Blasta's cast bar tab (NameplateShape),
    -- else after DaylightUI's cast bar height.
    local anchor = extras.FindSetting(plates, "blastaCastTextY") and "blastaCastTextY" or "castHeight"
    for _, axis in ipairs({ "X", "Y" }) do
        local row = { type = "slider", key = "castTime" .. axis, min = -60, max = 60, step = 1, unit = "px",
            label = axis == "X" and "Cast time left / right" or "Cast time up / down",
            desc = "Moves the remaining time on enemy cast bars. In Design mode, drag it on the preview.",
            blastaSince = VERSION }
        extras.AddSetting(plates, anchor, row)
        anchor = row.key
    end

    -- The offset itself is applied where the cast bar's text is laid out
    -- (NameplateShape): reading the time's position back (GetPoint) is
    -- refused on a nameplate under restrictions.
    -- A "Cast time" part on the nameplate preview, dragged like the party
    -- resource bar (xKey/yKey): it moves from where it sits now.
    function extras.AddPlateCastTimeMove(parts)
        for _, part in ipairs(parts) do
            local c = part.label == "Cast bar" and part.region
            local t = c and c.time
            if t and t:IsVisible() and c:GetLeft() then
                local cx, cy = t:GetCenter()
                if cx and cy then
                    local scale = t:GetEffectiveScale() / c:GetEffectiveScale()
                    local x0, y0 = cx * scale - c:GetLeft(), c:GetTop() - cy * scale
                    local px = tonumber(DUI:Get("Nameplates", "castTimeX")) or 0
                    local py = tonumber(DUI:Get("Nameplates", "castTimeY")) or 0
                    local function clamp(v) return math.max(-60, math.min(60, math.floor(v + 0.5))) end
                    parts[#parts + 1] = { region = t, label = "Cast time", keys = { "castTimeX", "castTimeY" },
                        move = { owner = c, dots = {}, xKey = "castTimeX", yKey = "castTimeY",
                            drop = function(x, y) return nil, clamp(px + (x - x0)), clamp(py - (y - y0)) end } }
                end
                return
            end
        end
    end
    any = true
end

if any then extras.Loaded("DesignParts") end
