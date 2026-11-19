local _, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("Quests")
if not ns then return end

local mod = DUI:GetModule("Quests")
local journal = ns.Journal
if journal and type(journal.Do) == "function" and type(journal.CanAbandon) == "function"
    and type(journal.AbandonPopup) == "function" and extras.FindSetting(mod, "journal") then
    local key = "blastaQuickQuestAbandon"
    mod.defaults[key] = false
    extras.AddSetting(mod, "journal", {
        type = "toggle", key = key, label = "Quick quest abandonment",
        desc = "Show a confirmation directly when you choose Abandon in the quest log's right-click menu.",
    })

    local original = journal.Do
    function journal.Do(action, quest)
        if action ~= "abandon" or not (mod.db and mod.db[key] and StaticPopupDialogs and StaticPopup_Show) then
            return original(action, quest)
        end
        if quest and journal.CanAbandon(quest) then return journal.AbandonPopup(quest) end
    end
end

-- The quest level beside the title is DaylightUI's own now ("Quest levels in
-- the tracker" and "Show quest levels in the quest log").

extras.Loaded("QuestTracker")
