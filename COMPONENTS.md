# How Project Highlander Gen1+2 is put together

Project Highlander is one mod made of parts. Each part lives in its own folder
under `components/` and is installed as if it were a small mod of its own.

| Part (id) | Folder | What it is |
| --- | --- | --- |
| highlander_start | start_menu | Highlander Start Menu |
| highlander_party | party | Highlander Party |
| highlander_bag | bag | Highlander Bag |
| highlander_pc | pc | Highlander PC |
| highlander_pokedex | pokedex | Highlander Dex |
| highlander_trainer_id | trainer_id | Gen 1 Trainer ID in Gold's layout (always on) |
| battle_screen | battle_screen | Battle Screen and Highlander HUD |
| move_colors | move_colors | Colored Moves / Colored Pokeballs |
| other_settings | other_settings | Other Settings, Overworld Screen, Get All Pokémon, Game Corner |
| rumble | rumble | Controller Rumble |
| pokemoves | pokemoves | PokéMoves |
| full_control | full_control | Full Control and the Jukebox button |
| steel_typing | steel_typing | Steel/Fairy and Typing Charts (zyrancz) |
| crystal_animated_sprites_with_shiny_visuals | crystal_animated_sprites_with_shiny_visuals | Crystal sprites (TRW) |
| shortcuts | shortcuts | Ball and Item Shortcuts |
| custom_borders | custom_borders | Custom Borders and Screen Ratio |
| jukebox | jukebox | Jukebox |

## The core

- `main.lua` loads the shared pieces, checks every part's files, installs the
  parts in order and adds the PROJECTHIGHLANDER entry to the Options menu.
- `core/components.lua` is the list of parts above, with their files.
- `core/part_api.lua` is what each part sees as `mod`: its own folder, its own
  settings, and listeners/hooks/screens that switch off with the part.
- `core/settings.lua` stores every setting under the main mod as
  `<part key>.<setting>` (for example `other_settings.coins_2x`).
- `core/hub.lua` is the PROJECTHIGHLANDER menu and all of its pages.
- `core/poke_icons.lua`, `core/item_shortcuts.lua` and `core/window_focus.lua`
  are shared helpers that are always on.

## Adding or changing a part

1. Change the files in the part's folder only.
2. Read and write settings with `mod.options:get/set`; other parts' settings
   with `mod.highlander.option(id, key)`.
3. Load sibling files with `mod:load()`, pictures with `mod.assets:image()`.
4. List new files and pictures in `core/components.lua`.
5. Record player-visible changes in `CHANGELOG.md` and rebuild the zip.
