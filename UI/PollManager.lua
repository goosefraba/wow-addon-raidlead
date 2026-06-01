----------------------------------------------------------------------
-- RaidLead — UI/PollManager.lua
-- "Polls" tab. Two sub-views via a pill toggle:
--   Questions — lead-managed library of custom poll questions (each with
--               its own options and single/multi-select mode). Launched
--               from the Quick Poll launcher alongside the built-in presets.
--   History   — past poll results, kept locally for whoever ran the poll.
--               Not shared; can be re-announced to raid/party chat.
-- Editing the library and clearing history require edit permission
-- (raid leader / assistant); others see read-only behavior.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f = ns.mainFrame
local MAX_OPTIONS = 6

----------------------------------------------------------------------
-- Tab content frame
----------------------------------------------------------------------
local pollContent = CreateFrame("Frame", nil, f)
pollContent:SetPoint("TOPLEFT",     f, "TOPLEFT",      10, -68)
pollContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10,  10)
pollContent:Hide()

-- Forward declarations
local RefreshList, RefreshHistory, OpenEditor, SetView
local viewMode = "questions"

----------------------------------------------------------------------
-- Top bar: view pills (left) + Quick Poll (right)
----------------------------------------------------------------------
local questionsPill = ns.MakePill(pollContent, "Questions")
questionsPill:SetWidth(90)
questionsPill:SetPoint("TOPLEFT", pollContent, "TOPLEFT", 4, -2)
questionsPill:SetScript("OnClick", function() SetView("questions") end)

local historyPill = ns.MakePill(pollContent, "History")
historyPill:SetWidth(80)
historyPill:SetPoint("LEFT", questionsPill, "RIGHT", 6, 0)
historyPill:SetScript("OnClick", function() SetView("history") end)

local sendBtn = ns.MakeSmallButton(pollContent, "Quick Poll", 100, 22)
sendBtn:SetPoint("TOPRIGHT", pollContent, "TOPRIGHT", -4, -2)
sendBtn:SetScript("OnClick", function()
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can start a poll.|r")
        return
    end
    if ns.ShowPollLauncher then ns.ShowPollLauncher() end
end)

----------------------------------------------------------------------
-- Questions view
----------------------------------------------------------------------
local questionsView = CreateFrame("Frame", nil, pollContent)
questionsView:SetPoint("TOPLEFT",     pollContent, "TOPLEFT",      0, -28)
questionsView:SetPoint("BOTTOMRIGHT", pollContent, "BOTTOMRIGHT",  0,   0)

local hint = questionsView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", questionsView, "TOPLEFT", 4, -2)
hint:SetJustifyH("LEFT")
hint:SetTextColor(0.6, 0.6, 0.6)
hint:SetText("Custom questions you can broadcast from the Quick Poll launcher.")

local newBtn = ns.MakeSmallButton(questionsView, "New Question", 110, 22)
newBtn:SetPoint("TOPLEFT", questionsView, "TOPLEFT", 4, -20)
newBtn:SetScript("OnClick", function()
    if ns.CanEdit and not ns.CanEdit() then ns.LockedNotice(); return end
    OpenEditor(nil)
end)

local listHeader = ns.MakeSectionHeader(questionsView, "Your Questions")
listHeader:SetPoint("TOPLEFT",  questionsView, "TOPLEFT",  0, -46)
listHeader:SetPoint("RIGHT",    questionsView, "RIGHT",   -4,  0)

local emptyMsg = questionsView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
emptyMsg:SetPoint("TOPLEFT", questionsView, "TOPLEFT", 8, -74)
emptyMsg:SetTextColor(0.5, 0.5, 0.5)
emptyMsg:SetText("No custom questions yet. Click |cFFFFCC00New Question|r to add one.")
emptyMsg:Hide()

local listRows = {}
local ROW_H = 38

local function GetListRow(i)
    local row = listRows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, questionsView)
    row:SetSize(10, ROW_H)
    row:SetPoint("TOPLEFT",  questionsView, "TOPLEFT",  4, -72 - (i - 1) * (ROW_H + 4))
    row:SetPoint("RIGHT",    questionsView, "RIGHT",   -4, 0)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.10, 0.10, 0.13, 0.6)

    row.editBtn = ns.MakeSmallButton(row, "Edit", 48, 22)
    row.editBtn:SetPoint("RIGHT", row, "RIGHT", -32, 0)

    row.delBtn = ns.MakeSmallButton(row, "X", 24, 22)
    row.delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row.question = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.question:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.question:SetPoint("RIGHT",   row.editBtn, "LEFT", -8, 0)
    row.question:SetJustifyH("LEFT")
    row.question:SetWordWrap(false)

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 5)
    row.detail:SetPoint("RIGHT",      row.editBtn, "LEFT", -8, 0)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)
    row.detail:SetTextColor(0.6, 0.6, 0.6)

    listRows[i] = row
    return row
