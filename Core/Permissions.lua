----------------------------------------------------------------------
-- RaidLead — Core/Permissions.lua
-- Permission checks for broadcasting assignments
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

function ns.CanBroadcast()
    if ns.GetGroupType() ~= "raid" then return true end  -- in party, anyone can
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function ns.IsRaidLeader()
    return UnitIsGroupLeader("player")
end

----------------------------------------------------------------------
-- Who can send a Role Check broadcast.
-- Solo: allowed (lets the local user test without errors).
-- Group/raid: leader only - assistants do not get this control.
----------------------------------------------------------------------
function ns.CanSendRoleCheck()
    if ns.GetGroupType() == "solo" then return true end
    return UnitIsGroupLeader("player") and true or false
end

----------------------------------------------------------------------
-- Who may modify raid-coordination data (assignments, marks, polls).
-- Same rule as broadcasting: solo/party anyone, in a raid lead/assist.
-- Personal settings (own role, addon display options) are NOT gated.
----------------------------------------------------------------------
function ns.CanEdit()
    return ns.CanBroadcast()
end

-- Standard "you can't edit right now" chat notice. Permission-aware so
-- non-lead/assist players don't get told to "click the lock icon" (which
-- wouldn't help them).
function ns.LockedNotice()
    if not ns.CanEdit() then
        ns.P("|cFFFF8800View only.|r Only the raid leader or assistants can make changes.")
    else
        ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
    end
end
