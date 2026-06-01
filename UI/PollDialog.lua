----------------------------------------------------------------------
-- RaidLead - UI/PollDialog.lua
-- Three surfaces for the polling system:
--   1) Launcher dialog  - lead picks a preset to broadcast
--   2) Vote dialog      - recipients pick an option
--   3) Results window   - initiator watches live tally
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Shared lookup so we can hide a vote dialog by pollId
----------------------------------------------------------------------
local activeVoteDialog  -- only one at a time
local resultsWindow

----------------------------------------------------------------------
-- 1) Launcher: lead picks a preset poll
----------------------------------------------------------------------
local launcherDialog
local launcherRows = {}

-- Gather the lead's managed questions (built-in presets are seeded into
-- this same list on first load, so there's only one source now). Each
-- carries its own single/multi mode.
local function CollectPollChoices()
    local list = {}
    if ns.db and ns.db.customPolls then
        for _, c in ipairs(ns.db.customPolls) do
            if c.question and c.options and #c.options >= 2 then
                list[#list + 1] = {
                    question = c.question,
                    options  = c.options,
                    multi    = c.multi and true or false,
                }
            end
        end
    end
    return list
end

local function BuildLauncher()
    if launcherDialog then return end

    launcherDialog = CreateFrame("Frame", "RaidLeadPollLauncher", UIParent)
    launcherDialog:SetSize(360, 280)
    launcherDialog:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    launcherDialog:SetFrameStrata("DIALOG")
    launcherDialog:SetFrameLevel(100)
    launcherDialog:EnableMouse(true)
    launcherDialog:SetMovable(true)
    launcherDialog:RegisterForDrag("LeftButton")
    launcherDialog:SetScript("OnDragStart", function(s) s:StartMoving() end)
    launcherDialog:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    launcherDialog:Hide()

    ns.ApplyBackdrop(launcherDialog, ns.DIALOG_BACKDROP)

    local closeBtn = CreateFrame("Button", nil, launcherDialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", launcherDialog, "TOPRIGHT", -2, -2)

    local title = launcherDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", launcherDialog, "TOP", 0, -14)
    title:SetText("|cFFFFCC00Quick Poll|r")

    local subtitle = launcherDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subtitle:SetPoint("TOPLEFT",  launcherDialog, "TOPLEFT",  16, -38)
    subtitle:SetPoint("TOPRIGHT", launcherDialog, "TOPRIGHT", -16, -38)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetTextColor(0.7, 0.7, 0.7)
    subtitle:SetText("Pick a question. RaidLead users get a vote popup; "
        .. "enable chat voting below to include everyone else.")

    local cancelBtn = ns.MakeSmallButton(launcherDialog, "Cancel", 90, 24)
    cancelBtn:SetPoint("BOTTOMRIGHT", launcherDialog, "BOTTOMRIGHT", -16, 24)
    cancelBtn:SetScript("OnClick", function() launcherDialog:Hide() end)

    -- "Chat voting" toggle: posts numbered instructions to chat and scans
    -- replies/whispers so people without the addon can still vote.
    local chatCheck = CreateFrame("CheckButton", nil, launcherDialog, "UICheckButtonTemplate")
    chatCheck:SetSize(22, 22)
    chatCheck:SetPoint("BOTTOMLEFT", launcherDialog, "BOTTOMLEFT", 14, 40)
    local cl = chatCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cl:SetPoint("LEFT", chatCheck, "RIGHT", 2, 0)
    cl:SetText("Let everyone vote in chat")
    cl:SetTextColor(0.85, 0.85, 0.85)
    chatCheck:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Chat voting", 1, 0.82, 0.1)
        GameTooltip:AddLine(
            "Posts the question and numbered options to raid/party chat. "
            .. "People without RaidLead can vote by typing the number "
            .. "(or whispering you to vote silently).", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    chatCheck:HookScript("OnLeave", function() GameTooltip:Hide() end)
    chatCheck:SetScript("OnClick", function(self)
        if ns.db then ns.db.pollChatVoting = self:GetChecked() and true or false end
    end)
    launcherDialog.chatCheck = chatCheck

    -- "Auto-close after 30s" toggle. Off = poll stays open until the lead
    -- ends it manually (with a long safety timeout).
    local autoCheck = CreateFrame("CheckButton", nil, launcherDialog, "UICheckButtonTemplate")
    autoCheck:SetSize(22, 22)
    autoCheck:SetPoint("BOTTOMLEFT", launcherDialog, "BOTTOMLEFT", 14, 16)
    local al = autoCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    al:SetPoint("LEFT", autoCheck, "RIGHT", 2, 0)
    al:SetText("Auto-close after 30s")
    al:SetTextColor(0.85, 0.85, 0.85)
    autoCheck:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Auto-close after 30s", 1, 0.82, 0.1)
        GameTooltip:AddLine(
            "Ends the poll automatically 30 seconds after starting. "
            .. "Leave off to keep it open until you click End Poll.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    autoCheck:HookScript("OnLeave", function() GameTooltip:Hide() end)
    autoCheck:SetScript("OnClick", function(self)
        if ns.db then ns.db.pollAutoClose = self:GetChecked() and true or false end
    end)
    launcherDialog.autoCheck = autoCheck
end

-- (Re)build one row per available question. Rebuilt on every open so
-- edits to custom questions show up immediately.
local function RebuildLauncherRows()
    for _, row in ipairs(launcherRows) do row:Hide() end

    local choices = CollectPollChoices()
    local ROW_H   = 44
    local ROW_GAP = 8
    local rowY    = -64

    for i, choice in ipairs(choices) do
        local row = launcherRows[i]
        if not row then
            row = ns.MakeSmallButton(launcherDialog, "", 320, ROW_H)
            -- Stack: question on the upper half, options on the lower half.
            row.text:ClearAllPoints()
            row.text:SetPoint("TOP", row, "TOP", 0, -8)
            row.opts = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.opts:SetPoint("BOTTOM", row, "BOTTOM", 0, 8)
            launcherRows[i] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOP", launcherDialog, "TOP", 0, rowY)
        row.text:SetText(choice.question)

        local preview = "|cFF888888" .. table.concat(choice.options, " / ") .. "|r"
        if choice.multi then
            preview = preview .. " |cFF6699CC(pick several)|r"
        end
        row.opts:SetText(preview)

        row:SetScript("OnClick", function()
            if ns.Polls and ns.Polls.SendPoll then
                local chatVote = launcherDialog.chatCheck
                    and launcherDialog.chatCheck:GetChecked() and true or false
                local autoClose = (launcherDialog.autoCheck
                    and launcherDialog.autoCheck:GetChecked()) and 30 or nil
                ns.Polls.SendPoll(choice.question, choice.options, choice.multi,
                    chatVote, autoClose)
            end
            launcherDialog:Hide()
        end)
        row:Show()
        rowY = rowY - (ROW_H + ROW_GAP)
    end

    -- Size the dialog to fit title + subtitle + rows + the two checkboxes
    -- and the cancel button at the bottom.
    local contentBottom = -rowY + 6
    launcherDialog:SetHeight(math.max(190, contentBottom + 70))
end

function ns.ShowPollLauncher()
    BuildLauncher()
    if launcherDialog.chatCheck then
        local on = (not ns.db) or (ns.db.pollChatVoting ~= false)
        launcherDialog.chatCheck:SetChecked(on)
    end
    if launcherDialog.autoCheck then
        launcherDialog.autoCheck:SetChecked(ns.db and ns.db.pollAutoClose and true or false)
    end
    RebuildLauncherRows()
    launcherDialog:Show()
end

----------------------------------------------------------------------
-- 2) Vote dialog: recipient picks an option
----------------------------------------------------------------------
-- Submit a vote for the local player, recording locally too when we're
-- the initiator (the server echoes our own addon msg back, but that
-- self-echo is filtered in Comm).
local function CastAndRecord(pollId, choices)
    if not (ns.Polls and ns.Polls.CastVote) then return end
    ns.Polls.CastVote(pollId, choices)
    if ns.Polls.activePoll and ns.Polls.activePoll.id == pollId then
        ns.Polls.RecordVote(pollId, UnitName("player"), choices)
    end
end

local function BuildVoteDialog(pollId, question, options, senderName, multi)
    local d = CreateFrame("Frame", nil, UIParent)
    d:SetFrameStrata("DIALOG")
    d:SetFrameLevel(100)
    d:EnableMouse(true)
    d:SetMovable(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", function(s) s:StartMoving() end)
    d:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)

    ns.ApplyBackdrop(d, ns.DIALOG_BACKDROP)

    local BTN_W = 100
    local BTN_GAP = 8
    local nOpts = #options
    local rowW = nOpts * BTN_W + (nOpts - 1) * BTN_GAP
    local dialogW = math.max(380, rowW + 32)

    -- Multi-select needs an extra row for the Submit button.
    d:SetSize(dialogW, multi and 210 or 170)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 100)

    d.pollId = pollId

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -2, -2)

    local title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", d, "TOP", 0, -14)
    title:SetText("|cFFFFCC00Poll|r")

    local who = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    who:SetPoint("TOPLEFT",  d, "TOPLEFT",  16, -38)
    who:SetPoint("TOPRIGHT", d, "TOPRIGHT", -16, -38)
    who:SetJustifyH("CENTER")
    who:SetTextColor(0.75, 0.75, 0.75)
    who:SetText("from |cFFFFCC00" .. (senderName or "?") .. "|r")

    local q = d:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    q:SetPoint("TOPLEFT",  d, "TOPLEFT",  16, -58)
    q:SetPoint("TOPRIGHT", d, "TOPRIGHT", -16, -58)
    q:SetJustifyH("CENTER")
    q:SetTextColor(0.95, 0.95, 0.85)
    q:SetText(question)

    local startX = (dialogW - rowW) / 2

    if not multi then
        -- Single-select: one click votes and closes.
        for i, opt in ipairs(options) do
            local b = ns.MakeSmallButton(d, opt, BTN_W, 30)
            b:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT",
                startX + (i - 1) * (BTN_W + BTN_GAP), 16)
            local choiceIdx = i
            b:SetScript("OnClick", function()
                CastAndRecord(pollId, { choiceIdx })
                d:Hide()
            end)
        end
        return d
    end

    -- Multi-select: option buttons toggle on/off, a Submit button sends
    -- the whole selection at once.
    local hint = d:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", d, "BOTTOM", 0, 86)
    hint:SetTextColor(0.55, 0.7, 0.85)
    hint:SetText("Pick one or more, then Submit")

    local SEL_BG = { 0.62, 0.42, 0.10, 0.95 }
    local function ApplyToggleVisual(b)
        if b.selected then
            b:SetBackdropColor(unpack(SEL_BG))
            b.text:SetTextColor(1, 0.96, 0.85)
        else
            b:SetBackdropColor(0.15, 0.15, 0.18, 0.92)
            b.text:SetTextColor(0.92, 0.92, 0.88)
        end
    end

    local optButtons = {}
    for i, opt in ipairs(options) do
        local b = ns.MakeSmallButton(d, opt, BTN_W, 30)
        b:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT",
            startX + (i - 1) * (BTN_W + BTN_GAP), 52)
        b.selected = false
        b:SetScript("OnClick", function(self)
            self.selected = not self.selected
            ApplyToggleVisual(self)
        end)
        -- MakeSmallButton's hover handlers reset the color on leave; re-apply
        -- the selected tint afterwards so the toggle state stays visible.
        b:HookScript("OnLeave", function(self) ApplyToggleVisual(self) end)
        optButtons[i] = b
    end

    local submit = ns.MakeSmallButton(d, "Submit", 120, 26)
    submit:SetPoint("BOTTOM", d, "BOTTOM", 0, 14)
    submit:SetScript("OnClick", function()
        local chosen = {}
        for idx, b in ipairs(optButtons) do
            if b.selected then chosen[#chosen + 1] = idx end
        end
        if #chosen == 0 then
            ns.P("|cFFFF8800Pick at least one option before submitting.|r")
            return
        end
        CastAndRecord(pollId, chosen)
        d:Hide()
    end)

    return d
end

function ns.ShowPollVoteDialog(pollId, question, options, senderName, multi)
    -- Replace any older vote dialog with the new one
    if activeVoteDialog then activeVoteDialog:Hide() end
    activeVoteDialog = BuildVoteDialog(pollId, question, options, senderName, multi)
    activeVoteDialog:Show()
    if PlaySound then pcall(PlaySound, 880) end
end

function ns.HidePollVoteDialog(pollId)
    if activeVoteDialog and activeVoteDialog.pollId == pollId then
        activeVoteDialog:Hide()
        activeVoteDialog = nil
    end
end

----------------------------------------------------------------------
-- 3) Results window: live tally for the initiator
----------------------------------------------------------------------
local resultRows = {}
local RenderResults  -- forward decl (referenced by buttons in BuildResults)

