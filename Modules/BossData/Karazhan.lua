----------------------------------------------------------------------
-- RaidLead — Modules/BossData/Karazhan.lua
-- Karazhan boss definitions (starting with Netherspite)
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

ns.BossRegistry:Register("netherspite", {
    name          = "Netherspite",
    announceTitle = "Netherspite - Portal Beams",
    instance      = "Karazhan",
    templateType  = "portals",
    portals = {
        {
            key      = "red",
            label    = "Red",
            fullName = "Perseverance",
            tip      = "Tank beam - reduces damage taken, stacking DoT",
            color    = { 0.9, 0.2, 0.2 },
        },
        {
            key      = "green",
            label    = "Green",
            fullName = "Serenity",
            tip      = "Healer beam - heals soaker, stacking HoT",
            color    = { 0.2, 0.9, 0.2 },
        },
        {
            key      = "blue",
            label    = "Blue",
            fullName = "Dominance",
            tip      = "DPS/Mana beam - spell damage + mana, stacking debuff",
            color    = { 0.3, 0.4, 0.9 },
        },
    },
    phases = {
        { key = "phase1", label = "Phase 1" },
        { key = "phase2", label = "Phase 2" },
    },
    slotsPerPortal = { "Primary", "Secondary" },
    notes = "Rotate portal soakers each phase. Never let beams hit the boss.",
})
