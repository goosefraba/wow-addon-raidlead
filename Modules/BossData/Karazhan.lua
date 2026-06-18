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
    notes = "Rotate portal soakers each phase. Never let beams hit the boss. Green is the one you must never leak - it heals Netherspite.",
    mechanics = {
        summary = "Netherspite alternates a ~60s Beam phase (intercept three portal beams) with a ~30s Banish phase (no beams; he goes immobile but is still attackable - dodge Netherbreath). He can be damaged in both phases. Hard enrage at 9 minutes (+500% damage), so beam rotations must keep DPS flowing.",
        sections = {
            {
                title = "Beam Phase",
                body = "Three coloured beams link Netherspite to three portals. A raid member must stand in each beam's line to intercept it, or it reaches the boss and empowers him.\n"
                    .. "Each soaker builds stacks while in a beam and must rotate out before it gets dangerous. On leaving a beam you get Nether Exhaustion (~90s) that blocks re-soaking that SAME colour, so plan 2 people per beam and swap on a timer.\n"
                    .. "There are no void zones on this fight - the only ground danger is the Netherbreath cone in the banish phase.",
            },
            {
                title = "Portal Beams - effect on the soaker / on the boss if NOT blocked",
                body = "Red - Perseverance (tank beam)\n"
                    .. "- Soaker: gains huge max health, damage reduction and threat per stack - this is what lets the tank survive the beam and hold aggro.\n"
                    .. "- If it reaches Netherspite: the boss takes less damage per stack (gets very tanky). Annoying, not fatal.\n\n"
                    .. "Green - Serenity (healer beam) - THE ONE TO NEVER LEAK\n"
                    .. "- Soaker: healed heavily each second but stacks a debuff that blocks outside healing - the beam itself keeps them alive, so rotate before stacks get too high.\n"
                    .. "- If it reaches Netherspite: the boss heals thousands of HP per second and can erase your whole pull. Cover green first, always.\n\n"
                    .. "Blue - Dominance (caster beam)\n"
                    .. "- Soaker: gains a big spell-damage and mana buff each second, with a stacking +spell-damage-taken debuff. Casters rotate it for extra DPS.\n"
                    .. "- If it reaches Netherspite: the boss deals MORE damage per stack, making the phase far more lethal.",
            },
            {
                title = "Banish Phase",
                body = "After each beam phase Netherspite banishes himself for about 30s. The beams stop and he goes immobile/shadowy, but he keeps meleeing and can STILL be attacked - keep DPSing him.\n"
                    .. "- He casts Netherbreath often: a frontal cone toward his current target for heavy damage plus a knockback. Face him away from the raid.\n"
                    .. "- Threat fully resets when banish ends, so the tank must instantly re-grab him as the next beam phase opens.\n"
                    .. "Then the Beam phase starts again.",
            },
            {
                title = "Raid-Leader Tactic",
                body = "- Assign beams 1 tank (red) / 1 healer (green) / 2 DPS (blue), each colour with a backup for the 90s lockout swap.\n"
                    .. "- PRIORITISE GREEN above all - leaking red just slows you, but a leaked green beam heals the boss and resets your progress.\n"
                    .. "- Park Netherspite against one wall before each banish so the raid sidesteps Netherbreath and the threat-reset re-grab is clean.\n"
                    .. "- Hard enrage at 9 min - tight rotations so DPS never stops.",
            },
        },
    },
})

