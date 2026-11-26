-- SPDX-License-Identifier: GPL-3.0-or-later
-- Which of Blasta's parts this DaylightUI version lets run.
-- Every part checks at load that the DaylightUI pieces it hooks are there and
-- quietly stays off otherwise. Each one that got all the way through called
-- extras.Loaded (Extras/Core.lua). After login Blasta compares that with the
-- list below: a part that stayed off although its DaylightUI module is loaded
-- most likely needs an update for this DaylightUI. Blasta says so once in chat
-- per DaylightUI version, "/blasta check" lists it again, and the bug report
-- carries it.
local ADDON, extras = ...
local DUI = DaylightUI

local Compat = {}
extras.Compat = Compat

Compat.PARTS = {
    { file = "Profiles", label = "Combined profile", de = "Gemeinsames Profil", needs = {  } },
    { file = "PortraitShapes", label = "Portrait shapes", de = "Porträtformen", needs = { "UnitFrames" } },
    { file = "PartyPortraits", label = "Party portraits", de = "Gruppenporträts", needs = { "UnitFrames" } },
    { file = "PartyPowerBar", label = "Compact party resource bar", de = "Kompakte Ressourcenleiste der Gruppe", needs = { "UnitFrames" } },
    { file = "BarTextSizes", label = "Bar text sizes", de = "Textgrößen der Leisten", needs = { "UnitFrames" } },
    { file = "SwingTimer", label = "Swing timer", de = "Schlagtimer", needs = { "UnitFrames" } },
    { file = "ConsumableBars", label = "Flask and food bars", de = "Fläschchen- und Essensleisten", needs = { "UnitFrames" } },
    { file = "Moments", label = "Moments", de = "Momente", needs = { "UnitFrames" } },
    { file = "FinisherTint", label = "Finisher damage color", de = "Farbe für Finisher-Schaden", needs = { "UnitFrames" } },
    { file = "DotHatching", label = "DoT hatching", de = "DoT-Schraffur", needs = { "UnitFrames" } },
    { file = "ShadowWordDeath", label = "Shadow Word: Death hint", de = "Hinweis für Schattenwort: Tod", needs = { "UnitFrames" } },
    { file = "AfkScreen", label = "AFK screen", de = "AFK-Bildschirm", needs = { "QoL" } },
    { file = "BarVisuals", label = "Bar animations", de = "Leistenanimationen", needs = { "UnitFrames" } },
    { file = "LevelBadges", label = "Level badges", de = "Stufenabzeichen", needs = { "UnitFrames" } },
    { file = "PortraitIconOffsets", label = "Portrait icon positions", de = "Positionen der Porträt-Symbole", needs = { "UnitFrames" } },
    { file = "TargetMarkerRing", label = "Raid marker ring", de = "Markierungsring am Porträt", needs = { "UnitFrames" } },
    { file = "WhatsNew", label = "What's new pages", de = "Neuigkeiten-Seiten", needs = {  } },
    { file = "Tour", label = "Blasta tour", de = "Blasta-Tour", needs = {  } },
    { file = "AuraFit", label = "Aura fitting", de = "Aura-Einpassung", needs = { "UnitFrames" } },
    { file = "AuraBars", label = "Aura bars", de = "Aura-Leisten", needs = { "Buffs", "UnitFrames" } },
    { file = "TargetAuraShape", label = "Square target auras", de = "Eckige Ziel-Auren", needs = { "UnitFrames" } },
    { file = "Databar", label = "Data text colors", de = "Farben der Datentexte", needs = { "InfoPanel" } },
    { file = "TopRightLayout", label = "Minimap buff layout", de = "Buff-Anordnung an der Minimap", needs = { "Buffs", "InfoPanel" } },
    { file = "DispelHighlights", label = "Dispel highlight", de = "Bannen-Hervorhebung", needs = { "UnitFrames" } },
    { file = "ExperienceBar", label = "Experience bar", de = "Erfahrungsleiste", needs = { "InfoPanel" } },
    { file = "ExperienceGain", label = "Experience gain animation", de = "Animation für Erfahrungsgewinn", needs = { "InfoPanel" } },
    { file = "Coins", label = "Coins in prices", de = "Münzen in Preisen", needs = { "Tooltip" } },
    { file = "BlastaTooltips", label = "Blasta tooltips", de = "Blasta-Tooltips", needs = { "Tooltip" } },
    { file = "QuestTracker", label = "Quest tracker", de = "Questverfolgung", needs = { "Quests" } },
    { file = "Spellbook", label = "Spellbook", de = "Zauberbuch", needs = {  } },
    { file = "TrainingTotal", label = "Training total", de = "Gesamtkosten beim Lehrer", needs = {  } },
    { file = "CcRing", label = "Crowd control alert as a ring", de = "Kontrollverlust als Ring", needs = { "Skins" } },
    { file = "ChatWhisper", label = "Whisper conversation from the chat's edge", de = "Flüster-Gespräch aus dem Chat-Rand", needs = { "Chat" } },
    { file = "TalentRows", label = "Talent row thresholds", de = "Talentreihen mit Punkten", needs = {  } },
    { file = "TalentStyle", label = "Talent layout", de = "Talentansicht", needs = { "Book" } },
    { file = "FriendDetails", label = "Friend details", de = "Freundesdetails", needs = { "Social" } },
    { file = "DungeonFilters", label = "Dungeon finder filters", de = "Filter im Dungeonbrowser", needs = {  } },
    { file = "LootFeed", label = "Loot feed", de = "Beuteanzeige", needs = { "QoL" } },
    { file = "BagsOrganize", label = "Bag organizing", de = "Taschen sortieren", needs = { "Bags" } },
    { file = "CharacterPanel", label = "Character window", de = "Charakterfenster", needs = {  } },
    { file = "CraftShine", label = "Craft shine", de = "Glanz beim Herstellen", needs = { "Professions" } },
    { file = "RecipeChance", label = "Recipe skill-up chance", de = "Chance auf Fertigkeitspunkte", needs = { "Professions" } },
    { file = "TravelRoutes", label = "Travel routes", de = "Reiserouten", needs = { "Skins" } },
    { file = "ZoneTitleExtras", label = "Zone title extras", de = "Extras beim Gebietstitel", needs = { "QoL" } },
    { file = "NameplateBorders", label = "Nameplate borders", de = "Ränder der Namensplaketten", needs = { "Nameplates" } },
    { file = "NameplateShape", label = "Nameplate shape", de = "Form der Namensplaketten", needs = { "Nameplates" } },
    { file = "NameplateAuraMotion", label = "Nameplate aura motion", de = "Bewegung der Plaketten-Auren", needs = { "Nameplates" } },
    { file = "NameplateAuraSizes", label = "Nameplate aura sizes", de = "Größe der Plaketten-Auren", needs = { "Nameplates" } },
    { file = "NameplateThreat", label = "Nameplate threat gradient", de = "Bedrohungsfarbverlauf der Namensplaketten", needs = { "Nameplates" } },
    { file = "NameplateNames", label = "Abbreviated target names", de = "Gekürzte Zielnamen", needs = { "UnitFrames" } },
    { file = "BagBorders", label = "Bag borders", de = "Taschenränder", needs = { "Bags" } },
    { file = "ActionBarPixels", label = "Pixel-exact action buttons", de = "Pixelgenaue Aktionstasten", needs = { "ActionBars" } },
    { file = "ActionBarSlants", label = "Action bar slants", de = "Schräge Aktionsleisten", needs = { "ActionBars", "UnitFrames" } },
    { file = "BarFxPresets", label = "Blasta bar animations", de = "Blasta-Leistenanimationen", needs = {  } },
    { file = "ChannelTicks", label = "Channel ticks", de = "Kanalisierungs-Ticks", needs = { "Nameplates", "UnitFrames" } },
    { file = "DesignParts", label = "Design mode parts", de = "Teile für den Design-Modus", needs = { "UnitFrames", "Nameplates" } },
    { file = "InterruptHint", label = "Interrupt hint", de = "Unterbrechungs-Hinweis", needs = { "Nameplates" } },
    { file = "ProfessionTabs", label = "Profession tabs", de = "Berufsreiter", needs = {  } },
    { file = "TrainerRecipes", label = "Learnable recipes", de = "Lernbare Rezepte", needs = { "Professions" } },
    { file = "ProfessionOverview", label = "Professions panel", de = "Berufsleiste", needs = { "Professions" } },
}

