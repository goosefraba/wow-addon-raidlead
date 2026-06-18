----------------------------------------------------------------------
-- RaidLead - Modules/BossData/TempestKeep.lua
-- Tempest Keep (The Eye) - Phase 2 raid content
----------------------------------------------------------------------
local ADDON_NAME, ns = ...

----------------------------------------------------------------------
-- Void Reaver - stack melee, spread ranged orb kiters, 3 tanks swap on
-- Knock Away (untauntable). Uses the generic slots widget.
----------------------------------------------------------------------
ns.BossRegistry:Register("voidreaver", {
    name          = "Void Reaver",
    announceTitle = "Void Reaver - Tanks & Orb Kiters",
    instance      = "Tempest Keep",
    templateType  = "position_tanks",
    notes         = "Tank in the center. Stack melee under the boss; ranged spread out as orb kiters. 3 tanks swap on Knock Away (no taunt). Pure DPS/heal check - heal through Pounding, dodge every orb.",
    slots = {
        { key = "tank1", label = "Main Tank",   tip = "Holds Void Reaver in the center of the room. Loses threat on every Knock Away - the next tank takes over. Build max threat." },
        { key = "tank2", label = "Off Tank 2",  tip = "Stand on the boss ready to grab aggro the instant Main Tank gets Knocked Away (he cannot be taunted, so just out-threat)." },
        { key = "tank3", label = "Off Tank 3",  tip = "Third tank in the Knock Away swap rotation - keeps a tank on the boss at all times." },
        { key = "orb1",  label = "Orb Kiter 1", tip = "Stand 20+ yards out in a fixed spot, back to the boss; the instant an orb spawns on you, run sideways so it lands in empty floor." },
        { key = "orb2",  label = "Orb Kiter 2", tip = "Ranged orb-soak spot, well clear of the raid. Hunters are ideal (steady damage at range)." },
        { key = "orb3",  label = "Orb Kiter 3", tip = "Ranged orb-soak spot. Keep clear floor behind you to run into." },
        { key = "orb4",  label = "Orb Kiter 4", tip = "Optional 4th orb spot for larger raids - more spread means fewer people endangered per orb." },
    },
    mechanics = {
        summary = "A patchwerk-style DPS/heal check with three mechanics: Pounding (melee AoE), Arcane Orb (ranged), and Knock Away (tank threat wipe). Tank center, stack melee, spread ranged, swap tanks. No hard enrage but you must out-DPS attrition.",
        sections = {
            {
                title = "Pounding",
                body = "A channeled AoE that pulses heavy arcane damage to everyone within ~20 yards of the boss (so it hits all the stacked melee). Pre-warn healers - blanket the melee ball with HoTs/AoE heals and keep them topped while it channels.",
            },
            {
                title = "Arcane Orb",
                body = "A slow-moving orb is hurled at a random player who is NOT in melee range, and explodes where they were standing for big damage plus a 6-second silence. Keep all ranged 20+ yards out in set spots; the moment you are targeted, sidestep so it lands on empty floor, never on the raid.",
            },
            {
                title = "Knock Away",
                body = "Hits the current tank for heavy physical damage, knocks them back and wipes their threat. Void Reaver CANNOT be taunted, so run 3 tanks stacked on him - the next tank simply out-threats and takes over after each Knock Away.",
            },
            {
                title = "Positioning",
                body = "- Tank Void Reaver dead center to maximize orb-dodge room.\n"
                    .. "- Melee and non-kiting casters stack in melee under the boss.\n"
                    .. "- Orb kiters stand 20+ yards out, spread, in assigned spots with clear floor to run into.\n"
                    .. "- All three tanks on the boss for the swap.\n"
                    .. "- No hard enrage, but he hits ever harder over time - push DPS.",
            },
            {
                title = "Roles to Assign",
                body = "Three tanks (for the Knock Away swaps) and 3-4 orb kiters (ranged, hunters ideal).",
            },
        },
    },
})

