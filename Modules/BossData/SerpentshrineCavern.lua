----------------------------------------------------------------------
-- RaidLead - Modules/BossData/SerpentshrineCavern.lua
-- Serpentshrine Cavern boss definitions
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Fathom-Lord Karathress - council fight, icon-keyed tank assignments
----------------------------------------------------------------------
ns.BossRegistry:Register("karathress", {
    name         = "Fathom-Lord Karathress",
    instance     = "Serpentshrine Cavern",
    templateType = "icon_tanks",
    enemies = {
        { key = "skull",    iconIdx = 8, label = "Skull" },
        { key = "cross",    iconIdx = 7, label = "Cross" },
        { key = "square",   iconIdx = 6, label = "Square" },
        { key = "moon",     iconIdx = 5, label = "Moon" },
    },
    notes = "Mark Karathress and the three guards. Assign one tank per marked target. Common kill order: Sharkkis > Tidalvess > Caribdis > Karathress.",
})

----------------------------------------------------------------------
-- Lady Vashj - phase 2 role assignments
----------------------------------------------------------------------
ns.BossRegistry:Register("vashj", {
    name         = "Lady Vashj",
    instance     = "Serpentshrine Cavern",
    templateType = "vashj_roles",
    notes = "Phase 2 focus: Strider tank, Naga tank, Tainted Elemental caller/killer, and core relay positions.",
    roles = {
        { key = "maintank", label = "Main Tank", tip = "Tanks Vashj in phase 1 and phase 3." },
        { key = "strider",  label = "Strider Tank", tip = "Kites or tanks Coilfang Striders during phase 2." },
        { key = "naga",     label = "Naga Tank", tip = "Controls Coilfang Elite/Naga spawns during phase 2." },
        { key = "tainted",  label = "Tainted Ele", tip = "Calls and kills Tainted Elemental, then starts core relay." },
    },
    corePositions = {
        { key = "north", label = "Core North" },
        { key = "east",  label = "Core East" },
        { key = "south", label = "Core South" },
        { key = "west",  label = "Core West" },
    },
})
