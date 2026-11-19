-- Blasta XP gain motion, laid over DaylightUI's experience bar.
-- A gain shows at once as a light ghost piece; the fill runs after it with a
-- soft light on its tip, longer for bigger gains, and gains in a row carry on
-- without restarting. A level up runs the fill to the end, crosses the full
-- bar with a band, drains it back to the left, then fills it again. The rested
-- part glides too.
-- DaylightUI's rising "+N" stays; its flash and band are replaced by ours.
local ADDON, extras = ...
local DUI = DaylightUI
local ns = extras.Compatible("InfoPanel")
if not (ns and ns.XP and ns.XPGain and ns.XPGain.Show and extras.ExperienceClip) then return end

local XP, Gain = ns.XP, ns.XPGain
local secret = DUI.IsSecret or function() return false end
local ROOT = "experienceStyle"
local GLOW = DUI.MEDIA .. "glow.png"

local MIN_TIME, MAX_TIME = 0.45, 1.2   -- a kill .. a big quest turn-in
local BIG = 0.3                        -- share of the bar that takes MAX_TIME
local WRAP_TIME, BAND_TIME, DRAIN_TIME = 0.35, 0.45, 0.5
local RESTED_TIME, TIP_FADE = 0.6, 0.25
local GHOST_ALPHA, LIFT, BAND_SHARE = 0.55, 0.4, 0.25

local function on()
    local s = DUI:Get(ADDON, ROOT)
    return not (s and s.gainMotion == false) and not (DUI.Motion and not DUI.Motion.On())
end

local ghost, tip, band
local parts = {}
extras.ExperienceGainParts = parts

local function build()
    if ghost or not XP.bar then return ghost ~= nil end
    local bar = XP.bar
    -- Under the fill (its own background is hidden), over the bars below.
    ghost = bar:CreateTexture(nil, "BACKGROUND", nil, 7)
    ghost:SetTexture("Interface\\Buttons\\WHITE8X8")
    ghost:Hide()
    local over = CreateFrame("Frame", nil, bar)
    over:SetAllPoints(bar)
    over:SetFrameLevel(bar:GetFrameLevel() + 3)
    tip = over:CreateTexture(nil, "OVERLAY")
    tip:SetTexture(GLOW)
    tip:SetBlendMode("ADD")
    tip:Hide()
    band = over:CreateTexture(nil, "OVERLAY")
    band:SetTexture("Interface\\Buttons\\WHITE8X8")
    band:SetBlendMode("ADD")
    band:Hide()
    parts[1], parts[2], parts[3] = ghost, tip, band
    for _, t in ipairs(parts) do extras.ExperienceClip(t) end
    return true
end

-- The fill's color, lifted toward white. A gradient fill reads as white, so
-- the player's accent stands in for it.
local function paint()
    local r, g, b = XP.bar:GetStatusBarColor()
    if not r or (r > 0.95 and g > 0.95 and b > 0.95) then
        local api = DUI.API
        if api and api.Accent then r, g, b = api.Accent() else r, g, b = 1, 1, 1 end
    end
    r, g, b = r + (1 - r) * LIFT, g + (1 - g) * LIFT, b + (1 - b) * LIFT
    ghost:SetVertexColor(r, g, b, GHOST_ALPHA)
    tip:SetVertexColor(r, g, b, 1)
    band:SetVertexColor(r, g, b, 0.8)
end

local function length()
    return (XP.vertical and XP.bar:GetHeight() or XP.bar:GetWidth()) or 0
end
local function thickness()
    return (XP.vertical and XP.bar:GetWidth() or XP.bar:GetHeight()) or 0
end

-- Lays a texture over [a, b] of max along the bar.
local function span(tex, a, b, max)
    local len = length()
    if len <= 0 or max <= 0 or b - a <= 0 then tex:Hide(); return end
    local p, q = len * a / max, len * math.min(b, max) / max
    tex:ClearAllPoints()
    if XP.vertical then
        tex:SetPoint("BOTTOMLEFT", XP.bar, "BOTTOMLEFT", 0, p)
        tex:SetPoint("TOPRIGHT", XP.bar, "BOTTOMRIGHT", 0, q)
    else
        tex:SetPoint("TOPLEFT", XP.bar, "TOPLEFT", p, 0)
        tex:SetPoint("BOTTOMRIGHT", XP.bar, "BOTTOMLEFT", q, 0)
    end
    tex:Show()
