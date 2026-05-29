----------------------------------------------------------------------
-- RaidLead — BuffData.lua
-- Buff / consumable definitions.
-- Uses spell IDs (resolved via GetSpellInfo) so names auto-localize
-- to the client's language. English fallbacks are kept in case an
-- ID is unavailable or wrong.
----------------------------------------------------------------------

RaidSpyBuffs = {}

----------------------------------------------------------------------
-- Helper: resolve a list of spell IDs to localized names, optionally
-- merged with English fallbacks. De-duplicates.
----------------------------------------------------------------------
local function ResolveNames(idList, fallbacks)
    local names = {}
    local seen = {}
    if idList then
        for _, id in ipairs(idList) do
            local n = GetSpellInfo and GetSpellInfo(id)
            if n and not seen[n] then
                names[#names + 1] = n
                seen[n] = true
            end
        end
    end
    if fallbacks then
        for _, n in ipairs(fallbacks) do
            if not seen[n] then
                names[#names + 1] = n
                seen[n] = true
            end
        end
    end
    return names
end

----------------------------------------------------------------------
-- Spell ID lists (TBC era)
----------------------------------------------------------------------
local FLASK_IDS = {
    -- TBC flasks
    28520,  -- Flask of Fortification
    28540,  -- Flask of Relentless Assault
    28521,  -- Flask of Pure Death
    28518,  -- Flask of Blinding Light
    28519,  -- Flask of Mighty Restoration
    28522,  -- Flask of Chromatic Wonder
    -- Classic flasks
    17626,  -- Flask of the Titans
    17627,  -- Distilled Wisdom
    17628,  -- Supreme Power
    17629,  -- Chromatic Resistance
}

local BATTLE_ELIXIR_IDS = {
    28497,  -- Elixir of Major Agility
    28501,  -- Elixir of Major Firepower
    28493,  -- Elixir of Major Frost Power
    28503,  -- Elixir of Major Shadow Power
    28491,  -- Elixir of Healing Power
    28490,  -- Elixir of Major Strength
    33726,  -- Elixir of Mastery
    28494,  -- Adept's Elixir
    33828,  -- Onslaught Elixir
    17538,  -- Elixir of the Mongoose
    31679,  -- Fel Strength Elixir
}

local GUARDIAN_ELIXIR_IDS = {
    28502,  -- Elixir of Major Defense
    28514,  -- Elixir of Major Fortitude
    28509,  -- Elixir of Major Mageblood
    39628,  -- Elixir of Ironskin
    39627,  -- Earthen Elixir
    39626,  -- Elixir of Draenic Wisdom
}

-- Well Fed buff IDs (food sets a generic "Well Fed" buff)
local FOOD_IDS = {
    19705,  -- Well Fed (canonical)
    24870,  -- Well Fed (variant)
}

----------------------------------------------------------------------
-- Build the localized lists
----------------------------------------------------------------------
RaidSpyBuffs.flasks = ResolveNames(FLASK_IDS, {
    "Flask of Relentless Assault",
    "Flask of Pure Death",
    "Flask of Blinding Light",
    "Flask of Mighty Restoration",
    "Flask of Fortification",
    "Flask of Chromatic Wonder",
    "Supreme Power",
    "Distilled Wisdom",
    "Flask of the Titans",
    "Flask of Chromatic Resistance",
})

RaidSpyBuffs.battleElixirs = ResolveNames(BATTLE_ELIXIR_IDS, {
    "Elixir of Major Agility",
    "Elixir of Major Firepower",
    "Elixir of Major Frost Power",
    "Elixir of Major Shadow Power",
    "Elixir of Healing Power",
    "Elixir of Major Strength",
    "Elixir of Mastery",
    "Adept's Elixir",
    "Onslaught Elixir",
    "Elixir of the Mongoose",
    "Fel Strength Elixir",
})

RaidSpyBuffs.guardianElixirs = ResolveNames(GUARDIAN_ELIXIR_IDS, {
    "Elixir of Major Defense",
    "Elixir of Major Fortitude",
    "Elixir of Major Mageblood",
    "Elixir of Draenic Wisdom",
    "Elixir of Ironskin",
    "Earthen Elixir",
})

RaidSpyBuffs.food = ResolveNames(FOOD_IDS, {
    "Well Fed",
})

----------------------------------------------------------------------
-- Raid buffs (class-provided), grouped by buff family
-- Each family has spell IDs covering single-target + group versions
-- across all useful ranks. ResolveNames builds a localized name list.
----------------------------------------------------------------------
RaidSpyBuffs.raidBuffs = {
    motw = {
        label   = "MotW",
        class   = "DRUID",
        icon    = "Interface\\Icons\\Spell_Nature_Regeneration",
        spellIds = {
            -- Mark of the Wild ranks
            1126, 5232, 6756, 5234, 8907, 9884, 9885, 26990,
            -- Gift of the Wild ranks
            21849, 21850, 26991,
        },
        fallbacks = { "Mark of the Wild", "Gift of the Wild" },
    },
    fort = {
        label   = "Fort",
        class   = "PRIEST",
        icon    = "Interface\\Icons\\Spell_Holy_WordFortitude",
        spellIds = {
            -- Power Word: Fortitude
            1243, 1244, 1245, 2791, 10937, 10938, 25389,
            -- Prayer of Fortitude
            21562, 21564, 25392,
        },
        fallbacks = { "Power Word: Fortitude", "Prayer of Fortitude" },
    },
    ai = {
        label   = "Int",
        class   = "MAGE",
        icon    = "Interface\\Icons\\Spell_Holy_MagicalSentry",
        spellIds = {
            -- Arcane Intellect
            1459, 1460, 1461, 10156, 10157, 27126,
            -- Arcane Brilliance
            23028, 27127,
        },
        fallbacks = { "Arcane Intellect", "Arcane Brilliance" },
    },
    spirit = {
        label   = "Spirit",
        class   = "PRIEST",
        icon    = "Interface\\Icons\\Spell_Holy_DivineSpirit",
        spellIds = {
            -- Divine Spirit
            14752, 14818, 14819, 27841, 25312,
            -- Prayer of Spirit
            27681, 32999,
        },
        fallbacks = { "Divine Spirit", "Prayer of Spirit" },
    },
    shadow = {
        label   = "SProt",
        class   = "PRIEST",
        icon    = "Interface\\Icons\\Spell_Shadow_AntiShadow",
        spellIds = {
            -- Shadow Protection
            976, 10957, 10958, 27683,
            -- Prayer of Shadow Protection
            27683, 39374,
        },
        fallbacks = { "Shadow Protection", "Prayer of Shadow Protection" },
    },
    kings = {
        label   = "Kings",
        class   = "PALADIN",
        icon    = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
        spellIds = {
            20217,  -- Blessing of Kings
            25898,  -- Greater Blessing of Kings
        },
        fallbacks = { "Blessing of Kings", "Greater Blessing of Kings" },
    },
    might = {
        label   = "Might",
        class   = "PALADIN",
        icon    = "Interface\\Icons\\Spell_Holy_FistOfJustice",
        spellIds = {
            -- Blessing of Might
            19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140,
            -- Greater Blessing of Might
            25916, 27141,
        },
        fallbacks = { "Blessing of Might", "Greater Blessing of Might" },
    },
    wisdom = {
        label   = "Wis",
        class   = "PALADIN",
        icon    = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
        spellIds = {
            -- Blessing of Wisdom
            19742, 19850, 19852, 19853, 19854, 25290, 27142,
            -- Greater Blessing of Wisdom
            25918, 27143,
        },
        fallbacks = { "Blessing of Wisdom", "Greater Blessing of Wisdom" },
    },
    salvation = {
        label   = "Salv",
        class   = "PALADIN",
        icon    = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
        spellIds = {
            1038,   -- Blessing of Salvation
            25895,  -- Greater Blessing of Salvation
        },
        fallbacks = { "Blessing of Salvation", "Greater Blessing of Salvation" },
    },
    light = {
        label   = "Light",
        class   = "PALADIN",
        icon    = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02",
        spellIds = {
            19977, 19978, 19979, 27144,  -- Blessing of Light
            25890,                          -- Greater Blessing of Light
        },
        fallbacks = { "Blessing of Light", "Greater Blessing of Light" },
    },
    battleShout = {
        label   = "BShout",
        class   = "WARRIOR",
        icon    = "Interface\\Icons\\Ability_Warrior_BattleShout",
        spellIds = {
            6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436,
        },
        fallbacks = { "Battle Shout" },
    },
    commandingShout = {
        label   = "CShout",
        class   = "WARRIOR",
        icon    = "Interface\\Icons\\Ability_Warrior_RallyingCry",
        spellIds = {
            469,    -- Commanding Shout (TBC)
            47439,  -- (later)
        },
        fallbacks = { "Commanding Shout" },
    },
    trueshotAura = {
        label   = "Trueshot",
        class   = "HUNTER",
        icon    = "Interface\\Icons\\Ability_TrueShot",
        spellIds = {
            19506, 20905, 20906, 27066,
        },
        fallbacks = { "Trueshot Aura" },
    },
}

-- Resolve raid buff names per family
for _, family in pairs(RaidSpyBuffs.raidBuffs) do
    family.buffs = ResolveNames(family.spellIds, family.fallbacks)
end

----------------------------------------------------------------------
-- Reverse-lookup tables (built once at load time)
----------------------------------------------------------------------
RaidSpyBuffs.buffLookup     = {}  -- "BuffName" -> category
RaidSpyBuffs.raidBuffLookup = {}  -- "BuffName" -> familyKey

for _, name in ipairs(RaidSpyBuffs.flasks) do
    RaidSpyBuffs.buffLookup[name] = "flask"
end
for _, name in ipairs(RaidSpyBuffs.battleElixirs) do
    RaidSpyBuffs.buffLookup[name] = "battleElixir"
end
for _, name in ipairs(RaidSpyBuffs.guardianElixirs) do
    RaidSpyBuffs.buffLookup[name] = "guardianElixir"
end
for _, name in ipairs(RaidSpyBuffs.food) do
    RaidSpyBuffs.buffLookup[name] = "food"
end
for familyKey, family in pairs(RaidSpyBuffs.raidBuffs) do
    for _, name in ipairs(family.buffs) do
        RaidSpyBuffs.raidBuffLookup[name] = familyKey
    end
end
