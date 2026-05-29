----------------------------------------------------------------------
-- RaidLead — Modules/BossData/MagtheridonsLair.lua
-- Magtheridon's Lair boss definitions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Magtheridon — main tank + 5 cube clickers for Blast Nova
----------------------------------------------------------------------
ns.BossRegistry:Register("magtheridon", {
    name         = "Magtheridon",
    instance     = "Magtheridon's Lair",
    templateType = "tank_cubes",
    mainTank = {
        label = "Main Tank",
        tip   = "Tanks Magtheridon in the center. Cleave Armor stacks - rotate with OT if available.",
        color = { 0.9, 0.2, 0.2 },
    },
    -- 5 cube slots, keyed by raid icon. Mark Hellfire Channelers with these
    -- icons in phase 1; the clicker for [icon] takes the cube where that
    -- channeler stood in phase 2. All 5 share the mob name, so Auto-Mark
    -- assigns icons to the first 5 channelers it finds in range.
    cubes = {
        { key = "skull",    iconIdx = 8, label = "Skull",    mob = "Hellfire Channeler" },
        { key = "cross",    iconIdx = 7, label = "Cross",    mob = "Hellfire Channeler" },
        { key = "square",   iconIdx = 6, label = "Square",   mob = "Hellfire Channeler" },
        { key = "moon",     iconIdx = 5, label = "Moon",     mob = "Hellfire Channeler" },
        { key = "triangle", iconIdx = 4, label = "Triangle", mob = "Hellfire Channeler" },
    },
    notes = "Mark Hellfire Channelers in phase 1. Clicker for each icon takes the cube where that channeler stood.",
})