----------------------------------------------------------------------
-- Al'ar - 4 platform tanks rotate through phase 1; one ember kiter
-- in phase 2. No raid icons - the platforms are compass positions.
----------------------------------------------------------------------
ns.BossRegistry:Register("alar", {
    name         = "Al'ar",
    instance     = "Tempest Keep",
    templateType = "position_tanks",
    notes         = "Phase 1: Al'ar circles 4 platforms in a fixed clockwise loop and lands on each. The next tank in the loop pre-positions on the platform she is heading to so she is grabbed instantly (no melee in range = raid-wiping Flame Buffet). Phase 2 (at 0%): she lands center, ground-bound - kite/kill Embers before they reach her.",
    slots = {
        { key = "ne",    label = "NE Platform",        tip = "Tank Al'ar here when she lands NE; be standing in melee BEFORE she arrives so Flame Buffet never starts." },
        { key = "se",    label = "SE Platform",        tip = "Tank Al'ar here when she lands SE; pre-position as she leaves the previous platform." },
        { key = "sw",    label = "SW Platform",        tip = "Tank Al'ar here when she lands SW; pre-position as she leaves the previous platform." },
        { key = "nw",    label = "NW Platform",        tip = "Tank Al'ar here when she lands NW; pre-position as she leaves the previous platform." },
        { key = "ember", label = "Ember Kiter (P2)",   tip = "Grab each Ember of Al'ar and run it AWAY from the boss, then kill it clear of her. An Ember that reaches Al'ar heals her and triggers a Meteor - never let one touch her." },
    },
    mechanics = {
        summary = "A phoenix boss in two phases. Phase 1: she flies a fixed clockwise loop around four platforms; a tank must be waiting in melee on each. Phase 2 (at 0%): she revives center, ground-bound, and the fight becomes about kiting Embers away from her.",
        sections = {
            {
                title = "Phase 1 - Platform Loop",
                body = "Al'ar circles the four platforms in a fixed clockwise order, ~30s each, and never crosses the center.\n"
                    .. "- A tank must already be in melee on the platform she lands on - if no one is in range she spams Flame Buffet (a stacking fire debuff) that wipes the raid.\n"
                    .. "- Have the next tank in the loop pre-position on the upcoming platform so the handoff is instant.\n"
                    .. "- Flame Quills: instead of moving she flies to center and rains fire on her last platform - get everyone off that platform until she resumes the loop.",
            },
            {
                title = "Phase 2 - Ground Phase",
                body = "At 0% she revives in the center, ground-bound, and becomes a tank-and-spank with adds.\n"
                    .. "- Melt Armor stacks on the tank - swap tanks before it gets dangerous.\n"
                    .. "- Dive Bomb / Meteor targets a random player and explodes for heavy AoE - spread so only one person is caught, then move out of the patch.\n"
                    .. "- Embers of Al'ar spawn (notably after Dive Bomb). A kiter pulls each Ember AWAY and kills it clear of the boss - if an Ember reaches Al'ar it heals her and triggers a Meteor. Embers also explode on death, so kill them away from the raid.",
            },
            {
                title = "Roles to Assign",
                body = "One tank per platform (NE/SE/SW/NW) for the phase 1 loop, plus an Ember kiter (and a tank-swap partner for Melt Armor) for phase 2.",
            },
        },
    },
})

