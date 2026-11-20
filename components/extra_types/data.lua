-- Extra Types: every fixed table the part uses.
--
-- Move names are at most 12 letters (the game's own limit). TM numbers are
-- the same in every game: TM51-57 Fairy, TM58, TM60 and TM62 Steel,
-- TM59 and TM61 Dark.
-- Learner lists already include evolutions of a listed Pokemon.
local D = {}

-- One row per new TM. `group` says which setting owns it (its Nurse Joys
-- and its move's type): fairy, steel or dark. `gens` = games that get it.
D.TMS = {
  { number = 51, move = "DAZZLING_GLEAM", group = "fairy", gens = { 1, 2 } },
  { number = 52, move = "DISARMING_VOICE", group = "fairy", gens = { 1, 2 } },
  { number = 53, move = "DRAINING_KISS", group = "fairy", gens = { 1, 2 } },
  { number = 54, move = "PLAY_ROUGH", group = "fairy", gens = { 1, 2 } },
  { number = 55, move = "MOONBLAST", group = "fairy", gens = { 1, 2 } },
  { number = 56, move = "FAIRY_WIND", group = "fairy", gens = { 1, 2 } },
  { number = 57, move = "BABY_DOLL_EYES", group = "fairy", gens = { 1, 2 } },
  { number = 58, move = "METAL_SOUND", group = "steel", gens = { 1, 2 } },
  { number = 59, move = "TAUNT", group = "dark", gens = { 1, 2 } },
  { number = 60, move = "STEEL_WING", group = "steel", gens = { 1 } },
  { number = 61, move = "PURSUIT", group = "dark", gens = { 1 } },
  { number = 62, move = "IRON_TAIL", group = "steel", gens = { 1 } },
}

-- 1.74.0: Snatch (old TM62) became Taunt (TM59), and Iron Tail moved from
-- TM59 to TM62. The old ids stay known (hidden) so a save that has them
-- loads without losing anything; main.lua turns them into the new ones.
D.LEGACY_MOVES = { SNATCH = "TAUNT" }
D.LEGACY_ITEMS = { TM_SNATCH = "TM_TAUNT" }

-- The moves. `gen1` / `gen2` hold what differs between the two games:
-- the effect, and where the animation and sound are borrowed from.
-- A move a game already has (Gen 2's Iron Tail, Steel Wing, Pursuit) is
-- never registered there.
D.MOVES = {
  DAZZLING_GLEAM = {
    name = "DAZZLE GLEAM", type = "FAIRY", power = 80, accuracy = 100, pp = 10,
    text = "Damages the foe<NEXT>with strong light.",
    gen1 = { effect = "NO_ADDITIONAL_EFFECT", animFrom = "FLASH" },
    gen2 = { effect = "EFFECT_NORMAL_HIT", animFrom = "FLASH" },
  },
  DISARMING_VOICE = {
    name = "DISARM VOICE", type = "FAIRY", power = 40, accuracy = 100, pp = 15,
    text = "A charming cry<NEXT>that never misses.",
    gen1 = { effect = "SWIFT_EFFECT", animFrom = "SUPERSONIC" },
    gen2 = { effect = "EFFECT_ALWAYS_HIT", animFrom = "SUPERSONIC" },
  },
  DRAINING_KISS = {
    name = "DRAININGKISS", type = "FAIRY", power = 50, accuracy = 100, pp = 10,
    text = "A kiss that heals<NEXT>3/4 of the damage.",
    gen1 = { effect = "PH_DRAIN_3_4_EFFECT", animFrom = "LOVELY_KISS" },
    gen2 = { effect = "EFFECT_LEECH_HIT", animFrom = "SWEET_KISS" },
  },
  PLAY_ROUGH = {
    name = "PLAY ROUGH", type = "FAIRY", power = 90, accuracy = 90, pp = 10,
    text = "May lower the<NEXT>foe's ATTACK.",
    gen1 = { effect = "PH_ATTACK_DOWN_10_EFFECT", animFrom = "COMET_PUNCH" },
    gen2 = { effect = "EFFECT_ATTACK_DOWN_HIT", effectChance = 10,
             animFrom = "COMET_PUNCH" },
  },
  MOONBLAST = {
    name = "MOONBLAST", type = "FAIRY", power = 95, accuracy = 100, pp = 15,
    text = "May lower the<NEXT>foe's SPECIAL.",
    text2 = "May lower the<NEXT>foe's SPCL.ATK.",
    gen1 = { effect = "PH_SPECIAL_DOWN_30_EFFECT", animFrom = "AURORA_BEAM" },
    gen2 = { effect = "EFFECT_SP_ATK_DOWN_HIT", effectChance = 30,
             animFrom = "AURORA_BEAM" },
  },
  FAIRY_WIND = {
    name = "FAIRY WIND", type = "FAIRY", power = 40, accuracy = 100, pp = 30,
    text = "Stirs up a fairy<NEXT>wind to strike.",
    gen1 = { effect = "NO_ADDITIONAL_EFFECT", animFrom = "GUST" },
    gen2 = { effect = "EFFECT_NORMAL_HIT", animFrom = "GUST" },
  },
  BABY_DOLL_EYES = {
    name = "BABYDOLLEYES", type = "FAIRY", power = 0, accuracy = 100, pp = 30,
    priority = 1,
    text = "Lowers ATTACK.<NEXT>Always goes first.",
    gen1 = { effect = "ATTACK_DOWN1_EFFECT", animFrom = "LEER" },
    gen2 = { effect = "EFFECT_ATTACK_DOWN", animFrom = "CHARM" },
  },
  METAL_SOUND = {
    name = "METAL SOUND", type = "STEEL", power = 0, accuracy = 85, pp = 40,
    text = "Sharply lowers the<NEXT>foe's SPECIAL.",
    text2 = "Sharply lowers the<NEXT>foe's SPCL.DEF.",
    gen1 = { effect = "PH_SPECIAL_DOWN_2_EFFECT", animFrom = "SCREECH" },
    gen2 = { effect = "EFFECT_SP_DEF_DOWN_2", animFrom = "SCREECH" },
  },
  IRON_TAIL = {
    name = "IRON TAIL", type = "STEEL", power = 100, accuracy = 75, pp = 15,
    text = "An attack that may<NEXT>reduce DEFENSE.",
    gen1 = { effect = "PH_DEFENSE_DOWN_30_EFFECT", animFrom = "SLAM" },
  },
  STEEL_WING = {
    name = "STEEL WING", type = "STEEL", power = 70, accuracy = 90, pp = 25,
    text = "An attack that may<NEXT>up DEFENSE.",
    gen1 = { effect = "PH_DEFENSE_UP_10_EFFECT", animFrom = "WING_ATTACK" },
  },
  PURSUIT = {
    name = "PURSUIT", type = "DARK", power = 40, accuracy = 100, pp = 20,
    text = "Heavy damage if<NEXT>foe switches out.",
    gen1 = { effect = "NO_ADDITIONAL_EFFECT", animFrom = "QUICK_ATTACK" },
  },
  TAUNT = {
    name = "TAUNT", type = "DARK", power = 0, accuracy = 100, pp = 20,
    text = "Foe can only use<NEXT>attack moves.",
    -- Metronome's animation (1.75.0). Red/Blue/Yellow draw Gold's
    -- Metronome hand (hand_anim.lua); this is only its fallback.
    gen1 = { effect = "PH_TAUNT_EFFECT", animFrom = "METRONOME" },
    gen2 = { effect = "EFFECT_PH_TAUNT", animFrom = "METRONOME" },
  },
}

-- Who learns each TM. gen1 = Red/Blue/Yellow species; gen2 = the extra
-- species Gold/Silver/Crystal add on top of the gen1 list.
D.LEARNERS = {
  [51] = {
    gen1 = { "CLEFAIRY", "CLEFABLE", "JIGGLYPUFF", "WIGGLYTUFF", "ODDISH",
      "GLOOM", "VILEPLUME", "ABRA", "KADABRA", "ALAKAZAM", "TENTACOOL",
      "TENTACRUEL", "GASTLY", "HAUNTER", "GENGAR", "DROWZEE", "HYPNO",
      "CHANSEY", "STARYU", "STARMIE", "MR_MIME", "MEW" },
    gen2 = { "CHINCHOU", "LANTURN", "TOGEPI", "TOGETIC", "NATU", "XATU",
      "BELLOSSOM", "HOPPIP", "SKIPLOOM", "JUMPLUFF", "ESPEON", "MISDREAVUS",
      "GIRAFARIG", "SNUBBULL", "GRANBULL", "BLISSEY", "CELEBI" },
  },
  [52] = {
    gen1 = { "CLEFAIRY", "CLEFABLE", "JIGGLYPUFF", "WIGGLYTUFF" },
    gen2 = {},
  },
  [53] = {
    gen1 = { "JYNX" },
    gen2 = {},
  },
  [54] = {
    gen1 = { "WIGGLYTUFF", "PERSIAN" },
    gen2 = { "MARILL", "AZUMARILL", "SNUBBULL", "GRANBULL" },
  },
  [55] = {
    gen1 = { "CLEFAIRY", "CLEFABLE", "ODDISH", "GLOOM", "VILEPLUME" },
    gen2 = { "HOOTHOOT", "NOCTOWL", "BELLOSSOM" },
  },
  -- Fairy types only (the Gen 6 typings), whatever the settings say.
  [56] = {
    gen1 = { "CLEFAIRY", "CLEFABLE", "JIGGLYPUFF", "WIGGLYTUFF", "MR_MIME" },
    gen2 = { "CLEFFA", "IGGLYBUFF", "TOGEPI", "TOGETIC", "MARILL",
      "AZUMARILL", "SNUBBULL", "GRANBULL" },
  },
  [57] = {
    gen1 = { "VULPIX", "NINETALES", "EEVEE", "VAPOREON", "JOLTEON", "FLAREON" },
    gen2 = { "ESPEON", "UMBREON", "TEDDIURSA", "URSARING" },
  },
  [58] = {
    gen1 = { "MAGNEMITE", "MAGNETON", "KABUTO", "KABUTOPS" },
    gen2 = { "SKARMORY" },
  },
  -- Taunt: Pokemon that learn it by TM12 in Ruby/Sapphire/Emerald
  -- (Murkrow and Sneasel also learn it by level there).
  [59] = {
    gen1 = { "RATTATA", "RATICATE", "NIDOQUEEN", "NIDOKING", "ZUBAT", "GOLBAT",
      "MEOWTH", "PERSIAN", "MANKEY", "PRIMEAPE", "ABRA", "KADABRA", "ALAKAZAM",
      "DODRIO", "GRIMER", "MUK", "GASTLY", "HAUNTER", "GENGAR", "ONIX",
      "DROWZEE", "HYPNO", "VOLTORB", "ELECTRODE", "KOFFING", "WEEZING",
      "MR_MIME", "JYNX", "GYARADOS", "AERODACTYL", "MEWTWO", "MEW" },
    gen2 = { "CROBAT", "SUDOWOODO", "AIPOM", "UMBREON", "MURKROW", "MISDREAVUS",
      "STEELIX", "SNUBBULL", "GRANBULL", "SNEASEL", "TEDDIURSA", "URSARING",
      "SKARMORY", "HOUNDOUR", "HOUNDOOM", "LARVITAR", "PUPITAR", "TYRANITAR" },
  },
  -- Iron Tail (TM59 until 1.74.0)
  [62] = {
    gen1 = { "CHARMANDER", "CHARMELEON", "CHARIZARD", "SQUIRTLE", "WARTORTLE",
      "BLASTOISE", "RATTATA", "RATICATE", "EKANS", "ARBOK", "PIKACHU",
      "RAICHU", "SANDSHREW", "SANDSLASH", "NIDORAN_F", "NIDORINA",
      "NIDOQUEEN", "NIDORAN_M", "NIDORINO", "NIDOKING", "CLEFAIRY",
      "CLEFABLE", "VULPIX", "NINETALES", "MEOWTH", "PERSIAN", "PSYDUCK",
      "GOLDUCK", "MANKEY", "PRIMEAPE", "GROWLITHE", "ARCANINE", "ABRA",
      "KADABRA", "ALAKAZAM", "PONYTA", "RAPIDASH", "SLOWPOKE", "SLOWBRO",
      "FARFETCHD", "ONIX", "CUBONE", "MAROWAK", "LICKITUNG", "RHYHORN",
      "RHYDON", "CHANSEY", "KANGASKHAN", "ELECTABUZZ", "MAGMAR", "TAUROS",
      "LAPRAS", "EEVEE", "VAPOREON", "JOLTEON", "FLAREON", "PORYGON",
      "AERODACTYL", "DRATINI", "DRAGONAIR", "DRAGONITE", "MEWTWO", "MEW" },
  },
  [60] = {
    gen1 = { "CHARIZARD", "PIDGEY", "PIDGEOTTO", "PIDGEOT", "SPEAROW",
      "FEAROW", "ZUBAT", "GOLBAT", "FARFETCHD", "DODUO", "DODRIO", "SCYTHER",
      "AERODACTYL", "ARTICUNO", "ZAPDOS", "MOLTRES", "DRAGONITE", "MEW" },
  },
  [61] = {
    gen1 = { "BEEDRILL", "RATTATA", "RATICATE", "SPEAROW", "FEAROW", "DODUO",
      "DODRIO", "HITMONCHAN", "SCYTHER", "TAUROS" },
  },
}

-- Species ids the games spell differently.
D.ALIASES = {
  FARFETCHD = { "FARFETCHD", "FARFETCH_D" },
  MR_MIME = { "MR_MIME", "MR__MIME" },
}

-- Typings, in the Gen 6 order.
D.STEEL_PKMN = {
  MAGNEMITE = { "ELECTRIC", "STEEL" },
  MAGNETON = { "ELECTRIC", "STEEL" },
}
D.FAIRY_PKMN = {
  CLEFAIRY = { "FAIRY", "FAIRY" },
  CLEFABLE = { "FAIRY", "FAIRY" },
  JIGGLYPUFF = { "NORMAL", "FAIRY" },
  WIGGLYTUFF = { "NORMAL", "FAIRY" },
  MR_MIME = { "PSYCHIC_TYPE", "FAIRY" },
  -- Gold/Silver/Crystal only
  CLEFFA = { "FAIRY", "FAIRY" },
  IGGLYBUFF = { "NORMAL", "FAIRY" },
  TOGEPI = { "FAIRY", "FAIRY" },
  TOGETIC = { "FAIRY", "FLYING" },
  MARILL = { "WATER", "FAIRY" },
  AZUMARILL = { "WATER", "FAIRY" },
  SNUBBULL = { "FAIRY", "FAIRY" },
  GRANBULL = { "FAIRY", "FAIRY" },
}

-- Old moves whose type a setting changes.
D.GEN2_FAIRY_OLD_MOVES = { "CHARM", "MOONLIGHT", "SWEET_KISS" }
D.GEN1_OTHER_MOVES = {
  GUST = "FLYING", KARATE_CHOP = "FIGHTING", SAND_ATTACK = "GROUND",
  SANDATTACK = "GROUND",
}

-- The type chart. Multipliers are x10 (20 = 2x, 5 = 1/2x, 0 = none).
D.FAIRY_ROWS = {
  { "FAIRY", "FIGHTING", 20 }, { "FAIRY", "DRAGON", 20 }, { "FAIRY", "DARK", 20 },
  { "FAIRY", "FIRE", 5 }, { "FAIRY", "POISON", 5 }, { "FAIRY", "STEEL", 5 },
  { "FIGHTING", "FAIRY", 5 }, { "BUG", "FAIRY", 5 }, { "DARK", "FAIRY", 5 },
  { "POISON", "FAIRY", 20 }, { "STEEL", "FAIRY", 20 }, { "DRAGON", "FAIRY", 0 },
}
-- Red/Blue/Yellow only: Gold already has Dark and Steel.
D.DARK_ROWS = {
  { "DARK", "GHOST", 20 }, { "DARK", "PSYCHIC_TYPE", 20 },
  { "DARK", "FIGHTING", 5 }, { "DARK", "DARK", 5 },
  { "FIGHTING", "DARK", 20 }, { "BUG", "DARK", 20 },
  { "PSYCHIC_TYPE", "DARK", 0 }, { "GHOST", "DARK", 5 }, { "DARK", "DARK", 5 },
}
D.STEEL_ROWS = {
  { "STEEL", "ICE", 20 }, { "STEEL", "ROCK", 20 }, { "STEEL", "FIRE", 5 },
  { "STEEL", "WATER", 5 }, { "STEEL", "ELECTRIC", 5 }, { "STEEL", "STEEL", 5 },
  { "NORMAL", "STEEL", 5 }, { "FLYING", "STEEL", 5 }, { "ROCK", "STEEL", 5 },
  { "BUG", "STEEL", 5 }, { "GRASS", "STEEL", 5 }, { "PSYCHIC_TYPE", "STEEL", 5 },
  { "ICE", "STEEL", 5 }, { "DRAGON", "STEEL", 5 }, { "POISON", "STEEL", 0 },
  { "FIGHTING", "STEEL", 20 }, { "GROUND", "STEEL", 20 }, { "FIRE", "STEEL", 20 },
}
-- Rows the chart settings switch. [choice] = multiplier.
D.VS_STEEL = {
  { "GHOST", "STEEL", gen2 = 5, gen6 = 10 },
  { "DARK", "STEEL", gen2 = 5, gen6 = 10 },
}
D.EFFECTIVENESS = {
  { "GHOST", "PSYCHIC_TYPE", gen1 = 0, gen2 = 20 },
  { "BUG", "POISON", gen1 = 20, gen2 = 5 },
  { "POISON", "BUG", gen1 = 20, gen2 = 10 },
  { "ICE", "FIRE", gen1 = 10, gen2 = 5 },
}

-- The extra Nurse Joy, to the left of the PC (Gen 1: behind the counter
-- beside the Cable Club desk; Gen 2: in the top-right corner).
D.NURSES = {
  [1] = {
    { map = "VIRIDIAN_POKECENTER", tm = 51, x = 12, y = 2 },
    { map = "PEWTER_POKECENTER", tm = 62, x = 12, y = 2 },
    { map = "MT_MOON_POKECENTER", tm = 52, x = 12, y = 2 },
    { map = "CERULEAN_POKECENTER", tm = 61, x = 12, y = 2 },
    { map = "VERMILION_POKECENTER", tm = 53, x = 12, y = 2 },
    { map = "ROCK_TUNNEL_POKECENTER", tm = 60, x = 12, y = 2 },
    { map = "LAVENDER_POKECENTER", tm = 54, x = 12, y = 2 },
    { map = "CELADON_POKECENTER", tm = 59, x = 12, y = 2 },
    { map = "SAFFRON_POKECENTER", tm = 57, x = 12, y = 2 },
    { map = "FUCHSIA_POKECENTER", tm = 58, x = 12, y = 2 },
    { map = "CINNABAR_POKECENTER", tm = 55, x = 12, y = 2 },
    { map = "INDIGO_PLATEAU_LOBBY", tm = 56, x = 14, y = 6 },
  },
  [2] = {
    { map = "CHERRYGROVE_POKECENTER_1F", tm = 59, x = 8, y = 1 },
    -- Violet's corner is taken by a Youngster, so its Joy stands one step
    -- further left.
    { map = "VIOLET_POKECENTER_1F", tm = 51, x = 7, y = 1 },
    { map = "ROUTE_32_POKECENTER_1F", tm = 52, x = 8, y = 1 },
    { map = "AZALEA_POKECENTER_1F", tm = 53, x = 8, y = 1 },
    { map = "ECRUTEAK_POKECENTER_1F", tm = 58, x = 8, y = 1 },
    { map = "OLIVINE_POKECENTER_1F", tm = 54, x = 8, y = 1 },
    { map = "CIANWOOD_POKECENTER_1F", tm = 57, x = 8, y = 1 },
    { map = "MAHOGANY_POKECENTER_1F", tm = 56, x = 8, y = 1 },
    { map = "BLACKTHORN_POKECENTER_1F", tm = 55, x = 8, y = 1 },
  },
}

D.TEXT = {
  gift = "Thank you for\nbeing a loyal\fcustomer of the\nPOKéMON CENTER.\fHere's a free TM\nfor you!",
  got = "You got\n%s!",
  full = "You have no room\nfor this TM!",
  bye = "Have a nice day!",
}

return D
