----------------------------------------------------------------------
-- RaidLead — UI/BuffScanFrame.lua
-- Grid tab + Missing tab (ported from RaidSpy)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BD = RaidSpyBuffs
local BuffScan = ns.BuffScan

----------------------------------------------------------------------
-- Grid tab content frame
----------------------------------------------------------------------
local f = ns.mainFrame

local gridContent = CreateFrame("Frame", nil, f)
gridContent:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -68)
gridContent:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 42)
gridContent:Hide()

----------------------------------------------------------------------
-- Sub-view toggle: Grid (matrix) vs Missing (summary). Both live under
-- the single "Grid" tab.
----------------------------------------------------------------------
local SetBuffSubView  -- forward decl
local buffSubMode = "grid"

local gridBtn = ns.MakePill(gridContent, "Grid")
gridBtn:SetWidth(64)
gridBtn:SetPoint("TOPLEFT", gridContent, "TOPLEFT", 0, 0)
gridBtn:SetScript("OnClick", function() if SetBuffSubView then SetBuffSubView("grid") end end)

local missingBtn = ns.MakePill(gridContent, "Missing")
missingBtn:SetWidth(72)
missingBtn:SetPoint("LEFT", gridBtn, "RIGHT", 4, 0)
missingBtn:SetScript("OnClick", function() if SetBuffSubView then SetBuffSubView("missing") end end)

----------------------------------------------------------------------
-- Missing sub-view content (parented under the Grid tab, below the toggle)
----------------------------------------------------------------------
local missingContent = CreateFrame("Frame", nil, gridContent)
missingContent:SetPoint("TOPLEFT", gridContent, "TOPLEFT", 0, -24)
missingContent:SetPoint("BOTTOMRIGHT", gridContent, "BOTTOMRIGHT", 0, 0)
missingContent:Hide()

----------------------------------------------------------------------
-- Grid constants
----------------------------------------------------------------------
local GRID_ROW_HEIGHT = 20
local COL_NAME_W  = 130
local COL_FLASK_X = COL_NAME_W + 4
local COL_FLASK_W = 70
local COL_FOOD_X  = COL_FLASK_X + COL_FLASK_W + 4
local COL_FOOD_W  = 50
local COL_RAID_X  = COL_FOOD_X  + COL_FOOD_W  + 4

----------------------------------------------------------------------
-- Grid header bar
----------------------------------------------------------------------
local headerBar = CreateFrame("Frame", nil, gridContent)
headerBar:SetHeight(18)
headerBar:SetPoint("TOPLEFT", gridContent, "TOPLEFT", 0, -24)
headerBar:SetPoint("TOPRIGHT", gridContent, "TOPRIGHT", 0, -24)

ns.MakeHeader(headerBar, "Name",          4,           COL_NAME_W)
ns.MakeHeader(headerBar, "Flask/Elixir",  COL_FLASK_X, COL_FLASK_W)
ns.MakeHeader(headerBar, "Food",          COL_FOOD_X,  COL_FOOD_W)

-- Raid buff header icons
do
    local HDR_ICON = 14
    local HDR_PAD  = 2
    for idx, fk in ipairs(ns.RAID_BUFF_ORDER) do
        local family = BD.raidBuffs[fk]
        if family then
            local hIcon = CreateFrame("Frame", nil, headerBar)
            hIcon:SetSize(HDR_ICON, HDR_ICON)
            hIcon:SetPoint("TOPLEFT", headerBar, "TOPLEFT",
                COL_RAID_X + (idx - 1) * (16 + HDR_PAD), -2)
            hIcon:EnableMouse(true)

            local tex = hIcon:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(family.icon)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            tex:SetVertexColor(0.8, 0.8, 0.6, 0.9)

            hIcon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(family.label .. " (" .. family.class:sub(1,1) .. family.class:sub(2):lower() .. ")", 1, 0.82, 0.1)
                for _, bName in ipairs(family.buffs) do
                    GameTooltip:AddLine("  " .. bName, 0.8, 0.8, 0.8)
                end
                GameTooltip:Show()
            end)
            hIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