end

local function placeTip(v, max, alpha)
    local len, thick = length(), thickness()
    if len <= 0 or max <= 0 or alpha <= 0 then tip:Hide(); return end
    local at = len * math.min(v, max) / max
    local long, wide = math.max(10, thick * 1.6), thick * 2.4
    tip:ClearAllPoints()
    if XP.vertical then
        tip:SetSize(wide, long)
        tip:SetPoint("CENTER", XP.bar, "BOTTOM", 0, at)
    else
        tip:SetSize(long, wide)
        tip:SetPoint("CENTER", XP.bar, "LEFT", at, 0)
    end
    tip:SetAlpha(alpha)
    tip:Show()
end

local function placeBand(k)
    local len = length()
    if len <= 0 then band:Hide(); return end
    local w = len * BAND_SHARE
    local at = (len - w) * (1 - (1 - k) ^ 2)
    band:ClearAllPoints()
    if XP.vertical then
        band:SetPoint("BOTTOMLEFT", XP.bar, "BOTTOMLEFT", 0, at)
        band:SetPoint("BOTTOMRIGHT", XP.bar, "BOTTOMRIGHT", 0, at)
        band:SetHeight(w)
    else
        band:SetPoint("TOPLEFT", XP.bar, "TOPLEFT", at, 0)
        band:SetPoint("BOTTOMLEFT", XP.bar, "BOTTOMLEFT", at, 0)
        band:SetWidth(w)
    end
    band:SetAlpha(1 - k)
    band:Show()
end

local function timeFor(delta, max)
    if max <= 0 then return MIN_TIME end
    return MIN_TIME + (MAX_TIME - MIN_TIME) * math.min(1, (delta / max) / BIG)
end

-- Running state. A phase is { kind = "fill" | "band" | "drain" | "fade", from, to, max, dur }.
local driver = CreateFrame("Frame")
driver:Hide()
local phases, phase, t = {}, nil, 0
local shown                       -- the value the fill shows now
local prev                        -- the last reading: label, value, max, level, rep
local rest                        -- the rested glide: { from, to, t, delay, dur }
local testing
local repWaiting                  -- a reputation gain waits for the XP animation

local function quiet(tex)
    if not tex then return end
    if tex.__duiFlash then tex.__duiFlash:Stop() end
    if tex.group then tex.group:Stop() end
    tex:Hide()
end

local function stop()
    wipe(phases)
    phase = nil
    if ghost then ghost:Hide(); tip:Hide(); band:Hide() end
    if XP.banked then XP.banked:SetAlpha(1) end
    if rest then XP.rested:SetValue(rest.to); rest = nil end
    testing, repWaiting = nil, nil
    driver:Hide()
end

-- Draws the phase that runs; true when it has ended.
local function draw(p, k)
    if p.kind == "fill" then
        local e = 1 - (1 - k) ^ 3
        shown = p.from + (p.to - p.from) * e
        XP.bar:SetMinMaxValues(0, p.max)
        XP.bar:SetValue(shown)
        span(ghost, shown, p.to, p.max)
        placeTip(shown, p.max, math.min(1, k * 6))
    elseif p.kind == "band" then
        XP.bar:SetMinMaxValues(0, p.max)
        XP.bar:SetValue(p.max)
        ghost:Hide()
        placeTip(p.max, p.max, 1 - k)
        placeBand(k)
    elseif p.kind == "drain" then
        -- The full bar runs out to the left, slow to start, easing in at the end.
        local e = k < 0.5 and 2 * k * k or 1 - (2 - 2 * k) ^ 2 / 2
        shown = p.from * (1 - e)
        XP.bar:SetMinMaxValues(0, p.max)
        XP.bar:SetValue(shown)
        ghost:Hide()
        band:Hide()
        placeTip(shown, p.max, 0.7 * (1 - k))
    elseif p.kind == "fade" then
        placeTip(p.to, p.max, 1 - k)
    end
end

