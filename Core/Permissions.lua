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
