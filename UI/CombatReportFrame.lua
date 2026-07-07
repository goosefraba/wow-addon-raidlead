----------------------------------------------------------------------
-- RaidLead — UI/CombatReportFrame.lua
-- "Combat" tab: the Combat Report. A live readiness board for key raid
-- cooldowns (Druid Innervate + Battle Rez), a combat-rez pool + per-death
-- rez plan (incl. Warlock Soulstones), and a timeline of casts & deaths.
-- Backed by Modules/CombatReport.lua.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f  = ns.mainFrame
local CR = ns.CombatReport

local content = CreateFrame("Frame", nil, f)
content:SetPoint("TOPLEFT",     f, "TOPLEFT",      10, -68)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10,  10)
content:Hide()

local fmtTime = CR.FmtTime

local KIND_ORDER = { "innervate", "rebirth", "misdirect" }
local COL_NAME   = 0
local COL_KIND   = { innervate = 150, rebirth = 262, misdirect = 374 }
local NAME_W     = 140

local ROW_H          = 22
local READY_START_Y  = -86
local READY_ROWS_MAX = 7
local LOG_ROW_H      = 15
local LOG_POOL_MAX   = 20
local FOOTER_RESERVE = 24   -- space at the bottom for the auto-reset toggle

----------------------------------------------------------------------
-- Top: summary + rez plan + Reset + info
----------------------------------------------------------------------
local summary = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
summary:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -6)
summary:SetPoint("RIGHT",   content, "RIGHT", -140, 0)
summary:SetJustifyH("LEFT")
summary:SetWordWrap(false)

local resetBtn = ns.MakeSmallButton(content, "Clear Log", 84, 22)
resetBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -2)
resetBtn:SetScript("OnClick", function() CR.SoftReset() end)
resetBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Clear Log", 1, 0.82, 0.1)
    GameTooltip:AddLine("Clears the cast & death log for a fresh pull. Cooldown "
        .. "timers are kept - they're real-world time, so a Battle Rez that "
        .. "still has 15 min left stays that way.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
resetBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

local infoBtn = CreateFrame("Button", nil, content)
infoBtn:SetSize(18, 18)
infoBtn:SetPoint("RIGHT", resetBtn, "LEFT", -6, 0)
local infoTex = infoBtn:CreateTexture(nil, "ARTWORK")
infoTex:SetAllPoints()
infoTex:SetTexture("Interface\\FriendsFrame\\InformationIcon")
infoBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Combat Report", 1, 0.82, 0.1)
    GameTooltip:AddLine("Reads Innervate / Battle Rez / Misdirect casts, deaths, and "
        .. "Soulstones from the combat log (within ~100 yd - the whole raid on a pull).",
        0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Combat rez pool = ready Battle Rezzes + active Soulstones. "
        .. "Readiness is estimated and local only - it sends nothing to the raid.",
        0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end)
infoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Rez plan / who's down (single line; truncates when crowded).
local rezPlan = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rezPlan:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -28)
rezPlan:SetPoint("RIGHT",   content, "RIGHT", -6, 0)
rezPlan:SetJustifyH("LEFT")
rezPlan:SetWordWrap(false)

----------------------------------------------------------------------
-- Readiness board
----------------------------------------------------------------------
local readyHeader = ns.MakeSectionHeader(content, "Cooldown readiness")
readyHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -48)
readyHeader:SetPoint("RIGHT",   content, "RIGHT", 0, 0)

local colHead = CreateFrame("Frame", nil, content)
colHead:SetHeight(14)
colHead:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -70)
colHead:SetPoint("RIGHT",   content, "RIGHT", -4, 0)
local function MakeColHead(text, x)
    local fs = colHead:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", colHead, "LEFT", x, 0)
    fs:SetText("|cFFFFCC00" .. text .. "|r")
    return fs
end
MakeColHead("Player", COL_NAME)
for _, kind in ipairs(KIND_ORDER) do
    MakeColHead(CR.KINDS[kind].label, COL_KIND[kind])
end