----------------------------------------------------------------------
-- Remaining Karazhan bosses: mechanics/tactics only (no assignment
-- config), so they fall through to the generic placeholder page.
----------------------------------------------------------------------
ns.BossRegistry:Register("attumen", {
    name          = "Attumen the Huntsman",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Two-phase fight; Midnight the horse joins almost immediately, then merges with Attumen into a mounted boss. Balance both health bars to 25% together.",
    mechanics = {
        summary = "Tank the horse Midnight first; Attumen spawns once Midnight is at 95% HP. When EITHER reaches 25% they merge into a single mounted boss (threat resets) who is tanked away from the raid due to Shadow Cleave.",
        sections = {
            { title = "Phases", body = "- Phase 1: Tank Midnight (the horse) alone.\n" ..
                "- At 95% of MIDNIGHT's health, Attumen the Huntsman spawns and is tanked separately ~10 yds away.\n" ..
                "- When EITHER Attumen or Midnight hits 25%, they merge into mounted Attumen and ALL threat resets - re-grab instantly." },
            { title = "Key Abilities", body = "- Shadow Cleave: heavy frontal shadow AoE - everyone but the tank stacks behind Attumen.\n" ..
                "- Intangible Presence: -50% hit chance on a target (a Warrior can Spell Reflect it back onto Attumen).\n" ..
                "- Knock Away: throws the tank back and drops threat.\n" ..
                "- Berserker Charge (mounted phase only): charges a random player with a knockdown." },
            { title = "Positioning", body = "- Keep both tanks ~10 yds apart so the merge happens in one controlled spot.\n" ..
                "- Stack the whole raid tight behind Attumen to eat Shadow Cleave safely and reduce Berserker Charge spread.\n" ..
                "- Face the boss away from the raid at all times for the cleave." },
            { title = "Raid-Leader Tactic", body = "- BALANCE both health pools down evenly through Phase 2. If Midnight has more HP than Attumen at the merge, Attumen's health JUMPS UP to match - so burning only Attumen wastes the merge.\n" ..
                "- Get both to ~25% together for the smallest possible merged health pool.\n" ..
                "- Tank pre-loads an instant threat ability for the merge's threat reset; healers watch cleave/charge spikes." },
        },
    },
})

ns.BossRegistry:Register("moroes", {
    name          = "Moroes",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Adds-control fight; CC two guests, kill the healer guests first, manage Vanish/Garrote. Garrote is physical and cannot be dispelled.",
    mechanics = {
        summary = "Moroes spawns with 4 random elite guests (from a pool of 6) that must be crowd-controlled or killed. He periodically Vanishes and reappears with a stacking Garrote on a random player. It is a Garrote/mana race, not a fixed timer - he enrages at 30% HP.",
        sections = {
            { title = "Adds (Guests)", body = "- 4 random guests from a pool of 6: 2 healers (Catriona - Holy Priest, Keira - Holy Paladin), Dorothea (Shadow Priest, Mana Burn), Rafe (Ret Paladin, Hammer of Justice), Daris (Arms Warrior, Mortal Strike), Crispin (Prot Warrior, harmless).\n" ..
                "- CC two with Sap, Polymorph, Shackle, Freezing Trap, etc.\n" ..
                "- KILL the healer guests FIRST (Catriona, then Keira) or they negate all your damage; then Dorothea for her Mana Burn." },
            { title = "Key Abilities", body = "- Vanish: every ~30s Moroes vanishes WITHOUT dropping aggro, then Garrotes a random raider.\n" ..
                "- Garrote: ~1000 physical damage every 3s for 5 min, stacking each Vanish. PHYSICAL bleed - not dispellable; only immunities (BoP, Ice Block, Divine Shield, Stoneform) or a combat-res clear it.\n" ..
                "- Gouge: stuns his current target, then he hits the second-highest threat - keep an off-tank as a solid #2.\n" ..
                "- Blind: disorients the closest non-tank (breaks on damage)." },
            { title = "Raid-Leader Tactic", body = "- Pre-assign a dedicated healer to spot the Garrote target instantly - it can kill cloth fast.\n" ..
                "- Have immunity classes (Paladin, Mage, Dwarf) SELF-CLEAR their own Garrote, taking that load off healers entirely.\n" ..
                "- After Gouge, the off-tank picks Moroes up so he never runs loose.\n" ..
                "- Re-CC guests as effects break; leave the harmless Prot warrior (Crispin) for last." },
            { title = "Enrage", body = "- Moroes enrages at 30% health (plus an open-ended Berserk if it drags).\n" ..
                "- Once the healer guests are dead and CC holds, burn Moroes steadily - the real clock is stacking Garrote and healer mana." },
        },
    },
})