end

-- Header underline
local headerLine = headerBar:CreateTexture(nil, "ARTWORK")
headerLine:SetHeight(1)
headerLine:SetPoint("BOTTOMLEFT", headerBar, "BOTTOMLEFT", 0, 0)
headerLine:SetPoint("BOTTOMRIGHT", headerBar, "BOTTOMRIGHT", 0, 0)
ns.SetColorTex(headerLine, 0.4, 0.4, 0.4, 1)

----------------------------------------------------------------------
-- Grid scroll frame + row pool
----------------------------------------------------------------------
local gridScrollParent = CreateFrame("Frame", nil, gridContent)
gridScrollParent:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -2)
gridScrollParent:SetPoint("BOTTOMRIGHT", gridContent, "BOTTOMRIGHT", -20, 0)
gridScrollParent:EnableMouse(false)

local gridScroll = CreateFrame("ScrollFrame", "RaidLeadGridScroll", gridContent, "FauxScrollFrameTemplate")
gridScroll:SetPoint("TOPLEFT", gridScrollParent, "TOPLEFT", 0, 0)
gridScroll:SetPoint("BOTTOMRIGHT", gridScrollParent, "BOTTOMRIGHT", 0, 0)
gridScroll:EnableMouse(false)

local gridContentInner = CreateFrame("Frame", nil, gridContent)
gridContentInner:SetPoint("TOPLEFT", gridScrollParent, "TOPLEFT", 0, 0)
gridContentInner:SetPoint("BOTTOMRIGHT", gridScrollParent, "BOTTOMRIGHT", 0, 0)
gridContentInner:EnableMouse(false)

local gridRows = {}

