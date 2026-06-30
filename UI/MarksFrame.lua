----------------------------------------------------------------------
-- RaidLead — UI/MarksFrame.lua
-- "Marks" tab: the pull-coordination board. Mark the pack, then assign a
-- Tank / CC / Interrupt per raid icon. Backed by Modules/MarkBoard.lua.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f = ns.mainFrame
local MB = ns.MarkBoard

local content = CreateFrame("Frame", nil, f)
content:SetPoint("TOPLEFT",     f, "TOPLEFT",      10, -68)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10,  10)
content:Hide()

-- Status dots (font lacks ●/○ glyphs, so use indicator textures).
local DOT_LIVE    = "|TInterface\\COMMON\\Indicator-Green:12|t"
local DOT_PLANNED = "|TInterface\\COMMON\\Indicator-Gray:12|t"

local RefreshMarks  -- forward decl

----------------------------------------------------------------------
-- Toolbar: Scan Marks | Mark Next | Quick-Mark All
----------------------------------------------------------------------
local scanBtn = ns.MakeSmallButton(content, "Scan Marks", 90, 22)
scanBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
scanBtn:SetScript("OnClick", function()
    local count = (MB.ScanAndUpdate and MB.ScanAndUpdate()) or 0
    RefreshMarks()
    if count == 0 then
        ns.P("|cFF888888No marked mobs detected. Mark some (or use Mark Next), then Scan.|r")
    end
end)
scanBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Scan Marked Mobs", 1, 0.82, 0)
    GameTooltip:AddLine("Reads the live raid markers and fills in each icon's mob name.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
scanBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

-- Mark Next (green) — stamp current target with the next icon, one click
-- at a time. The label shows which icon is next.
local markNextBtn = ns.MakeSmallButton(content, "Mark Next", 120, 22)
markNextBtn:SetPoint("LEFT", scanBtn, "RIGHT", 6, 0)
markNextBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
markNextBtn:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
        if ns.ResetMarkSequence then ns.ResetMarkSequence() end
    else
        if ns.MarkNextTarget then ns.MarkNextTarget() end
    end
end)

function ns.UpdateMarkNextLabel()
    local idx = (ns.GetNextMarkIcon and ns.GetNextMarkIcon()) or 8
    local tex = ns.GetRaidIconTexture(idx)
    markNextBtn.text:SetText(tex and ("Mark Next |T" .. tex .. ":14|t") or "Mark Next")
end
ns.UpdateMarkNextLabel()

local NEXT_BG, NEXT_BG_HOVER = { 0.14, 0.42, 0.18, 0.95 }, { 0.20, 0.58, 0.26, 1.00 }
markNextBtn:SetBackdropColor(unpack(NEXT_BG))
markNextBtn.text:SetTextColor(0.88, 1, 0.88)
markNextBtn:HookScript("OnEnter", function(self)
    self:SetBackdropColor(unpack(NEXT_BG_HOVER))
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Mark Next Target", 1, 0.82, 0.1)
    GameTooltip:AddLine("Marks your current target with the next icon (Skull, Cross, …), "
        .. "advancing each click. Target a mob \226\134\146 click; repeat down the pack.",
        0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Right-click: reset to Skull. Also: /raidlead marknext (macro it).", 0.85, 0.55, 0.2, true)
    GameTooltip:Show()
end)
markNextBtn:HookScript("OnLeave", function(self)
    self:SetBackdropColor(unpack(NEXT_BG))
    GameTooltip:Hide()
end)

-- Target Sweep — read marks on mobs too far for the normal Scan: click,
-- target/mouse over each marked mob, click again to stop.
local sweepBtn = ns.MakeSweepButton(content, function()
    if MB.ScanAndUpdate then MB.ScanAndUpdate() end
    RefreshMarks()
end, 110)
sweepBtn:SetPoint("LEFT", markNextBtn, "RIGHT", 6, 0)

-- Quick-Mark All (amber) — batch-mark a gathered in-range pack.
local quickBtn = ns.MakeSmallButton(content, "Quick-Mark All", 115, 22)
quickBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, 0)
quickBtn:SetScript("OnClick", function()
    local n = (ns.AutoMarkPack and ns.AutoMarkPack()) or 0
    if n > 0 then
        if MB.ScanAndUpdate then MB.ScanAndUpdate() end
        RefreshMarks()
    end
end)
local Q_BG, Q_BG_HOVER = { 0.60, 0.40, 0.10, 0.95 }, { 0.80, 0.56, 0.16, 1.00 }
quickBtn:SetBackdropColor(unpack(Q_BG))
quickBtn.text:SetTextColor(1, 0.96, 0.82)
quickBtn:HookScript("OnEnter", function(self)
    self:SetBackdropColor(unpack(Q_BG_HOVER))
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Quick-Mark All Targets", 1, 0.82, 0.1)
    GameTooltip:AddLine("Marks every visible, unmarked hostile (Skull, Cross, …). Best for a "
        .. "gathered pack that's all in range. Spread mobs: use Mark Next.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
quickBtn:HookScript("OnLeave", function(self)
    self:SetBackdropColor(unpack(Q_BG))
    GameTooltip:Hide()
end)

----------------------------------------------------------------------
-- Hint + column headers
----------------------------------------------------------------------
local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -26)
hint:SetPoint("RIGHT",   content, "RIGHT", -4, 0)
hint:SetJustifyH("LEFT")
hint:SetTextColor(0.6, 0.6, 0.6)
hint:SetText("Mark the pack, then assign per icon.   " .. DOT_LIVE .. "|cFF888888 live  |r"
    .. DOT_PLANNED .. "|cFF888888 planned|r")

-- Column geometry (shared by header + rows)
local COL = { icon = 0, mob = 30, tank = 176, cc = 290, interrupt = 404 }
local DD_W = 108
local ROLE_X = { tank = COL.tank, cc = COL.cc, interrupt = COL.interrupt }

local headerRow = CreateFrame("Frame", nil, content)
headerRow:SetHeight(14)
headerRow:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -46)
headerRow:SetPoint("RIGHT",   content, "RIGHT", -4, 0)
local function MakeHeader(text, x)
    local fs = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", headerRow, "LEFT", x, 0)
    fs:SetText(text)
    fs:SetTextColor(0.85, 0.85, 0.85)
    return fs
