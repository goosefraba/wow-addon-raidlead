----------------------------------------------------------------------
-- RaidLead — UI/MainFrame.lua
-- Main window shell, dynamic tab system, settings panel
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local MIN_W, MIN_H = 580, 340
local MAX_W, MAX_H = 900, 700

ns.D("creating main frame...")

----------------------------------------------------------------------
-- Main frame
----------------------------------------------------------------------
local f = CreateFrame("Frame", "RaidLeadFrame", UIParent)
f:SetSize(MIN_W, MIN_H)
f:SetPoint("CENTER")
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetFrameStrata("DIALOG")
f:SetClampedToScreen(true)
ns.ApplyBackdrop(f, ns.DIALOG_BACKDROP)
f:Hide()

ns.mainFrame = f
ns.MIN_W = MIN_W
ns.MIN_H = MIN_H

-- Resizable
if f.SetResizable then
    f:SetResizable(true)
    if f.SetMinResize then
        f:SetMinResize(MIN_W, MIN_H)
        f:SetMaxResize(MAX_W, MAX_H)
    elseif f.SetResizeBounds then
        f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    end
end

-- Drag to move
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    if ns.db and ns.db.frame then
        ns.db.frame.point    = point
        ns.db.frame.relPoint = relPoint
        ns.db.frame.x        = x
        ns.db.frame.y        = y
    end
end)

-- Resize handle
local sizer = CreateFrame("Frame", nil, f)
sizer:SetSize(16, 16)
sizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
sizer:EnableMouse(true)
sizer:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
sizer:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if ns.db and ns.db.frame then
        if ns.db.settings and ns.db.settings.compactMode then
            -- Save compact-mode size separately
            ns.db.frame.compactW = f:GetWidth()
            ns.db.frame.compactH = f:GetHeight()
            -- Refresh only the compact display, don't re-show full UI
            if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
        else
            ns.db.frame.width  = f:GetWidth()
            ns.db.frame.height = f:GetHeight()
            if ns.RefreshUI then ns.RefreshUI() end
        end
    end
end)

local grip = sizer:CreateTexture(nil, "OVERLAY")
grip:SetSize(16, 16)
grip:SetPoint("CENTER")
grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
sizer:SetScript("OnEnter", function() grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight") end)
sizer:SetScript("OnLeave", function() grip:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up") end)

-- Close on Escape
tinsert(UISpecialFrames, "RaidLeadFrame")

-- Title
local titleBar = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleBar:SetPoint("TOP", f, "TOP", 0, -14)
titleBar:SetText("|cFF" .. ns.ACCENT .. "RaidLead|r")

-- Version warning chip (only shown when a newer version is known from
-- a raid peer). Sits in the top-left corner where there is empty space
-- next to the centered title; hover for full details.
local versionWarn = CreateFrame("Button", nil, f)
versionWarn:SetSize(160, 18)
versionWarn:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -14)
versionWarn:EnableMouse(true)
versionWarn:Hide()

local vIcon = versionWarn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
vIcon:SetPoint("LEFT", versionWarn, "LEFT", 0, 0)
vIcon:SetText("\226\154\160")  -- warning triangle
vIcon:SetTextColor(1, 0.65, 0.2)

local vText = versionWarn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
vText:SetPoint("LEFT",  vIcon,        "RIGHT", 4, 0)
vText:SetPoint("RIGHT", versionWarn, "RIGHT", 0, 0)
vText:SetJustifyH("LEFT")
vText:SetWordWrap(false)
vText:SetTextColor(1, 0.72, 0.3)

versionWarn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:AddLine("RaidLead update available", 1, 0.82, 0.1)
    if ns.Versions then
        local known = ns.Versions.GetKnownLatest() or "?"
        local mine  = ns.VERSION or "?"
        GameTooltip:AddLine("Latest seen in raid:  |cFF55EEFFv" .. known .. "|r",
            0.85, 0.85, 0.85)
        GameTooltip:AddLine("You're on:  |cFFCCCCCCv" .. mine .. "|r",
            0.85, 0.85, 0.85)
    end
    GameTooltip:Show()
end)
versionWarn:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.UpdateVersionBanner()
    if not ns.Versions then return end
    if ns.Versions.MineIsOutdated() then
        local known = ns.Versions.GetKnownLatest() or "?"
        vText:SetText("Update to v" .. known)
        versionWarn:Show()
    else
        versionWarn:Hide()
    end
end

-- Close button
local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

----------------------------------------------------------------------
-- Top-right icon bar
----------------------------------------------------------------------
local ICON_SIZE = 20
local ICON_GAP  = 4