----------------------------------------------------------------------
-- High Astromancer Solarian - phase tabs
--   P1: tank Solarian + 3 priest off-tanks + magi add tank
--   P2: Solarian vanishes; 3 portals each spew Solarium Agents, then
--       2 Solarium Priests spawn before she returns (she does NOT split)
--   (P3 Voidwalker at 20% inherits P1 main-tank assignment)
----------------------------------------------------------------------
ns.BossRegistry:Register("solarian", {
    name          = "High Astromancer Solarian",
    announceTitle = "Solarian - Adds & Tanks",
    instance      = "Tempest Keep",
    templateType  = "phased_roles",
    notes         = "P1: tank Solarian, dodge Wrath of the Astromancer bombs, off-tank the 2 priests, AoE the agents. P2: she vanishes and 3 portals each spawn Solarium Agents (about 5 per portal) - AoE them down, then 2 priests spawn before she returns. P3: at 20% she becomes a Voidwalker - re-tank and burn.",
    phases = {
        {
            key = "p1", label = "Phase 1",
            slots = {
                { key = "mt",      label = "Solarian Tank",  tip = "Main tank on Solarian for P1, and again on the Voidwalker in P3. Watch for a tank-fixate, keep her still." },
                { key = "priest1", label = "Priest 1 Tank",  tip = "Pick up a Solarium Priest the moment it spawns - they heal and must be focused/interrupted fast." },
                { key = "priest2", label = "Priest 2 Tank",  tip = "Pick up the second Solarium Priest; only 2 priests spawn per portal cycle." },
                { key = "priest3", label = "Priest 3 Tank",  tip = "Backup priest grabber / swing tank for whichever priest is loose." },
                { key = "magi",    label = "Agent Add Tank", tip = "Round up the Solarium Agents that pour from the portals so the raid can AoE them in one pile." },
            },
        },
        {
            key = "p2", label = "Phase 2",
            slots = {
                { key = "portal_ne", label = "Portal NE", tip = "Assign melee/AoE to collapse on the NE portal and burn its Solarium Agents (about 5 spawn here)." },
                { key = "portal_nw", label = "Portal NW", tip = "Assign a group to the NW portal's agents - clear all three portals before Solarian returns." },
                { key = "portal_s",  label = "Portal S",  tip = "Assign a group to the S portal's agents. Note: portals open at random spots - reassign on the fly to wherever they appear." },
            },
        },
    },
    mechanics = {
        summary = "Three phases: tank-and-spank while dodging Wrath bombs, then a portal/add phase (she vanishes, agents and priests spawn), then a Voidwalker burn at 20%. She does NOT split into copies.",
        sections = {
            {
                title = "Phase 1",
                body = "- Tank Solarian and DPS her down. Wrath of the Astromancer: an arcane bomb lands on a random player - that player runs well away from the raid before it detonates (it knocks up/teleports everyone nearby), then returns.\n"
                    .. "- Arcane Missiles fire at random raiders; Blinding Light pulses raid-wide arcane damage - keep the raid healed.",
            },
            {
                title = "Phase 2 (portals/adds)",
                body = "Around 70%-ish she vanishes and 3 portals open at random spots, each spawning roughly 5 Solarium Agents. AoE the agents down fast; just before she returns 2 Solarium Priests spawn - off-tank and focus the priests first. Then she reappears and Phase 1 repeats. She does NOT split into copies, so there is no 'real one' to find - just clear every portal.",
            },
            {
                title = "Phase 3 (Voidwalker)",
                body = "At 20% Solarian transforms into a giant Voidwalker, losing her old abilities and gaining Void Bolt (heavy tank damage) and Psychic Scream (melee fear). Main tank re-grabs her, melee can back off slightly to dodge the fear, and the raid burns her down.",
            },
            {
                title = "Roles to Assign",
                body = "Phase 1/3: Solarian tank + priest off-tanks + an agent-add tank. Phase 2: a group/caller per portal to AoE the agents (portals appear at random spots, so reassign live).",
            },
        },
    },
})

