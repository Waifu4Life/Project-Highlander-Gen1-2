-- PH Pokédex (Project Highlander Gen1+2): one Pokédex for Red/Blue/Yellow and
-- Gold/Silver/Crystal, built on Gold's layout. OTHER SETTINGS > PH POKéDEX
-- turns it on or off; off gives the game's own Pokédex back.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local D = mod:load("data.lua")(mod)
  local Screen = mod:load("screen.lua")(mod, D)

  local gen2 = GameVersion.generation and GameVersion.generation() == 2
  local id = gen2 and "Gen2PokedexMenu" or "PokedexMenu"
  local record = { new = function(game, opts) return Screen.new(game, opts) end }
  if mod.content.screens:get(id) then
    mod.content.screens:override(id, record)
  else
    mod.content.screens:register(id, record)
  end

  -- Keep the "owned" marks right for Pokémon that other mods hand out
  -- without telling the Pokédex.
  mod.events:on("game.ready", function(event)
    local game = type(event) == "table" and (event.game or event) or nil
    pcall(D.repairOwned, game)
  end, 1000)

  mod.exports.data = D
  mod.log:info("PH Pokedex ready (%s)", gen2 and "Gen 2" or "Gen 1")
end
