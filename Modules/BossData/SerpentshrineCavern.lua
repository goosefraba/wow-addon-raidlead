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
    notes = "Mark Karathress and the three advisors; one tank per mark. Kill the advisors first - common order Tidalvess > Sharkkis > Caribdis > Karathress. Do NOT push Karathress below 75% until the advisors are dead.",
    mechanics = {
        summary = "Fathom-Lord plus three advisors, all tanked at once. At 75% Karathress gains Blessing of the Tides, a massive haste buff for every advisor still alive - so kill the three advisors first and burn Karathress only after they are dead.",
        sections = {
            {
                title = "Setup",
                body = "- Mark Karathress and the three advisors; one dedicated tank per mark, all picked up at the pull.\n"
                    .. "- Blessing of the Tides: when Karathress drops below 75% he gains a huge attack/cast haste buff for EACH advisor still alive. Hold him above 75% until all three advisors are dead.\n"
                    .. "- Each advisor also hands Karathress their signature ability when they die, so order matters.",
            },
            {
                title = "Kill Order",
                body = "- Tidalvess > Sharkkis > Caribdis > Karathress (standard).\n"
                    .. "- Tidalvess first: his Spitfire Totem is a top wipe cause - kill it on sight - and his tank damage is nasty.\n"
                    .. "- Sharkkis second: he gains The Beast Within, a self damage buff, so end him fast.\n"
                    .. "- Caribdis last of the advisors: keep melee on Karathress and let casters burn her to avoid her Tidal Surge.",
            },
            {
                title = "The Advisors",
                body = "- Fathom-Guard Sharkkis (hunter): Multi-Toss, Leeching Throw (dispel it), The Beast Within, and summons a pet (Fathom Lurker or Fathom Sporebat) that must also be tanked.\n"
                    .. "- Fathom-Guard Tidalvess (shaman): Spitfire / Earthbind / Poison Cleansing Totems (kill them, Spitfire first), Frost Shock. Interrupt where possible.\n"
                    .. "- Fathom-Guard Caribdis (siren): Water Bolt Volley, Tidal Surge (frost stun + damage to nearby players), Healing Wave (INTERRUPT every cast), and Summon Cyclone - spread and move out of the cyclones.",
            },
            {
                title = "Karathress",
                body = "- Cataclysmic Bolt: hits a random player for ~50% max health and stuns them - pre-heal/HoT the raid.\n"
                    .. "- Sear Nova: damage to everyone in melee range.\n"
                    .. "- Once all three advisors are down, blow cooldowns and burn him through 75%.",
            },
        },
    },
})

----------------------------------------------------------------------
-- Lady Vashj - phase 2 role assignments
----------------------------------------------------------------------
ns.BossRegistry:Register("vashj", {
    name         = "Lady Vashj",
    instance     = "Serpentshrine Cavern",
    templateType = "vashj_roles",
    notes = "Phase 2 is the fight: ranged kill the Striders fast, pass Tainted Cores from Tainted Elementals to the four shield generators (N/E/S/W), and keep Enchanted Elementals off Vashj.",
    mechanics = {
        summary = "Three phases. Tank-and-spank to 70%, then a chaotic add/relay phase where you loot Tainted Cores from Tainted Elementals and carry them to four shield generators to drop her shield, then a burn phase with Toxic Spore Bats.",
        sections = {
            {
                title = "Phase 1 (100% to 70%)",
                body = "- Tank Vashj at the edge of the platform; raid spreads at least 5 yards apart.\n"
                    .. "- Shock Blast: massive hit + 5s stun on her current aggro target (the tank) - the off-tank should be ready and healers must top the MT before it lands.\n"
                    .. "- Static Charge: a debuff that zaps players within 5 yards, so stay spread.\n"
                    .. "- Entangle: roots everyone within ~15 yards of Vashj - melee just keep attacking, ranged stay out of range.\n"
                    .. "- Push her to 70% to start phase 2.",
            },
            {
                title = "Phase 2 (the core relay)",
                body = "Vashj shields herself, becomes immune, and only casts Forked Lightning while four shield generators (N/E/S/W) must be disabled.\n"
                    .. "- Tainted Elementals spawn; kill one, loot the Tainted Core it drops. Holding a Core ROOTS you - the only way to move it is to use the Core item on another player to pass it.\n"
                    .. "- Relay each Core hand-to-hand out to its generator; a player standing at a generator with a Core disables it. Disable all four to advance.\n"
                    .. "- Coilfang Striders fear anyone in melee range (pulses ~every 2s) - RANGED must kill them fast (they are the real threat).\n"
                    .. "- Naga tank holds the Coilfang Elite spawns.\n"
                    .. "- Enchanted Elementals walk in from the water edges to buff Vashj - kill them before they reach her or her stacks climb.",
            },
            {
                title = "Phase 3 (shield down, ~70% to 0%)",
                body = "- Threat is wiped entering this phase - tank must re-establish before DPS opens up.\n"
                    .. "- Same phase-1 abilities (Shock Blast, Static Charge, Entangle) plus Toxic Spore Bats that spawn and need ranged attention.\n"
                    .. "- Stay spread, keep her tanked at the edge, and burn her before healers run dry.",
            },
            {
                title = "Roles to Assign",
                body = "Main tank, Strider tank, Naga tank, Tainted Elemental caller/killer, and the four core-relay positions (N/E/S/W) - each ideally with a runner who carries the Core out to that generator.",
            },
        },
    },
    roles = {
        { key = "maintank", label = "Main Tank", tip = "Tanks Vashj at the platform edge in phase 1 and phase 3. Expect Shock Blast (big hit + 5s stun) - call for the off-tank cover and pre-heals. Re-grab her at the start of phase 3 (threat is wiped)." },
        { key = "strider",  label = "Strider Tank", tip = "Coilfang Striders fear everyone in melee, so they cannot be tanked normally - this role marks/calls them and makes sure RANGED burn them down immediately. They are the most dangerous phase-2 add." },
        { key = "naga",     label = "Naga Tank", tip = "Picks up and holds the Coilfang Elite (Naga) spawns during phase 2 so they do not hit the relay teams or healers." },
        { key = "tainted",  label = "Tainted Ele", tip = "Calls and kills the Tainted Elementals, then makes sure a player loots each Tainted Core and starts passing it toward its generator. Holding a Core roots you - pass it player-to-player." },
    },
    corePositions = {
        { key = "north", label = "Core North" },
        { key = "east",  label = "Core East" },
        { key = "south", label = "Core South" },
        { key = "west",  label = "Core West" },
    },
})