end

RefreshList = function()
    local polls   = (ns.db and ns.db.customPolls) or {}
    local canEdit = (not ns.CanEdit) or ns.CanEdit()

    newBtn:SetAlpha(canEdit and 1 or 0.4)

    for _, row in ipairs(listRows) do row:Hide() end
    emptyMsg:SetShown(#polls == 0)

    for i, poll in ipairs(polls) do
        local row = GetListRow(i)
        row.question:SetText(poll.question or "(untitled)")
        local mode = poll.multi and "pick several" or "pick one"
        row.detail:SetText(table.concat(poll.options or {}, " / ")
            .. "  |cFF6699CC\194\183 " .. mode .. "|r")

        row.editBtn:SetAlpha(canEdit and 1 or 0.4)
        row.delBtn:SetAlpha(canEdit and 1 or 0.4)

        local idx = i
        row.editBtn:SetScript("OnClick", function()
            if ns.CanEdit and not ns.CanEdit() then ns.LockedNotice(); return end
            OpenEditor(idx)
        end)
        row.delBtn:SetScript("OnClick", function()
            if ns.CanEdit and not ns.CanEdit() then ns.LockedNotice(); return end
            table.remove(ns.db.customPolls, idx)
            RefreshList()
        end)
        row:Show()
    end
end

----------------------------------------------------------------------
-- History view
----------------------------------------------------------------------
local historyView = CreateFrame("Frame", nil, pollContent)
historyView:SetPoint("TOPLEFT",     pollContent, "TOPLEFT",      0, -28)
historyView:SetPoint("BOTTOMRIGHT", pollContent, "BOTTOMRIGHT",  0,   0)
historyView:Hide()

local histHint = historyView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
histHint:SetPoint("TOPLEFT", historyView, "TOPLEFT", 4, -2)
histHint:SetJustifyH("LEFT")
histHint:SetTextColor(0.6, 0.6, 0.6)
histHint:SetText("Past poll results (only you can see these). Re-announce posts the tally to chat.")

local clearHistBtn = ns.MakeSmallButton(historyView, "Clear History", 110, 22)
clearHistBtn:SetPoint("TOPRIGHT", historyView, "TOPRIGHT", -4, -2)
clearHistBtn:SetScript("OnClick", function(self)
    if ns.CanEdit and not ns.CanEdit() then ns.LockedNotice(); return end
    if self.armed then
        self.armed = nil
        ns.db.pollHistory = {}
        self:SetText("Clear History")
        RefreshHistory()
    else
        self.armed = true
        self:SetText("|cFFFF6666Confirm?|r")
        C_Timer.After(3, function()
            if self.armed then self.armed = nil; self:SetText("Clear History") end
        end)
    end
end)

local histHeader = ns.MakeSectionHeader(historyView, "Past Polls")
histHeader:SetPoint("TOPLEFT", historyView, "TOPLEFT", 0, -28)
histHeader:SetPoint("RIGHT",   historyView, "RIGHT",  -4,  0)

local histEmpty = historyView:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
histEmpty:SetPoint("TOPLEFT", historyView, "TOPLEFT", 8, -56)
histEmpty:SetTextColor(0.5, 0.5, 0.5)
histEmpty:SetText("No polls run yet. Results show up here after a poll ends.")
histEmpty:Hide()

local histRows = {}
local HROW_H = 40

local function FormatPollDate(ts)
    if not ts or ts == 0 then return "?" end
    return date("%Y-%m-%d %H:%M", ts)
end

-- Compact "Yes 5 / No 3" summary from a stored entry.
local function StoredSummary(entry)
    local parts = {}
    for i, opt in ipairs(entry.options or {}) do
        local c = (entry.counts and entry.counts[i]) or 0
        parts[#parts + 1] = opt .. " " .. c
    end
    return table.concat(parts, " / ")
end

local function GetHistRow(i)
    local row = histRows[i]
    if row then return row end

    row = CreateFrame("Button", nil, historyView)
    row:SetSize(10, HROW_H)
    row:SetPoint("TOPLEFT", historyView, "TOPLEFT", 4, -54 - (i - 1) * (HROW_H + 4))
    row:SetPoint("RIGHT",   historyView, "RIGHT",  -4, 0)
    row:RegisterForClicks("LeftButtonUp")

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.10, 0.10, 0.13, 0.6)

    -- Clicking the row (anywhere but the Announce button) opens the
    -- per-voter breakdown for that poll.
    row:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.16, 0.16, 0.20, 0.85)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Click to see who voted", 1, 0.82, 0.1)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.10, 0.10, 0.13, 0.6)
        GameTooltip:Hide()
    end)

    row.reBtn = ns.MakeSmallButton(row, "Announce", 90, 22)
    row.reBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    row.question = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.question:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -4)
    row.question:SetPoint("RIGHT",   row.reBtn, "LEFT", -8, 0)
    row.question:SetJustifyH("LEFT")
    row.question:SetWordWrap(false)

    row.detail = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 5)
    row.detail:SetPoint("RIGHT",      row.reBtn, "LEFT", -8, 0)
    row.detail:SetJustifyH("LEFT")
    row.detail:SetWordWrap(false)
    row.detail:SetTextColor(0.6, 0.6, 0.6)

    histRows[i] = row
    return row
