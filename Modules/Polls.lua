----------------------------------------------------------------------
-- RaidLead - Modules/Polls.lua
-- Quick raid polls: lead initiates a question ("Continue or wipe?"),
-- all RaidLead users see a popup with vote buttons, results tally
-- live for the initiator.
--
-- Comm protocol (3 message types):
--   POLL_START <pollId> <mode> <question> <opt1>|<opt2>|...  from initiator
--   POLL_VOTE  <pollId> <idx[,idx,...]>                      from voter
--   POLL_END   <pollId>                                      from initiator
--
-- <mode> is "single" (pick one) or "multi" (pick several).
-- Choice indices are 1-based; multi votes are comma-separated. Option
-- labels arrive separated by "|" because the Comm SEP (tab) is already
-- used as the field separator.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Polls = {}
ns.Polls = Polls

----------------------------------------------------------------------
-- Preset poll templates the launcher offers
----------------------------------------------------------------------
Polls.PRESETS = {
    { key = "yesno",    question = "Yes or No?",            options = { "Yes", "No" } },
    { key = "cwb",      question = "Continue, Wipe, or Break?", options = { "Continue", "Wipe", "Break" } },
    { key = "pull",     question = "Ready to pull?",        options = { "Ready", "Need a minute" } },
    { key = "alts",     question = "Alts or mains tonight?", options = { "Alts", "Mains", "Mixed" } },
}

----------------------------------------------------------------------
-- Throttle: prevent poll spam
----------------------------------------------------------------------
local lastPollSent = 0
local POLL_THROTTLE = 20   -- seconds between sends
local POLL_DURATION = 30   -- seconds before auto-end

-- Initiator's active poll state. Only set while WE'RE running a poll.
Polls.activePoll = nil

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function NewPollId()
    -- Random-ish but unique-enough id (sender name + timestamp)
    return (UnitName("player") or "X") .. ":" .. tostring(math.floor(GetTime() * 1000))
end

local function PackOptions(opts)
    return table.concat(opts, "|")
end

