----------------------------------------------------------------------
-- RaidLead — UI/BossTemplateWidgets/NetherspitePortals.lua
-- Netherspite portal assignment UI (3 portals x 2 phases x 2 slots)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY = "netherspite"

----------------------------------------------------------------------
-- Register the widget creation function
----------------------------------------------------------------------
ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    -- State
    local activePhase = bossData.phases[1].key  -- "phase1"
    local dropdowns = {}  -- [portalKey][phaseKey][slotIdx] = dropdown button

    --------------------------------------------------------------------
    -- Phase sub-tabs
    --------------------------------------------------------------------
    local phaseBtns = {}
    local phaseTabW = 80

    local function ShowPhase(phaseKey)
        activePhase = phaseKey
        -- Update tab styling
        for _, p in ipairs(bossData.phases) do
            local btn = phaseBtns[p.key]
            if btn then
                if p.key == phaseKey then
                    btn.label:SetTextColor(1, 0.82, 0.1)
                    btn.underline:Show()
                else
                    btn.label:SetTextColor(0.6, 0.6, 0.6)
                    btn.underline:Hide()
                end
            end
        end
        -- Show/hide dropdown rows for each phase
        for _, portal in ipairs(bossData.portals) do
            for _, phase in ipairs(bossData.phases) do
                for slotIdx = 1, #bossData.slotsPerPortal do
                    local dd = dropdowns[portal.key] and dropdowns[portal.key][phase.key] and dropdowns[portal.key][phase.key][slotIdx]
                    if dd then
                        if phase.key == phaseKey then
                            dd.row:Show()
                        else
                            dd.row:Hide()
                        end
                    end
                end
            end
        end
    end

    for i, phase in ipairs(bossData.phases) do
        local btn = CreateFrame("Button", nil, widget)
        btn:SetSize(phaseTabW, 18)
        btn:SetPoint("TOPLEFT", widget, "TOPLEFT", (i - 1) * (phaseTabW + 8), 0)

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("CENTER", btn, "CENTER", 0, 0)
        lbl:SetText(phase.label)
        btn.label = lbl

        local ul = btn:CreateTexture(nil, "ARTWORK")
        ul:SetHeight(2)
        ul:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 4, 0)
        ul:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, 0)
        ns.SetColorTex(ul, 0.9, 0.7, 0.2, 1)
        ul:Hide()
        btn.underline = ul

        local pk = phase.key
        btn:SetScript("OnClick", function() ShowPhase(pk) end)
        phaseBtns[phase.key] = btn
    end

    --------------------------------------------------------------------
    -- Notes text
    --------------------------------------------------------------------
    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -22)
        notes:SetPoint("RIGHT", widget, "RIGHT", -4, 0)
        notes:SetJustifyH("LEFT")
        notes:SetText("|cFF888888" .. bossData.notes .. "|r")
    end

    --------------------------------------------------------------------
    -- Portal columns
    --------------------------------------------------------------------
    local COLUMN_W = 165
    local COLUMN_PAD = 8
    local COLUMN_TOP = -42

    for pIdx, portal in ipairs(bossData.portals) do
        local col = CreateFrame("Frame", nil, widget)
        local xOff = (pIdx - 1) * (COLUMN_W + COLUMN_PAD)
        col:SetSize(COLUMN_W, 180)
        col:SetPoint("TOPLEFT", widget, "TOPLEFT", xOff, COLUMN_TOP)

        -- Colored header strip
        local headerBg = col:CreateTexture(nil, "BACKGROUND")
        headerBg:SetHeight(22)
        headerBg:SetPoint("TOPLEFT", col, "TOPLEFT", 0, 0)
        headerBg:SetPoint("TOPRIGHT", col, "TOPRIGHT", 0, 0)
        ns.SetColorTex(headerBg, portal.color[1], portal.color[2], portal.color[3], 0.25)

        -- Portal name
        local portalLabel = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        portalLabel:SetPoint("TOPLEFT", col, "TOPLEFT", 6, -4)
        local cr, cg, cb = portal.color[1], portal.color[2], portal.color[3]
        portalLabel:SetText(string.format("|cFF%02X%02X%02X%s|r",
            math.floor(cr * 255), math.floor(cg * 255), math.floor(cb * 255),
            portal.label))

        -- Full name + tip as tooltip (hover the header)
        col:EnableMouse(true)
        col:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(portal.label .. " - " .. (portal.fullName or ""), cr, cg, cb)
            GameTooltip:AddLine(portal.tip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        col:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- Slot dropdowns (for each phase)
        dropdowns[portal.key] = {}

        for _, phase in ipairs(bossData.phases) do
            dropdowns[portal.key][phase.key] = {}

            for slotIdx, slotLabel in ipairs(bossData.slotsPerPortal) do
                local yOff = -28 - (slotIdx - 1) * 46

                local slotRow = CreateFrame("Frame", nil, col)
                slotRow:SetSize(COLUMN_W, 42)
                slotRow:SetPoint("TOPLEFT", col, "TOPLEFT", 0, yOff)

                -- Slot label
                local slotLbl = slotRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                slotLbl:SetPoint("TOPLEFT", slotRow, "TOPLEFT", 6, -2)
                slotLbl:SetText("|cFFCCCCCC" .. slotLabel .. ":|r")

                -- Player dropdown
                local portalKey = portal.key
                local phaseKey = phase.key
                local sIdx = slotIdx

                local dd = ns.CreatePlayerDropdown(slotRow, COLUMN_W - 8, function(playerName)
                    ns.BossTemplates.SetAssignment(BOSS_KEY, portalKey, phaseKey, sIdx, playerName)
                end)
                dd.respectLock = true
                dd:SetPoint("TOPLEFT", slotLbl, "BOTTOMLEFT", -4, -1)

                -- Load saved assignment
                local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, portal.key, phase.key, slotIdx)
                if saved then
                    local roster = ns.BossTemplates.GetPlayerRoster()
                    local class = "UNKNOWN"
                    for _, p in ipairs(roster) do
                        if p.name == saved then class = p.class; break end
                    end
                    dd:SetSelectedPlayer(saved, class)
                end

                dropdowns[portal.key][phase.key][slotIdx] = { btn = dd, row = slotRow }
            end
        end
    end

    --------------------------------------------------------------------
    -- Bottom buttons: Announce + Debug + Clear
    --------------------------------------------------------------------
    local function GetLines() return ns.BossTemplates.BuildAnnounceLines(BOSS_KEY) end

    local announceBtn = ns.MakeSmallButton(widget, "Announce", 110, 24)
    announceBtn:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 0, 4)
    announceBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.BossTemplates.ShowChannelMenu(GetLines)
        else
            ns.BossTemplates.SendLines(GetLines())
        end
    end)
    announceBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Announce", 1, 0.82, 0.1)
        GameTooltip:AddLine("Left-click: send to raid/party (auto)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: pick channel or preview locally", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    announceBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local clearBtn = ns.MakeSmallButton(widget, "Clear All", 80, 24)
    clearBtn:SetPoint("LEFT", announceBtn, "RIGHT", 6, 0)
    clearBtn:SetScript("OnClick", function()
        if ns.BossTemplates.IsLocked() then
            ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
            return
        end
        ns.BossTemplates.ClearAssignments(BOSS_KEY)
        -- Reset all dropdowns
        for _, portal in ipairs(bossData.portals) do
            for _, phase in ipairs(bossData.phases) do
                for slotIdx = 1, #bossData.slotsPerPortal do
                    local dd = dropdowns[portal.key][phase.key][slotIdx]
                    if dd and dd.btn then
                        dd.btn:SetSelectedPlayer(nil, nil)
                    end
                end
            end
        end
    end)

    --------------------------------------------------------------------
    -- Compact view text (used in compact mode)
    --------------------------------------------------------------------
    function widget.BuildCompactText()
        local lines = {}
        lines[#lines + 1] = "|cFFFFCC00" .. bossData.name .. "|r"
        for _, phase in ipairs(bossData.phases) do
            local row = "|cFFFFFFFF" .. phase.label .. "|r"
            for _, portal in ipairs(bossData.portals) do
                local primary = ns.BossTemplates.GetAssignment(BOSS_KEY, portal.key, phase.key, 1) or "-"
                local backup  = ns.BossTemplates.GetAssignment(BOSS_KEY, portal.key, phase.key, 2)
                local cR, cG, cB = portal.color[1], portal.color[2], portal.color[3]
                local colorCode = string.format("|cFF%02X%02X%02X",
                    math.floor(cR * 255), math.floor(cG * 255), math.floor(cB * 255))
                local entry = primary
                if backup then
                    entry = entry .. " |cFF888888(" .. backup .. ")|r"
                end
                row = row .. "   " .. colorCode .. portal.label .. "|r " .. entry
            end
            lines[#lines + 1] = row
        end
        return table.concat(lines, "\n")
    end

    --------------------------------------------------------------------
    -- Refresh function
    --------------------------------------------------------------------
    function widget.Refresh()
        -- Reload saved assignments into dropdowns
        local roster = ns.BossTemplates.GetPlayerRoster()
        for _, portal in ipairs(bossData.portals) do
            for _, phase in ipairs(bossData.phases) do
                for slotIdx = 1, #bossData.slotsPerPortal do
                    local dd = dropdowns[portal.key][phase.key][slotIdx]
                    if dd and dd.btn then
                        local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, portal.key, phase.key, slotIdx)
                        if saved then
                            local class = "UNKNOWN"
                            for _, p in ipairs(roster) do
                                if p.name == saved then class = p.class; break end
                            end
                            dd.btn:SetSelectedPlayer(saved, class)
                        else
                            dd.btn:SetSelectedPlayer(nil, nil)
                        end
                    end
                end
            end
        end
        ShowPhase(activePhase)
    end

    -- Init: show phase 1
    ShowPhase(bossData.phases[1].key)

    return widget
end)
