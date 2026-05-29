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
    -- 5 icon-keyed rows. Mark each council member with an icon in-game,
    -- then click "Scan Marks" to map names to icons.
    enemies = {
        { key = "skull",    iconIdx = 8, label = "Skull" },
        { key = "cross",    iconIdx = 7, label = "Cross" },
        { key = "square",   iconIdx = 6, label = "Square" },
        { key = "moon",     iconIdx = 5, label = "Moon" },
        { key = "triangle", iconIdx = 4, label = "Triangle" },
    },
    notes = "Mark each council member with a raid icon. Kill order: Krosh > Kiggler > Blindeye > Olm > Maulgar. CC wolves.",
})
