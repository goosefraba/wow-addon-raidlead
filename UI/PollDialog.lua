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

    -- One row per preset
    local PRESETS = (ns.Polls and ns.Polls.PRESETS) or {}
    local rowY = -68
    for _, preset in ipairs(PRESETS) do
        local row = ns.MakeSmallButton(launcherDialog, preset.question, 320, 30)
        row:SetPoint("TOP", launcherDialog, "TOP", 0, rowY)
        local p = preset
        row:SetScript("OnClick", function()
            if ns.Polls and ns.Polls.SendPoll then
                ns.Polls.SendPoll(p.question, p.options)
            end
            launcherDialog:Hide()
        end)

        local optsLine = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        optsLine:SetPoint("CENTER", row, "CENTER", 0, -10)
        optsLine:SetText("|cFF888888" .. table.concat(preset.options, " / ") .. "|r")
        rowY = rowY - 38
    end

    local cancelBtn = ns.MakeSmallButton(launcherDialog, "Cancel", 90, 24)
    cancelBtn:SetPoint("BOTTOM", launcherDialog, "BOTTOM", 0, 14)
    cancelBtn:SetScript("OnClick", function() launcherDialog:Hide() end)
end

function ns.ShowPollLauncher()
    BuildLauncher()
    launcherDialog:Show()
end

----------------------------------------------------------------------
-- 2) Vote dialog: recipient picks an option
----------------------------------------------------------------------
local function BuildVoteDialog(pollId, question, options, senderName)
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

    d:SetSize(dialogW, 170)
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
    for i, opt in ipairs(options) do
        local b = ns.MakeSmallButton(d, opt, BTN_W, 30)
        b:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", startX + (i - 1) * (BTN_W + BTN_GAP), 16)
        local choiceIdx = i
        b:SetScript("OnClick", function()
            if ns.Polls and ns.Polls.CastVote then
                ns.Polls.CastVote(pollId, choiceIdx)
                -- If WE'RE the initiator, record locally too (self-echo is filtered)
                if ns.Polls.activePoll and ns.Polls.activePoll.id == pollId then
                    ns.Polls.RecordVote(pollId, UnitName("player"), choiceIdx)
                end
            end
            d:Hide()
        end)
    end

    return d
end

function ns.ShowPollVoteDialog(pollId, question, options, senderName)
    -- Replace any older vote dialog with the new one
    if activeVoteDialog then activeVoteDialog:Hide() end
    activeVoteDialog = BuildVoteDialog(pollId, question, options, senderName)
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

    resultsWindow.status = resultsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resultsWindow.status:SetPoint("BOTTOM", resultsWindow, "BOTTOM", 0, 14)
    resultsWindow.status:SetTextColor(0.6, 0.6, 0.6)
end

local function RenderResults(poll)
    if not resultsWindow then return end

    resultsWindow.question:SetText(poll.question or "")

    -- Reset old rows
    for _, r in ipairs(resultRows) do r:Hide() end

    -- Count votes per option
    local counts = {}
    local voterTotal = 0
    for i = 1, #poll.options do counts[i] = 0 end
    for _, idx in pairs(poll.votes) do
        counts[idx] = (counts[idx] or 0) + 1
        voterTotal = voterTotal + 1
    end

    local maxN = 0
    for _, n in ipairs(counts) do if n > maxN then maxN = n end end

    local ROW_H = 26
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
        row.count:SetText(tostring(counts[i]))

        local frac = (maxN > 0) and (counts[i] / maxN) or 0
        row.fill:SetWidth(math.max(2, frac * 280))
        row:Show()
    end

    if poll.endedAt then
        resultsWindow.status:SetText("Poll closed - " .. voterTotal .. " vote"
            .. (voterTotal == 1 and "" or "s") .. " counted")
    else
        resultsWindow.status:SetText(voterTotal .. " vote"
            .. (voterTotal == 1 and "" or "s") .. " so far")
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
