# Project Highlander Gen1+2 — v1.58.0 (First Release)

The first public release of **Project Highlander Gen1+2**: modern full-screen interfaces and quality-of-life for Pokémon **Red, Blue, Yellow, Gold, Silver and Crystal** on Gen1 Recomp, all in one mod.

This is the successor of *Project Highlander – A Modern UI Suite Fork* (last build 3.75.0). The mod was renamed, its version restarted at 1.0.0, and every screen inherited from Ish's Modern UI Suite was rebuilt from scratch. **Since 1.51.0, the whole mod is Project Highlander's own code.**

## Highlights

- **Highlander Start Menu** — full-screen Start Menu with colours, a clock bar, custom icons, custom names, hidden tiles and a Sort Menu, all kept per save.
- **Highlander Party** — Gen 1-style party list in both gens with XP bars, Rename for any Pokémon, Gold-style 3-page summary and Gen 1 move descriptions.
- **Highlander Bag** — Gold/Silver/Crystal's PACK in both generations, START: SORT per pocket, choice of opening pocket, 255-item bag with a counter.
- **Highlander PC** — every box as one big box (240 in Gen 1, 280 in Gen 2) beside the party, Auto-Grab, Multiple Selections, page jumps and Gen 2 held items.
- **Highlander Dex** — a Gold-based Pokédex for all six games with Area, Locations, Stats, Family and Moves pages.
- **Highlander Trainer ID** — Gold's trainer card in Gen 1 with STATUS and BADGES pages.
- **Battle Screen** — Highlander HUD move grid with PP and effectiveness icons, Enemy HP Counter, Gen 2-style EXP bar in Gen 1, Lock OG Layout, Gen3 Catch Rate, Boosted EXP and Modern EXP Share.
- **Plus**: PokéMoves, Ball and Item Shortcuts, Running Shoes, Repel prompts, Modern Stores, Game Corner and Safari Zone options, Get All Pokémon, Steel/Fairy type charts, Full Control button mapping, Controller Rumble, Jukebox, Custom Borders with 16:9 Screen Ratio, and Crystal sprites read from your own Crystal install.

See the [README](https://github.com/Waifu4Life/Project-Highlander-Gen1-2#readme) for the full feature list.

## Requirements

- **Gen1 Recomp (G1R / G1R Deluxe)** with Mod API 2.
- Pokémon Red, Blue, Yellow, Gold, Silver and/or Crystal set up in G1R.
- *Optional:* Pokémon Crystal installed in G1R for Crystal sprites in the other games.

## Installation

1. Download the zip attached to this release (not GitHub's "Source code" zip).
2. In G1R, open **MODS → Import mod .zip** and pick it, then make sure it is enabled.
3. In game, open **OPTION > ProjectHighlander** to adjust settings. Almost everything is On by default.

## Upgrading from the old Project Highlander

- **Disable or remove** the old *Project Highlander (Modern UI Suite Fork)* and *Modern UI Suite* — they conflict with this mod.
- Settings were renamed in 1.51.0, so options start from their defaults. Saves and the data stored in them (Item Shortcuts, Start Menu layout) keep working.

## Changes in 1.58.0

- **Jukebox**: SELECT on a song plays it, looping, until you press SELECT on it again or leave the Jukebox page. SELECT on another song switches to it.
- **Start Menu > Colour**: Automatic uses Green when Blue Into Green is On, like Custom Borders.
- **Crystal > Pokédex Pictures**: OG / Crystal instead of Off / On, like the other rows. Your old setting carries over.

## Changes in 1.57.0

- **Battle Screen**, Gold/Silver/Crystal: Colored Moves and Colored Pokeballs are no longer listed. Gen 2 already colours its move animations and balls, and these options only work on the Gen 1 battle screen.

## Changes in 1.56.0

- **In-app updates**: the manifest now points to this GitHub repo, so G1R's MODS panel offers **Update** and **Versions** for this and every future release. This is the last version you'll need to install by hand.

## Changes in 1.55.0

- **Highlander PC** new buttons: A opens the Pokémon's menu; SELECT toggles **Auto-Grab** (A grabs and drops, with a GRAB badge); Multiple Selections uses A to mark, SELECT to drop, B to end; **START + Left/Right** jumps 6 rows.
- **Full Control**: Left Analog for D-Pad works again.

For every change since 1.0.0, see `CHANGELOG.md` inside the zip.

## Known limitations

- Turning a Highlander screen off takes effect the next time that screen opens.
- The bigger Bag stays active when Highlander Bag is Off, to protect saves.
- Exporting to an original cartridge save is limited to cartridge-era item counts.
- Steel/Fairy chart changes need a G1R restart.

## Credits

Waifu4Life (Project Highlander) · Gen1Recomp · zyrancz (Steel/Fairy and Typing Charts) · TRW (Crystal Animated Sprites with Shiny Visuals) · YoDrehDenSwagAuf (GSC follower icons) · NikoIchu (1-bit Pixel Icons). Full notices in `THIRD_PARTY_NOTICES.md`.
