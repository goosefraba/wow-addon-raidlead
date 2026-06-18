----------------------------------------------------------------------
-- RaidLead - UI/BossTemplateFrame.lua
-- Boss tab container - instance selector + boss-specific widgets
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local f = ns.mainFrame

----------------------------------------------------------------------
-- Boss tab content frame
----------------------------------------------------------------------
local bossContent = CreateFrame("Frame", nil, f)
bossContent:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -68)
bossContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 42)
bossContent:Hide()

----------------------------------------------------------------------
-- Instance + boss selector row
----------------------------------------------------------------------
local selector = CreateFrame("Frame", nil, bossContent)
selector:SetHeight(24)
selector:SetPoint("TOPLEFT", bossContent, "TOPLEFT", 0, 0)
selector:SetPoint("TOPRIGHT", bossContent, "TOPRIGHT", 0, 0)

local instanceLabel = selector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
instanceLabel:SetPoint("LEFT", selector, "LEFT", 4, 0)
instanceLabel:SetText("|cFFFFCC00Raid:|r")

local instanceDropBtn = ns.MakeSmallButton(selector, "(Select Raid)", 160, 22)
instanceDropBtn:SetPoint("LEFT", instanceLabel, "RIGHT", 8, 0)

local bossLabel = selector:CreateFontString(nil, "OVERLAY", "GameFontNormal")
bossLabel:SetPoint("LEFT", instanceDropBtn, "RIGHT", 12, 0)
bossLabel:SetText("|cFFFFCC00Boss:|r")

local bossDropBtn = ns.MakeSmallButton(selector, "(Select Boss)", 190, 22)
bossDropBtn:SetPoint("LEFT", bossLabel, "RIGHT", 8, 0)

-- Read-only "boss mechanics" info button. Opens a scrollable explainer for
-- the active boss (populated from bossData.mechanics).
local infoBtn = CreateFrame("Button", nil, selector)
infoBtn:SetSize(22, 22)
infoBtn:SetPoint("LEFT", bossDropBtn, "RIGHT", 8, 0)
infoBtn:SetNormalTexture("Interface\\FriendsFrame\\InformationIcon")
infoBtn:SetHighlightTexture("Interface\\FriendsFrame\\InformationIcon")
infoBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Boss mechanics", 1, 0.82, 0.1)
    GameTooltip:AddLine("Click to read how this fight works.", 0.8, 0.8, 0.8, true)
    GameTooltip:Show()
end)
infoBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
infoBtn:SetScript("OnClick", function()
    local key = ns.GetActiveBossKey and ns.GetActiveBossKey()
    if key and ns.ShowBossInfo then
        ns.ShowBossInfo(ns.BossRegistry:Get(key))
    end
end)
infoBtn:Hide()   -- shown once a boss with mechanics is selected

----------------------------------------------------------------------
-- Widget container (below selector row)
----------------------------------------------------------------------
local widgetContainer = CreateFrame("Frame", nil, bossContent)
widgetContainer:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -4)
widgetContainer:SetPoint("BOTTOMRIGHT", bossContent, "BOTTOMRIGHT", 0, 0)
ns.bossWidgetContainer = widgetContainer

----------------------------------------------------------------------
-- Active state
----------------------------------------------------------------------
local activeInstance = nil
local activeBossKey = nil
local activeWidget  = nil

ns.bossWidgets = {}

function ns.RegisterBossWidget(bossKey, createFunc)
    ns.bossWidgets[bossKey] = createFunc
end

