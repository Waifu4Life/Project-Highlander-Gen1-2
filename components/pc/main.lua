-- Highlander PC (Project Highlander Gen1+2): the Pokémon Storage screen for
-- Red/Blue/Yellow/Green and Gold/Silver/Crystal, with all the boxes shown as
-- one big box (240 Pokémon in Gen 1, 280 in Gen 2).
-- OTHER SETTINGS > HIGHLANDER PC turns it on or off; off gives the game's
-- own PC back, and the boxes are still ordinary boxes underneath.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local gen2 = GameVersion.generation and GameVersion.generation() == 2
  local S = mod:load("storage.lua")(mod, gen2)
  local PC = mod:load("screen.lua")(mod, S, gen2)

  local function constructor(record)
    if type(record) == "function" then return record end
    return type(record) == "table" and record.new or nil
  end

  local NATIVE = {
    BoxMenu = "src.ui.BoxMenu",
    Gen2PcMenu = "src.ui.gen2.PcMenu",
    Gen2BoxMenu = "src.ui.gen2.BoxMenu",
  }

  local function replace(id)
    local inherited = constructor(mod.content.screens:get(id))
    local record = {
      isMenu = true,
      new = function(game, opts, ...)
        local save = (type(opts) == "table" and opts.save) or (game and game.save)
        -- No Pokémon at all: the game's own PC says so.
        if not (save and type(save.party) == "table" and #save.party > 0) then
          local make = inherited or require(NATIVE[id]).new
          return make(game, opts, ...)
        end
        return PC.new(game, type(opts) == "table" and opts or {})
      end,
    }
    if mod.content.screens:get(id) then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end

  if gen2 then
    replace("Gen2PcMenu")
    replace("Gen2BoxMenu")
    S.attachCatch()
  else
    replace("BoxMenu")
  end

  mod.exports.storage = S
  mod.log:info("Highlander PC ready (Gen %d, %d slots)", gen2 and 2 or 1, S.capacity())
end
