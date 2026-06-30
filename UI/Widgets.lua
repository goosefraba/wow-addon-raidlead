----------------------------------------------------------------------
-- RaidLead — UI/Widgets.lua
-- Reusable widget factories: backdrop, buttons, toggles, headers
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Backdrop compatibility wrapper
----------------------------------------------------------------------
function ns.ApplyBackdrop(frame, config)
    if BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        frame:OnBackdropLoaded()
    end
    if frame.SetBackdrop then
        frame:SetBackdrop(config.backdrop)
        if config.color then
            frame:SetBackdropColor(unpack(config.color))
        end
    end
end

-- Main panel backdrop - clean dark panel with thin tooltip-style border.
-- (The old ornate stone/dialog border is replaced with a modern look.)
ns.DIALOG_BACKDROP = {
    backdrop = {
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 14,
        insets = { left = 5, right = 5, top = 5, bottom = 5 },
    },
    color = { 0.06, 0.06, 0.09, 0.94 },
}

ns.DIALOG_BACKDROP_SMALL = {
    backdrop = {
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    },
    color = { 0.05, 0.05, 0.08, 0.96 },
}

ns.ROW_BACKDROP = {
    backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    },
}

-- Compact mode: minimal thin border
ns.COMPACT_BACKDROP = {
    backdrop = {
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    },
    color = { 0, 0, 0, 0.7 },
}

----------------------------------------------------------------------
-- Header text factory (column header in grid views)
----------------------------------------------------------------------
function ns.MakeHeader(parent, text, xOff, width)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", xOff, -2)
    fs:SetWidth(width or 80)
    fs:SetJustifyH("LEFT")
    fs:SetText("|cFFFFCC00" .. text .. "|r")
    return fs
end

----------------------------------------------------------------------
-- Pill button - flat, dark, with an active state (used for segmented
-- toggles like "Assignments | Roster"). The pill grows to fit its
-- label; callers may override width with SetWidth().
--
-- Active state uses our amber palette so it visually matches the
-- gold/orange accent of the rest of the addon. Inactive is a muted
-- dark slate.
----------------------------------------------------------------------
local PILL_BG_INACTIVE = { 0.10, 0.10, 0.12, 0.85 }
local PILL_BG_ACTIVE   = { 0.62, 0.42, 0.10, 0.95 }  -- warm amber
local PILL_TXT_INACTIVE = { 0.65, 0.65, 0.62 }
local PILL_TXT_ACTIVE   = { 1.00, 0.96, 0.85 }       -- warm cream

