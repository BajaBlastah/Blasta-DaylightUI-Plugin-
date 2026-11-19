-- SPDX-License-Identifier: GPL-3.0-or-later
-- Each profession tab in DaylightUI's profession window shows its skill in
-- small text under the name ("172/225"). At its rank's limit it turns orange:
-- the next rank is at the trainer. Hovering a tab lists rank, the next rank's
-- level and every profession the character has, gathering ones and fishing
-- included (they have no window, so no tab).
local ADDON, extras = ...
local DUI = DaylightUI
local craft = DUI.Craft
local window, data = craft and craft.Window, craft and craft.Data
local Style, Tips = DUI.Style, DUI.Tips
local mod = DUI:GetModule("Professions")
if not (mod and mod.defaults and window and window.Show and window.Refreshed and window.MakeTabs
    and data and data.Tabs and data.Profession and Style and Style.Text and Style.InkText and Style.SIZE
    and Style.INK and Tips and Tips.Clear and Tips.Title and Tips.Line and Tips.Text and Tips.Flush
    and extras.FindSetting(mod, "rarityNames")) then return end

local T = extras.Translate
local german = extras.German
local KEY = "blastaTabSkill"
mod.defaults[KEY] = true

german["Skill in the profession tabs"] = "Fertigkeit in den Berufsreitern"
german["Each profession tab shows its skill under the name. Orange: the rank's limit is reached, the next rank is at the trainer. Hover a tab for every profession, gathering ones included."] =
    "Jeder Berufsreiter zeigt seine Fertigkeit unter dem Namen. Orange: Das Limit des Rangs ist erreicht, der nächste Rang wartet beim Lehrer. Fahr über einen Reiter, um alle Berufe zu sehen, auch Sammelberufe."
german["Apprentice"], german["Journeyman"], german["Expert"], german["Artisan"] = "Lehrling", "Geselle", "Experte", "Fachmann"
german["Rank"] = "Rang"
german["Skill"] = "Fertigkeit"
german["At the limit: learn %s from a trainer (from level %d)."] = "Am Limit: Lerne %s beim Lehrer (ab Stufe %d)."
german["At the limit: the next rank is at the trainer."] = "Am Limit: Der nächste Rang wartet beim Lehrer."
german["Fully trained."] = "Voll ausgebildet."
german["All professions"] = "Alle Berufe"

extras.AddSetting(mod, "rarityNames", {
    type = "toggle", key = KEY, label = "Skill in the profession tabs",
    desc = "Each profession tab shows its skill under the name. Orange: the rank's limit is reached, the next rank is at the trainer. Hover a tab for every profession, gathering ones included.",
})

local function on() return DUI:Get(mod.name, KEY) ~= false end
local function readable(v) return type(v) == "number" and not (issecretvalue and issecretvalue(v)) end

-- Classic ranks: the limit each one gives, and the level its next rank needs.
local RANK_OF = { [75] = "Apprentice", [150] = "Journeyman", [225] = "Expert", [300] = "Artisan" }
local NEXT = { [75] = { "Journeyman", 10 }, [150] = { "Expert", 20 }, [225] = { "Artisan", 35 } }
local TOP = 300

-- skill, limit -> "capped" (rank done, more at the trainer), "done" (all of it) or nil.
local function state(skill, max)
    if not (readable(skill) and readable(max) and max > 0 and skill >= max) then return nil end
    return max >= TOP and "done" or "capped"
end

-- Every profession the character has, with or without a window.
local function allProfessions()
    local out = {}
    if type(GetProfessions) ~= "function" or type(GetProfessionInfo) ~= "function" then return out end
    local list = { GetProfessions() }
    for i = 1, 6 do
        local idx = list[i]
        if idx then
            local ok, name, _, rank, max = pcall(GetProfessionInfo, idx)
            if ok and type(name) == "string" and readable(rank) and readable(max) then
                out[#out + 1] = { name = name, rank = rank, max = max }
            end
        end
    end
    return out
end

-- The tab's numbers: the open profession as its header shows them (bonus
-- included), the others from the game's profession list.
local function numbers(tab, open)
    if open and open.id == tab.skillLine then
        return (open.skill or 0) + (open.bonus or 0), open.max or 0
    end
    return tab.rank or 0, tab.max or 0
