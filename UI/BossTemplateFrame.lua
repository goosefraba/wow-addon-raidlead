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
        if ns.UpdateCompactDisplay then ns.UpdateCompactDisplay() end
        return
    end

    local bossData = ns.BossRegistry:Get(bossKey)
    if not bossData then return end

    if bossData.instance and bossData.instance ~= activeInstance then
        ShowInstance(bossData.instance, true)
    end

    bossDropBtn:SetText(bossData.name)

    local createFunc = ns.bossWidgets[bossKey]
    if createFunc then
        if not widgetContainer.widgets then widgetContainer.widgets = {} end
        if not widgetContainer.widgets[bossKey] then
            widgetContainer.widgets[bossKey] = createFunc(widgetContainer)
        end
        activeWidget = widgetContainer.widgets[bossKey]
        activeWidget:Show()
        if activeWidget.Refresh then activeWidget.Refresh() end
    else
        ns.D("No widget registered for boss: " .. bossKey)
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
-- Register the Boss tab
----------------------------------------------------------------------
ns.RegisterTab("Boss", 20, bossContent, RefreshBossTab)