function ns.MakePill(parent, label)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp")

    ns.ApplyBackdrop(b, {
        backdrop = {
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        color = PILL_BG_INACTIVE,
    })

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(label or "")
    fs:SetTextColor(unpack(PILL_TXT_INACTIVE))
    b.text = fs

    -- Auto-size to label (minimum width 40)
    b:SetWidth(math.max(40, fs:GetStringWidth() + 20))

    function b:SetActive(active)
        if active then
            self:SetBackdropColor(unpack(PILL_BG_ACTIVE))
            self.text:SetTextColor(unpack(PILL_TXT_ACTIVE))
        else
            self:SetBackdropColor(unpack(PILL_BG_INACTIVE))
            self.text:SetTextColor(unpack(PILL_TXT_INACTIVE))
        end
        self._active = active and true or false
    end

    function b:IsActive() return self._active end

    -- Subtle hover - brighten slightly when not already active
    b:SetScript("OnEnter", function(self)
        if not self._active then
            self:SetBackdropColor(0.18, 0.16, 0.14, 0.95)
            self.text:SetTextColor(0.85, 0.82, 0.75)
        end
    end)
    b:SetScript("OnLeave", function(self)
        if not self._active then
            self:SetBackdropColor(unpack(PILL_BG_INACTIVE))
            self.text:SetTextColor(unpack(PILL_TXT_INACTIVE))
        end
    end)

    return b
end

----------------------------------------------------------------------
-- Small button - flat dark backdrop, no UIPanelButtonTemplate red.
-- Used for action buttons (Announce, Clear, Auto-Assign, etc.).
-- Accepts both left- and right-button clicks (callers can dispatch on
-- the `button` arg in their OnClick handler).
----------------------------------------------------------------------
local SMALL_BG_NORMAL = { 0.15, 0.15, 0.18, 0.92 }
local SMALL_BG_HOVER  = { 0.28, 0.22, 0.12, 0.95 }  -- amber tint
local SMALL_TXT       = { 0.92, 0.92, 0.88 }

function ns.MakeSmallButton(parent, label, w, h)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 90, h or 22)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    ns.ApplyBackdrop(b, {
        backdrop = {
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 10,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        color = SMALL_BG_NORMAL,
    })

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(label or "")
    fs:SetTextColor(unpack(SMALL_TXT))
    b.text = fs

    -- Mirror common UIPanelButtonTemplate methods so callers can drop
    -- this in without touching their refresh code.
    function b:SetText(t) self.text:SetText(t or "") end
    function b:GetText()  return self.text:GetText()  end

    b._enabled = true
    function b:Enable()
        self._enabled = true
        self:EnableMouse(true)
        self.text:SetTextColor(unpack(SMALL_TXT))
        self:SetBackdropColor(unpack(SMALL_BG_NORMAL))
    end
    function b:Disable()
        self._enabled = false
        self:EnableMouse(false)
        self.text:SetTextColor(0.45, 0.45, 0.42)
        self:SetBackdropColor(0.10, 0.10, 0.12, 0.75)
    end
    function b:IsEnabled() return self._enabled end

    b:SetScript("OnEnter", function(self)
        if self._enabled ~= false then
            self:SetBackdropColor(unpack(SMALL_BG_HOVER))
        end
    end)
    b:SetScript("OnLeave", function(self)
        if self._enabled ~= false then
            self:SetBackdropColor(unpack(SMALL_BG_NORMAL))
        end
    end)

    return b
end

----------------------------------------------------------------------
-- Target Sweep toggle button. Drives ns.MarkSweep (Core/Utils.lua):
-- click to start, then target / mouse over each marked mob (no range
-- limit), click again to stop. onUpdate is called whenever a new mark is
-- captured so the caller can refresh its detected-mob labels live.
----------------------------------------------------------------------
function ns.MakeSweepButton(parent, onUpdate, w)
    local btn = ns.MakeSmallButton(parent, "Target Sweep", w or 110, 22)
    local function sync()
        if ns.MarkSweep and ns.MarkSweep.active then
            btn:SetText("|cFFFF6666Stop Sweep|r")
        else
            btn:SetText("Target Sweep")
        end
    end
    btn:SetScript("OnClick", function()
        if not ns.MarkSweep then return end
        if ns.MarkSweep.active then
            ns.MarkSweep.Stop()
        else
            ns.MarkSweep.Start(onUpdate)
        end
        sync()
    end)
    btn:HookScript("OnShow", sync)
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Target Sweep", 1, 0.82, 0.1)
        GameTooltip:AddLine("For marks that are too far for the normal scan. "
            .. "Click, then target (or mouse over) each marked enemy one at a "
            .. "time - their icons fill in here. Click again to stop.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    btn.SyncSweepLabel = sync
    return btn
end

----------------------------------------------------------------------
-- Section header bar — for "Healers", "Compact View", boss sections etc.
-- Returns a Frame with:
--   - subtle dark background
--   - colored accent stripe on the left
--   - thin gold underline
--   - title text on the left
-- Caller positions it with SetPoint(...) and may anchor other widgets to it.
----------------------------------------------------------------------
function ns.MakeSectionHeader(parent, text, opts)
    opts = opts or {}
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(opts.height or 20)

    -- Background bar
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.15, 0.55)

    -- Bottom underline (gold accent)
    local line = h:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 0, 0)
    line:SetColorTexture(1, 0.82, 0, 0.45)

    -- Left accent stripe
    local accent = h:CreateTexture(nil, "ARTWORK")
    accent:SetWidth(3)
    accent:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", 0, 0)
    accent:SetColorTexture(1, 0.82, 0, 0.95)

    -- Title text
    local fs = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("LEFT", h, "LEFT", 8, 0)
    fs:SetText(text)
    fs:SetTextColor(1, 0.92, 0.55)
    h.text = fs

    return h
