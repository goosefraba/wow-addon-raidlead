----------------------------------------------------------------------
-- RaidLead - Modules/BossData/BossRegistry.lua
-- Registry for boss template definitions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

local BossRegistry = {
    bosses = {},        -- [bossKey] = bossData
    ordered = {},       -- { bossKey, ... } in registration order
    instances = {},     -- [instanceName] = { bossKey, ... }
    instanceOrder = {}, -- { instanceName, ... } in first-seen order
}
ns.BossRegistry = BossRegistry

function BossRegistry:Register(bossKey, bossData)
    if self.bosses[bossKey] then return end

    self.bosses[bossKey] = bossData
    self.ordered[#self.ordered + 1] = bossKey

    local instanceName = bossData.instance or "Other"
    if not self.instances[instanceName] then
        self.instances[instanceName] = {}
        self.instanceOrder[#self.instanceOrder + 1] = instanceName
    end
    self.instances[instanceName][#self.instances[instanceName] + 1] = bossKey

    ns.D("BossRegistry: registered " .. bossKey .. " in " .. instanceName)
end

function BossRegistry:Get(bossKey)
    return self.bosses[bossKey]
end

function BossRegistry:GetAll()
    return self.bosses, self.ordered
end

function BossRegistry:GetInstances()
    return self.instances, self.instanceOrder
end

function BossRegistry:GetBossesForInstance(instanceName)
    return self.instances[instanceName] or {}
end

function BossRegistry:GetFirstInstance()
    return self.instanceOrder[1]
end

function BossRegistry:GetFirstBossForInstance(instanceName)
    local bosses = self:GetBossesForInstance(instanceName)
    return bosses and bosses[1]
end