local function nextPhase()
    phase, t = table.remove(phases, 1), 0
    if not phase then return end
    if phase.kind == "fill" and phase.from == 0 then XP.banked:SetAlpha(1) end
    if phase.kind ~= "band" then band:Hide() end
end

local function finished()
    ghost:Hide(); tip:Hide(); band:Hide()
    XP.banked:SetAlpha(1)
    if testing and prev then
        -- The test is over: back to the real reading.
        testing = nil
        XP.bar:SetMinMaxValues(0, prev.max)
        DUI.Style.SetBarValue(XP.bar, prev.value)
        shown = prev.value
    end
    if repWaiting then
        -- Now the reputation gain gets its turn on the bar.
        repWaiting = nil
        C_Timer.After(0.15, function() if not phase then XP.ShowRep(true) end end)
    end
end

driver:SetScript("OnUpdate", function(_, elapsed)
    if not (XP.bar and XP.bar:IsVisible()) then stop(); return end
    if phase then
        t = t + elapsed
        local k = phase.dur > 0 and math.min(1, t / phase.dur) or 1
        draw(phase, k)
        if k >= 1 then
            nextPhase()
            if not phase then finished() end
        end
    end
    if rest then
        rest.t = rest.t + elapsed
        local k = math.max(0, rest.t - rest.delay) / rest.dur
        if k >= 1 then
            XP.rested:SetValue(rest.to)
            rest = nil
        else
            local e = 1 - (1 - k) ^ 3
            XP.rested:SetValue(rest.from + (rest.to - rest.from) * e)
        end
    end
    if not phase and not rest then driver:Hide() end
end)

-- DaylightUI lays the reputation bar over the experience bar for a few seconds
-- after a reputation gain (a quest turn-in gives both). While experience runs,
-- that waits; one already on screen steps aside and comes back after.
local function holdRep()
    local bar = XP.repBar
    if not bar or XP.hover or not XP.repUntil or GetTime() >= XP.repUntil then return end
    if (bar:GetAlpha() or 0) <= 0 then return end
    if DUI.Motion and DUI.Motion.Tween then DUI.Motion.Tween("xpRep", 0, 0) end
    bar:SetAlpha(0)
    XP.repUntil = nil
    repWaiting = true
end

if XP.ShowRep then
    local nativeShowRep = XP.ShowRep
    function XP.ShowRep(sweep)
        if sweep and phase and not XP.hover and on() then repWaiting = true; return end
        return nativeShowRep(sweep)
    end
end

local function begin(list)
    if not build() then return end
    holdRep()
    paint()
    wipe(phases)
    for i, p in ipairs(list) do phases[i] = p end
    nextPhase()
    if phase then draw(phase, 0) end
    driver:Show()
end

local function fill(from, to, max)
    return { kind = "fill", from = from, to = to, max = max, dur = timeFor(to - from, max) }
end

local function levelUp(from, oldMax, value, max)
    if XP.banked then XP.banked:SetAlpha(0) end
    begin({
        { kind = "fill", from = from, to = oldMax, max = oldMax, dur = WRAP_TIME },
        { kind = "band", max = oldMax, dur = BAND_TIME },
        { kind = "drain", from = oldMax, max = oldMax, dur = DRAIN_TIME },
        fill(0, value, max),
        { kind = "fade", to = value, max = max, dur = TIP_FADE },
    })
end

local function gain(from, value, max)
    -- Still running toward this range (a level up, say): run on to the new value.
    local n = #phases
    local final = phases[n] and phases[n].kind == "fade" and phases[n - 1]
    if final and final.kind == "fill" and final.max == max then
        final.to, final.dur = value, timeFor(value - final.from, max)
        phases[n].to = value
        return
    end
    begin({ fill(from, value, max), { kind = "fade", to = value, max = max, dur = TIP_FADE } })
end

-- Keeps what runs on screen after DaylightUI set the bar again.
local function hold(d)
    if phase then draw(phase, phase.dur > 0 and math.min(1, t / phase.dur) or 1)
    else XP.bar:SetValue(d.value); shown = d.value end
end

