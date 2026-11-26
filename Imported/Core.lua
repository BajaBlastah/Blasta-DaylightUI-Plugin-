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

-- Settings, kept in the player's DaylightUI profile. `pages` (Options.lua) go in this plugin's
-- own section of the options window, under the Plugins heading.
-- Blasta's breath bar edges and its "Reverse unit frame slant" became
-- DaylightUI 2.4.0's own settings, one per bar end: the saved choices move
-- there once DaylightUI has them, so nothing looks different.
local REVERSED_UNITS = { "player", "target", "targettarget", "focus", "pet", "party", "partyPet", "raid", "arena" }
local function endFor(direction) -- Blasta's "straight" | "top" | "bottom" -> angled, flipped
	if direction ~= "top" and direction ~= "bottom" then return false, false end
	return true, direction == "bottom"
end
local function retireEnds(modules)
	local skinsModule = DUI:GetModule("Skins")
	local skins = modules.Skins
	if type(skins) == "table" and skinsModule and type(skinsModule.defaults) == "table"
		and skinsModule.defaults.breathSlantLeft ~= nil then
		if skins.mirrorLeft ~= nil then skins.breathSlantLeft, skins.breathUnderLeft = endFor(skins.mirrorLeft) end
		if skins.mirrorRight ~= nil then skins.breathSlant, skins.breathUnder = endFor(skins.mirrorRight) end
		skins.mirrorLeft, skins.mirrorRight = nil, nil
	end
	local unitModule = DUI:GetModule("UnitFrames")
	local units = modules.UnitFrames
	local d = unitModule and unitModule.defaults
	if type(units) == "table" and type(d) == "table" and type(d.player) == "table"
		and d.player.slantUnderOuter ~= nil then
		for _, unit in ipairs(REVERSED_UNITS) do
			local cfg = units[unit]
			if type(cfg) == "table" and cfg.reverseSlant ~= nil then
				if cfg.reverseSlant == true then cfg.slantUnder, cfg.slantUnderOuter = true, true end
				cfg.reverseSlant = nil
			end
		end
	end
end

local function migrateProfiles()
	local old = "DaylightAddonSkins"
	-- This key is also used by Glowey's current plugin. Shared skin settings
	-- cannot identify legacy Blasta data: copy only Blasta-owned settings and
	-- keep the source intact, including unknown fields and explicit false values.
	local blastaKeys = {
		"auraReminder", "experienceStyle", "squareSpellbookIcons", "characterPanel",
		"mapZoneLevels", "zoneTitleExtras", "dispelOverlay", "dungeonFinder",
		"blastaBags", "blastaLoot", "blastaLootSpace", "blastaLootIconBorder",
		"rageNeed", "consumableBars", "moments", "blastaDispelOnlyMine", "mapTravelRoutes",
	}
	for _, profile in pairs(DUI.DB.Root().profileData) do
		local modules = type(profile) == "table" and profile.modules
		if type(modules) == "table" and ns.MigratePortraitShape then ns.MigratePortraitShape(profile) end
		if type(modules) == "table" then retireEnds(modules) end
		local previous = type(modules) == "table" and modules[old]
		if type(previous) == "table" then
			local legacy = {}
			for _, key in ipairs(blastaKeys) do
				if previous[key] ~= nil then legacy[key] = previous[key] end
			end
			if next(legacy) then
				if modules[ADDON] == nil then modules[ADDON] = {} end
				if type(modules[ADDON]) == "table" then
					DUI.DB.MergeDefaults(modules[ADDON], legacy)
				end
			end
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
	defaults.auraIconCorners = false
	defaults.experienceStyle = ns.ExperienceDefaults
	defaults.squareSpellbookIcons = false
	defaults.talentWorkbench = true
	defaults.windowCorners = false
	defaults.characterPanel = ns.CharacterPanelDefaults
	defaults.zoneTitleExtras = ns.ZoneTitleExtrasDefaults
	defaults.dispelOverlay = false
	defaults.dungeonFinder = false
	defaults.compatNotice = ""
	defaults.blastaBags = false
	defaults.blastaLoot = ns.LootFeedDefaults
	defaults.blastaLootSpace = true
	defaults.blastaLootIconBorder = "square"
	defaults.rageNeed = ns.RageNeedDefaults
	defaults.consumableBars = ns.ConsumableBarDefaults
	defaults.moments = ns.MomentsDefaults
	defaults.blastaDispelOnlyMine = false
	defaults.mapTravelRoutes = true
	-- DaylightUI 1.9.5 checks every row: one without a text label (a custom row
	-- carried over from a DaylightUI page) gets its title or an empty label.
	for _, page in ipairs(pages or {}) do
		for _, group in ipairs(page.groups or {}) do
			if type(group.label) ~= "string" then group.label = "" end
			for _, item in ipairs(group.items or {}) do
				local ok = type(item.label) == "string" or (item.type == "text" and type(item.label) == "function")
				if not ok then
					local title = item.title or item.name
					if type(item.label) == "function" then
						local fine, text = pcall(item.label)
						if fine and type(text) == "string" then title = text end
					end
					item.label = type(title) == "string" and title or ""
				end
			end
		end
	end
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