local function CreateGridRow(index)
    local row = CreateFrame("Button", nil, gridContentInner)
    row:SetHeight(GRID_ROW_HEIGHT)
    row:SetPoint("TOPLEFT", gridContentInner, "TOPLEFT", 0, -((index - 1) * GRID_ROW_HEIGHT))
    row:SetPoint("RIGHT", gridContentInner, "RIGHT", 0, 0)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    ns.ApplyBackdrop(row, ns.ROW_BACKDROP)

    row.baseR, row.baseG, row.baseB, row.baseA = 0.08, 0.08, 0.10, 0.8

    -- Hover
    row:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(
                math.min(self.baseR + 0.12, 1),
                math.min(self.baseG + 0.12, 1),
                math.min(self.baseB + 0.18, 1), 0.9)
        end
        local r = self.data
        if r then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.ClassColor(r.class) .. r.name .. "|r", 1, 1, 1)

            -- Show self-declared role (if any)
            local roleKey = ns.Roles and ns.Roles.GetRole(r.name)
            if roleKey then
                local roleLabel = ns.Roles.ROLE_LABELS[roleKey] or roleKey
                local color     = ns.Roles.ROLE_COLORS[roleKey] or "FFCCCCCC"
                local icon      = ns.Roles.IconString and ns.Roles.IconString(roleKey, 14) or ""
                GameTooltip:AddLine("Role: " .. icon .. " |c" .. color .. roleLabel .. "|r",
                    0.8, 0.8, 0.8)
            end

            -- Show reported addon version (if any)
            local peerVer = ns.Versions and ns.Versions.GetVersion(r.name)
            if peerVer then
                local cmp = ns.Versions.CompareToMine(peerVer)
                local line, vr, vg, vb
                if cmp == nil or cmp == 0 then
                    line = "Addon: v" .. peerVer
                    vr, vg, vb = 0.7, 0.7, 0.7
                elseif cmp < 0 then
                    line = "Addon: v" .. peerVer .. "  |cFFFF6644(outdated, you're on v"
                        .. (ns.VERSION or "?") .. ")|r"
                    vr, vg, vb = 1, 0.55, 0.3
                else  -- cmp > 0 -> they're newer than us
                    line = "Addon: v" .. peerVer .. "  |cFF55BBFF(newer than yours)|r"
                    vr, vg, vb = 0.55, 0.85, 1
                end
                GameTooltip:AddLine(line, vr, vg, vb)
            elseif ns.Versions then
                GameTooltip:AddLine("Addon: |cFF888888not detected|r", 0.6, 0.6, 0.6)
            end

            if r.outOfRange then
                GameTooltip:AddLine("Out of inspect range", 1, 0.5, 0)
            elseif r.isDead then
                GameTooltip:AddLine("Dead", 0.6, 0.6, 0.6)
            else
                if r.hasFlask then
                    GameTooltip:AddLine("Flask: " .. (r.flaskName or "Yes"), 0.4, 1, 0.4)
                else
                    if r.hasBattle then
                        GameTooltip:AddLine("Battle Elixir: " .. (r.battleName or "Yes"), 0.4, 1, 0.4)
                    else
                        GameTooltip:AddLine("Battle Elixir: MISSING", 1, 0.3, 0.3)
                    end
                    if r.hasGuardian then
                        GameTooltip:AddLine("Guardian Elixir: " .. (r.guardianName or "Yes"), 0.4, 1, 0.4)
                    else
                        GameTooltip:AddLine("Guardian Elixir: MISSING", 1, 0.3, 0.3)
                    end
                end
                if r.hasFood then
                    GameTooltip:AddLine("Food: " .. (r.foodName or "Well Fed"), 0.4, 1, 0.4)
                else
                    GameTooltip:AddLine("Food: MISSING", 1, 0.3, 0.3)
                end
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Raid Buffs:", 1, 0.82, 0.1)
                for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                    local family = BD.raidBuffs[fk]
                    if family then
                        if r.raidBuffs[fk] then
                            GameTooltip:AddLine("  " .. family.label .. ": " .. (r.raidBuffNames[fk] or "Yes"), 0.4, 1, 0.4)
                        else
                            GameTooltip:AddLine("  " .. family.label .. ": MISSING", 1, 0.3, 0.3)
                        end
                    end
                end
            end
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(self.baseR, self.baseG, self.baseB, self.baseA)
        end
        GameTooltip:Hide()
    end)

    -- Right-click context menu
    row:SetScript("OnClick", function(self, button)
        if button == "RightButton" and self.data then
            local r = self.data
            local menu = {
                { text = ns.ClassColor(r.class) .. r.name .. "|r", isTitle = true },
                { text = "Whisper Missing Buffs", func = function()
                    BuffScan.WhisperMissing(r.name)
                end },
                { text = "Target", func = function()
                    TargetUnit(r.name)
                end },
            }
            ns.ShowContextMenu(menu, "cursor", 0, 0)
        end
    end)

    -- Columns
    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)
    row.nameText:SetWidth(COL_NAME_W)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetWordWrap(false)

    row.flaskText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.flaskText:SetPoint("TOPLEFT", row, "TOPLEFT", COL_FLASK_X, -3)
    row.flaskText:SetWidth(COL_FLASK_W)
    row.flaskText:SetJustifyH("CENTER")

    row.foodText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.foodText:SetPoint("TOPLEFT", row, "TOPLEFT", COL_FOOD_X, -3)
    row.foodText:SetWidth(COL_FOOD_W)
    row.foodText:SetJustifyH("CENTER")

    -- Raid buff icons
    local ICON_SIZE = 16
    local ICON_PAD  = 2
    row.raidIcons = {}
    for idx, fk in ipairs(ns.RAID_BUFF_ORDER) do
        local family = BD.raidBuffs[fk]
        if family then
            local iconFrame = CreateFrame("Frame", nil, row)
            iconFrame:SetSize(ICON_SIZE, ICON_SIZE)
            iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT",
                COL_RAID_X + (idx - 1) * (ICON_SIZE + ICON_PAD), -2)
            iconFrame:EnableMouse(true)

            local tex = iconFrame:CreateTexture(nil, "ARTWORK")
            tex:SetAllPoints()
            tex:SetTexture(family.icon)
            tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            iconFrame.tex = tex

            iconFrame.familyKey = fk
            iconFrame:SetScript("OnEnter", function(self)
                local data = row.data
                if not data then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local fam = BD.raidBuffs[self.familyKey]
                if data.outOfRange then
                    GameTooltip:AddLine(fam.label .. ": Out of range", 0.6, 0.6, 0.6)
                elseif data.isDead or not data.isOnline then
                    GameTooltip:AddLine(fam.label .. ": --", 0.6, 0.6, 0.6)
                elseif data.raidBuffs[self.familyKey] then
                    GameTooltip:AddLine(fam.label .. ": " .. (data.raidBuffNames[self.familyKey] or "Yes"), 0.4, 1, 0.4)
                else
                    GameTooltip:AddLine(fam.label .. ": MISSING", 1, 0.3, 0.3)
                end
                GameTooltip:Show()
                if row.SetBackdropColor then
                    row:SetBackdropColor(
                        math.min(row.baseR + 0.12, 1),
                        math.min(row.baseG + 0.12, 1),
                        math.min(row.baseB + 0.18, 1), 0.9)
                end
            end)
            iconFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
                if row.SetBackdropColor then
                    row:SetBackdropColor(row.baseR, row.baseG, row.baseB, row.baseA)
                end
            end)

            row.raidIcons[fk] = iconFrame
        end
    end

    row.data = nil
    row:SetFrameLevel(gridContentInner:GetFrameLevel() + 5)
    gridRows[index] = row
    return row