local nativeShow = Gain.Show
function Gain.Show(d)
    if not on() or secret(d.value) or secret(d.max) or not XP.bar then
        prev = nil
        if phase or rest then stop() end
        return nativeShow(d)
    end
    local level = UnitLevel and UnitLevel("player")
    local p = prev
    prev = { label = d.label, value = d.value, max = d.max, level = level, rep = d.rep }
    -- DaylightUI's "+N" rises as before; its flash and band give way to ours.
    nativeShow(d)
    quiet(Gain.flash)
    quiet(Gain.band)
    if testing then hold(d); return true end
    if not p or p.label ~= d.label or p.rep ~= d.rep then
        stop()
        XP.bar:SetValue(d.value)
        shown = d.value
        return true
    end
    local up = not d.rep and ((level and p.level and level > p.level) or d.value < p.value)
    if up then
        levelUp((phase and shown) or p.value, p.max, d.value, d.max)
    elseif d.max ~= p.max then
        stop()
        XP.bar:SetValue(d.value)
        shown = d.value
    elseif d.value > p.value then
        gain((phase and phase.max == d.max and shown) or p.value, d.value, d.max)
    else
        hold(d)
    end
    return true
end

-- The rested part: DaylightUI sets it at the end of each update; glide to it.
local restedLast, restedMax
hooksecurefunc(XP, "Update", function()
    if not (XP.frame and XP.frame:IsShown() and XP.rested) then
        prev, restedLast = nil, nil
        if phase or rest then stop() end
        return
    end
    local target = XP.rested:GetValue()
    local _, max = XP.rested:GetMinMaxValues()
    if not on() or secret(target) or secret(max) then restedLast = nil; return end
    local from = restedLast
    if rest then
        from = rest.from + (rest.to - rest.from) * math.min(1, math.max(0, rest.t - rest.delay) / rest.dur)
    end
    -- A level up has just begun: the rested part waits, then grows from empty.
    local leveled = phase and phases[1] and phases[1].kind == "band"
    if leveled then
        rest = { from = 0, to = target, t = 0, delay = WRAP_TIME + BAND_TIME + DRAIN_TIME, dur = RESTED_TIME }
        XP.rested:SetValue(0)
        driver:Show()
    elseif from and restedMax == max and target ~= from and not testing then
        rest = { from = from, to = target, t = 0, delay = 0, dur = RESTED_TIME }
        XP.rested:SetValue(from)
        driver:Show()
    end
    restedLast, restedMax = target, max
end)

-- A preview resets the reading, so the test values never look like a gain.
function extras.ExperienceGainReset()
    stop()
    prev, restedLast = nil, nil
end

-- "Test gain animation": a made-up gain from where the bar stands; one that
-- runs past the end shows the level up. The real reading comes back after.
function extras.ExperienceGainTest()
    if not (on() and XP.bar and XP.bar:IsVisible() and prev and build()) then return end
    local max = prev.max
    if not max or max <= 0 then return end
    local from = shown or prev.value
    local value = from + max * math.random(6, 16) / 100
    stop()
    if value >= max then
        levelUp(from, max, value - max, max)
    else
        begin({ fill(from, value, max), { kind = "fade", to = value, max = max, dur = TIP_FADE } })
    end
    testing = true
end

function extras.ExperienceGainGroup()
    return { label = "Gain animation", items = {
        { type = "toggle", key = ROOT .. ".gainMotion", label = "Animate experience gains",
            desc = "New experience shows at once as a light piece, and the fill runs after it with a soft light on its tip. A level up fills the bar, crosses it with a band and fills it again from empty. Needs Motion effects." },
        { type = "button", label = "Test gain animation", text = "Test gain animation",
            func = function() extras.ExperienceGainTest() end,
            disabled = function(get) return get(ROOT .. ".gainMotion") == false end },
        { type = "toggle", key = ROOT .. ".killEstimate", label = "Kills to the next level",
            desc = "Hovering the bar shows about how many more kills the level takes, from the experience of your last kills." },
    } }
end

-- Kills to the next level: the experience of the last kills, read from the
-- game's own "X dies, you gain N experience" lines, gives an average; the
-- bar's hover adds how many more of those the level takes.
local KEEP = 10   -- kills averaged
local kills = {}
local patterns = {}

