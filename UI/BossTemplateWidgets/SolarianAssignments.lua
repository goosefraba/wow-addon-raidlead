----------------------------------------------------------------------
-- RaidLead — UI/BossTemplateWidgets/SolarianAssignments.lua
-- High Astromancer Solarian: phased-role assignments (P1 tanks, P2 portals)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY = "solarian"

----------------------------------------------------------------------
-- Register the widget creation function
----------------------------------------------------------------------
ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    -- State
    local activePhase = bossData.phases[1].key  -- "p1"
    local dropdowns = {}  -- [phaseKey][slotKey] = { btn = dd, row = slotRow }

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
        -- Show/hide rows for each phase
        for _, phase in ipairs(bossData.phases) do
            local phaseRows = dropdowns[phase.key]
            if phaseRows then
                for _, entry in pairs(phaseRows) do
                    if entry.row then
                        if phase.key == phaseKey then
                            entry.row:Show()
                        else
                            entry.row:Hide()
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
    -- Slot rows (one per slot per phase, label left + dropdown right)
    --------------------------------------------------------------------
    local ROW_H        = 24
    local ROW_GAP      = 4
    local ROW_TOP      = -56
    local LABEL_W      = 140
    local DROPDOWN_W   = 200

    local function LoadSavedInto(dd, slotKey, phaseKey)
        local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, slotKey, phaseKey, 1)
        if saved then
            local roster = ns.BossTemplates.GetPlayerRoster()
            local class = "UNKNOWN"
            for _, p in ipairs(roster) do
                if p.name == saved then class = p.class; break end
            end
            dd:SetSelectedPlayer(saved, class)
        else
            dd:SetSelectedPlayer(nil, nil)
        end
    end

    for _, phase in ipairs(bossData.phases) do
        dropdowns[phase.key] = {}

        for slotIdx, slot in ipairs(phase.slots) do
            local yOff = ROW_TOP - (slotIdx - 1) * (ROW_H + ROW_GAP)

            local row = CreateFrame("Frame", nil, widget)
            row:SetSize(LABEL_W + DROPDOWN_W + 10, ROW_H)
            row:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, yOff)

            -- Label (hover tooltip from slot.tip)
            local lblBtn = CreateFrame("Frame", nil, row)
            lblBtn:SetSize(LABEL_W, ROW_H)
            lblBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
            lblBtn:EnableMouse(true)

            local lbl = lblBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("LEFT", lblBtn, "LEFT", 0, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetText("|cFFCCCCCC" .. slot.label .. "|r")

            local slotTip = slot.tip
            local slotLabel = slot.label
            lblBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(slotLabel, 1, 0.82, 0.1)
                if slotTip then
                    GameTooltip:AddLine(slotTip, 0.8, 0.8, 0.8, true)
                end
                GameTooltip:Show()
            end)
            lblBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Dropdown
            local slotKey = slot.key
            local phaseKey = phase.key

            local dd = ns.CreatePlayerDropdown(row, DROPDOWN_W, function(playerName)
                ns.BossTemplates.SetAssignment(BOSS_KEY, slotKey, phaseKey, 1, playerName)
            end)
            dd.respectLock = true
            dd:SetPoint("LEFT", lblBtn, "RIGHT", 6, 0)

            LoadSavedInto(dd, slot.key, phase.key)

            dropdowns[phase.key][slot.key] = { btn = dd, row = row }
        end
    end

    --------------------------------------------------------------------
    -- Bottom buttons: Announce + Clear
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
            ns.LockedNotice()
            return
        end
        ns.BossTemplates.ClearAssignments(BOSS_KEY)
        for _, phase in ipairs(bossData.phases) do
            for _, slot in ipairs(phase.slots) do
                local entry = dropdowns[phase.key] and dropdowns[phase.key][slot.key]
                if entry and entry.btn then
                    entry.btn:SetSelectedPlayer(nil, nil)
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
            lines[#lines + 1] = "|cFFFFFFFF" .. phase.label .. "|r"
            for _, slot in ipairs(phase.slots) do
                local assigned = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, phase.key, 1) or "-"
                lines[#lines + 1] = "   |cFFCCCCCC" .. slot.label .. ":|r " .. assigned
            end
        end
        return table.concat(lines, "\n")
    end

    --------------------------------------------------------------------
    -- Refresh function
    --------------------------------------------------------------------
    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        for _, phase in ipairs(bossData.phases) do
            for _, slot in ipairs(phase.slots) do
                local entry = dropdowns[phase.key] and dropdowns[phase.key][slot.key]
                if entry and entry.btn then
                    local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, phase.key, 1)
                    if saved then
                        local class = "UNKNOWN"
                        for _, p in ipairs(roster) do
                            if p.name == saved then class = p.class; break end
                        end
                        entry.btn:SetSelectedPlayer(saved, class)
                    else
                        entry.btn:SetSelectedPlayer(nil, nil)
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