-- Helper: small textured button with hover highlight + tooltip
local function MakeIconButton(parent, texturePath, tooltipTitle, tooltipDesc, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(ICON_SIZE, ICON_SIZE)

    -- Use SetNormalTexture so the button's clickable hit-area is properly defined
    btn:SetNormalTexture(texturePath)
    btn:SetPushedTexture(texturePath)
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    -- Tint the pushed texture darker for click feedback
    local pushed = btn:GetPushedTexture()
    if pushed then pushed:SetVertexColor(0.7, 0.7, 0.7, 1) end

    -- Expose the normal texture for callers that want to recolor or swap it
    btn.tex = btn:GetNormalTexture()

    btn:SetScript("OnClick", function(self, mouseButton)
        -- Defensive: ensure DB is loaded before the action runs
        if not ns.db and ns.InitDB then ns.InitDB() end
        onClick(self, mouseButton)
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tooltipTitle, 1, 0.82, 0)
        if tooltipDesc then
            GameTooltip:AddLine(tooltipDesc, 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

-- Settings (gears)
local settingsBtn = MakeIconButton(f,
    "Interface\\Icons\\Trade_Engineering",
    "Settings",
    "Open the settings panel.",
    function()
        local sp = RaidLeadSettings
        if sp then
            if sp:IsShown() then sp:Hide() else sp:Show() end
        end
    end)
-- Crop the icon border for a cleaner look (applies to both normal and pushed)
local sNorm = settingsBtn:GetNormalTexture()
local sPush = settingsBtn:GetPushedTexture()
if sNorm then sNorm:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
if sPush then sPush:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -ICON_GAP, -2)
ns.settingsBtn = settingsBtn

-- Compact mode toggle - "live view" eye icon
local COMPACT_ICON = "Interface\\Icons\\INV_Misc_Eye_01"

local compactBtn = MakeIconButton(f,
    COMPACT_ICON,
    "Compact / Live View",
    "Shrinks the window and hides controls for raid use.",
    function()
        if not ns.db then return end
        ns.db.settings.compactMode = not ns.db.settings.compactMode
        ns.ApplyCompactMode()
    end)
compactBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -ICON_GAP, 0)
-- Crop the icon border for a cleaner look
local cNorm = compactBtn:GetNormalTexture()
local cPush = compactBtn:GetPushedTexture()
if cNorm then cNorm:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
if cPush then cPush:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
ns.compactBtn = compactBtn

-- Refresh / re-scan
local scanBtn = MakeIconButton(f,
    "Interface\\Buttons\\UI-RotationRight-Button-Up",
    "Refresh",
    "Re-scan the group for buffs.",
    function()
        ns.BuffScan.ScanGroup()
        ns.P("Scan complete.")
    end)
scanBtn:SetPoint("RIGHT", compactBtn, "LEFT", -ICON_GAP, 0)
ns.scanBtn = scanBtn

