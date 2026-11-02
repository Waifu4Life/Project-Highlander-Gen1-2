-- Project Highlander settings.
--
-- Every part's settings live in one place, under the main mod's id, as
-- "<part key>.<setting>" (for example "other_settings.coins_2x"). A part's
-- own ON/OFF switch is "<part key>.enabled".
--
-- A value is looked up in this order:
--   1. what was set during this session
--   2. the save file's copy   (game.save.options.modOptions[mod id])
--   3. the game's live copy   (game.mods.modOptions[mod id])
--   4. the game's Mods-menu options (mod.options)
--   5. the part's own default
return function(mainMod, parts)
  local Store = {
    parent = mainMod,
    components = parts,
    byId = {},
    activeGame = nil,
  }
  local sessionValues = {}

  for _, part in ipairs(parts) do Store.byId[part.id] = part end

  -- PokéIcons has a page but no code of its own (core/poke_icons.lua reads
  -- these two settings), so it is listed here rather than in components.lua.
  Store.byId.poke_icons = {
    id = "poke_icons", key = "poke_icons", name = "Poke Icons",
    short = "POKE ICONS", defaultEnabled = true,
  }

  local function deepCopy(value, done)
    if type(value) ~= "table" then return value end
    done = done or {}
    if done[value] then return done[value] end
    local copy = {}
    done[value] = copy
    for k, v in pairs(value) do copy[deepCopy(k, done)] = deepCopy(v, done) end
    return copy
  end

  local function partOf(self, idOrPart)
    if type(idOrPart) == "table" then return idOrPart end
    local part = self.byId[idOrPart]
    if not part then error("Project Highlander has no part called " .. tostring(idOrPart), 2) end
    return part
  end

  local function isSwitch(key) return key == "__enabled" end

  function Store:keyFor(idOrPart, key)
    local part = partOf(self, idOrPart)
    if isSwitch(key) then return part.key .. ".enabled" end
    return part.key .. "." .. key
  end

  -- The save's table and the live table for this mod; `make` creates them.
  local function buckets(game, make)
    local id = mainMod.id
    local inSave, inLive
    local options = game and game.save and game.save.options
    if options then
      if make then
        options.modOptions = options.modOptions or {}
        options.modOptions[id] = options.modOptions[id] or {}
      end
      inSave = options.modOptions and options.modOptions[id]
    end
    local mods = game and game.mods
    if mods then
      if make then
        mods.modOptions = mods.modOptions or {}
        mods.modOptions[id] = mods.modOptions[id] or {}
      end
      inLive = mods.modOptions and mods.modOptions[id]
    end
    return inSave, inLive
  end

  local function currentGame(self)
    local game = self.activeGame
    if game and game.save then return game end
    local ok, Game = pcall(require, "src.core.Game")
    if ok then return Game end
    return game
  end

  function Store:get(idOrPart, key)
    local part = partOf(self, idOrPart)
    if part.alwaysOn and isSwitch(key) then return true end
    local full = self:keyFor(part, key)
    if sessionValues[full] ~= nil then return sessionValues[full] end
    local inSave, inLive = buckets(currentGame(self), false)
    if inSave and inSave[full] ~= nil then return inSave[full] end
    if inLive and inLive[full] ~= nil then return inLive[full] end
    local fromMenu = mainMod.options:get(full)
    if fromMenu ~= nil then return fromMenu end
    if isSwitch(key) then return part.defaultEnabled ~= false end
    -- A default of false reads as "not set" (nil), as it always has.
    local default = part.defaults and part.defaults[key]
    if default then return default end
    return nil
  end

  -- quiet: don't announce the change (bulk writes like JUKEBOX > ALL SONGS).
  function Store:set(game, idOrPart, key, value, quiet)
    local part = partOf(self, idOrPart)
    game = game or self.activeGame
    assert(game, "Project Highlander settings need the live game")
    local full = self:keyFor(part, key)
    local inSave, inLive = buckets(game, true)
    -- Copies, so the save's table and the live table never share a table
    -- (the Start Menu stores tables as values).
    if inSave then inSave[full] = deepCopy(value) end
    if inLive then inLive[full] = deepCopy(value) end
    sessionValues[full] = deepCopy(value)
    pcall(function()
      if mainMod.options and type(mainMod.options.set) == "function" then
        mainMod.options:set(game, full, value)
      end
    end)
    local events = not quiet and game.mods and game.mods.events
    if events then
      -- Once under the main mod with the full key, once under the part with
      -- its short key (the Crystal and Steel/Fairy parts listen for that one).
      events:emit("mod.options_changed", {
        mod = mainMod.id, key = full, value = value, component = part.id,
      })
      events:emit("mod.options_changed", {
        mod = part.id, key = isSwitch(key) and "enabled" or key, value = value,
        parent = mainMod.id,
      })
    end
    return true
  end

  function Store:isEnabled(idOrPart)
    local part = partOf(self, idOrPart)
    if part.alwaysOn then return true end
    return self:get(part, "__enabled") ~= false
  end

  function Store:setEnabled(game, idOrPart, on, quiet)
    return self:set(game, idOrPart, "__enabled", on ~= false, quiet)
  end

  function Store:persist(game)
    game = game or self.activeGame
    if game and type(game.writeOptions) == "function" then
      return pcall(game.writeOptions, game)
    end
    return false
  end

  function Store:registerSchema(idOrPart, schema)
    local part = partOf(self, idOrPart)
    schema = schema or {}
    part.schema = schema
    part.defaults = part.defaults or {}
    for _, row in ipairs(schema) do
      if type(row) == "table" and type(row.key) == "string" then
        part.defaults[row.key] = row.default
      end
    end
    return schema
  end

  -- Row label on a part's own page: no need to repeat the page's name.
  function Store:detailLabel(idOrPart, row)
    local part = partOf(self, idOrPart)
    local label = tostring(row.label or row.key or part.name)
    label = label:gsub("^START MENU ", ""):gsub("^POKEDEX ", "")
    return label
  end

  ---------------------------------------------------------------------------
  -- The flat list the game's Mods menu shows for this mod. Its option boxes
  -- are narrow, so every row gets a short "<PART> <SETTING>" label.
  ---------------------------------------------------------------------------
  local MODS_MENU_PREFIX = {
    hstart = "START", battle_screen = "BATTLE", move_colors = "BATTLE",
    other_settings = "OTHER", rumble = "RUMBLE", custom_borders = "BORDERS",
  }
  local MODS_MENU_SHORT = {
    hstart = { colour = "COLOUR", colour_scope = "COLOUR SCOPE", clock = "CLOCK",
      pokebox = "POKEBOX" },
    crystal = { crystalAnimations = "ANIMATIONS", crystalBattleSprites = "BATTLE SPRITES",
      crystalFrontNPCs = "FRONT NPCS", crystalOverworldNPCs = "OVERWORLD NPCS" },
    steel = { preset = "PRESET", steel_type = "STEEL", dark_type = "DARK",
      fairy_type = "FAIRY", ghost_vs_steel = "GHOST/STEEL", dark_vs_steel = "DARK/STEEL",
      ghost_vs_psychic = "GHOST/PSY", bug_vs_poison = "BUG/POISON", ice_vs_fire = "ICE/FIRE",
      other_gen1_moves = "OTHER GEN1 MOVES" },
    rumble = { intensity = "INTENSITY", when_hit = "GET HIT", when_hitting = "HIT FOE" },
    custom_borders = { border = "BORDER", border_scope = "SCOPE", screen_ratio = "RATIO" },
    pokemoves = { forgettable_hms = "FORGET HMS", tms_forever = "TMS FOREVER",
      instant_tmhm = "INSTANT TMS/HMS", no_learn_hms = "NO LEARN HMS",
      move_relearning = "RELEARN" },
    other_settings = { always_boosted_exp = "BOOSTED EXP", modern_exp_share = "MODERN EXP",
      running_shoes = "SHOES", blue_into_green = "BLUE > GREEN", decapitalize = "DECAPITALIZE",
      display_area_names = "AREA NAMES", modern_stores = "STORES", infinite_safari = "SAFARI",
      unlimited_safari_balls = "SAFARI BALLS", safari_no_run = "SAFARI NO RUN",
      sparkling_hidden = "SPARKLES", rematch_anyone = "REMATCH", pikachu_sound = "PIKACHU",
      force_crystal_settings = "GENDER" },
    battle_screen = { enemy_hp_counter = "ENEMY HP", low_hp_beep = "LOW HP BEEP" },
    move_colors = { colored_pokeballs = "POKEBALLS", colored_pokemoves = "MOVES" },
  }

  local function modsMenuLabel(self, part, row)
    local prefix = MODS_MENU_PREFIX[part.key] or part.short
    if not row then return prefix .. " ENABLED" end
    local short = (MODS_MENU_SHORT[part.key] or {})[row.key] or self:detailLabel(part, row)
    if short:sub(1, #prefix + 1) == prefix .. " " then return short end
    return prefix .. " " .. short
  end

  -- Storage-only rows ("BY GAME" tables) never show in the Mods menu.
  local NOT_IN_MODS_MENU = { theme_by_game = true, border_by_game = true }

  function Store:aggregateSchema()
    local rows = {}
    for _, part in ipairs(self.components) do
      if not part.alwaysOn then
        rows[#rows + 1] = {
          key = self:keyFor(part, "__enabled"), label = modsMenuLabel(self, part),
          type = "toggle", default = part.defaultEnabled ~= false,
        }
      end
    end
    for _, part in ipairs(self.components) do
      for _, row in ipairs(part.schema or {}) do
        if not NOT_IN_MODS_MENU[row.key] then
          local entry = deepCopy(row)
          entry.key = self:keyFor(part, row.key)
          entry.label = modsMenuLabel(self, part, row)
          rows[#rows + 1] = entry
        end
      end
    end
    return rows
  end

  Store:registerSchema(Store.byId.poke_icons, {
    { key = "party", label = "ICONS FOR PARTY", type = "choice", default = "original",
      choices = { { "ORIGINAL", "original" }, { "WILD FOLLOWERS", "followers" } } },
    { key = "pc", label = "ICONS FOR PC", type = "choice", default = "original",
      choices = { { "ORIGINAL", "original" }, { "WILD FOLLOWERS", "followers" } } },
  })

  return Store
end