----------------------------------------------------------------------
-- Remaining SSC bosses - generic role-slot assignments + mechanics.
----------------------------------------------------------------------
ns.BossRegistry:Register("hydross", {
    name          = "Hydross the Unstable",
    announceTitle = "Hydross the Unstable - Assignments",
    instance      = "Serpentshrine Cavern",
    templateType  = "slots",
    notes         = "Two-tank transition fight - drag him across the center line to flip his element. Swap at 3 stacks (before the 4th, the 100% application) so the raid debuff never gets unhealable.",
    slots = {
        { key = "tank1", label = "Nature Resist Tank", tip = "Tanks Hydross on the clean (Pure / Nature) side, away from the water. He deals Nature damage here and applies Mark of Hydross - wear Nature Resist gear and pre-position on the clean side so you can taunt the instant he crosses." },
        { key = "tank2", label = "Frost Resist Tank",  tip = "Tanks Hydross on the corrupted (Tainted / Frost) side, in the water. He deals Frost damage here and applies Mark of Corruption - wear Frost Resist gear and grab him immediately on every transition (threat resets each cross)." },
        { key = "addtank1", label = "Add Tank", tip = "Each transition spawns 4 elemental adds (Pure Spawns on the clean side, Tainted Spawns in the water). Grab all four immediately and hold them stacked so DPS can AoE them before they reach the raid." },
    },
    mechanics = {
        summary = "Hydross flips between Frost (corrupted/water) and Nature (pure/clean) each time he is dragged across the center line. Two resist-geared tanks alternate holding him while you swap sides before the stacking Mark debuff climbs too high.",
        sections = {
            { title = "Transitions",
              body  = "- Dragging Hydross over the center line flips him between Corrupted (Frost, in the water) and Pure (Nature, on dry land).\n" ..
                      "- Each transition resets his threat AND spawns 4 elemental adds - have the next tank and the add tank ready before you drag.\n" ..
                      "- Crossing the line clears the current Mark stacks, which is the whole point of moving him." },
            { title = "Marks - the swap timer",
              body  = "- On the clean side he stacks Mark of Hydross (bonus Frost taken); in the water he stacks Mark of Corruption (bonus Nature taken).\n" ..
                      "- Each stack lands every ~15s and ramps 10% > 25% > 50% > 100% > 250% > 500%.\n" ..
                      "- Drag him across at 3 stacks (right before the 4th = 100% application) so the raid never eats the high-end damage." },
            { title = "Resistance Gear",
              body  = "- Nature Resist tank handles the clean side, Frost Resist tank handles the water side - pre-stand each tank on their side.\n" ..
                      "- Stack high resist totals so the active aura is largely mitigated; the off-side tank can be in normal gear until it is their turn.\n" ..
                      "- Healers swap which school they watch after every transition." },
            { title = "Add Control",
              body  = "- Pure Spawns (clean) and Tainted Spawns (water) hit hard and must be controlled - the add tank grabs all 4 on spawn.\n" ..
                      "- AoE them down quickly before re-engaging Hydross so they do not pile up across multiple transitions." },
        },
    },
})

