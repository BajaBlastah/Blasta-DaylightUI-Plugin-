local ADDON, extras = ...
local DUI = DaylightUI
local version = C_AddOns.GetAddOnMetadata(ADDON, "Version")

local clientGerman = GetLocale() == "deDE"
local languages = { enUS = "English", deDE = "Deutsch" }
local defaultLanguage = clientGerman and "deDE" or "enUS"
local function selectedLanguage()
    return languages[DaylightBlastaLanguage] and DaylightBlastaLanguage or defaultLanguage
end

extras.Language = selectedLanguage()
extras.German = setmetatable({}, {
    __newindex = function(self, key, value)
        rawset(self, key, value)
        if clientGerman and rawget(DUI.L, key) == nil then DUI.L[key] = value end
    end,
})

-- Blasta's parts mark themselves when they loaded all the way (Compat.lua).
local loaded = {}
function extras.Loaded(name) loaded[name] = true end
function extras.IsLoaded(name) return loaded[name] == true end

function extras.Translate(key)
    if extras.Language == "deDE" then
        return extras.German[key] or (clientGerman and rawget(DUI.L, key)) or key
    end
    return key
end

local function isNewBlastaSetting(item)
    return item.blastaSince ~= nil and item.blastaSince == version
end

local options = DUI.Options
if options and options.IsNew then
    local isNew = options.IsNew
    function options.IsNew(item)
        if item.blastaSince then return isNewBlastaSetting(item) end
        return isNew(item)
    end
end

local widgets = DUI.Widgets
if widgets and widgets.Row then
    local buildRow = widgets.Row
    function widgets.Row(card, page, group, item)
        local row = buildRow(card, page, group, item)
        if item.blastaDynamicLabel then
            local update = row.Update
            function row.Update()
                if update then update() end
                row.label:SetText(options.Label(item))
            end
        end
        if row.newTag and isNewBlastaSetting(item) then
            row.newTag:SetText(extras.Translate("New"))
            row.newTag:SetTextColor(92 / 255, 249 / 255, 119 / 255)
            row.Measure()
        end
        if item.blastaBadge and item.type ~= "custom" then extras.AddBlastaBadge(row) end
        return row
    end
end

-- Daylight resolves option strings through its own locale. Scope Blasta's
-- resolved strings so that a language override never changes native menus.
local menuKeys = {}
local function menuText(value)
    if type(value) ~= "string" then return value end
    local key = "DaylightBlasta:menu:" .. value
    if not menuKeys[key] then
        menuKeys[key] = value
        DUI.L[key] = extras.Translate(value)
    end
    return key
end

