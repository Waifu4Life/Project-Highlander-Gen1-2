-- Project Highlander Gen1+2: start-up.
--
-- The mod is made of parts (core/components.lua), each in its own folder
-- under components/ and each installed as if it were a small mod of its own
-- (core/part_api.lua). This file:
--   1. loads the shared pieces (settings, PokeIcons, Item Shortcuts, focus fix)
--   2. checks every part's files are present and readable
--   3. installs the parts in their set order
--   4. adds the PROJECTHIGHLANDER entry to the Options menu (core/hub.lua)
return function(mod)
  local function runFile(relative)
    local source, readErr = mod:read(relative)
    assert(source, tostring(readErr or (relative .. " is missing")))
    local chunk, compileErr = load(source, "@" .. mod.path .. "/" .. relative)
    assert(chunk, compileErr)
    return chunk()
  end

  local parts = runFile("core/components.lua")
  local store = runFile("core/settings.lua")(mod, parts)
  local partApi = runFile("core/part_api.lua")
  local buildHub = runFile("core/hub.lua")

  -- Shared between the parts, the settings menu and this file.
  local shared = {
    componentApis = {},  -- part id -> its `mod`
    optionsHooks = {},   -- part id -> its Options-row hook (shown in the hub)
    screenTouches = {},  -- part id -> how many screens it registered
    bootErrors = {},     -- part id -> error logged while installing
  }
  shared.heldDirs = runFile("core/held_dirs.lua")()
  shared.pagedText = runFile("core/paged_text.lua")()
  shared.pokeIcons = runFile("core/poke_icons.lua")(mod, store)
  -- Always on: Key Item shortcuts (Bag SHORT.1-3 rows and the SELECT box).
  shared.itemShortcuts = runFile("core/item_shortcuts.lua")(mod, store)
  -- Always on: take keyboard/gamepad focus when started from outside the
  -- launcher (frontend, Playnite, -red / -blue shortcuts).
  pcall(function() runFile("core/window_focus.lua")(mod) end)
  -- Always on: the mouse pointer hides after 2 seconds without moving.
  pcall(function() runFile("core/mouse_hide.lua")(mod) end)

  -- Check the whole zip first: a missing or broken file stops the mod here,
  -- before any part has changed anything in the game.
  for _, part in ipairs(parts) do
    local base = "components/" .. (part.folder or part.id) .. "/"
    for _, relative in ipairs(part.files or {}) do
      local path = base .. relative
      local source, readErr = mod:read(path)
      assert(source, tostring(readErr or (path .. " is missing")))
      assert(load(source, "@" .. mod.path .. "/" .. path))
    end
    for _, relative in ipairs(part.assets or {}) do
      local path = base .. relative
      local bytes, readErr = mod:read(path)
      assert(bytes and #bytes > 0, tostring(readErr or (path .. " is missing or empty")))
    end
  end

  -- Settings need the running game before any part's game.ready work.
  mod.events:on("game.ready", function(event)
    local game = event and (event.game or event)
    if type(game) == "table" then store.activeGame = game end
  end, 10000)

  local order = {}
  for i, part in ipairs(parts) do order[i] = part end
  table.sort(order, function(a, b) return a.installOrder < b.installOrder end)
  for _, part in ipairs(order) do
    local partMod = partApi(mod, store, shared, part)
    local install = partMod:load("main.lua")
    assert(type(install) == "function", part.id .. "/main.lua must return a function")
    install(partMod)
    local failed = shared.bootErrors[part.id]
    if failed then error(part.id .. " failed to initialize: " .. failed, 0) end
  end

  ---------------------------------------------------------------------------
  -- MENU SPEED for our menus
  ---------------------------------------------------------------------------
  -- With per-category GAME SPEED, a menu opened over the overworld would run
  -- at OVERWORLD SPEED. While one of our screens (or a prompt on top of it)
  -- is the newest thing on screen, use MENU SPEED instead. A battle or the
  -- overworld above it ends the search.
  local OUR_SCREEN_FLAGS = {
    "highlanderStartMenu", "highlanderComponent", "highlanderBag", "highlanderPC",
    "highlanderParty", "highlanderSummary", "highlanderTrainerId",
  }
  local ourIdPrefixes = { mod.id .. ":" }
  for _, part in ipairs(parts) do ourIdPrefixes[#ourIdPrefixes + 1] = part.id .. ":" end

  local function isOurs(screen)
    for _, flag in ipairs(OUR_SCREEN_FLAGS) do
      if screen[flag] == true then return true end
    end
    local id = screen.screenId
    if type(id) == "string" then
      for _, prefix in ipairs(ourIdPrefixes) do
        if id:sub(1, #prefix) == prefix then return true end
      end
    end
    return false
  end

  local function ourMenuOnTop(game)
    local states = game and game.stack and game.stack.states or {}
    for i = #states, 1, -1 do
      local screen = states[i]
      if type(screen) == "table" then
        if isOurs(screen) then return true end
        if screen.isBattle or screen.isOverworld then return false end
      end
    end
    return false
  end

  mod.hooks:wrap("core.logic_speed", function(nextFn, game)
    local speed = nextFn(game)
    if not ourMenuOnTop(game) then return speed end
    local options = game and game.save and game.save.options
    -- Older game builds have a single speed: leave it alone there.
    return tonumber(options and options.speedMenu) or speed
  end, 1000)

  ---------------------------------------------------------------------------
  -- The old mod id
  ---------------------------------------------------------------------------
  -- Until 1.0.0 the mod was "project_highlander". Other mods may still look
  -- it up by that name, so answer to it too (unless the old mod itself is
  -- installed). It is not listed as a second mod: the loader would then see
  -- Project Highlander twice.
  local OLD_ID = "project_highlander"
  local function answerToOldId(game)
    local loader = type(game) == "table" and game.mods or nil
    if type(loader) ~= "table" then return end
    if type(loader.exports) == "table" and loader.exports[OLD_ID] == nil then
      loader.exports[OLD_ID] = loader.exports[mod.id]
    end
    if type(loader.mods) == "table" and loader.mods[OLD_ID] == loader.mods[mod.id] then
      loader.mods[OLD_ID] = nil
    end
  end
  mod.events:on("game.ready", function(event)
    pcall(answerToOldId, type(event) == "table" and (event.game or event) or nil)
  end, 10000)

  ---------------------------------------------------------------------------
  -- Gen 1 full-colour pieces
  ---------------------------------------------------------------------------
  -- Full-colour pieces (the Gender Mod Trainer ID portrait, the caught-ball
  -- marker, Crystal art, coloured icons...) ask the game to skip its palette
  -- pass with PaletteFX.markTrueColor. Newer G1R builds only honour those
  -- marks in the RED++ colour mode, so in every other mode the pass bleaches
  -- them (light colours turn white). Hand the marks to the palette pass
  -- ourselves when the game doesn't.
  pcall(function()
    local GV = require("src.core.GameVersion")
    if GV.generation and GV.generation() ~= 1 then return end
    local PaletteFX = require("src.render.PaletteFX")
    if type(PaletteFX.honorsTrueColor) ~= "function"
        or type(PaletteFX.trueColorRects) ~= "function" then return end
    mod.hooks:wrap("render.zones", function(nextFn, game, zones)
      zones = nextFn(game, zones)
      if type(zones) ~= "table" or not zones[1] then return zones end
      local okH, honoured = pcall(PaletteFX.honorsTrueColor)
      if okH and honoured then return zones end
      local okR, rects = pcall(PaletteFX.trueColorRects, "ui")
      if not okR or type(rects) ~= "table" or not rects[1] then return zones end
      local merged = {}
      for i = 1, #zones do merged[i] = zones[i] end
      for i = 1, #rects do merged[#merged + 1] = rects[i] end
      return merged
    end)
  end)

  ---------------------------------------------------------------------------
  -- Settings menu and what other mods can see
  ---------------------------------------------------------------------------
  mod.options:define(store:aggregateSchema())
  local hub = buildHub(mod, store, shared, parts)

  local public = {}
  for _, part in ipairs(parts) do
    public[part.id] = {
      version = part.version,
      enabled = function() return store:isEnabled(part) end,
      exports = part.exports,
    }
  end
  mod.exports.components = public
  mod.exports.isEnabled = function(id)
    local part = store.byId[id]
    return part and store:isEnabled(part) or false
  end
  mod.exports.settings = hub
  mod.exports.apiVersion = 1
  mod.log:info(tostring(#parts) .. "-part Project Highlander Gen1+2 initialized")
end