end
MakeHeader("Mob",       COL.mob)
MakeHeader("Tank",      COL.tank)
MakeHeader("CC",        COL.cc)
MakeHeader("Interrupt", COL.interrupt)

----------------------------------------------------------------------
-- Icon rows
----------------------------------------------------------------------
local ROW_H = 28
local rows = {}

local function CreateRow(icon)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -64 - (icon - 1) * ROW_H)
    row:SetPoint("RIGHT",   content, "RIGHT", -4, 0)

    -- Raid icon texture
    local iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetSize(22, 22)
    iconFrame:SetPoint("LEFT", row, "LEFT", COL.icon, 0)
    iconFrame:EnableMouse(true)
    local tex = iconFrame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(ns.GetRaidIconTexture(icon))
    iconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine((ns.RAID_ICON_NAMES and ns.RAID_ICON_NAMES[icon]) or ("Icon " .. icon), 1, 1, 1)
        GameTooltip:Show()
    end)
    iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Detected mob name + status
    row.mob = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.mob:SetPoint("LEFT", row, "LEFT", COL.mob, 0)
    row.mob:SetWidth(COL.tank - COL.mob - 8)
    row.mob:SetJustifyH("LEFT")
    row.mob:SetWordWrap(false)

    -- One dropdown per role
    row.dd = {}
    for _, r in ipairs(MB.ROLES) do
        local roleKey = r.key
        local dd = ns.CreatePlayerDropdown(row, DD_W, function(playerName)
            MB.SetRole(icon, roleKey, playerName)
        end)
        dd.respectLock = true
        dd.classFilter = r.classes
        dd:SetPoint("LEFT", row, "LEFT", ROLE_X[roleKey], 0)
        row.dd[roleKey] = dd
    end

    rows[icon] = row
    return row
end

for i = 1, 8 do CreateRow(i) end

RefreshMarks = function()
    if not MB.EnsureDB() then return end
    for icon = 1, 8 do
        local row = rows[icon]
        local rec = MB.Get(icon) or {}

        local hasMob = rec.mob and rec.mob ~= ""
        local hasAny = false
        for _, r in ipairs(MB.ROLES) do
            if rec[r.key] then hasAny = true end
        end
        if hasMob then
            row.mob:SetText(DOT_LIVE .. " |cFF88CCFF" .. rec.mob .. "|r")
        elseif hasAny then
            row.mob:SetText(DOT_PLANNED .. " |cFF888888(not marked)|r")
        else
            row.mob:SetText("|cFF555555(unused)|r")
        end

        for _, r in ipairs(MB.ROLES) do
            local dd = row.dd[r.key]
            local who = rec[r.key]
            if who then
                dd:SetSelectedPlayer(who, ns.ClassOf(who))
            else
                dd:SetSelectedPlayer(nil, nil)
            end
        end
    end
end
ns.RefreshMarksView = RefreshMarks

----------------------------------------------------------------------
-- Bottom: Announce + Clear All
----------------------------------------------------------------------
local announceBtn = ns.MakeSmallButton(content, "Announce", 110, 24)
announceBtn:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 4)
announceBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
announceBtn:SetScript("OnClick", function(self, button)
    local function GetLines() return MB.BuildAnnounceLines() end
    if button == "RightButton" then
        ns.BossTemplates.ShowChannelMenu(GetLines, function()
            ns.BossTemplates.WhisperRecipients(MB.BuildWhispers(), "mark assignment")
        end)
    else
        ns.BossTemplates.SendLines(GetLines())
    end
end)
announceBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Announce", 1, 0.82, 0.1)
    GameTooltip:AddLine("Left-click: send the board to raid/party", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: pick channel, whisper each player, or preview", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
announceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

local clearBtn = ns.MakeSmallButton(content, "Clear...", 80, 24)
clearBtn:SetPoint("LEFT", announceBtn, "RIGHT", 6, 0)
clearBtn:SetScript("OnClick", function()
    if MB.IsLocked() then ns.LockedNotice(); return end
    ns.ShowContextMenu({
        { text = "Clear", isTitle = true },
        { text = "Assignments", func = function()
            MB.ClearAssignments()
            RefreshMarks()
        end },
        { text = "Raid markers (icons)", func = function()
            if ns.ClearVisibleMarks then ns.ClearVisibleMarks() end
            if MB.ClearDetected then MB.ClearDetected() end
            RefreshMarks()
        end },
        { text = "Both", func = function()
            if ns.ClearVisibleMarks then ns.ClearVisibleMarks() end
            MB.ClearAll()
            RefreshMarks()
        end },
    }, "cursor", 0, 0)
end)
clearBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Clear", 1, 0.82, 0.1)
    GameTooltip:AddLine("Assignments: wipe the tank/CC/interrupt board.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Raid markers: pull the icons off the mobs in-game.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Both: clear assignments and icons.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
clearBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

----------------------------------------------------------------------
-- Register the tab (combat-coordination group: after Boss, before Assign)
----------------------------------------------------------------------
ns.RegisterTab("Marks", 22, content, function()
    if MB.ScanAndUpdate then MB.ScanAndUpdate() end  -- reflect live markers on open
    RefreshMarks()
end)
