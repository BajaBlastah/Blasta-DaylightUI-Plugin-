local ADDON, extras = ...
local DUI = DaylightUI
local API = DUI and DUI.API
local me = API and API.major == 1 and (API.minor or 0) >= 3 and API.For and API.For(ADDON)
local mod = DUI:GetModule("UnitFrames")
local ns = extras.Compatible("UnitFrames")
local UF = ns and ns.UF
local party = ns and ns.Party and ns.Party.group
local pixel = DUI.Pixel
if not (me and party and UF and UF.LayoutPortrait and UF.LayoutStatus and UF.PORTRAIT_FREE
    and pixel and pixel.Snap) then return end
if not extras.FindSetting(mod, "party.portrait") or extras.HasSetting(mod, "party.portraitAt") then return end

-- A party portrait beside its frame: it rides on its own party button at an
-- offset, so it follows the group's spacing, growth direction, sorting and
-- the options preview by itself, and keeps the button's visibility and fade.
-- The offset points away from the frame and mirrors with the frame's slant.
local position = "party.portraitAt"
local DEFAULT_GAP = 6
mod.defaults.party.portraitAt = "frame"
mod.defaults.party.portraitIconsStay = false
mod.defaults.party.blastaPortraitGap = DEFAULT_GAP
mod.defaults.party.blastaPortraitY = 0

local besideLabel = "Beside the frame"
local positionDesc = "Beside the frame, the portrait sits outside its party frame at the distance below, on the frame's outer side. The frame keeps its whole length."
local gapLabel, yLabel = "Portrait distance", "Portrait height offset"
local gapDesc = "How far the portrait sits from the frame's outer edge. Negative values let it overlap the frame."
extras.German[besideLabel] = "Neben dem Rahmen"
extras.German[positionDesc] = "Neben dem Rahmen sitzt das Porträt mit dem unten eingestellten Abstand außen am Gruppenrahmen. Der Rahmen behält seine ganze Länge."
extras.German[gapLabel] = "Abstand des Porträts"
extras.German[yLabel] = "Porträt hoch / runter"
extras.German[gapDesc] = "Abstand des Porträts zur Außenkante des Rahmens. Negative Werte lassen es den Rahmen überlappen."

local function portraitOff(get) return get("party.portrait") == "none" end
local function notBeside(get) return get(position) ~= "free" or portraitOff(get) end

extras.AddSetting(mod, "party.portrait", {
    type = "dropdown", key = position, label = "Portrait position",
    values = { frame = "On the frame", free = besideLabel },
    order = { "frame", "free" },
    desc = positionDesc,
    disabled = portraitOff,
})
extras.AddSetting(mod, position, {
    type = "slider", key = "party.blastaPortraitGap", label = gapLabel, desc = gapDesc,
    min = -60, max = 120, step = 1, unit = "px", onRelease = true, disabled = notBeside,
})
extras.AddSetting(mod, "party.blastaPortraitGap", {
    type = "slider", key = "party.blastaPortraitY", label = yLabel,
    min = -60, max = 60, step = 1, unit = "px", onRelease = true, disabled = notBeside,
})
extras.AddSetting(mod, "party.blastaPortraitY", {
    type = "toggle", key = "party.portraitIconsStay", label = "Icons stay on the frame",
    desc = "With the portrait on its own, the crown, resting Zzz, PvP flag, level badge and DoT skull stay on the frame instead of going with it.",
    disabled = notBeside,
})

local holders = setmetatable({}, { __mode = "k" })

-- No mover is registered under this key, so DaylightUI's own Movers calls on
-- the holder (Suspend, Scale) find nothing and leave it to us.
local HOLDER_KEY = "blasta.partyPortrait"
local function holderFor(frame)
    local holder = holders[frame]
    if not holder then
        holder = CreateFrame("Frame", nil, frame)
        holder.key = HOLDER_KEY
        holder:Hide()
        holders[frame] = holder
        frame.portraitHolder = holder
    end
    return holder
end

local function place(frame, holder, cfg)
    -- DaylightUI scales a free holder for UIParent. This one lives on the party
    -- button, which already carries the frame's scale.
    holder:SetScale(1)
    local outerRight = frame.spec.slant == "left"
    local outer, inner = outerRight and "RIGHT" or "LEFT", outerRight and "LEFT" or "RIGHT"
    local gap = pixel.Snap(frame, tonumber(cfg.blastaPortraitGap) or DEFAULT_GAP)
    local y = pixel.Snap(frame, tonumber(cfg.blastaPortraitY) or 0)
    holder:ClearAllPoints()
    holder:SetPoint(inner, frame, outer, (outerRight and 1 or -1) * gap, y)
    holder:SetShown(holder.want == true)
end

