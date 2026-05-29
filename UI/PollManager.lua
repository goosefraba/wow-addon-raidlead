----------------------------------------------------------------------
-- RaidLead — UI/PollManager.lua
-- "Polls" tab: lead manages a library of custom poll questions, each
-- with its own options and single/multi-select mode. The launcher
-- (UI/PollDialog.lua) offers these alongside the built-in presets.
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

local hint = pollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", pollContent, "TOPLEFT", 4, -2)
hint:SetJustifyH("LEFT")
hint:SetTextColor(0.6, 0.6, 0.6)
hint:SetText("Custom questions you can broadcast from the Quick Poll launcher.")

local newBtn = ns.MakeSmallButton(pollContent, "New Question", 110, 22)
newBtn:SetPoint("TOPLEFT", pollContent, "TOPLEFT", 4, -24)

local sendBtn = ns.MakeSmallButton(pollContent, "Quick Poll", 100, 22)
sendBtn:SetPoint("TOPRIGHT", pollContent, "TOPRIGHT", -4, -24)
sendBtn:SetScript("OnClick", function()
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can start a poll.|r")
        return
    end
    if ns.ShowPollLauncher then ns.ShowPollLauncher() end
end)

local listHeader = ns.MakeSectionHeader(pollContent, "Your Questions")
listHeader:SetPoint("TOPLEFT",  pollContent, "TOPLEFT",  0, -52)
listHeader:SetPoint("RIGHT",    pollContent, "RIGHT",   -4,  0)

local emptyMsg = pollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
emptyMsg:SetPoint("TOPLEFT", pollContent, "TOPLEFT", 8, -82)
emptyMsg:SetTextColor(0.5, 0.5, 0.5)
emptyMsg:SetText("No custom questions yet. Click |cFFFFCC00New Question|r to add one.")
emptyMsg:Hide()

----------------------------------------------------------------------
-- Question list (simple pooled rows)
----------------------------------------------------------------------
local listRows = {}
local RefreshList  -- forward decl
local OpenEditor   -- forward decl

local ROW_H = 38
local function GetListRow(i)
    local row = listRows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, pollContent)
    row:SetSize(10, ROW_H)
    row:SetPoint("TOPLEFT",  pollContent, "TOPLEFT",  4, -80 - (i - 1) * (ROW_H + 4))
    row:SetPoint("RIGHT",    pollContent, "RIGHT",   -4, 0)

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
    local polls = (ns.db and ns.db.customPolls) or {}

    for _, row in ipairs(listRows) do row:Hide() end
    emptyMsg:SetShown(#polls == 0)

    for i, poll in ipairs(polls) do
        local row = GetListRow(i)
        row.question:SetText(poll.question or "(untitled)")
        local mode = poll.multi and "pick several" or "pick one"
        row.detail:SetText(table.concat(poll.options or {}, " / ")
            .. "  |cFF6699CC\194\183 " .. mode .. "|r")

        local idx = i
        row.editBtn:SetScript("OnClick", function() OpenEditor(idx) end)
        row.delBtn:SetScript("OnClick", function()
            table.remove(ns.db.customPolls, idx)
            RefreshList()
        end)
        row:Show()
    end
end

newBtn:SetScript("OnClick", function() OpenEditor(nil) end)

----------------------------------------------------------------------
-- Editor popup
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
-- Register the tab (between Roles and Profile)
----------------------------------------------------------------------
ns.RegisterTab("Polls", 28, pollContent, RefreshList)