-- Forward-declared state — these are initialized later in the file but
-- need to be in scope here so closures defined below (e.g. the history
-- toggle's click handler) can capture them as upvalues.
local registeredTabs = {}   -- { { name=, order=, content=, refresh= }, ... }
local tabButtons     = {}   -- [name] = btn
local tabContents    = {}   -- [name] = frame
local activeTab      = nil
local soloMsg                -- assigned later

-- Loot history toggle (a "mode" overlay - hides tabs and shows history)
local historyMode = false
local function SetHistoryMode(enabled)
    historyMode = enabled and true or false
    local hist = ns.lootHistContent
    if not hist then return end
    if historyMode then
        -- Hide regular content; show history
        for _, btn in pairs(tabButtons) do btn:Hide() end
        for _, cf in pairs(tabContents) do cf:Hide() end
        if ns.bottomBar then ns.bottomBar:Hide() end
        if soloMsg then soloMsg:Hide() end
        hist:Show()
        if ns.RefreshLootHistory then ns.RefreshLootHistory() end
    else
        hist:Hide()
        -- Restore tabs and active tab content
        for _, btn in pairs(tabButtons) do btn:Show() end
        if ns.ShowTab and activeTab then ns.ShowTab(activeTab) end
    end
end
ns.SetHistoryMode = SetHistoryMode

local historyBtn = MakeIconButton(f,
    "Interface\\Icons\\INV_Misc_Note_05",
    "Loot History",
    "Open the loot history viewer.",
    function() SetHistoryMode(not historyMode) end)
historyBtn:SetPoint("RIGHT", scanBtn, "LEFT", -ICON_GAP, 0)
-- Crop icon border
local hNorm = historyBtn:GetNormalTexture()
local hPush = historyBtn:GetPushedTexture()
if hNorm then hNorm:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
if hPush then hPush:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
ns.historyBtn = historyBtn

-- Boss-config lock toggle
local lockBtn = CreateFrame("Button", nil, f)
lockBtn:SetSize(ICON_SIZE, ICON_SIZE)
lockBtn:SetPoint("RIGHT", historyBtn, "LEFT", -ICON_GAP, 0)

lockBtn:SetNormalTexture("Interface\\PetBattles\\PetBattle-LockIcon")
lockBtn:SetPushedTexture("Interface\\PetBattles\\PetBattle-LockIcon")
lockBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
local lockPushed = lockBtn:GetPushedTexture()
if lockPushed then lockPushed:SetVertexColor(0.7, 0.7, 0.7, 1) end

local function UpdateLockIcon()
    local locked = ns.db and ns.db.settings and ns.db.settings.bossLocked
    local tex = lockBtn:GetNormalTexture()
    if not tex then return end
    if locked then
        tex:SetVertexColor(1, 0.4, 0.4, 1)        -- vivid red = locked
        tex:SetDesaturated(false)
    else
        tex:SetVertexColor(0.5, 1, 0.5, 0.55)     -- dim green = unlocked
        tex:SetDesaturated(true)
    end
end

lockBtn:SetScript("OnClick", function()
    if not ns.db and ns.InitDB then ns.InitDB() end
    if not ns.db then return end
    ns.db.settings.bossLocked = not ns.db.settings.bossLocked
    UpdateLockIcon()
    if ns.db.settings.bossLocked then
        ns.P("|cFFFF8800Configs locked.|r Click the lock icon to unlock.")
    else
        ns.P("|cFF44FF44Configs unlocked.|r You can now edit assignments.")
    end
end)
lockBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local locked = ns.db and ns.db.settings and ns.db.settings.bossLocked
    if locked then
        GameTooltip:AddLine("Configs LOCKED", 1, 0.4, 0.4)
        GameTooltip:AddLine("Click to unlock and allow edits.", 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine("Configs UNLOCKED", 0.4, 1, 0.4)
        GameTooltip:AddLine("Click to lock and prevent accidental edits.", 0.8, 0.8, 0.8, true)
    end
    GameTooltip:Show()
end)
lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
ns.lockBtn = lockBtn
ns.UpdateLockIcon = UpdateLockIcon

-- Apply initial tint immediately. ns.db may already be set if InitDB
-- ran in RaidLead.lua's file-load step before this UI loaded; if not, the
-- tint will fall through and ADDON_LOADED handler will refresh it later.
if ns.db and ns.db.settings then
    UpdateLockIcon()
end

ns.D("main frame OK")

----------------------------------------------------------------------
-- Solo message
----------------------------------------------------------------------
soloMsg = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
soloMsg:SetPoint("CENTER", f, "CENTER", 0, 0)
soloMsg:SetText("|cFFAAAAAA" .. "You are not in a group or raid.\n\n" ..
    "Join a party or raid and click |cFF" .. ns.ACCENT .. "Refresh|r\n" ..
    "or type |cFF" .. ns.ACCENT .. "/rl scan|r to inspect buffs.\n\n" ..
    "Or type |cFF" .. ns.ACCENT .. "/rl mock|r to load test data.|r")
soloMsg:SetJustifyH("CENTER")
soloMsg:Hide()
ns.soloMsg = soloMsg

----------------------------------------------------------------------
-- Dynamic tab system (state declared earlier in this file)
----------------------------------------------------------------------
function ns.RegisterTab(name, order, contentFrame, refreshFunc)
    registeredTabs[#registeredTabs + 1] = {
        name    = name,
        order   = order,
        content = contentFrame,
        refresh = refreshFunc,
    }
    tabContents[name] = contentFrame
    -- Sort by order
    table.sort(registeredTabs, function(a, b) return a.order < b.order end)
end

local function RebuildTabButtons()
    -- Clear old buttons
    for _, btn in pairs(tabButtons) do btn:Hide() end
    tabButtons = {}

    local tabW = 80
    for i, tab in ipairs(registeredTabs) do
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(tabW, 22)
        btn:SetPoint("TOPLEFT", f, "TOPLEFT", 20 + (i - 1) * (tabW + 4), -36)
        btn:EnableMouse(true)

        -- Active-tab background tint (hidden until selected)
        local activeBg = btn:CreateTexture(nil, "BACKGROUND")
        activeBg:SetAllPoints()
        activeBg:SetColorTexture(1, 0.82, 0, 0.13)
        activeBg:Hide()
        btn.activeBg = activeBg

        -- Subtle hover effect (always shown on mouse-over)
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("CENTER", btn, "CENTER", 0, 0)
        lbl:SetText(tab.name)
        btn.label = lbl

        -- Bottom underline (active tab indicator)
        local ul = btn:CreateTexture(nil, "ARTWORK")
        ul:SetHeight(2)
        ul:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 0)
        ul:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 0)
        ns.SetColorTex(ul, 1, 0.82, 0.1, 1)
        ul:Hide()
        btn.underline = ul

        local tabName = tab.name
        btn:SetScript("OnClick", function() ns.ShowTab(tabName) end)
        tabButtons[tabName] = btn
    end
end

function ns.ShowTab(name)
    -- Rebuild buttons if not yet created
    if not next(tabButtons) then RebuildTabButtons() end

    activeTab = name
    for tname, btn in pairs(tabButtons) do
        if tname == name then
            btn.label:SetTextColor(1, 0.92, 0.4)
            btn.underline:Show()
            if btn.activeBg then btn.activeBg:Show() end
        else
            btn.label:SetTextColor(0.55, 0.55, 0.55)
            btn.underline:Hide()
            if btn.activeBg then btn.activeBg:Hide() end
        end
    end
    for tname, cf in pairs(tabContents) do
        if tname == name then cf:Show() else cf:Hide() end
    end
    -- Bottom bar is only used by Grid/Missing (buff scan tabs).
    -- Boss / Healers tabs have their own bottom controls.
    if ns.bottomBar then
        if name == "Grid" or name == "Missing" then
            ns.bottomBar:Show()
        else
            ns.bottomBar:Hide()
        end
    end
    -- Call refresh for the active tab
    for _, tab in ipairs(registeredTabs) do
        if tab.name == name and tab.refresh then
            tab.refresh()
        end
    end