ns.BossRegistry:Register("lurker", {
    name          = "The Lurker Below",
    announceTitle = "The Lurker Below - Assignments",
    instance      = "Serpentshrine Cavern",
    templateType  = "slots",
    notes         = "Fish him up from the Strange Pool. Tank him on the central platform; during the ~2 min stationary phase survive Spout by diving, then off-tanks grab the Guardians and Ambushers when he submerges.",
    slots = {
        { key = "tank1", label = "Main Tank", tip = "Tanks The Lurker Below on the central platform and never lets go - if no one is in melee he casts Water Bolt, which one-shots its target. Keep him put and keep melee on him so Spout coverage stays predictable." },
        { key = "addtank1", label = "Add Tank 1", tip = "When Lurker submerges, 3 Coilfang Guardians spawn on the main platform. Pick them up and hold them centered while DPS burn them before he resurfaces (~60s under)." },
        { key = "addtank2", label = "Add Tank 2", tip = "Help control the Coilfang Guardians plus the Coilfang Ambushers (2 spawn on each outer platform, on the ranged/healers stationed there). Peel Ambushers off the casters fast." },
        { key = "addtank3", label = "Add Tank 3", tip = "Backup add control for the Guardian/Ambusher wave. Make sure every outer platform's Ambushers are picked up so the whole add wave dies before Lurker comes back up." },
    },
    mechanics = {
        summary = "Lurker alternates a ~2 minute stationary phase (Spout, Whirl, Geyser, Water Bolt) with a ~1 minute dive phase where the raid spreads to the outer platforms and Guardians + Ambushers spawn. Survive Spout, clear the adds, repeat.",
        sections = {
            { title = "Spout",
              body  = "- Lurker rotates while breathing a water jet that knocks anyone hit into the water and deals heavy damage.\n" ..
                      "- Being SUBMERGED avoids Spout entirely - when Spout is cast, jump into the water (or get fully behind cover) until it ends.\n" ..
                      "- He spins one direction the whole cast - watch which way he starts turning and run/dive the other way to stay ahead of the beam." },
            { title = "Whirl & Water Bolt",
              body  = "- Whirl: a small knockback hitting everyone in melee range between Spouts - melee expect it and run straight back in.\n" ..
                      "- Water Bolt: only cast when NO ONE is in melee range, and it can one-shot its target. Always keep the tank (and ideally melee) in melee so this never goes out." },
            { title = "Geyser",
              body  = "- Geyser targets a random raid member and knocks back / damages everyone within ~10 yards of them.\n" ..
                      "- Keep ranged and healers spread on their platforms so a Geyser does not catch the whole group." },
            { title = "Dive (Add) Phase",
              body  = "- After ~2 minutes Lurker submerges for about a minute and the raid spreads to the outer strider platforms.\n" ..
                      "- 3 Coilfang Guardians spawn on the main platform and 2 Coilfang Ambushers spawn on each outer platform - add tanks grab them, DPS burn them all before he resurfaces." },
        },
    },
})

