----------------------------------------------------------------------
-- RaidLead — UI/HealAssignFrame.lua
-- Roles tab: two views switchable via a toggle at the top.
--   1) "Assignments" - global healer assignments + hunter Misdirect
--   2) "Roster"      - declared role for every raid member, grouped
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f = ns.mainFrame

----------------------------------------------------------------------
-- Tab content frame
----------------------------------------------------------------------
local healContent = CreateFrame("Frame", nil, f)
healContent:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -68)
healContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
healContent:Hide()

----------------------------------------------------------------------
-- View toggle (top-right)
----------------------------------------------------------------------
local SetRolesViewMode  -- forward declare; assigned at the bottom
local viewMode = "assignments"

local toggleRow = CreateFrame("Frame", nil, healContent)
toggleRow:SetSize(340, 22)
toggleRow:SetPoint("TOPRIGHT", healContent, "TOPRIGHT", -4, -2)

local assignmentsBtn = ns.MakePill(toggleRow, "Assignments")
assignmentsBtn:SetWidth(86)
assignmentsBtn:SetPoint("LEFT", toggleRow, "LEFT", 0, 0)
assignmentsBtn:SetScript("OnClick", function() if SetRolesViewMode then SetRolesViewMode("assignments") end end)

local cooldownsBtn = ns.MakePill(toggleRow, "Cooldowns")
cooldownsBtn:SetWidth(90)
cooldownsBtn:SetPoint("LEFT", assignmentsBtn, "RIGHT", 4, 0)
cooldownsBtn:SetScript("OnClick", function() if SetRolesViewMode then SetRolesViewMode("cooldowns") end end)

local ccBtn = ns.MakePill(toggleRow, "CC")
ccBtn:SetWidth(50)
ccBtn:SetPoint("LEFT", cooldownsBtn, "RIGHT", 4, 0)
ccBtn:SetScript("OnClick", function() if SetRolesViewMode then SetRolesViewMode("cc") end end)

local rosterBtn = ns.MakePill(toggleRow, "Roster")
rosterBtn:SetWidth(72)
rosterBtn:SetPoint("LEFT", ccBtn, "RIGHT", 4, 0)
rosterBtn:SetScript("OnClick", function() if SetRolesViewMode then SetRolesViewMode("roster") end end)

----------------------------------------------------------------------
-- Top hint (shares row with the toggle - text changes per view mode)
----------------------------------------------------------------------
local hint = healContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPLEFT", healContent, "TOPLEFT", 4, -2)
hint:SetPoint("RIGHT", toggleRow, "LEFT", -8, 0)
hint:SetJustifyH("LEFT")
hint:SetText("Auto-detected by class. Set your own role in the Profile tab.")
hint:SetTextColor(0.6, 0.6, 0.6)

----------------------------------------------------------------------
-- Section: Healers
----------------------------------------------------------------------
local healHeader = ns.MakeSectionHeader(healContent, "Healers")
healHeader:SetPoint("TOPLEFT", healContent, "TOPLEFT", 0, -22)
healHeader:SetPoint("RIGHT", healContent, "RIGHT", -4, 0)

-- Look up RGB for class color
local function ClassColorRGB(class)
    local hex = ns.CLASS_COLORS[(class or ""):upper()] or "AAAAAA"
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b
end

----------------------------------------------------------------------
-- Reserve bottom area for: Misdirect section (~150) + buttons (~36)
----------------------------------------------------------------------
local MISDIRECT_AREA_HEIGHT = 160

local scrollParent = CreateFrame("Frame", nil, healContent)
scrollParent:SetPoint("TOPLEFT", healHeader, "BOTTOMLEFT", 0, -4)
scrollParent:SetPoint("RIGHT", healContent, "RIGHT", -20, 0)
scrollParent:SetPoint("BOTTOM", healContent, "BOTTOM", 0, MISDIRECT_AREA_HEIGHT + 36)