end

----------------------------------------------------------------------
-- Grid refresh
----------------------------------------------------------------------
local GREEN_CHECK  = "|cFF44FF44OK|r"
local RED_X        = "|cFFFF4444X|r"
local YELLOW_HALF  = "|cFFFFCC00~|r"
local GREY_Q       = "|cFF888888?|r"
local GREY_DEAD    = "|cFF666666--|r"

local function RefreshGridTab()
    local scanResults = BuffScan.scanResults
    local scanSorted  = BuffScan.scanSorted

    local parentH = gridScrollParent:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / GRID_ROW_HEIGHT))
    local total = #scanSorted

    FauxScrollFrame_Update(gridScroll, total, visibleRows, GRID_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(gridScroll)

    for i = 1, visibleRows do
        local row = gridRows[i] or CreateGridRow(i)
        local dataIdx = offset + i
        if dataIdx <= total then
            local name = scanSorted[dataIdx]
            local r = scanResults[name]
            row.data = r

            if dataIdx % 2 == 0 then
                row.baseR, row.baseG, row.baseB, row.baseA = 0.12, 0.12, 0.15, 0.8
            else
                row.baseR, row.baseG, row.baseB, row.baseA = 0.08, 0.08, 0.10, 0.8
            end
            if row.SetBackdropColor then
                row:SetBackdropColor(row.baseR, row.baseG, row.baseB, row.baseA)
            end

            if r then
                row.nameText:SetText(ns.ClassColor(r.class) .. r.name .. "|r")

                if r.outOfRange then
                    row.flaskText:SetText(GREY_Q)
                    row.foodText:SetText(GREY_Q)
                    for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                        local ic = row.raidIcons[fk]
                        if ic then
                            ic.tex:SetVertexColor(0.4, 0.4, 0.4, 0.5)
                            ic.tex:SetDesaturated(true)
                        end
                    end
                elseif r.isDead then
                    row.nameText:SetText("|cFF666666" .. r.name .. "|r")
                    row.flaskText:SetText(GREY_DEAD)
                    row.foodText:SetText(GREY_DEAD)
                    for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                        local ic = row.raidIcons[fk]
                        if ic then
                            ic.tex:SetVertexColor(0.4, 0.4, 0.4, 0.5)
                            ic.tex:SetDesaturated(true)
                        end
                    end
                elseif not r.isOnline then
                    row.nameText:SetText("|cFF666666" .. r.name .. " (offline)|r")
                    row.flaskText:SetText(GREY_DEAD)
                    row.foodText:SetText(GREY_DEAD)
                    for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                        local ic = row.raidIcons[fk]
                        if ic then
                            ic.tex:SetVertexColor(0.4, 0.4, 0.4, 0.5)
                            ic.tex:SetDesaturated(true)
                        end
                    end
                else
                    if r.hasFlask then
                        row.flaskText:SetText(GREEN_CHECK)
                    elseif r.hasBattle and r.hasGuardian then
                        row.flaskText:SetText(GREEN_CHECK)
                    elseif r.hasBattle or r.hasGuardian then
                        row.flaskText:SetText(YELLOW_HALF)
                    else
                        row.flaskText:SetText(RED_X)
                    end

                    row.foodText:SetText(r.hasFood and GREEN_CHECK or RED_X)

                    for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
                        local ic = row.raidIcons[fk]
                        if ic then
                            if r.raidBuffs[fk] then
                                ic.tex:SetDesaturated(false)
                                ic.tex:SetVertexColor(1, 1, 1, 1)
                            else
                                ic.tex:SetDesaturated(true)
                                ic.tex:SetVertexColor(0.5, 0.5, 0.5, 0.6)
                            end
                        end
                    end
                end
            end

            row:Show()
        else
            row:Hide()
        end
    end

    for i = visibleRows + 1, #gridRows do
        gridRows[i]:Hide()
    end
end
ns.RefreshGridTab = RefreshGridTab

gridScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, GRID_ROW_HEIGHT, RefreshGridTab)
end)