ns.BossRegistry:Register("leotheras", {
    name          = "Leotheras the Blind",
    announceTitle = "Leotheras the Blind - Assignments",
    instance      = "Serpentshrine Cavern",
    templateType  = "slots",
    notes         = "Tank the Elf form; a Fire Resist warlock tanks the Demon form. Every player Whispered must solo-kill their own Inner Demon. At 15% he splits into both forms - kill the Elf to end it.",
    slots = {
        { key = "tank1", label = "Human Form Tank", tip = "Tanks Leotheras in his Elf form. His Whirlwind WIPES your threat, so back out during it and immediately re-establish aggro when it ends. He stays in Elf form once he hits 15% (split phase)." },
        { key = "demontank", label = "Demon Tank (Warlock)", tip = "A warlock with high FIRE Resistance tanks the Demon form. Chaos Blast is Fire damage that ignores armor - stack Fire Resist, use Soul Link / health funnel, and keep Searing Pain up for threat. Raid healers top the warlock between blasts." },
        { key = "tank2", label = "Off Tank", tip = "Backup for the Elf form and the 15% split phase. Be ready to taunt the Elf if the main tank is killed or loses it after a Whirlwind threat reset." },
    },
    mechanics = {
        summary = "Leotheras alternates Elf form (Whirlwind, threat wipe) and Demon form (Chaos Blast, Insidious Whisper) about every 45 seconds. In demon phase five players are Whispered and must solo-kill their own Inner Demon. At 15% both forms are active at once.",
        sections = {
            { title = "Form Swaps",
              body  = "- Starts in Elf form, swaps to Demon form roughly every 45 seconds.\n" ..
                      "- Elf tank holds the Elf; the Fire Resist warlock holds the Demon whenever it is up.\n" ..
                      "- Assign someone to watch and call the ~45s form-swap timer out loud." },
            { title = "Whirlwind (Elf form)",
              body  = "- In Elf form he Whirlwinds toward random players, hitting hard and leaving a DoT; his threat fully resets when it ends.\n" ..
                      "- Everyone stays away from him during Whirlwind; the tank re-grabs the instant it finishes before DPS resume." },
            { title = "Inner Demon (Demon form)",
              body  = "- In Demon form he casts Insidious Whisper on 5 random players, spawning an Inner Demon copy of each.\n" ..
                      "- Each Whispered player MUST solo-kill their own Inner Demon before the timer, or they are permanently Mind Controlled and the raid has to kill them (likely a wipe).\n" ..
                      "- Whispered players save personal cooldowns - healers cannot help them while Whispered. Pre-assign who watches the timer and calls it." },
            { title = "Demon Tanking (Chaos Blast)",
              body  = "- Demon form casts Chaos Blast: large FIRE damage on its highest-threat target that ignores normal armor.\n" ..
                      "- The Fire Resist warlock tanks it and self-sustains (Soul Link, drain/health funnel); raid healers top the warlock between blasts." },
            { title = "Split Phase (15%)",
              body  = "- At 15% the Elf stays up AND the Demon spawns alongside it, both with their abilities active.\n" ..
                      "- Focus and kill the ELF form - when it dies the Demon despawns and the fight ends. Keep the warlock on the Demon and the rest of the raid burning the Elf." },
        },
    },
})

ns.BossRegistry:Register("morogrim", {
    name          = "Morogrim Tidewalker",
    announceTitle = "Morogrim Tidewalker - Assignments",
    instance      = "Serpentshrine Cavern",
    templateType  = "slots",
    notes         = "Two-tank the boss near a pillar facing away. Free Watery Grave players fast, AoE the Murloc waves from Earthquake, and at 25% dodge the Water Globules.",
    slots = {
        { key = "tank1", label = "Main Tank", tip = "Tanks Morogrim near a pillar, FACED AWAY from the raid so Tidal Wave (frost cone) only hits the tank. Watery Grave can teleport you to the center waterfall - call it so the off-tank taunts instantly." },
        { key = "tank2", label = "Off Tank", tip = "Taunt Morogrim the moment the main tank is taken by Watery Grave. Otherwise help bring the Murloc adds to the boss so they can be AoE'd down together." },
        { key = "addtank1", label = "Murloc Tank / Control", tip = "When Earthquake summons the two packs of 6 Murlocs from the room entrances, gather them onto Morogrim for raid AoE. Keep them off the healers - they hit fast and rush the back line." },
    },
    mechanics = {
        summary = "Morogrim hits hard, teleports players into Watery Graves, and his Earthquake summons waves of Murlocs that must be AoE'd down. At 25% he stops Watery Grave and spawns fixating Water Globules instead.",
        sections = {
            { title = "Watery Grave",
              body  = "- Teleports 4 random players (can include the tank) to the center waterfall, stunning them and dropping them for fall damage, then leaving them taking damage.\n" ..
                      "- Assign 2 healers to the Watery Grave targets - they die fast if neglected.\n" ..
                      "- If the main tank is taken, the off-tank taunts instantly so the boss never goes loose." },
            { title = "Tidal Wave",
              body  = "- A frontal Frost CONE that also slows attack speed for 15s.\n" ..
                      "- Keep Morogrim faced away from the raid (near a pillar) so only the tank eats it." },
            { title = "Earthquake & Murloc Adds",
              body  = "- Earthquake damages everyone within ~50 yards and summons two packs of 6 Murlocs from the room's entrances.\n" ..
                      "- Off-tanks drag both packs onto Morogrim and the raid AoEs them down immediately before the next wave overlaps." },
            { title = "Phase 2 - Water Globules (25%)",
              body  = "- At 25% Morogrim stops Watery Grave and spawns Water Globules at the waterfalls that fixate on random players.\n" ..
                      "- A Globule explodes for massive damage if it reaches its target - the raid can reposition into a doorway and kite/kill the Globules before they connect, then burn the boss." },
        },
    },
})