for _, part in ipairs(Compat.PARTS) do extras.German[part.label] = part.de end
extras.German["Not active with this DaylightUI version:"] = "Mit dieser DaylightUI-Version nicht aktiv:"
extras.German["All Blasta parts work with this DaylightUI version."] = "Alle Blasta-Teile funktionieren mit dieser DaylightUI-Version."
extras.German["Probably needs a Blasta update. /blasta report adds this to a bug report."] =
    "Braucht vermutlich ein Blasta-Update. /blasta report fügt das einem Fehlerbericht hinzu."

local function present(needs)
    for _, name in ipairs(needs) do
        if not DUI:GetModule(name) then return false end
    end
    return true
end

-- The parts that stayed off although what they need is loaded, in list order.
function Compat.Inactive()
    local out = {}
    for _, part in ipairs(Compat.PARTS) do
        if not extras.IsLoaded(part.file) and present(part.needs) then out[#out + 1] = part end
    end
    return out
end

function Compat.Labels(english)
    local out = {}
    for _, part in ipairs(Compat.Inactive()) do
        out[#out + 1] = english and part.label or extras.Translate(part.label)
    end
    return out
end

local function say(text) DEFAULT_CHAT_FRAME:AddMessage("|cff34bcedBlasta|r: " .. text) end

-- quiet: only when something is off (the login check).
function Compat.Print(quiet)
    local labels = Compat.Labels()
    if #labels == 0 then
        if not quiet then say(extras.Translate("All Blasta parts work with this DaylightUI version.")) end
        return
    end
    say(extras.Translate("Not active with this DaylightUI version:") .. " " .. table.concat(labels, ", "))
    say(extras.Translate("Probably needs a Blasta update. /blasta report adds this to a bug report."))
end

local function daylightVersion()
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local ok, v = pcall(get, "DaylightUI", "Version")
    return tostring(DUI.VERSION or (ok and v) or "?")
end

-- Once per DaylightUI version and set of inactive parts.
local function loginCheck()
    local labels = Compat.Labels(true)
    if #labels == 0 then return end
    local seen = daylightVersion() .. ":" .. table.concat(labels, ",")
    local ok, last = pcall(DUI.Get, DUI, ADDON, "compatNotice")
    if ok and last == seen then return end
    Compat.Print(true)
    pcall(DUI.Set, DUI, ADDON, "compatNotice", seen)
end

extras.SlashHandlers = extras.SlashHandlers or {}
table.insert(extras.SlashHandlers, function(msg)
    if not msg:lower():match("^%s*check") then return false end
    Compat.Print(false)
    return true
end)

DUI.On("Login", function() C_Timer.After(3, function() pcall(loginCheck) end) end)
