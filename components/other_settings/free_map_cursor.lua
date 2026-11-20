-- Free map cursor: Start swaps the Town Map / Pokegear map / Fly map cursor
-- between the original list cursor (Up/Down step through places) and a free
-- cursor the d-pad moves anywhere.  The free cursor snaps to the nearest place
-- within SNAP_RADIUS, names it, and on a Fly map only snaps to places you can
-- fly to (A flies there).  Away from every place the name is cleared and A
-- does nothing.  The chosen mode is remembered (save flag + this session).
return function(mod)
  local FLAG = "HIGHLANDER_FREE_MAP_CURSOR"
  local SNAP_RADIUS = 8      -- pixels, about one map tile
  local session = nil        -- mode chosen this session (before any save)

  local function modeOn(game)
    if session ~= nil then return session end
    local flags = game and game.save and game.save.flags
    return type(flags) == "table" and flags[FLAG] == true
  end

  local function setMode(game, on)
    session = on and true or false
    local save = game and game.save
    if type(save) == "table" then
      if type(save.flags) ~= "table" then save.flags = {} end
      save.flags[FLAG] = on and true or nil
    end
  end

  -- Hands an update the real input minus the buttons the free cursor owns.
  local function filtered(real, hide)
    return setmetatable({
      wasPressed = function(_, btn)
        if hide[btn] then return false end
        return real:wasPressed(btn)
      end,
      isDown = function(_, btn)
        if hide[btn] then return false end
        return real:isDown(btn)
      end,
    }, {
      __index = function(_, k)
        local v = real[k]
        if type(v) == "function" then
          return function(_, ...) return v(real, ...) end
        end
        return v
      end,
    })
  end

  local function withInput(game, input, fn, ...)
    local real = game.input
    game.input = input
    local ok, a, b = pcall(fn, ...)
    game.input = real
    if not ok then error(a, 0) end
    return a, b
  end

  local DIRS = { up = true, down = true, left = true, right = true, start = true }
  local DIRS_A = { up = true, down = true, left = true, right = true,
                   start = true, a = true }

  -- Moves st.x/st.y with the held d-pad: 1px on the first frame (fine
  -- placement on a tap), 2px while held, 3px after half a second.
  local function move(st, input, minX, minY, maxX, maxY)
    local dx, dy = 0, 0
    if input:isDown("left") then dx = dx - 1 end
    if input:isDown("right") then dx = dx + 1 end
    if input:isDown("up") then dy = dy - 1 end
    if input:isDown("down") then dy = dy + 1 end
    if dx == 0 and dy == 0 then
      st.held = 0
      return
    end
    st.held = (st.held or 0) + 1
    local speed = st.held == 1 and 1 or (st.held > 30 and 3 or 2)
    st.x = math.max(minX, math.min(maxX, st.x + dx * speed))
    st.y = math.max(minY, math.min(maxY, st.y + dy * speed))
  end

  -- Nearest candidate within SNAP_RADIUS; candidates are { cx, cy } lists
  -- indexed like the caller's own list.
  local function nearest(st, points)
    local best, bestD = nil, SNAP_RADIUS * SNAP_RADIUS + 1
    for i, p in pairs(points) do
      local dx, dy = p[1] - st.x, p[2] - st.y
      local d = dx * dx + dy * dy
      if d < bestD then best, bestD = i, d end
    end
    return best
  end

  -- Corner brackets around (cx, cy), drawn in the darkest shade.
  local function bracket(cx, cy)
    local G = love.graphics
    local h, arm, t = 9, 5, 2
    local l, r = math.floor(cx - h), math.floor(cx + h - t)
    local top, bot = math.floor(cy - h), math.floor(cy + h - t)
    G.setColor(0, 0, 0, 1)
    -- top-left
    G.rectangle("fill", l, top, arm, t)
    G.rectangle("fill", l, top, t, arm)
    -- top-right
    G.rectangle("fill", r + t - arm, top, arm, t)
    G.rectangle("fill", r, top, t, arm)
    -- bottom-left
    G.rectangle("fill", l, bot, arm, t)
    G.rectangle("fill", l, bot + t - arm, t, arm)
    -- bottom-right
    G.rectangle("fill", r + t - arm, bot, arm, t)
    G.rectangle("fill", r, bot + t - arm, t, arm)
    G.setColor(1, 1, 1, 1)
  end

  -- A small drawn label font (3x5, M and W 5 wide) with a dark outline, so the
  -- button hints fit in a map corner without the game's 8px font.
  local GLYPHS = {
    A = { ".#.", "#.#", "###", "#.#", "#.#" },
    C = { ".##", "#..", "#..", "#..", ".##" },
    E = { "###", "#..", "##.", "#..", "###" },
    H = { "#.#", "#.#", "###", "#.#", "#.#" },
    I = { "###", ".#.", ".#.", ".#.", "###" },
    L = { "#..", "#..", "#..", "#..", "###" },
    M = { "#...#", "##.##", "#.#.#", "#...#", "#...#" },
    O = { ".#.", "#.#", "#.#", "#.#", ".#." },
    P = { "##.", "#.#", "##.", "#..", "#.." },
    R = { "##.", "#.#", "##.", "#.#", "#.#" },
    S = { ".##", "#..", ".#.", "..#", "##." },
    T = { "###", ".#.", ".#.", ".#.", ".#." },
    U = { "#.#", "#.#", "#.#", "#.#", "###" },
    W = { "#...#", "#...#", "#.#.#", "##.##", "#...#" },
    [":"] = { ".", "#", ".", "#", "." },
  }
  local LABEL_PITCH = 7

  local function labelPixels(text, x, y, fn)
    local pen = x
    for ch in tostring(text):upper():gmatch(".") do
      local g = GLYPHS[ch]
      if g then
        for row = 1, #g do
          local line = g[row]
          for col = 1, #line do
            if line:sub(col, col) == "#" then fn(pen + col - 1, y + row - 1) end
          end
        end
        pen = pen + #g[1] + 1
      else
        pen = pen + 2
      end
    end
  end

  local function drawLabels(lines, x, y, pitch)
    local G = love.graphics
    pitch = pitch or LABEL_PITCH
    G.setColor(0, 0, 0, 1)
    for i, s in ipairs(lines) do
      labelPixels(s, x, y + (i - 1) * pitch, function(px, py)
        G.rectangle("fill", px - 1, py - 1, 3, 3)
      end)
    end
    G.setColor(1, 1, 1, 1)
    for i, s in ipairs(lines) do
      labelPixels(s, x, y + (i - 1) * pitch, function(px, py)
        G.rectangle("fill", px, py, 1, 1)
      end)
    end
  end

  ---------------------------------------------------------------- Gen 1
  pcall(function()
    local TownMap = require("src.ui.TownMap")
    if type(TownMap) ~= "table" or TownMap._phFreeCursor then return end
    if type(TownMap.update) ~= "function" or type(TownMap.draw) ~= "function" then
      return
    end
    TownMap._phFreeCursor = true

    -- same transform as TownMap's markerXY, plus half a tile to the centre
    local function center(loc)
      return loc.x * 8 + 16 + 4, loc.y * 8 + 8 + 4
    end

    local function eligible(self)
      if self.nestSpecies or self.mode ~= "grid" or not self.bg then return false end
      local locs = self.locs
      if type(locs) ~= "table" or #locs == 0 then return false end
      for _, loc in ipairs(locs) do
        if not (loc.x and loc.y) then return false end
      end
      return true
    end

    local function state(self)
      local st = self.phFree
      if st then return st end
      st = { on = modeOn(self.game), held = 0 }
      local loc = self.locs[self.sel] or self.locs[1]
      st.x, st.y = center(loc)
      st.snap = self.sel
      self.phFree = st
      return st
    end

    local function snap(self, st)
      local points = {}
      for i, loc in ipairs(self.locs) do
        local x, y = center(loc)
        points[i] = { x, y }
      end
      st.snap = nearest(st, points)
    end

    local origUpdate = TownMap.update
    function TownMap.update(self, dt, ...)
      if not eligible(self) then return origUpdate(self, dt, ...) end
      local st = state(self)
      local input = self.game.input
      if input:wasPressed("start") then
        local on = not st.on
        st.on, st.held = on, 0
        setMode(self.game, on)
        if on then
          local loc = self.locs[self.sel] or self.locs[1]
          st.x, st.y = center(loc)
          st.snap = self.sel
        end
        pcall(function()
          require("src.core.Sound").play(self.game.data, "Press_AB")
        end)
      end
      if not st.on then
        return withInput(self.game, filtered(input, { start = true }),
          origUpdate, self, dt, ...)
      end
      move(st, input, 0, 8, 159, 143)
      snap(self, st)
      if st.snap then self.sel = st.snap end
      return withInput(self.game,
        filtered(input, st.snap and DIRS or DIRS_A), origUpdate, self, dt, ...)
    end

    local function noop() end

    local function drawHint()
      drawLabels({ "START:", "SWITCH CURSOR" }, 2, 11)
    end

    local origDraw = TownMap.draw
    function TownMap.draw(self, ...)
      if not eligible(self) then return origDraw(self, ...) end
      local st = state(self)
      if not st.on then
        origDraw(self, ...)
        drawHint(self, st)
        return
      end
      local sel, blink = self.sel, self.blink
      -- the blinking list cursor is replaced by the bracket; the Fly bird stays
      -- on the snapped town as the "you'll land here" marker
      self.sel = st.snap or 0
      if not self.fly then self.blink = 31 end
      self.drawFlyArrows = noop
      local ok, err = pcall(origDraw, self, ...)
      self.sel, self.blink = sel, blink
      self.drawFlyArrows = nil
      if not ok then error(err, 0) end
      local loc = st.snap and self.locs[st.snap]
      if loc then
        bracket(center(loc))
      else
        bracket(st.x, st.y)
      end
      drawHint(self, st)
    end
  end)

  ---------------------------------------------------------------- Gen 2
  pcall(function()
    local Pokegear = require("src.ui.gen2.Pokegear")
    if type(Pokegear) ~= "table" or Pokegear._phFreeCursor then return end
    if type(Pokegear.update) ~= "function" or type(Pokegear.drawMap) ~= "function" then
      return
    end
    Pokegear._phFreeCursor = true

    local function byIndex(self)
      local out = {}
      for _, e in pairs((self.landmarks or {}).landmarks or {}) do
        if type(e) == "table" and e.index then out[e.index] = e end
      end
      return out
    end

    local function onMap(self)
      if self.fly then return #self.fly > 0 end
      if self.townMap then return true end
      if self.mode ~= "card" then return false end
      local card = type(self.card) == "function" and self:card() or nil
      return type(card) == "table" and card.id == "map"
    end

    -- Candidate points keyed like the list the old cursor walks: Fly rows by
    -- row number, the map card's landmarks by landmark index.
    local function points(self)
      local idx = byIndex(self)
      local out = {}
      if self.fly then
        for i, row in ipairs(self.fly) do
          local e = row.index and idx[row.index]
          if e and e.x and e.y then out[i] = { e.x, e.y } end
        end
        return out
      end
      -- The whole region the map is showing.  The list cursor's limits keep
      -- Kanto down to the 7 landmarks around Victory Road until the Hall of
      -- Fame; the free cursor can point anywhere on the map you can see.
      local region = self.phRegion
      if region ~= "johto" and region ~= "kanto" then
        local okR, r = pcall(self.region, self)
        region = okR and r or "johto"
      end
      local okL, first, last = pcall(function()
        if region == "kanto" then
          return self:landmarkIndex("PALLET_TOWN"), self:landmarkIndex("ROUTE_28")
        end
        return self:landmarkIndex("NEW_BARK_TOWN"), self:landmarkIndex("SILVER_CAVE")
      end)
      if not okL then
        local ok, l, f = pcall(self.cursorLimits, self)
        if not ok then return out end
        first, last = f, l
      end
      for i = first, last do
        local e = idx[i]
        if e and e.x and e.y then out[i] = { e.x, e.y } end
      end
      return out
    end

    local function state(self)
      local st = self.phFree
      if st then return st end
      st = { on = modeOn(self.game), held = 0 }
      local ok, cur = pcall(self.mapLandmark, self)
      if ok and type(cur) == "table" and cur.x and cur.y then
        st.x, st.y = cur.x, cur.y
      else
        st.x, st.y = 80, 84
      end
      self.phFree = st
      return st
    end

    local function snap(self, st)
      st.snap = nearest(st, points(self))
      if not st.snap then return end
      if self.fly then
        self.flyIndex = st.snap
      else
        self.mapCursor = st.snap
      end
    end

    local origUpdate = Pokegear.update
    function Pokegear:update(...)
      local input = self.game and self.game.input
      if not (input and onMap(self)) then return origUpdate(self, ...) end
      local st = state(self)
      if input:wasPressed("start") then
        local on = not st.on
        st.on, st.held = on, 0
        setMode(self.game, on)
        if on then
          local ok, cur = pcall(self.mapLandmark, self)
          if ok and type(cur) == "table" and cur.x and cur.y then
            st.x, st.y = cur.x, cur.y
          end
        end
      end
      if not st.on then
        return withInput(self.game, filtered(input, { start = true }),
          origUpdate, self, ...)
      end
      move(st, input, 2, 26, 157, 141)
      snap(self, st)
      local hide = DIRS
      if self.fly and not st.snap then hide = DIRS_A end
      return withInput(self.game, filtered(input, hide), origUpdate, self, ...)
    end

    local function none() return nil end
    local function noop() end

    local function drawHint(self)
      local lines = { "START:", "SWITCH CURSOR" }
      local unlocked = Pokegear._phKantoUnlocked
      if type(unlocked) == "function" then
        local ok, yes = pcall(unlocked, self.game and self.game.save)
        if ok and yes then
          lines = { "SELECT:", "SWITCH MAP", "START:", "SWITCH CURSOR" }
        end
      end
      -- Inside the map, on the empty terrain of its top-left corner. Johto's
      -- corner is clear down to Routes 38/39. Kanto's ends at the top of
      -- Indigo Plateau's road (y 32), so its lines sit 6px apart to fit.
      local region = (self.fly and self.flyRegion) or self.phRegion
      if not region then
        local ok, r = pcall(self.region, self)
        region = ok and r or nil
      end
      if region == "kanto" then
        drawLabels(lines, 10, 8, 6)
      else
        drawLabels(lines, 10, 10)
      end
    end

    local origDrawMap = Pokegear.drawMap
    function Pokegear:drawMap(...)
      local st = self.phFree
      if not (st and onMap(self)) then return origDrawMap(self, ...) end
      if not st.on then
        origDrawMap(self, ...)
        drawHint(self, st)
        return
      end
      local classTile = Pokegear.tile
      -- the ▲▼ scroller says "Up/Down steps"; hide it while the cursor is free
      self.tile = function(s, id, tx, ty, ...)
        if id == 0x34 and ((tx == 8 and ty == 0) or (tx == 18 and ty == 1)) then
          return
        end
        return classTile(s, id, tx, ty, ...)
      end
      self.mapCursorSprite = noop
      if not st.snap then
        self.mapLandmark = none
        self.flyRow = none
      end
      local ok, err = pcall(origDrawMap, self, ...)
      self.tile, self.mapCursorSprite = nil, nil
      self.mapLandmark, self.flyRow = nil, nil
      if not ok then error(err, 0) end
      -- cover the scroller cell too, whatever drew it
      if self.fly then
        self:drawPlate(18, 1, 1, 1)
      else
        self:drawPlate(8, 0, 1, 1)
      end
      local pts = st.snap and points(self) or nil
      local p = pts and pts[st.snap]
      if p then
        bracket(p[1], p[2])
      else
        bracket(st.x, st.y)
      end
      drawHint(self, st)
    end
  end)
end