local scrollFrame = CreateFrame("ScrollFrame", "RaidLeadHealScroll", healContent, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", scrollParent, "BOTTOMRIGHT", 0, 0)

local scrollInner = CreateFrame("Frame", nil, healContent)
scrollInner:SetPoint("TOPLEFT", scrollParent, "TOPLEFT", 0, 0)
scrollInner:SetPoint("BOTTOMRIGHT", scrollParent, "BOTTOMRIGHT", 0, 0)

----------------------------------------------------------------------
-- Healer row pool
----------------------------------------------------------------------
local ROW_HEIGHT = 28
local rows = {}

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, scrollInner)
    row:SetHeight(ROW_HEIGHT)
    row:SetPoint("TOPLEFT", scrollInner, "TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))
    row:SetPoint("RIGHT", scrollInner, "RIGHT", 0, 0)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.nameText:SetWidth(130)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.statusText:SetPoint("LEFT", row, "LEFT", 140, 0)
    row.statusText:SetWidth(60)
    row.statusText:SetJustifyH("LEFT")

    row.targetDD = ns.CreatePlayerDropdown(row, 130, function(playerName)
        if not row.healerName then return end
        if playerName then
            ns.HealAssign.SetConfig(row.healerName, "dedicated", playerName)
        else
            ns.HealAssign.SetConfig(row.healerName, "cross")
        end
        ns.RefreshHealAssign()
    end)
    row.targetDD.respectLock = true
    row.targetDD:SetPoint("LEFT", row.statusText, "RIGHT", 6, 0)

    row.esLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.esLabel:SetPoint("LEFT", row.targetDD, "RIGHT", 6, 0)
    row.esLabel:SetText("ES:")
    row.esLabel:SetTextColor(0.55, 0.85, 1)

    row.esDD = ns.CreatePlayerDropdown(row, 105, function(playerName)
        if not row.healerName then return end
        ns.HealAssign.SetEarthShield(row.healerName, playerName)
        ns.RefreshHealAssign()
    end)
    row.esDD.respectLock = true
    row.esDD:SetPoint("LEFT", row.esLabel, "RIGHT", 4, 0)

    row.noHealBtn = ns.MakeSmallButton(row, "Off", 60, 22)
    row.noHealBtn:SetPoint("LEFT", row.esDD, "RIGHT", 6, 0)
    row.noHealBtn:SetScript("OnClick", function()
        if ns.HealAssign.IsLocked() then
            ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
            return
        end
        if not row.healerName then return end
        local cfg = ns.HealAssign.GetConfig(row.healerName) or { mode = "cross" }
        if cfg.mode == "none" then
            ns.HealAssign.SetConfig(row.healerName, "cross")
        else
            ns.HealAssign.SetConfig(row.healerName, "none")
        end
        ns.RefreshHealAssign()
    end)
    -- HookScript (not SetScript) so the hover-tint behavior baked into
    -- MakeSmallButton's OnEnter/OnLeave still fires alongside the tooltip.
    row.noHealBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Toggle 'Not healing'", 1, 0.82, 0.1)
        GameTooltip:AddLine("Mark this healer as DPS-spec / not healing.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    row.noHealBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    rows[index] = row
    return row
end

----------------------------------------------------------------------
-- Section: Hunter Misdirect
----------------------------------------------------------------------
local mdContainer = CreateFrame("Frame", nil, healContent)
mdContainer:SetHeight(MISDIRECT_AREA_HEIGHT)
mdContainer:SetPoint("BOTTOMLEFT", healContent, "BOTTOMLEFT", 0, 36)
mdContainer:SetPoint("BOTTOMRIGHT", healContent, "BOTTOMRIGHT", -20, 36)

local mdHeader = ns.MakeSectionHeader(mdContainer, "Hunter Misdirect")
mdHeader:SetPoint("TOPLEFT", mdContainer, "TOPLEFT", 0, -2)
mdHeader:SetPoint("RIGHT", mdContainer, "RIGHT", -4, 0)

local mdHint = mdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mdHint:SetPoint("TOPLEFT", mdHeader, "BOTTOMLEFT", 0, -2)
mdHint:SetPoint("RIGHT", mdContainer, "RIGHT", -4, 0)
mdHint:SetJustifyH("LEFT")
mdHint:SetText("Pick a tank for each hunter to redirect threat to.")
mdHint:SetTextColor(0.6, 0.6, 0.6)

local mdEmpty = mdContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
mdEmpty:SetPoint("TOPLEFT", mdHint, "BOTTOMLEFT", 4, -8)
mdEmpty:SetText("|cFF888888(no hunters in raid)|r")
mdEmpty:Hide()

local MD_ROW_HEIGHT = 26
local mdRows = {}

local function CreateMisdirectRow(index)
    local row = CreateFrame("Frame", nil, mdContainer)
    row:SetHeight(MD_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", mdContainer, "TOPLEFT", 4, -42 - (index - 1) * MD_ROW_HEIGHT)
    row:SetPoint("RIGHT", mdContainer, "RIGHT", -4, 0)

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.nameText:SetWidth(120)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.arrow:SetPoint("LEFT", row, "LEFT", 130, 0)
    row.arrow:SetText("MD ->")
    row.arrow:SetTextColor(0.85, 0.6, 0.3)

    row.targetDD = ns.CreatePlayerDropdown(row, 200, function(playerName)
        if not row.hunterName then return end
        ns.HealAssign.SetMisdirect(row.hunterName, playerName)
        ns.RefreshHealAssign()
    end)
    row.targetDD.respectLock = true
    row.targetDD:SetPoint("LEFT", row.arrow, "RIGHT", 6, 0)

    mdRows[index] = row
    return row
end

----------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------
local function RefreshHealAssign()
    -- Keep the Profile tab in sync if it's the source of truth for My Role
    if ns.UpdateMyRoleButton then ns.UpdateMyRoleButton() end

    -- Healer rows
    local healers = ns.HealAssign.GetHealers()
    local total = #healers

    local parentH = scrollInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / ROW_HEIGHT))

    FauxScrollFrame_Update(scrollFrame, total, visibleRows, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame)

    for i = 1, visibleRows do
        local row = rows[i] or CreateRow(i)
        local dataIdx = offset + i
        if dataIdx <= total then
            local h = healers[dataIdx]
            row.healerName = h.name

            -- Append role tag if this player has self-declared a role
            local roleColored = ns.Roles and ns.Roles.ColorTag(ns.Roles.GetRole(h.name))
            if roleColored then
                row.nameText:SetText(h.name .. "  " .. roleColored)
            else
                row.nameText:SetText(h.name)
            end
            row.nameText:SetTextColor(ClassColorRGB(h.class))

            local cfg = ns.HealAssign.GetConfig(h.name) or { mode = "cross" }

            if cfg.mode == "none" then
                row.statusText:SetText("Off")
                row.statusText:SetTextColor(0.6, 0.6, 0.6)
                row.targetDD:SetSelectedPlayer(nil, nil)
                row.targetDD:SetAlpha(0.4)
                row.noHealBtn:SetText("|cFFFF8800Off|r")
            elseif cfg.mode == "dedicated" and cfg.target then
                row.statusText:SetText("Heals:")
                row.statusText:SetTextColor(0.6, 0.85, 1)
                local class = "UNKNOWN"
                if ns.BuffScan.scanResults[cfg.target] then
                    class = ns.BuffScan.scanResults[cfg.target].class or "UNKNOWN"
                end
                row.targetDD:SetSelectedPlayer(cfg.target, class)
                row.targetDD:SetAlpha(1)
                row.noHealBtn:SetText("Off")
            else
                row.statusText:SetText("Cross-heal")
                row.statusText:SetTextColor(0.85, 0.85, 0.85)
                row.targetDD:SetSelectedPlayer(nil, nil)
                row.targetDD:SetAlpha(1)
                row.noHealBtn:SetText("Off")
            end

            -- ES is only relevant for active shaman healers (not "Off")
            if h.class == "SHAMAN" and cfg.mode ~= "none" then
                row.esLabel:Show()
                row.esDD:Show()
                local es = cfg.earthShield
                if es then
                    local esClass = "UNKNOWN"
                    if ns.BuffScan.scanResults[es] then
                        esClass = ns.BuffScan.scanResults[es].class or "UNKNOWN"
                    end
                    row.esDD:SetSelectedPlayer(es, esClass)
                else
                    row.esDD:SetSelectedPlayer(nil, nil)
                end
            else
                row.esLabel:Hide()
                row.esDD:Hide()
            end

            row:Show()
        else
            row:Hide()
            row.healerName = nil
        end
    end

    for i = visibleRows + 1, #rows do
        rows[i]:Hide()
        rows[i].healerName = nil
    end

    -- Misdirect rows (hunters)
    local hunters = ns.HealAssign.GetHunters()
    if #hunters == 0 then
        mdEmpty:Show()
        for _, mdRow in ipairs(mdRows) do mdRow:Hide() end
    else
        mdEmpty:Hide()
        local maxRows = math.min(#hunters, 5)
        for i = 1, maxRows do
            local mdRow = mdRows[i] or CreateMisdirectRow(i)
            local h = hunters[i]
            mdRow.hunterName = h.name

            mdRow.nameText:SetText(h.name)
            mdRow.nameText:SetTextColor(ClassColorRGB(h.class))

            local target = ns.HealAssign.GetMisdirect(h.name)
            if target then
                local class = "UNKNOWN"
                if ns.BuffScan.scanResults[target] then
                    class = ns.BuffScan.scanResults[target].class or "UNKNOWN"
                end
                mdRow.targetDD:SetSelectedPlayer(target, class)
            else
                mdRow.targetDD:SetSelectedPlayer(nil, nil)
            end
            mdRow:Show()
        end
        for i = maxRows + 1, #mdRows do
            mdRows[i]:Hide()
            mdRows[i].hunterName = nil
        end
    end
end
ns.RefreshHealAssign = RefreshHealAssign

scrollFrame:SetScript("OnVerticalScroll", function(self, off)
    FauxScrollFrame_OnVerticalScroll(self, off, ROW_HEIGHT, RefreshHealAssign)
end)

----------------------------------------------------------------------
-- Roster view: dedicated grid of every raid member + declared role
----------------------------------------------------------------------
local rosterContainer = CreateFrame("Frame", nil, healContent)
rosterContainer:SetPoint("TOPLEFT",     healContent, "TOPLEFT",     0,  -26)
rosterContainer:SetPoint("BOTTOMRIGHT", healContent, "BOTTOMRIGHT", -20, 4)
rosterContainer:Hide()

-- Roster header row: summary text + "Request Role Check" button on the right
local rosterHeader = CreateFrame("Frame", nil, rosterContainer)
rosterHeader:SetHeight(24)
rosterHeader:SetPoint("TOPLEFT",  rosterContainer, "TOPLEFT",  0, 0)
rosterHeader:SetPoint("TOPRIGHT", rosterContainer, "TOPRIGHT", 0, 0)

local roleCheckBtn = ns.MakeSmallButton(rosterHeader, "Request Role Check", 140, 22)
roleCheckBtn:SetPoint("RIGHT", rosterHeader, "RIGHT", -4, 0)
roleCheckBtn:SetScript("OnClick", function()
    if ns.Roles and ns.Roles.SendRoleCheck then ns.Roles.SendRoleCheck() end
end)

-- Quick Poll launcher - leader / assistant only.
local quickPollBtn = ns.MakeSmallButton(rosterHeader, "Quick Poll", 100, 22)
quickPollBtn:SetPoint("RIGHT", roleCheckBtn, "LEFT", -6, 0)
quickPollBtn:SetScript("OnClick", function()
    if ns.CanBroadcast and not ns.CanBroadcast() then
        ns.P("|cFFFF8800Only the raid leader or an assistant can start a poll.|r")
        return
    end
    if ns.ShowPollLauncher then ns.ShowPollLauncher() end
end)
quickPollBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Quick Poll", 1, 0.82, 0.1)
    GameTooltip:AddLine(
        "Send a yes/no or continue/wipe/break question to every RaidLead user in the raid. "
        .. "Live tally for the initiator.",
        0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Leader or assistant only.", 0.85, 0.55, 0.2, true)
    GameTooltip:Show()
end)
quickPollBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateQuickPollBtn()
    local can = ns.CanBroadcast and ns.CanBroadcast() or false
    quickPollBtn:SetShown(can)
end
ns.UpdateQuickPollButton = UpdateQuickPollBtn
UpdateQuickPollBtn()

roleCheckBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Request Role Check", 1, 0.82, 0.1)
    GameTooltip:AddLine(
        "Asks every RaidLead user in the raid to confirm their role via a popup. "
        .. "Players without the addon won't be prompted.",
        0.8, 0.8, 0.8, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Only the raid leader can send a role check.", 0.85, 0.55, 0.2, true)
    GameTooltip:Show()
end)
roleCheckBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Visibility gated by raid-leader status. Refreshed on tab/roster
-- refresh and on group-leader change events.
local function UpdateRoleCheckBtn()
    local can = ns.CanSendRoleCheck and ns.CanSendRoleCheck() or false
    roleCheckBtn:SetShown(can)
end
ns.UpdateRoleCheckButton = UpdateRoleCheckBtn
UpdateRoleCheckBtn()

local rosterSummary = rosterHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
rosterSummary:SetPoint("LEFT",  rosterHeader, "LEFT", 4, 0)
rosterSummary:SetPoint("RIGHT", roleCheckBtn, "LEFT", -8, 0)
rosterSummary:SetJustifyH("LEFT")
rosterSummary:SetWordWrap(false)

local rosterScrollParent = CreateFrame("Frame", nil, rosterContainer)
rosterScrollParent:SetPoint("TOPLEFT",     rosterHeader,    "BOTTOMLEFT",  0, -6)
rosterScrollParent:SetPoint("BOTTOMRIGHT", rosterContainer, "BOTTOMRIGHT", 0,  0)

local rosterScroll = CreateFrame("ScrollFrame", "RaidLeadRosterScroll", rosterContainer, "FauxScrollFrameTemplate")
rosterScroll:SetPoint("TOPLEFT",     rosterScrollParent, "TOPLEFT",     0, 0)
rosterScroll:SetPoint("BOTTOMRIGHT", rosterScrollParent, "BOTTOMRIGHT", 0, 0)

local rosterInner = CreateFrame("Frame", nil, rosterContainer)
rosterInner:SetPoint("TOPLEFT",     rosterScrollParent, "TOPLEFT",     0, 0)
rosterInner:SetPoint("BOTTOMRIGHT", rosterScrollParent, "BOTTOMRIGHT", 0, 0)

local ROSTER_ROW_HEIGHT = 18
local rosterRows    = {}
local rosterEntries = {}

local GROUP_ORDER  = { "tank", "healer", "melee", "ranged", "unknown" }
local GROUP_LABELS = {
    tank    = "Tanks",
    healer  = "Healers",
    melee   = "Melee DPS",
    ranged  = "Ranged DPS",
    unknown = "Unknown / no role declared",
}

local function CreateRosterRow(idx)
    local row = CreateFrame("Frame", nil, rosterInner)
    row:SetHeight(ROSTER_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", rosterInner, "TOPLEFT", 0, -((idx - 1) * ROSTER_ROW_HEIGHT))
    row:SetPoint("RIGHT",   rosterInner, "RIGHT",   0, 0)
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.08, 0.08, 0.10, 0)

    -- Subtle hover highlight (shown only on data rows)
    row.hover = row:CreateTexture(nil, "ARTWORK")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(1, 1, 1, 0.06)
    row.hover:Hide()

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.nameText:SetWidth(240)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.roleText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.roleText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.roleText:SetWidth(160)
    row.roleText:SetJustifyH("RIGHT")
    row.roleText:SetWordWrap(false)

    row:SetScript("OnEnter", function(self)
        local e = self.data
        if not e or e.type ~= "row" then return end
        self.hover:Show()

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(ns.ClassColor(e.class) .. e.name .. "|r", 1, 1, 1)

        -- Role
        if e.role and ns.Roles then
            local label = ns.Roles.ROLE_LABELS[e.role] or e.role
            local color = ns.Roles.ROLE_COLORS[e.role] or "FFCCCCCC"
            local icon  = ns.Roles.IconString and ns.Roles.IconString(e.role, 14) or ""
            GameTooltip:AddLine("Role: " .. icon .. " |c" .. color .. label .. "|r",
                0.85, 0.85, 0.85)
        else
            GameTooltip:AddLine("Role: |cFF888888(not declared)|r", 0.85, 0.85, 0.85)
        end

        -- Addon version
        local peerVer = ns.Versions and ns.Versions.GetVersion(e.name)
        if peerVer then
            local cmp = ns.Versions.CompareToMine(peerVer)
            if cmp == nil or cmp == 0 then
                GameTooltip:AddLine("Addon: v" .. peerVer, 0.7, 0.7, 0.7)
            elseif cmp < 0 then
                GameTooltip:AddLine("Addon: v" .. peerVer
                    .. "  |cFFFF6644(outdated, you're on v"
                    .. (ns.VERSION or "?") .. ")|r", 1, 0.55, 0.3)
            else
                GameTooltip:AddLine("Addon: v" .. peerVer
                    .. "  |cFF55BBFF(newer than yours)|r", 0.55, 0.85, 1)
            end
        else
            GameTooltip:AddLine("Addon: |cFF888888not detected|r", 0.6, 0.6, 0.6)
        end

        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
        GameTooltip:Hide()
    end)

    rosterRows[idx] = row
    return row
end

local function PopulateRosterRow(row, entry, isAlt)
    row.data = entry  -- stashed so OnEnter can build the tooltip
    if entry.type == "header" then
        row.bg:SetColorTexture(0.18, 0.16, 0.10, 0.75)
        row.nameText:SetText("|cFFFFCC00" .. entry.label
            .. "|r  |cFF888888(" .. entry.count .. ")|r")
        row.roleText:SetText("")
    else
        row.bg:SetColorTexture(0.08, 0.08, 0.10, isAlt and 0.55 or 0.25)
        row.nameText:SetText(ns.ClassColor(entry.class) .. entry.name .. "|r")
        if entry.role then
            local tag  = ns.Roles and ns.Roles.ColorTag(entry.role) or entry.role
            local icon = ns.Roles and ns.Roles.IconString and ns.Roles.IconString(entry.role, 14) or ""
            row.roleText:SetText(icon .. " " .. tag)
        else
            row.roleText:SetText("|cFF666666(unknown)|r")
        end
    end
end

local function BuildRosterEntries()
    rosterEntries = {}
    if not ns.BuffScan or not ns.BuffScan.scanResults then return end

    local buckets = {}
    for _, k in ipairs(GROUP_ORDER) do buckets[k] = {} end

    for name, info in pairs(ns.BuffScan.scanResults) do
        local role = ns.Roles and ns.Roles.GetRole(name)
        local bucket = (role and buckets[role]) or buckets.unknown
        bucket[#bucket + 1] = { name = name, class = info.class or "UNKNOWN", role = role }
    end

    for _, b in pairs(buckets) do
        table.sort(b, function(a, c) return a.name < c.name end)
    end

    for _, gKey in ipairs(GROUP_ORDER) do
        local b = buckets[gKey]
        if #b > 0 then
            rosterEntries[#rosterEntries + 1] = {
                type = "header", label = GROUP_LABELS[gKey], count = #b,
            }
            for _, p in ipairs(b) do
                rosterEntries[#rosterEntries + 1] = {
                    type = "row", name = p.name, class = p.class, role = p.role,
                }
            end
        end
    end
end

local function BuildRosterSummary()
    local counts = { tank = 0, healer = 0, melee = 0, ranged = 0, unknown = 0 }
    local total = 0
    for _, e in ipairs(rosterEntries) do
        if e.type == "row" then
            local k = e.role or "unknown"
            counts[k] = (counts[k] or 0) + 1
            total = total + 1
        end
    end

    if total == 0 then
        rosterSummary:SetText("|cFF888888No raid members yet. Open the addon or run /rl scan.|r")
        return
    end

    local parts = {}
    local function add(key, label, color)
        if counts[key] and counts[key] > 0 then
            parts[#parts + 1] = "|c" .. color .. counts[key] .. " " .. label .. "|r"
        end
    end
    local C = ns.Roles and ns.Roles.ROLE_COLORS or {}
    add("tank",    "Tanks",  C.tank   or "FF4488CC")
    add("healer",  "Healers", C.healer or "FF44CC88")
    add("melee",   "Melee",  C.melee  or "FFDD5555")
    add("ranged",  "Ranged", C.ranged or "FFDDAA55")
    add("unknown", "Unknown", "FF888888")

    rosterSummary:SetText(total .. " raid member"
        .. (total == 1 and "" or "s") .. ":  " .. table.concat(parts, "   "))
end

local function RefreshRoster()
    UpdateRoleCheckBtn()
    UpdateQuickPollBtn()
    BuildRosterEntries()
    BuildRosterSummary()

    local parentH = rosterInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / ROSTER_ROW_HEIGHT))
    local total = #rosterEntries

    FauxScrollFrame_Update(rosterScroll, total, visibleRows, ROSTER_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(rosterScroll)

    local stripe = false
    for i = 1, visibleRows do
        local row = rosterRows[i] or CreateRosterRow(i)
        local dataIdx = offset + i
        if dataIdx <= total then
            local entry = rosterEntries[dataIdx]
            if entry.type == "row" then
                PopulateRosterRow(row, entry, stripe)
                stripe = not stripe
            else
                PopulateRosterRow(row, entry, false)
                stripe = false
            end
            row:Show()
        else
            row:Hide()
        end
    end
    for i = visibleRows + 1, #rosterRows do
        rosterRows[i]:Hide()
    end
end
ns.RefreshRolesRoster = RefreshRoster

rosterScroll:SetScript("OnVerticalScroll", function(self, off)
    FauxScrollFrame_OnVerticalScroll(self, off, ROSTER_ROW_HEIGHT, RefreshRoster)
end)

----------------------------------------------------------------------
-- Cooldowns view: raid cooldown assignments (caster + optional target)
----------------------------------------------------------------------
local cooldownsContainer = CreateFrame("Frame", nil, healContent)
cooldownsContainer:SetPoint("TOPLEFT",     healContent, "TOPLEFT",     0,  -26)
cooldownsContainer:SetPoint("BOTTOMRIGHT", healContent, "BOTTOMRIGHT", -20, 4)
cooldownsContainer:Hide()

local cdHeader = ns.MakeSectionHeader(cooldownsContainer, "Raid Cooldowns")
cdHeader:SetPoint("TOPLEFT", cooldownsContainer, "TOPLEFT", 0, 0)
cdHeader:SetPoint("RIGHT",   cooldownsContainer, "RIGHT",   -4, 0)

local CD_ROW_H = 28
local cdRows = {}  -- [cdKey] = { label, casterDD, targetDD, cd }

local function CreateCooldownRow(idx, cd)
    local row = CreateFrame("Frame", nil, cooldownsContainer)
    row:SetHeight(CD_ROW_H)
    row:SetPoint("TOPLEFT", cooldownsContainer, "TOPLEFT", 4,  -24 - (idx - 1) * CD_ROW_H)
    row:SetPoint("RIGHT",   cooldownsContainer, "RIGHT",   -4, 0)

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    label:SetWidth(140)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(cd.label)
    label:SetTextColor(ClassColorRGB(cd.class))

    -- Mouse area for the label tooltip
    local hover = CreateFrame("Frame", nil, row)
    hover:SetPoint("TOPLEFT", label, "TOPLEFT", 0, 2)
    hover:SetPoint("BOTTOMRIGHT", label, "BOTTOMRIGHT", 0, -2)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(cd.label, 1, 0.82, 0.1)
        if cd.tip then GameTooltip:AddLine(cd.tip, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local casterDD = ns.CreatePlayerDropdown(row, 140, function(playerName)
        local rec = ns.CooldownAssign.GetCD(cd.key) or {}
        ns.CooldownAssign.SetCD(cd.key, playerName, rec.target)
    end)
    casterDD.respectLock = true
    casterDD:SetPoint("LEFT", label, "RIGHT", 6, 0)

    local targetDD
    local arrow, raidWide
    if cd.needsTarget then
        arrow = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        arrow:SetPoint("LEFT", casterDD, "RIGHT", 6, 0)
        arrow:SetText("->")
        arrow:SetTextColor(0.85, 0.6, 0.3)

        targetDD = ns.CreatePlayerDropdown(row, 140, function(playerName)
            local rec = ns.CooldownAssign.GetCD(cd.key) or {}
            ns.CooldownAssign.SetCD(cd.key, rec.caster, playerName)
        end)
        targetDD.respectLock = true
        targetDD:SetPoint("LEFT", arrow, "RIGHT", 4, 0)
    else
        raidWide = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        raidWide:SetPoint("LEFT", casterDD, "RIGHT", 10, 0)
        raidWide:SetText("|cFF888888(raid-wide)|r")
    end

    cdRows[cd.key] = {
        row      = row,
        label    = label,
        casterDD = casterDD,
        targetDD = targetDD,
        cd       = cd,
    }
    return row
end

for i, cd in ipairs(ns.CooldownAssign.COOLDOWNS) do
    CreateCooldownRow(i, cd)
end

-- Bottom buttons for cooldowns view
local cdAnnounceBtn = ns.MakeSmallButton(cooldownsContainer, "Announce", 110, 24)
cdAnnounceBtn:SetPoint("BOTTOMLEFT", cooldownsContainer, "BOTTOMLEFT", 0, 4)
cdAnnounceBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
cdAnnounceBtn:SetScript("OnClick", function(self, button)
    local function GetLines() return ns.CooldownAssign.BuildCooldownLines() end
    if button == "RightButton" then
        ns.BossTemplates.ShowChannelMenu(GetLines)
    else
        ns.BossTemplates.SendLines(GetLines())
    end
end)
cdAnnounceBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Announce", 1, 0.82, 0.1)
    GameTooltip:AddLine("Left-click: send to raid/party (auto)", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: pick channel or preview locally", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
cdAnnounceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

local cdClearBtn = ns.MakeSmallButton(cooldownsContainer, "Clear All", 80, 24)
cdClearBtn:SetPoint("LEFT", cdAnnounceBtn, "RIGHT", 6, 0)
cdClearBtn:SetScript("OnClick", function()
    if ns.CooldownAssign.IsLocked() then
        ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
        return
    end
    ns.CooldownAssign.ClearAllCDs()
    if ns.RefreshCooldownsView then ns.RefreshCooldownsView() end
end)

local function RefreshCooldowns()
    if not ns.CooldownAssign then return end
    for _, cd in ipairs(ns.CooldownAssign.COOLDOWNS) do
        local r = cdRows[cd.key]
        if r then
            r.label:SetTextColor(ClassColorRGB(cd.class))
            local rec = ns.CooldownAssign.GetCD(cd.key) or {}
            local function classOf(name)
                if not name then return "UNKNOWN" end
                if ns.BuffScan and ns.BuffScan.scanResults and ns.BuffScan.scanResults[name] then
                    return ns.BuffScan.scanResults[name].class or "UNKNOWN"
                end
                return "UNKNOWN"
            end
            if rec.caster then
                r.casterDD:SetSelectedPlayer(rec.caster, classOf(rec.caster))
            else
                r.casterDD:SetSelectedPlayer(nil, nil)
            end
            if r.targetDD then
                if rec.target then
                    r.targetDD:SetSelectedPlayer(rec.target, classOf(rec.target))
                else
                    r.targetDD:SetSelectedPlayer(nil, nil)
                end
            end
        end
    end
end
ns.RefreshCooldownsView = RefreshCooldowns

----------------------------------------------------------------------
-- CC view: per-raid-icon crowd-control caster assignments
----------------------------------------------------------------------
local ccContainer = CreateFrame("Frame", nil, healContent)
ccContainer:SetPoint("TOPLEFT",     healContent, "TOPLEFT",     0,  -26)
ccContainer:SetPoint("BOTTOMRIGHT", healContent, "BOTTOMRIGHT", -20, 4)
ccContainer:Hide()

local ccScanBtn = ns.MakeSmallButton(ccContainer, "Scan Marks", 110, 22)
ccScanBtn:SetPoint("TOPLEFT", ccContainer, "TOPLEFT", 0, 0)
ccScanBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Scan Marked Mobs", 1, 0.82, 0)
    GameTooltip:AddLine("Checks raid targets for marked mobs and fills in their names.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
ccScanBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

local ccHint = ccContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ccHint:SetPoint("LEFT", ccScanBtn, "RIGHT", 8, 0)
ccHint:SetPoint("RIGHT", ccContainer, "RIGHT", -4, 0)
ccHint:SetJustifyH("LEFT")
ccHint:SetText("Mark mobs in-game with raid icons, then click Scan.")
ccHint:SetTextColor(0.6, 0.6, 0.6)

local CC_ROW_H = 28
local ccRows = {}  -- [iconIdx] = { row, detectedLabel, casterDD }

local function CreateCcRow(iconIdx)
    local row = CreateFrame("Frame", nil, ccContainer)
    row:SetHeight(CC_ROW_H)
    row:SetPoint("TOPLEFT", ccContainer, "TOPLEFT", 4,  -28 - (iconIdx - 1) * CC_ROW_H)
    row:SetPoint("RIGHT",   ccContainer, "RIGHT",   -4, 0)

    -- Icon texture
    local iconFrame = CreateFrame("Frame", nil, row)
    iconFrame:SetSize(24, 24)
    iconFrame:SetPoint("LEFT", row, "LEFT", 0, 0)
    iconFrame:EnableMouse(true)
    local tex = iconFrame:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    if ns.GetRaidIconTexture then
        tex:SetTexture(ns.GetRaidIconTexture(iconIdx))
    end
    iconFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local name = (ns.RAID_ICON_NAMES and ns.RAID_ICON_NAMES[iconIdx])
            or ("Icon " .. iconIdx)
        GameTooltip:AddLine(name, 1, 1, 1)
        GameTooltip:Show()
    end)
    iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Detected mob name label
    local detected = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    detected:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
    detected:SetWidth(160)
    detected:SetJustifyH("LEFT")
    detected:SetWordWrap(false)
    detected:SetText("|cFF666666(not detected)|r")

    -- CC caster dropdown
    local casterDD = ns.CreatePlayerDropdown(row, 160, function(playerName)
        ns.CooldownAssign.SetCC(iconIdx, playerName, nil)
    end)
    casterDD.respectLock = true
    casterDD:SetPoint("LEFT", detected, "RIGHT", 6, 0)

    ccRows[iconIdx] = {
        row      = row,
        detected = detected,
        casterDD = casterDD,
    }
    return row
end

for i = 1, 8 do CreateCcRow(i) end

-- Bottom buttons for CC view
local ccAnnounceBtn = ns.MakeSmallButton(ccContainer, "Announce", 110, 24)
ccAnnounceBtn:SetPoint("BOTTOMLEFT", ccContainer, "BOTTOMLEFT", 0, 4)
ccAnnounceBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
ccAnnounceBtn:SetScript("OnClick", function(self, button)
    local function GetLines() return ns.CooldownAssign.BuildCCLines() end
    if button == "RightButton" then
        ns.BossTemplates.ShowChannelMenu(GetLines)
    else
        ns.BossTemplates.SendLines(GetLines())
    end
end)
ccAnnounceBtn:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Announce", 1, 0.82, 0.1)
    GameTooltip:AddLine("Left-click: send to raid/party (auto)", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: pick channel or preview locally", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
ccAnnounceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

local ccClearBtn = ns.MakeSmallButton(ccContainer, "Clear All", 80, 24)
ccClearBtn:SetPoint("LEFT", ccAnnounceBtn, "RIGHT", 6, 0)
ccClearBtn:SetScript("OnClick", function()
    if ns.CooldownAssign.IsLocked() then
        ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
        return
    end
    ns.CooldownAssign.ClearAllCC()
    if ns.RefreshCcView then ns.RefreshCcView() end
end)

local function RefreshCc()
    if not ns.CooldownAssign then return end
    for i = 1, 8 do
        local r = ccRows[i]
        if r then
            local rec = ns.CooldownAssign.GetCC(i) or {}
            if rec.detectedName and rec.detectedName ~= "" then
                r.detected:SetText("|cFF88CCFF" .. rec.detectedName .. "|r")
            else
                r.detected:SetText("|cFF666666(not detected)|r")
            end
            if rec.caster then
                local class = "UNKNOWN"
                if ns.BuffScan and ns.BuffScan.scanResults
                    and ns.BuffScan.scanResults[rec.caster] then
                    class = ns.BuffScan.scanResults[rec.caster].class or "UNKNOWN"
                end
                r.casterDD:SetSelectedPlayer(rec.caster, class)
            else
                r.casterDD:SetSelectedPlayer(nil, nil)
            end
        end
    end
end
ns.RefreshCcView = RefreshCc

ccScanBtn:SetScript("OnClick", function()
    local count = ns.CooldownAssign.ScanAndUpdate() or 0
    RefreshCc()
    if count == 0 then
        ns.P("|cFF888888No marked mobs detected. Make sure someone targets the marked mobs.|r")
    end
end)

----------------------------------------------------------------------
-- Bottom buttons: Announce + Clear
----------------------------------------------------------------------
local announceBtn = ns.MakeSmallButton(healContent, "Announce", 110, 24)
announceBtn:SetPoint("BOTTOMLEFT", healContent, "BOTTOMLEFT", 0, 4)
announceBtn:SetScript("OnClick", function(self, button)
    local function GetLines() return ns.HealAssign.BuildAnnounceLines() end
    if button == "RightButton" then
        ns.BossTemplates.ShowChannelMenu(GetLines)
    else
        ns.BossTemplates.SendLines(GetLines())
    end
end)
announceBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Announce", 1, 0.82, 0.1)
    GameTooltip:AddLine("Left-click: send to raid/party (auto)", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Right-click: pick channel or preview locally", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)
announceBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local clearBtn = ns.MakeSmallButton(healContent, "Clear All", 80, 24)
clearBtn:SetPoint("LEFT", announceBtn, "RIGHT", 6, 0)
clearBtn:SetScript("OnClick", function()
    if ns.HealAssign.IsLocked() then
        ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
        return
    end
    ns.HealAssign.ClearAll()
    ns.HealAssign.ClearMisdirects()
    RefreshHealAssign()
end)

local autoBtn = ns.MakeSmallButton(healContent, "Auto-Assign", 120, 24)
autoBtn:SetPoint("LEFT", clearBtn, "RIGHT", 6, 0)
autoBtn:SetScript("OnClick", function()
    ns.HealAssign.AutoAssign()
end)
autoBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Auto-Assign Healers", 1, 0.82, 0.1)
    GameTooltip:AddLine(
        "Fills sensible defaults: paladins -> dedicated to main tanks, "
        .. "shaman/druid/priest -> cross-heal, Earth Shield on MT 1. "
        .. "Uses self-declared roles + class fallback + |cFFFFCC00/maintank|r marks.",
        0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
autoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

----------------------------------------------------------------------
-- View toggle implementation (now that every frame exists)
----------------------------------------------------------------------
local function StyleToggle(btn, active)
    -- Pills built via ns.MakePill expose :SetActive(true/false)
    if btn.SetActive then btn:SetActive(active) end
end

SetRolesViewMode = function(mode)
    viewMode = mode
    local showAssign    = (mode == "assignments")
    local showCooldowns = (mode == "cooldowns")
    local showCc        = (mode == "cc")
    local showRoster    = (mode == "roster")

    -- Assignments-view frames
    healHeader:SetShown(showAssign)
    scrollFrame:SetShown(showAssign)
    scrollInner:SetShown(showAssign)
    mdContainer:SetShown(showAssign)
    announceBtn:SetShown(showAssign)
    clearBtn:SetShown(showAssign)
    autoBtn:SetShown(showAssign)

    -- Other-view containers
    cooldownsContainer:SetShown(showCooldowns)
    ccContainer:SetShown(showCc)
    rosterContainer:SetShown(showRoster)

    -- Button styling
    StyleToggle(assignmentsBtn, showAssign)
    StyleToggle(cooldownsBtn,   showCooldowns)
    StyleToggle(ccBtn,          showCc)
    StyleToggle(rosterBtn,      showRoster)

    -- Hint text
    if showAssign then
        hint:SetText("Auto-detected by class. Set your own role in the Profile tab.")
    elseif showCooldowns then
        hint:SetText("Assign raid cooldowns. Caster + (target if applicable).")
    elseif showCc then
        hint:SetText("Crowd-control assignments per raid icon. Scan marks to auto-fill names.")
    else
        hint:SetText("Self-declared roles for everyone with RaidLead. Others show as Unknown.")
    end

    -- Refresh whatever is now visible
    if showAssign then
        RefreshHealAssign()
    elseif showCooldowns then
        RefreshCooldowns()
    elseif showCc then
        RefreshCc()
    elseif showRoster then
        RefreshRoster()
    end
end
ns.SetRolesViewMode = SetRolesViewMode

-- Initial state
SetRolesViewMode("assignments")

----------------------------------------------------------------------
-- Tab refresh: route to the currently visible view
----------------------------------------------------------------------
local function RefreshActiveRolesView()
    if viewMode == "roster" then
        RefreshRoster()
    elseif viewMode == "cooldowns" then
        RefreshCooldowns()
    elseif viewMode == "cc" then
        RefreshCc()
    else
        RefreshHealAssign()
    end
end

----------------------------------------------------------------------
-- Register the tab
----------------------------------------------------------------------
ns.RegisterTab("Roles", 25, healContent, RefreshActiveRolesView)