ns.BossRegistry:Register("maiden", {
    name          = "Maiden of Virtue",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Single-target fight; Repentance stuns everyone but the tank, dispel Holy Fire, spread for Holy Wrath. Break Repentance by standing in Holy Ground.",
    mechanics = {
        summary = "A tank-and-spank with a raid-wide Repentance incapacitate (the tank is immune) and stacking Holy damage. Spread out, dispel Holy Fire, and keep the tank up through the 12s Repentance windows.",
        sections = {
            { title = "Key Abilities", body = "- Repentance: 12-second incapacitate on the whole raid EXCEPT her current target (the tank keeps swinging). ~30s cooldown; breaks on damage.\n" ..
                "- Holy Fire: heavy holy DoT (~1750/2s for 12s) on a random player - dispellable.\n" ..
                "- Holy Wrath: hits a random player and chains to nearby players, ramping damage with each jump.\n" ..
                "- Holy Ground: permanent ~12-yard aura around her dealing holy ticks plus a brief silence - melee stand in it constantly." },
            { title = "Positioning", body = "- Spread the raid out so Holy Wrath cannot chain - clumping can cascade-wipe a group.\n" ..
                "- Melee take constant Holy Ground damage; healers account for it.\n" ..
                "- Ranged and healers otherwise stay at max range." },
            { title = "Raid-Leader Tactic", body = "- Have healers and ranged step INTO Holy Ground (the melee aura) a couple seconds before each Repentance - the tick damage breaks the incapacitate almost instantly so they can keep healing the tank.\n" ..
                "- Use immunity breaks where available (Divine Shield, Ice Block, Berserker Rage) to act through Repentance.\n" ..
                "- Dispel Holy Fire off cloth fast; keep the tank topped through Holy Ground." },
        },
    },
})

ns.BossRegistry:Register("opera", {
    name          = "Opera Event",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "One of 3 random events: Wizard of Oz, Big Bad Wolf, or Romulo and Julianne. Identify it when the curtain rises.",
    mechanics = {
        summary = "A randomly selected stage event with one of three encounters. Each has unique mechanics, so identify the event immediately and switch strategy.",
        sections = {
            { title = "Wizard of Oz", body = "- Five mobs at once, then the Crone: Dorothee, Tito (her dog), Roar (lion), Strawman (scarecrow), Tinhead (tin man).\n" ..
                "- Kill order: Dorothee FIRST (she is untankable and randomly nukes Water Bolt - frost damage - and an AoE Fear). Do NOT kill Tito before her or she enrages.\n" ..
                "- Then Tito, Roar (AoE fear, himself fearable), Strawman (Brain Bash stun), Tinhead (Cleave, slows himself with Rust).\n" ..
                "- The Crone appears last: Chain Lightning plus roaming Cyclone tornadoes - dodge the tornadoes." },
            { title = "Oz - Raid-Leader Tactic", body = "- Assign one Fire caster to 'tank' Strawman with spammed direct fire (Mage Scorch is ideal). Each fire hit has a high chance to apply Burning Straw, DISORIENTING him so he cannot cast Brain Bash - this removes the only dangerous ability in the event.\n" ..
                "- Note: it disorients him in place (he does not flee), and it needs DIRECT fire hits - DoT/AoE ticks are unreliable." },
            { title = "Big Bad Wolf", body = "- Single boss, tanked in a corner.\n" ..
                "- 'Little Red Riding Hood': every ~30s a random player is forced to flee (cannot fight back) and the Wolf chases THEM specifically, hitting hard.\n" ..
                "- Tactic: the hooded player runs a wide circular kite around the room's edge (never the center) until it expires while healers pre-heal them; tank re-grabs the instant it ends." },
            { title = "Romulo and Julianne", body = "- Three phases: fight Julianne, then Romulo, then both together.\n" ..
                "- Julianne casts Eternal Affection (a heal - interrupt it) and Powerful Attraction (a knockback). Romulo is melee-only and can be Disarmed.\n" ..
                "- In Phase 3 they must die within ~10 seconds of each other or the dead one RESURRECTS at full health.\n" ..
                "- Tactic: split DPS (interrupters on Julianne, ranged on Romulo), call a hard DPS-stop when one hits ~5%, then burst both past the threshold together." },
        },
    },
})