-- A global format string ("%s dies, you gain %d experience.", with or
-- without numbered arguments) as a Lua pattern, and which capture holds the
-- experience (its first number).
local function compile(fmt)
    if type(fmt) ~= "string" or not fmt:find("%%") then return end
    local out, args, i = {}, {}, 1
    while i <= #fmt do
        local a, b, pos, conv = fmt:find("^%%(%d*)%$?([sd])", i)
        if a then
            args[#args + 1] = { conv = conv, pos = tonumber(pos) or (#args + 1) }
            out[#out + 1] = conv == "d" and "([%d%.,]+)" or "(.-)"
            i = b + 1
        elseif fmt:sub(i, i + 1) == "%%" then
            out[#out + 1] = "%%"
            i = i + 2
        else
            local c = fmt:sub(i, i)
            out[#out + 1] = c:find("^[%^%$%(%)%%%.%[%]%*%+%-%?]") and "%" .. c or c
            i = i + 1
        end
    end
    local slot, first
    for k, arg in ipairs(args) do
        if arg.conv == "d" and (not first or arg.pos < first) then slot, first = k, arg.pos end
    end
    if slot then return "^" .. table.concat(out), slot end
end

local function readPatterns()
    if #patterns > 0 then return end
    for name, fmt in pairs(_G) do
        if type(name) == "string" and name:find("^COMBATLOG_XPGAIN_") and not name:find("UNNAMED")
            and not name:find("QUEST") and type(fmt) == "string" then
            local pattern, slot = compile(fmt)
            if pattern then patterns[#patterns + 1] = { pattern = pattern, slot = slot } end
        end
    end
    -- The longer ones (rested, group bonus) first.
    table.sort(patterns, function(a, b) return #a.pattern > #b.pattern end)
end

local function killed(_, text)
    if type(text) ~= "string" or secret(text) then return end
    readPatterns()
    for _, p in ipairs(patterns) do
        local found = { text:match(p.pattern) }
        if #found > 0 then
            local amount = tonumber((tostring(found[p.slot] or ""):gsub("[^%d]", "")))
            if amount and amount > 0 then
                table.insert(kills, amount)
                if #kills > KEEP then table.remove(kills, 1) end
            end
            return
        end
    end
end
DUI.RegisterEvent("CHAT_MSG_COMBAT_XP_GAIN", killed)

local function estimateOn()
    local s = DUI:Get(ADDON, ROOT)
    return not (s and s.killEstimate == false)
end

-- How many more kills the level takes, or nil while there's too little to go on.
function extras.ExperienceKillsLeft()
    if #kills < 3 or not estimateOn() then return end
    local d = XP.Read and XP.Read()
    if not (d and d.max and d.value) or secret(d.max) or secret(d.value) then return end
    local sum = 0
    for _, v in ipairs(kills) do sum = sum + v end
    local average = sum / #kills
    local left = d.max - d.value
    if average <= 0 or left <= 0 then return end
    return math.ceil(left / average)
end

-- The line joins the bar's own hover, after its experience rows and before
-- the reputation part when that shows too.
local hovering, added
local Tips = DUI.Tips
local function addKills()
    if not hovering or added then return end
    added = true
    local n = extras.ExperienceKillsLeft()
    if n then Tips.Line(extras.Translate("Kills to level up"), "~" .. BreakUpLargeNumbers(n)) end
end
if Tips and Tips.Flush and Tips.Gap then
    local flush, gap = Tips.Flush, Tips.Gap
    Tips.Gap = function(...)
        addKills()
        return gap(...)
    end
    Tips.Flush = function(...)
        addKills()
        return flush(...)
    end
end
local hooked
local function hookHover()
    if hooked or not (XP.frame and XP.frame.GetScript) then return end
    local enter = XP.frame:GetScript("OnEnter")
    if not enter then return end
    hooked = true
    XP.frame:SetScript("OnEnter", function(...)
        hovering, added = true, false
        local ok, err = pcall(enter, ...)
        hovering = false
        if not ok then error(err, 0) end
    end)
end
hookHover()
hooksecurefunc(XP, "Update", hookHover)

extras.Loaded("ExperienceGain")
