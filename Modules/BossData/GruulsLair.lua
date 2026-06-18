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
    -- 5 icon-keyed rows. The `mob` field drives one-click Auto-Mark. These
    -- icons are just markers (not the kill order) - use "Scan Marks" to verify.
    enemies = {
        { key = "skull",    iconIdx = 8, label = "Skull",    mob = "Krosh Firehand" },
        { key = "cross",    iconIdx = 7, label = "Cross",    mob = "Kiggler the Crazed" },
        { key = "square",   iconIdx = 6, label = "Square",   mob = "Blindeye the Seer" },
        { key = "moon",     iconIdx = 5, label = "Moon",     mob = "Olm the Summoner" },
        { key = "triangle", iconIdx = 4, label = "Triangle", mob = "High King Maulgar" },
    },
    notes = "Mark each council member with a raid icon. Kill order: Blindeye > Olm > Krosh > Kiggler > Maulgar. A mage tanks Krosh in a corner. Warlocks Banish/Enslave Olm's Wild Felhunters.",
    mechanics = {
        summary = "A council fight: all five enemies pull at once and each needs its own tank/handler. Pick them all up in the first GCD - one loose caster or a loose Maulgar shreds the raid - then kill in the set order while CC holds the others.",
        sections = {
            {
                title = "Pull & Control",
                body = "- Mark all five with raid icons and assign a tank/handler to each BEFORE the pull.\n"
                    .. "- The standard opener: warrior tanks Maulgar, the mage runs to a far corner to tank Krosh, a tank or hunter holds Kiggler, a tank holds Olm, and Blindeye gets picked up - everyone grabs their target on the first GCD.\n"
                    .. "- Pop Bloodlust/Heroism at the start to burn Blindeye down before he can land a heal.\n"
                    .. "- Heavy raid damage throughout (Blast Wave, Death Coil, Lightning Bolt) - keep everyone topped and pre-assign healers per tank.",
            },
            {
                title = "Kill Order",
                body = "Blindeye the Seer > Olm the Summoner > Krosh Firehand > Kiggler the Crazed > High King Maulgar.\n"
                    .. "(Blindeye first because he heals/shields the whole council; Maulgar is only the focus once the four advisers are dead.)",
            },
            {
                title = "The Council",
                body = "- Blindeye the Seer: priest - Heal (heals a council member to full - INTERRUPT every cast) and Greater Power Word: Shield. Kill first, ideally under Bloodlust.\n"
                    .. "- Olm the Summoner: warlock - Death Coil, Dark Decay, and Summon Wild Felhunter. WARLOCKS handle the felhunters: Enslave Demon one, Banish/Fear the rest as they spawn (they are demons, not stunnable). Tank Olm steady.\n"
                    .. "- Krosh Firehand: mage - no melee, casts Greater Fireball and Blast Wave, and shields himself with Spell Shield. A MAGE tanks him in a far corner away from the raid: SPELLSTEAL the Spell Shield (a spell-damage absorb - stealing it both strips Krosh and protects the mage), then hold threat with light DPS. Corner-position him so his Blast Wave never clips the raid.\n"
                    .. "- Kiggler the Crazed: shaman - Lightning Bolt, Arcane Shock, Greater Polymorph (a random sheep), Earth Shock. A tank or hunter keeps him in place at range; spread a little so his Arcane Explosion does not chain.\n"
                    .. "- High King Maulgar: focused last - Arcing Smash, Mighty Blow, Whirlwind, Charge, and Roar (raid-wide attack-speed slow / Flurry on himself). Tank him away from the raid; melee step out during Whirlwind.",
            },
        },
    },
})

----------------------------------------------------------------------
-- Gruul the Dragonkiller - main tank + off-tank (Hurtful Strike), the
-- raid spreads for Shatter and avoids Cave In.
----------------------------------------------------------------------
ns.BossRegistry:Register("gruul", {
    name          = "Gruul the Dragonkiller",
    announceTitle = "Gruul - Tanks",
    instance      = "Gruul's Lair",
    templateType  = "slots",
    notes         = "Main tank + a melee off-tank kept as the clear #2 on threat for Hurtful Strike. Whole raid spreads 8+ yards for Shatter; race his Growth stacks.",
    slots = {
        { key = "tank1", label = "Main Tank", tip = "Holds Gruul in the center, facing him away from the raid. Takes the biggest hits; stack healers here and watch for Growth scaling around stack 15+." },
        { key = "tank2", label = "Off Tank (Hurtful)", tip = "Stays in melee as the clear #2 on threat so Hurtful Strike (hits the second-highest threat in melee) lands on a geared tank, not a squishy. Keep threat just under the main tank - never pass it." },
    },
    mechanics = {
        summary = "A single-target soft-enrage fight: Gruul grows stronger every 30s while the raid survives Hurtful Strike, Cave In, and the Ground Slam -> Shatter combo. Stay spread the whole fight and burn him before Growth makes him unhealable.",
        sections = {
            {
                title = "Growth (soft enrage)",
                body = "- Gruul gains a stacking Growth buff roughly every 30 seconds: +10% size and +15% damage per stack.\n"
                    .. "- This is the enrage clock - around 15-20 stacks he one-shots tanks. Save Bloodlust/Heroism and DPS cooldowns to end the fight before then.",
            },
            {
                title = "Hurtful Strike",
                body = "- Hits the SECOND-highest threat target in melee range for a huge physical blow (mitigatable).\n"
                    .. "- Keep a geared off-tank parked as the clear #2 on threat so it never lands on a DPS or healer. Ranged are immune - this is purely a melee/off-tank problem.",
            },
            {
                title = "Ground Slam -> Shatter",
                body = "- Ground Slam tosses the whole raid into the air and knocks everyone in random directions, then applies Gronn Lord's Grasp (-20% move speed, stacks to 5; at 5 stacks you are Stoned and rooted).\n"
                    .. "- It is followed by Shatter: everyone takes damage scaled by how close they are to other players, plus a stacking damage-taken debuff.\n"
                    .. "- SPREAD OUT (8+ yards, ideally 10-15) and keep moving apart the instant you land, BEFORE you get Stoned - stacked players die. Do not panic-bunch when the knockback scatters you.",
            },
            {
                title = "Cave In",
                body = "- Rocks crash down on random spots for heavy damage - move off the marked ground immediately, without bunching up with anyone else.",
            },
            {
                title = "Reverberation & Positioning",
                body = "- Reverberation is a periodic ground-stomp silence - tanks keep targets topped and refresh HoTs before it lands.\n"
                    .. "- Tank Gruul in the center, raid spread the ENTIRE fight so every Shatter is survivable: melee in a loose ring at max melee range, ranged and healers fanned out near the walls.\n"
                    .. "- Reposition out of Cave In and after Ground Slam without ever clumping.",
            },
        },
    },
})