ns.BossRegistry:Register("curator", {
    name          = "The Curator",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Add-summoning robot; kill Astral Flares and dump every cooldown during the first Evocation when he takes 200% extra damage.",
    mechanics = {
        summary = "The Curator summons an Astral Flare every ~10s while draining mana on Hateful Bolt. After the 10th flare his mana is gone and he Evocates - taking +200% damage (3x) for ~20s, the burn window. Soft enrage at 15%.",
        sections = {
            { title = "Astral Flares", body = "- Every ~10s he summons an Astral Flare that uses Arcing Sear (chained arcane hits, up to 3 players within 10 yds).\n" ..
                "- Kill flares immediately; they are low health but deadly if they pile up. They do not explode on death.\n" ..
                "- Ranged/AoE handle flares while one group stays on the boss." },
            { title = "Key Abilities", body = "- Hateful Bolt: heavy arcane hit to the highest-threat NON-tank (effectively #2). Park a stable off-tank as #2 to eat it; keep that player topped.\n" ..
                "- Evocation: after the 10th flare he channels ~20s, does no damage, summons nothing, and takes +200% damage (triple) - burn hard.\n" ..
                "- Berserk: at 15% health he stops summoning flares and attacks faster with frequent Hateful Bolts." },
            { title = "Raid-Leader Tactic", body = "- Stack Bloodlust/Heroism + ALL dps cooldowns + trinkets/pots on the very FIRST Evocation window - the 200% amp lets that burst carry him a huge chunk, often near the 15% execute range.\n" ..
                "- Push him toward 15% so the final enrage is a short, survivable burn.\n" ..
                "- Below 15% no more flares - pure DPS race on the boss." },
        },
    },
})

ns.BossRegistry:Register("illhoof", {
    name          = "Terestian Illhoof",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Demonology fight; kill Demon Chains to free Sacrificed players (and stop Illhoof self-healing), AoE the imps, kill Kil'rek for +25% damage taken.",
    mechanics = {
        summary = "Illhoof Sacrifices a random raider into Demon Chains (a killable add) that must die to free them, while imp portals spew constant adds. His familiar Kil'rek, when killed, applies Broken Pact (+25% damage taken). 10-minute Berserk.",
        sections = {
            { title = "Sacrifice / Demon Chains", body = "- Periodically Sacrifices a RANDOM raider (never the main tank), stunning them and dealing ~1500 unresistable shadow/sec.\n" ..
                "- They are held by Demon Chains (~13k HP, a killable creature). While the chains are up, Illhoof self-heals ~3000 HP/sec.\n" ..
                "- DPS must instantly switch to kill the chains - this both saves the player AND stops his self-heal." },
            { title = "Adds", body = "- Imp portals continuously spawn weak imps casting Firebolt - AoE them down (Warlock Seed of Corruption / Hellfire is ideal).\n" ..
                "- Kil'rek: his familiar; casts Amplify Flames (+fire damage taken). On death applies Broken Pact: Illhoof takes +25% DAMAGE (a damage-taken debuff, not armor). Respawns ~45s later - re-kill it.\n" ..
                "- Assign dedicated AoE to keep imps from accumulating throughout." },
            { title = "Key Abilities", body = "- Shadow Bolt: ~4000 shadow to the top of the threat list (the tank).\n" ..
                "- Summon Demon Chains and the imp portals drive the encounter.\n" ..
                "- 10-minute Berserk (Shadow Bolt Volley spam)." },
            { title = "Raid-Leader Tactic", body = "- Glue 1-2 Warlocks (Seed of Corruption) to the imp portals so imps never pile up.\n" ..
                "- Pre-assign an instant-switch burst group to nuke Demon Chains the SECOND a Sacrifice lands.\n" ..
                "- KILL Kil'rek for the +25% damage buff (do not Banish it - you want it dead and it respawns anyway). Immunity classes can self-escape Sacrifice damage with Ice Block / Divine Shield / Barkskin." },
        },
    },
})

