-- Highlander Bag (Project Highlander Gen1+2): what both generations share.
--
--   * the SORT menu's choices and its rules (Category / Names, per pocket)
--   * the TM/HM pocket's sort, kept per save
--   * the small "Start:Sort" lettering in the header
--   * Gen 1 item descriptions (Gen 2 carries its own)
return function(mod)
  local Bag = require("src.inventory.Bag")
  local G = love.graphics
  local C = {}

  C.SORT_CHOICES = {
    { label = "CATEGORY ASC", kind = "category" },
    { label = "CATEGORY DESC", kind = "category", descending = true },
    { label = "NAMES A-Z", kind = "name" },
    { label = "NAMES Z-A", kind = "name", descending = true },
  }
  -- the SORT box, in tiles: title on row 2, choices on rows 4/6/8/10
  C.SORT_BOX = { tx = 4, ty = 1, tw = 16, th = 11 }

  ---------------------------------------------------------------------------
  -- Category rules: the group an item belongs to, then its place in the
  -- group. Anything not listed comes after, alphabetically.
  ---------------------------------------------------------------------------
  local priority = {}
  local groups = {
    { "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL",
      "LEVEL_BALL", "LURE_BALL", "MOON_BALL", "FRIEND_BALL", "FAST_BALL",
      "HEAVY_BALL", "LOVE_BALL", "PARK_BALL" },
    { "POTION", "SUPER_POTION", "HYPER_POTION", "MAX_POTION", "FRESH_WATER",
      "SODA_POP", "LEMONADE", "MOOMOO_MILK", "ENERGYPOWDER", "ENERGY_ROOT",
      "BERRY_JUICE", "RAGECANDYBAR", "FULL_RESTORE" },
    { "ANTIDOTE", "AWAKENING", "BURN_HEAL", "ICE_HEAL", "PARLYZ_HEAL",
      "FULL_HEAL", "HEAL_POWDER" },
    { "REVIVE", "MAX_REVIVE", "REVIVAL_HERB", "SACRED_ASH" },
    { "ETHER", "MAX_ETHER", "ELIXER", "MAX_ELIXER" },
    { "HP_UP", "PP_UP", "PROTEIN", "IRON", "CARBOS", "CALCIUM", "RARE_CANDY",
      "X_ATTACK", "X_DEFEND", "X_SPEED", "X_SPECIAL", "X_ACCURACY", "DIRE_HIT",
      "GUARD_SPEC" },
    { "BERRY", "GOLD_BERRY", "PSNCUREBERRY", "PRZCUREBERRY", "BURNT_BERRY",
      "ICE_BERRY", "MINT_BERRY", "BITTER_BERRY", "MIRACLEBERRY", "MYSTERYBERRY" },
    { "FIRE_STONE", "WATER_STONE", "THUNDER_STONE", "LEAF_STONE", "MOON_STONE",
      "SUN_STONE" },
    { "REPEL", "SUPER_REPEL", "MAX_REPEL", "ESCAPE_ROPE", "POKE_DOLL", "NUGGET" },
    { "DOME_FOSSIL", "HELIX_FOSSIL", "OLD_AMBER", "OLD_ROD", "GOOD_ROD", "SUPER_ROD" },
  }
  for group, ids in ipairs(groups) do
    for index, id in ipairs(ids) do priority[id] = group * 100 + index end
  end
  priority.ELIXIR, priority.MAX_ELIXIR = priority.ELIXER, priority.MAX_ELIXER
  priority.X_DEFENSE = priority.X_DEFEND
  priority.PARALYZE_HEAL = priority.PARLYZ_HEAL

  local function rank(id) return priority[id] or 10000 end

  -- a.key / b.key: the item id; a.name / b.name: lower-case name
  function C.less(kind, descending)
    return function(a, b)
      if kind == "category" then
        local ra, rb = rank(a.key), rank(b.key)
        if ra ~= rb then
          if descending then return ra > rb end
          return ra < rb
        end
      end
      if a.name ~= b.name then
        if descending then return a.name > b.name end
        return a.name < b.name
      end
      if a.key ~= b.key then
        if descending then return a.key > b.key end
        return a.key < b.key
      end
      return (a.slot or 0) < (b.slot or 0)
    end
  end

  ---------------------------------------------------------------------------
  -- Reorder the bag rows of ONE pocket, leaving every other pocket where it
  -- was. `inPocket(id)` says which rows move; `data` is the item table
  -- holder Bag.* expects. Works on stack rows, so Gen 1's split stacks
  -- (more than 99 of an item) keep their counts.
  ---------------------------------------------------------------------------
  local function writeRows(save, data, rows)
    local order = Bag.order(save, data)
    local stacks = type(save.bagStacks) == "table" and save.bagStacks or {}
    Bag.setRows(save.inventory, order, rows, data, stacks)
    save.bagStacks = next(stacks) ~= nil and stacks or nil
  end

  function C.reorderPocket(save, data, inPocket, arrange)
    if type(save) ~= "table" or type(save.inventory) ~= "table" then return false end
    local rows = Bag.rows(save, data)
    local at, picked = {}, {}
    for i, row in ipairs(rows) do
      if not Bag.isBadge(row.id) and inPocket(row.id) then
        at[#at + 1] = i
        picked[#picked + 1] = row
      end
    end
    if #picked < 2 then return false end
    picked = arrange(picked) or picked
    for i, position in ipairs(at) do rows[position] = picked[i] end
    writeRows(save, data, rows)
    return true
  end

  function C.sortPocket(save, data, inPocket, nameOf, kind, descending)
    local less = C.less(kind, descending)
    return C.reorderPocket(save, data, inPocket, function(rows)
      local keyed = {}
      for i, row in ipairs(rows) do
        keyed[i] = { row = row, key = row.id, slot = row.slot,
          name = tostring(nameOf(row.id) or row.id):lower() }
      end
      table.sort(keyed, less)
      local out = {}
      for i, k in ipairs(keyed) do out[i] = k.row end
      return out
    end)
  end

  -- SELECT's move: the row at `from` (1-based inside the pocket) goes to `to`.
  function C.movePocketRow(save, data, inPocket, from, to)
    return C.reorderPocket(save, data, inPocket, function(rows)
      if not rows[from] then return rows end
      to = math.max(1, math.min(to, #rows))
      if to == from then return rows end
      table.insert(rows, to, table.remove(rows, from))
      return rows
    end)
  end

  ---------------------------------------------------------------------------
  -- The TM/HM pocket's own sort, kept in the save file.
  ---------------------------------------------------------------------------
  local function bucket(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local ph = save.modData.project_highlander
    if type(ph) ~= "table" then
      if not create then return nil end
      ph = {}
      save.modData.project_highlander = ph
    end
    if type(ph.bag) ~= "table" then
      if not create then return nil end
      ph.bag = {}
    end
    return ph.bag
  end

  function C.tmSort(save)
    local b = bucket(save, false)
    local value = b and b.tmSort
    if value == "category_desc" then return "category", true end
    if value == "name" then return "name", false end
    if value == "name_desc" then return "name", true end
    return "category", false
  end

  function C.setTmSort(save, kind, descending)
    local b = bucket(save, true)
    if not b then return end
    local value = kind == "name" and "name" or "category"
    if descending then value = value .. "_desc" end
    b.tmSort = value ~= "category" and value or nil
  end

  -- number: TM number (HMs after the TMs); name: the move's name
  function C.sortMachines(list, numberOf, nameOf, save)
    local kind, descending = C.tmSort(save)
    table.sort(list, function(a, b)
      local ka, kb
      if kind == "name" then
        ka, kb = tostring(nameOf(a) or ""):lower(), tostring(nameOf(b) or ""):lower()
      else
        ka, kb = numberOf(a) or 9999, numberOf(b) or 9999
      end
      if ka ~= kb then
        if descending then return ka > kb end
        return ka < kb
      end
      return tostring(a.id or a.value) < tostring(b.id or b.value)
    end)
  end

  ---------------------------------------------------------------------------
  -- OTHER SETTINGS > HIGHLANDER BAG: the pocket the bag opens on, in and out
  -- of battle. Pockets are 1 Items, 2 Balls, 3 Key Items, 4 TMs/HMs.
  ---------------------------------------------------------------------------
  local OPEN_ON = { items = 1, balls = 2, key = 3, tmhm = 4 }
  -- nil = LAST OPENED (the default)
  function C.defaultPocket()
    local value = mod.options:get("open_on")
    return OPEN_ON[value]
  end

  function C.lastPocket(save)
    local b = bucket(save, false)
    local n = b and tonumber(b.lastPocket)
    if n and n >= 1 and n <= 4 then return math.floor(n) end
    return nil
  end

  function C.setLastPocket(save, n)
    local b = bucket(save, true)
    if b then b.lastPocket = n end
  end

  ---------------------------------------------------------------------------
  -- "START: SORT", in the header's own small lettering (6 pixels tall).
  ---------------------------------------------------------------------------
  -- the header's own capitals (copied from POCKET / ITEMS)
  local GLYPHS = {
    S = { "###", "#..", "##.", ".##", "..#", "###" },
    T = { "###", ".#.", ".#.", ".#.", ".#.", ".#." },
    A = { ".##.", "#..#", "#..#", "####", "#..#", "#..#" },
    R = { "###.", "#..#", "#..#", "###.", "#.#.", "#..#" },
    O = { ".##.", "#..#", "#..#", "#..#", "#..#", ".##." },
    [":"] = { ".", "#", ".", ".", "#", "." },
    [" "] = { "." },
  }
  C.HEADER_TEXT_X = 98

  function C.drawStartSort(x, y)
    G.setColor(1, 1, 1, 1)
    local text = "START: SORT"
    for i = 1, #text do
      local glyph = GLYPHS[text:sub(i, i)]
      for row, bits in ipairs(glyph) do
        for col = 1, #bits do
          if bits:sub(col, col) == "#" then
            G.rectangle("fill", x + col - 1, y + row, 1, 1)
          end
        end
      end
      x = x + #glyph[1] + 1
    end
  end

  ---------------------------------------------------------------------------
  -- Money and the slot counter, as text.
  ---------------------------------------------------------------------------
  function C.money(save)
    local n = type(save) == "table" and (tonumber(save.money)
      or (type(save.player) == "table" and tonumber(save.player.money))) or 0
    n = math.max(0, math.min(999999, math.floor(n or 0)))
    return "\xc2\xa5" .. tostring(n)
  end

  -- used/255. Gen 2: every pocket together (the whole bag holds 255
  -- different items), the same number on every pocket.
  function C.counter(save, data, pocket)
    local used = 0
    local okV, GV = pcall(require, "src.core.GameVersion")
    local gen2 = okV and GV.generation and GV.generation() == 2
    if gen2 then
      pcall(function() used = C.totalSlots(save, data) end)
      return ("%d/%d"):format(used, 255)
    end
    pcall(function() used = Bag.slots(save, data, pocket) end)
    local cap = 255
    pcall(function() cap = Bag.capacity(data, pocket) end)
    return ("%d/%d"):format(used, cap)
  end

  function C.totalSlots(save, data)
    if not (save and save.inventory) then return 0 end
    return Bag.storeSlots(save.inventory, data, function(id)
      return not Bag.isBadge(id) and (tonumber(save.inventory[id]) or 0) > 0
    end, save.bagStacks)
  end

  return C
end