-- DaylightUI only frees the portraits of units listed in UF.PORTRAIT_FREE.
-- Party buttons share their spec, so give the native layout a private view
-- of it with a listed unit. One view per spec; nothing writes into specs.
local groupUnit = "blastaPartyPortrait"
UF.PORTRAIT_FREE[groupUnit] = HOLDER_KEY
local specViews = setmetatable({}, { __mode = "k" })
local function viewOf(spec)
    local view = specViews[spec]
    if not view then
        view = setmetatable({ unit = groupUnit }, { __index = spec })
        specViews[spec] = view
    end
    return view
end

me.Wrap(UF, "LayoutPortrait", function(original, frame, cfg)
    if frame.group ~= party or not frame.portrait or type(cfg) ~= "table" or cfg.portraitAt ~= "free" then
        return original(frame, cfg)
    end
    local holder = holderFor(frame)
    local spec = frame.spec
    frame.spec = viewOf(spec)
    local ok, err = pcall(original, frame, cfg)
    frame.spec = spec
    if not ok then error(err, 0) end
    place(frame, holder, cfg)
end)

me.Hook(UF, "LayoutStatus", function(frame)
    if not (holders[frame] and frame.iconsStay and frame.status and frame.health) then return end

    -- The native fallback uses the name tab, which party styles can hide or
    -- offset. Anchor the default spots to the health bar in every party style.
    local status, bar = frame.status, frame.health
    local outerRight = frame.spec.slant == "left"
    local outer, inner = outerRight and "RIGHT" or "LEFT", outerRight and "LEFT" or "RIGHT"
    local inward = outerRight and -1 or 1
    local topOuter, topInner, bottomOuter = "TOP" .. outer, "TOP" .. inner, "BOTTOM" .. outer

    local function put(icon, point, x, y)
        icon:ClearAllPoints()
        icon:SetPoint(point, bar, point, x, y)
    end

    local icons = status.icons
    local leader, role = frame.leaderNudge or UF.NO_NUDGE, frame.roleNudge or UF.NO_NUDGE
    if not frame.leaderSpot then put(icons.leader, topOuter, inward * 2 + leader.x, -2 + leader.y) end
    if icons.role and not frame.roleSpot then put(icons.role, topInner, -inward * 2 + role.x, -2 + role.y) end
    put(icons.rest, topOuter, inward * (icons.leader:GetWidth() + 4), -2)
    put(icons.pvp, bottomOuter, inward * (icons.level:GetWidth() + 4), 2)
    if not frame.levelSpot then put(icons.level, bottomOuter, inward * 2, 2) end
    status:SetFrameLevel(math.max(status:GetFrameLevel(), bar:GetFrameLevel() + 8))
end)

-- Positions from 1.7's per-slot handles are no longer used.
DUI.On("Login", function()
    local positions = DUI.DB and DUI.DB.Positions and DUI.DB.Positions()
    if type(positions) ~= "table" then return end
    for index = 1, 5 do positions["unitframes.blastaPartyPortrait" .. index] = nil end
end)

-- Design mode: in DaylightUI's party preview the portrait beside the frame
-- drags like a native piece. Dropping it sets its distance from the frame
-- (mirrored with the frame's slant) and its height offset.
function extras.AddPartyPortraitMove(preview, parts)
    if DUI:Get(mod.name, position) ~= "free" or DUI:Get(mod.name, "party.portrait") == "none" then return end
    for _, part in ipairs(parts) do
        local region = part.label == "Portrait" and part.region
        local frame
        for owner, holder in pairs(holders) do
            if region and (region == owner.portrait or region:GetParent() == holder) then frame = owner; break end
        end
        if frame and region:IsVisible() and frame:GetLeft() then
            local scale = region:GetEffectiveScale() / frame:GetEffectiveScale()
            local cx, cy = region:GetCenter()
            if cx and cy then
                local x0, y0 = cx * scale - frame:GetLeft(), frame:GetTop() - cy * scale
                local gap0 = tonumber(DUI:Get(mod.name, "party.blastaPortraitGap")) or DEFAULT_GAP
                local up0 = tonumber(DUI:Get(mod.name, "party.blastaPortraitY")) or 0
                local outward = frame.spec and frame.spec.slant == "left" and 1 or -1
                local function clamp(v, lo, hi) return math.max(lo, math.min(hi, math.floor(v + 0.5))) end
                part.keys = part.keys or {}
                part.keys[#part.keys + 1] = "party.blastaPortraitGap"
                part.keys[#part.keys + 1] = "party.blastaPortraitY"
                part.move = { owner = frame, dots = {}, xKey = "party.blastaPortraitGap", yKey = "party.blastaPortraitY",
                    drop = function(x, y)
                        return nil, clamp(gap0 + outward * (x - x0), -60, 120), clamp(up0 + (y0 - y), -60, 60)
                    end }
            end
        end
    end
end

extras.Loaded("PartyPortraits")