ns.BossRegistry:Register("aran", {
    name          = "Shade of Aran",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Movement-heavy caster; NOBODY moves during Flame Wreath, run to the WALLS for Arcane Explosion, watch the drink phase. Stay >10 yds from him to avoid his AoE Counterspell.",
    mechanics = {
        summary = "A caster boss; the raid spreads around the room and reacts to Flame Wreath, Blizzard, Arcane Explosion, and Conflagration. At 40% HEALTH he summons Water Elementals; at 20% MANA he Mass Polymorphs the raid, drinks, then unleashes a raid-wide Pyroblast. ~12-min Berserk.",
        sections = {
            { title = "Flame Wreath", body = "- Marks 3 random players with a fire ring (~20s); if ANY player crosses a ring (not just the marked ones) the whole raid takes massive damage.\n" ..
                "- One caller yells STOP the instant it casts - total positional discipline. Casting in place, turning, and pets are fine.\n" ..
                "- This is the most common wipe cause - call it clearly (DBM/BigWigs automates it)." },
            { title = "Key Abilities", body = "- Arcane Explosion: a ~10s-cast point-blank nuke (~20-yd radius) after he drags the raid inward - what saves you is DISTANCE: run to the walls (outside 20 yds), not just spreading.\n" ..
                "- Blizzard: a Blizzard rotates slowly clockwise around the room; step around it (except during Flame Wreath).\n" ..
                "- Conflagration: a random player is set on fire and disoriented (can't cast, random movement); run away from others.\n" ..
                "- Frostbolt / Fireball / Arcane Missiles as filler nukes; Chains of Ice is a dispellable root, not a summon." },
            { title = "Drink Phase (20% MANA)", body = "- At ~20% mana he Mass Polymorphs the ENTIRE raid (not Frost Nova/Ice Block), conjures water and drinks ~10s, the sheep breaks, then he hits the whole raid with Pyroblast (~7k to everyone).\n" ..
                "- Separately, at 40% HEALTH he summons 4 elite Water Elementals (Waterbolt spam, despawn ~90s).\n" ..
                "- Never let the 20%-mana and 40%-health windows overlap - stacked Pyroblast + Waterbolts wipes raids." },
            { title = "Raid-Leader Tactic", body = "- Assign dedicated interrupters all fight to kick his Frostbolt/Fireball - this slows his mana so he reaches the drink threshold less often.\n" ..
                "- Pre-shield/HoT the raid just before the Mass Polymorph breaks to soak the guaranteed Pyroblast.\n" ..
                "- Keep casters/healers >10 yds from Aran - he has an AoE Counterspell (~10 yd) that locks a spell school." },
        },
    },
})

ns.BossRegistry:Register("chess", {
    name          = "Chess Event",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Control chess pieces; defeat Medivh's King. Kill the enemy Bishops (healers) first, then mass focus the King. Nearly impossible to fail.",
    mechanics = {
        summary = "A non-traditional encounter where each player right-clicks and controls a chess piece. You win by killing the opposing (Medivh's) King - it is a kill with no enrage timer and no gear damage.",
        sections = {
            { title = "How It Works", body = "- Right-click a friendly piece to control it; you get Move, Change Facing, and two piece abilities (each on a ~5s shared cooldown).\n" ..
                "- Pieces move one tile any direction (Knights two straight), auto-attack what they face, and auto-cast but do NOT move while unmanned.\n" ..
                "- Win condition: kill Medivh's King; your own King must survive." },
            { title = "Piece Roles", body = "- King: strongest piece, frontal Sweep plus an ally damage buff - keep it alive and off fire.\n" ..
                "- Queen: main ranged damage. Bishop: HEALER (so kill the enemy Bishops first).\n" ..
                "- Knight: mobile harasser. Rook: AoE plus a self-shield.\n" ..
                "- Pawns: weak fodder for blocking and chip damage." },
            { title = "Medivh's Interventions", body = "- King's Hope: heals Medivh's King back up - this is why chipping slowly fails.\n" ..
                "- Hand of Medivh: a BERSERK buff (size/speed/+damage) on one of Medivh's pieces - it does NOT heal the King.\n" ..
                "- Fury of Medivh: a fire patch (~4k/sec post-nerf) under one of YOUR pieces - move off it immediately." },
            { title = "Raid-Leader Tactic", body = "- Kill Medivh's Bishops, then MASS focus-fire the enemy King with everything at once - burst it faster than King's Hope can heal.\n" ..
                "- Post-nerf the cheats are weak and pieces are replaceable, so the only real babysitting is moving a piece off Fury of Medivh fire the instant it appears." },
        },
    },
})

