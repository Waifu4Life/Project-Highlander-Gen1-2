-- Highlander Party (Project Highlander Gen1+2): the party screen and the
-- Pokémon summary for Red/Blue/Yellow/Green and Gold/Silver/Crystal.
-- OTHER SETTINGS > HIGHLANDER PARTY turns it on or off; off gives the game's
-- own screens back, untouched.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local Strings = require("src.core.Strings")
  local C = mod:load("common.lua")(mod)
  local gen2 = GameVersion.generation and GameVersion.generation() == 2

  local function constructor(record)
    if type(record) == "function" then return record end
    return type(record) == "table" and record.new or nil
  end

  -- Wrap whatever builds the screen today (another mod, or the game).
  local function decorateScreen(id, nativePath, decorate)
    local inherited = constructor(mod.content.screens:get(id))
    local record = {
      isMenu = true,
      new = function(game, ...)
        local make = inherited or require(nativePath).new
        return decorate(make(game, ...))
      end,
    }
    if mod.content.screens:get(id) then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end

  local function replaceScreen(id, record)
    if mod.content.screens:get(id) then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end

  if gen2 then
    local G2 = mod:load("gen2.lua")(mod, C)
    decorateScreen("Gen2PartyMenu", "src.ui.gen2.PartyMenu", G2.decorateParty)
    decorateScreen("Gen2SummaryMenu", "src.ui.gen2.SummaryMenu", G2.decorateSummary)
  else
    local Party = mod:load("gen1_party.lua")(mod, C)
    local Summary = mod:load("gen1_summary.lua")(mod, C)
    decorateScreen("PartyMenu", "src.ui.PartyMenu", Party.decorate)
    replaceScreen("SummaryMenu", {
      isMenu = true,
      new = function(game, mon) return Summary.new(game, mon) end,
    })
  end

  ---------------------------------------------------------------------------
  -- RENAME in the A menu (the game's own naming keyboard). An empty name
  -- puts the species name back.
  ---------------------------------------------------------------------------
  local function speciesName(game, mon)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return (def and def.name) or mon.species
  end

  local function setName(mon, name)
    if type(name) == "string" and name ~= "" then
      mon.nickname = name
    else
      -- un-nicknamed: the game shows (and evolves) the species name
      mon.nickname = nil
    end
  end

  local function openRename(game, mon)
    local Screens = require("src.ui.Screens")
    if gen2 then
      local naming
      local function close()
        if game.stack:top() == naming then game.stack:pop() end
      end
      naming = Screens.push(game, "Gen2NamingScreen", {
        type = "nickname",
        mon = mon,
        monName = speciesName(game, mon),
        menuGfx = game.data and game.data.gen2MenuGfx,
        onDone = function(name)
          close()
          setName(mon, name)
        end,
        onCancel = close,
      })
    else
      Screens.push(game, "NamingScreen", {
        title = Strings("NICKNAME?"), maxLen = 10, mon = mon,
        onDone = function(name) setName(mon, name) end,
      })
    end
  end

  mod.hooks:wrap("ui.party.submenu", function(nextFn, game, items, mon, ctx)
    local out = nextFn(game, items, mon, ctx)
    if type(out) ~= "table" or (ctx and ctx.battle) then return out end
    if type(mon) ~= "table" or mon.isEgg then return out end
    local has = false
    for _, row in ipairs(out) do
      if type(row) == "table" and row.highlanderRename then has = true break end
    end
    if not has then
      out[#out + 1] = {
        id = "RENAME",
        label = Strings("RENAME"),
        highlanderRename = true,
        onSelect = function(selMon, g) openRename(g or game, selMon or mon) end,
      }
    end
    C.orderActions(out, 1)
    return out
  end, 10000)

  mod.exports.common = C
  mod.log:info("Highlander Party ready (%s)", gen2 and "Gen 2" or "Gen 1")
end
