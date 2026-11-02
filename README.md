# Project Highlander Gen1+2

**Modern screens and quality-of-life for Pokémon Red, Blue, Yellow, Gold, Silver and Crystal — all in one mod for Gen1 Recomp.**

Project Highlander Gen1+2 replaces the Start Menu, Party, Bag, PC, Pokédex and Gen 1 Trainer ID with new full-screen interfaces drawn in the cartridges' own style, adds a cleaner battle screen with a move grid, and brings dozens of modern conveniences (running shoes, EXP Share, Repel prompts, shortcuts, rumble, a jukebox and more). Every option lives in one menu, and almost everything can be switched off to get the original game back.

> Project Highlander Gen1+2 is the successor of *Project Highlander – A Modern UI Suite Fork* (last build 3.75.0). Since 1.51.0 the whole mod is Project Highlander's own code.

---

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Upgrading from the old Project Highlander](#upgrading-from-the-old-project-highlander)
- [The ProjectHighlander menu](#the-projecthighlander-menu)
- [Highlander screens](#highlander-screens)
- [Mechanics](#mechanics)
- [System](#system)
- [Cosmetics](#cosmetics)
- [Always-on features](#always-on-features)
- [Compatibility](#compatibility)
- [Known limitations](#known-limitations)
- [Credits](#credits)
- [License](#license)

---

## Requirements

| What | Details |
| --- | --- |
| Host game | **Gen1 Recomp (G1R / G1R Deluxe)** with Mod API 2 (engine `>=0.0.0-dev <1.0.0`) |
| Supported games | Pokémon **Red, Blue, Yellow** (Gen 1) and **Gold, Silver, Crystal** (Gen 2). Blue can also be played as **Green** (see *Blue Into Green*). |
| Permission | `engine_internals` — needed to redraw the game's own screens |
| Optional | **Pokémon Crystal installed in G1R** — unlocks Crystal's animated Pokémon sprites, animations in the other five games (see *Crystal*) |
| Optional | A controller with rumble support for *Cont. Rumble* |

Tested on Windows PC, Steam Deck and Android (Galaxy S24).

## Installation

1. Download the zip from the [latest release](https://github.com/Waifu4Life/Project-Highlander-Gen1-2/releases/latest) (not GitHub's "Source code" zip).
2. In G1R, open **MODS → Import mod .zip** and pick it (or use [G1R Frontend](https://github.com/Waifu4Life/G1R-Frontend/releases)).
3. Make sure it is enabled, and that none of the mods listed under [Conflicts](#conflicts) are enabled.
4. Start a game, open **OPTION** and choose **ProjectHighlander** to set things up. Everything is On by default except a few options noted below.

From 1.56.0 on, updates are offered in G1R's **MODS** panel (**Update** / **Versions**), so you only install by hand once.

## Upgrading from the old Project Highlander

- Disable or remove **Project Highlander (Modern UI Suite Fork)** and **Modern UI Suite**: they can't run together with this mod.
- Settings were renamed in 1.51.0, so all options start from their defaults. Your saves, Item Shortcuts and other data stored in saves keep working.

---

## The ProjectHighlander menu

The mod adds one entry to the game's **OPTION** menu: **ProjectHighlander**. It is split into three categories:

| Category | Pages |
| --- | --- |
| **MECHANICS** | Battle Screen, Overworld Screen, PokéMoves, Shortcuts, Game Corner, Safari Zone *(Gen 1 only)*, Steel/Fairy |
| **SYSTEM** | Start Menu, Other Settings, Full Control, Cont. Rumble, Get All Pokémon |
| **COSMETICS** | Jukebox, Custom Borders, Crystal, PokéIcons |

Pages are alphabetical, with "Highlander" rows first. There are no Back rows: **B** leaves any page. The four Highlander screens are switched on and off at the top of **Other Settings**.

---

## Highlander screens

### Highlander Start Menu
A full-screen Start Menu (160×144, the cart's own font) with 2 columns × 5 rows of tiles, extra pages when needed, a clock bar and a footer.

- **COLOUR**: Automatic (follows the cart; Green when *Blue Into Green* is On), Red, Blue, Green, Yellow, Gold, Silver, Crystal.
- **COLOUR SCOPE**: per Game or per Save.
- **CLOCK**: Off, Device (`Sun 2026-10-18 23:50`), Play time, In-Game (Gold/Silver/Crystal) or **Rotation** (default, cycles every 3 s).
- **CUSTOM ICONS**: pick a 16×16 icon for non-system tiles.
- **CUSTOM RENAME**: rename any tile, up to 6 characters, with the game's keyboard (empty name = default).
- **HIDE ITEMS**: show/hide POKEBOX, MODS and other mods' tiles; put any mod's Options page (ProjectHighlander included) on the Start Menu as a shortcut.
- **SORT MENU** (also SELECT on the Start Menu): move tiles around, including QUIT, and leave empty gaps.
- Icons, names, hidden tiles and order are kept per save file.
- QUIT and Gen 2's "end the Contest?" ask on the page itself.

### Highlander Party
- Gen 1-style party list in both generations: icon, name, level, status, HP bar with numbers and a blue XP bar.
- **SELECT** picks up a Pokémon to swap it with another.
- The A menu is a centred box in a fixed order: Stats, (Gen 2: Move, Item), Switch, Relearn, Rename, Dismiss/Follow, TM field moves, HM field moves, Cancel.
- **RENAME** any Pokémon, traded ones included.
- Gen2-style 3-page summary (Pink: HP/status/types/EXP · Green: item and coloured moves table · Blue: ID, OT, stats).
- Gen 1 gets Gen2's move screen: type, power and Crystal's move descriptions, and reorder moves with A.

### Highlander Bag
- Gen2's **PACK** in both generations (rebuilt from scratch for Gen 1 with four pockets: Items, Balls, Key Items, TM/HM).
- Money in the header and a used/255 counter.
- **START: SORT** per pocket: Category Asc/Desc, Names A-Z/Z-A. TM/HM pocket in number order unless name-sorted (kept in the save).
- **SELECT** moves an item inside its pocket.
- A description for every Gen 1 item; TMs/HMs show their move's.

### Highlander PC
- All boxes shown as **one big box**, 5 wide: 240 Pokémon in Gen 1, 280 in Gen 2, always packed with no gaps. The game's own boxes stay underneath, so turning it off or exporting a cartridge save works as normal.
- Party is a fixed first column with a PARTY badge; the header shows the nickname of the Pokémon under the cursor.
- **A** opens the Pokémon's menu: Summary, (Gen 2: Item — Give/Take), Send to Box / Send to Party, Release (with confirmation), Multiple Selections, Cancel.
- **SELECT** toggles **Auto-Grab** (A grabs and drops directly; a GRAB badge shows while it's on).
- **Multiple Selections**: A marks, SELECT drops/swaps (same side or across), B ends.
- **START + Left/Right** jumps 6 rows.
- The game's rules are kept: no empty healthy party, Gen 2 Mail, eggs can't be released, Yellow's Pikachu stays.
- Colours follow the Start Menu colour; icons follow *PokéIcons*.

### Highlander Dex
A Gen2-based Pokédex for all six games, drawn at Game Boy size and framed in each game's colour.

- Main list with full-colour pictures, page jumps, OPTION (Gen 1: Pokédex/A-Z mode; Gen 2: New/Old/A-Z/Unown) and SEARCH by type in both gens.
- Entry page: number, catch rate, both types in colour, and **INFO, AREA, CRY, PRNT, STATS, FAMILY, MOVES**.
- **AREA**: nest map plus a Locations chart by hittin Select (sort by location, level or rate; SELECT for colour codes).
- **STATS**: base stats and total. **FAMILY**: one page per evolution line with methods. **MOVES**: level-up, TM/HM, egg and Crystal tutor moves, each with power/accuracy/PP/description.
- **PRNT** works in Gen1 too.
- Seen-only Pokémon grey out INFO and MOVES, like the originals.

---

## Mechanics

### Battle Screen
| Option | Default | What it does |
| --- | --- | --- |
| **Highlander HUD** | On | FIGHT opens a 3-column grid: type-coloured move names, PP lined up on "/", and 0x / ½x / 1x / 2x effectiveness icons against the current foe (Steel/Dark/Fairy aware). START shows a type-colour and effectiveness help screen. |
| Colored Moves | On | Move animations take their type's colour. (Gen1 only) |
| Colored Pokeballs | On | Poké Balls are drawn in their own colours. (Gen1 only) |
| Enemy HP Counter | On | Shows the foe's HP as numbers under its bar. |
| Gen3 Catch Rate | On | Gen 3 catch formula (Apricorn balls use HGSS modifiers). |
| Get Boosted EXP | On | Every Pokémon earns traded-Pokémon EXP. |
| Lock OG Layout | On | Keeps the battle on the cartridge's 160×144 layout. Off allows WIDE again. |
| Low HP Beeping | Reduce | On / Off / Reduce. |
| Modern EXP Share | On | Pokémon that didn't fight share half EXP, announced in one line. Off = Whatever EXP share the games used before. |

### Overworld Screen
| Option | Default | What it does |
| --- | --- | --- |
| Modern Stores | On | Shows how many of the highlighted item you own in Poké Mart lists. |
| Rematch Anyone | On | Battle trainers again. |
| Running Shoes | Hold B | Off / Hold B / Toggle B. Gen 1 keeps a short sneakers story from Mom; Gen 2 can run from the start. |
| Show Area Names | On | The area's name pops up when you enter it. In Crystal, this adds to it's own function by showing the name of inside houses and buildings.|
| Sparkling Hidden Items | On | Unfound hidden items twinkle on the map. |
| Use Repel Again? | On | Offers another Repel of the same kind when one wears off. |

### PokéMoves
| Option | Default | What it does |
| --- | --- | --- |
| Forgettable HMs | On | HMs can be deleted like any move. |
| Instant TMs/HMs | On | Use field moves like Cut and Surf straight away by pressing the A button; passive field moves like Fly and Flash appear in the SELECT menu. |
| Move Relearning | On | **Relearn** in the Party menu. |
| No Learn HMs | On | Use an HM field move without teaching it, if the Pokémon could learn it and you have the badge and the HM. |
| TMs Forever | On | TMs are not used up. |

### Shortcuts
- **Ball Shortcuts** (On): SELECT + a direction throws the assigned ball from a wild battle's command menu. Defaults: Up = Poké Ball, Left = Great Ball, Down = Ultra Ball, Right = none. Gen 2 adds Fast, Level, Lure, Heavy, Love, Friend and Moon Balls. Never Safari/Sport/Master Ball, and never in the Safari Zone, Bug-Catching Contest, trainer or link battles.
- **Item Shortcuts** (On) with **Item Shortcut 1-3**: register Rods, Itemfinder, Bicycle or the Map. SELECT on the overworld lists them (plus PokéMoves field moves). Saved per save file.

### Game Corner
| Option | Default | What it does |
| --- | --- | --- |
| 2x Coins for Cash | On | Coin purchases give double coins. |
| All Lucky Slot M. | On | Every slot machine gets the lucky machine's odds. |
| Bigger Payouts | On | Every slot win pays double (capped at 9999). |
| Slot Odds | Lucky | Normal / Generous / Lucky. |

Works in Gen 1 and Gen 2.

### Safari Zone *(Gen1)*
| Option | Default | What it does |
| --- | --- | --- |
| Infinite Safari | On | No step limit. |
| No Running Away | On | Wild Safari Pokémon never flee (Bait/Rock still affect catch rate). |
| Unlimited Balls | On | The Safari Ball count stays at 30. |

### Steel/Fairy *(by zyrancz)*
Type-chart presets: **Vanilla**, **Gen II (Steel + Dark)**, **Gen VI (Steel + Dark + Fairy)** (default) or **Custom**, with individual Steel/Dark/Fairy types, Ghost vs Steel, Dark vs Steel, Ghost vs Psychic, Bug vs Poison and Ice vs Fire fixes, and Other Gen1 Move Changes (Gust → Flying, Karate Chop → Fighting, Sand-Attack → Ground, Struggle typeless). Chart changes take effect after restarting G1R.

---

## System

### Other Settings
| Option | Default | What it does |
| --- | --- | --- |
| **Highlander Bag** | Last Opened | Opening pocket choice: Off, Default Items, Default TMs/HMs, Default Balls, Default KeyItems or **Last Opened** (default), in and out of battle. |
| **Highlander Dex** | On | Highlander Dex on/off. |
| **Highlander Party** | On | Highlander Party on/off. |
| **Highlander PC** | On | Highlander PC on/off. |
| Blue Into Green | Off | *(Blue only)* Title, logo colour, "Green Version" and Nidorino intro turn Blue into Green. Custom Borders' and the Start Menu's Automatic pick Green. |
| Decap. Words | On | Turns ALL-CAPS game text into normal case, keeping abbreviations (TM, HM, PKMN, HP, PP…) in capitals. |
| Gender Mod | On | Boy/Girl choice in Red/Blue/Yellow/Gold/Silver (Red/Green, Gold/Kris): portrait, battle back sprite and overworld walk/bike. Hidden in Crystal. |
| Pikachu Sound | Yellow | *(Yellow only)* Yellow's Pikachu voice or the original cry. |

### Full Control
Rebind every button for keyboard and controller, shown in controller order: Up, Down, Left, Right, A, B, Start, Select, **Speed +**, **Speed −**, plus **Jukebox Button**. Also: **Left Analog for D-Pad** (On), **Right Analog for D-Pad** (Off) and **Select Visual Combos** (On: SELECT + A/B/X/Y/LB keep the game's display shortcuts).

### Cont. Rumble
Controller rumble in battle. **Intensity** (Off/Low/**Medium**/High), **Press Select to Test**, **When I Get Hit**, **When I Hit**, **Wild Battle Start**, **Trainer Battle Start** (all On). Not very effective = a tap, effective = a pulse, super effective = two strong pulses.

### Get All Pokémon
Only the page for the running generation is shown. Every option is On by default.

**Gen 1 (Red/Blue/Yellow)**
- Get Exclusive PKMN from Other Gen1 Games — the other versions' exclusives appear in the wild.
- Get All Starters — Prof. Oak gives the leftover starters later in the game.
- Get Other Fossil — the other Mt. Moon fossil.
- Get Other Fighter — the second Fighting Dojo Pokémon.
- Get More Eevees — extra Eevees from Mr. Fuji.
- Trade w/ Link C. — an NPC that handles trade evolutions.
- Infinite Tries for Limited Encounters — the Legendary Birds and Mewtwo come back if you flee or faint them.
- Get ??? — a secret encounter.

**Gen 2 (Gold/Silver/Crystal)**
- Get Exclusive PKMN from Other Gen2 Games — the other carts' exclusives at the routes the Pokédex shows.
- Get All Starters — Prof. Elm gives the leftover Johto starters.
- Get OG Starters — the Kanto starters.
- Kim Fossil Trades — fossil Pokémon via trades.
- GS Ball — the GS Ball event with Kurt and the Ilex Forest shrine.
- Get Legend. Birds — Articuno, Zapdos and Moltres in Kanto.
- Get Mew/Mewtwo.
- Roaming Hunter — 100% encounter with a roaming beast on its current route, no fleeing, no Roar.
- Trade w/ Link C.
- Infinite Tries for Limited Encounters.

---

## Cosmetics

### Jukebox
Every background song of the game you're playing, each On by default (ALL SONGS on top). The songs that are On form a playlist. Hold **Full Control > Jukebox Button** on the overworld with **Up** (play), **Down** (stop), **Left/Right** (previous/next). The song continues across maps, Surf and Bicycle; battles and events keep the game's music. Each game keeps its own list.

To listen to a song, press **SELECT** on it in the Jukebox page: it plays, looping (the row shows PLAY), until you press SELECT on it again or leave the page. SELECT on another song switches to it.

### Custom Borders
Super Game Boy-style borders around the 4:3 screen (title, Options, Trainer ID, OG battles, Start Menu).
- **Border**: Automatic, Classic/Modern 1/Modern 2 Red, Classic/Modern 1/Modern 2 Green, Classic/Modern Blue, Yellow, Classic/Modern Gold, Silver and Crystal, Custom 1-4.
- **Border Scope**: by Save or by Game.
- **Screen Ratio**: Off / 16:9 — runs the whole game in a 16:9 area on any screen shape (Steam Deck, ultrawide). Off by default.

### Crystal *(by TRW)*
Crystal's animated Pokémon sprites and shiny visuals, read from **your own Pokémon Crystal install** in G1R (no Pokémon sprites are bundled).
- **Front NPCs** / **Overworld NPCs** *(Gen 1)*: OG or GEN2 trainers.
- **Pokédex Pictures**: OG (default) or Crystal — Crystal's animated pictures in the Highlander Dex *(not in Crystal)*.
- **Battle Sprites**: OG or Crystal *(not in Crystal)*.
- **Animations**: Loop or Play Once.
- An INSTALLED / NOT INSTALLED line tells you if Crystal was found.

### PokéIcons
**Icons for Party** and **Icons for PC**: Original or Wild Followers (GSC follower icons by YoDrehDenSwagAuf). Original is respected even with Wilds of Kanto Revival installed.

---

## Always-on features

- **Highlander Trainer ID (Gen 1)**: Gen2's trainer card for Red/Blue/Yellow with STATUS and BADGES pages and spinning earned badges.
- **Gen 2 Trainer Card**: coloured Johto badges and a Kanto leaders page.
- **Gen 1 EXP bar**: Gen 2's blue EXP bar in Gen 1 battles, filling right to left with the rising tick and level-up music.
- **Caught-ball marker** beside wild Pokémon you already own.
- **Bigger Bag**: 255 items, stacks up to 999; the Gen 1 item PC holds 255.
- **Town Map marker** follows Boy/Girl.
- **Fly map / Pokégear**: SELECT swaps Johto and Kanto once Kanto is reachable.
- **Window focus**: grabs keyboard/controller focus when launched from a frontend, Playnite or a shortcut.

---

## Compatibility

### Works alongside
Wilds of Kanto Revival, Gen 2 Expanded Boxes, DV Tracker, Kanto Ribbons, the Battle Art Voxel mods, HGSS Sprites, Gold/Silver Sprites, Stadium 2 Importer and the other mods listed as optional dependencies in `manifest.json`.

### Conflicts
Don't enable these together with Project Highlander Gen1+2 (their features are built in, or they replace the same screens):

`project_highlander`, `modern_ui_suite`, `modern_start_menu_ui`, `modern_party_ui`, `modern_bag_ui`, `modern_pc_ui`, `modern_pokedex_ui`, `battle_info_hud`, `typed_move_colors`, `unlimited_pp`, `mute_low_hp_alarm`, `pokeball-colorfix`, `pokemove-colorfix`, `CONTROLLER_RUMBLE`, `steel_typing`, `crystal_animated_sprites_with_shiny_visuals`, `crystal_animated_sprites`, `gen2_shiny_visuals`, `shiny_visuals`.

## Known limitations

- Turning a Highlander screen off takes effect the next time that screen opens.
- The bigger Bag stays active when Highlander Bag is Off, to protect saves.
- Exporting to an original cartridge save is limited to cartridge-era item counts.
- Steel/Fairy chart changes need a G1R restart.
- Infinite Tries for Limited Encounters is fully active in Gen 1; in Gen 2 (Lugia, Ho-Oh, Snorlax, Sudowoodo, Red Gyarados) it only detects the encounters for now.

---

## Credits

- **Waifu4Life** — Project Highlander
- **Gen1Recomp** — native mod platform, controllers, data and renderer
- **zyrancz** — Steel/Fairy and Typing Charts (used with permission)
- **TRW** — Crystal Animated Sprites with Shiny Visuals (used with permission)
- **YoDrehDenSwagAuf** — poke_followers GSC icons from Wilds of Kanto 2.1.9 (MIT)
- **NikoIchu** — 1-bit Pixel Icons (CC0) used by the Start Menu
- **Game Freak** — interface and storage inspiration

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for full credits. No ROM assets are included; game data is extracted at runtime by Gen1 Recomp.

## License

MIT © 2026 Waifu4Life — see [`LICENSE`](LICENSE). Bundled third-party pieces keep their own terms.

*Pokémon is © Nintendo, Creatures Inc. and GAME FREAK inc. This is a fan project and is not affiliated with or endorsed by them.*
