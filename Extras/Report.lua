-- /blasta report: everything a GitHub issue about Blasta needs, in one box to
-- copy: Blasta's and DaylightUI's versions, the game, which of Blasta's parts
-- are on, the other addons, and this session's latest Blasta errors.
-- Nothing runs until it's opened, and no character or realm name goes in.
-- The text stays English: it's read by whoever works on the bug.
local ADDON, extras = ...
local DUI = DaylightUI

local Report = {}
extras.Report = Report

Report.WIDTH, Report.BOX, Report.ERRORS, Report.STACK = 620, 340, 5, 8

local function secret(v) return DUI.IsSecret and DUI.IsSecret(v) end
local function meta(addon, field)
    local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
    local ok, v = pcall(get, addon, field)
    return ok and v or nil
end

-- Whether an error is Blasta's: its file is named in the message or the top
-- line of its stack.
local function ours(text, stack)
    if type(text) == "string" and text:find(ADDON, 1, true) then return true end
    local top = type(stack) == "string" and stack:match("[^\r\n]+")
    return top and top:find(ADDON, 1, true) ~= nil or false
end

-- This session's Blasta errors, oldest first, each { text, count, stack }.
function Report.Errors()
    local out, known = {}, {}
    for _, e in ipairs(DUI.Errors and DUI.Errors() or {}) do
        if type(e.text) == "string" and ours(e.text, e.stack) then
            known[e.text] = true
            out[#out + 1] = { text = e.text, count = e.count, stack = e.stack }
        end
    end
    local grabber = rawget(_G, "BugGrabber")
    local okDb, db = pcall(function() return grabber and grabber:GetDB() end)
    local okSession, session = pcall(function() return grabber and grabber:GetSessionId() end)
    if okDb and type(db) == "table" then
        local seen = {}
        for _, e in ipairs(db) do
            local msg = type(e) == "table" and (not okSession or e.session == session) and e.message
            if type(msg) == "string" and not secret(msg) then
                local text = msg:match("^[^\n]*"):gsub("^%(seen %d+ times%) ", "")
                local stack = type(e.stack) == "string" and not secret(e.stack) and e.stack or nil
                if not known[text] and ours(text, stack) then
                    local entry = seen[text]
                    if not entry then
                        entry = { text = text, count = 0 }
                        seen[text] = entry
                        out[#out + 1] = entry
                    end
                    entry.count = entry.count + (tonumber(e.counter) or 1)
                    entry.stack = stack
                end
            end
        end
    end
    return out
end

-- Blasta's parts that are on: every settings section switched on, and the
-- switches that are on at the top.
function Report.Parts()
    local mod = DUI:GetModule(ADDON)
    local db = mod and mod.db
    local sections, switches = {}, {}
    if type(db) == "table" then
        for k, v in pairs(db) do
            if type(k) == "string" then
                if type(v) == "table" and v.enabled == true then sections[#sections + 1] = k
                elseif v == true then switches[#switches + 1] = k end
            end
        end
    end
    table.sort(sections)
    table.sort(switches)
    return sections, switches
end

local function addons()
    local out = {}
    local count = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, count do
        local name = C_AddOns.GetAddOnInfo(i)
        if type(name) == "string" and C_AddOns.IsAddOnLoaded(i) and name ~= ADDON then
            local version = meta(name, "Version")
            out[#out + 1] = version and (name .. " " .. version) or name
        end
    end
    table.sort(out, function(a, b) return a:lower() < b:lower() end)
    return out
end

local function listed(t) return #t > 0 and table.concat(t, ", ") or "none" end

function Report.Text()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end
    local version, build, _, toc = GetBuildInfo()
    add("**Blasta** " .. tostring(meta(ADDON, "Version") or "?"))
    add("**DaylightUI** " .. tostring(DUI.VERSION or meta("DaylightUI", "Version") or "?"))
    add(("**Game** %s (%s, interface %s), %s"):format(tostring(version), tostring(build), tostring(toc), tostring(GetLocale())))
    local on = {}
    if DUI.Modules then
        for name, mod in DUI.Modules() do if mod.enabled then on[#on + 1] = name end end
        table.sort(on)
    end
    add("**Daylight modules on** " .. listed(on))
    local sections, switches = Report.Parts()
    add("**Blasta parts on** " .. listed(sections))
    add("**Blasta switches on** " .. listed(switches))
    add("**Blasta parts inactive with this DaylightUI** " .. listed(extras.Compat and extras.Compat.Labels(true) or {}))
    add("**Other addons** " .. listed(addons()))
    add("")
    local errors = Report.Errors()
    if #errors == 0 then
        add("**Errors** none from Blasta this session")
    else
        add(("**Errors** (latest %d of %d)"):format(math.min(#errors, Report.ERRORS), #errors))
        add("```")
        for i = math.max(1, #errors - Report.ERRORS + 1), #errors do
            local e = errors[i]
            add((e.count or 1) > 1 and ("%s (x%d)"):format(e.text, e.count) or e.text)
            if type(e.stack) == "string" then
                local n = 0
                for line in e.stack:gmatch("[^\r\n]+") do
                    n = n + 1
                    if n > Report.STACK then break end
                    add("    " .. line)
                end
            end
            add("")
        end
        add("```")
    end
    return table.concat(lines, "\n")
end

local f

function Report.Close()
    if not (f and DUI.Win.IsOpen(f)) then return end
    f.edit:ClearFocus()
    DUI.Win.Close(f)
    DUI.Win.KeysOn(f, false)
end

local function build()
    local W, Win = DUI.Widgets, DUI.Win
    f = Win.New({ name = "DaylightUIBlastaReport", w = Report.WIDTH,
        h = Win.HEADER + 12 + Report.BOX + 12 + 56, strata = "DIALOG" })
    f.title:SetText(extras.Translate("Blasta report"))
    if f.sub then f.sub:SetText(extras.Translate("Click the box and press Ctrl+C, then paste it into a GitHub issue.")) end
    f.onClose = Report.Close
    local host = f.host
    local area = W.TextArea(host, { width = Report.WIDTH - 2 * Win.EDGE - 28, step = 40, onEscape = Report.Close })
    area:SetPoint("TOPLEFT", host, "TOPLEFT", Win.EDGE, -12)
    area:SetPoint("RIGHT", host, "RIGHT", -Win.EDGE, 0)
    area:SetHeight(Report.BOX)
    local e = area.edit
    e:SetTextInsets(6, 6, 6, 6)
    e:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    f.area, f.edit = area, e
    f.foot = Win.Parts.Footer(host)
    f.foot:Set({ { text = _G.DONE or "Done", primary = true, onClick = Report.Close } })
    Win.Drag(f, {})
    Win.Keys(f, function(key)
        if key == "ESCAPE" then Report.Close(); return true end
    end)
end

-- Opens with the report filled in and selected, ready for Ctrl+C.
function Report.Show()
    if not (DUI.Win and DUI.Widgets and DUI.Widgets.TextArea) then
        print("|cffffd200Blasta|r: " .. Report.Text())
        return
    end
    if not f then build() end
    f.area.Lock(DUI.Widgets.SetEditText(f.edit, Report.Text()), true)
    f.edit:SetCursorPosition(0)
    f.area:SetVerticalScroll(0)
    if not DUI.Win.IsOpen(f) then
        f:ClearAllPoints()
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
        f:SetScale(DUI.Win.Scale(1))
        DUI.Win.Open(f)
        DUI.Win.KeysOn(f, true)
    end
    f:Raise()
    f.edit:SetFocus()
end