end

----------------------------------------------------------------------
-- Announce button factory
----------------------------------------------------------------------
function ns.MakeAnnounceBtn(parent, anchor, anchorPoint, xOff, label, tooltipTitle, mode)
    local btn = ns.MakeSmallButton(parent, label, label:len() * 7 + 20, 22)
    if type(anchor) == "string" then
        btn:SetPoint("LEFT", parent, anchor, xOff, 0)
    else
        btn:SetPoint("LEFT", anchor, anchorPoint, xOff, 0)
    end
    btn:SetScript("OnClick", function(self, button)
        ns.D("Button clicked: " .. tostring(label) .. " mode=" .. tostring(mode) .. " button=" .. tostring(button))
        if button == "RightButton" then
            ns.ShowAnnounceMenu(mode)
        else
            local ok, err = pcall(ns.BuffScan.Announce, nil, mode)
            if not ok then
                ns.P("|cFFFF4444Error:|r " .. tostring(err))
            end
        end
    end)
    -- HookScript so the amber-tint hover baked into MakeSmallButton still fires
    btn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(tooltipTitle, 1, 0.82, 0.1)
        GameTooltip:AddLine("Left-click: auto (raid/party)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right-click: choose channel", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    return btn
end

----------------------------------------------------------------------
-- Settings toggle factory
----------------------------------------------------------------------
function ns.CreateToggle(parent, yOffset, label, description, getter, setter)
    local row = CreateFrame("CheckButton", nil, parent)
    row:SetSize(24, 24)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    row:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    row:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    row:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
    row:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")

    local lbl = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lbl:SetPoint("LEFT", row, "RIGHT", 4, 0)
    lbl:SetText(label)

    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", lbl, "BOTTOMLEFT", 0, -2)
    desc:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("|cFF888888" .. description .. "|r")
    desc:SetWordWrap(true)

    row:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
    end)
    row.Refresh = function()
        row:SetChecked(getter())
    end
    return row
end