local function BuildResults()
    if resultsWindow then return end

    resultsWindow = CreateFrame("Frame", "RaidLeadPollResults", UIParent)
    resultsWindow:SetSize(340, 220)
    resultsWindow:SetPoint("CENTER", UIParent, "CENTER", 0, -80)
    resultsWindow:SetFrameStrata("DIALOG")
    resultsWindow:SetFrameLevel(100)
    resultsWindow:EnableMouse(true)
    resultsWindow:SetMovable(true)
    resultsWindow:RegisterForDrag("LeftButton")
    resultsWindow:SetScript("OnDragStart", function(s) s:StartMoving() end)
    resultsWindow:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    resultsWindow:Hide()

    ns.ApplyBackdrop(resultsWindow, ns.DIALOG_BACKDROP)

    local closeBtn = CreateFrame("Button", nil, resultsWindow, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", resultsWindow, "TOPRIGHT", -2, -2)

    local title = resultsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", resultsWindow, "TOP", 0, -14)
    title:SetText("|cFFFFCC00Poll Results|r")

    resultsWindow.question = resultsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultsWindow.question:SetPoint("TOPLEFT",  resultsWindow, "TOPLEFT",  16, -38)
    resultsWindow.question:SetPoint("TOPRIGHT", resultsWindow, "TOPRIGHT", -16, -38)
    resultsWindow.question:SetJustifyH("CENTER")
    resultsWindow.question:SetTextColor(0.9, 0.9, 0.78)

    -- Announce the tally to raid/party chat (initiator-only window).
    local announceBtn = ns.MakeSmallButton(resultsWindow, "Announce", 100, 24)
    announceBtn:SetPoint("BOTTOMLEFT", resultsWindow, "BOTTOMLEFT", 16, 12)
    announceBtn:SetScript("OnClick", function()
        if ns.Polls and ns.Polls.AnnounceResults then ns.Polls.AnnounceResults() end
    end)
    announceBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Announce results", 1, 0.82, 0.1)
        GameTooltip:AddLine("Post the current tally to raid/party chat.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    announceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    -- End / Restart. While the poll is open this ends it (stops collecting
    -- votes); once closed it restarts the same poll with a fresh tally.
    local endBtn = ns.MakeSmallButton(resultsWindow, "End Poll", 90, 24)
    endBtn:SetPoint("LEFT", announceBtn, "RIGHT", 8, 0)
    endBtn:SetScript("OnClick", function()
        local poll = ns.Polls and ns.Polls.activePoll
        if not poll then return end
        if poll.endedAt then
            if ns.Polls.RestartPoll then ns.Polls.RestartPoll() end
        elseif ns.Polls.EndPoll then
            ns.Polls.EndPoll(poll.id, "manual")
        end
    end)
    endBtn:HookScript("OnEnter", function(self)
        local poll = ns.Polls and ns.Polls.activePoll
        local closed = poll and poll.endedAt
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if closed then
            GameTooltip:AddLine("Restart poll", 1, 0.82, 0.1)
            GameTooltip:AddLine("Re-run this question with a fresh tally.",
                0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine("End poll", 1, 0.82, 0.1)
            GameTooltip:AddLine("Stop collecting votes and close the poll. "
                .. "Results stay here and in History.", 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    endBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    resultsWindow.endBtn = endBtn

    -- Toggle the per-voter breakdown (who voted for what).
    local votersBtn = ns.MakeSmallButton(resultsWindow, "Hide Votes", 90, 24)
    votersBtn:SetPoint("BOTTOMRIGHT", resultsWindow, "BOTTOMRIGHT", -16, 12)
    votersBtn:SetScript("OnClick", function()
        resultsWindow.showVoters = not resultsWindow.showVoters
        if ns.Polls and ns.Polls.activePoll then RenderResults(ns.Polls.activePoll) end
    end)
    resultsWindow.votersBtn = votersBtn
    resultsWindow.showVoters = true   -- lead sees the vote list by default

    -- Per-voter list (one line per player + their pick).
    resultsWindow.voterList = resultsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultsWindow.voterList:SetJustifyH("LEFT")
    resultsWindow.voterList:SetJustifyV("TOP")
    resultsWindow.voterList:SetTextColor(0.85, 0.85, 0.85)

    -- Status sits above the button row so it never overlaps the buttons.
    resultsWindow.status = resultsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultsWindow.status:SetPoint("BOTTOMRIGHT", resultsWindow, "BOTTOMRIGHT", -16, 44)
    resultsWindow.status:SetJustifyH("RIGHT")
    resultsWindow.status:SetTextColor(0.6, 0.6, 0.6)
end

RenderResults = function(poll)
    if not resultsWindow then return end

    resultsWindow.question:SetText(poll.question or "")

    -- Count votes per option (handles both single index and multi-select
    -- index tables stored in poll.votes).
    local counts, voterTotal = ns.Polls.TallyVotes(poll)

    local ROW_H = 26
    local barsBottom = 58 + #poll.options * (ROW_H + 4)
    local rowW = (resultsWindow:GetWidth() or 340) - 32   -- stretch to window edges
    ns.RenderPollBars(resultsWindow, resultRows, poll.options, counts, voterTotal, -58, rowW)

    -- How many of those came from chat/whisper (non-addon) voters?
    local chatN = 0
    if poll.voteSource then
        for _, src in pairs(poll.voteSource) do
            if src ~= "addon" then chatN = chatN + 1 end
        end
    end
    local viaChat = (chatN > 0) and ("  |cFF6699CC(" .. chatN .. " via chat)|r") or ""

    -- End/Restart label follows the poll state.
    if resultsWindow.endBtn then
        resultsWindow.endBtn:SetText(poll.endedAt and "Restart" or "End Poll")
    end

    -- Per-voter breakdown: one line per player with their pick(s) and a
    -- tag for chat/whisper votes. Sorted by name.
    local SRC_TAG = { chat = "  |cFF6699CC(chat)|r", whisper = "  |cFF9988CC(whisper)|r" }
    local names = {}
    for name in pairs(poll.votes or {}) do names[#names + 1] = name end
    table.sort(names)

    local MAX_SHOWN = 40
    local lines, shown = {}, 0
    for _, name in ipairs(names) do
        shown = shown + 1
        if shown > MAX_SHOWN then
            lines[#lines + 1] = "|cFF888888...and " .. (#names - MAX_SHOWN) .. " more|r"
            break
        end
        local choice = poll.votes[name]
        local picks = {}
        if type(choice) == "table" then
            for _, idx in ipairs(choice) do picks[#picks + 1] = poll.options[idx] or "?" end
        else
            picks[1] = poll.options[choice] or "?"
        end
        local cc  = ns.ClassColor and ns.ClassColor(ns.ClassOf and ns.ClassOf(name) or "UNKNOWN")
            or "|cFFFFFFFF"
        local tag = SRC_TAG[(poll.voteSource or {})[name]] or ""
        lines[#lines + 1] = cc .. name .. "|r  |cFFCCCCCC" .. table.concat(picks, ", ") .. "|r" .. tag
    end

    local hasVoters = (#names > 0)
    local showList  = resultsWindow.showVoters and hasVoters
    local vl = resultsWindow.voterList
    vl:ClearAllPoints()
    vl:SetPoint("TOPLEFT",  resultsWindow, "TOPLEFT",  16, -(barsBottom + 4))
    vl:SetPoint("RIGHT",    resultsWindow, "RIGHT",   -16, 0)
    vl:SetText(table.concat(lines, "\n"))
    vl:SetShown(showList)

    if resultsWindow.votersBtn then
        resultsWindow.votersBtn:SetText(resultsWindow.showVoters and "Hide Votes" or "Show Votes")
        resultsWindow.votersBtn:SetShown(hasVoters)
    end

    -- Grow the window to fit options + (optional) voter list + bottom bar.
    local LINE_H   = 13
    local listH    = showList and (math.min(shown, MAX_SHOWN + 1) * LINE_H + 8) or 0
    resultsWindow:SetHeight(math.max(180, barsBottom + listH + 68))

    local noun = (voterTotal == 1) and "voter" or "voters"
    if poll.endedAt then
        resultsWindow.status:SetText("Poll closed - " .. voterTotal .. " " .. noun .. viaChat)
    else
        resultsWindow.status:SetText("|cFF66CC66Open|r - " .. voterTotal .. " " .. noun .. viaChat)
    end
end

function ns.ShowPollResultsWindow(poll)
    BuildResults()
    RenderResults(poll)
    resultsWindow:Show()
end

function ns.RefreshPollResultsWindow(poll)
    if not resultsWindow or not resultsWindow:IsShown() then return end
    RenderResults(poll)
end

function ns.MarkPollEnded(poll, reason)
    if not resultsWindow then return end
    RenderResults(poll)
end
