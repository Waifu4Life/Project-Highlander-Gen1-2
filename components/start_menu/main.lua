-- Highlander Start Menu (1.27.0): Project Highlander's own FULL SCREEN Start
-- Menu for Gen 1 and Gen 2. It takes over the game's START screens through
-- the screen registry, the same way the Bag and PC components do: the game
-- (and any other mod) still builds the menu and its rows, then this
-- component sorts the rows and draws and drives them as a 160x144 page.
return function(mod)
  local E = mod:load("entries.lua")()
  local icons = mod:load("icons.lua")
  local W, H = 160, 144

  mod.options:define({
    { key = "colour", label = "COLOUR", type = "custom", default = "auto" },
    { key = "colour_scope", label = "COLOUR SCOPE", type = "choice",
      default = "game", choices = { { "GAME", "game" }, { "SAVE", "save" } } },
    -- OFF / DEVICE / PLAY / IN-GAME (Gold, Silver, Crystal) / ROTATION
    { key = "clock", label = "CLOCK", type = "custom", default = "rotation" },
    -- Shown on START > HIDE ITEMS, not as a row of its own.
    { key = "pokebox", label = "POKEBOX", type = "toggle", default = true,
      hidden = true },
  })
  -- Stored without a row of their own: colour_by_game, order, icons,
  -- mod_rows, hidden and option_rows (core/hub.lua).

  local lastGame
  local pokeboxShown -- HIDE ITEMS section below
  local clockValue -- CLOCK section below
  local function liveGame(game)
    if type(game) == "table" and game.save then lastGame = game return game end
    if lastGame then return lastGame end
    local ok, Game = pcall(require, "src.core.Game")
    return ok and type(Game) == "table" and Game or nil
  end

  local function get(key) return mod.options:get(key) end
  local function put(game, key, value)
    game = liveGame(game)
    if not game then return end
    mod.options:set(game, key, value)
    if type(game.writeOptions) == "function" then pcall(game.writeOptions, game) end
  end

  ---------------------------------------------------------------------------
  -- COLOUR
  ---------------------------------------------------------------------------
  local COLOURS = {
    { "AUTOMATIC", "auto" }, { "RED", "red" }, { "BLUE", "blue" },
    { "GREEN", "green" }, { "YELLOW", "yellow" }, { "GOLD", "gold" },
    { "SILVER", "silver" }, { "CRYSTAL", "crystal" },
  }
  -- paper, light, dark, ink
  local PALETTES = {
    red = { { 255, 240, 236 }, { 240, 128, 112 }, { 176, 40, 48 }, { 40, 16, 16 } },
    blue = { { 236, 244, 255 }, { 120, 168, 240 }, { 32, 80, 176 }, { 16, 24, 56 } },
    yellow = { { 255, 252, 230 }, { 255, 224, 96 }, { 240, 176, 16 }, { 80, 48, 0 } },
    green = { { 232, 255, 232 }, { 96, 212, 112 }, { 32, 132, 56 }, { 16, 36, 16 } },
    gold = { { 255, 244, 214 }, { 232, 176, 64 }, { 156, 100, 24 }, { 40, 24, 8 } },
    silver = { { 236, 244, 248 }, { 168, 184, 200 }, { 88, 104, 128 }, { 20, 24, 32 } },
    crystal = { { 232, 252, 255 }, { 96, 216, 232 }, { 32, 120, 168 }, { 8, 24, 48 } },
  }
  local function validColour(v) return v == "auto" or PALETTES[v] ~= nil end

  -- The cart being played ("green" when Blue is launched as Green).
  local function cart()
    local ok, GV = pcall(require, "src.core.GameVersion")
    if ok and type(GV) == "table" and type(GV.get) == "function" then
      local id = GV.get()
      if id == "blue" then
        local name = tostring(GV.launcherName or GV.displayName or ""):lower()
        if name:find("green", 1, true) then return "green" end
      end
      if type(id) == "string" and id ~= "" then return id end
    end
    return "red"
  end

  local function saveBucket(game, create)
    game = liveGame(game)
    local save = game and game.save
    if not save then return nil end
    if create then save.modData = save.modData or {} end
    local data = save.modData
    if not data then return nil end
    if create and type(data.highlander_start) ~= "table" then
      data.highlander_start = {}
    end
    return data.highlander_start, data
  end

  -- One table: cart -> colour.
  local function byGame()
    local map = get("colour_by_game")
    return type(map) == "table" and map or {}
  end

  local function storedColour(game)
    if get("colour_scope") == "save" then
      local bucket = saveBucket(game, false)
      local v = bucket and bucket.colour
      return validColour(v) and v or "auto"
    end
    local v = byGame()[cart()]
    return validColour(v) and v or "auto"
  end

  local function setColour(game, value)
    if get("colour_scope") == "save" then
      local bucket = saveBucket(game, true)
      if bucket then bucket.colour = value end
    else
      local map = {}
      for k, v in pairs(byGame()) do map[k] = v end
      map[cart()] = value
      put(game, "colour_by_game", map)
    end
  end

  local function palette(game)
    local v = storedColour(game)
    if v == "auto" then v = PALETTES[cart()] and cart() or "red" end
    return PALETTES[v]
  end

  local function colourLabel(game)
    local v = storedColour(game)
    for _, c in ipairs(COLOURS) do if c[2] == v then return c[1] end end
    return "AUTOMATIC"
  end

  local function stepColour(game, direction)
    local v, at = storedColour(game), 1
    for i, c in ipairs(COLOURS) do if c[2] == v then at = i break end end
    at = (at - 1 + (direction or 1)) % #COLOURS + 1
    setColour(game, COLOURS[at][2])
    return true
  end

  ---------------------------------------------------------------------------
  -- CLOCK (the Start Menu's top bar)
  ---------------------------------------------------------------------------
  local CLOCKS = {
    { "OFF", "off" }, { "DEVICE", "device" }, { "PLAY", "play" },
    { "IN-GAME", "ingame", gen2Only = true }, { "ROTATION", "rotation" },
  }
  local function isGen2()
    local ok, GV = pcall(require, "src.core.GameVersion")
    return ok and type(GV) == "table" and type(GV.generation) == "function"
      and GV.generation() == 2
  end
  -- IN-GAME only exists in Gen 2; a Gen 1 game shows DEVICE instead.
  clockValue = function()
    local v = get("clock")
    for _, c in ipairs(CLOCKS) do
      if c[2] == v then
        if c.gen2Only and not isGen2() then return "device" end
        return v
      end
    end
    return "rotation"
  end
  local function clockLabel()
    local v = clockValue()
    for _, c in ipairs(CLOCKS) do if c[2] == v then return c[1] end end
    return "ROTATION"
  end
  local function stepClock(game, direction)
    local v, at = clockValue(), 1
    for i, c in ipairs(CLOCKS) do if c[2] == v then at = i break end end
    local gen2 = isGen2()
    repeat
      at = (at - 1 + (direction or 1)) % #CLOCKS + 1
    until gen2 or not CLOCKS[at].gen2Only
    put(game, "clock", CLOCKS[at][2])
    return true
  end

  ---------------------------------------------------------------------------
  -- ORDER, CUSTOM ICONS and the list of other mods' rows
  ---------------------------------------------------------------------------
  local orderVersion = 0

  -- The player's own layout lives in the save file (save.modData
  -- .highlander_start): order, icons, names, hidden, pokebox. Whatever the
  -- old builds kept in the options file moves into the first save loaded.
  local mine -- set below
  local function globalOrder()
    local list = get("order")
    return type(list) == "table" and list or {}
  end

  local function order(game)
    local list = mine(game, "order")
    return type(list) == "table" and list or {}
  end

  local function iconTable(game)
    local t = mine(game, "icons")
    return type(t) == "table" and t or {}
  end

  local function globalIcons()
    local t = get("icons")
    return type(t) == "table" and t or {}
  end

  local function baseKey(key) return (tostring(key):gsub("#%d+$", "")) end

  local function getIcon(key)
    local v = iconTable()[baseKey(key)]
    return icons.frames[v] and v ~= "auto" and v or nil
  end

  local setMine -- set below
  local function saveOrder(keys, game)
    setMine(game, "order", keys or {})
    orderVersion = orderVersion + 1
  end

  local function setIcon(game, key, frame)
    local t = {}
    for k, v in pairs(iconTable(game)) do t[k] = v end
    t[baseKey(key)] = frame
    setMine(game, "icons", t)
    orderVersion = orderVersion + 1
  end

  -- CUSTOM RENAME: { [key] = "NAME" }, up to 6 characters.
  -- Tiles that start out with a short name of their own (CUSTOM RENAME
  -- still changes them; an empty name brings this one back).
  local DEFAULT_NAMES = {
    ["mod:opt:highlander_settings"] = "P.High",
  }
  local function nameFor(key, game)
    local t = mine(game, "names")
    local v = type(t) == "table" and t[baseKey(key)] or nil
    if type(v) == "string" and v ~= "" then return v end
    return DEFAULT_NAMES[baseKey(key)]
  end
  local function setName(game, key, name)
    local t = {}
    local old = mine(game, "names")
    for k, v in pairs(type(old) == "table" and old or {}) do t[k] = v end
    t[baseKey(key)] = (type(name) == "string" and name ~= "") and name or nil
    setMine(game, "names", t)
    orderVersion = orderVersion + 1
  end

  local function modRows()
    local list = get("mod_rows")
    return type(list) == "table" and list or {}
  end

  local function rememberModRows(rows, game)
    local list, index, changed = {}, {}, false
    for i, r in ipairs(modRows()) do
      list[i] = { key = r.key, label = r.label }
      index[r.key] = list[i]
    end
    for _, row in ipairs(rows) do
      local key = baseKey(row.key)
      -- (Options shortcuts, "mod:opt:...", are listed from option_rows.)
      if key:sub(1, 4) == "mod:" and key:sub(1, 8) ~= "mod:opt:" then
        local label = tostring(row.item.label or row.item.id or "MENU")
        if not index[key] then
          list[#list + 1] = { key = key, label = label }
          index[key] = list[#list]
          changed = true
        elseif index[key].label ~= label then
          index[key].label = label
          changed = true
        end
      end
    end
    if changed or type(get("mod_rows")) ~= "table" then put(game, "mod_rows", list) end
  end

  -- Reading a field of the save's layout. The first time a save is read,
  -- the old options-file layout (if any, and not yet moved) is copied in.
  mine = function(game, field)
    local bucket = saveBucket(game, true)
    if bucket and not bucket.layout and not get("layout_moved") then
      local g = liveGame(game)
      bucket.layout = 1
      local hiddenOld = get("hidden")
      bucket.order = globalOrder()
      bucket.icons = globalIcons()
      bucket.hidden = type(hiddenOld) == "table" and hiddenOld or {}
      if get("pokebox") == false then bucket.pokebox = false end
      put(g, "layout_moved", true)
    elseif bucket and not bucket.layout then
      bucket.layout = 1
    end
    return bucket and bucket[field]
  end
  setMine = function(game, field, value)
    local bucket = saveBucket(game, true)
    if not bucket then return end
    mine(game, field)
    bucket[field] = value
  end

  ---------------------------------------------------------------------------
  -- the page
  ---------------------------------------------------------------------------
  local Page
  local function openSort(game)
    if not (game and game.stack) then return false end
    local gen2 = false
    pcall(function() gen2 = require("src.core.GameVersion").generation() == 2 end)
    -- The Start Menu underneath (SELECT on it), or, from START > SORT MENU,
    -- one built just to read its rows: the game and every mod fill it in
    -- exactly as they would when START is pressed. It's never shown.
    local rows
    local states = game.stack.states or {}
    for i = #states, 1, -1 do
      local s = states[i]
      if type(s) == "table" and s.hs then rows = s.hs.rows break end
    end
    if not rows and game.save then
      local ok, menu = pcall(function()
        return require("src.ui.Screens").build(game,
          gen2 and "Gen2StartMenu" or "StartMenu", gen2 and { save = game.save } or nil)
      end)
      if ok and type(menu) == "table" then
        if menu.hs then
          rows = menu.hs.rows
        elseif type(menu.items) == "table" then
          rows = E.sorted(menu.items, order(game), game)
        end
      else
        mod.log:warn("SORT MENU could not read the Start Menu: %s", tostring(menu))
      end
    end
    game.stack:push(Page.newSort(game, rows or {}, gen2, mod.id))
    return true
  end

  Page = mod:load("page.lua")({
    entries = E,
    icons = icons,
    image = function(path) return mod.assets:image(path) end,
    palette = function(game) return palette(game) end,
    clockMode = function() return clockValue() end,
    iconFor = getIcon,
    nameFor = function(key) return nameFor(key) end,
    order = order,
    saveOrder = function(keys, game) saveOrder(keys, game) end,
    openSort = openSort,
    log = mod.log,
  })

  local CustomIcons = mod:load("custom_icons.lua")({
    id = mod.id, page = Page, entries = E, choices = icons.choices,
    ListMenu = mod.ui and mod.ui.ListMenu,
    -- other mods' Start rows, plus the shortcuts to mods' Options pages
    modRows = function()
      local list = {}
      for _, r in ipairs(modRows()) do list[#list + 1] = r end
      local options = get("option_rows")
      for _, r in ipairs(type(options) == "table" and options or {}) do
        if type(r) == "table" and r.key then
          list[#list + 1] = { key = "mod:" .. r.key, label = r.label }
        end
      end
      return list
    end,
    getIcon = getIcon, setIcon = setIcon,
  })

  local function blackSurround(_, w, h)
    love.graphics.push("all")
    love.graphics.setShader()
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, w or love.graphics.getWidth(),
      h or love.graphics.getHeight())
    love.graphics.pop()
  end

  local function signature(menu)
    local parts = { orderVersion, #menu.items }
    for _, item in ipairs(menu.items) do parts[#parts + 1] = tostring(item) end
    return table.concat(parts, "|")
  end

  -- Put menu.items into the saved order (in place: Gen 2's list and Gen 1's
  -- own rows keep pointing at the same table) and keep the cursor on the
  -- row it was on.
  local function arrange(menu)
    local hs = menu.hs
    local keep = hs.rows and hs.rows[hs.index] and hs.rows[hs.index].item
    hs.rows = E.sorted(menu.items, order(menu.game), menu.game)
    -- menu.items keeps only the real rows (the game counts on them); hs.rows
    -- also has the empty tiles, so remember where each row's item sits.
    local n = 0
    for _, row in ipairs(hs.rows) do
      if not row.gap then
        n = n + 1
        menu.items[n], row.itemIndex = row.item, n
      end
    end
    hs.index = nil
    local want = menu.game and menu.game.highlanderStartCursor
    for i, row in ipairs(hs.rows) do
      if not row.gap and ((keep and row.item == keep) or (not keep and row.key == want)) then
        hs.index = i
        break
      end
    end
    if not hs.index then
      hs.index = 1
      for i, row in ipairs(hs.rows) do
        if not row.gap then hs.index = i break end
      end
    end
    hs.sig = signature(menu)
    rememberModRows(hs.rows, menu.game)
  end

  local function attach(menu, game)
    if type(menu) ~= "table" or menu.highlanderStartMenu then return menu end
    if type(menu.items) ~= "table" or type(menu.update) ~= "function" then
      mod.log:warn("START screen without rows; leaving it to the game")
      return menu
    end
    game = liveGame(game or menu.game)
    menu.game = menu.game or game
    local hs = {
      gen2 = type(menu.list) == "table" and type(menu.choose) == "function"
        and type(menu.close) == "function",
      nativeUpdate = menu.update,
      index = 1,
    }
    menu.hs = hs
    function hs.select(m, index)
      hs.index = index
      local row = hs.rows[index]
      if row and m.game then m.game.highlanderStartCursor = row.key end
      local at = row and row.itemIndex or 1
      if hs.gen2 then m.list.index = at else m.index = at end
    end
    function hs.refresh(m)
      if hs.sig ~= signature(m) then arrange(m) end
    end
    arrange(menu)
    hs.select(menu, hs.index)

    menu.highlanderStartMenu = true
    menu.highlanderStartFull = true -- Custom Borders frames it
    menu.isOpaque = true
    -- Nothing opened on top (Gen 1's SAVE panel, the Bag...) may slide the
    -- screen sideways or dock to the window edges (UI LAYOUT: DYNAMIC);
    -- Game:draw reads this off the stack.
    menu.holdsUIAnchors = true
    menu.update = Page.update
    menu.draw = Page.draw
    menu.uiSize = function() return W, H end
    menu.sgbPalettes = function(self)
      return { { colors = palette(self.game), x = 0, y = 0, w = W, h = H } }
    end
    if menu.drawWidescreen == nil then menu.drawWidescreen = blackSurround end
    return menu
  end

  ---------------------------------------------------------------------------
  -- hooking into the game
  ---------------------------------------------------------------------------
  local NATIVE = { StartMenu = "src.ui.StartMenu", Gen2StartMenu = "src.ui.gen2.StartMenu" }
  for id, path in pairs(NATIVE) do
    local downstream = mod.content.screens:get(id)
    local build = type(downstream) == "function" and downstream
      or (type(downstream) == "table" and downstream.new) or nil
    local record = {
      new = function(game, ...)
        local menu = build and build(game, ...) or require(path).new(game, ...)
        return attach(menu, game)
      end,
    }
    if downstream then
      mod.content.screens:override(id, record)
    else
      mod.content.screens:register(id, record)
    end
  end
  -- Safety net for a START screen another mod builds itself.
  mod.events:on("screen.pushed", function(event)
    local s = type(event) == "table" and event.state or nil
    if type(s) == "table" and not s.highlanderStartMenu
        and (s.screenId == "StartMenu" or s.screenId == "Gen2StartMenu") then
      attach(s, s.game)
    end
  end, -1000)

  -- Gen 2 SAVE: the save screen opens over the Start Menu and draws its
  -- boxes and text through Gold's box palette (white paper, black ink).
  -- While it sits on the Start Menu, draw it in the Start Menu's COLOUR,
  -- the way Gen 1's SAVE panel takes it from the SGB palette.
  local function overStartMenu(screen)
    local states = screen.game and screen.game.stack and screen.game.stack.states or {}
    for i = #states, 1, -1 do
      local s = states[i]
      if s ~= screen and type(s) == "table" then
        if s.highlanderStartMenu then return s end
        if s.isOpaque then return nil end
      end
    end
  end
  mod.events:on("screen.pushed", function(event)
    local s = type(event) == "table" and event.state or nil
    if type(s) ~= "table" or s.screenId ~= "Gen2SaveMenu" or s.hsTinted
        or type(s.draw) ~= "function" then return end
    s.hsTinted = true
    s.game = s.game or lastGame
    local draw = s.draw
    s.draw = function(self, ...)
      local okC, Chrome = pcall(require, "src.ui.gen2.Chrome")
      local colors = overStartMenu(self) and palette(self.game)
      if not (okC and type(Chrome) == "table" and colors) then
        return draw(self, ...)
      end
      local saved = Chrome.DEFAULT_BOX_PALETTE
      Chrome.DEFAULT_BOX_PALETTE = colors
      local ok, err = pcall(draw, self, ...)
      Chrome.DEFAULT_BOX_PALETTE = saved
      if not ok then error(err, 0) end
    end
  end)

  -- POKEBOX: Bill's PC straight from START, once the player has a Pokemon
  -- (the box screens have nothing to show before that).
  local function openPokebox(game)
    local Screens = require("src.ui.Screens")
    pcall(function() require("src.core.Sound").play(game.data, "Enter_PC") end)
    local gen2 = false
    pcall(function() gen2 = require("src.core.GameVersion").generation() == 2 end)
    for _, id in ipairs(gen2 and { "Gen2BoxMenu", "Gen2PcMenu" } or { "BoxMenu" }) do
      if pcall(Screens.push, game, id) then return end
    end
    local TextBox = require("src.render.TextBox")
    local Strings = require("src.core.Strings")
    game.stack:push(TextBox.new(game, Strings("PC is not\navailable now.")))
  end

  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    items = next(game, items) or items or {}
    local party = game and game.save and game.save.party
    local hasBox = false
    for _, item in ipairs(items) do
      if type(item) == "table" then
        local key = E.keyOf(item, game)
        if key == "pokebox" then hasBox = true end
        -- MODS opens over the Start Menu, which waits underneath.
        if key == "mods" then item.keepOpen = true end
      end
    end
    if pokeboxShown(game) and type(party) == "table" and #party > 0
        and not hasBox then
      items[#items + 1] = {
        id = "pokebox", label = "POKEBOX", keepOpen = true,
        onSelect = function() openPokebox(game) end,
      }
    end
    return items
  end)

  ---------------------------------------------------------------------------
  -- HIDE ITEMS: every Start Menu row that isn't one of the game's own can
  -- be hidden: POKEBOX, MODS, other mods' rows, and the shortcuts to mods'
  -- pages in the game's Options menu (remembered by core/hub.lua in
  -- option_rows). Everything shows until hidden. Per save:
  -- hidden = { [key] = true }, pokebox = false when hidden.
  ---------------------------------------------------------------------------
  local showEverything = false -- CUSTOM RENAME reads hidden rows too

  local function hiddenSet(game)
    local t = mine(game, "hidden")
    return type(t) == "table" and t or {}
  end
  local function setHidden(game, key, hide)
    local t = {}
    for k, v in pairs(hiddenSet(game)) do t[k] = v end
    t[key] = hide or nil
    setMine(game, "hidden", t)
  end
  pokeboxShown = function(game)
    return showEverything or mine(game, "pokebox") ~= false
  end

  -- The Options menu's rows, live (their activate functions can't be saved).
  local function liveOptionRows(game)
    local ok, Runtime = pcall(require, "src.mods.Runtime")
    if not (ok and type(Runtime) == "table" and type(Runtime.call) == "function") then
      return {}
    end
    local okCall, rows = pcall(Runtime.call, "ui.options.rows",
      function(_, r) return r end, game, {})
    return okCall and type(rows) == "table" and rows or {}
  end

  -- Each mod page in the Options menu as a Start Menu tile ("mod:opt:...").
  local function shortcutItems(game)
    local items = {}
    for _, r in ipairs(liveOptionRows(game)) do
      if type(r) == "table" and type(r.activate) == "function" then
        local label = tostring(r.label or r.id or "?")
        local row = r
        items[#items + 1] = {
          id = "opt:" .. tostring(r.id or label:upper()), label = label,
          keepOpen = true, onSelect = function() row.activate(game) end,
        }
      end
    end
    return items
  end

  -- Outermost link of the chain, so every mod's rows are already in.
  mod.hooks:wrap("ui.start_menu.items", function(next, game, items)
    items = next(game, items) or items or {}
    for _, extra in ipairs(shortcutItems(game)) do items[#items + 1] = extra end
    local rows = {}
    for _, item in ipairs(items) do
      if type(item) == "table" then
        rows[#rows + 1] = { key = E.keyOf(item, game), item = item }
      end
    end
    pcall(rememberModRows, rows, game)
    if showEverything then return items end
    local hide = hiddenSet(game)
    local out = {}
    for _, row in ipairs(rows) do
      if not hide[baseKey(row.key)] then out[#out + 1] = row.item end
    end
    return out
  end, 100000)

  local function optionShortcuts()
    local list = {}
    local options = get("option_rows")
    for _, r in ipairs(type(options) == "table" and options or {}) do
      if type(r) == "table" and r.key then
        list[#list + 1] = { key = "mod:" .. r.key, label = r.label }
      end
    end
    return list
  end

  local function byLabel(a, b)
    return tostring(a.label):upper() < tostring(b.label):upper()
  end

  local function hideRows(game)
    local rows = {}
    local function row(id, label, isHidden, flip)
      rows[#rows + 1] = {
        id = "hstart_hide." .. id,
        label = label,
        value = function() return isHidden() and "HIDE" or "SHOW" end,
        step = function(g)
          flip(g or game, not isHidden())
          return true
        end,
      }
    end
    row("pokebox", "POKEBOX",
      function() return mine(game, "pokebox") == false end,
      function(g, hide)
        if hide then setMine(g, "pokebox", false) else setMine(g, "pokebox", nil) end
      end)
    local function entry(key, label)
      row(key, label,
        function() return hiddenSet(game)[key] == true end,
        function(g, hide) setHidden(g, key, hide) end)
    end
    entry("mods", "MODS")
    for _, r in ipairs(modRows()) do entry(r.key, r.label) end
    for _, r in ipairs(optionShortcuts()) do entry(r.key, r.label) end
    table.sort(rows, byLabel)
    return rows
  end
  mod.exports.hideRows = hideRows

  ---------------------------------------------------------------------------
  -- CUSTOM RENAME: every row of the Start Menu (hidden ones included), each
  -- renamed with the game's own keyboard, up to 6 characters. Only the
  -- Start Menu tile changes. An empty name puts the usual one back.
  ---------------------------------------------------------------------------
  local MAX_NAME = 6

  local function allRows(game)
    showEverything = true
    local ok, rows = pcall(function()
      local gen2 = isGen2()
      local menu = require("src.ui.Screens").build(game,
        gen2 and "Gen2StartMenu" or "StartMenu", gen2 and { save = game.save } or nil)
      if type(menu) ~= "table" then return {} end
      return menu.hs and menu.hs.rows or E.sorted(menu.items or {}, order(game), game)
    end)
    showEverything = false
    return ok and rows or {}
  end

  local function openKeyboard(game, current, onDone)
    local Screens = require("src.ui.Screens")
    local Strings = require("src.core.Strings")
    if isGen2() then
      local naming
      local function close()
        if game.stack:top() == naming then game.stack:pop() end
      end
      naming = Screens.push(game, "Gen2NamingScreen", {
        type = "nickname", prompt = Strings("NAME?"), maxLength = MAX_NAME,
        initial = current, menuGfx = game.data and game.data.gen2MenuGfx,
        onDone = function(name) close(); onDone(name) end,
        onCancel = close,
      })
    else
      Screens.push(game, "NamingScreen", {
        title = Strings("NAME?"), maxLen = MAX_NAME,
        onDone = function(name) onDone(name) end,
      })
    end
  end

  local function renameRows(game)
    game = liveGame(game)
    local rows = {}
    if not (game and game.save) then return rows end
    local seen = {}
    for _, r in ipairs(allRows(game)) do
      local key = baseKey(r.key)
      if not r.gap and not seen[key] then
        seen[key] = true
        local label = Page.rowName({ key = key, item = r.item }, game)
        rows[#rows + 1] = {
          id = "hstart_name." .. key,
          label = label,
          value = function() return nameFor(key, game) or "----" end,
          activate = function(g)
            g = g or game
            openKeyboard(g, nameFor(key, g), function(name)
              if type(name) == "string" then
                setName(g, key, name)
              end
            end)
          end,
        }
      end
    end
    table.sort(rows, byLabel)
    return rows
  end
  mod.exports.renameRows = renameRows
  -- The names on the CUSTOM RENAME page are shown exactly as typed too.
  mod.exports.keepNames = function(game)
    local t = mine(game, "names")
    local keep = {}
    for _, v in pairs(type(t) == "table" and t or {}) do keep[v] = true end
    for _, v in pairs(DEFAULT_NAMES) do keep[v] = true end
    return keep
  end

  ---------------------------------------------------------------------------
  -- for the START sub-menu (core/hub.lua)
  ---------------------------------------------------------------------------
  mod.exports.customValue = function(game, key)
    if key == "colour" then return colourLabel(game) end
    if key == "clock" then return clockLabel() end
    return "----"
  end
  mod.exports.customStep = function(game, key, direction)
    if key == "colour" then return stepColour(game, direction) end
    if key == "clock" then return stepClock(game, direction) end
    return false
  end
  mod.exports.openCustomIcons = function(game) return CustomIcons.open(liveGame(game)) end
  mod.exports.openSort = function(game) return openSort(liveGame(game)) end
  mod.exports.palette = palette
  mod.log:info("Highlander Start Menu ready")
end
