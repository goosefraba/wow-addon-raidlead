----------------------------------------------------------------------
-- RaidLead - UI/ProfileFrame.lua
-- "Profile" tab: personal settings the local player declares for
-- themselves and shares with everyone else in the raid that has
-- this addon installed.
--
-- Currently hosts:
--   * My Role  - tank / healer / melee / ranged
-- Planned additions:
--   * Loot targets / wishlist
--   * Per-player buff preferences (flask choice, food, etc.)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f = ns.mainFrame

----------------------------------------------------------------------
-- Tab content frame
----------------------------------------------------------------------
local profileContent = CreateFrame("Frame", nil, f)
profileContent:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -68)
profileContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
profileContent:Hide()

----------------------------------------------------------------------
-- Top intro
----------------------------------------------------------------------
local intro = profileContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
intro:SetPoint("TOPLEFT", profileContent, "TOPLEFT", 4, -2)
intro:SetPoint("RIGHT", profileContent, "RIGHT", -4, 0)
intro:SetJustifyH("LEFT")
intro:SetText("Personal settings - shared with everyone in the raid who has RaidLead installed.")
intro:SetTextColor(0.6, 0.6, 0.6)

----------------------------------------------------------------------
-- Section: My Role
----------------------------------------------------------------------
local roleHeader = ns.MakeSectionHeader(profileContent, "My Role")
roleHeader:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", -4, -6)
roleHeader:SetPoint("RIGHT", profileContent, "RIGHT", -4, 0)

local roleRow = CreateFrame("Frame", nil, profileContent)
roleRow:SetHeight(24)
roleRow:SetPoint("TOPLEFT", roleHeader, "BOTTOMLEFT", 4, -6)
roleRow:SetPoint("RIGHT", profileContent, "RIGHT", -4, 0)

local roleLabel = roleRow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
roleLabel:SetPoint("LEFT", roleRow, "LEFT", 0, 0)
roleLabel:SetText("Role today:")

local roleBtn = ns.MakeSmallButton(roleRow, "(not set)", 140, 22)
roleBtn:SetPoint("LEFT", roleLabel, "RIGHT", 10, 0)

local roleHint = roleRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
roleHint:SetPoint("LEFT", roleBtn, "RIGHT", 12, 0)
roleHint:SetPoint("RIGHT", roleRow, "RIGHT", 0, 0)
roleHint:SetJustifyH("LEFT")
roleHint:SetText("Used by Auto-Assign in the Roles tab and broadcast to raid.")
roleHint:SetTextColor(0.55, 0.55, 0.55)

local function UpdateMyRoleButton()
    if not ns.Roles then
        roleBtn:SetText("(not set)")
        return
    end
    local myRole = ns.Roles.GetMyRole()
    if myRole and ns.Roles.ROLE_LABELS[myRole] then
        local color = ns.Roles.ROLE_COLORS[myRole] or "FFFFFFFF"
        local icon  = ns.Roles.IconString and ns.Roles.IconString(myRole, 14) or ""
        roleBtn:SetText(icon .. " |c" .. color .. ns.Roles.ROLE_LABELS[myRole] .. "|r")
    else
        roleBtn:SetText("(not set)")
    end
end
ns.UpdateMyRoleButton = UpdateMyRoleButton

local function OnRolePicked(roleKey)
    if not ns.Roles then return end
    ns.Roles.SetMyRole(roleKey)
    UpdateMyRoleButton()
    -- Refresh other tabs that surface roles
    if ns.RefreshHealAssign  then ns.RefreshHealAssign()  end
    if ns.RefreshGridTab     then ns.RefreshGridTab()     end
    if ns.RefreshRolesRoster then ns.RefreshRolesRoster() end
end

roleBtn:SetScript("OnClick", function()
    if not ns.Roles then return end
    local menu = { { text = "Pick Your Role Today", isTitle = true } }
    for _, key in ipairs(ns.Roles.ROLE_KEYS) do
        local label   = ns.Roles.ROLE_LABELS[key]
        local color   = ns.Roles.ROLE_COLORS[key]
        local icon    = ns.Roles.IconString and ns.Roles.IconString(key, 14) or ""
        local roleKey = key
        menu[#menu + 1] = {
            text = icon .. " |c" .. color .. label .. "|r",
            func = function() OnRolePicked(roleKey) end,
        }
    end
    menu[#menu + 1] = {
        text = "|cFF888888(clear)|r",
        func = function() OnRolePicked(nil) end,
    }
    ns.ShowContextMenu(menu, "cursor", 0, 0)
end)

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
local function RefreshProfile()
    UpdateMyRoleButton()
end
ns.RefreshProfile = RefreshProfile

----------------------------------------------------------------------
-- Register the tab
----------------------------------------------------------------------
ns.RegisterTab("Profile", 30, profileContent, RefreshProfile)
