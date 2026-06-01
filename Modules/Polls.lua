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
local POLL_THROTTLE = 20    -- seconds between sends
-- Safety auto-close only. The lead normally ends the poll manually with
-- the "End Poll" button; this just stops a forgotten poll from scanning
-- chat forever. People need time to read and type, so keep it generous.
local POLL_DURATION = 300   -- seconds before auto-end (5 min)

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
-- Chat-vote scanning (lets people WITHOUT the addon vote by typing).
-- Only the initiator runs this — they hold activePoll, so there's no
-- double-counting across the raid. Matching is deliberately strict so
-- normal chatter is never mistaken for a vote.
----------------------------------------------------------------------

-- Precompute a lowercased label -> option index map for keyword votes.
local function BuildMatcher(poll)
    local map = {}
    for i, o in ipairs(poll.options or {}) do
        local key = tostring(o):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if key ~= "" and not map[key] then map[key] = i end
    end
    poll._labelMap = map
end

-- Parse one chat line into a list of option indices, or nil if it isn't
-- clearly a vote. Accepts: a bare number ("2"), several numbers for
-- multi-select ("1,3" / "1 3"), an exact option label ("wipe"), or
-- yes/no shorthand on a 2-option Yes/No poll (y/n/+/-).
local function ParseChatVote(poll, text)
    if not text then return nil end
    local msg = tostring(text):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "" then return nil end
    local nOpts = #poll.options

    -- Pure numeric (digits, spaces, commas only) -> index list.
    if msg:match("^[%d%s,]+$") then
        local picks, seen = {}, {}
        for n in msg:gmatch("%d+") do
            local idx = tonumber(n)
            if idx and idx >= 1 and idx <= nOpts and not seen[idx] then
                seen[idx] = true
                picks[#picks + 1] = idx
                if not poll.multi then break end  -- single-mode: first only
            end
        end
        if #picks > 0 then return picks end
        return nil
    end

    -- Exact option label.
    local idx = poll._labelMap and poll._labelMap[msg]
    if idx then return { idx } end

    -- Yes/No shorthand, only when the poll actually has Yes/No options.
    if nOpts == 2 and poll._labelMap then
        local yes, no = poll._labelMap["yes"], poll._labelMap["no"]
        if yes and (msg == "y" or msg == "yes" or msg == "+") then return { yes } end
        if no  and (msg == "n" or msg == "no"  or msg == "-") then return { no  } end
    end
    return nil
end

local chatFrame = CreateFrame("Frame")
local CHAT_EVENTS = {
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
}
chatFrame:SetScript("OnEvent", function(_, event, text, sender)
    local poll = Polls.activePoll
    if not poll or poll.endedAt or not poll.chatVote then return end
    local name = sender and sender:match("^[^-]+") or sender   -- strip realm
    if not name or name == "" then return end
    local picks = ParseChatVote(poll, text)
    if not picks then return end
    local src = (event == "CHAT_MSG_WHISPER") and "whisper" or "chat"
    Polls.RecordVote(poll.id, name, picks, src)
end)

local function StartChatScan(poll)
    BuildMatcher(poll)
    for _, e in ipairs(CHAT_EVENTS) do chatFrame:RegisterEvent(e) end
    if poll.scanWhispers then chatFrame:RegisterEvent("CHAT_MSG_WHISPER") end
end

local function StopChatScan()
    chatFrame:UnregisterAllEvents()
end

-- Post human-readable voting instructions to raid/party chat so people
-- without the addon know how to vote — including a silent whisper option.
local function PostChatInstructions(poll)
    local channel = ns.BuffScan and ns.BuffScan.GetAnnounceChannel
        and ns.BuffScan.GetAnnounceChannel()
    if not channel then return end
    local function clean(s) return (tostring(s or ""):gsub("|", "")) end

    SendChatMessage("[Poll] " .. clean(poll.question), channel)

    local parts = {}
    for i, o in ipairs(poll.options) do parts[#parts + 1] = i .. "=" .. clean(o) end
    local verb = poll.multi and "reply with the number(s)" or "reply with a number"
    SendChatMessage("Vote: " .. verb .. " in chat -  " .. table.concat(parts, "   "), channel)

    local me = UnitName("player") or "me"
    SendChatMessage("Prefer to vote silently? Whisper your choice to " .. me .. ".", channel)
end

----------------------------------------------------------------------
-- Sender side: initiate a poll
----------------------------------------------------------------------
function Polls.SendPoll(question, options, multi, chatVote, autoCloseSecs)
    if not ns.Comm then return end
    if not question or question == "" or not options or #options < 2 then
        ns.P("|cFFFF8800Poll needs a question and at least 2 options.|r")
        return
    end
    multi    = multi and true or false
    chatVote = chatVote and true or false
    -- autoCloseSecs: a positive number auto-ends the poll after that many
    -- seconds; anything else means "stay open until ended manually" (a long
    -- safety timeout still applies so a forgotten poll can't run forever).
    autoCloseSecs = (type(autoCloseSecs) == "number" and autoCloseSecs > 0)
        and autoCloseSecs or nil

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
        id           = pollId,
        question     = question,
        options      = options,
        multi        = multi,
        chatVote     = chatVote,        -- accept typed votes from non-addon users
        scanWhispers = chatVote,        -- and silent whispers to us
        autoClose    = autoCloseSecs,   -- remembered for Restart
        votes        = {},  -- voterName -> choiceIdx | { idx, ... }
        voteSource   = {},  -- voterName -> "addon" | "chat" | "whisper"
        startedAt    = now,
    }

    -- Broadcast to peers (no-op when solo)
    ns.Comm.Send("POLL_START", pollId, multi and "multi" or "single",
        question, PackOptions(options))

    -- Chat-vote layer: post instructions and start scanning chat. When
    -- off, make sure any prior scan from an earlier poll is torn down.
    if chatVote then
        PostChatInstructions(Polls.activePoll)
        StartChatScan(Polls.activePoll)
    else
        StopChatScan()
    end

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

    -- Auto-end: use the chosen short duration if set, otherwise the long
    -- safety timeout. Either way it only fires if THIS poll is still active.
    local dur = autoCloseSecs or POLL_DURATION
    C_Timer.After(dur, function()
        if Polls.activePoll and Polls.activePoll.id == pollId
            and not Polls.activePoll.endedAt then
            Polls.EndPoll(pollId, "timeout")
        end
    end)
end

----------------------------------------------------------------------
-- Restart: re-run the current poll with the same question/options/mode,
-- resetting votes. Used by the results window after a poll has ended.
----------------------------------------------------------------------
function Polls.RestartPoll()
    local p = Polls.activePoll
    if not p then return end
    local q, o, m, cv, ac = p.question, p.options, p.multi, p.chatVote, p.autoClose
    lastPollSent = 0   -- explicit user action: bypass the spam throttle
    Polls.SendPoll(q, o, m, cv, ac)
end

-- choices: a single 1-based index, or a table of them (multi-select).
-- source: "addon" (default), "chat", or "whisper". An explicit addon vote
-- is authoritative — a later chat/whisper line from the SAME player is
-- ignored, so someone who clicks the popup AND types is never counted or
-- replaced twice. (Votes are name-keyed, so they're one entry regardless.)
function Polls.RecordVote(pollId, voterName, choices, source)
    if not Polls.activePoll or Polls.activePoll.id ~= pollId then return end
    if not voterName or voterName == "" then return end
    source = source or "addon"

    Polls.activePoll.voteSource = Polls.activePoll.voteSource or {}
    if Polls.activePoll.voteSource[voterName] == "addon" and source ~= "addon" then
        return
    end

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
    Polls.activePoll.voteSource[voterName] = source

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

    -- Snapshot who voted for what so the History view can show a per-voter
    -- breakdown later. votes[name] = { optIdx, ... }; source[name] = tag.
    local votes, source = {}, {}
    for name, choice in pairs(poll.votes or {}) do
        local picks = {}
        if type(choice) == "table" then
            for _, idx in ipairs(choice) do picks[#picks + 1] = idx end
        else
            picks[1] = choice
        end
        votes[name]  = picks
        source[name] = (poll.voteSource or {})[name] or "addon"
    end

    table.insert(ns.db.pollHistory, 1, {
        question   = poll.question,
        options    = opts,
        multi      = poll.multi and true or false,
        counts     = savedCounts,
        voterTotal = voterTotal,
        votes      = votes,
        voteSource = source,
        endedAt    = time(),
    })
    while #ns.db.pollHistory > POLL_HISTORY_MAX do
        table.remove(ns.db.pollHistory)
    end
end

function Polls.EndPoll(pollId, reason)
    if not Polls.activePoll or Polls.activePoll.id ~= pollId then return end
    if Polls.activePoll.endedAt then return end   -- already closed

    -- Mark closed FIRST so every render below shows the closed state and
    -- the End Poll button flips to Restart. (Previously endedAt was set
    -- after MarkPollEnded, so the window kept rendering as "Open".)
    Polls.activePoll.endedAt = GetTime()
    StopChatScan()

    if ns.Comm then
        ns.Comm.Send("POLL_END", pollId)
    end

    SaveToHistory(Polls.activePoll)
    if ns.MarkPollEnded then ns.MarkPollEnded(Polls.activePoll, reason) end
    if ns.RefreshPollManager then ns.RefreshPollManager() end

    ns.P("|cFF88CCFF[poll]|r closed (" .. (reason or "manual") .. ").")
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
-- Post a question + per-option counts/percentages + voter total to chat.
-- SendChatMessage rejects '|', so strip it from labels.
----------------------------------------------------------------------
local function PostTally(channel, question, options, counts, voterTotal)
    local function clean(s) return (tostring(s or ""):gsub("|", "")) end
    SendChatMessage("[Poll] " .. clean(question), channel)
    for i, opt in ipairs(options or {}) do
        local c = counts[i] or 0
        local pct = (voterTotal > 0) and math.floor(c / voterTotal * 100 + 0.5) or 0
        SendChatMessage(string.format("  %s: %d (%d%%)", clean(opt), c, pct), channel)
    end
    SendChatMessage(
        string.format("  (%d voter%s)", voterTotal, voterTotal == 1 and "" or "s"),
        channel)
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

    local counts, voterTotal = TallyVotes(poll)
    PostTally(channel, poll.question, poll.options, counts, voterTotal)
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

    PostTally(channel, entry.question, entry.options, entry.counts or {}, entry.voterTotal or 0)
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