----------------------------------------------------------------------
-- Fallback widgets for bosses without a dedicated UI:
--   * BuildGenericSlotsWidget - any boss with a `slots` table (role rows
--     + Announce/Clear), so simple assignment fights need no widget file.
--   * BuildPlaceholderWidget   - mechanics-only bosses: a friendly note
--     pointing at the info button.
----------------------------------------------------------------------
local function BuildGenericSlotsWidget(bossKey, parent)
    local bossData = ns.BossRegistry:Get(bossKey)
    if not bossData or not bossData.slots then return nil end

    local PHASE_KEY = "default"
    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()
    local dropdowns = {}

    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -2)
        notes:SetPoint("RIGHT", widget, "RIGHT", -4, 0)
        notes:SetJustifyH("LEFT")
        notes:SetText(bossData.notes)
        notes:SetTextColor(0.6, 0.6, 0.6)
    end

    local sectionHeader = ns.MakeSectionHeader(widget, "Assignments")
    sectionHeader:SetPoint("TOPLEFT", widget, "TOPLEFT", 0, -34)
    sectionHeader:SetPoint("RIGHT", widget, "RIGHT", -4, 0)

    local LABEL_W, PLAYER_W, PAD = 170, 180, 6

    local headerRow = CreateFrame("Frame", nil, widget)
    headerRow:SetHeight(16)
    headerRow:SetPoint("TOPLEFT", sectionHeader, "BOTTOMLEFT", 0, -4)
    headerRow:SetPoint("RIGHT", widget, "RIGHT", 0, 0)
    local function ColHeader(text, xOff, width)
        local fs = headerRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", headerRow, "TOPLEFT", xOff, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        fs:SetTextColor(0.85, 0.85, 0.85)
    end
    ColHeader("Role",   0,             LABEL_W)
    ColHeader("Player", LABEL_W + PAD, PLAYER_W)

    local ROW_H = 28
    for sIdx, slot in ipairs(bossData.slots) do
        local yOff = -22 - (sIdx - 1) * ROW_H
        local row = CreateFrame("Frame", nil, widget)
        row:SetSize(620, ROW_H - 2)
        row:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, yOff)

        local labelFrame = CreateFrame("Frame", nil, row)
        labelFrame:SetSize(LABEL_W, ROW_H - 4)
        labelFrame:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
        labelFrame:EnableMouse(true)
        local label = labelFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", labelFrame, "LEFT", 0, 0)
        label:SetWidth(LABEL_W)
        label:SetJustifyH("LEFT")
        label:SetText(slot.label)

        local slotTip, slotLabel = slot.tip, slot.label
        labelFrame:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(slotLabel, 1, 1, 1)
            if slotTip then GameTooltip:AddLine(slotTip, 0.8, 0.8, 0.8, true) end
            GameTooltip:Show()
        end)
        labelFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local slotKey = slot.key
        local dd = ns.CreatePlayerDropdown(row, PLAYER_W, function(playerName)
            ns.BossTemplates.SetAssignment(bossKey, slotKey, PHASE_KEY, 1, playerName)
        end)
        dd.respectLock = true
        dd:SetPoint("TOPLEFT", row, "TOPLEFT", LABEL_W + PAD, -2)
        dropdowns[slot.key] = dd
    end

    local function BuildAnnounceLines()
        local title = bossData.announceTitle or (bossData.name .. " - Assignments")
        local lines = { "== " .. title .. " ==" }
        for _, slot in ipairs(bossData.slots) do
            local who = ns.BossTemplates.GetAssignment(bossKey, slot.key, PHASE_KEY, 1) or "?"
            lines[#lines + 1] = slot.label .. ": " .. who
        end
        return lines
    end

    function widget.BuildCompactText()
        local lines = { "|cFFFFCC00" .. bossData.name .. "|r" }
        for _, slot in ipairs(bossData.slots) do
            local who = ns.BossTemplates.GetAssignment(bossKey, slot.key, PHASE_KEY, 1) or "-"
            lines[#lines + 1] = slot.label .. ": " .. who
        end
        return table.concat(lines, "\n")
    end

    local announceBtn = ns.MakeSmallButton(widget, "Announce", 110, 24)
    announceBtn:SetPoint("BOTTOMLEFT", widget, "BOTTOMLEFT", 0, 4)
    announceBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            ns.BossTemplates.ShowChannelMenu(BuildAnnounceLines)
        else
            ns.BossTemplates.SendLines(BuildAnnounceLines())
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
        if ns.BossTemplates.IsLocked() then ns.LockedNotice(); return end
        ns.BossTemplates.ClearAssignments(bossKey)
        for _, slot in ipairs(bossData.slots) do
            if dropdowns[slot.key] then dropdowns[slot.key]:SetSelectedPlayer(nil, nil) end
        end
    end)

    function widget.Refresh()
        local roster = ns.BossTemplates.GetPlayerRoster()
        for _, slot in ipairs(bossData.slots) do
            local dd = dropdowns[slot.key]
            if dd then
                local saved = ns.BossTemplates.GetAssignment(bossKey, slot.key, PHASE_KEY, 1)
                if saved then
                    local class = "UNKNOWN"
                    for _, p in ipairs(roster) do
                        if p.name == saved then class = p.class; break end
                    end
                    dd:SetSelectedPlayer(saved, class)
                else
                    dd:SetSelectedPlayer(nil, nil)
                end
            end
        end
    end

    widget.Refresh()
    return widget
end

local function BuildPlaceholderWidget(bossData, parent)
    local widget = CreateFrame("Frame", nil, parent)
    widget:SetAllPoints()

    if bossData.notes then
        local notes = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        notes:SetPoint("TOPLEFT", widget, "TOPLEFT", 4, -2)
        notes:SetPoint("RIGHT", widget, "RIGHT", -4, 0)
        notes:SetJustifyH("LEFT")
        notes:SetText(bossData.notes)
        notes:SetTextColor(0.6, 0.6, 0.6)
    end

    local msg = widget:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    msg:SetPoint("CENTER", widget, "CENTER", 0, 12)
    msg:SetWidth(400)
    msg:SetJustifyH("CENTER")
    msg:SetText("|cFF999999No raid assignments to set for this fight.|r")

    local hint = widget:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", msg, "BOTTOM", 0, -10)
    hint:SetWidth(400)
    hint:SetJustifyH("CENTER")
    hint:SetTextColor(0.6, 0.6, 0.6)
    if bossData.mechanics or bossData.tactics then
        hint:SetText("Use the |cFFFFCC00info button|r at the top to read the mechanics and tactics.")
    end

    function widget.BuildCompactText()
        return "|cFFFFCC00" .. (bossData.name or "Boss") .. "|r\n|cFF888888(no assignments)|r"
    end
    function widget.Refresh() end
    return widget
end

local ShowBossWidget

local function ShowInstance(instanceName, keepBoss)
    activeInstance = instanceName
    instanceDropBtn:SetText(instanceName or "(Select Raid)")

    if not keepBoss then
        local firstBoss = instanceName and ns.BossRegistry:GetFirstBossForInstance(instanceName)
        ShowBossWidget(firstBoss)
    end
end

ShowBossWidget = function(bossKey)
    if activeWidget then activeWidget:Hide() end
    activeWidget = nil
    activeBossKey = bossKey

    if not bossKey then
        bossDropBtn:SetText("(Select Boss)")
        infoBtn:Hide()
        if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
        return
    end

    local bossData = ns.BossRegistry:Get(bossKey)
    if not bossData then return end

    -- Show the mechanics info button when this boss has mechanics/tactics.
    infoBtn:SetShown(bossData.mechanics ~= nil or bossData.tactics ~= nil)

    if bossData.instance and bossData.instance ~= activeInstance then
        ShowInstance(bossData.instance, true)
    end

    bossDropBtn:SetText(bossData.name)

    if not widgetContainer.widgets then widgetContainer.widgets = {} end
    if not widgetContainer.widgets[bossKey] then
        local createFunc = ns.bossWidgets[bossKey]
        if createFunc then
            widgetContainer.widgets[bossKey] = createFunc(widgetContainer)
        elseif bossData.slots then
            -- Simple assignment fight: generic role-slot widget, no file needed.
            widgetContainer.widgets[bossKey] = BuildGenericSlotsWidget(bossKey, widgetContainer)
        else
            -- Mechanics-only boss: friendly placeholder page.
            widgetContainer.widgets[bossKey] = BuildPlaceholderWidget(bossData, widgetContainer)
        end
    end
    activeWidget = widgetContainer.widgets[bossKey]
    if activeWidget then
        activeWidget:Show()
        if activeWidget.Refresh then activeWidget.Refresh() end
    end

    if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
end

function ns.GetActiveBossKey() return activeBossKey end
function ns.GetActiveBossWidget() return activeWidget end
function ns.GetActiveBossInstance() return activeInstance end

----------------------------------------------------------------------
-- Menus
----------------------------------------------------------------------
instanceDropBtn:SetScript("OnClick", function(self)
    local _, orderedInstances = ns.BossRegistry:GetInstances()
    local menu = {
        { text = "Select Raid Instance", isTitle = true },
    }
    for _, instanceName in ipairs(orderedInstances) do
        local name = instanceName
        menu[#menu + 1] = {
            text = name,
            func = function() ShowInstance(name, false) end,
        }
    end
    ns.ShowContextMenu(menu, "cursor", 0, 0)
end)

bossDropBtn:SetScript("OnClick", function(self)
    if not activeInstance then
        activeInstance = ns.BossRegistry:GetFirstInstance()
        if activeInstance then instanceDropBtn:SetText(activeInstance) end
    end

    local menu = {
        { text = activeInstance or "Select Boss", isTitle = true },
    }
    local bosses = activeInstance and ns.BossRegistry:GetBossesForInstance(activeInstance) or {}
    for _, bossKey in ipairs(bosses) do
        local bossData = ns.BossRegistry:Get(bossKey)
        if bossData then
            local key = bossKey
            menu[#menu + 1] = {
                text = bossData.name,
                func = function() ShowBossWidget(key) end,
            }
        end
    end
    ns.ShowContextMenu(menu, "cursor", 0, 0)
end)

----------------------------------------------------------------------
-- Refresh function for the tab
----------------------------------------------------------------------
local function RefreshBossTab()
    if not activeInstance then
        local firstInstance = ns.BossRegistry:GetFirstInstance()
        if firstInstance then
            ShowInstance(firstInstance, false)
        end
    elseif not activeBossKey then
        local firstBoss = ns.BossRegistry:GetFirstBossForInstance(activeInstance)
        if firstBoss then ShowBossWidget(firstBoss) end
    elseif activeWidget and activeWidget.Refresh then
        activeWidget.Refresh()
    end
end

----------------------------------------------------------------------
-- Boss mechanics info popup (read-only, scrollable)
----------------------------------------------------------------------
local infoPopup

-- Flatten a boss's mechanics table into one rich, wrapped string.
--   mechanics = { summary = "...", sections = { { title=, body= }, ... } }
local function MechanicsToText(m)
    local parts = {}
    if m.summary and m.summary ~= "" then
        parts[#parts + 1] = "|cFFFFFFFF" .. m.summary .. "|r"
    end
    for _, sec in ipairs(m.sections or {}) do
        local block = "|cFFFFCC00" .. (sec.title or "") .. "|r"
        if sec.body and sec.body ~= "" then
            block = block .. "\n|cFFCCCCCC" .. sec.body .. "|r"
        end
        parts[#parts + 1] = block
    end
    return table.concat(parts, "\n\n")
end

-- Normalize a boss's info into a list of tactics. Supports:
--   bossData.tactics  = { { name=, summary=, sections= }, ... }   (multi)
--   bossData.mechanics = { summary=, sections= }                  (single)
-- so we're ready to show several tactics per boss with a selector later.
local function GetTactics(bossData)
    if bossData.tactics and #bossData.tactics > 0 then
        return bossData.tactics
    elseif bossData.mechanics then
        local m = bossData.mechanics
        return { { name = m.name or "Standard", summary = m.summary, sections = m.sections } }
    end
    return {}
end

local function BuildInfoPopup()
    if infoPopup then return infoPopup end

    local d = CreateFrame("Frame", "RaidLeadBossInfo", UIParent)
    d:SetSize(460, 480)
    d:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    d:SetFrameStrata("FULLSCREEN_DIALOG")
    d:SetFrameLevel(220)
    d:EnableMouse(true)
    d:SetMovable(true)
    d:RegisterForDrag("LeftButton")
    d:SetScript("OnDragStart", function(s) s:StartMoving() end)
    d:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    d:Hide()

    ns.ApplyBackdrop(d, ns.DIALOG_BACKDROP)
    tinsert(UISpecialFrames, "RaidLeadBossInfo")

    local closeBtn = CreateFrame("Button", nil, d, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", d, "TOPRIGHT", -2, -2)

    d.title = d:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    d.title:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -14)
    d.title:SetPoint("RIGHT",   d, "RIGHT",  -36, 0)
    d.title:SetJustifyH("LEFT")

    -- Tactic selector row (only shown when a boss has more than one tactic).
    d.tabRow = CreateFrame("Frame", nil, d)
    d.tabRow:SetPoint("TOPLEFT", d, "TOPLEFT", 16, -40)
    d.tabRow:SetPoint("RIGHT",   d, "RIGHT",  -16, 0)
    d.tabRow:SetHeight(22)
    d.tabPills = {}

    local scroll = CreateFrame("ScrollFrame", "RaidLeadBossInfoScroll", d, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -32, 14)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(404, 10)
    scroll:SetScrollChild(content)
    d.scroll  = scroll
    d.content = content

    d.text = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    d.text:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    d.text:SetWidth(404)
    d.text:SetJustifyH("LEFT")
    d.text:SetJustifyV("TOP")
    d.text:SetSpacing(3)

    function d.RenderTactic(idx)
        local t = d.tactics and d.tactics[idx]
        if not t then return end
        d.activeIdx = idx
        for i, pill in ipairs(d.tabPills) do
            if pill.SetActive then pill:SetActive(i == idx) end
        end
        d.text:SetText(MechanicsToText(t))
        d.content:SetHeight(math.max(10, d.text:GetStringHeight() + 8))
        d.scroll:SetVerticalScroll(0)
    end

    infoPopup = d
    return d
end

function ns.ShowBossInfo(bossData)
    if not bossData then return end
    local d = BuildInfoPopup()

    d.title:SetText("|cFFFFCC00" .. (bossData.name or "Boss") .. "|r |cFF888888Mechanics|r")
    d.tactics = GetTactics(bossData)

    for _, p in ipairs(d.tabPills) do p:Hide() end

    local multi = (#d.tactics > 1)
    if multi then
        d.tabRow:Show()
        local x = 0
        for i, t in ipairs(d.tactics) do
            local pill = d.tabPills[i]
            if not pill then
                pill = ns.MakePill(d.tabRow, "")
                d.tabPills[i] = pill
            end
            pill.text:SetText(t.name or ("Tactic " .. i))
            pill:SetWidth(math.max(70, pill.text:GetStringWidth() + 20))
            pill:ClearAllPoints()
            pill:SetPoint("LEFT", d.tabRow, "LEFT", x, 0)
            pill:SetScript("OnClick", function() d.RenderTactic(i) end)
            pill:Show()
            x = x + pill:GetWidth() + 6
        end
        d.scroll:ClearAllPoints()
        d.scroll:SetPoint("TOPLEFT",     d, "TOPLEFT",     16, -68)
        d.scroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -32, 14)
    else
        d.tabRow:Hide()
        d.scroll:ClearAllPoints()
        d.scroll:SetPoint("TOPLEFT",     d, "TOPLEFT",     16, -42)
        d.scroll:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", -32, 14)
    end

    if #d.tactics == 0 then
        d.text:SetText("|cFF888888No mechanics notes for this boss yet.|r")
        d.content:SetHeight(40)
        d.scroll:SetVerticalScroll(0)
    else
        d.RenderTactic(1)
    end
    d:Show()
end

----------------------------------------------------------------------
-- Register the Boss tab
----------------------------------------------------------------------
ns.RegisterTab("Boss", 20, bossContent, RefreshBossTab)