----------------------------------------------------------------------
-- Kael'thas Sunstrider - the marquee TK fight, 5 phases
--   P1: 4 advisors, fought one at a time
--   P2: 7 legendary weapons spawn, class-assigned by convention
--   P3: all 4 advisors return at once (reuse P1 assignments)
--   P4-5: Kael himself - too dynamic to template, just role notes
----------------------------------------------------------------------
ns.BossRegistry:Register("kaelthas", {
    name          = "Kael'thas Sunstrider",
    announceTitle = "Kael'thas - Phase Assignments",
    instance      = "Tempest Keep",
    templateType  = "phased_roles",
    notes         = "P1: kill the 4 advisors in sequence. P2: 7 legendary weapons spawn - assign a looter per weapon; everyone keeps and uses their weapon in P3/P4. P3: all 4 advisors return at once (P1 assignments apply). P4: Kael with Phoenixes, Mind Control, Pyroblast. P5 (at 50%): Gravity Lapse - fly to Kael and dodge Nether Beams.",
    phases = {
        {
            key = "p1", label = "P1: Advisors",
            slots = {
                { key = "thaladred", label = "Thaladred",  tip = "Gaze fixates a random player who must run - keep NO ONE in melee, kite him at range and out-heal the fixate target." },
                { key = "sanguinar", label = "Sanguinar",  tip = "Fears the raid. Cover with Fear Ward / Tremor Totem and keep tanking through it." },
                { key = "capernian", label = "Capernian",  tip = "Fire caster - only RANGED should hit her (Conflagration nukes anyone in melee). Interrupt her casts." },
                { key = "telonicus", label = "Telonicus",  tip = "Drops bombs and Remote Toy - spread the raid and tank him facing away." },
            },
        },
        {
            key = "p2", label = "P2: Weapons",
            slots = {
                { key = "staff",    label = "Staff (Caster)",    tip = "Staff of Disintegration - kill FIRST (it nukes the raid). Looter wields it for big caster DPS in P3/P4." },
                { key = "bow",      label = "Bow (Hunter)",      tip = "Netherstrand Longbow - also kill early. Best looted and used by a hunter." },
                { key = "crossbow", label = "Crossbow (Ranged)", tip = "Phaseshift Bulwark (shield) - a tank loots it; its on-use absorb soaks Kael's Pyroblast in P4." },
                { key = "dagger",   label = "Dagger (Rogue)",    tip = "Warp Slicer - a melee/rogue loots it. Swap OFF it before its self-damage debuff gets dangerous." },
                { key = "sword",    label = "Sword (Melee)",     tip = "Cosmic Infuser (mace) - a healer loots it; its heal/resist buff helps in P3/P4." },
                { key = "mace",     label = "Mace (Enh/Tank)",   tip = "Devastation - tank it AWAY from the raid (Whirlwind). Swap off before the self-damage stacks up." },
                { key = "shield",   label = "Shield (Tank)",     tip = "Infinity Blade - a melee loots it; it dispels Mind Control on hit, key for P4." },
            },
        },
        {
            key = "p45", label = "P4-5: Kael",
            slots = {
                { key = "mc_handler",     label = "Mind Control Handler", tip = "CC/kill MC'd raiders fast; Infinity Blade or any dispel breaks MC on hit. Healers stop healing MC'd players." },
                { key = "gravity_healer", label = "Gravity Lapse Healer", tip = "Lead healer for the float phase - everyone is airborne, so pre-HoT and top the raid before liftoff." },
                { key = "phoenix_kiter",  label = "Phoenix Kiter",        tip = "Tank each Phoenix away (it self-immolates) and IMMEDIATELY kill its Phoenix Egg - eggs are top priority." },
                { key = "pyro_caller",    label = "Pyroblast Caller",     tip = "Call the Pyroblast target so the Phaseshift Bulwark holder shields them / interrupt the cast." },
            },
        },
    },
    mechanics = {
        summary = "A long five-phase fight: the four advisors one at a time, then loot the seven legendary weapons, then the advisors return together, then Kael himself with Phoenixes, Mind Control and Pyroblast, and finally Gravity Lapse at 50%.",
        sections = {
            {
                title = "Phase 1 - Advisors",
                body = "Kill four advisors one at a time:\n"
                    .. "- Thaladred the Darkener: Gaze fixates a random player who must run - keep everyone out of melee and kite.\n"
                    .. "- Lord Sanguinar: Fear - cover with Fear Ward / Tremor Totem.\n"
                    .. "- Grand Astromancer Capernian: fire caster - RANGED only (Conflagration kills melee), interrupt her.\n"
                    .. "- Master Engineer Telonicus: Bombs + Remote Toy - spread out, tank facing away.",
            },
            {
                title = "Phase 2 - Weapons",
                body = "Seven legendary weapons animate at once; assign a looter per weapon and everyone keeps/uses theirs in P3-P4. Kill the Staff of Disintegration and Netherstrand Longbow FIRST (they nuke the raid). Tank Devastation away (Whirlwind). The Warp Slicer and Devastation give the holder a stacking self-damage debuff - swap off them before it gets dangerous. Save the Phaseshift Bulwark (Pyroblast soak), Infinity Blade (dispels Mind Control) and Cosmic Infuser for later phases.",
            },
            {
                title = "Phase 3 - Advisors Return",
                body = "All four advisors resurrect at once (phase-1 assignments apply). Melee focus Sanguinar and Telonicus, ranged focus Thaladred and Capernian, and use your looted weapons. Kael becomes active next.",
            },
            {
                title = "Phase 4 - Kael'thas",
                body = "- Interrupt Fireball/Pyroblast on cooldown - a finished Pyroblast one-shots; the Phaseshift Bulwark holder shields the target if it lands.\n"
                    .. "- Mind Control: CC/dispel/kill MC'd raiders fast (Infinity Blade breaks it on hit).\n"
                    .. "- Phoenix: tank it away (it self-immolates) and kill the Phoenix Egg immediately - eggs are top priority.\n"
                    .. "- Flame Strike: move out of the patch. Burn his Shock Barrier shields quickly.",
            },
            {
                title = "Phase 5 - Gravity Lapse (50%)",
                body = "At 50% Kael casts Gravity Lapse: the whole raid is teleported to him and floats, able to fly, for ~30s. Fly toward Kael and keep DPSing him, dodge the Nether Vapor clouds, and if you are hit by a Nether Beam break away from the group so it does not chain. Heal up before each Lapse and burn him down.",
            },
            {
                title = "Roles to Assign",
                body = "P1/P3: a handler per advisor. P2: a looter per weapon (by class). P4-5: Mind Control handler, Gravity Lapse lead healer, Phoenix kiter, Pyroblast caller.",
            },
        },
    },
})