local function UnpackOptions(str)
    local out = {}
    for opt in (str or ""):gmatch("([^|]+)") do
        out[#out + 1] = opt
    end
    return out
end

-- Tally votes for a poll. votes[name] may be a single index (legacy /
-- single-mode) or a table of indices (multi-mode); handle both.
-- Returns counts[optIdx] -> n, and voterTotal (distinct voters).
local function TallyVotes(poll)
    local counts = {}
    for i = 1, #poll.options do counts[i] = 0 end
    local voterTotal = 0
    for _, choice in pairs(poll.votes) do
        voterTotal = voterTotal + 1
        if type(choice) == "table" then
            for _, idx in ipairs(choice) do
                if counts[idx] then counts[idx] = counts[idx] + 1 end
            end
        elseif counts[choice] then
            counts[choice] = counts[choice] + 1
        end
    end
    return counts, voterTotal
end
Polls.TallyVotes = TallyVotes

----------------------------------------------------------------------
-- Sender side: initiate a poll
----------------------------------------------------------------------
function Polls.SendPoll(question, options, multi)
    if not ns.Comm then return end
    if not question or question == "" or not options or #options < 2 then
        ns.P("|cFFFF8800Poll needs a question and at least 2 options.|r")
        return
    end
    multi = multi and true or false

    -- Permission: leader/assist only (same gate as broadcast permissions)
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can start a poll.|r")
        return
    end

    -- Throttle
    local now = GetTime()
    if now - lastPollSent < POLL_THROTTLE then
        local left = math.ceil(POLL_THROTTLE - (now - lastPollSent))
        ns.P("|cFFFFAA00Poll throttled.|r Try again in " .. left .. "s.")
        return
    end
    lastPollSent = now

    local pollId = NewPollId()
    Polls.activePoll = {
        id        = pollId,
        question  = question,
        options   = options,
        multi     = multi,
        votes     = {},  -- voterName -> choiceIdx | { idx, ... }
        startedAt = now,
    }

    -- Broadcast to peers (no-op when solo)
    ns.Comm.Send("POLL_START", pollId, multi and "multi" or "single",
        question, PackOptions(options))

    -- Initiator also opens their results window AND a local vote popup
    -- so they can vote too (mirrors role-check behavior).
    if ns.ShowPollResultsWindow then
        ns.ShowPollResultsWindow(Polls.activePoll)
    end
    if ns.ShowPollVoteDialog then
        ns.ShowPollVoteDialog(pollId, question, options, UnitName("player"), multi)
    end

    local gt = ns.GetGroupType and ns.GetGroupType() or "solo"
    if gt == "solo" then
        ns.P("|cFF88CCFF[poll]|r solo - opening dialog locally.")
    else
        ns.P("|cFF88CCFF[poll]|r \"" .. question .. "\" sent to RaidLead users.")
    end

    -- Auto-end after POLL_DURATION
    C_Timer.After(POLL_DURATION, function()
        if Polls.activePoll and Polls.activePoll.id == pollId then
            Polls.EndPoll(pollId, "timeout")
        end
    end)
end

-- choices: a single 1-based index, or a table of them (multi-select).
function Polls.RecordVote(pollId, voterName, choices)
    if not Polls.activePoll or Polls.activePoll.id ~= pollId then return end
    if not voterName or voterName == "" then return end

    local nOpts = #Polls.activePoll.options
    if type(choices) ~= "table" then choices = { choices } end

    -- Keep only valid, de-duplicated indices.
    local seen, clean = {}, {}
    for _, idx in ipairs(choices) do
        idx = tonumber(idx)
        if idx and idx >= 1 and idx <= nOpts and not seen[idx] then
            seen[idx] = true
            clean[#clean + 1] = idx
        end
    end
    if #clean == 0 then return end

    Polls.activePoll.votes[voterName] = clean

    if ns.RefreshPollResultsWindow then
        ns.RefreshPollResultsWindow(Polls.activePoll)
    end
end

local POLL_HISTORY_MAX = 25

-- Snapshot a finished poll's final tally into local history (newest first).
-- Stored as plain counts so it can be re-announced without live vote state.
local function SaveToHistory(poll)
    if not (ns.db and poll) then return end
    ns.db.pollHistory = ns.db.pollHistory or {}

    local counts, voterTotal = TallyVotes(poll)
    local opts = {}
    for i, o in ipairs(poll.options or {}) do opts[i] = o end
    local savedCounts = {}
    for i = 1, #opts do savedCounts[i] = counts[i] or 0 end

    table.insert(ns.db.pollHistory, 1, {
        question   = poll.question,
        options    = opts,
        multi      = poll.multi and true or false,
        counts     = savedCounts,
        voterTotal = voterTotal,
        endedAt    = time(),
    })
    while #ns.db.pollHistory > POLL_HISTORY_MAX do
        table.remove(ns.db.pollHistory)
    end
end

function Polls.EndPoll(pollId, reason)
    if not Polls.activePoll or Polls.activePoll.id ~= pollId then return end

    if ns.Comm then
        ns.Comm.Send("POLL_END", pollId)
    end
    if ns.MarkPollEnded then ns.MarkPollEnded(Polls.activePoll, reason) end

    Polls.activePoll.endedAt = GetTime()
    SaveToHistory(Polls.activePoll)
    if ns.RefreshPollManager then ns.RefreshPollManager() end
end

----------------------------------------------------------------------
-- Vote side: respond to a poll
----------------------------------------------------------------------
-- choices: a single 1-based index, or a table of them (multi-select).
function Polls.CastVote(pollId, choices)
    if not ns.Comm then return end
    if not pollId or not choices then return end
    if type(choices) ~= "table" then choices = { choices } end
    if #choices == 0 then return end
    ns.Comm.Send("POLL_VOTE", pollId, table.concat(choices, ","))
end

----------------------------------------------------------------------
-- Announce the current tally to raid/party chat (initiator only)
----------------------------------------------------------------------
function Polls.AnnounceResults()
    local poll = Polls.activePoll
    if not poll then
        ns.P("|cFFFF8800No active poll to announce.|r")
        return
    end

    local channel = ns.BuffScan and ns.BuffScan.GetAnnounceChannel
        and ns.BuffScan.GetAnnounceChannel()
    if not channel then
        ns.P("You are not in a group or raid.")
        return
    end

    -- SendChatMessage rejects the '|' escape char; strip it from labels.
    local function clean(s) return (tostring(s or ""):gsub("|", "")) end

    local counts, voterTotal = TallyVotes(poll)

    SendChatMessage("[Poll] " .. clean(poll.question), channel)
    for i, opt in ipairs(poll.options) do
        local pct = (voterTotal > 0)
            and math.floor(counts[i] / voterTotal * 100 + 0.5) or 0
        SendChatMessage(
            string.format("  %s: %d (%d%%)", clean(opt), counts[i], pct),
            channel)
    end
    SendChatMessage(
        string.format("  (%d voter%s)", voterTotal, voterTotal == 1 and "" or "s"),
        channel)
end

----------------------------------------------------------------------
-- Re-announce a stored (past) poll result to raid/party chat.
-- entry: { question, options = {...}, counts = {...}, voterTotal }
----------------------------------------------------------------------
function Polls.AnnounceStored(entry)
    if not entry then return end

    -- Re-announcing is a broadcast; gate to leader / assistant.
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can announce poll results.|r")
        return
    end

    local channel = ns.BuffScan and ns.BuffScan.GetAnnounceChannel
        and ns.BuffScan.GetAnnounceChannel()
    if not channel then
        ns.P("You are not in a group or raid.")
        return
    end

    local function clean(s) return (tostring(s or ""):gsub("|", "")) end
    local voterTotal = entry.voterTotal or 0

    SendChatMessage("[Poll] " .. clean(entry.question), channel)
    for i, opt in ipairs(entry.options or {}) do
        local c = (entry.counts and entry.counts[i]) or 0
        local pct = (voterTotal > 0) and math.floor(c / voterTotal * 100 + 0.5) or 0
        SendChatMessage(string.format("  %s: %d (%d%%)", clean(opt), c, pct), channel)
    end
    SendChatMessage(
        string.format("  (%d voter%s)", voterTotal, voterTotal == 1 and "" or "s"),
        channel)
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("POLL_START", function(parts, sender, channel)
        local pollId   = parts[2]
        local mode     = parts[3]
        local question = parts[4]
        local optsStr  = parts[5]
        if not (pollId and question and optsStr) then return end

        local options = UnpackOptions(optsStr)
        if #options < 2 then return end

        if ns.ShowPollVoteDialog then
            ns.ShowPollVoteDialog(pollId, question, options, sender, mode == "multi")
        end
    end)

    ns.Comm.RegisterHandler("POLL_VOTE", function(parts, sender, channel)
        local pollId  = parts[2]
        if not pollId then return end
        local choices = {}
        for n in (parts[3] or ""):gmatch("%d+") do
            choices[#choices + 1] = tonumber(n)
        end
        if #choices == 0 then return end
        Polls.RecordVote(pollId, sender, choices)
    end)

    ns.Comm.RegisterHandler("POLL_END", function(parts, sender, channel)
        local pollId = parts[2]
        if not pollId then return end
        if ns.HidePollVoteDialog then
            ns.HidePollVoteDialog(pollId)
        end
    end)
end
