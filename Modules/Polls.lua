----------------------------------------------------------------------
-- RaidLead - Modules/Polls.lua
-- Quick raid polls: lead initiates a question ("Continue or wipe?"),
-- all RaidLead users see a popup with vote buttons, results tally
-- live for the initiator.
--
-- Comm protocol (3 message types):
--   POLL_START <pollId> <question> <opt1>|<opt2>|...   broadcast from initiator
--   POLL_VOTE  <pollId> <choiceIdx>                    broadcast from voter
--   POLL_END   <pollId>                                broadcast from initiator
--
-- Choice indices are 1-based; option labels arrive separated by "|"
-- because the Comm SEP (tab) is already used as the field separator.
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

----------------------------------------------------------------------
-- Sender side: initiate a poll
----------------------------------------------------------------------
function Polls.SendPoll(question, options)
    if not ns.Comm then return end
    if not question or question == "" or not options or #options < 2 then
        ns.P("|cFFFF8800Poll needs a question and at least 2 options.|r")
        return
    end

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
        votes     = {},  -- voterName -> choiceIdx
        startedAt = now,
    }

    -- Broadcast to peers (no-op when solo)
    ns.Comm.Send("POLL_START", pollId, question, PackOptions(options))

    -- Initiator also opens their results window AND a local vote popup
    -- so they can vote too (mirrors role-check behavior).
    if ns.ShowPollResultsWindow then
        ns.ShowPollResultsWindow(Polls.activePoll)
    end
    if ns.ShowPollVoteDialog then
        ns.ShowPollVoteDialog(pollId, question, options, UnitName("player"))
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

function Polls.RecordVote(pollId, voterName, choiceIdx)
    if not Polls.activePoll or Polls.activePoll.id ~= pollId then return end
    if not voterName or voterName == "" then return end
    if not choiceIdx or choiceIdx < 1 or choiceIdx > #Polls.activePoll.options then return end

    Polls.activePoll.votes[voterName] = choiceIdx

    if ns.RefreshPollResultsWindow then
        ns.RefreshPollResultsWindow(Polls.activePoll)
    end
end

function Polls.EndPoll(pollId, reason)
    if not Polls.activePoll or Polls.activePoll.id ~= pollId then return end

    if ns.Comm then
        ns.Comm.Send("POLL_END", pollId)
    end
    if ns.MarkPollEnded then ns.MarkPollEnded(Polls.activePoll, reason) end

    -- Keep the results window open so the lead can read final tally;
    -- they close it manually.
    Polls.activePoll.endedAt = GetTime()
end

----------------------------------------------------------------------
-- Vote side: respond to a poll
----------------------------------------------------------------------
function Polls.CastVote(pollId, choiceIdx)
    if not ns.Comm then return end
    if not pollId or not choiceIdx then return end
    ns.Comm.Send("POLL_VOTE", pollId, tostring(choiceIdx))
end

----------------------------------------------------------------------
-- Comm handlers
----------------------------------------------------------------------
if ns.Comm then
    ns.Comm.RegisterHandler("POLL_START", function(parts, sender, channel)
        local pollId   = parts[2]
        local question = parts[3]
        local optsStr  = parts[4]
        if not (pollId and question and optsStr) then return end

        local options = UnpackOptions(optsStr)
        if #options < 2 then return end

        if ns.ShowPollVoteDialog then
            ns.ShowPollVoteDialog(pollId, question, options, sender)
        end
    end)

    ns.Comm.RegisterHandler("POLL_VOTE", function(parts, sender, channel)
        local pollId    = parts[2]
        local choiceIdx = tonumber(parts[3])
        if not (pollId and choiceIdx) then return end
        Polls.RecordVote(pollId, sender, choiceIdx)
    end)

    ns.Comm.RegisterHandler("POLL_END", function(parts, sender, channel)
        local pollId = parts[2]
        if not pollId then return end
        if ns.HidePollVoteDialog then
            ns.HidePollVoteDialog(pollId)
        end
    end)
end
