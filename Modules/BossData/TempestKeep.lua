----------------------------------------------------------------------
-- RaidLead - Modules/BossData/TempestKeep.lua
-- Tempest Keep (The Eye) - Phase 2 raid content
--
-- Void Reaver intentionally omitted: tank-and-spank, nothing to assign
-- beyond the in-game /maintank flow that auto-assign already reads.
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Al'ar - 4 platform tanks rotate through phase 1; one ember kiter
-- in phase 2. No raid icons - the platforms are compass positions.
----------------------------------------------------------------------
ns.BossRegistry:Register("alar", {
    name         = "Al'ar",
    instance     = "Tempest Keep",
    templateType = "position_tanks",
    notes        = "Phase 1: Al'ar lands on 4 platforms in sequence (NE -> SE -> SW -> NW). Tanks rotate to whichever platform he arrives at. Phase 2: kill Embers of Al'ar before they reach the boss.",
    slots = {
        { key = "ne",    label = "NE Platform",        tip = "Tank when Al'ar lands NE." },
        { key = "se",    label = "SE Platform",        tip = "Tank when Al'ar lands SE." },
        { key = "sw",    label = "SW Platform",        tip = "Tank when Al'ar lands SW." },
        { key = "nw",    label = "NW Platform",        tip = "Tank when Al'ar lands NW." },
        { key = "ember", label = "Ember Kiter (P2)",   tip = "Kite Embers of Al'ar away from the boss; kill before they reach him." },
    },
})

----------------------------------------------------------------------
-- High Astromancer Solarian - phase tabs
--   P1: tank Solarian + 3 priest off-tanks + magi add tank
--   P2: Solarian splits into 3 copies at 3 portals
--   (P3 inherits P1 main-tank assignment - no separate phase)
----------------------------------------------------------------------
ns.BossRegistry:Register("solarian", {
    name         = "High Astromancer Solarian",
    instance     = "Tempest Keep",
    templateType = "phased_roles",
    notes        = "P1: tank Solarian + 3 priests, AoE the 12 magi adds. P2: Solarian splits into 3 copies at NE/NW/S portals - assign focus per copy. P3: re-tank Solarian.",
    phases = {
        {
            key = "p1", label = "Phase 1",
            slots = {
                { key = "mt",      label = "Solarian Tank",  tip = "Main tank for P1 and P3." },
                { key = "priest1", label = "Priest 1 Tank",  tip = "Off-tank a priest add." },
                { key = "priest2", label = "Priest 2 Tank",  tip = "Off-tank a priest add." },
                { key = "priest3", label = "Priest 3 Tank",  tip = "Off-tank a priest add." },
                { key = "magi",    label = "Magi Add Tank",  tip = "Pick up the 12 magi adds for AoE." },
            },
        },
        {
            key = "p2", label = "Phase 2",
            slots = {
                { key = "portal_ne", label = "Portal NE", tip = "Focus the Solarian copy at the NE portal." },
                { key = "portal_nw", label = "Portal NW", tip = "Focus the Solarian copy at the NW portal." },
                { key = "portal_s",  label = "Portal S",  tip = "Focus the Solarian copy at the S portal." },
            },
        },
    },
})

----------------------------------------------------------------------
-- Kael'thas Sunstrider - the marquee TK fight, 5 phases
--   P1: 4 advisors, fought one at a time
--   P2: 7 legendary weapons spawn, class-assigned by convention
--   P3: ghost versions of P1 advisors (reuse P1 assignments)
--   P4-5: Kael himself - too dynamic to template, just role notes
----------------------------------------------------------------------
ns.BossRegistry:Register("kaelthas", {
    name         = "Kael'thas Sunstrider",
    instance     = "Tempest Keep",
    templateType = "phased_roles",
    notes        = "P1: tank/handle each advisor in sequence. P2: 7 weapons - assign by class. P3: ghost advisors return briefly (P1 assignments apply). P4-5: Kael with Mind Control, Gravity Lapse, Pyroblast, Phoenixes.",
    phases = {
        {
            key = "p1", label = "P1: Advisors",
            slots = {
                { key = "thaladred", label = "Thaladred",  tip = "Gaze (focuses random target). Cannot be taunted - just outheal." },
                { key = "sanguinar", label = "Sanguinar",  tip = "Fears the raid. Tank with high HP / fear-ward rotation." },
                { key = "capernian", label = "Capernian",  tip = "Caster. Needs interrupt rotation. Drops a fire DOT." },
                { key = "telonicus", label = "Telonicus",  tip = "Drops bombs. Tank facing away from raid." },
            },
        },
        {
            key = "p2", label = "P2: Weapons",
            slots = {
                { key = "staff",    label = "Staff (Caster)",    tip = "Netherstrand Longbow / staff equivalent - casts Shadow Bolts. Mage / Warlock / Boomkin." },
                { key = "bow",      label = "Bow (Hunter)",      tip = "Netherstrand Longbow. Best handled by a hunter." },
                { key = "crossbow", label = "Crossbow (Ranged)", tip = "Phaseshift Bulwark. Ranged DPS." },
                { key = "dagger",   label = "Dagger (Rogue)",    tip = "Warp Slicer. Rogue / Combat preferred." },
                { key = "sword",    label = "Sword (Melee)",     tip = "Cosmic Infuser. Melee DPS." },
                { key = "mace",     label = "Mace (Enh/Tank)",   tip = "Devastation. Enhancement shaman or tank." },
                { key = "shield",   label = "Shield (Tank)",     tip = "Infinity Blades (thrown shield). Tank-friendly." },
            },
        },
        {
            key = "p45", label = "P4-5: Kael",
            slots = {
                { key = "mc_handler",     label = "Mind Control Handler", tip = "Sheep / fear / kill MC'd raid members fast." },
                { key = "gravity_healer", label = "Gravity Lapse Healer", tip = "Lead healer for the floating-up phase." },
                { key = "phoenix_kiter",  label = "Phoenix Kiter",        tip = "Kite the Phoenix adds that spawn periodically." },
                { key = "pyro_caller",    label = "Pyroblast Caller",     tip = "Call out who Pyroblast targets so they get peeled / healed." },
            },
        },
    },
})
