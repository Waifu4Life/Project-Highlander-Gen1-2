-- Battle Screen. Its page shows rows from three components:
--   this one        ENEMY HP COUNTER, HIGHLANDER HUD, LOCK OG LAYOUT,
--                   LOW HP BEEPING, UNLIMITED PP (unlimited_pp.lua)
--   Move Colours    COLORED MOVES, COLORED POKEBALLS
--   Other Settings  GEN3 CATCH RATE, GET BOOSTED EXP, MODERN EXP SHARE
-- Always on (no row): the Gen 1 EXP bar and the caught-ball marker.
return function(mod)
  mod.options:define({
    { key = "enemy_hp_counter", label = "ENEMY HP COUNTER", type = "toggle",
      default = true },
    { key = "highlander_hud", label = "HIGHLANDER HUD", type = "toggle",
      default = true },
    { key = "lock_og_layout", label = "LOCK OG LAYOUT", type = "toggle",
      default = true },
    { key = "low_hp_beep", label = "LOW HP BEEPING", type = "choice",
      default = "reduce",
      choices = {
        { "ON", "on" },
        { "OFF", "off" },
        { "REDUCE", "reduce" },
      } },
    -- Off by default: borderline cheating
    { key = "unlimited_pp", label = "UNLIMITED PP", type = "toggle",
      default = false },
  })

  -- ON = stock looping siren. OFF = silent. REDUCE = two tones when the
  -- bar first turns red, then quiet until HP leaves the red and returns
  -- (or a new mon is sent out).
  local REDUCE_FRAMES = 40
  local chirp = setmetatable({}, { __mode = "k" })
  mod.hooks:wrap("battle.low_health_alarm", function(next, ctx)
    local mode = mod.options:get("low_hp_beep")
    if mode == "off" then
      ctx.on = false
    elseif mode == "reduce" then
      local battle = ctx and ctx.battle
      if not ctx.on then
        if battle then chirp[battle] = nil end
      else
        local left = battle and chirp[battle]
        if not left then
          if battle then chirp[battle] = REDUCE_FRAMES end
        elseif left > 0 then
          chirp[battle] = left - 1
        else
          ctx.on = false
        end
      end
    end
    return next(ctx)
  end)

  -- LOCK OG LAYOUT: keeps the game's OPTION > BATTLE LAYOUT on OG (the
  -- 160x144 cartridge battle screen). While ON, that row shows OG and can't
  -- be changed; turning it OFF gives the choice back.
  local function locked()
    local ok, value = pcall(mod.options.get, mod.options, "lock_og_layout")
    return not ok or value ~= false
  end

  local function forceOG(options)
    if type(options) ~= "table" or options.battleLayout == "og" then return end
    options.battleLayout = "og"
    -- The extended HUD only exists in WIDE; the game resets it the same way.
    options.battleHud = "standard"
  end

  local function enforce(game)
    if not locked() or type(game) ~= "table" then return end
    forceOG(game.save and game.save.options)
    forceOG(game.options)
  end

  -- Every frame: catches saves, the launcher's settings and other mods.
  pcall(function()
    mod.hooks:wrap("core.update", function(next, game, dt, ...)
      pcall(enforce, game)
      return next(game, dt, ...)
    end)
  end)
  mod.events:on("game.ready", function(event)
    pcall(enforce, type(event) == "table" and (event.game or event) or nil)
  end)

  -- The game's own BATTLE LAYOUT row (Gen 1: id, Gen 2: key).
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local out = next(game, rows)
    if type(out) ~= "table" or not locked() then return out end
    for index, row in ipairs(out) do
      if type(row) == "table"
          and (row.id == "battleLayout" or row.key == "battleLayout") then
        local copy = {}
        for k, v in pairs(row) do copy[k] = v end
        if row.id == "battleLayout" then
          copy.value = function(g)
            enforce(g)
            local Strings = require("src.core.Strings")
            return Strings("OG")
          end
          copy.step = function(g) enforce(g); return false end
        else
          copy.cycle = function(o) forceOG(o) end
        end
        out[index] = copy
      end
    end
    return out
  end)

  local GameVersion = require("src.core.GameVersion")
  local generation = type(GameVersion.generation) == "function"
    and GameVersion.generation() or 1
  local okPp, errPp = pcall(function() return mod:load("unlimited_pp.lua")(mod) end)
  if not okPp then mod.log:error("unlimited PP failed: %s", tostring(errPp)) end

  local file = generation == 2 and "gen2.lua" or "gen1.lua"
  local ok, err = pcall(function() return mod:load(file)(mod) end)
  if not ok then
    mod.log:error("battle screen (%s) failed: %s", file, tostring(err))
  end
end
