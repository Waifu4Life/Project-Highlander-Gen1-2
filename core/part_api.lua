-- What each Project Highlander part sees as `mod`.
--
-- A part is installed like a small mod of its own: it gets its own id, its
-- own folder for files and pictures, and its own settings (stored by
-- core/settings.lua under the main mod). Anything not listed here comes
-- straight from the main mod.
--
-- A part with an ON/OFF switch is fully off while switched off: its event
-- listeners and hooks don't run, and its screens fall back to whatever was
-- registered before it (another mod's, or the game's own).
return function(mainMod, store, shared, part)
  local folder = "components/" .. (part.folder or part.id)
  local function isOn() return store:isEnabled(part) end

  local api = {
    id = part.id,
    version = part.version,
    path = mainMod.path .. "/" .. folder,
    manifest = { id = part.id, version = part.version },
    exports = {},
  }
  -- Plain services passed through untouched.
  for _, name in ipairs({ "DELETE", "ui", "save", "storage", "checkpoints", "input", "migrations" }) do
    api[name] = mainMod[name]
  end
  part.exports = api.exports
  shared.componentApis[part.id] = api

  ---------------------------------------------------------------------------
  -- Settings
  ---------------------------------------------------------------------------
  api.options = {
    define = function(_, schema) return store:registerSchema(part, schema) end,
    get = function(_, key) return store:get(part, key) end,
    -- quiet: no mod.options_changed event (bulk writes)
    set = function(_, game, key, value, quiet) return store:set(game, part, key, value, quiet) end,
    enabled = function() return isOn() end,
  }

  -- Things every part can reach: mod.highlander.*
  local function shortcuts() return shared.itemShortcuts end
  api.highlander = {
    pokeIcons = shared.pokeIcons,
    heldDirs = shared.heldDirs,
    pagedText = shared.pagedText,
    itemShortcuts = shared.itemShortcuts,
    openShortcutMenu = function(game, rows)
      return shortcuts() and shortcuts().open(game, rows)
    end,
    injectButton = function(game, button)
      return shortcuts() and shortcuts().inject(game, button)
    end,
    addFrameJob = function(fn)
      return shortcuts() and shortcuts().addJob(fn)
    end,
    option = function(id, key) return store:get(id, key) end,
    enabled = function(id) return store:isEnabled(id) end,
  }

  ---------------------------------------------------------------------------
  -- Events and hooks (silent while the part is switched off)
  ---------------------------------------------------------------------------
  api.events = {
    on = function(_, name, callback, priority)
      return mainMod.events:on(name, function(payload)
        if isOn() then return callback(payload) end
      end, priority)
    end,
    once = function(_, name, callback, priority)
      local stop
      stop = mainMod.events:on(name, function(payload)
        if not isOn() then return end
        if stop then stop(); stop = nil end
        return callback(payload)
      end, priority)
      return stop
    end,
    emit = function(_, name, payload) return mainMod.events:emit(name, payload) end,
    -- Runs even while the part is switched off.
    always = function(_, name, callback, priority)
      return mainMod.events:on(name, callback, priority)
    end,
  }

  api.hooks = {
    wrap = function(_, name, callback, priority)
      -- A part's Options-menu rows don't go to the game's Options screen:
      -- core/hub.lua shows them on the part's page.
      if name == "ui.options.rows" then
        shared.optionsHooks[part.id] = callback
        return function() shared.optionsHooks[part.id] = nil end
      end
      return mainMod.hooks:wrap(name, function(nextFn, ...)
        if isOn() then return callback(nextFn, ...) end
        return nextFn(...)
      end, priority)
    end,
  }

  ---------------------------------------------------------------------------
  -- Screens
  ---------------------------------------------------------------------------
  -- The game's own screen for an id: "Gen2PackMenu" lives in
  -- src/ui/gen2/PackMenu.lua, "BagMenu" in src/ui/BagMenu.lua.
  local function gameScreenModule(id)
    local gen2Name = id:match("^Gen2(.+)$")
    if gen2Name then return "src.ui.gen2." .. gen2Name end
    return "src.ui." .. id
  end

  local function makerOf(record)
    if type(record) == "function" then return record end
    if type(record) == "table" then return record.new end
    return nil
  end

  -- While the part is off, its screen hands over to the one it replaced.
  local function switchable(id, record, previous)
    -- Settings pages and the icon picker are always the part's own.
    if id:find(":settings", 1, true) or id:find(":icon_picker", 1, true) then
      return record
    end
    local build = makerOf(record)
    assert(build, "screen " .. id .. " has no constructor")
    local wrapped = {}
    if type(record) == "table" then
      for k, v in pairs(record) do wrapped[k] = v end
      setmetatable(wrapped, getmetatable(record))
    end
    wrapped.new = function(game, ...)
      if isOn() then return build(game, ...) end
      local fallback = makerOf(previous)
      if fallback then return fallback(game, ...) end
      local moduleName = gameScreenModule(id)
      local ok, Screen = pcall(require, moduleName)
      assert(ok and type(Screen) == "table" and type(Screen.new) == "function",
        "no game screen to fall back to for " .. id)
      return Screen.new(game, ...)
    end
    wrapped.__highlanderComponent = part.id
    wrapped.__highlanderEnabled = isOn
    return wrapped
  end

  local screens = mainMod.content.screens
  local function touched()
    shared.screenTouches[part.id] = (shared.screenTouches[part.id] or 0) + 1
  end
  api.content = setmetatable({
    screens = {
      get = function(_, id) return screens:get(id) end,
      has = function(_, id) return screens:get(id) ~= nil end,
      register = function(_, id, record)
        touched()
        return screens:register(id, switchable(id, record, screens:get(id)))
      end,
      override = function(_, id, record)
        touched()
        return screens:override(id, switchable(id, record, screens:get(id)))
      end,
      patch = function(_, ...) return screens:patch(...) end,
      remove = function(_, ...) return screens:remove(...) end,
    },
  }, { __index = mainMod.content })

  ---------------------------------------------------------------------------
  -- Files and pictures, relative to the part's folder
  ---------------------------------------------------------------------------
  api.assets = setmetatable({
    path = function(_, relative) return mainMod.assets:path(folder .. "/" .. relative) end,
    image = function(_, relative) return mainMod.assets:image(folder .. "/" .. relative) end,
  }, { __index = mainMod.assets })

  function api:read(relative)
    return mainMod:read(folder .. "/" .. relative)
  end

  function api:load(relative)
    local source, readErr = self:read(relative)
    assert(source, tostring(readErr or (relative .. " is missing")))
    local chunk, compileErr = load(source, "@" .. self.path .. "/" .. relative)
    assert(chunk, compileErr)
    return chunk()
  end

  -- mod.find("x") or mod:find("x"): another part of Project Highlander, or
  -- any other installed mod.
  api.find = function(a, b)
    local id = b == nil and a or b
    local other = shared.componentApis[id]
    if not other then return mainMod.find(id) end
    local info = store.byId[id] or {}
    return {
      id = id, version = info.version, exports = other.exports,
      assets = other.assets, path = other.path,
      read = function(_, relative) return other:read(relative) end,
    }
  end

  -- Log lines are tagged with the part's id; an error also stops the install.
  api.log = {
    info = function(_, fmt, ...) return mainMod.log:info("[%s] " .. fmt, part.id, ...) end,
    warn = function(_, fmt, ...) return mainMod.log:warn("[%s] " .. fmt, part.id, ...) end,
    error = function(_, fmt, ...)
      shared.bootErrors[part.id] = string.format(fmt, ...)
      return mainMod.log:error("[%s] " .. fmt, part.id, ...)
    end,
  }

  return setmetatable(api, { __index = mainMod })
end