local readyRows = {}
local function GetReadyRow(i)
    local row = readyRows[i]
    if row then return row end
    row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, READY_START_Y - (i - 1) * ROW_H)
    row:SetPoint("RIGHT",   content, "RIGHT", -4, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT", row, "LEFT", COL_NAME, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.cell = {}
    for _, kind in ipairs(KIND_ORDER) do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", row, "LEFT", COL_KIND[kind], 0)
        fs:SetJustifyH("LEFT")
        row.cell[kind] = fs
    end

    readyRows[i] = row
    return row
end

local function CellText(p, kind)
    -- Only the class that owns the spell gets a real cell; others show a dash.
    local meta = CR.KINDS[kind]
    if meta and meta.class and meta.class ~= p.class then return "|cFF444444-|r" end
    local st = p.unit and CR.UnitStatus(p.unit) or "alive"
    if st == "offline" then return "|cFF777777offline|r" end
    if st == "dead"    then return "|cFFFF6644dead|r"    end
    local rem = CR.Remaining(p.name, kind)
    if rem <= 0 then return "|cFF44FF44Ready|r" end
    return "|cFFFFCC00" .. fmtTime(rem) .. "|r"
end

local noDruids = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
noDruids:SetPoint("TOPLEFT", content, "TOPLEFT", 8, READY_START_Y)
noDruids:SetPoint("RIGHT",   content, "RIGHT", -8, 0)
noDruids:SetJustifyH("LEFT")
noDruids:SetTextColor(0.6, 0.6, 0.6)
noDruids:SetText("No druids or hunters detected. (Tracked: Innervate, Battle Rez, Misdirection.)")
noDruids:Hide()

-- Soulstone holders (they aren't druids, so they're not in the board above;
-- this line makes the "+ N Soulstone" part of the pool visible).
local ssLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ssLine:SetJustifyH("LEFT")
ssLine:SetWordWrap(false)
ssLine:Hide()

----------------------------------------------------------------------
-- Recent casts + deaths log (positioned dynamically below the board)
----------------------------------------------------------------------
local logHeader = ns.MakeSectionHeader(content, "Recent casts & deaths")

local logEmpty = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
logEmpty:SetJustifyH("LEFT")
logEmpty:SetTextColor(0.55, 0.55, 0.55)
logEmpty:SetText("No casts or deaths yet since the last reset.")
logEmpty:Hide()

local logRows = {}
local function GetLogRow(i)
    local fs = logRows[i]
    if fs then return fs end
    fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    logRows[i] = fs
    return fs
end

----------------------------------------------------------------------
-- Auto-reset footer toggle
----------------------------------------------------------------------
local autoChk = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
autoChk:SetSize(20, 20)
autoChk:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 2, 2)
local autoLbl = autoChk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
autoLbl:SetPoint("LEFT", autoChk, "RIGHT", 2, 0)
autoLbl:SetText("Auto-clear log each pull")
autoLbl:SetTextColor(0.78, 0.78, 0.78)
autoChk:SetScript("OnClick", function(self)
    if ns.db and ns.db.settings then
        ns.db.settings.combatAutoReset = self:GetChecked() and true or false
    end
end)
autoChk:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Auto-clear log each pull", 1, 0.82, 0.1)
    GameTooltip:AddLine("When a new pull starts (combat begins after a lull), clear the "
        .. "cast & death log automatically. Cooldown timers are kept.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
autoChk:SetScript("OnLeave", function() GameTooltip:Hide() end)

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
-- Class-colored name; Cn takes an explicit class, CcOf looks it up.
local function Cn(name, class)
    return ns.ClassColor(class or "UNKNOWN") .. (name or "?") .. "|r"
end
local function CcOf(name)  -- look the class up (death victims / rez targets vary)
    return ns.ClassColor(ns.ClassOf(name)) .. (name or "?") .. "|r"
end

local function Refresh()
    local druids = CR.GetDruids()
    local a      = CR.Availability()

    -- Summary line: combat-rez pool headline + innervate count.
    if a.rezTotal == 0 and a.ssCount == 0 then
        summary:SetText("|cFF888888No druids or soulstones in the group.|r")
    else
        summary:SetText(string.format(
            "Combat rez pool: |cFF44FF44%d|r |cFF777777(%d Rez + %d SS)|r"
            .. "     |cFF888888Innervate|r %s%d/%d|r ready",
            a.pool, a.rezReady, a.ssCount,
            (a.innReady > 0) and "|cFFFFFFFF" or "|cFFFF6644", a.innReady, a.innTotal))
    end

    -- Rez plan / who's down.
    local plan = CR.BuildRezPlan()
    if #plan == 0 then
        rezPlan:SetText("|cFF55AA55Nobody down.|r")
    else
        local segs, shown = {}, math.min(#plan, 3)
        for i = 1, shown do
            local e = plan[i]
            local byCol = (e.kind == "none") and "|cFF888888" or "|cFF66CCFF"
            segs[i] = Cn(e.name, e.class) .. " |cFF999999->|r " .. byCol .. e.by .. "|r"
        end
        local more = (#plan > shown) and ("  |cFF888888+" .. (#plan - shown) .. " more|r") or ""
        rezPlan:SetText("|cFFFF6644Down:|r  " .. table.concat(segs, "   ") .. more)
    end

    -- Readiness rows (druids + hunters).
    local players = CR.GetTrackedPlayers()
    local nShown  = math.min(#players, READY_ROWS_MAX)
    noDruids:SetShown(#players == 0)
    for i = 1, READY_ROWS_MAX do
        local p = players[i]
        if p then
            local row = GetReadyRow(i)
            local st  = p.unit and CR.UnitStatus(p.unit) or "alive"
            local nm  = Cn(p.name, p.class)
            if st == "dead" then nm = nm .. " |cFFFF6644*|r" end
            row.name:SetText(nm)
            for _, kind in ipairs(KIND_ORDER) do
                row.cell[kind]:SetText(CellText(p, kind))
            end
            row:Show()
        elseif readyRows[i] then
            readyRows[i]:Hide()
        end
    end

    -- Soulstone holders line (right below the druid board), so the "+ N SS"
    -- part of the pool has a visible owner. Warlocks/soulstone recipients
    -- aren't druids, so they never appear in the board itself.
    local effRows      = math.max(nShown, 1)
    local yAfterBoard  = READY_START_Y - effRows * ROW_H
    local ssNames = {}
    for nm in pairs(CR.GetSoulstones()) do ssNames[#ssNames + 1] = nm end
    if #ssNames > 0 then
        table.sort(ssNames)
        local colored = {}
        for i, nm in ipairs(ssNames) do colored[i] = CcOf(nm) end
        ssLine:ClearAllPoints()
        ssLine:SetPoint("TOPLEFT", content, "TOPLEFT", 6, yAfterBoard - 2)
        ssLine:SetPoint("RIGHT",   content, "RIGHT", -6, 0)
        ssLine:SetText("|cFF9482C9Soulstone:|r  " .. table.concat(colored, ", "))
        ssLine:Show()
        yAfterBoard = yAfterBoard - 16
    else
        ssLine:Hide()
    end

    -- Position the log header + rows just below the board (+ soulstone line).
    local logHY = yAfterBoard - 10
    local logSY = logHY - 20
    logHeader:ClearAllPoints()
    logHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, logHY)
    logHeader:SetPoint("RIGHT",   content, "RIGHT", 0, 0)
    logEmpty:ClearAllPoints()
    logEmpty:SetPoint("TOPLEFT", content, "TOPLEFT", 6, logSY)

    -- Recent casts & deaths (newest first). Fit as many rows as the window
    -- allows above the footer; a "+N earlier" note caps the rest.
    local events   = CR.events
    local n        = #events
    logEmpty:SetShown(n == 0)

    local contentH = content:GetHeight() or 0
    local avail    = logSY + contentH - FOOTER_RESERVE   -- both terms negative/positive net px
    local visible  = math.max(0, math.min(LOG_POOL_MAX, math.floor(avail / LOG_ROW_H)))

    local extra = 0
    if n > visible and visible > 0 then extra = n - (visible - 1) end
    local toShow = (extra > 0) and (visible - 1) or math.min(n, visible)

    for i = 1, LOG_POOL_MAX do
        local fs = logRows[i]
        if i <= toShow then
            local e = events[n - i + 1]   -- walk back from newest
            fs = GetLogRow(i)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", 6, logSY - (i - 1) * LOG_ROW_H)
            fs:SetPoint("RIGHT",   content, "RIGHT", -6, 0)
            local when = "|cFF888888[+" .. fmtTime(e.t - CR.resetAt) .. "]|r"
            if e.kind == "death" then
                fs:SetText(when .. "  |cFFFF5555x|r " .. CcOf(e.caster) .. " |cFFFF6644died|r")
            else
                local meta   = CR.KINDS[e.kind]
                -- The spell's class is the caster's class (Druid or Hunter).
                local caster = ns.ClassColor(meta and meta.class or "UNKNOWN") .. e.caster .. "|r"
                local target = (e.target and e.target ~= e.caster)
                    and ("  |cFF999999to|r " .. CcOf(e.target)) or ""
                fs:SetText(string.format("%s  %s%s   |cFF66CCFF%s|r",
                    when, caster, target, meta and meta.label or e.kind))
            end
            fs:Show()
        elseif extra > 0 and i == visible then
            fs = GetLogRow(i)
            fs:ClearAllPoints()
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", 6, logSY - (i - 1) * LOG_ROW_H)
            fs:SetPoint("RIGHT",   content, "RIGHT", -6, 0)
            fs:SetText("|cFF666666(+" .. extra .. " earlier)|r")
            fs:Show()
        elseif fs then
            fs:Hide()
        end
    end
end
ns.RefreshCombatReport = Refresh

-- Live ticker: tick countdowns / elapsed while the tab is visible (~2 Hz).
local accum = 0
content:SetScript("OnUpdate", function(_, elapsed)
    accum = accum + elapsed
    if accum < 0.5 then return end
    accum = 0
    Refresh()
end)

----------------------------------------------------------------------
-- Register the tab (raid-execution cluster: after Marks, before Assign)
----------------------------------------------------------------------
ns.RegisterTab("Combat", 24, content, function()
    if autoChk then
        autoChk:SetChecked(ns.db and ns.db.settings and ns.db.settings.combatAutoReset)
    end
    Refresh()
end)
