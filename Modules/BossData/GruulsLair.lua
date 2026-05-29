----------------------------------------------------------------------
-- RaidLead — Modules/BossData/GruulsLair.lua
-- Gruul's Lair + Magtheridon's Lair boss definitions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- High King Maulgar — council fight (5 enemies, tank + heal assignments)
----------------------------------------------------------------------
ns.BossRegistry:Register("maulgar", {
    name         = "High King Maulgar",
    instance     = "Gruul's Lair",
    templateType = "tank_heal",
    -- 5 icon-keyed rows. The `mob` field drives one-click Auto-Mark; icon
    -- order follows the kill order below. Use "Scan Marks" to verify.
    enemies = {
        { key = "skull",    iconIdx = 8, label = "Skull",    mob = "Krosh Firehand" },
        { key = "cross",    iconIdx = 7, label = "Cross",    mob = "Kiggler the Crazed" },
        { key = "square",   iconIdx = 6, label = "Square",   mob = "Blindeye the Seer" },
        { key = "moon",     iconIdx = 5, label = "Moon",     mob = "Olm the Summoner" },
        { key = "triangle", iconIdx = 4, label = "Triangle", mob = "High King Maulgar" },
    },
    notes = "Mark each council member with a raid icon. Kill order: Krosh > Kiggler > Blindeye > Olm > Maulgar. CC wolves.",
})