ns.BossRegistry:Register("prince", {
    name          = "Prince Malchezaar",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Three-phase fight; the Enfeeble + Shadow Nova combo is the main killer - Enfeebled players CANNOT be healed, they must run out of Shadow Nova range. Infernals fall the whole fight.",
    mechanics = {
        summary = "A three-phase fight (by HP) defined by the Enfeeble + Shadow Nova combo, Infernals raining persistent Hellfire patches the entire encounter, and a final phase where he releases two flying axes and casts Amplify Damage.",
        sections = {
            { title = "Phases", body = "- Phase 1 (100-60%): Enfeeble, Shadow Nova, Shadow Word: Pain; Infernals already falling.\n" ..
                "- Phase 2 (60-30%): he equips two axes (heavy tank melee spikes, Sunder/Thrash). Enfeeble and Shadow Nova CONTINUE - they do NOT stop.\n" ..
                "- Phase 3 (30-0%): he releases the two axes as untargetable FLYING axes that hit random raiders, gains Amplify Damage, and Infernal cadence jumps from ~45s to ~15s. He does NOT fly or cast Hellfire himself." },
            { title = "Key Abilities", body = "- Enfeeble: sets 5 random players (never the top-threat tank) to 1 max HP and NULLIFIES all healing for ~7s. Undispellable - you cannot heal through it.\n" ..
                "- Shadow Nova: ~3s cast, large raid-wide shadow AoE (~25-30 yds) plus knockback, timed to land right after Enfeeble - a 1-HP player caught in it dies instantly.\n" ..
                "- Infernals: untargetable, cannot be killed or tanked, leave a persistent Hellfire patch, despawn after ~180s.\n" ..
                "- Amplify Damage (P3): +100% damage taken for 10s, undispellable, often lands on the tank - can be an instant death without a cooldown." },
            { title = "Raid-Leader Tactic", body = "- Make Enfeeble a MOVEMENT rule: the instant it lands, affected players (and melee by default) run >25-30 yds from the boss before Shadow Nova finishes - out of range = safe.\n" ..
                "- Tell healers explicitly: do NOT waste heals during Enfeeble (it's nullified) - burst-heal the moment it expires.\n" ..
                "- Rotate external/personal cooldowns onto the tank for Phase 3 Amplify Damage." },
            { title = "Infernal Management", body = "- Fight in a large open area with a pre-assigned kite path; slowly walk the boss and raid to fresh ground away from each Hellfire patch.\n" ..
                "- React when the Infernal lands, not after Hellfire ticks. A poorly placed Infernal can soft-enrage the fight by shrinking usable space, especially in P3." },
        },
    },
})

ns.BossRegistry:Register("nightbane", {
    name          = "Nightbane",
    instance      = "Karazhan",
    templateType  = "info_only",
    notes         = "Optional summoned dragon (Blackened Urn at the Master's Terrace). Alternates ground and air phases; counter Bellowing Roar fear and burn the Rain of Bones skeletons before he lands.",
    mechanics = {
        summary = "An optional dragon summoned with the reusable Blackened Urn. He alternates a ground melee phase with an aerial bombardment phase, taking flight at 75%, 50%, and 25% health. Manage Charred Earth fire, Bellowing Roar fear, and the skeletons from Rain of Bones.",
        sections = {
            { title = "Ground Phase", body = "- Cleave: heavy frontal physical - face him away from the raid.\n" ..
                "- Tail Sweep: cone behind him (fire plus knockback) - keep the raid out of front and rear arcs.\n" ..
                "- Bellowing Roar: AoE fear (~2.5s cast, ~30s cooldown) - the main ground-phase danger.\n" ..
                "- Charred Earth: fire patch under a random player (~30s) - move out. Distracting Ash gives -30% hit chance (dispellable)." },
            { title = "Air Phase", body = "- Nightbane takes flight at 75%, 50%, and 25% HEALTH (not on a timer).\n" ..
                "- Rain of Bones: summons 5 Restless Skeletons (~13.5k HP each) that must die before he lands.\n" ..
                "- Smoking Blast: rapid hits on the highest-threat target, and it applies Searing Cinders (a stacking ~3k fire DoT, dispellable - dispel it).\n" ..
                "- Spread out and heal through the bombardment." },
            { title = "Raid-Leader Tactic", body = "- Skeletons: hard target-swap rule - the moment Rain of Bones lands, all DPS AoE the 5 skeletons with an off-tank/Challenging Shout holding them, so they die before he lands.\n" ..
                "- Bellowing Roar: drop a Tremor Totem at the tank's feet and/or Fear Ward the tank, and position Nightbane with his back to the outer wall with the tank OFF the open ledge edge - a feared/knocked tank then drifts into the room, not off the terrace." },
        },
    },
})
