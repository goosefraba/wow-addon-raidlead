----------------------------------------------------------------------
-- RaidLead - UI/RoleCheckDialog.lua
-- Popup shown when a raid peer broadcasts a ROLE_CHECK. Modeled
-- loosely on the in-game LFD role check: four role buttons (the
-- current selection is pre-highlighted), plus Confirm / Skip.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local dialog
local senderText
local roleButtons = {}
local confirmBtn
local selected

----------------------------------------------------------------------
-- Visual update: highlight the currently-selected role + enable
-- Confirm only when a selection exists.
----------------------------------------------------------------------
local function UpdateButtons()
    for key, btn in pairs(roleButtons) do
        if btn.selectGlow then
            btn.selectGlow:SetShown(key == selected)
        end
        if btn.SetBackdropBorderColor then
            if key == selected then
                btn:SetBackdropBorderColor(1, 0.82, 0.1, 1)
            else
                btn:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
            end
        end
    end
    if confirmBtn then
        if selected then
            confirmBtn:Enable()
        else
            confirmBtn:Disable()
        end
    end
end

----------------------------------------------------------------------
-- Build dialog lazily on first show
----------------------------------------------------------------------
local function Build()
    if dialog then return end

    dialog = CreateFrame("Frame", "RaidLeadRoleCheckDialog", UIParent)
    dialog:SetSize(400, 180)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetFrameLevel(100)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", function(s) s:StartMoving()        end)
    dialog:SetScript("OnDragStop",  function(s) s:StopMovingOrSizing() end)
    dialog:Hide()

    ns.ApplyBackdrop(dialog, ns.DIALOG_BACKDROP)

    -- Close X
    local closeBtn = CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -2, -2)

    -- Title
    local title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dialog, "TOP", 0, -14)
    title:SetText("|cFFFFCC00Role Check|r")

    -- Sender line (filled in on Show)
    senderText = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    senderText:SetPoint("TOPLEFT",  dialog, "TOPLEFT",  16, -36)
    senderText:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -16, -36)
    senderText:SetJustifyH("CENTER")
    senderText:SetTextColor(0.85, 0.85, 0.85)
    senderText:SetWordWrap(true)

    -- Grow the dialog vertically so the tiles fit comfortably
    dialog:SetSize(420, 240)

    -- Row of 4 role-tile buttons (icon on top, label below)
    local btnRow = CreateFrame("Frame", nil, dialog)
    btnRow:SetSize(400, 90)
    btnRow:SetPoint("TOP", senderText, "BOTTOM", 0, -18)

    local BTN_W    = 88
    local BTN_H    = 88
    local BTN_GAP  = 10
    local ICON_SIZE = 44
    local totalW   = 4 * BTN_W + 3 * BTN_GAP
    local startX   = (400 - totalW) / 2

    for i, key in ipairs(ns.Roles.ROLE_KEYS) do
        local label = ns.Roles.ROLE_LABELS[key]
        local color = ns.Roles.ROLE_COLORS[key]

        -- Plain Button (no UIPanelButtonTemplate red textures), styled as a tile
        local btn = CreateFrame("Button", nil, btnRow)
        btn:SetSize(BTN_W, BTN_H)
        btn:SetPoint("LEFT", btnRow, "LEFT", startX + (i - 1) * (BTN_W + BTN_GAP), 0)
        btn:EnableMouse(true)
        btn:RegisterForClicks("LeftButtonUp")

        ns.ApplyBackdrop(btn, {
            backdrop = {
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 8, edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 },
            },
            color = { 0.08, 0.08, 0.10, 0.95 },
        })

        -- Hover highlight (subtle white wash)
        local hover = btn:CreateTexture(nil, "BORDER")
        hover:SetPoint("TOPLEFT",     btn, "TOPLEFT",     3, -3)
        hover:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        hover:SetColorTexture(1, 1, 1, 0.08)
        hover:Hide()
        btn.hover = hover

        -- Selection highlight (gold wash, shown when this role is picked)
        local glow = btn:CreateTexture(nil, "BORDER")
        glow:SetPoint("TOPLEFT",     btn, "TOPLEFT",     3, -3)
        glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
        glow:SetColorTexture(1, 0.82, 0.1, 0.18)
        glow:Hide()
        btn.selectGlow = glow

        -- Role icon, centered horizontally near the top
        local icon = ns.Roles.MakeRoleIcon(btn, key, ICON_SIZE)
        icon:SetPoint("TOP", btn, "TOP", 0, -10)

        -- Label under the icon
        local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lbl:SetPoint("BOTTOM", btn, "BOTTOM", 0, 8)
        lbl:SetText("|c" .. color .. label .. "|r")

        btn:SetScript("OnEnter", function() hover:Show() end)
        btn:SetScript("OnLeave", function() hover:Hide() end)
        btn:SetScript("OnClick", function()
            selected = key
            UpdateButtons()
        end)
        roleButtons[key] = btn
    end

    -- Bottom buttons (Confirm / Skip)
    confirmBtn = ns.MakeSmallButton(dialog, "Confirm", 110, 24)
    confirmBtn:SetPoint("BOTTOMRIGHT", dialog, "BOTTOM", -6, 14)
    confirmBtn:SetScript("OnClick", function()
        if selected and ns.Roles then
            ns.Roles.SetMyRole(selected)
            if ns.UpdateMyRoleButton then ns.UpdateMyRoleButton() end
            if ns.RefreshGridTab     then ns.RefreshGridTab()     end
            if ns.RefreshHealAssign  then ns.RefreshHealAssign()  end
            if ns.RefreshRolesRoster then ns.RefreshRolesRoster() end
            ns.P("|cFF44FF44Role confirmed:|r "
                .. (ns.Roles.ROLE_LABELS[selected] or selected))
        end
        dialog:Hide()
    end)

    local skipBtn = ns.MakeSmallButton(dialog, "Skip", 80, 24)
    skipBtn:SetPoint("BOTTOMLEFT", dialog, "BOTTOM", 6, 14)
    skipBtn:SetScript("OnClick", function() dialog:Hide() end)
end

----------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------
function ns.ShowRoleCheckDialog(senderName)
    if not ns.Roles then return end
    Build()

    selected = ns.Roles.GetMyRole()

    if senderName and senderName ~= "" then
        senderText:SetText("|cFFFFCC00" .. senderName
            .. "|r asked everyone to confirm their role.")
    else
        senderText:SetText("Please confirm your role.")
    end

    UpdateButtons()
    dialog:Show()

    -- Optional audio cue (silently no-op if unavailable)
    if PlaySound then pcall(PlaySound, 880) end
end
