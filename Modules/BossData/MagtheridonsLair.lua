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
        tip   = "Tanks Magtheridon in the middle of the room, backed against the wall so Quake knockback has nowhere to push him. Face him AWAY from the raid - his Cleave stacks an armor-reduction debuff, so rotate with an OT when one is available.",
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
    notes = "Mark Hellfire Channelers in phase 1. Each clicker owns the cube where their channeler stood and stays on it. Assign a backup per cube - Mind Exhaustion (3 min) blocks a re-click, so backups cover the next Nova.",
    mechanics = {
        summary = "Kill the five channelers, then tank Magtheridon while assigned players click the Manticron Cubes to interrupt Blast Nova on its cast bar. One missed Blast Nova wipes the raid - cube coverage and backups are everything.",
        sections = {
            {
                title = "Phase 1 - Hellfire Channelers",
                body = "Five Hellfire Channelers channel to keep Mag imprisoned (about a 2-minute window).\n"
                    .. "- Tank and kill them; they cast Shadow Bolt Volley, Dark Mending (a heal - INTERRUPT it every time) and Fear.\n"
                    .. "- They summon Burning Abyssals: warlocks Banish/Enslave them, or mages/hunters CC, since the Abyssals dive on healers.\n"
                    .. "- Each channeler that dies buffs the survivors (Soul Transfer, stacking damage) - assign extra healing to whoever tanks the last couple.\n"
                    .. "- Mark each with a raid icon. The clicker assigned to an icon owns the cube nearest where that channeler stood.",
            },
            {
                title = "Phase 2 - Magtheridon",
                body = "Once the channelers fall Mag breaks free.\n"
                    .. "- Main tank holds him in the middle, against the wall (so Quake cannot knock him loose), faced away from the raid.\n"
                    .. "- Cleave applies a stacking armor reduction to whoever he faces - rotate with an off-tank if you have one.",
            },
            {
                title = "Blast Nova - the Cubes (critical)",
                body = "Roughly every 50-60s Mag casts Blast Nova, a raid-wide nuke that kills everyone if it lands.\n"
                    .. "- The cube call is timed to the cast bar: on the 'Magtheridon begins to cast Blast Nova' emote (he detargets the tank), the raid leader gives ONE callout ('NOVA - CLICK') and all five clickers channel their cube together inside the ~2s cast. Wait for the emote - clicking too early wastes it.\n"
                    .. "- Click the cube ONCE only - it is a channel, and a second click cancels it. While all five are channeled Mag is stunned and takes massively increased damage, so the raid burns him.\n"
                    .. "- Every cube needs a person and they hold position spread around the room so all five are always covered.",
            },
            {
                title = "Clickers - do NOT swap cubes; use backups",
                body = "Each clicker stays mapped to the SAME cube (their channeler's icon) the entire fight - they do not rotate cubes or trade positions.\n"
                    .. "- But a click leaves Mind Exhaustion (3 minutes), which is longer than the gap between Novas, so one person cannot cover back-to-back Novas alone.\n"
                    .. "- Assign a NAMED backup to each cube. The backup takes that cube on the next Nova (and if the primary dies or is feared away). With two people per cube position you alternate cleanly through every Blast Nova.",
            },
            {
                title = "Phase 3 - Collapse / Debris",
                body = "At 30% Mag collapses the roof: Debris stuns the whole raid for ~2s and hits hard, then ceiling chunks keep falling on marked spots.\n"
                    .. "- Heal through the stun, move off the marked debris zones, and keep clicking cubes through every Blast Nova - the dance does not stop, just burn him down.",
            },
        },
    },
})