-- Search: DaylightUI matches the stored text and its translation. Blasta's
-- stored text is a scoped key ("DaylightBlasta:menu:..."), so every search
-- for "menu" or "blasta" found every Blasta row. Blasta's rows match their
-- English text and the language Blasta shows instead.
if options and options.Matches then
    local matches = options.Matches
    local PREFIX = "DaylightBlasta:menu:"
    local function scoped(v) return type(v) == "string" and v:sub(1, #PREFIX) == PREFIX end
    local function has(v, query)
        if type(v) ~= "string" then return false end
        local english = menuKeys[v] or v
        if english:lower():find(query, 1, true) then return true end
        local shown = DUI.L[v]
        return type(shown) == "string" and shown ~= v and shown:lower():find(query, 1, true) ~= nil
    end
    function options.Matches(group, item, query)
        if not (scoped(item.label) or scoped(item.desc) or scoped(group and group.label)) then
            return matches(group, item, query)
        end
        if query == nil or query == "" then return true end
        if item.type == "text" or item.type == "custom" or item.noSearch then return false end
        query = query:lower()
        return has(item.label, query) or has(item.desc, query) or has(item.text, query)
            or has(group and group.label, query)
    end
end

-- SavedVariables may be populated after the Lua files have been read.
local languageLoader = CreateFrame("Frame")
languageLoader:RegisterEvent("ADDON_LOADED")
languageLoader:SetScript("OnEvent", function(self, _, addon)
    if addon ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    extras.Language = selectedLanguage()
    for key, value in pairs(menuKeys) do DUI.L[key] = extras.Translate(value) end
end)

local function menuValues(values)
    if not values then return end
    local translated = {}
    for key, value in pairs(values) do translated[key] = menuText(value) end
    return translated
end

local function localizeText(option, field)
    local value = option[field]
    if type(value) == "function" then
        option[field] = function(...) return menuText(value(...)) end
    else
        option[field] = menuText(value)
    end
end

function extras.LocalizePages(pages)
    for _, page in ipairs(pages) do
        localizeText(page, "label")
        localizeText(page, "desc")
        for _, group in ipairs(page.groups) do
            localizeText(group, "label")
            localizeText(group, "desc")
            localizeText(group, "tab")
            for _, row in ipairs(group.items) do
                if row.blastaSince then row.since = isNewBlastaSetting(row) and row.blastaSince or nil end
                localizeText(row, "label")
                localizeText(row, "desc")
                localizeText(row, "text")
                localizeText(row, "shownAs")
                local choices = row.choices
                if choices then
                    row.choices = function(...)
                        local values, order, titles = choices(...)
                        return menuValues(values), order, titles
                    end
                elseif row.values then
                    local values, order = row.values, row.order
                    row.choices = function()
                        return menuValues(values), order or DUI.Widgets.SortedKeys(values)
                    end
                end
            end
        end
    end
end

local function loginMessageEnabled()
    return DaylightBlastaLoginMessage ~= false
end

local fade = DUI.Fade
local canSkipIntro = fade and type(fade.SkipIntro) == "function" and type(fade.RevealComing) == "function"

local function skipIntro()
    local revealComing = fade.RevealComing
    -- SkipIntro finishes the area fades but also calls Reveal through StartIntro.
    fade.RevealComing = function() return false end
    local ok, err = pcall(fade.SkipIntro)
    fade.RevealComing = revealComing
    if not ok then geterrorhandler()(err) end
end

if canSkipIntro then
    DUI.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, initialLogin, reloadingUI)
        if (reloadingUI and DaylightBlastaIntroAtReload == false)
            or (not reloadingUI and initialLogin and DaylightBlastaIntroAtLogin == false) then
            skipIntro()
        end
    end, true)
end