----------------------------------------------------------------------
-- Missing tab
----------------------------------------------------------------------
local missingScroll = CreateFrame("ScrollFrame", "RaidLeadMissingScroll", missingContent, "FauxScrollFrameTemplate")
missingScroll:SetPoint("TOPLEFT", missingContent, "TOPLEFT", 0, -20)
missingScroll:SetPoint("BOTTOMRIGHT", missingContent, "BOTTOMRIGHT", -20, 0)

local missingSummary = missingContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
missingSummary:SetPoint("TOPLEFT", missingContent, "TOPLEFT", 4, -2)
missingSummary:SetJustifyH("LEFT")

local missingInner = CreateFrame("Frame", nil, missingContent)
missingInner:SetPoint("TOPLEFT", missingContent, "TOPLEFT", 0, -20)
missingInner:SetPoint("BOTTOMRIGHT", missingContent, "BOTTOMRIGHT", -20, 0)
missingInner:EnableMouse(false)

local MISSING_ROW_HEIGHT = 18
local missingRows = {}

local function CreateMissingRow(index)
    local row = missingInner:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row:SetPoint("TOPLEFT", missingInner, "TOPLEFT", 4, -((index - 1) * MISSING_ROW_HEIGHT))
    row:SetPoint("RIGHT", missingInner, "RIGHT", -4, 0)
    row:SetJustifyH("LEFT")
    row:SetWordWrap(false)
    missingRows[index] = row
    return row
end

local missingLines = {}

