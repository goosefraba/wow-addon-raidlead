----------------------------------------------------------------------
-- RaidLead — UI/LootHistoryFrame.lua
-- History tab: list of raid runs + per-player totals + run detail view
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f = ns.mainFrame

----------------------------------------------------------------------
-- Tab content frame
----------------------------------------------------------------------
local histContent = CreateFrame("Frame", nil, f)
histContent:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -68)
histContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
histContent:Hide()

-- Local class-color RGB helper
local ClassColorRGB = ns.ClassColorRGB

-- Lookup a player's class from cached scan data (best-effort)
local function ClassFor(playerName)
    if ns.BuffScan and ns.BuffScan.scanResults
       and ns.BuffScan.scanResults[playerName] then
        return ns.BuffScan.scanResults[playerName].class
    end
    return "UNKNOWN"
end

----------------------------------------------------------------------
-- View state
----------------------------------------------------------------------
local VIEW_RUNS       = "runs"
local VIEW_PLAYERS    = "players"
local VIEW_ATTENDANCE = "attendance"
local VIEW_DETAIL     = "detail"
local currentView    = VIEW_RUNS
local selectedRunId  = nil

----------------------------------------------------------------------
-- Top bar: view toggle + back button
----------------------------------------------------------------------
local topBar = CreateFrame("Frame", nil, histContent)
topBar:SetHeight(24)
topBar:SetPoint("TOPLEFT", histContent, "TOPLEFT", 0, 0)
topBar:SetPoint("TOPRIGHT", histContent, "TOPRIGHT", 0, 0)

-- Per-run "< Back" button (returns from the detail view to the run list).
local backBtn = ns.MakeSmallButton(topBar, "< Back", 90, 22)
backBtn:SetPoint("LEFT", topBar, "LEFT", 0, 0)
backBtn:Hide()

local viewRunsBtn = ns.MakePill(topBar, "Raid Runs")
viewRunsBtn:SetWidth(100)
viewRunsBtn:SetPoint("LEFT", topBar, "LEFT", 0, 0)

local viewPlayersBtn = ns.MakePill(topBar, "Per-Player")
viewPlayersBtn:SetWidth(110)
viewPlayersBtn:SetPoint("LEFT", viewRunsBtn, "RIGHT", 4, 0)

local viewAttendanceBtn = ns.MakePill(topBar, "Attendance")
viewAttendanceBtn:SetWidth(110)
viewAttendanceBtn:SetPoint("LEFT", viewPlayersBtn, "RIGHT", 4, 0)

local headerText = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
headerText:SetPoint("RIGHT", topBar, "RIGHT", -4, 0)
headerText:SetJustifyH("RIGHT")
headerText:SetTextColor(0.7, 0.7, 0.7)

----------------------------------------------------------------------
-- Column header bar (changes per view)
----------------------------------------------------------------------
local colHeader = ns.MakeSectionHeader(histContent, "")
colHeader:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -4)
colHeader:SetPoint("RIGHT", histContent, "RIGHT", -4, 0)

----------------------------------------------------------------------
-- Scroll area
----------------------------------------------------------------------
local scrollParent = CreateFrame("Frame", nil, histContent)
scrollParent:SetPoint("TOPLEFT", colHeader, "BOTTOMLEFT", 0, -4)
scrollParent:SetPoint("BOTTOMRIGHT", histContent, "BOTTOMRIGHT", -20, 36)

