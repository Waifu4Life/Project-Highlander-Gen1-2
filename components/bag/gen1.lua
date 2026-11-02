-- Highlander Bag, Gen 1: Gold/Silver/Crystal's PACK screen for Red, Blue,
-- Yellow and Green, drawn entirely by this file.
--
-- The game's own Bag stays underneath: every A press goes to its own
-- onChoose, so USE / TOSS, battle use, ball throws, TMs/HMs, the BICYCLE,
-- rods and the rest behave exactly as before. This file only decides what
-- the list shows (one pocket at a time) and draws the screen:
--
--   row 0       ◀▶ POCKET ▼▲ ITEMS  Start:Sort
--   row 1       money                  rows 2-11  the item list, 5 items
--   rows 3-5    the bag picture         (name, then ×count on the next row)
--   rows 7-9    the pocket plaque       rows 12-17 the description
--   row 11      used/255
--
-- LEFT/RIGHT change pocket, SELECT moves an item (not in TM/HM), START
-- opens SORT BY. Graphics: assets/bag_gen1.png (taken from Crystal's PACK).
return function(mod, C)
  local Bag = require("src.inventory.Bag")
  local Font = require("src.render.Font")
  local MenuRepeat = require("src.ui.MenuRepeat")
  local Strings = require("src.core.Strings")
  local G = love.graphics

  local DESCRIPTIONS = {}
  pcall(function() DESCRIPTIONS = mod:load("descriptions.lua") or {} end)

  local POCKETS = { "ITEMS", "BALLS", "KEY ITEMS", "TM/HM" }
  local ITEMS, BALLS, KEY, MACHINES = 1, 2, 3, 4
  local VISIBLE = 5
  local LIST_DIRS = { "up", "down" }

  ---------------------------------------------------------------- graphics
  local sheet
  local function image()
    if sheet ~= nil then return sheet or nil end
    local img
    pcall(function() img = mod.assets:image("assets/bag_gen1.png") end)
    if not img then
      pcall(function()
        local bytes = mod:read("assets/bag_gen1.png")
        img = G.newImage(love.filesystem.newFileData(bytes, "bag_gen1.png"))
      end)
    end
    if img then pcall(img.setFilter, img, "nearest", "nearest") end
    sheet = img or false
    return img
  end

  local quads = {}
  local function piece(x, y, w, h, dx, dy)
    local img = image()
    if not img then return end
    local key = x .. ":" .. y .. ":" .. w .. ":" .. h
    local q = quads[key]
    if not q then
      local iw, ih = img:getDimensions()
      q = G.newQuad(x, y, w, h, iw, ih)
      quads[key] = q
    end
    G.setColor(1, 1, 1, 1)
    G.draw(img, q, dx, dy)
  end
  local function tile(n, tx, ty) piece(n * 8, 8, 8, 8, tx * 8, ty * 8) end
  local CHECKER, CURSOR, HOLLOW = 0, 1, 2
  local TL, T, TR, L, R, BL, B, BR = 3, 4, 5, 6, 7, 8, 9, 10

  -- A Crystal text box: border tiles round a white inside.
  local function box(tx, ty, tw, th)
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", tx * 8, ty * 8, tw * 8, th * 8)
    local right, bottom = tx + tw - 1, ty + th - 1
    tile(TL, tx, ty); tile(TR, right, ty)
    tile(BL, tx, bottom); tile(BR, right, bottom)
    for x = tx + 1, right - 1 do tile(T, x, ty); tile(B, x, bottom) end
    for y = ty + 1, bottom - 1 do tile(L, tx, y); tile(R, right, y) end
  end

  local function text(s, x, y)
    G.setColor(0, 0, 0, 1)
    Font.draw(s, x, y)
  end

  ------------------------------------------------------------------- sound
  local function beep(game)
    local data = game and game.data
    if not data then return end
    pcall(function() require("src.core.Sound").play(data, "Press_AB") end)
  end

  -- Gen 1 has no pocket click: Crystal's own, from the mod's folder.
  local function pocketSound(game)
    local data = game and game.data
    if not data then return end
    local ok, Sound = pcall(require, "src.core.Sound")
    if not ok then return end
    data.audio = data.audio or {}
    data.audio.sfx = data.audio.sfx or {}
    local function try(id)
      local src
      local played = pcall(function() src = Sound.play(data, id) end)
      return played and src ~= nil
    end
    if try("Sfx_SwitchPockets") then return end
    data.audio.sfx.Sfx_SwitchPockets = { file = (mod.path or ".") .. "/assets/switch_pockets.wav" }
    if try("Sfx_SwitchPockets") then return end
    pcall(function()
      local src = love.audio.newSource((mod.path or ".") .. "/assets/switch_pockets.wav", "static")
      src:setVolume(0.7)
      src:play()
    end)
  end

  ------------------------------------------------------------- the pockets
  local function pocketOf(game, id)
    local def = game.data.items[id]
    if (def and def.machine) or id:find("^TM_") or id:find("^HM_") then return MACHINES end
    if def and def.keyItem then return KEY end
    local okE, ItemEffects = pcall(require, "src.inventory.ItemEffects")
    if okE and ItemEffects.isBall and ItemEffects.isBall(id) then return BALLS end
    return ITEMS
  end

  local function moveName(game, moveId)
    local mv = game.data.moves and game.data.moves[moveId]
    return (mv and mv.name) or tostring(moveId or ""):gsub("_", " ")
  end

  local function buildRows(self)
    local game = self.game
    local data = game.data
    local rows = {}
    for _, r in ipairs(Bag.rows(game.save, data)) do
      local id = r.id
      if not Bag.isBadge(id) and pocketOf(game, id) == self.hbPocket then
        local def = data.items[id]
        local machine = def and def.machine
        local hm = id:find("^HM_") ~= nil or (machine and machine.kind == "HM")
        -- the game's own rows: value / label / count / slot / stack
        local row = { value = id, label = (def and def.name) or id,
          slot = r.slot, stack = r.count }
        -- no ×count on key items and HMs, like both games
        if not ((def and def.keyItem) or hm) then row.count = r.count end
        if machine then
          local n = tonumber(machine.number) or 0
          row.display = moveName(game, machine.move)
          row.tmLabel = hm and ("H" .. n) or ("%02d"):format(n)
          row.tmNumber = (hm and 100 or 0) + n
        end
        rows[#rows + 1] = row
      end
    end
    if self.hbPocket == MACHINES then
      C.sortMachines(rows, function(r) return r.tmNumber end,
        function(r) return r.display end, game.save)
    end
    rows[#rows + 1] = { cancel = true, label = Strings("CANCEL") }
    return rows
  end

  local function ensureVisible(self)
    local n = #self.items
    if self.index <= self.scroll then
      self.scroll = self.index - 1
    elseif self.index > self.scroll + VISIBLE then
      self.scroll = self.index - VISIBLE
    end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, n - VISIBLE)))
  end

  local function rebuild(self, keepId, fallback)
    local rows = buildRows(self)
    self.hbRows, self.items = rows, rows
    local index
    if keepId then
      for i, row in ipairs(rows) do
        if row.value == keepId then index = i break end
      end
    end
    self.index = math.max(1, math.min(index or fallback or self.index or 1, #rows))
    ensureVisible(self)
  end

  -- cursor and scroll per pocket, for the session (like Gen 2's PACK)
  local function memory(game)
    game.hbBagCursor = game.hbBagCursor or { pocket = ITEMS, index = {}, scroll = {} }
    return game.hbBagCursor
  end
  local function remember(self)
    local mem = memory(self.game)
    mem.pocket = self.hbPocket
    C.setLastPocket(self.game.save, self.hbPocket)
    mem.index[self.hbPocket], mem.scroll[self.hbPocket] = self.index, self.scroll
  end

  local function switchPocket(self, delta)
    remember(self)
    self.hbPocket = (self.hbPocket - 1 + delta) % #POCKETS + 1
    local mem = memory(self.game)
    self.index = mem.index[self.hbPocket] or 1
    self.scroll = mem.scroll[self.hbPocket] or 0
    rebuild(self)
    remember(self)
    pocketSound(self.game)
  end

  local function stepCursor(self, delta, edge)
    local n = #self.items
    local nextIndex = self.index + delta
    if nextIndex < 1 then nextIndex = edge and n or 1
    elseif nextIndex > n then nextIndex = edge and 1 or n end
    self.index = nextIndex
    ensureVisible(self)
  end

  local function inThisPocket(self)
    local game = self.game
    return function(id) return pocketOf(game, id) == self.hbPocket end
  end

  ------------------------------------------------------------------ SELECT
  local function placeMove(self)
    local from = self.hbMove
    self.hbMove = nil
    local row = self.items[from]
    if not row or row.cancel then return end
    local to = self.index
    if self.items[to] and self.items[to].cancel then to = to - 1 end
    if to ~= from then
      C.movePocketRow(self.game.save, self.game.data, inThisPocket(self), from, to)
      rebuild(self, nil, to)
      pcall(function() require("src.core.Sound").play(self.game.data, "Swap") end)
    end
  end

  -------------------------------------------------------------------- SORT
  local function applySort(self, choice)
    local game = self.game
    local selected = self.items[self.index]
    if self.hbPocket == MACHINES then
      C.setTmSort(game.save, choice.kind, choice.descending)
    else
      C.sortPocket(game.save, game.data, inThisPocket(self), function(id)
        local def = game.data.items[id]
        return def and def.name or id
      end, choice.kind, choice.descending)
    end
    rebuild(self, selected and not selected.cancel and selected.value or nil)
  end

  local function updateSort(self, input)
    local sort = self.hbSort
    local n = #C.SORT_CHOICES
    if input:wasPressed("up") then
      sort.index = sort.index > 1 and sort.index - 1 or n
    elseif input:wasPressed("down") then
      sort.index = sort.index < n and sort.index + 1 or 1
    elseif input:wasPressed("a") then
      beep(self.game)
      self.hbSort = nil
      applySort(self, C.SORT_CHOICES[sort.index])
    elseif input:wasPressed("b") or input:wasPressed("start") then
      beep(self.game)
      self.hbSort = nil
    end
  end

  ------------------------------------------------------------------ update
  local function update(self)
    self.optionBox = nil
    self.hollowIndex = nil
    if self.items ~= self.hbRows then
      -- the game rebuilt its full list after an item was used or tossed
      rebuild(self, self.hbLastId, self.hbLastIndex)
    end
    local input = self.game.input
    if not input then return end
    if self.hbSort then return updateSort(self, input) end

    local dir, edge = MenuRepeat.direction(self.hbHold, input, LIST_DIRS)
    if self.hbMove then
      if dir == "up" then stepCursor(self, -1, edge)
      elseif dir == "down" then stepCursor(self, 1, edge)
      elseif input:wasPressed("a") or input:wasPressed("select") then placeMove(self)
      elseif input:wasPressed("b") then self.hbMove = nil end
      return
    end

    if input:wasPressed("left") then
      switchPocket(self, -1)
    elseif input:wasPressed("right") then
      switchPocket(self, 1)
    elseif dir == "up" then
      stepCursor(self, -1, edge)
    elseif dir == "down" then
      stepCursor(self, 1, edge)
    elseif input:wasPressed("start") then
      beep(self.game)
      self.hbSort = { index = 1 }
    elseif input:wasPressed("select") then
      local row = self.items[self.index]
      if self.hbPocket ~= MACHINES and row and not row.cancel then
        self.hbMove = self.index
      end
    elseif input:wasPressed("b") then
      beep(self.game)
      remember(self)
      self.game.stack:pop()
      if self.onCancel then self.onCancel() end
      return
    elseif input:wasPressed("a") then
      beep(self.game)
      remember(self)
      local item = self.items[self.index]
      self.hbLastId = item and item.value
      self.hbLastIndex = self.index
      if self.onChoose then self.onChoose(item, self) end
      return
    end
    remember(self)
  end

  -------------------------------------------------------------------- draw
  -- Gen 1 TMs/HMs show their move's description (the Highlander Party's
  -- Gen 1 list, Crystal's wording).
  local moveDescs
  local function clean(s) return (tostring(s or ""):upper():gsub("[^A-Z0-9]", "")) end
  local function moveDescription(game, moveId)
    local mv = game.data.moves and game.data.moves[moveId]
    if mv and type(mv.description) == "string" and mv.description ~= "" then
      return mv.description
    end
    if not moveDescs then
      moveDescs = {}
      pcall(function()
        local party = mod.find("highlander_party")
        local source = party and party:read("move_descriptions.lua")
        local list = source and load(source)()
        for _, row in pairs(list or {}) do
          local t = row.gen1 or row.text
          if row.id then moveDescs[clean(row.id)] = t end
          if row.name then moveDescs[clean(row.name)] = t end
        end
      end)
    end
    return moveDescs[clean(moveId)] or (mv and moveDescs[clean(mv.name)]) or ""
  end

  local function description(self)
    if self.hbMove then return "Where should this<NEXT>be moved to?" end
    local row = self.items[self.index]
    if not row or row.cancel then return nil end
    local game = self.game
    local def = game.data.items[row.value]
    if def and def.machine then return moveDescription(game, def.machine.move) end
    if def and type(def.description) == "string" and def.description ~= ""
        and def.description ~= "?" then
      return def.description
    end
    return DESCRIPTIONS[row.value]
  end

  local function drawCursor(n, tx, ty) tile(n, tx, ty) end

  local function draw(self)
    local game = self.game
    if game.stack:top() == self then
      self.optionBox = nil
      self.hollowIndex = nil
    end
    G.push("all")
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, 160, 144)
    local ok, err = pcall(function()
      -- header
      piece(0, 0, 160, 8, 0, 0)
      C.drawStartSort(C.HEADER_TEXT_X, 0)
      -- left column: checker, bag picture, plaque
      for _, ty in ipairs({ 2, 6, 10 }) do
        for tx = 0, 4 do tile(CHECKER, tx, ty) end
      end
      local p = self.hbPocket
      piece((p - 1) * 40, 16, 40, 24, 0, 24)
      piece((p - 1) * 40, 40, 40, 24, 0, 56)
      text(C.money(game.save), 0, 8)
      text(C.counter(game.save, game.data, nil), 0, 88)

      -- the list
      local picked = (self.hollowIndex ~= nil) or (self.optionBox ~= nil)
        or (game.stack:top() ~= self) or (self.hbSort ~= nil)
      for r = 1, VISIBLE do
        local i = self.scroll + r
        local row = self.items[i]
        if not row then break end
        local y = (2 + (r - 1) * 2) * 8
        if row.tmLabel then text(row.tmLabel, 40, y) end
        if i == self.index then
          drawCursor(picked and HOLLOW or CURSOR, 7, y / 8)
        elseif i == self.hbMove then
          drawCursor(HOLLOW, 7, y / 8)
        end
        text(row.display or row.label, 64, y)
        if row.count then
          local digits = tostring(row.count)
          local dx = 160 - Font.width(digits)
          text(digits, dx, y + 8)
          text("\xc3\x97", math.min(136, dx - 8), y + 8)
        end
      end

      -- the description
      box(0, 12, 20, 6)
      local desc = description(self)
      if desc and desc ~= "" then
        local first, second = desc:match("^(.-)<NEXT>(.*)$")
        if not first then first, second = desc:match("^(.-)\n(.*)$") end
        text(first or desc, 8, 112)
        if second then text(second, 8, 128) end
      end

      -- SORT BY
      if self.hbSort then
        local b = C.SORT_BOX
        box(b.tx, b.ty, b.tw, b.th)
        text(Strings("SORT BY"), (b.tx + 2) * 8, (b.ty + 1) * 8)
        for i, choice in ipairs(C.SORT_CHOICES) do
          local ty = b.ty + 1 + i * 2
          if i == self.hbSort.index then drawCursor(CURSOR, b.tx + 1, ty) end
          text(Strings(choice.label), (b.tx + 2) * 8, ty * 8)
        end
      end
    end)
    if not ok and not mod._hbDrawWarned then
      mod._hbDrawWarned = true
      mod.log:warn("bag draw: %s", tostring(err))
    end
    G.pop()
    -- USE / TOSS stays up while its choice runs (start_sub_menus.asm:298)
    if self.optionBox and game.stack:top() ~= self.optionBox then
      self.optionBox:draw()
    end
    G.setColor(1, 1, 1, 1)
  end

  ---------------------------------------------------------------- decorate
  local H = {}

  function H.decorate(list)
    if type(list) ~= "table" or type(list.items) ~= "table"
        or type(list.onChoose) ~= "function" or list.highlanderBag then
      return list
    end
    local game = list.game
    if not (game and game.save and game.data) then return list end
    list.highlanderBag = true
    list.isOpaque = true
    list.uiShiftRight = nil
    list.itemBox = false
    list.swapIndex = nil
    list.sgbPalettes = function()
      local okP, PaletteFX = pcall(require, "src.render.PaletteFX")
      if not okP then return nil end
      return { PaletteFX.zone(false, 0, 0, 19, 17) }
    end
    list.hbHold = MenuRepeat.new(MenuRepeat.GEN2_DELAY, MenuRepeat.GEN2_RATE)
    local mem = memory(game)
    -- HIGHLANDER BAG: a default pocket, or the last one opened
    list.hbPocket = C.defaultPocket() or C.lastPocket(game.save) or mem.pocket or ITEMS
    list.index = mem.index[list.hbPocket] or 1
    list.scroll = mem.scroll[list.hbPocket] or 0
    rebuild(list)
    list.update = update
    list.draw = draw
    return list
  end

  return H
end
