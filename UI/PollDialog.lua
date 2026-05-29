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
    subtitle:SetText("Pick a question - all RaidLead users will see a vote popup.")

    local cancelBtn = ns.MakeSmallButton(launcherDialog, "Cancel", 90, 24)
    cancelBtn:SetPoint("BOTTOM", launcherDialog, "BOTTOM", 0, 14)
    cancelBtn:SetScript("OnClick", function() launcherDialog:Hide() end)
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
                ns.Polls.SendPoll(choice.question, choice.options, choice.multi)
            end
            launcherDialog:Hide()
        end)
        row:Show()
        rowY = rowY - (ROW_H + ROW_GAP)
    end

    -- Size the dialog to fit title + subtitle + rows + cancel button.
    local contentBottom = -rowY + 6
    launcherDialog:SetHeight(math.max(180, contentBottom + 44))
end

function ns.ShowPollLauncher()
    BuildLauncher()
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

local function BuildResults()
    if resultsWindow then return end

    resultsWindow = CreateFrame("Frame", "RaidLeadPollResults", UIParent)
    resultsWindow:SetSize(320, 220)
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

    resultsWindow.status = resultsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultsWindow.status:SetPoint("BOTTOMRIGHT", resultsWindow, "BOTTOMRIGHT", -16, 18)
    resultsWindow.status:SetJustifyH("RIGHT")
    resultsWindow.status:SetTextColor(0.6, 0.6, 0.6)
end

local function RenderResults(poll)
    if not resultsWindow then return end

    resultsWindow.question:SetText(poll.question or "")

    -- Reset old rows
    for _, r in ipairs(resultRows) do r:Hide() end

    -- Count votes per option (handles both single index and multi-select
    -- index tables stored in poll.votes).
    local counts, voterTotal = ns.Polls.TallyVotes(poll)

    local maxN = 0
    for _, n in ipairs(counts) do if n > maxN then maxN = n end end

    local ROW_H = 26
    -- Grow the window to fit however many options this poll has.
    resultsWindow:SetHeight(math.max(180, 58 + #poll.options * (ROW_H + 4) + 52))

    for i, opt in ipairs(poll.options) do
        local row = resultRows[i]
        if not row then
            row = CreateFrame("Frame", nil, resultsWindow)
            row:SetSize(280, ROW_H)
            row:SetPoint("TOPLEFT", resultsWindow, "TOPLEFT", 16, -58 - (i - 1) * (ROW_H + 4))
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.10, 0.10, 0.13, 0.85)
            row.fill = row:CreateTexture(nil, "BORDER")
            row.fill:SetPoint("TOPLEFT",     row, "TOPLEFT",     0, 0)
            row.fill:SetPoint("BOTTOMLEFT",  row, "BOTTOMLEFT",  0, 0)
            row.fill:SetColorTexture(0.62, 0.42, 0.10, 0.85)
            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT",  row, "LEFT",   8, 0)
            row.label:SetWidth(180)
            row.label:SetJustifyH("LEFT")
            row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.count:SetJustifyH("RIGHT")
            resultRows[i] = row
        end
        row.label:SetText(opt)
        local pct = (voterTotal > 0)
            and math.floor(counts[i] / voterTotal * 100 + 0.5) or 0
        row.count:SetText(string.format("%d  |cFF888888%d%%|r", counts[i], pct))

        local frac = (maxN > 0) and (counts[i] / maxN) or 0
        row.fill:SetWidth(math.max(2, frac * 280))
        row:Show()
    end

    local noun = (voterTotal == 1) and "voter" or "voters"
    if poll.endedAt then
        resultsWindow.status:SetText("Poll closed - " .. voterTotal .. " " .. noun)
    else
        resultsWindow.status:SetText(voterTotal .. " " .. noun .. " so far")
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
