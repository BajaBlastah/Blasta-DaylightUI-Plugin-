-- Blasta (DaylightUI Plugin): registers the plugin, its settings and the /blasta command with DaylightUI.
-- A plugin: it runs on top of DaylightUI through DaylightUI.API only (see DaylightUI's API.md).
-- Blasta no longer skins other addons; AddonSkins by Glowey_ does that.

local ADDON, ns = ...

local DUI = _G.DaylightUI
local API = DUI and DUI.API
if not API or API.major ~= 1 then return end

ns.API = API
ns.ok = true

local defaults = {}

local function Guard(fn, ...)
	return xpcall(fn, geterrorhandler(), ...)
end
ns.Guard = Guard

-- Settings, kept in the player's DaylightUI profile. `pages` (Options.lua) go in this plugin's
-- own section of the options window, under the Plugins heading.
local function migrateProfiles()
	local old = "DaylightAddonSkins"
	for _, profile in pairs(DUI.DB.Root().profileData) do
		local modules = type(profile) == "table" and profile.modules
		if type(modules) == "table" and ns.MigratePortraitShape then ns.MigratePortraitShape(profile) end
		local previous = type(modules) == "table" and modules[old]
		if type(previous) == "table" then
			if type(modules[ADDON]) == "table" then
				DUI.DB.MergeDefaults(modules[ADDON], previous)
			else
				modules[ADDON] = previous
			end
			modules[old] = nil
		end
	end
end

local sectionID = "plugin:" .. ADDON

local function stylePluginMenu()
	local navAPI = DUI.OptionsNav
	if not (navAPI and type(navAPI.New) == "function") then return end
	local original = navAPI.New
	function navAPI.New(...)
		local nav = original(...)
		if not (nav and nav.listTitle and nav.sectionButtons and nav.pageButtons and nav.Layout) then return nav end
		local layout = nav.Layout
		local title = nav.listTitle
		function nav.Layout(state)
			layout(state)
			-- The section heading: just "Blasta" in its colors, at DaylightUI's
			-- own size (DaylightUI leaves the "(DaylightUI Plugin)" tag out here).
			if state.section == sectionID then
				title:SetText(ns.BlastaGradient("Blasta"))
			end
			local button = nav.sectionButtons[sectionID]
			if button and button.text then button.text:SetText(ns.BlastaGradient("Blasta")) end
			for _, section in ipairs(state.sections or {}) do
				if section.id == sectionID then
					for _, page in ipairs(section.pages) do
						local row = nav.pageButtons[page.id]
						if row and row.text and not row.blastaGradient then
							row.text:SetText(ns.BlastaGradient(row.text:GetText() or ""))
							row.blastaGradient = true
						end
					end
					break
				end
			end
		end
		return nav
	end
end

function ns.RegisterSettings(pages)
	defaults.auraReminder = ns.AuraReminderDefaults
	defaults.experienceStyle = ns.ExperienceDefaults
	defaults.squareSpellbookIcons = false
	defaults.characterPanel = ns.CharacterPanelDefaults
	defaults.zoneTitleExtras = ns.ZoneTitleExtrasDefaults
	defaults.dispelOverlay = false
	defaults.dungeonFinder = false
	defaults.compatNotice = ""
	defaults.blastaBags = false
	defaults.blastaLoot = ns.LootFeedDefaults
	defaults.rageNeed = ns.RageNeedDefaults
	defaults.consumableBars = ns.ConsumableBarDefaults
	defaults.moments = ns.MomentsDefaults
	defaults.blastaDispelOnlyMine = false
	Guard(function()
		migrateProfiles()
		DUI:RegisterPlugin(ADDON, {
			needs = { 1, 1 },
			short = "Blasta",
			icon = "Interface\\AddOns\\" .. ADDON .. "\\Media\\BlastaMenuIcon.tga",
			color = { 1, 1, 1 },
			blurb = "More settings and refinements for DaylightUI.",
		})
		DUI:RegisterModule(ADDON, { plugin = ADDON, label = "Blasta", defaults = defaults,
			options = pages and { pages = pages } or nil })
		stylePluginMenu()
		SLASH_DAYLIGHTBLASTA1 = "/blasta"
		SlashCmdList.DAYLIGHTBLASTA = function(msg)
			if type(msg) == "string" and msg:lower():match("^%s*report") and ns.Report then
				ns.Report.Show()
				return
			end
			-- Other Blasta parts' commands (/blasta apply ...).
			if type(msg) == "string" then
				for _, handle in ipairs(ns.SlashHandlers or {}) do
					local ok, done = pcall(handle, msg)
					if ok and done then return end
				end
			end
			if DUI.OptionsPanel and DUI.OptionsPanel.ShowSection then DUI.OptionsPanel.ShowSection(sectionID) end
		end
	end)
end