local bajaColors = { { 76, 146, 255 }, { 15, 252, 209 }, { 211, 255, 82 } }
if widgets and widgets.toggle then
    hooksecurefunc(widgets, "toggle", function(row, page)
        if not page or page.scope ~= ADDON then return end
        local switch = row.control
        if not (switch and switch.track and switch.SetOn and switch.CreateMaskTexture) then return end
        local track = switch.track
        local mask = switch:CreateMaskTexture()
        mask:SetAllPoints(track)
        mask:SetTexture(track:GetTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        local fills = {}
        for i = 1, 2 do
            local fill = switch:CreateTexture(nil, "ARTWORK", nil, 1)
            if i == 1 then
                fill:SetPoint("TOPLEFT", track, "TOPLEFT")
                fill:SetPoint("BOTTOMRIGHT", track, "BOTTOM")
            else
                fill:SetPoint("TOPLEFT", track, "TOP")
                fill:SetPoint("BOTTOMRIGHT", track, "BOTTOMRIGHT")
            end
            local a, b = bajaColors[i], bajaColors[i + 1]
            fill:SetColorTexture(1, 1, 1, 1)
            fill:SetGradient("HORIZONTAL", CreateColor(a[1]/255, a[2]/255, a[3]/255, 1),
                CreateColor(b[1]/255, b[2]/255, b[3]/255, 1))
            fill:AddMaskTexture(mask)
            fill:Hide()
            fills[i] = fill
        end
        hooksecurefunc(switch, "SetOn", function(on)
            for _, fill in ipairs(fills) do fill:SetShown(on == true and not switch.off) end
        end)
    end)
end

function extras.BlastaGradient(message, palette)
    palette = palette or bajaColors
    local segments = #palette - 1
    local chars, colored = {}, {}
    for ch in message:gmatch("[%z\1-\127\194-\244][\128-\191]*") do chars[#chars + 1] = ch end
    for i, ch in ipairs(chars) do
        local t = segments * (i - 1) / math.max(1, #chars - 1)
        local stop = math.min(math.floor(t) + 1, segments)
        local from, to = palette[stop], palette[stop + 1]
        local blend = t - (stop - 1)
        -- Each character closes its own color: chat frames don't keep a long
        -- stack of open colors, and the whole line would show the first one.
        colored[i] = ("|cff%02x%02x%02x%s|r"):format(
            math.floor(from[1] + (to[1] - from[1]) * blend + 0.5),
            math.floor(from[2] + (to[2] - from[2]) * blend + 0.5),
            math.floor(from[3] + (to[3] - from[3]) * blend + 0.5), ch)
    end
    return table.concat(colored)
end

-- Blasta rows that stay in DaylightUI's own menus carry a small "BLASTA"
-- badge in Blasta's colors right after their label, so players can tell
-- which settings come from the plugin.
function extras.AddBlastaBadge(row)
    if row.blastaBadge or not (widgets and widgets.Font and row.label) then return end
    local badge = widgets.Font(row, widgets.TITLE or widgets.BODY, 9)
    badge:SetText(extras.BlastaGradient("BLASTA"))
    row.blastaBadge = badge
    local gap = 6
    local room = math.ceil(badge:GetStringWidth() or 0) + gap
    if row.control then
        local newRoom = row.newTag and (math.ceil(row.newTag:GetStringWidth() or 0) + gap) or 0
        row.label:SetPoint("RIGHT", row.extras or row.control, "LEFT",
            -((widgets.LABEL_GAP or 36) + newRoom + room), 0)
    end
    local function place()
        local label = row.label
        local text = label.GetUnboundedStringWidth and label:GetUnboundedStringWidth() or label:GetStringWidth() or 0
        local width = label:GetWidth() or 0
        if width > 0 and text > width then text = width end
        local x = math.ceil(text) + gap
        if row.newTag and row.newTag:IsShown() then x = x + math.ceil(row.newTag:GetStringWidth() or 0) + gap end
        badge:ClearAllPoints()
        badge:SetPoint("LEFT", label, "LEFT", x, 0)
    end
    local measure, update = row.Measure, row.Update
    function row.Measure()
        if measure then measure() end
        place()
    end
    function row.Update()
        if update then update() end
        place()
    end
    place()
end

local loginColors = { bajaColors[1], bajaColors[2], { 92, 249, 119 }, bajaColors[3] }
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_ENTERING_WORLD")
login:SetScript("OnEvent", function(self, _, initialLogin, reloadingUI)
    if not (initialLogin or reloadingUI) then return end
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if loginMessageEnabled() then
        local title = ("Blasta (DaylightUI Plugin): Version %s"):format(version or "?")
        local greeting = extras.Translate("Thanks for playing! Menu via /blasta.")
        DEFAULT_CHAT_FRAME:AddMessage(extras.BlastaGradient(title .. " – " .. greeting, loginColors))
    end
end)

function extras.GeneralPage()
    local page = { id = "language", label = "General", groups = {
        { label = "Language", items = {
            { type = "dropdown", label = "Blasta language", values = languages, order = { "enUS", "deDE" },
                get = selectedLanguage,
                set = function(value)
                    if not languages[value] then return false end
                    if value == selectedLanguage() then return true end
                    DaylightBlastaLanguage = value
                    if value ~= extras.Language then
                        DEFAULT_CHAT_FRAME:AddMessage("Blasta: " .. extras.Translate("Type /reload to apply the language change."))
                    end
                    return true
                end,
                default = function() return defaultLanguage end,
                desc = "Changes Blasta's language for all profiles. Type /reload to apply." },
        } },
        { label = "Chat", items = {
            { type = "toggle", label = "Show Blasta login message", get = loginMessageEnabled,
                set = function(value) DaylightBlastaLoginMessage = value; return true end,
                default = function() return true end,
                desc = "Show a welcome message in chat at login and after reloading the interface." },
        } },
    } }
    if canSkipIntro then
        page.groups[#page.groups + 1] = { label = "Startup animation", items = {
            { type = "toggle", label = "Show animation at login",
                get = function() return DaylightBlastaIntroAtLogin ~= false end,
                set = function(value)
                    DaylightBlastaIntroAtLogin = value
                    DUI.Fire("SettingChanged", ADDON, "introAtLogin", value)
                    return true
                end,
                default = function() return true end,
                desc = "Allow DaylightUI's startup animation when logging into a character." },
            { type = "toggle", label = "Show animation after reload",
                get = function() return DaylightBlastaIntroAtReload ~= false end,
                set = function(value)
                    DaylightBlastaIntroAtReload = value
                    DUI.Fire("SettingChanged", ADDON, "introAtReload", value)
                    return true
                end,
                default = function() return true end,
                desc = "Allow DaylightUI's startup animation after reloading the interface." },
        } }
    end
    return page
end

-- Outline flags for Blasta's own SetFont calls. DaylightUI 1.9.5 draws its
-- outlined text with the game's slug renderer (Style.Slug); Blasta's text
-- follows so both look equally crisp. Older DaylightUI: flags unchanged.
function extras.Outline(flags)
    local slug = DUI.Style and DUI.Style.Slug
    if type(slug) ~= "function" then return flags end
    local ok, out = pcall(slug, flags)
    return ok and type(out) == "string" and out or flags
end

-- Each integration checks the methods and tables it needs before hooking them.
function extras.Compatible(name)
    local mod = DUI:GetModule(name)
    return mod and mod.ns
end

function extras.FindSetting(mod, key)
    for _, page in ipairs(mod and mod.options and mod.options.pages or {}) do
        for _, group in ipairs(page.groups or {}) do
            for i, row in ipairs(group.items or {}) do
                if row.key == key then return row, group.items, i end
            end
        end
    end
end

function extras.AddSetting(mod, anchor, row, before)
    if extras.FindSetting(mod, row.key) then return end
    local _, items, index = extras.FindSetting(mod, anchor)
    if items then
        row.blastaJumpAnchor = anchor
        table.insert(items, before and index or index + 1, row)
    end
end

-- Read the native schema before registering a fallback for the same field.
function extras.HasSetting(mod, key)
    return extras.FindSetting(mod, key) ~= nil or DUI.DB.GetPath(mod.defaults, key) ~= nil
end

local function frameShape(settings)
    if settings.frameShape == "square" or settings.frameShape == "rounded" then return settings.frameShape end
    local legacy = tonumber(settings.radius)
    if legacy and legacy >= 0 then return legacy > 0 and "rounded" or "square" end
end

function extras.FrameCornerOverride(settings)
    local shape = frameShape(settings)
    if shape == "square" then return 0 end
    if shape == "rounded" then
        local current = DUI.DB.General().cornerPx or 0
        return current > 0 and current or DUI.DB.GENERAL_DEFAULTS.cornerPx
    end
end

function extras.FrameShapeOption(addon, root, getConfig)
    local key = root .. ".frameShape"
    -- Another addon can leave the general setting empty (e.g. after logout strips defaults).
    local function inherited() return (tonumber(DUI.DB.General().cornerPx) or DUI.DB.GENERAL_DEFAULTS.cornerPx or 0) > 0 and "rounded" or "square" end
    return {
        type = "dropdown", key = key, label = "Frame shape",
        values = { square = "Square", rounded = "Rounded" }, order = { "square", "rounded" },
        get = function() return frameShape(getConfig()) or inherited() end,
        set = function(value) return DUI:Set(addon, key, value) end,
        default = inherited,
    }
end