end

RefreshHistory = function()
    local hist    = (ns.db and ns.db.pollHistory) or {}
    local canEdit = (not ns.CanEdit) or ns.CanEdit()

    clearHistBtn:SetAlpha(canEdit and 1 or 0.4)
    clearHistBtn:SetShown(#hist > 0)

    for _, row in ipairs(histRows) do row:Hide() end
    histEmpty:SetShown(#hist == 0)

    for i, entry in ipairs(hist) do
        local row = GetHistRow(i)
        row.question:SetText(entry.question or "(untitled)")
        row.detail:SetText("|cFF888888" .. FormatPollDate(entry.endedAt) .. "|r  "
            .. StoredSummary(entry)
            .. "  |cFF6699CC\194\183 " .. (entry.voterTotal or 0) .. " voters|r")

        local e = entry
        local canBroadcast = (not ns.CanBroadcast) or ns.CanBroadcast()
        row.reBtn:SetAlpha(canBroadcast and 1 or 0.4)
        row.reBtn:SetScript("OnClick", function()
            ns.Polls.AnnounceStored(e)
        end)
        row:SetScript("OnClick", function()
            if ns.ShowPollVotersDetail then ns.ShowPollVotersDetail(e) end
        end)
        row:Show()
    end
end

----------------------------------------------------------------------
-- Per-voter detail popup (opened by clicking a History row)
----------------------------------------------------------------------
local votersDetail

local function BuildVotersDetail()
    if votersDetail then return votersDetail end

    local d = CreateFrame("Frame", "RaidLeadPollVoters", UIParent)
    d:SetSize(360, 280)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetFrameLevel(220)
    d:EnableMouse(true)
    d:SetMovable(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", function(s) s:StartMoving() end)
    d:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    d:Hide()

    ns.ApplyBackdrop(d, ns.DIALOG_BACKDROP)
    tinsert(UISpecialFrames, "RaidLeadPollVoters")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -2, -2)

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", d, "TOP", 0, -14)
    title:SetText("|cFFFFCC00Poll Votes|r")

    d.question = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    d.question:SetPoint("TOPLEFT",  d, "TOPLEFT",  16, -40)
    d.question:SetPoint("TOPRIGHT", d, "TOPRIGHT", -16, -40)
    d.question:SetJustifyH("CENTER")
    d.question:SetTextColor(0.95, 0.95, 0.85)

    d.meta = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.meta:SetPoint("TOPLEFT",  d, "TOPLEFT",  16, -60)
    d.meta:SetPoint("TOPRIGHT", d, "TOPRIGHT", -16, -60)
    d.meta:SetJustifyH("CENTER")
    d.meta:SetTextColor(0.6, 0.6, 0.6)

    d.barRows = {}   -- pooled result bars (shared renderer)

    d.list = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.list:SetJustifyH("LEFT")
    d.list:SetJustifyV("TOP")
    d.list:SetTextColor(0.85, 0.85, 0.85)

    votersDetail = d
    return d
end

-- Build the sorted "Name: pick(s) (tag)" lines from a stored history entry.
local function BuildVoterLines(entry)
    local SRC_TAG = { chat = "  |cFF6699CC(chat)|r", whisper = "  |cFF9988CC(whisper)|r" }
    local names = {}
    for name in pairs(entry.votes or {}) do names[#names + 1] = name end
    table.sort(names)

    local MAX_SHOWN = 40
    local lines, shown = {}, 0
    for _, name in ipairs(names) do
        shown = shown + 1
        if shown > MAX_SHOWN then
            lines[#lines + 1] = "|cFF888888...and " .. (#names - MAX_SHOWN) .. " more|r"
            break
        end
        local picks = {}
        for _, idx in ipairs(entry.votes[name]) do
            picks[#picks + 1] = (entry.options and entry.options[idx]) or "?"
        end
        local cc  = ns.ClassColor and ns.ClassColor(ns.ClassOf and ns.ClassOf(name) or "UNKNOWN")
            or "|cFFFFFFFF"
        local tag = SRC_TAG[(entry.voteSource or {})[name]] or ""
        lines[#lines + 1] = cc .. name .. "|r  |cFFCCCCCC"
            .. table.concat(picks, ", ") .. "|r" .. tag
    end
    return lines, #names
end

function ns.ShowPollVotersDetail(entry)
    if not entry then return end
    local d = BuildVotersDetail()

    d.question:SetText(entry.question or "(untitled)")

    local lines, nVoters = BuildVoterLines(entry)
    local voterTotal = entry.voterTotal or nVoters
    local when = (entry.endedAt and entry.endedAt > 0)
        and date("%Y-%m-%d %H:%M", entry.endedAt) or "?"
    d.meta:SetText(when .. "  |cFF6699CC\194\183|r  " .. voterTotal
        .. (voterTotal == 1 and " voter" or " voters"))

    -- Result bars (same look as the live Poll Results window). Available
    -- for every history entry since counts are always stored.
    local options = entry.options or {}
    local ROW_H   = 26
    local rowW    = (d:GetWidth() or 360) - 32
    ns.RenderPollBars(d, d.barRows, options, entry.counts or {}, voterTotal, -82, rowW)
    local barsBottom = 82 + #options * (ROW_H + 4)

    -- Per-voter list below the bars.
    d.list:ClearAllPoints()
    d.list:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -(barsBottom + 6))
    d.list:SetPoint("RIGHT",   d, "RIGHT",  -16,  0)

    if nVoters == 0 then
        -- Older history entries (recorded before per-voter capture) have no
        -- per-voter data; show a friendly note instead of a blank list.
        if entry.votes then
            d.list:SetText("|cFF888888No one voted.|r")
        else
            d.list:SetText("|cFF888888No per-voter detail for this poll "
                .. "(recorded before this feature).|r")
        end
    else
        d.list:SetText(table.concat(lines, "\n"))
    end

    local LINE_H   = 14
    local listRows = math.max(1, math.min(nVoters, 41))
    d:SetHeight(math.max(170, barsBottom + listRows * LINE_H + 22))
    d:Show()
end

----------------------------------------------------------------------
-- View toggle
----------------------------------------------------------------------
SetView = function(mode)
    viewMode = mode
    local showQuestions = (mode ~= "history")
    questionsView:SetShown(showQuestions)
    historyView:SetShown(not showQuestions)
    if questionsPill.SetActive then questionsPill:SetActive(showQuestions) end
    if historyPill.SetActive   then historyPill:SetActive(not showQuestions) end
    if showQuestions then RefreshList() else RefreshHistory() end
end

----------------------------------------------------------------------
-- Editor popup (Questions view)
----------------------------------------------------------------------
local editor

local function MakeLabeledInput(parent, labelText, x, y, width)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(labelText)
    lbl:SetTextColor(0.8, 0.8, 0.8)

    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 6, y - 16)
    eb:SetSize(width, 20)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(120)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
    eb:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)
    return eb
end

local function BuildEditor()
    if editor then return end

    editor = CreateFrame("Frame", "RaidLeadPollEditor", UIParent)
    editor:SetSize(340, 400)
    editor:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    editor:SetFrameStrata("FULLSCREEN_DIALOG")
    editor:SetFrameLevel(200)
    editor:EnableMouse(true)
    editor:SetMovable(true)
    editor:RegisterForDrag("LeftButton")
    editor:SetScript("OnDragStart", function(s) s:StartMoving() end)
    editor:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    editor:Hide()

    ns.ApplyBackdrop(editor, ns.DIALOG_BACKDROP)
    tinsert(UISpecialFrames, "RaidLeadPollEditor")

    local closeBtn = CreateFrame("Button", nil, editor, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -2, -2)

    editor.title = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    editor.title:SetPoint("TOP", editor, "TOP", 0, -14)
    editor.title:SetText("|cFFFFCC00New Question|r")

    -- Question
    editor.questionInput = MakeLabeledInput(editor, "Question", 16, -44, 300)

    -- Options
    editor.optionInputs = {}
    local optLbl = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optLbl:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, -84)
    optLbl:SetText("Options (2 minimum, blanks ignored)")
    optLbl:SetTextColor(0.8, 0.8, 0.8)

    local oy = -102
    for i = 1, MAX_OPTIONS do
        local eb = CreateFrame("EditBox", nil, editor, "InputBoxTemplate")
        eb:SetPoint("TOPLEFT", editor, "TOPLEFT", 22, oy)
        eb:SetSize(294, 20)
        eb:SetAutoFocus(false)
        eb:SetMaxLetters(60)
        eb:SetFontObject("GameFontHighlightSmall")
        eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        eb:SetScript("OnEnterPressed",  function(s) s:ClearFocus() end)
        editor.optionInputs[i] = eb
        oy = oy - 26
    end

    -- Mode toggle
    local modeLbl = editor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    modeLbl:SetPoint("TOPLEFT", editor, "TOPLEFT", 16, oy - 6)
    modeLbl:SetText("Voters may:")
    modeLbl:SetTextColor(0.8, 0.8, 0.8)

    editor.pickOneBtn = ns.MakePill(editor, "Pick one")
    editor.pickOneBtn:SetWidth(80)
    editor.pickOneBtn:SetPoint("TOPLEFT", editor, "TOPLEFT", 90, oy - 2)

    editor.pickManyBtn = ns.MakePill(editor, "Pick several")
    editor.pickManyBtn:SetWidth(100)
    editor.pickManyBtn:SetPoint("LEFT", editor.pickOneBtn, "RIGHT", 6, 0)

    local function SetMulti(multi)
        editor.multi = multi and true or false
        editor.pickOneBtn:SetActive(not editor.multi)
        editor.pickManyBtn:SetActive(editor.multi)
    end
    editor.SetMulti = SetMulti
    editor.pickOneBtn:SetScript("OnClick",  function() SetMulti(false) end)
    editor.pickManyBtn:SetScript("OnClick", function() SetMulti(true)  end)

    -- Save / Cancel
    local saveBtn = ns.MakeSmallButton(editor, "Save", 90, 24)
    saveBtn:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", -16, 14)
    saveBtn:SetScript("OnClick", function()
        if ns.CanEdit and not ns.CanEdit() then ns.LockedNotice(); editor:Hide(); return end
        local question = (editor.questionInput:GetText() or ""):trim()
        if question == "" then
            ns.P("|cFFFF8800Enter a question first.|r")
            return
        end
        local options = {}
        for _, eb in ipairs(editor.optionInputs) do
            local t = (eb:GetText() or ""):trim()
            if t ~= "" then options[#options + 1] = t end
        end
        if #options < 2 then
            ns.P("|cFFFF8800Add at least 2 options.|r")
            return
        end

        local entry = { question = question, options = options, multi = editor.multi }
        if editor.editIndex then
            ns.db.customPolls[editor.editIndex] = entry
        else
            ns.db.customPolls[#ns.db.customPolls + 1] = entry
        end
        editor:Hide()
        RefreshList()
    end)

    local cancelBtn = ns.MakeSmallButton(editor, "Cancel", 90, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", saveBtn, "BOTTOMLEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() editor:Hide() end)
end

OpenEditor = function(index)
    BuildEditor()
    editor.editIndex = index

    local poll = index and ns.db.customPolls[index] or nil
    editor.title:SetText(index and "|cFFFFCC00Edit Question|r"
                                or "|cFFFFCC00New Question|r")
    editor.questionInput:SetText(poll and poll.question or "")
    for i, eb in ipairs(editor.optionInputs) do
        eb:SetText(poll and poll.options and poll.options[i] or "")
    end
    editor.SetMulti(poll and poll.multi or false)

    editor:Show()
    editor.questionInput:SetFocus()
end

----------------------------------------------------------------------
-- Tab refresh: refresh the active view (also exposed for permission and
-- poll-end updates from elsewhere).
----------------------------------------------------------------------
local function RefreshPollManager()
    if viewMode == "history" then RefreshHistory() else RefreshList() end
end
ns.RefreshPollManager = RefreshPollManager

-- Initial state
SetView("questions")

----------------------------------------------------------------------
-- Register the tab (between Roles and Profile)
----------------------------------------------------------------------
ns.RegisterTab("Polls", 28, pollContent, RefreshPollManager)