----------------------------------------------------------------------
-- Raid target icon helpers
----------------------------------------------------------------------
ns.RAID_ICON_NAMES = {
    [1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle",
    [5] = "Moon", [6] = "Square", [7] = "Cross",   [8] = "Skull",
}

function ns.GetRaidIconTexture(index)
    if not index or index < 1 or index > 8 then return nil end
    return "Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. index
end

-- Text marker for chat (uses WoW's built-in raid icon tokens)
function ns.GetRaidIconText(index)
    if not index or index < 1 or index > 8 then return "" end
    return "{rt" .. index .. "}"
end

----------------------------------------------------------------------
-- Raid icon picker button
-- Click to open a grid of the 8 raid target icons + clear
-- onSelect(iconIndex) — nil for clear
----------------------------------------------------------------------
function ns.CreateRaidIconPicker(parent, size, onSelect)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)

    ns.ApplyBackdrop(btn, {
        backdrop = {
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        color = { 0.1, 0.1, 0.13, 0.9 },
    })

    btn.selected = nil

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 3, -3)
    btn.icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
    btn.icon:Hide()

    btn.placeholder = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.placeholder:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn.placeholder:SetText("?")
    btn.placeholder:SetTextColor(0.5, 0.5, 0.5)

    function btn:SetIcon(iconIndex)
        btn.selected = iconIndex
        if iconIndex then
            btn.icon:SetTexture(ns.GetRaidIconTexture(iconIndex))
            btn.icon:Show()
            btn.placeholder:Hide()
        else
            btn.icon:Hide()
            btn.placeholder:Show()
        end
    end

    btn:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.15, 0.15, 0.2, 1)
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if btn.selected then
            GameTooltip:AddLine(ns.RAID_ICON_NAMES[btn.selected] or "Icon", 1, 1, 1)
        else
            GameTooltip:AddLine("Click to set raid icon", 1, 0.82, 0)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.1, 0.1, 0.13, 0.9)
        end
        GameTooltip:Hide()
    end)

    -- Popup picker: 8 icons in a 4x2 grid
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(200)
    popup:EnableMouse(true)
    popup:Hide()

    ns.ApplyBackdrop(popup, {
        backdrop = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        color = { 0.05, 0.05, 0.08, 0.97 },
    })

    local ICON_SIZE = 28
    local ICON_PAD  = 4
    local PAD       = 6

    -- 8 icons in 4x2 grid
    for i = 1, 8 do
        local col = ((i - 1) % 4)
        local row = math.floor((i - 1) / 4)
        local iconBtn = CreateFrame("Button", nil, popup)
        iconBtn:SetSize(ICON_SIZE, ICON_SIZE)
        iconBtn:SetPoint("TOPLEFT", popup, "TOPLEFT",
            PAD + col * (ICON_SIZE + ICON_PAD),
            -PAD - row * (ICON_SIZE + ICON_PAD))

        local tex = iconBtn:CreateTexture(nil, "ARTWORK")
        tex:SetAllPoints()
        tex:SetTexture(ns.GetRaidIconTexture(i))

        iconBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

        local idx = i
        iconBtn:SetScript("OnClick", function()
            btn:SetIcon(idx)
            if onSelect then onSelect(idx) end
            popup:Hide()
        end)
        iconBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(ns.RAID_ICON_NAMES[idx], 1, 1, 1)
            GameTooltip:Show()
        end)
        iconBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- "Clear" button below the grid
    local clearBtn = ns.MakeSmallButton(popup, "Clear",
        4 * (ICON_SIZE + ICON_PAD) - ICON_PAD, 20)
    clearBtn:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, -PAD - 2 * (ICON_SIZE + ICON_PAD))
    clearBtn:SetScript("OnClick", function()
        btn:SetIcon(nil)
        if onSelect then onSelect(nil) end
        popup:Hide()
    end)

    local popupW = 4 * ICON_SIZE + 3 * ICON_PAD + PAD * 2
    local popupH = 2 * ICON_SIZE + ICON_PAD + PAD * 2 + 24
    popup:SetSize(popupW, popupH)

    -- Capture outside clicks
    local capture
    btn:SetScript("OnClick", function(self)
        -- Honor lock state if this picker is part of a boss config
        if btn.respectLock and ns.BossTemplates and ns.BossTemplates.IsLocked() then
            ns.LockedNotice()
            return
        end
        if popup:IsShown() then
            popup:Hide()
            return
        end
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        popup:Show()

        capture = CreateFrame("Button", nil, UIParent)
        capture:SetFrameStrata("FULLSCREEN_DIALOG")
        capture:SetFrameLevel(199)
        capture:SetAllPoints(UIParent)
        capture:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        capture:SetScript("OnClick", function()
            popup:Hide()
            capture:Hide()
        end)
    end)

    popup:SetScript("OnHide", function()
        if capture then capture:Hide() end
    end)

    return btn
end

----------------------------------------------------------------------
-- Simple context menu popup (replacement for EasyMenu)
-- items = { { text=, func=, isTitle=, disabled= }, ... }
----------------------------------------------------------------------
local activeContextMenu = nil