local function BuildMissingLines()
    missingLines = {}
    local scanResults = BuffScan.scanResults
    local scanSorted  = BuffScan.scanSorted
    local s = ns.db and ns.db.settings or ns.SETTINGS_DEFAULTS
    local style = s.announceStyle or "buff"
    local fullyBuffed = 0
    local totalChecked = 0

    if style == "buff" or style == "category" then
        local catPlayers = BuffScan.BuildAnnounceByCat()
        for _, name in ipairs(scanSorted) do
            local r = scanResults[name]
            if r and not r.outOfRange and not r.isDead and r.isOnline then
                totalChecked = totalChecked + 1
                local m = BuffScan.GetMissing(r)
                if #m == 0 then fullyBuffed = fullyBuffed + 1 end
            end
        end
        for _, label in ipairs({"Flask/Elixirs", "Battle Elixir", "Guardian Elixir", "Food"}) do
            if catPlayers[label] then
                missingLines[#missingLines + 1] = "|cFFFFCC00Missing " .. label .. ":|r"
                for _, pname in ipairs(catPlayers[label]) do
                    local r = scanResults[pname]
                    local cc = r and ns.ClassColor(r.class) or "|cFFAAAAAA"
                    missingLines[#missingLines + 1] = "    " .. cc .. pname .. "|r"
                end
            end
        end
        for _, fk in ipairs(ns.RAID_BUFF_ORDER) do
            local family = BD.raidBuffs[fk]
            if family and catPlayers[family.label] then
                missingLines[#missingLines + 1] = "|cFFFFCC00Missing " .. family.label .. ":|r"
                for _, pname in ipairs(catPlayers[family.label]) do
                    local r = scanResults[pname]
                    local cc = r and ns.ClassColor(r.class) or "|cFFAAAAAA"
                    missingLines[#missingLines + 1] = "    " .. cc .. pname .. "|r"
                end
            end
        end
    else
        local lines = BuffScan.BuildAnnounceByPlayer()
        for _, name in ipairs(scanSorted) do
            local r = scanResults[name]
            if r and not r.outOfRange and not r.isDead and r.isOnline then
                totalChecked = totalChecked + 1
                local m = BuffScan.GetMissing(r)
                if #m == 0 then fullyBuffed = fullyBuffed + 1 end
            end
        end
        for _, entry in ipairs(lines) do
            local r = scanResults[entry.name]
            local cc = r and ns.ClassColor(r.class) or "|cFFAAAAAA"
            missingLines[#missingLines + 1] = cc .. entry.name .. "|r" ..
                "  |cFFFF4444missing: " .. table.concat(entry.missing, ", ") .. "|r"
        end
    end

    if totalChecked > 0 then
        missingSummary:SetText("|cFF" .. ns.ACCENT ..
            fullyBuffed .. "/" .. totalChecked .. " fully buffed|r" ..
            "  |cFF888888(" .. (#scanSorted - totalChecked) .. " dead/offline/oor)|r")
    else
        missingSummary:SetText("")
    end
end

local function RefreshMissingTab()
    BuildMissingLines()

    local parentH = missingInner:GetHeight()
    local visibleRows = math.max(1, math.floor(parentH / MISSING_ROW_HEIGHT))
    local total = #missingLines

    FauxScrollFrame_Update(missingScroll, total, visibleRows, MISSING_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(missingScroll)

    for i = 1, visibleRows do
        local row = missingRows[i] or CreateMissingRow(i)
        local dataIdx = offset + i
        if dataIdx <= total then
            row:SetText(missingLines[dataIdx])
            row:Show()
        else
            row:SetText("")
            row:Hide()
        end
    end
    for i = visibleRows + 1, #missingRows do
        missingRows[i]:SetText("")
        missingRows[i]:Hide()
    end
end

missingScroll:SetScript("OnVerticalScroll", function(self, offset)
    FauxScrollFrame_OnVerticalScroll(self, offset, MISSING_ROW_HEIGHT, RefreshMissingTab)
end)

----------------------------------------------------------------------
-- Sub-view switch + tab registration
----------------------------------------------------------------------
SetBuffSubView = function(mode)
    buffSubMode = (mode == "missing") and "missing" or "grid"
    local showGrid = (buffSubMode == "grid")

    headerBar:SetShown(showGrid)
    gridScroll:SetShown(showGrid)
    gridContentInner:SetShown(showGrid)
    missingContent:SetShown(not showGrid)

    if gridBtn.SetActive    then gridBtn:SetActive(showGrid) end
    if missingBtn.SetActive then missingBtn:SetActive(not showGrid) end

    if showGrid then RefreshGridTab() else RefreshMissingTab() end
end
ns.SetBuffSubView = SetBuffSubView

-- One "Grid" tab; its refresh re-renders whichever sub-view is active.
ns.RegisterTab("Grid", 10, gridContent, function() SetBuffSubView(buffSubMode) end)
