-- Highlander Bag, Gen 2: the game's own PACK (Gold/Silver/Crystal), with
--   * money on row 1 and the bag's used/255 on row 11 of the left column
--   * ▼▲ ITEMS moved four tiles left and "Start:Sort" beside it
--   * START opening SORT BY (this pocket only; the TM/HM pocket's choice is
--     kept per save)
--   * three-digit counts (stacks up to 999)
-- Everything else -- USE / GIVE / TOSS / SEL, SELECT's move, battle use,
-- teaching TMs, the item PC and the mart -- is the game's own.
return function(mod, C)
  local Bag = require("src.inventory.Bag")
  local Chrome = require("src.ui.gen2.Chrome")
  local GbcPalette = require("src.render.GbcPalette")
  local Strings = require("src.core.Strings")
  local G = love.graphics

  local PAL = function() return Chrome.DEFAULT_BOX_PALETTE end
  local VISIBLE_ROWS, LIST_SPACING = 5, 2

  ------------------------------------------------------------------ header
  -- One header tile, from column `src` of the strip, drawn at `dst` with
  -- the colours it has at its own place.
  local function headerTile(gfx, src, dst)
    local img = gfx:image("menu")
    if not img then return end
    local first = gfx.gfx.headerFirstTile or 0x28
    local q = gfx:quad(img, gfx.gfx.menuTilesWide or 16, first + src)
    local colors = gfx:colorsAt(src, 0)
    G.setColor(1, 1, 1, 1)
    local function body() G.draw(img, q, dst * 8, 0) end
    if colors and GbcPalette.available() then GbcPalette.with(colors, body) else body() end
  end

  local function patchChrome(menu, gfx, pocketId)
    -- ▼▲ ITEMS (columns 10-15) four tiles left, then blank to the end
    for col = 6, 11 do headerTile(gfx, col + 4, col) end
    for col = 12, 19 do headerTile(gfx, 19, col) end
    if not menu.tutorial then C.drawStartSort(C.HEADER_TEXT_X, 0) end
    -- money on row 1, the counter on row 11 (the checker stays on 2/6/10)
    Chrome.paletteFill(0, 8, 40, 8, PAL())
    Chrome.paletteFill(0, 88, 40, 8, PAL())
    Chrome.printThrough(C.money(menu.save), 0, 1, PAL())
    Chrome.printThrough(C.counter(menu.save, menu.bagData, pocketId), 0, 11, PAL())
  end

  -------------------------------------------------------------------- list
  -- The game's own drawList, with room for a three-digit count.
  local function drawList(self, listX, listY)
    local picked = not self.switching
      and (self.submenu or self.qtyState or self.confirm or self.message
        or self.hbSort) and true or false
    for row = 1, VISIBLE_ROWS do
      local i = row + self.scroll
      local ty = listY + (row - 1) * LIST_SPACING
      if i <= #self.rows then
        local entry = self.rows[i]
        if entry.tmhmLabel then
          Chrome.printThrough(entry.tmhmLabel, listX - 3, ty, PAL())
        end
        if i == self.index then
          self:cursorAt(listX - 1, ty, picked)
        elseif i == self.switching then
          self:cursorAt(listX - 1, ty, true)
        end
        Chrome.printThrough((entry.tmhmLabel and entry.teaches) or entry.name,
          listX, ty, PAL())
        if entry.showCount then
          local count = math.floor(tonumber(entry.count) or 0)
          local wide = count > 99
          Chrome.printThrough("\xc3\x97" .. Chrome.number(count, wide and 3 or 2),
            listX + (wide and 8 or 9), ty + 1, PAL())
        end
      elseif i == self:total() then
        if i == self.index then self:cursorAt(listX - 1, ty, picked) end
        Chrome.printThrough(Strings("CANCEL"), listX, ty, PAL())
      end
    end
  end

  local function drawQuantity(self)
    local qty = self.qtyState.qty
    if (self.qtyState.max or 0) > 99 then
      Chrome.box(14, 9, 6, 3)
      Chrome.printThrough("\xc3\x97" .. Chrome.number(qty, 3, true), 15, 10, PAL())
    else
      Chrome.box(15, 9, 5, 3)
      Chrome.printThrough("\xc3\x97" .. Chrome.number(qty, 2, true), 16, 10, PAL())
    end
  end

  -------------------------------------------------------------------- SORT
  local function selectedId(menu)
    local row = menu.rows and menu.rows[menu.index]
    return row and row.id or nil
  end

  local function selectId(menu, id)
    if not id then return end
    for i, row in ipairs(menu.rows or {}) do
      if row.id == id then menu.index = i break end
    end
    if menu.ensureVisible then menu:ensureVisible() end
  end

  local function applySort(menu, choice)
    local pocket = menu:pocket().id
    local keep = selectedId(menu)
    if pocket == "TM_HM" then
      C.setTmSort(menu.save, choice.kind, choice.descending)
    else
      C.sortPocket(menu.save, menu.bagData, function(id)
        return menu:pocketOf(id) == pocket
      end, function(id)
        local def = menu.items and menu.items[id]
        return (def and def.name) or id
      end, choice.kind, choice.descending)
    end
    menu:rebuild()
    selectId(menu, keep)
    if menu.storeCursor then menu:storeCursor() end
  end

  local function updateSort(menu, input)
    local sort = menu.hbSort
    local n = #C.SORT_CHOICES
    if input:wasPressed("up") then
      sort.index = sort.index > 1 and sort.index - 1 or n
    elseif input:wasPressed("down") then
      sort.index = sort.index < n and sort.index + 1 or 1
    elseif input:wasPressed("a") then
      menu:playSfx("Sfx_ReadText2")
      menu.hbSort = nil
      applySort(menu, C.SORT_CHOICES[sort.index])
    elseif input:wasPressed("b") or input:wasPressed("start") then
      menu:playSfx("Sfx_ReadText2")
      menu.hbSort = nil
    end
  end

  local function drawSort(menu)
    local b = C.SORT_BOX
    Chrome.box(b.tx, b.ty, b.tw, b.th)
    Chrome.printThrough(Strings("SORT BY"), b.tx + 2, b.ty + 1, PAL())
    for i, choice in ipairs(C.SORT_CHOICES) do
      local ty = b.ty + 1 + i * 2
      if i == menu.hbSort.index then Chrome.cursorThrough(b.tx + 1, ty, PAL()) end
      Chrome.printThrough(Strings(choice.label), b.tx + 2, ty, PAL())
    end
  end

  ---------------------------------------------------------------- decorate
  local H = {}

  local POCKET_IDS = { "ITEM", "BALL", "KEY_ITEM", "TM_HM" }
  local POCKET_NUMBER = { ITEM = 1, BALL = 2, KEY_ITEM = 3, TM_HM = 4 }

  -- HIGHLANDER BAG: open on a default pocket, or on the last one opened
  -- (kept in the save). A caller that asks for a pocket itself (the item
  -- PC's DEPOSIT, the mart's SELL) keeps it.
  local function openOn(menu, opts)
    if type(opts) == "table" and opts.pocket then return end
    local wanted = C.defaultPocket() or C.lastPocket(menu.save)
    local id = wanted and POCKET_IDS[wanted]
    if not id or menu:pocket().id == id then return end
    for i, pocket in ipairs(menu.POCKETS or require("src.ui.gen2.PackMenu").POCKETS or {}) do
      if pocket.id == id then
        menu.pocketIndex = i
        if menu.restoreCursor then menu:restoreCursor() end
        return
      end
    end
  end

  function H.decorate(menu, opts)
    if type(menu) ~= "table" or menu.highlanderBag
        or type(menu.rebuild) ~= "function" or type(menu.pocket) ~= "function" then
      return menu
    end
    menu.highlanderBag = true
    pcall(openOn, menu, opts)

    -- every pocket change / close / use goes through storeCursor
    local baseStore = menu.storeCursor
    if type(baseStore) == "function" then
      menu.storeCursor = function(self, ...)
        local n = POCKET_NUMBER[self:pocket().id]
        if n then C.setLastPocket(self.save, n) end
        return baseStore(self, ...)
      end
    end

    -- TM/HM pocket: the game sorts by number; apply a Names / DESC choice.
    local baseRebuild = menu.rebuild
    menu.rebuild = function(self, ...)
      local keep = selectedId(self)
      baseRebuild(self, ...)
      if self:pocket().id == "TM_HM" then
        local kind, descending = C.tmSort(self.save)
        if kind ~= "category" or descending then
          C.sortMachines(self.rows, function(r) return self:tmhmKey(r.id) end,
            function(r) return r.teaches or r.name end, self.save)
          selectId(self, keep)
        end
      end
    end
    pcall(menu.rebuild, menu)

    local baseUpdate = menu.update
    menu.update = function(self, dt)
      local input = self.game and self.game.input
      if input and self.hbSort then return updateSort(self, input) end
      if input and not self.tutorial and input:wasPressed("start")
          and not (self.message or self.confirm or self.submenu
            or self.qtyState or self.switching or self.repeatSfx) then
        self:playSfx("Sfx_ReadText2")
        self.hbSort = { index = 1 }
        return
      end
      return baseUpdate(self, dt)
    end

    menu.drawList = drawList
    menu.drawQuantity = drawQuantity
    local baseOverlays = menu.drawOverlays
    menu.drawOverlays = function(self, ...)
      baseOverlays(self, ...)
      if self.hbSort then drawSort(self) end
    end

    -- the PACK's tiles: draw them, then our changes on top
    local gfx = menu.gfx
    if type(gfx) == "table" and type(gfx.draw) == "function" then
      local baseDraw = gfx.draw
      gfx.draw = function(g, pocketId, ...)
        baseDraw(g, pocketId, ...)
        local ok, err = pcall(patchChrome, menu, g, pocketId)
        if not ok and not mod._hbGen2Warned then
          mod._hbGen2Warned = true
          mod.log:warn("pack header: %s", tostring(err))
        end
      end
    end
    return menu
  end

  return H
end