function ns.ShowContextMenu(items, anchorMode, xOff, yOff)
    if activeContextMenu then
        activeContextMenu:Hide()
        activeContextMenu = nil
    end

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(200)
    popup:EnableMouse(true)
    popup:Hide()  -- start hidden, show after deferred to avoid eating the triggering click

    ns.ApplyBackdrop(popup, {
        backdrop = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        color = { 0.05, 0.05, 0.08, 0.97 },
    })

    local ITEM_HEIGHT = 18
    local PAD = 6
    local width = 180  -- will grow

    local buttons = {}
    local y = -PAD
    for i, item in ipairs(items) do
        local itemBtn = CreateFrame("Button", nil, popup)
        itemBtn:SetHeight(ITEM_HEIGHT)
        itemBtn:SetPoint("TOPLEFT", popup, "TOPLEFT", PAD, y)
        itemBtn:SetPoint("RIGHT", popup, "RIGHT", -PAD, 0)

        local fs = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", itemBtn, "LEFT", 4, 0)
        fs:SetJustifyH("LEFT")

        if item.isTitle then
            fs:SetText("|cFFFFCC00" .. item.text .. "|r")
            itemBtn:Disable()
        elseif item.disabled then
            fs:SetText("|cFF888888" .. item.text .. "|r")
            itemBtn:Disable()
        else
            fs:SetText(item.text)
            itemBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            local fn = item.func
            itemBtn:SetScript("OnClick", function()
                if fn then fn() end
                popup:Hide()
                if activeContextMenu == popup then activeContextMenu = nil end
            end)
        end

        -- Measure width from string
        local strW = fs:GetStringWidth() + 24
        if strW > width then width = strW end

        buttons[i] = itemBtn
        y = y - ITEM_HEIGHT
    end

    popup:SetSize(width + PAD * 2, -y + PAD)

    -- Position
    if anchorMode == "cursor" then
        local cx, cy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cx / scale + (xOff or 0), cy / scale + (yOff or 0))
    end

    -- Defer Show() + capture creation by one frame so the click that
    -- triggered us doesn't immediately get caught by the new popup/capture
    -- and dismiss it.
    local capture
    C_Timer.After(0, function()
        if not popup then return end
        popup:Show()
        activeContextMenu = popup

        capture = CreateFrame("Button", nil, UIParent)
        capture:SetFrameStrata("FULLSCREEN_DIALOG")
        capture:SetFrameLevel(199)
        capture:SetAllPoints(UIParent)
        capture:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        capture:SetScript("OnClick", function()
            popup:Hide()
            capture:Hide()
            if activeContextMenu == popup then activeContextMenu = nil end
        end)
    end)

    popup:SetScript("OnHide", function()
        if capture then capture:Hide() end
        if activeContextMenu == popup then activeContextMenu = nil end
    end)

    return popup
end

----------------------------------------------------------------------
-- Player dropdown button
-- Creates a button that shows a scrollable player list on click
----------------------------------------------------------------------
local activeDropdown = nil  -- only one open at a time

local function CloseActiveDropdown()
    if activeDropdown then
        activeDropdown:Hide()
        activeDropdown = nil
    end
end