end

ns.activeTab = function() return activeTab end

----------------------------------------------------------------------
-- Bottom bar (announce buttons)
----------------------------------------------------------------------
local bottomBar = CreateFrame("Frame", nil, f)
bottomBar:SetHeight(32)
bottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
bottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
ns.bottomBar = bottomBar

function ns.ShowAnnounceMenu(mode, anchor)
    local MENU_TITLES = { all = "Announce All", consumables = "Announce Consumables", raidbuffs = "Announce Raid Buffs" }
    local label = MENU_TITLES[mode] or "Announce"
    local menu = {
        { text = label, isTitle = true },
    }
    local gt = ns.GetGroupType()
    if gt == "raid" then
        menu[#menu + 1] = { text = "To Raid",  func = function() ns.BuffScan.Announce("RAID", mode) end }
        menu[#menu + 1] = { text = "To Party", func = function() ns.BuffScan.Announce("PARTY", mode) end }
    elseif gt == "party" then
        menu[#menu + 1] = { text = "To Party", func = function() ns.BuffScan.Announce("PARTY", mode) end }
    else
        menu[#menu + 1] = { text = "Not in a group", disabled = true }
    end
    ns.ShowContextMenu(menu, "cursor", 0, 0)
end

-- Create announce buttons
local btnConsumables = ns.MakeAnnounceBtn(bottomBar, "LEFT", nil, 0,
    "Consumables", "Announce Missing Consumables", "consumables")
local btnRaidBuffs = ns.MakeAnnounceBtn(bottomBar, btnConsumables, "RIGHT", 4,
    "Raid Buffs", "Announce Missing Raid Buffs", "raidbuffs")
local btnAll = ns.MakeAnnounceBtn(bottomBar, btnRaidBuffs, "RIGHT", 4,
    "All", "Announce Everything Missing", "all")

local statusText = bottomBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
statusText:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
statusText:SetJustifyH("RIGHT")
statusText:SetText("")
ns.statusText = statusText

ns.D("bottom bar OK")

----------------------------------------------------------------------
-- Compact / Live view
----------------------------------------------------------------------
local compactFrame = CreateFrame("Frame", nil, f)
compactFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -28)
compactFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
compactFrame:Hide()

local compactText = compactFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
compactText:SetPoint("TOPLEFT", compactFrame, "TOPLEFT", 4, -2)
compactText:SetPoint("RIGHT", compactFrame, "RIGHT", -4, 0)
compactText:SetJustifyH("LEFT")
compactText:SetJustifyV("TOP")
compactText:SetWordWrap(true)
compactText:SetSpacing(3)
-- Slightly smaller than GameFontNormalSmall for tightness
local fontFile, _, fontFlags = compactText:GetFont()
if fontFile then compactText:SetFont(fontFile, 10, fontFlags) end

function ns.UpdateCompactDisplay()
    if not ns.db or not ns.db.settings.compactMode then return end
    local s = ns.db.settings
    local sections = {}

    -- Boss assignments section
    if s.compactShowBoss then
        local widget = ns.GetActiveBossWidget and ns.GetActiveBossWidget()
        if widget and widget.BuildCompactText then
            local txt = widget.BuildCompactText()
            if txt and txt ~= "" then
                sections[#sections + 1] = txt
            end
        elseif ns.GetActiveBossKey and ns.GetActiveBossKey() then
            sections[#sections + 1] = "|cFF888888(no compact view for this boss)|r"
        end
    end

    -- Healer assignments section
    if s.compactShowHealers and ns.HealAssign and ns.HealAssign.BuildHealersCompactText then
        local txt = ns.HealAssign.BuildHealersCompactText()
        if txt and txt ~= "" then
            sections[#sections + 1] = "|cFFFFCC00Healers|r\n" .. txt
        end
    end

    -- Misdirect section
    if s.compactShowMisdirects and ns.HealAssign and ns.HealAssign.BuildMisdirectsCompactText then
        local txt = ns.HealAssign.BuildMisdirectsCompactText()
        if txt and txt ~= "" then
            sections[#sections + 1] = "|cFFFFCC00Misdirect|r\n" .. txt
        end
    end

    if #sections == 0 then
        if not s.compactShowBoss and not s.compactShowHealers and not s.compactShowMisdirects then
            compactText:SetText("|cFFFFCC00All sections hidden.|r\nEnable some in /rl settings.")
        else
            compactText:SetText("|cFF888888(nothing configured to show)|r")
        end
    else
        compactText:SetText(table.concat(sections, "\n\n"))
    end
end

local NORMAL_W, NORMAL_H = ns.MIN_W, ns.MIN_H
local COMPACT_W, COMPACT_H = 380, 200

----------------------------------------------------------------------
-- Smooth alpha fade utility (used when toggling compact <-> full)
----------------------------------------------------------------------
local fadeRunner = CreateFrame("Frame")
fadeRunner:Hide()
local fadeData = nil

fadeRunner:SetScript("OnUpdate", function(self, elapsed)
    if not fadeData then self:Hide(); return end
    fadeData.elapsed = fadeData.elapsed + elapsed
    local pct = math.min(fadeData.elapsed / fadeData.duration, 1.0)
    -- ease-out (1 - (1-t)^2): fast start, gentle finish
    local eased = 1 - (1 - pct) * (1 - pct)
    local current = fadeData.from + (fadeData.to - fadeData.from) * eased
    fadeData.frame:SetAlpha(current)
    if pct >= 1.0 then
        fadeData.frame:SetAlpha(fadeData.to)
        fadeData = nil
        self:Hide()
    end
end)

local function FadeAlpha(frame, fromAlpha, toAlpha, duration)
    fadeData = {
        frame    = frame,
        from     = fromAlpha,
        to       = toAlpha,
        duration = duration or 0.18,
        elapsed  = 0,
    }
    frame:SetAlpha(fromAlpha)
    fadeRunner:Show()
end

function ns.ApplyCompactMode()
    if not ns.db then return end
    local compact = ns.db.settings.compactMode

    if compact then
        -- Save current full size to restore later (only if not already in compact)
        if not compactFrame:IsShown() then
            ns.db.frame.width  = f:GetWidth()
            ns.db.frame.height = f:GetHeight()
        end

        -- Swap to a clean minimal backdrop
        if f.SetBackdrop then
            f:SetBackdrop(ns.COMPACT_BACKDROP.backdrop)
            f:SetBackdropColor(unpack(ns.COMPACT_BACKDROP.color))
        end

        -- Allow much smaller sizes in compact mode
        if f.SetMinResize then
            f:SetMinResize(220, 100)
        elseif f.SetResizeBounds then
            f:SetResizeBounds(220, 100, MAX_W, MAX_H)
        end

        local targetAlpha = ns.db.settings.compactAlpha or 0.92
        FadeAlpha(f, f:GetAlpha(), targetAlpha, 0.18)
        f:SetSize(ns.db.frame.compactW or COMPACT_W,
                  ns.db.frame.compactH or COMPACT_H)

        -- Hide normal UI (most chrome)
        scanBtn:Hide()
        lockBtn:Hide()
        settingsBtn:Hide()
        historyBtn:Hide()
        if ns.lootHistContent then ns.lootHistContent:Hide() end
        titleBar:Hide()
        -- Compact button stays visible (so user can toggle back) but reposition
        for _, btn in pairs(tabButtons) do btn:Hide() end
        for _, cf in pairs(tabContents) do cf:Hide() end
        bottomBar:Hide()
        soloMsg:Hide()

        compactFrame:Show()
        -- Reposition compact icon to the top-right when chrome is hidden
        compactBtn:ClearAllPoints()
        compactBtn:SetPoint("RIGHT", closeBtn, "LEFT", -ICON_GAP, -2)
        -- Highlight the compact icon to show it's "active"
        local n = compactBtn:GetNormalTexture()
        local p = compactBtn:GetPushedTexture()
        if n then n:SetVertexColor(1, 0.85, 0.2, 1) end  -- glowing yellow
        if p then p:SetVertexColor(0.7, 0.6, 0.15, 1) end
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 2)

        ns.UpdateCompactDisplay()
    else
        -- Restore the full dialog backdrop
        if f.SetBackdrop then
            f:SetBackdrop(ns.DIALOG_BACKDROP.backdrop)
            f:SetBackdropColor(unpack(ns.DIALOG_BACKDROP.color))
        end

        FadeAlpha(f, f:GetAlpha(), 1.0, 0.18)
        -- Restore full-mode resize bounds
        if f.SetMinResize then
            f:SetMinResize(NORMAL_W, NORMAL_H)
        elseif f.SetResizeBounds then
            f:SetResizeBounds(NORMAL_W, NORMAL_H, MAX_W, MAX_H)
        end
        f:SetSize(ns.db.frame.width or NORMAL_W, ns.db.frame.height or NORMAL_H)

        scanBtn:Show()
        lockBtn:Show()
        settingsBtn:Show()
        historyBtn:Show()
        titleBar:Show()
        for _, btn in pairs(tabButtons) do btn:Show() end
        compactFrame:Hide()

        -- Restore compact icon position + tint
        compactBtn:ClearAllPoints()
        compactBtn:SetPoint("RIGHT", settingsBtn, "LEFT", -ICON_GAP, 0)
        local n = compactBtn:GetNormalTexture()
        local p = compactBtn:GetPushedTexture()
        if n then n:SetVertexColor(1, 1, 1, 1) end  -- normal white
        if p then p:SetVertexColor(0.7, 0.7, 0.7, 1) end
        closeBtn:ClearAllPoints()
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)

        ns.RefreshUI()
    end
end

-- (compactBtn's OnClick is set by MakeIconButton above)

----------------------------------------------------------------------
-- RefreshUI (master refresh — called after every scan)
----------------------------------------------------------------------
function ns.RefreshUI()
    local gt = ns.GetGroupType()
    local isSolo = (gt == "solo") and #ns.BuffScan.scanSorted == 0

    soloMsg:SetShown(isSolo)

    -- Toggle tab content
    for _, cf in pairs(tabContents) do cf:SetShown(not isSolo) end
    bottomBar:SetShown(not isSolo)

    if not isSolo then
        ns.ShowTab(activeTab or registeredTabs[1] and registeredTabs[1].name or "Grid")
    end

    -- Status
    if ns.BuffScan.scanTime then
        statusText:SetText("|cFF888888Last scan: " .. ns.BuffScan.scanTime .. "|r")
    end
end

----------------------------------------------------------------------
-- Settings panel — tabbed (General / Buff Scanner / Compact View)
----------------------------------------------------------------------
do
    local SP_W, SP_H = 360, 440
    local sp = CreateFrame("Frame", "RaidLeadSettings", UIParent)
    sp:SetSize(SP_W, SP_H)
    sp:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
    sp:SetFrameStrata("FULLSCREEN_DIALOG")
    sp:SetMovable(true)
    sp:EnableMouse(true)
    sp:RegisterForDrag("LeftButton")
    sp:SetClampedToScreen(true)
    sp:SetScript("OnDragStart", function(s) s:StartMoving() end)
    sp:SetScript("OnDragStop", function(s) s:StopMovingOrSizing() end)
    sp:Hide()

    -- Use the same clean panel backdrop as the main frame
    ns.ApplyBackdrop(sp, ns.DIALOG_BACKDROP)

    tinsert(UISpecialFrames, "RaidLeadSettings")

    local spClose = CreateFrame("Button", nil, sp, "UIPanelCloseButton")
    spClose:SetPoint("TOPRIGHT", sp, "TOPRIGHT", -2, -2)

    local spTitle = sp:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    spTitle:SetPoint("TOP", sp, "TOP", 0, -14)
    spTitle:SetText("|cFF" .. ns.ACCENT .. "RaidLead Settings|r")

    --------------------------------------------------------------------
    -- Internal tab system
    --------------------------------------------------------------------
    local SP_TABS = { "General", "Buff Scanner", "Compact View" }
    local spTabBtns   = {}
    local spTabPanes  = {}
    local activeSpTab = "General"

    local function ShowSpTab(name)
        activeSpTab = name
        for tname, btn in pairs(spTabBtns) do
            if tname == name then
                btn.label:SetTextColor(1, 0.92, 0.4)
                btn.underline:Show()
                btn.activeBg:Show()
            else
                btn.label:SetTextColor(0.55, 0.55, 0.55)
                btn.underline:Hide()
                btn.activeBg:Hide()
            end
        end
        for pname, pane in pairs(spTabPanes) do
            pane:SetShown(pname == name)
        end
    end

    do
        local tabW = 100
        for i, tname in ipairs(SP_TABS) do
            local btn = CreateFrame("Button", nil, sp)
            btn:SetSize(tabW, 22)
            btn:SetPoint("TOPLEFT", sp, "TOPLEFT", 16 + (i - 1) * (tabW + 4), -42)
            btn:EnableMouse(true)

            local activeBg = btn:CreateTexture(nil, "BACKGROUND")
            activeBg:SetAllPoints()
            activeBg:SetColorTexture(1, 0.82, 0, 0.13)
            activeBg:Hide()
            btn.activeBg = activeBg

            btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

            local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("CENTER", btn, "CENTER", 0, 0)
            lbl:SetText(tname)
            btn.label = lbl

            local ul = btn:CreateTexture(nil, "ARTWORK")
            ul:SetHeight(2)
            ul:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 0)
            ul:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 0)
            ns.SetColorTex(ul, 1, 0.82, 0.1, 1)
            ul:Hide()
            btn.underline = ul

            local n = tname
            btn:SetScript("OnClick", function() ShowSpTab(n) end)
            spTabBtns[tname] = btn
        end
    end

    -- Helper: make a content pane for a tab. Leaves a 26px strip at the
    -- bottom for the always-visible version footer.
    local function MakePane(parent)
        local pane = CreateFrame("Frame", nil, parent)
        pane:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -72)
        pane:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -12, 28)
        pane:Hide()
        return pane
    end

    --------------------------------------------------------------------
    -- Version footer (bottom of every settings tab)
    --------------------------------------------------------------------
    local versionFooter = sp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    versionFooter:SetPoint("BOTTOMLEFT",  sp, "BOTTOMLEFT",  14, 10)
    versionFooter:SetPoint("BOTTOMRIGHT", sp, "BOTTOMRIGHT", -14, 10)
    versionFooter:SetJustifyH("LEFT")
    versionFooter:SetTextColor(0.55, 0.55, 0.55)

    local function UpdateSettingsVersionFooter()
        local mine = ns.VERSION or ns.ADDON_VERSION or "?"
        local left = "RaidLead |cFFCCCCCCv" .. mine .. "|r"
        local right = ""
        if ns.Versions and ns.Versions.MineIsOutdated and ns.Versions.MineIsOutdated() then
            local known = ns.Versions.GetKnownLatest() or "?"
            right = "  \226\128\148  |cFFFFAA00\226\154\160 update available: v"
                  .. known .. "|r"
        elseif ns.Versions and ns.Versions.GetKnownLatest then
            local known = ns.Versions.GetKnownLatest()
            if known and known ~= "" then
                right = "  \226\128\148  |cFF888888highest peer: v" .. known .. "|r"
            end
        end
        versionFooter:SetText(left .. right)
    end
    UpdateSettingsVersionFooter()

    -- Refresh whenever the version banner refreshes
    local prevUpdate = ns.UpdateVersionBanner
    ns.UpdateVersionBanner = function(...)
        if prevUpdate then prevUpdate(...) end
        UpdateSettingsVersionFooter()
    end
    -- Also refresh whenever the settings panel is shown
    sp:HookScript("OnShow", UpdateSettingsVersionFooter)

    --------------------------------------------------------------------
    -- General tab
    --------------------------------------------------------------------
    local generalPane = MakePane(sp)
    spTabPanes["General"] = generalPane

    do
        local yOff = -8
        local autoScanToggle = ns.CreateToggle(generalPane, yOff,
            "Auto-Scan on Roster Change",
            "Automatically rescan buffs when group roster changes.",
            function() return ns.db and ns.db.settings and ns.db.settings.autoScan or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.autoScan = val end
                ns.P("Auto-Scan: " .. (val and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))
            end
        )

        yOff = yOff - 50
        local debugToggle = ns.CreateToggle(generalPane, yOff,
            "Debug Logging",
            "Show verbose debug messages in chat.",
            function() return ns.DEBUG end,
            function(val)
                ns.DEBUG = val
                if ns.db and ns.db.settings then ns.db.settings.debug = val end
                ns.P("Debug: " .. (val and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))
            end
        )

        generalPane.Refresh = function()
            autoScanToggle.Refresh()
            debugToggle.Refresh()
        end
    end

    --------------------------------------------------------------------
    -- Buff Scanner tab
    --------------------------------------------------------------------
    local buffPane = MakePane(sp)
    spTabPanes["Buff Scanner"] = buffPane

    do
        local yOff = -8
        local trackFlaskToggle = ns.CreateToggle(buffPane, yOff,
            "Track Flasks / Elixirs",
            "Show flask and elixir status in the grid.",
            function() return ns.db and ns.db.settings and ns.db.settings.trackFlasks or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.trackFlasks = val end
                ns.P("Track Flasks: " .. (val and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))
            end
        )

        yOff = yOff - 50
        local trackFoodToggle = ns.CreateToggle(buffPane, yOff,
            "Track Food Buffs",
            "Show food buff status in the grid.",
            function() return ns.db and ns.db.settings and ns.db.settings.trackFood or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.trackFood = val end
                ns.P("Track Food: " .. (val and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))
            end
        )

        yOff = yOff - 50
        local trackRaidToggle = ns.CreateToggle(buffPane, yOff,
            "Track Raid Buffs",
            "Show class-provided raid buffs in the grid.",
            function() return ns.db and ns.db.settings and ns.db.settings.trackRaidBuffs or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.trackRaidBuffs = val end
                ns.P("Track Raid Buffs: " .. (val and "|cFF44FF44ON|r" or "|cFFFF4444OFF|r"))
            end
        )

        -- Announce style section
        yOff = yOff - 56
        local styleHeader = ns.MakeSectionHeader(buffPane, "Announce Style")
        styleHeader:SetPoint("TOPLEFT", buffPane, "TOPLEFT", 0, yOff)
        styleHeader:SetPoint("RIGHT", buffPane, "RIGHT", 0, 0)

        yOff = yOff - 28
        local styleBuffBtn = ns.MakePill(buffPane, "By Buff")
        styleBuffBtn:SetWidth(90)
        styleBuffBtn:SetPoint("TOPLEFT", buffPane, "TOPLEFT", 4, yOff)

        local styleCatBtn = ns.MakePill(buffPane, "By Category")
        styleCatBtn:SetWidth(110)
        styleCatBtn:SetPoint("LEFT", styleBuffBtn, "RIGHT", 6, 0)

        local stylePlayerBtn = ns.MakePill(buffPane, "By Player")
        stylePlayerBtn:SetWidth(100)
        stylePlayerBtn:SetPoint("LEFT", styleCatBtn, "RIGHT", 6, 0)

        local function UpdateStyleButtons()
            local style = ns.db and ns.db.settings and ns.db.settings.announceStyle or "buff"
            styleBuffBtn:SetActive(style == "buff")
            styleCatBtn:SetActive(style == "category")
            stylePlayerBtn:SetActive(style == "player")
        end

        styleBuffBtn:SetScript("OnClick", function()
            if ns.db and ns.db.settings then ns.db.settings.announceStyle = "buff" end
            UpdateStyleButtons()
            ns.P("Announce style: |cFFFFCC00By Buff|r")
        end)
        styleCatBtn:SetScript("OnClick", function()
            if ns.db and ns.db.settings then ns.db.settings.announceStyle = "category" end
            UpdateStyleButtons()
            ns.P("Announce style: |cFFFFCC00By Category|r")
        end)
        stylePlayerBtn:SetScript("OnClick", function()
            if ns.db and ns.db.settings then ns.db.settings.announceStyle = "player" end
            UpdateStyleButtons()
            ns.P("Announce style: |cFFFFCC00By Player|r")
        end)

        buffPane.Refresh = function()
            trackFlaskToggle.Refresh()
            trackFoodToggle.Refresh()
            trackRaidToggle.Refresh()
            UpdateStyleButtons()
        end
    end

    --------------------------------------------------------------------
    -- Compact View tab
    --------------------------------------------------------------------
    local compactPane = MakePane(sp)
    spTabPanes["Compact View"] = compactPane

    do
        local yOff = -8
        local transparencyHeader = ns.MakeSectionHeader(compactPane, "Transparency")
        transparencyHeader:SetPoint("TOPLEFT", compactPane, "TOPLEFT", 0, yOff)
        transparencyHeader:SetPoint("RIGHT", compactPane, "RIGHT", 0, 0)

        yOff = yOff - 28
        local alphaValue = compactPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        alphaValue:SetPoint("TOPRIGHT", compactPane, "TOPRIGHT", -4, yOff)
        alphaValue:SetTextColor(0.7, 0.85, 1)

        yOff = yOff - 12
        local slider = CreateFrame("Slider", "RaidLeadCompactAlphaSlider", compactPane, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", compactPane, "TOPLEFT", 8, yOff)
        slider:SetSize(280, 16)
        slider:SetMinMaxValues(0.3, 1.0)
        slider:SetValueStep(0.05)
        slider:SetObeyStepOnDrag(true)
        slider:SetValue(ns.db and ns.db.settings and ns.db.settings.compactAlpha or 0.92)
        if _G[slider:GetName() .. "Low"] then _G[slider:GetName() .. "Low"]:SetText("30%") end
        if _G[slider:GetName() .. "High"] then _G[slider:GetName() .. "High"]:SetText("100%") end
        if _G[slider:GetName() .. "Text"] then _G[slider:GetName() .. "Text"]:SetText("") end

        local function UpdateAlphaValueText(v)
            alphaValue:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        end
        UpdateAlphaValueText(slider:GetValue())

        slider:SetScript("OnValueChanged", function(self, value)
            if not ns.db or not ns.db.settings then return end
            ns.db.settings.compactAlpha = value
            UpdateAlphaValueText(value)
            if ns.db.settings.compactMode and ns.mainFrame then
                ns.mainFrame:SetAlpha(value)
            end
        end)

        -- Show in compact view section
        yOff = yOff - 36
        local sectionHeader = ns.MakeSectionHeader(compactPane, "Show in Compact View")
        sectionHeader:SetPoint("TOPLEFT", compactPane, "TOPLEFT", 0, yOff)
        sectionHeader:SetPoint("RIGHT", compactPane, "RIGHT", 0, 0)

        yOff = yOff - 26
        local compactBossToggle = ns.CreateToggle(compactPane, yOff,
            "Boss assignments",
            "Display the active boss's assignments.",
            function() return ns.db and ns.db.settings and ns.db.settings.compactShowBoss or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.compactShowBoss = val end
                if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
            end
        )

        yOff = yOff - 44
        local compactHealersToggle = ns.CreateToggle(compactPane, yOff,
            "Healer assignments",
            "Display global healer assignments.",
            function() return ns.db and ns.db.settings and ns.db.settings.compactShowHealers or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.compactShowHealers = val end
                if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
            end
        )

        yOff = yOff - 44
        local compactMDToggle = ns.CreateToggle(compactPane, yOff,
            "Misdirect assignments",
            "Display hunter misdirect assignments.",
            function() return ns.db and ns.db.settings and ns.db.settings.compactShowMisdirects or false end,
            function(val)
                if ns.db and ns.db.settings then ns.db.settings.compactShowMisdirects = val end
                if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
            end
        )

        compactPane.Refresh = function()
            compactBossToggle.Refresh()
            compactHealersToggle.Refresh()
            compactMDToggle.Refresh()
            if ns.db and ns.db.settings then
                slider:SetValue(ns.db.settings.compactAlpha or 0.92)
                UpdateAlphaValueText(ns.db.settings.compactAlpha or 0.92)
            end
        end
    end

    --------------------------------------------------------------------
    -- On show: refresh active pane and default to General
    --------------------------------------------------------------------
    sp:SetScript("OnShow", function()
        for _, pane in pairs(spTabPanes) do
            if pane.Refresh then pane.Refresh() end
        end
        ShowSpTab(activeSpTab or "General")
    end)
    -- Initialise default tab so the first OnShow shows General
    ShowSpTab("General")
end
