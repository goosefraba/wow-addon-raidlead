----------------------------------------------------------------------
-- RaidLead - UI/BossTemplateWidgets/KaelthasAssignments.lua
-- Kael'thas Sunstrider assignment UI (3 phase tabs, one dropdown per role)
--   P1: 4 advisors
--   P2: 7 legendary weapons
--   P4-5: Kael call-out roles (MC, Gravity Lapse, Phoenix, Pyroblast)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BOSS_KEY = "kaelthas"

----------------------------------------------------------------------
-- Register the widget creation function
----------------------------------------------------------------------
ns.RegisterBossWidget(BOSS_KEY, function(parent)
    local bossData = ns.BossRegistry:Get(BOSS_KEY)
    if not bossData then return end

    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    -- State
    local activePhase = bossData.phases[1].key
    local dropdowns = {}  -- [phaseKey][slotKey] = { btn = dd, row = slotRow }

    --------------------------------------------------------------------
    -- Phase sub-tabs
    --------------------------------------------------------------------
    local phaseBtns = {}
    local phaseTabW = 110

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
        -- Show/hide slot rows for each phase
        for _, phase in ipairs(bossData.phases) do
            for _, slot in ipairs(phase.slots) do
                local dd = dropdowns[phase.key] and dropdowns[phase.key][slot.key]
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
    -- Slot rows (one dropdown per role, per phase)
    --   Layout: label on left, dropdown on right
    --   All phases stack their rows in the same vertical region;
    --   ShowPhase() toggles visibility.
    --------------------------------------------------------------------
    local ROWS_TOP   = -56
    local ROW_H      = 26
    local LABEL_W    = 170
    local DROPDOWN_W = 200

    for _, phase in ipairs(bossData.phases) do
        dropdowns[phase.key] = {}

        for sIdx, slot in ipairs(phase.slots) do
            local yOff = ROWS_TOP - (sIdx - 1) * ROW_H

            local row = CreateFrame("Frame", nil, widget)
            row:SetSize(LABEL_W + DROPDOWN_W + 12, ROW_H - 2)
            row:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, yOff)

            -- Label (with hover tooltip showing slot.tip)
            local lblBtn = CreateFrame("Frame", nil, row)
            lblBtn:SetSize(LABEL_W, ROW_H - 4)
            lblBtn:SetPoint("LEFT", row, "LEFT", 0, 0)
            lblBtn:EnableMouse(true)

            local lbl = lblBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("LEFT", lblBtn, "LEFT", 0, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetText("|cFFCCCCCC" .. slot.label .. ":|r")

            local tipText = slot.tip
            local slotLabel = slot.label
            lblBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(slotLabel, 1, 0.82, 0.1)
                if tipText then
                    GameTooltip:AddLine(tipText, 0.8, 0.8, 0.8, true)
                end
                GameTooltip:Show()
            end)
            lblBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            -- Player dropdown
            local phaseKey = phase.key
            local slotKey  = slot.key

            local dd = ns.CreatePlayerDropdown(row, DROPDOWN_W, function(playerName)
                ns.BossTemplates.SetAssignment(BOSS_KEY, slotKey, phaseKey, 1, playerName)
            end)
            dd.respectLock = true
            dd:SetPoint("LEFT", lblBtn, "RIGHT", 6, 0)

            -- Load saved assignment
            local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, phase.key, 1)
            if saved then
                local roster = ns.BossTemplates.GetPlayerRoster()
                local class = "UNKNOWN"
                for _, p in ipairs(roster) do
                    if p.name == saved then class = p.class; break end
                end
                dd:SetSelectedPlayer(saved, class)
            end

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
            ns.P("|cFFFF8800Locked.|r Click the lock icon (top-right) to enable editing.")
            return
        end
        ns.BossTemplates.ClearAssignments(BOSS_KEY)
        -- Reset all dropdowns across all phases
        for _, phase in ipairs(bossData.phases) do
            for _, slot in ipairs(phase.slots) do
                local dd = dropdowns[phase.key] and dropdowns[phase.key][slot.key]
                if dd and dd.btn then
                    dd.btn:SetSelectedPlayer(nil, nil)
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
                local name = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, phase.key, 1) or "-"
                lines[#lines + 1] = "  |cFFCCCCCC" .. slot.label .. ":|r " .. name
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
                local dd = dropdowns[phase.key] and dropdowns[phase.key][slot.key]
                if dd and dd.btn then
                    local saved = ns.BossTemplates.GetAssignment(BOSS_KEY, slot.key, phase.key, 1)
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
        ShowPhase(activePhase)
    end

    -- Init: show first phase
    ShowPhase(bossData.phases[1].key)

    return widget
end)
