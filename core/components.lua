-- Project Highlander's parts, one entry each.
--   id            the part's name inside the mod (mod.find, settings lookups)
--   folder        its folder under components/ (defaults to the id)
--   key           prefix of its saved settings ("other_settings.coins_2x")
--   name / short  names for logs and the settings menus
--   installOrder  parts install from low to high
--   files/assets  checked before anything installs, so a broken zip fails
--                 cleanly instead of half-loading
--   alwaysOn      no ON/OFF switch of its own
--   hubHidden     no page in the PROJECTHIGHLANDER menu
--   rowOrder      page rows in this order instead of A-Z
return {
  {
    -- Highlander Start Menu (1.27.0).
    id = "highlander_start",
    folder = "start_menu",
    key = "hstart",
    name = "Highlander Start Menu",
    short = "START",
    version = "1.0.0",
    installOrder = 5,
    files = { "main.lua", "entries.lua", "page.lua", "custom_icons.lua", "icons.lua" },
    assets = { "assets/start_menu_icons_16.png" },
  },
  {
    -- Highlander Party (1.21.0).
    id = "highlander_party",
    folder = "party",
    key = "hparty",
    name = "Highlander Party",
    short = "HIGHLANDER PARTY",
    version = "1.0.0",
    installOrder = 3,
    defaultEnabled = true,
    -- No page of its own: OTHER SETTINGS > HIGHLANDER PARTY is its ON/OFF.
    hubHidden = true,
    files = {
      "main.lua", "common.lua", "gen1_party.lua", "gen1_summary.lua",
      "gen2.lua", "move_descriptions.lua",
    },
  },
  {
    -- Highlander Bag (1.41.0).
    id = "highlander_bag",
    folder = "bag",
    key = "hbag",
    name = "Highlander Bag",
    short = "HIGHLANDER BAG",
    version = "1.0.0",
    installOrder = 1,
    defaultEnabled = true,
    -- No page of its own: OTHER SETTINGS > HIGHLANDER BAG is its ON/OFF.
    hubHidden = true,
    files = { "main.lua", "common.lua", "storage.lua", "gen1.lua", "gen2.lua",
      "descriptions.lua" },
    assets = { "assets/bag_gen1.png", "assets/switch_pockets.wav" },
  },
  {
    -- Highlander PC (1.45.0): every box shown as one big box over the
    -- game's own boxes.
    id = "highlander_pc",
    folder = "pc",
    key = "hpc",
    name = "Highlander PC",
    short = "HIGHLANDER PC",
    version = "1.0.0",
    installOrder = 6,
    defaultEnabled = true,
    -- No page of its own: OTHER SETTINGS > HIGHLANDER PC is its ON/OFF.
    hubHidden = true,
    files = { "main.lua", "storage.lua", "screen.lua" },
  },
  {
    id = "highlander_pokedex",
    folder = "pokedex",
    key = "phdex",
    name = "Highlander Dex",
    short = "HIGHLANDER DEX",
    version = "1.0.0",
    installOrder = 7,
    defaultEnabled = true,
    -- No page of its own: OTHER SETTINGS > HIGHLANDER DEX is its ON/OFF.
    hubHidden = true,
    files = { "main.lua", "screen.lua", "data.lua", "locations.lua" },
  },
  {
    -- Highlander Trainer ID (1.36.0): Gold's trainer card for Gen 1.
    id = "highlander_trainer_id",
    folder = "trainer_id",
    key = "htid",
    name = "Highlander Trainer ID",
    short = "HIGHLANDER ID",
    version = "1.0.0",
    installOrder = 17,
    defaultEnabled = true,
    -- 1.37.0: always on, no ON/OFF row and no page (the game's own Gen 1
    -- card can cut the portrait off on some PCs).
    alwaysOn = true,
    hubHidden = true,
    files = { "main.lua", "screen.lua" },
    assets = { "assets/kanto_leaders_gen1.png", "assets/kanto_badges.png",
      "assets/badge_numbers.png" },
  },
  {
    id = "battle_screen",
    folder = "battle_screen",
    -- No ON/OFF of its own: every option on its page stands alone.
    alwaysOn = true,
    key = "battle_screen",
    name = "Battle Screen",
    short = "BATTLE SCREEN",
    version = "1.0.0",
    installOrder = 2,
    files = { "main.lua", "gen1.lua", "gen2.lua", "highlander_hud.lua", "unlimited_pp.lua",
      "status_reset.lua" },
    assets = { "assets/exp_bar_tick.wav" },
  },
  {
    id = "move_colors",
    folder = "move_colors",
    -- No ON/OFF of its own: every option on its page stands alone.
    alwaysOn = true,
    key = "move_colors",
    name = "Move Colours (Battle Screen)",
    short = "MOVE COLOURS",
    version = "1.0.0",
    installOrder = 4,
    files = { "main.lua", "colored_pokeballs.lua", "colored_pokemoves.lua" },
  },
  {
    id = "other_settings",
    folder = "other_settings",
    -- No ON/OFF of its own: every option on its page stands alone.
    alwaysOn = true,
    key = "other_settings",
    name = "Other Settings",
    short = "OTHER SETTINGS",
    version = "0.2.0",
    installOrder = 8,
    defaultEnabled = true,
    files = { "main.lua", "secret_mew.lua", "all_pkmn_gen1.lua", "all_pkmn_gen2.lua",
      "force_crystal.lua", "catch_rate.lua", "legendary_persist.lua",
      "blue_into_green.lua" },
    assets = { "assets/sparkle.png",
      "assets/blue_into_green/title_player.png",
      "assets/blue_into_green/title_version.png",
      "assets/blue_into_green/intro_nidorino_1.png",
      "assets/blue_into_green/intro_nidorino_2.png",
      "assets/blue_into_green/intro_nidorino_3.png" },
  },
  {
    id = "rumble",
    folder = "rumble",
    -- No ON/OFF of its own: every option on its page stands alone.
    alwaysOn = true,
    key = "rumble",
    name = "Rumble",
    short = "CONT.RUMBLE",
    version = "2.0.0",
    installOrder = 9,
    defaultEnabled = true,
    files = { "main.lua" },
  },
  {
    id = "pokemoves",
    -- No ON/OFF of its own: every option on its page stands alone.
    alwaysOn = true,
    key = "pokemoves",
    name = "PokeMoves",
    short = "POKEMOVES",
    version = "0.1.0",
    installOrder = 10,
    defaultEnabled = true,
    files = { "main.lua" },
  },
  {
    id = "full_control",
    key = "fullctl",
    name = "Full Control",
    short = "FULL CONTROL",
    version = "1.0.0",
    installOrder = 11,
    defaultEnabled = true,
    files = { "main.lua" },
    rowOrder = {
      "bind_up", "bind_down", "bind_left", "bind_right", "bind_a1", "bind_b1",
      "bind_start", "bind_select", "bind_speedp", "bind_speedm", "bind_jukebox",
    },
  },
  {
    id = "steel_typing",
    key = "steel",
    name = "Steel/Fairy and Typing Charts",
    short = "STEEL/FAIRY",
    version = "2.0.1",
    installOrder = 12,
    defaultEnabled = true,
    files = { "main.lua" },
  },
  {
    id = "crystal_animated_sprites_with_shiny_visuals",
    key = "crystal",
    name = "Crystal Animated Sprites",
    short = "CRYSTAL",
    version = "2.1.0",
    installOrder = 13,
    defaultEnabled = true,
    -- 3.71.0: no global ON/OFF row; every CRYSTAL option works on its own.
    alwaysOn = true,
    -- Gen 1's NPC rows, (the Crystal note, added by the hub,) then the
    -- rows that use Crystal's art; TRW's copyright stays at the bottom.
    rowOrder = {
      "crystalFrontNPCs", "crystalOverworldNPCs",
      "crystalDexPictures", "crystalBattleSprites", "crystalAnimations",
    },
    files = {
      "main.lua", "vendor.lua", "options_screen.lua",
      "species_map.lua", "crystal_source.lua", "portrait.lua",
    },
  },
  {
    id = "shortcuts",
    folder = "shortcuts",
    key = "shortcuts",
    name = "Shortcuts",
    short = "SHORTCUTS",
    fullLabel = "SHORTCUTS",
    -- The sub-menu's own ON/OFF row is the Ball Shortcuts switch; Item
    -- Shortcuts has its own toggle row and works either way.
    enabledLabel = "BALL SHORTCUTS",
    version = "1.1.0",
    installOrder = 15,
    defaultEnabled = true,
    files = { "main.lua" },
    rowOrder = {
      "select_up", "select_down", "select_left", "select_right",
      "item_shortcuts", "item_shortcut_1", "item_shortcut_2", "item_shortcut_3",
    },
  },
  {
    id = "custom_borders",
    folder = "custom_borders",
    key = "custom_borders",
    name = "Custom Borders",
    short = "CUSTOM BORDERS",
    fullLabel = "CUSTOM BORDERS",
    version = "0.3.0",
    installOrder = 14,
    defaultEnabled = true,
    files = { "main.lua", "screen_ratio.lua" },
    assets = {
      "assets/borders/red_modern.png", "assets/borders/red_modern2.png",
      "assets/borders/red_classic.png",
      "assets/borders/green_modern.png", "assets/borders/green_modern2.png",
      "assets/borders/green_classic.png",
      "assets/borders/blue_modern.png", "assets/borders/blue_classic.png",
      "assets/borders/yellow.png",
      "assets/borders/gold.png", "assets/borders/gold_classic.png",
      "assets/borders/silver.png", "assets/borders/silver_classic.png",
      "assets/borders/crystal.png", "assets/borders/crystal_classic.png",
      "assets/borders/custom1.png", "assets/borders/custom2.png",
      "assets/borders/custom3.png", "assets/borders/custom4.png",
    },
  },
  {
    id = "jukebox",
    -- No ON/OFF of its own: every song row stands alone. The JUKEBOX BUTTON
    -- lives in Full Control (bind_jukebox).
    alwaysOn = true,
    key = "jukebox",
    name = "Jukebox",
    short = "JUKEBOX",
    version = "1.0.0",
    installOrder = 16,
    defaultEnabled = true,
    files = { "main.lua" },
  },
}
