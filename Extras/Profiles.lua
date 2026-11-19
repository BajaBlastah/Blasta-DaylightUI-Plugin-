local _, extras = ...
local DUI = DaylightUI
local profiles = DUI.Profiles
if not (profiles and profiles.Snapshot and profiles.Pack and profiles.Unpack and profiles.Check
    and profiles.ShowText and profiles.ShowPaste and profiles.Wrap and profiles.Prompt
    and profiles.Create and profiles.Choose and profiles.CurrentSlot) then return end

local T = extras.Translate
local PREFIX = "!BLASTA1_"
local includeGlobals = false

local function globalSettings()
    local language = DaylightBlastaLanguage
    if language ~= "enUS" and language ~= "deDE" then language = extras.Language end
    return {
        language = language,
        loginMessage = DaylightBlastaLoginMessage ~= false,
        introAtLogin = DaylightBlastaIntroAtLogin ~= false,
        introAtReload = DaylightBlastaIntroAtReload ~= false,
    }
end

local function validGlobals(settings)
    return type(settings) == "table"
        and (settings.language == "enUS" or settings.language == "deDE")
        and type(settings.loginMessage) == "boolean"
        and type(settings.introAtLogin) == "boolean"
        and type(settings.introAtReload) == "boolean"
end

local function exportProfile()
    local text, why = profiles.Pack({ profile = profiles.Snapshot(), blasta = globalSettings() }, PREFIX)
    if not text then
        DUI.Print(string.format(T("Blasta profile export failed: %s"), why))
        return
    end
    profiles.ShowText(T("Export DaylightUI and Blasta"),
        T("Press Ctrl+C to copy the combined profile code."), profiles.Wrap(text))
end

local function readProfile(text)
    local bundle, why = profiles.Unpack(text, PREFIX)
    if not bundle then
        if why == "prefix" then return nil, T("Expected a combined Blasta profile code.") end
        if why == "client" then return nil, T("This game client cannot read profile codes.") end
        return nil, T("The profile code is empty or damaged.")
    end
    local profile = bundle.profile
    if not (validGlobals(bundle.blasta) and type(profile) == "table"
        and type(profile.general) == "table" and type(profile.modules) == "table"
        and type(profile.positions) == "table"
        and (profile.layout == nil or type(profile.layout) == "string")) then
        return nil, T("The combined profile data is incomplete or damaged.")
    end
    for module, settings in pairs(profile.modules) do
        if type(module) ~= "string" or type(settings) ~= "table" then
            return nil, T("The combined profile data is incomplete or damaged.")
        end
    end
    local checked, reason = profiles.Check(profile)
    if not checked then return nil, reason end
    return bundle, T("Combined profile ready. Continue to name the new profile.")
end

local function nameProfile(bundle, importGlobals, initial)
    profiles.Prompt(T("Name the new DaylightUI and Blasta profile."), initial, function(name)
        local created, why = profiles.Create(name, bundle.profile)
        if not created then
            DUI.Print(string.format(T("Blasta profile import failed: %s"), why))
            nameProfile(bundle, importGlobals, name)
            return
        end
        if importGlobals then
            local settings = bundle.blasta
            DaylightBlastaLanguage = settings.language
            DaylightBlastaLoginMessage = settings.loginMessage
            DaylightBlastaIntroAtLogin = settings.introAtLogin
            DaylightBlastaIntroAtReload = settings.introAtReload
        end
        DUI.Print(string.format(T("Imported combined profile %s."), created))
        profiles.Choose(profiles.CurrentSlot(), created)
    end)
end

local function importProfile()
    local importGlobals = includeGlobals
    local hint = importGlobals and "Paste the combined code. Import also changes Blasta's language, login message and startup animations for all profiles."
        or "Paste the combined code to import the profile settings."
    profiles.ShowPaste({
        title = T("Import DaylightUI and Blasta"),
        hint = T(hint),
        read = readProfile,
        button = function() return T("Continue") end,
        go = function(bundle) nameProfile(bundle, importGlobals, "") end,
    })
end

function extras.ProfileTransferPage()
    return { id = "blastaProfiles", label = "Profiles", groups = {
        { label = "Combined profile", items = {
            { type = "button", label = "Export DaylightUI and Blasta", text = "Export profile code",
                blastaSince = "1.5",
                desc = "Copies the active DaylightUI profile and Blasta settings into one shareable code.",
                func = exportProfile },
            { type = "toggle", label = "Include global Blasta settings on import",
                desc = "Also import Blasta's language, login message and both startup animation options for all profiles.",
                get = function() return includeGlobals end,
                set = function(value) includeGlobals = value == true; return true end },
            { type = "button", label = "Import DaylightUI and Blasta", text = "Import profile code",
                blastaSince = "1.5",
                desc = "Creates a new profile from a combined Blasta code. The imported profile can be used after a reload.",
                func = importProfile },
        } },
    } }
end

extras.Loaded("Profiles")
