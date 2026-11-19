local _, extras = ...
local DUI = DaylightUI
local social = extras.Compatible("Social")
local friends = social and social.Friends
local rows = DUI.Lfg and DUI.Lfg.Rows
if not (friends and friends.Sub and rows and rows.ClassWord) then return end

local nativeSubtitle = friends.Sub
function friends.Sub(friend, ...)
    local subtitle = nativeSubtitle(friend, ...)
    if not friend.char or friend.status == "off" then return subtitle end

    local class = type(friend.class) == "string" and rows.ClassWord(friend.class:upper()) or ""
    local race = friend.race or ""
    local details = race ~= "" and class ~= "" and (race .. " " .. class) or race .. class
    if details == "" then return subtitle end
    return subtitle ~= "" and (details .. " · " .. subtitle) or details
end

extras.Loaded("FriendDetails")