end

local labels = setmetatable({}, { __mode = "k" })   -- tab button -> its skill text
local tabInfo = setmetatable({}, { __mode = "k" })  -- tab button -> { name, skill, max }

local function tip(b)
    local info = tabInfo[b]
    if not (on() and info and GameTooltip) then return end
    GameTooltip:SetOwner(b, "ANCHOR_BOTTOM", 0, -4)
    Tips.Clear()
    Tips.Title(info.name)
    Tips.Line(T("Skill"), string.format("%d / %d", info.skill, info.max))
    local rank = RANK_OF[info.max]
    if rank then Tips.Line(T("Rank"), T(rank)) end
    local s = state(info.skill, info.max)
    if s == "capped" then
        local nextRank = NEXT[info.max]
        local text = nextRank and string.format(T("At the limit: learn %s from a trainer (from level %d)."), T(nextRank[1]), nextRank[2])
            or T("At the limit: the next rank is at the trainer.")
        Tips.Text(text, Style.INK.WARN)
    elseif s == "done" then
        Tips.Text(T("Fully trained."), Style.INK.GOOD)
    end
    local all = allProfessions()
    if #all > 1 then
        if Tips.Gap then Tips.Gap() end
        if Tips.Sub then Tips.Sub(T("All professions")) end
        for _, p in ipairs(all) do
            local ps = state(p.rank, p.max)
            local color = ps == "capped" and Style.INK.WARN or ps == "done" and Style.INK.GOOD or nil
            Tips.Line(p.name, string.format("%d / %d", p.rank, p.max), color)
        end
    end
    Tips.Flush(GameTooltip)
    GameTooltip:Show()
end

local function labelOf(b)
    local fs = labels[b]
    if fs then return fs end
    fs = Style.Text(b, Style.SIZE.tiny, "CENTER")
    fs:SetPoint("TOP", b, "BOTTOM", 0, -1)
    fs:SetWordWrap(false)
    labels[b] = fs
    b:HookScript("OnEnter", tip)
    b:HookScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    return fs
end

local function paint()
    local f = window.frame
    if not (f and f.tabs) then return end
    local show = on()
    local byLine = {}
    for _, t in ipairs(data.Tabs()) do byLine[t.skillLine] = t end
    local open = data.Profession()
    -- A linked profession (someone else's) shows their numbers in the header;
    -- the tabs stay the player's own.
    if open and data.Viewing and data.Viewing() then open = nil end
    for _, b in ipairs(f.tabs) do
        local tab = byLine[b.id]
        local fs = labelOf(b)
        if show and tab then
            local skill, max = numbers(tab, open)
            tabInfo[b] = { name = tab.name, skill = skill, max = max }
            fs:SetText(max > 0 and string.format("%d/%d", skill, max) or "")
            local s = state(skill, max)
            Style.InkText(fs, s == "capped" and "WARN" or s == "done" and "GOOD" or "LABEL", s and 1 or 0.85)
            fs:Show()
        else
            tabInfo[b] = tab and { name = tab.name, skill = tab.rank or 0, max = tab.max or 0 } or nil
            fs:Hide()
        end
    end
end

local function after(name)
    local original = window[name]
    window[name] = function(...)
        local a, b, c = original(...)
        pcall(paint)
        return a, b, c
    end
end
after("Show")
after("Refreshed")
after("MakeTabs")

DUI.RegisterEvent("SKILL_LINES_CHANGED", function() pcall(paint) end)
DUI.On("SettingChanged", function(scope, path)
    if scope == mod.name and path == KEY then pcall(paint) end
end)

extras.Loaded("ProfessionSkills")