local scrollFrame = CreateFrame("ScrollFrame", "RaidLeadHistScroll", histContent, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", scrollParent, "BOTTOMRIGHT", 0, 0)

local scrollInner = CreateFrame("Frame", nil, histContent)
scrollInner:SetAllPoints(scrollParent)

----------------------------------------------------------------------
-- Row pool (shared, repopulated per view)
----------------------------------------------------------------------
local ROW_HEIGHT = 22
local rows = {}

-- Per-item icon button. Has its own OnEnter showing the full game item tooltip.
local function CreateItemIconButton(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(18, 18)
    btn:EnableMouse(true)

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.tex = tex

    btn:SetScript("OnEnter", function(self)
        if not self.itemLink then return end
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetHyperlink(self.itemLink)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        if self.itemLink and IsShiftKeyDown() and ChatEdit_InsertLink then
            ChatEdit_InsertLink(self.itemLink)
        end
    end)
    btn:Hide()
    return btn
end

local function CreateRow(index)
    local row = CreateFrame("Button", nil, scrollInner)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollInner, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", scrollInner, "RIGHT", 0, 0)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    ns.ApplyBackdrop(row, ns.ROW_BACKDROP)
    row.baseR, row.baseG, row.baseB, row.baseA = 0.08, 0.08, 0.10, 0.6

    row:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(self.baseR + 0.10, self.baseG + 0.10, self.baseB + 0.15, 0.85)
        end
        -- Row-level text tooltip (e.g., player summary, run summary)
        if self.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            for _, line in ipairs(self.tooltip) do
                GameTooltip:AddLine(line, 0.9, 0.9, 0.9, true)
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(self.baseR, self.baseG, self.baseB, self.baseA)
        end
        GameTooltip:Hide()
    end)

    -- Up to 4 column font strings (reused for both views)
    for i = 1, 4 do
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row["col" .. i] = fs
    end

    -- Pool of item-icon buttons attached to this row.
    -- Each one is a real Button with its own per-item tooltip on hover.
    row.itemIcons = {}
    for i = 1, 12 do
        row.itemIcons[i] = CreateItemIconButton(row)
    end

    rows[index] = row
    return row
end

-- Helper: hide all per-row item icons. Call when switching views or
-- when a row should not display any items.
local function HideAllIcons(row)
    if not row.itemIcons then return end
    for _, btn in ipairs(row.itemIcons) do
        btn:Hide()
        btn.itemLink = nil
    end
end

-- Helper: lay out a list of loots as real icon buttons starting at xStart.
-- Returns the number of icons displayed.
local function LayoutItemIcons(row, loots, xStart)
    HideAllIcons(row)
    if not loots or #loots == 0 then return 0 end

    local count = 0
    local ICON_W, GAP = 18, 2
    for i, loot in ipairs(loots) do
        local btn = row.itemIcons[i]
        if not btn then break end  -- ran out of pool slots
        local _, link, _, _, _, _, _, _, _, texture =
            GetItemInfo(loot.itemLink or loot.itemId)
        if texture then
            btn.tex:SetTexture(texture)
        else
            btn.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        btn.itemLink = link or loot.itemLink
        btn:ClearAllPoints()
        btn:SetPoint("LEFT", row, "LEFT", xStart + (i - 1) * (ICON_W + GAP), 0)
        btn:Show()
        count = count + 1
    end
    return count
end

----------------------------------------------------------------------
-- Date formatting helper
----------------------------------------------------------------------
local function FormatDate(ts)
    if not ts or ts == 0 then return "?" end
    return date("%Y-%m-%d", ts)
end

local function FormatDateTime(ts)
    if not ts or ts == 0 then return "?" end
    return date("%Y-%m-%d %H:%M", ts)
end

local function FormatTime(ts)
    if not ts or ts == 0 then return "?" end
    return date("%H:%M", ts)
end

----------------------------------------------------------------------
-- View: Raid runs list
----------------------------------------------------------------------
local function CountAttendees(run)
    local n = 0
    if run.attendees then for _ in pairs(run.attendees) do n = n + 1 end end
    return n
end

local function RenderRunsView()
    local runs = ns.LootHistory.GetRuns()

    -- Column layout: Date | Instance | Att | Epics
    local COL = { date = 0, inst = 110, att = 280, epics = 340 }

    colHeader.text:SetText("Date         Instance                Attendees    Epics")

    local parentH = scrollInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / ROW_HEIGHT))
    local total = #runs

    FauxScrollFrame_Update(scrollFrame, total, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, visibleRows do
        local row = rows[i] or CreateRow(i)
        local dataIdx = offset + i

        if dataIdx <= total then
            -- Hide leftover detail-view icon/itemLink from previous render
            HideAllIcons(row)

            local entry = runs[dataIdx]
            local run = entry.data
            local epics = run.loots and #run.loots or 0

            -- Alternating tint
            if dataIdx % 2 == 0 then
                row.baseR, row.baseG, row.baseB, row.baseA = 0.12, 0.12, 0.14, 0.5
            else
                row.baseR, row.baseG, row.baseB, row.baseA = 0.06, 0.06, 0.08, 0.4
            end
            if row.SetBackdropColor then
                row:SetBackdropColor(row.baseR, row.baseG, row.baseB, row.baseA)
            end

            row.col1:ClearAllPoints()
            row.col1:SetPoint("LEFT", row, "LEFT", 4 + COL.date, 0)
            row.col1:SetWidth(105)
            row.col1:SetText(FormatDate(run.startTime))
            row.col1:SetTextColor(0.85, 0.85, 0.85)

            row.col2:ClearAllPoints()
            row.col2:SetPoint("LEFT", row, "LEFT", 4 + COL.inst, 0)
            row.col2:SetWidth(165)
            row.col2:SetText(run.instanceName or "Unknown")
            row.col2:SetTextColor(1, 0.92, 0.55)

            row.col3:ClearAllPoints()
            row.col3:SetPoint("LEFT", row, "LEFT", 4 + COL.att, 0)
            row.col3:SetWidth(55)
            row.col3:SetText(tostring(CountAttendees(run)))
            row.col3:SetTextColor(0.85, 0.85, 0.85)

            row.col4:ClearAllPoints()
            row.col4:SetPoint("LEFT", row, "LEFT", 4 + COL.epics, 0)
            row.col4:SetWidth(60)
            row.col4:SetText(tostring(epics))
            if epics > 0 then
                row.col4:SetTextColor(0.65, 0.35, 0.9)  -- epic-purple-ish
            else
                row.col4:SetTextColor(0.5, 0.5, 0.5)
            end

            row.tooltip = {
                run.instanceName,
                FormatDateTime(run.startTime) .. (run.endTime and (" - " .. FormatTime(run.endTime)) or ""),
                CountAttendees(run) .. " attendees, " .. epics .. " epic loot drops",
                " ",
                "Click for details",
            }

            local runId = entry.id
            row:SetScript("OnClick", function()
                selectedRunId = runId
                currentView = VIEW_DETAIL
                ns.RefreshLootHistory()
            end)

            row:Show()
        else
            row:Hide()
            row.tooltip = nil
            row:SetScript("OnClick", nil)
        end
    end

    for i = visibleRows + 1, #rows do
        rows[i]:Hide()
        rows[i].tooltip = nil
        rows[i]:SetScript("OnClick", nil)
    end

    headerText:SetText(total .. " run" .. (total == 1 and "" or "s") .. " logged")
end

----------------------------------------------------------------------
-- View: Per-player totals
----------------------------------------------------------------------
local function RenderPlayersView()
    local totals = ns.LootHistory.GetPerPlayerTotals()

    colHeader.text:SetText("Player                 Epics       Last received      Top items")

    local parentH = scrollInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / ROW_HEIGHT))
    local total = #totals

    FauxScrollFrame_Update(scrollFrame, total, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, visibleRows do
        local row = rows[i] or CreateRow(i)
        local dataIdx = offset + i

        if dataIdx <= total then
            HideAllIcons(row)

            local entry = totals[dataIdx]
            local info = entry.info

            if dataIdx % 2 == 0 then
                row.baseR, row.baseG, row.baseB, row.baseA = 0.12, 0.12, 0.14, 0.5
            else
                row.baseR, row.baseG, row.baseB, row.baseA = 0.06, 0.06, 0.08, 0.4
            end
            if row.SetBackdropColor then
                row:SetBackdropColor(row.baseR, row.baseG, row.baseB, row.baseA)
            end

            row.col1:ClearAllPoints()
            row.col1:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.col1:SetWidth(140)
            row.col1:SetText(entry.name)
            row.col1:SetTextColor(ClassColorRGB(ClassFor(entry.name)))

            row.col2:ClearAllPoints()
            row.col2:SetPoint("LEFT", row, "LEFT", 4 + 150, 0)
            row.col2:SetWidth(60)
            row.col2:SetText(tostring(info.count))
            row.col2:SetTextColor(0.65, 0.35, 0.9)

            row.col3:ClearAllPoints()
            row.col3:SetPoint("LEFT", row, "LEFT", 4 + 215, 0)
            row.col3:SetWidth(110)
            row.col3:SetText(FormatDate(info.lastTime))
            row.col3:SetTextColor(0.85, 0.85, 0.85)

            -- Top items: real icon buttons (each with its own hover tooltip)
            -- Most-recent first, up to the pool size.
            local items = info.items or {}
            local recent = {}
            for j = #items, math.max(1, #items - 8), -1 do
                recent[#recent + 1] = items[j]
            end
            LayoutItemIcons(row, recent, 4 + 330)

            -- Clear the col4 text since we're using real icon buttons now
            row.col4:SetText("")

            -- Tooltip: full item list
            local tip = { entry.name, info.count .. " epic drops total", " " }
            for _, it in ipairs(items) do
                tip[#tip + 1] = FormatDate(it.time) .. "  " .. (it.itemLink or ("Item " .. it.itemId))
            end
            row.tooltip = tip
            row:SetScript("OnClick", nil)

            row:Show()
        else
            row:Hide()
            row.tooltip = nil
            row:SetScript("OnClick", nil)
        end
    end

    for i = visibleRows + 1, #rows do
        rows[i]:Hide()
        rows[i].tooltip = nil
        rows[i]:SetScript("OnClick", nil)
    end

    headerText:SetText(total .. " player" .. (total == 1 and "" or "s") .. " with loot")
end

----------------------------------------------------------------------
-- View: Attendance
-- One row per known player. Shows how many runs they attended out of
-- the total recorded, when they were last seen, and an attendance bar.
----------------------------------------------------------------------
local function RenderAttendanceView()
    local list = ns.LootHistory.GetPerPlayerAttendance()

    colHeader.text:SetText("Player                 Runs         Last Seen           Attendance")

    local parentH = scrollInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / ROW_HEIGHT))
    local total = #list

    FauxScrollFrame_Update(scrollFrame, total, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    -- Color the % column: high attendance = green, mid = yellow, low = orange
    local function PctColor(p)
        if p >= 80 then return 0.40, 0.95, 0.40 end
        if p >= 50 then return 0.95, 0.85, 0.30 end
        return 0.95, 0.55, 0.30
    end

    for i = 1, visibleRows do
        local row = rows[i] or CreateRow(i)
        local dataIdx = offset + i

        if dataIdx <= total then
            HideAllIcons(row)

            local entry = list[dataIdx]

            if dataIdx % 2 == 0 then
                row.baseR, row.baseG, row.baseB, row.baseA = 0.12, 0.12, 0.14, 0.5
            else
                row.baseR, row.baseG, row.baseB, row.baseA = 0.06, 0.06, 0.08, 0.4
            end
            if row.SetBackdropColor then
                row:SetBackdropColor(row.baseR, row.baseG, row.baseB, row.baseA)
            end

            row.col1:ClearAllPoints()
            row.col1:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.col1:SetWidth(140)
            row.col1:SetText(entry.name)
            row.col1:SetTextColor(ClassColorRGB(ClassFor(entry.name)))

            row.col2:ClearAllPoints()
            row.col2:SetPoint("LEFT", row, "LEFT", 4 + 150, 0)
            row.col2:SetWidth(80)
            row.col2:SetText(entry.runsAttended .. " / " .. entry.totalRuns)
            row.col2:SetTextColor(0.85, 0.85, 0.85)

            row.col3:ClearAllPoints()
            row.col3:SetPoint("LEFT", row, "LEFT", 4 + 235, 0)
            row.col3:SetWidth(110)
            row.col3:SetText(FormatDate(entry.lastSeen))
            row.col3:SetTextColor(0.75, 0.75, 0.75)

            row.col4:ClearAllPoints()
            row.col4:SetPoint("LEFT", row, "LEFT", 4 + 350, 0)
            row.col4:SetWidth(110)
            row.col4:SetText(string.format("%.0f%%", entry.pct))
            row.col4:SetTextColor(PctColor(entry.pct))

            row.tooltip = {
                entry.name,
                "Attended " .. entry.runsAttended .. " of " .. entry.totalRuns .. " runs",
                string.format("%.1f%% attendance", entry.pct),
                "Last seen: " .. FormatDate(entry.lastSeen),
            }
            row:SetScript("OnClick", nil)
            row:Show()
        else
            row:Hide()
            row.tooltip = nil
            row:SetScript("OnClick", nil)
        end
    end

    for i = visibleRows + 1, #rows do
        rows[i]:Hide()
        rows[i].tooltip = nil
        rows[i]:SetScript("OnClick", nil)
    end

    headerText:SetText(total .. " unique player" .. (total == 1 and "" or "s")
        .. " across history")
end

----------------------------------------------------------------------
-- View: Run detail (one row per attendee with their loot grouped inline)
----------------------------------------------------------------------

-- Get the class from the run's stored attendee map; fall back to scan cache.
local function RunAttendeeClass(run, playerName)
    if run.attendees then
        local v = run.attendees[playerName]
        if type(v) == "string" then return v end  -- "PALADIN" etc.
    end
    return ClassFor(playerName)
end

-- Build a sorted list of {name, class, loots[]} for a run.
-- Sort: players with loot first (most loot first), then alphabetical.
local function BuildAttendeeRows(run)
    local rowsOut = {}
    local lootByPlayer = {}
    for _, loot in ipairs(run.loots or {}) do
        local list = lootByPlayer[loot.player]
        if not list then list = {}; lootByPlayer[loot.player] = list end
        list[#list + 1] = loot
    end
    -- include everyone in attendees + anyone who got loot but isn't listed
    local seen = {}
    for name in pairs(run.attendees or {}) do
        seen[name] = true
        rowsOut[#rowsOut + 1] = {
            name  = name,
            class = RunAttendeeClass(run, name),
            loots = lootByPlayer[name] or {},
        }
    end
    for name, list in pairs(lootByPlayer) do
        if not seen[name] then
            rowsOut[#rowsOut + 1] = {
                name  = name,
                class = RunAttendeeClass(run, name),
                loots = list,
            }
        end
    end
    table.sort(rowsOut, function(a, b)
        local an = #a.loots
        local bn = #b.loots
        if an ~= bn then return an > bn end
        return a.name < b.name
    end)
    return rowsOut
end

local function RenderDetailView()
    local run = selectedRunId and ns.LootHistory.GetRun(selectedRunId)
    if not run then
        currentView = VIEW_RUNS
        return RenderRunsView()
    end

    local attendeesCount = CountAttendees(run)
    local lootsCount     = run.loots and #run.loots or 0

    colHeader.text:SetText(
        (run.instanceName or "Unknown") .. "   " ..
        FormatDateTime(run.startTime) ..
        (run.endTime and ("   -   " .. FormatTime(run.endTime)) or "")
    )
    headerText:SetText(attendeesCount .. " attendees, " .. lootsCount .. " epic drops")

    local attendeeRows = BuildAttendeeRows(run)
    local total        = #attendeeRows

    local parentH = scrollInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / ROW_HEIGHT))

    FauxScrollFrame_Update(scrollFrame, total, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, visibleRows do
        local row = rows[i] or CreateRow(i)
        local dataIdx = offset + i

        if dataIdx <= total then
            local entry = attendeeRows[dataIdx]
            local lootList = entry.loots

            -- Alternating tint
            if dataIdx % 2 == 0 then
                row.baseR, row.baseG, row.baseB, row.baseA = 0.12, 0.12, 0.14, 0.5
            else
                row.baseR, row.baseG, row.baseB, row.baseA = 0.06, 0.06, 0.08, 0.4
            end
            if row.SetBackdropColor then
                row:SetBackdropColor(row.baseR, row.baseG, row.baseB, row.baseA)
            end

            -- Hide leftover single-item icon (the run-detail row uses inline icons)
            HideAllIcons(row)

            -- Player name (class-colored)
            row.col1:ClearAllPoints()
            row.col1:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.col1:SetWidth(140)
            row.col1:SetText(entry.name)
            row.col1:SetTextColor(ClassColorRGB(entry.class))

            -- Loot count column
            row.col2:ClearAllPoints()
            row.col2:SetPoint("LEFT", row, "LEFT", 4 + 150, 0)
            row.col2:SetWidth(50)
            if #lootList > 0 then
                row.col2:SetText(tostring(#lootList) .. "x")
                row.col2:SetTextColor(0.65, 0.35, 0.9)
            else
                row.col2:SetText("-")
                row.col2:SetTextColor(0.4, 0.4, 0.4)
            end

            row.col3:SetText("")
            row.col4:SetText("")

            -- Real per-item icon buttons (each has its own hover tooltip)
            LayoutItemIcons(row, lootList, 4 + 205)

            -- Row hover tooltip only when the row has no icons. Hovering an
            -- icon shows the full WoW item tooltip via its own handler.
            if #lootList == 0 then
                row.tooltip = { entry.name, " ", "|cFF888888no loot from this run|r" }
            else
                row.tooltip = nil
            end

            row:SetScript("OnClick", nil)
            row:Show()
        else
            row:Hide()
            HideAllIcons(row)
            row.tooltip = nil
            row:SetScript("OnClick", nil)
        end
    end

    for i = visibleRows + 1, #rows do
        rows[i]:Hide()
        rows[i]:SetScript("OnClick", nil)
    end
end

----------------------------------------------------------------------
-- Master refresh
----------------------------------------------------------------------
local function RefreshHistory()
    -- Toggle buttons based on current view
    if currentView == VIEW_DETAIL then
        viewRunsBtn:Hide()
        viewPlayersBtn:Hide()
        viewAttendanceBtn:Hide()
        backBtn:Show()
    else
        viewRunsBtn:Show()
        viewPlayersBtn:Show()
        viewAttendanceBtn:Show()
        backBtn:Hide()

        viewRunsBtn:SetActive(currentView == VIEW_RUNS)
        viewPlayersBtn:SetActive(currentView == VIEW_PLAYERS)
        viewAttendanceBtn:SetActive(currentView == VIEW_ATTENDANCE)
    end

    if currentView == VIEW_RUNS then
        RenderRunsView()
    elseif currentView == VIEW_PLAYERS then
        RenderPlayersView()
    elseif currentView == VIEW_ATTENDANCE then
        RenderAttendanceView()
    elseif currentView == VIEW_DETAIL then
        RenderDetailView()
    end
end
ns.RefreshLootHistory = RefreshHistory

scrollFrame:SetScript("OnVerticalScroll", function(self, off)
    FauxScrollFrame_OnVerticalScroll(self, off, ROW_HEIGHT, RefreshHistory)
end)

----------------------------------------------------------------------
-- Top-bar button handlers
----------------------------------------------------------------------
viewRunsBtn:SetScript("OnClick", function()
    currentView = VIEW_RUNS
    selectedRunId = nil
    RefreshHistory()
end)
viewPlayersBtn:SetScript("OnClick", function()
    currentView = VIEW_PLAYERS
    selectedRunId = nil
    RefreshHistory()
end)
viewAttendanceBtn:SetScript("OnClick", function()
    currentView = VIEW_ATTENDANCE
    selectedRunId = nil
    RefreshHistory()
end)
backBtn:SetScript("OnClick", function()
    currentView = VIEW_RUNS
    selectedRunId = nil
    RefreshHistory()
end)

----------------------------------------------------------------------
-- Bottom: Clear button
----------------------------------------------------------------------
local clearBtn = ns.MakeSmallButton(histContent, "Clear History", 110, 24)
clearBtn:SetPoint("BOTTOMLEFT", histContent, "BOTTOMLEFT", 0, 4)
clearBtn:SetScript("OnClick", function()
    -- Two-click confirm to avoid accidents
    if clearBtn.armed then
        clearBtn.armed = nil
        ns.LootHistory.ClearAll()
        currentView = VIEW_RUNS
        selectedRunId = nil
        RefreshHistory()
        clearBtn:SetText("Clear History")
    else
        clearBtn.armed = true
        clearBtn:SetText("|cFFFF6666Confirm?|r")
        C_Timer.After(3, function()
            if clearBtn.armed then
                clearBtn.armed = nil
                clearBtn:SetText("Clear History")
            end
        end)
    end
end)
clearBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Clear History", 1, 0.4, 0.4)
    GameTooltip:AddLine("Wipes all loot history. Click twice to confirm.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
clearBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

----------------------------------------------------------------------
-- Register as a regular tab. The top-right history icon (MainFrame.lua)
-- is just a shortcut that selects this tab.
----------------------------------------------------------------------
ns.lootHistContent = histContent  -- still exposed for the icon shortcut
ns.RefreshLootHistory = RefreshHistory
ns.RegisterTab("History", 29, histContent, RefreshHistory)