function ns.CreatePlayerDropdown(parent, width, onSelect)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, 22)

    -- Background
    ns.ApplyBackdrop(btn, {
        backdrop = {
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 8, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        color = { 0.1, 0.1, 0.13, 0.9 },
    })

    btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.label:SetPoint("LEFT", btn, "LEFT", 6, 0)
    btn.label:SetPoint("RIGHT", btn, "RIGHT", -16, 0)
    btn.label:SetJustifyH("LEFT")
    btn.label:SetText("(none)")
    btn.label:SetTextColor(0.53, 0.53, 0.53)
    btn.label:SetWordWrap(false)

    -- Arrow indicator
    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -4, 0)
    arrow:SetText("v")
    arrow:SetTextColor(0.67, 0.67, 0.67)

    btn.selectedName = nil

    -- Look up RGB from class colors hex
    local ClassColorRGB = ns.ClassColorRGB

    function btn:SetSelectedPlayer(name, class)
        if name then
            btn.selectedName = name
            btn.label:SetText(name)
            btn.label:SetTextColor(ClassColorRGB(class or "UNKNOWN"))
        else
            btn.selectedName = nil
            btn.label:SetText("(none)")
            btn.label:SetTextColor(0.53, 0.53, 0.53)
        end
    end

    -- Hover effect
    btn:SetScript("OnEnter", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.15, 0.15, 0.2, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if self.SetBackdropColor then
            self:SetBackdropColor(0.1, 0.1, 0.13, 0.9)
        end
    end)

    -- Create the dropdown popup (shared logic)
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetSize(width, 200)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(100)
    popup:EnableMouse(true)
    popup:Hide()

    ns.ApplyBackdrop(popup, {
        backdrop = {
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        },
        color = { 0.05, 0.05, 0.08, 0.97 },
    })

    local ITEM_HEIGHT = 18
    local popupContent = CreateFrame("Frame", nil, popup)
    popupContent:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -4)
    popupContent:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -4, 4)

    local popupScroll = CreateFrame("ScrollFrame", nil, popupContent, "FauxScrollFrameTemplate")
    popupScroll:SetPoint("TOPLEFT", popupContent, "TOPLEFT", 0, 0)
    popupScroll:SetPoint("BOTTOMRIGHT", popupContent, "BOTTOMRIGHT", -16, 0)

    local popupInner = CreateFrame("Frame", nil, popupContent)
    popupInner:SetPoint("TOPLEFT", popupContent, "TOPLEFT", 0, 0)
    popupInner:SetPoint("BOTTOMRIGHT", popupContent, "BOTTOMRIGHT", -16, 0)

    local itemButtons = {}
    popup.roster = {}

    local function RefreshPopup()
        local roster = popup.roster
        local parentH = popupInner:GetHeight()
        local visibleRows = math.max(1, math.floor(parentH / ITEM_HEIGHT))
        local total = #roster + 1  -- +1 for "Clear" option

        FauxScrollFrame_Update(popupScroll, total, visibleRows, ITEM_HEIGHT)
        local offset = FauxScrollFrame_GetOffset(popupScroll)

        for i = 1, visibleRows do
            local itemBtn = itemButtons[i]
            if not itemBtn then
                itemBtn = CreateFrame("Button", nil, popupInner)
                itemBtn:SetHeight(ITEM_HEIGHT)
                itemBtn:SetPoint("TOPLEFT", popupInner, "TOPLEFT", 0, -((i - 1) * ITEM_HEIGHT))
                itemBtn:SetPoint("RIGHT", popupInner, "RIGHT", 0, 0)

                itemBtn.text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                itemBtn.text:SetPoint("LEFT", itemBtn, "LEFT", 6, 0)
                itemBtn.text:SetJustifyH("LEFT")

                itemBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

                itemButtons[i] = itemBtn
            end

            local dataIdx = offset + i
            if dataIdx <= total then
                if dataIdx == 1 then
                    -- "Clear" option
                    itemBtn.text:SetText("(clear)")
                    itemBtn.text:SetTextColor(0.53, 0.53, 0.53)
                    itemBtn:SetScript("OnClick", function()
                        btn:SetSelectedPlayer(nil, nil)
                        onSelect(nil)
                        CloseActiveDropdown()
                    end)
                else
                    local entry = roster[dataIdx - 1]
                    itemBtn.text:SetText(entry.name)
                    itemBtn.text:SetTextColor(ClassColorRGB(entry.class))
                    itemBtn:SetScript("OnClick", function()
                        btn:SetSelectedPlayer(entry.name, entry.class)
                        onSelect(entry.name)
                        CloseActiveDropdown()
                    end)
                end
                itemBtn:Show()
            else
                itemBtn:Hide()
            end
        end

        for i2 = visibleRows + 1, #itemButtons do
            itemButtons[i2]:Hide()
        end
    end

    popupScroll:SetScript("OnVerticalScroll", function(self, off)
        FauxScrollFrame_OnVerticalScroll(self, off, ITEM_HEIGHT, RefreshPopup)
    end)

    btn:SetScript("OnClick", function(self)
        -- Honor lock state if this dropdown is part of a boss config
        if btn.respectLock and ns.BossTemplates and ns.BossTemplates.IsLocked() then
            ns.LockedNotice()
            return
        end

        if popup:IsShown() then
            CloseActiveDropdown()
            return
        end
        CloseActiveDropdown()

        -- Populate roster, optionally narrowed to specific classes
        -- (e.g. CC dropdowns only offer Mages/Warlocks).
        popup.roster = ns.BossTemplates.GetPlayerRoster()
        if btn.classFilter then
            local filtered = {}
            for _, e in ipairs(popup.roster) do
                if btn.classFilter[(e.class or ""):upper()] then
                    filtered[#filtered + 1] = e
                end
            end
            popup.roster = filtered
        end

        -- Position below the button
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

        -- Size: fit up to 12 items
        local itemCount = #popup.roster + 1
        local visH = math.min(itemCount, 12) * ITEM_HEIGHT + 10
        popup:SetSize(width, visH)

        popup:Show()
        activeDropdown = popup
        RefreshPopup()
    end)

    -- Close when clicking outside
    popup:SetScript("OnHide", function()
        if activeDropdown == popup then activeDropdown = nil end
    end)

    -- Stash popup ref for external close
    btn.popup = popup

    return btn
end

----------------------------------------------------------------------
-- Poll result bars. Renders one horizontal bar per option (label + fill
-- + count/percent) into a pooled row table, packed top-to-bottom from
-- startY. Shared by the live Poll Results window and the History detail
-- popup so both look identical.
--   parent      frame to anchor rows into
--   pool        table reused across calls to hold the row frames
--   options     { "Yes", "No", ... }
--   counts      { [i] = n }   votes per option
--   voterTotal  distinct voters (for the percentage)
--   startY      y-offset of the first row's top edge (negative)
--   rowW        usable width (for scaling the fill)
----------------------------------------------------------------------
function ns.RenderPollBars(parent, pool, options, counts, voterTotal, startY, rowW)
    local ROW_H, GAP = 26, 4
    counts = counts or {}

    for _, r in ipairs(pool) do r:Hide() end

    local maxN = 0
    for _, n in pairs(counts) do if n and n > maxN then maxN = n end end

    for i, opt in ipairs(options) do
        local row = pool[i]
        if not row then
            local y = startY - (i - 1) * (ROW_H + GAP)
            row = CreateFrame("Frame", nil, parent)
            row:SetHeight(ROW_H)
            row:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, y)
            row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)

            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(0.10, 0.10, 0.13, 0.85)

            row.fill = row:CreateTexture(nil, "BORDER")
            row.fill:SetPoint("TOPLEFT",    row, "TOPLEFT",    0, 0)
            row.fill:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.fill:SetColorTexture(0.62, 0.42, 0.10, 0.85)

            row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
            row.label:SetWidth(180)
            row.label:SetJustifyH("LEFT")

            row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.count:SetPoint("RIGHT", row, "RIGHT", -8, 0)
            row.count:SetJustifyH("RIGHT")

            pool[i] = row
        end

        row.label:SetText(opt)
        local c   = counts[i] or 0
        local pct = (voterTotal > 0) and math.floor(c / voterTotal * 100 + 0.5) or 0
        row.count:SetText(string.format("%d  |cFF888888%d%%|r", c, pct))

        local frac = (maxN > 0) and (c / maxN) or 0
        row.fill:SetWidth(math.max(2, frac * (rowW or 280)))
        row:Show()
    end
end
