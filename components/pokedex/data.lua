-- PH Pokédex data: everything the screens show, read from the cart that is
-- running (base stats, catch rate, types, dex entries, evolutions, level-up,
-- TM/HM, egg and tutor moves). Nothing is hard-coded per species, so Yellow's
-- own movesets and every Gen 2 change come straight from the game files.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local D = {}

  local LOC
  local function locationTable()
    if LOC == nil then
      local ok, t = pcall(mod.load, mod, "locations.lua")
      LOC = (ok and type(t) == "table") and t or false
    end
    return LOC or {}
  end

  ---------------------------------------------------------------------------
  -- Types
  ---------------------------------------------------------------------------
  D.TYPE_ORDER = {
    "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST",
    "STEEL", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC", "ICE", "DRAGON",
    "DARK", "FAIRY",
  }
  -- Same colours as the party screen's type labels.
  D.TYPE_BASE = {
    NORMAL = { 144, 152, 162 }, FIGHTING = { 206, 63, 107 },
    FLYING = { 143, 168, 222 }, POISON = { 171, 106, 200 },
    GROUND = { 217, 119, 70 }, ROCK = { 201, 182, 139 },
    BUG = { 144, 192, 44 }, GHOST = { 82, 105, 173 },
    FIRE = { 254, 156, 85 }, WATER = { 77, 144, 214 },
    GRASS = { 101, 188, 94 }, ELECTRIC = { 244, 210, 59 },
    PSYCHIC = { 249, 113, 119 }, ICE = { 115, 206, 191 },
    DRAGON = { 9, 109, 195 }, DARK = { 91, 82, 101 },
    FAIRY = { 236, 144, 231 }, STEEL = { 91, 142, 161 },
  }

  function D.typeKey(t)
    local k = tostring(t or "NORMAL"):upper()
    if k == "PSYCHIC_TYPE" then k = "PSYCHIC" end
    return k
  end

  function D.typeColor(t)
    return D.TYPE_BASE[D.typeKey(t)] or { 128, 128, 136 }
  end

  -- Black or white ink, whichever reads better on a fill colour.
  function D.inkOn(c)
    local l = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
    return l > 165 and { 16, 16, 16 } or { 255, 255, 255 }
  end

  function D.typeName(ctx, t)
    local name
    local types = ctx.data.type_chart and ctx.data.type_chart.types
    local rec = type(types) == "table" and types[t] or nil
    if type(rec) == "table" then name = rec.name end
    if not name then
      local ok, TypeChart = pcall(require, "src.battle.TypeChart")
      if ok and type(TypeChart.displayName) == "function" then
        local ok2, v = pcall(TypeChart.displayName, t, ctx.data)
        if ok2 then name = v end
      end
    end
    name = tostring(name or t or "???"):gsub("_TYPE$", ""):gsub("_", " ")
    return name:upper()
  end

  ---------------------------------------------------------------------------
  -- Context
  ---------------------------------------------------------------------------
  function D.context(game)
    local data = game and game.data or {}
    local ctx = {
      game = game, data = data, pokemon = data.pokemon or {},
      gen = (GameVersion.generation and GameVersion.generation() == 2) and 2 or 1,
      key = tostring(GameVersion.get and GameVersion.get() or "red"):lower(),
      dex2 = data.gen2Pokedex, cache = {},
    }
    return ctx
  end

  local function def(ctx, sp)
    local d = ctx.pokemon[sp]
    return type(d) == "table" and d or nil
  end
  D.def = def

  local function dexTable(ctx)
    local s = ctx.game and ctx.game.save
    return s and s.pokedex or {}
  end

  function D.isOwned(ctx, sp)
    local d = dexTable(ctx)
    return (type(d.owned) == "table" and d.owned[sp] == true)
      or (type(d.caught) == "table" and d.caught[sp] == true)
  end

  function D.isSeen(ctx, sp)
    local d = dexTable(ctx)
    return (type(d.seen) == "table" and d.seen[sp] == true) or D.isOwned(ctx, sp)
  end

  function D.name(ctx, sp)
    local d = def(ctx, sp)
    return tostring(d and d.name or sp or "?????")
  end

  function D.dexNo(ctx, sp)
    if ctx.gen == 2 and ctx.dex2 and ctx.dex2.entries and ctx.dex2.entries[sp] then
      return tonumber(ctx.dex2.entries[sp].dex) or 0
    end
    local d = def(ctx, sp)
    return d and tonumber(d.dex) or 0
  end

  function D.types(ctx, sp)
    local d = def(ctx, sp)
    local out, seen = {}, {}
    for _, t in ipairs(d and d.types or {}) do
      if t ~= nil and not seen[t] then seen[t] = true; out[#out + 1] = t end
    end
    return out
  end

  function D.catchRate(ctx, sp)
    local d = def(ctx, sp)
    return d and tonumber(d.catchRate) or nil
  end

  ---------------------------------------------------------------------------
  -- Listing
  ---------------------------------------------------------------------------
  -- Gen 1: NAT (dex number) and A-Z. Gen 2: NEW (Johto), OLD (national), A-Z.
  function D.modes(ctx)
    if ctx.gen == 2 then return { "NEW", "OLD", "A-Z" } end
    return { "NAT", "A-Z" }
  end

  local function nationalOrder(ctx)
    local list = {}
    if ctx.gen == 2 and ctx.dex2 and type(ctx.dex2.entries) == "table" then
      for sp in pairs(ctx.dex2.entries) do list[#list + 1] = sp end
    else
      for sp, d in pairs(ctx.pokemon) do
        if type(d) == "table" and tonumber(d.dex) and d.name then list[#list + 1] = sp end
      end
    end
    table.sort(list, function(a, b)
      local da, db = D.dexNo(ctx, a), D.dexNo(ctx, b)
      if da ~= db then return da < db end
      return tostring(a) < tostring(b)
    end)
    return list
  end

  function D.rows(ctx, mode)
    local order
    if mode == "NEW" and ctx.dex2 and type(ctx.dex2.newOrder) == "table" then
      order = ctx.dex2.newOrder
    else
      order = nationalOrder(ctx)
    end
    local rows = {}
    if mode == "A-Z" then
      for _, sp in ipairs(nationalOrder(ctx)) do
        if D.isSeen(ctx, sp) then
          rows[#rows + 1] = { species = sp, dex = D.dexNo(ctx, sp), seen = true,
            owned = D.isOwned(ctx, sp) }
        end
      end
      table.sort(rows, function(a, b)
        return D.name(ctx, a.species):upper() < D.name(ctx, b.species):upper()
      end)
      return rows
    end
    local last = 0
    for _, sp in ipairs(order) do
      if def(ctx, sp) then
        local seen = D.isSeen(ctx, sp)
        rows[#rows + 1] = { species = sp, dex = D.dexNo(ctx, sp), seen = seen,
          owned = D.isOwned(ctx, sp) }
        if seen then last = #rows end
      end
    end
    -- Like both carts: the list ends on the last Pokémon seen.
    for i = #rows, last + 1, -1 do rows[i] = nil end
    return rows
  end

  function D.totals(ctx)
    local seen, owned = 0, 0
    for _, sp in ipairs(nationalOrder(ctx)) do
      if D.isSeen(ctx, sp) then seen = seen + 1 end
      if D.isOwned(ctx, sp) then owned = owned + 1 end
    end
    return seen, owned
  end

  -- Every type that some Pokémon in this game has, in the usual order.
  function D.searchTypes(ctx)
    if ctx.cache.searchTypes then return ctx.cache.searchTypes end
    local present = {}
    for _, d in pairs(ctx.pokemon) do
      if type(d) == "table" and d.dex and type(d.types) == "table" then
        for _, t in ipairs(d.types) do present[t] = true end
      end
    end
    local out, used = {}, {}
    for _, want in ipairs(D.TYPE_ORDER) do
      for t in pairs(present) do
        if not used[t] and D.typeKey(t) == want then out[#out + 1] = t; used[t] = true end
      end
    end
    local extra = {}
    for t in pairs(present) do if not used[t] then extra[#extra + 1] = t end end
    table.sort(extra, function(a, b) return tostring(a) < tostring(b) end)
    for _, t in ipairs(extra) do out[#out + 1] = t end
    ctx.cache.searchTypes = out
    return out
  end

  function D.search(ctx, t1, t2)
    local out = {}
    for _, sp in ipairs(nationalOrder(ctx)) do
      if D.isSeen(ctx, sp) then
        local has1, has2 = t1 == nil, t2 == nil
        for _, t in ipairs(D.types(ctx, sp)) do
          if t == t1 then has1 = true end
          if t == t2 then has2 = true end
        end
        if has1 and has2 then
          out[#out + 1] = { species = sp, dex = D.dexNo(ctx, sp), seen = true,
            owned = D.isOwned(ctx, sp) }
        end
      end
    end
    return out
  end

  ---------------------------------------------------------------------------
  -- Entry page
  ---------------------------------------------------------------------------
  local function gen1Pages(ctx, d)
    local e = d.dexEntry or {}
    local text = e.text and ctx.data.text and ctx.data.text[e.text] or nil
    if type(text) ~= "string" then return {} end
    local dexEnd = true
    if text:sub(-6) == "{DONE}" then text, dexEnd = text:sub(1, -7), false end
    local pages = {}
    for chunk in (text .. "\f"):gmatch("(.-)\f") do
      local lines = {}
      for line in (chunk:gsub("\v", "\n") .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
      end
      while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
      if #lines > 0 then pages[#pages + 1] = lines end
    end
    if dexEnd and #pages > 0 then
      local last = pages[#pages]
      last[#last] = last[#last] .. "."
    end
    return pages
  end

  local function gen2Page(text)
    local lines = {}
    for part in (tostring(text or "") .. "<NEXT>"):gmatch("(.-)<NEXT>") do
      part = part:gsub("<[%u_]+>", ""):gsub("@", "")
      if part ~= "" or #lines > 0 then lines[#lines + 1] = part end
    end
    while #lines > 0 and lines[#lines] == "" do table.remove(lines) end
    return lines
  end

  function D.entry(ctx, sp)
    local out = { pages = {} }
    local owned = D.isOwned(ctx, sp)
    if ctx.gen == 2 then
      local e = ctx.dex2 and ctx.dex2.entries and ctx.dex2.entries[sp] or {}
      out.kind = e.kind
      if e.heightM then
        out.metric, out.m, out.kg = true, e.heightM, e.weightKg
      else
        local h = tonumber(e.height) or 0
        out.ft, out.inch = math.floor(h / 100), h % 100
        out.lb = (tonumber(e.weight) or 0) / 10
      end
      if owned then
        local p1, p2 = gen2Page(e.text), gen2Page(e.text2)
        if #p1 > 0 then out.pages[#out.pages + 1] = p1 end
        if #p2 > 0 then out.pages[#out.pages + 1] = p2 end
      end
    else
      local d = def(ctx, sp) or {}
      local e = d.dexEntry or {}
      out.kind = e.kind
      if e.heightM then
        out.metric, out.m, out.kg = true, e.heightM, e.weightKg
      else
        out.ft, out.inch = tonumber(e.heightFt) or 0, tonumber(e.heightIn) or 0
        out.lb = (tonumber(e.weight) or 0) / 10
      end
      if owned then out.pages = gen1Pages(ctx, d) end
    end
    out.owned = owned
    return out
  end

  ---------------------------------------------------------------------------
  -- Stats
  ---------------------------------------------------------------------------
  function D.stats(ctx, sp)
    local b = (def(ctx, sp) or {}).baseStats or {}
    local rows
    if ctx.gen == 2 then
      rows = {
        { "HP", b.hp }, { "ATTACK", b.attack }, { "DEFENSE", b.defense },
        { "SP.ATK", b.specialAttack }, { "SP.DEF", b.specialDefense },
        { "SPEED", b.speed },
      }
    else
      rows = {
        { "HP", b.hp }, { "ATTACK", b.attack }, { "DEFENSE", b.defense },
        { "SPEED", b.speed }, { "SPECIAL", b.special },
      }
    end
    local total = 0
    for _, r in ipairs(rows) do
      r[2] = tonumber(r[2]) or 0
      total = total + r[2]
    end
    return rows, total
  end

  ---------------------------------------------------------------------------
  -- Family
  ---------------------------------------------------------------------------
  local function target(edge)
    return type(edge) == "table" and (edge.into or edge.species) or nil
  end

  local function itemName(ctx, id)
    local it = id and ctx.data.items and ctx.data.items[id]
    local name = type(it) == "table" and it.name or id or "ITEM"
    return tostring(name):gsub("_", " "):upper()
  end
  D.itemName = itemName

  function D.method(ctx, edge)
    if type(edge) ~= "table" then return "" end
    local m = tostring(edge.method or ""):gsub("^EVOLVE_", "")
    local lv = tonumber(edge.level)
    if m == "LEVEL" then return "Lv" .. tostring(lv or 1) end
    if m == "ITEM" then return itemName(ctx, edge.item) end
    if m == "TRADE" then
      if edge.item then return "TRADE W/ " .. itemName(ctx, edge.item) end
      return "TRADE"
    end
    if m == "HAPPINESS" then
      local t = tostring(edge.time or "ANYTIME"):upper()
      if t == "MORNDAY" or t == "DAY" then return "HAPPY DAY" end
      if t == "NITE" or t == "NIGHT" then return "HAPPY NIGHT" end
      return "HAPPY"
    end
    if m == "STAT" then
      local c = ({ ATK_GT_DEF = "HI ATK", ATK_LT_DEF = "HI DEF",
        ATK_EQ_DEF = "SAME ATK/DEF" })[edge.comparison] or "STATS"
      return ("Lv%d %s"):format(lv or 1, c)
    end
    if lv then return "Lv" .. lv end
    return m ~= "" and m:gsub("_", " ") or "?"
  end

  function D.family(ctx, sp)
    ctx.cache.family = ctx.cache.family or {}
    if ctx.cache.family[sp] then return ctx.cache.family[sp] end
    local parents = ctx.cache.parents
    if not parents then
      parents = {}
      for key, d in pairs(ctx.pokemon) do
        if type(d) == "table" and d.name then
          for _, edge in ipairs(d.evolutions or {}) do
            local child = target(edge)
            if child and def(ctx, child) and not parents[child] then
              parents[child] = { species = d.id or key, edge = edge }
            end
          end
        end
      end
      ctx.cache.parents = parents
    end
    local root, walked = sp, {}
    while parents[root] and not walked[root] do
      walked[root] = true
      root = parents[root].species
    end
    local members, queue, seen = {}, { { species = root, depth = 0 } }, {}
    while #queue > 0 do
      local m = table.remove(queue, 1)
      local d = def(ctx, m.species)
      if d and not seen[m.species] and m.depth <= 3 then
        seen[m.species] = true
        members[#members + 1] = m
        local kids = {}
        for _, edge in ipairs(d.evolutions or {}) do
          local child = target(edge)
          if child and def(ctx, child) and not seen[child] then
            kids[#kids + 1] = { species = child, depth = m.depth + 1,
              parent = m.species, method = D.method(ctx, edge) }
          end
        end
        table.sort(kids, function(a, b) return D.dexNo(ctx, a.species) < D.dexNo(ctx, b.species) end)
        for _, k in ipairs(kids) do queue[#queue + 1] = k end
      end
    end
    if #members == 0 then members[1] = { species = sp, depth = 0 } end
    for _, m in ipairs(members) do ctx.cache.family[m.species] = members end
    return members
  end

  ---------------------------------------------------------------------------
  -- Moves
  ---------------------------------------------------------------------------
  local function machineLabels(ctx)
    if ctx.cache.machines then return ctx.cache.machines end
    local out = {}
    for id, item in pairs(ctx.data.items or {}) do
      if type(item) == "table" then
        local move, kind, num
        if type(item.machine) == "table" then
          move = item.machine.move
          kind = tostring(item.machine.kind or "TM"):upper()
          num = tonumber(item.machine.number)
        elseif item.teaches then
          move = item.teaches
          local label = tostring(item.tmLabel or item.name or id):upper()
          kind, num = label:match("^(TM)%s*(%d+)")
          if not kind then kind, num = label:match("^(HM)%s*(%d+)") end
          num = tonumber(num)
        end
        if move and kind then
          out[move] = { kind = kind == "HM" and "HM" or "TM", num = num }
        end
      end
    end
    local order = ctx.data.tmhmMoves
      or (ctx.data.constants and ctx.data.constants.tmhmMoves)
      or ctx.pokemon.tmhmMoves
    local hmEnd = ctx.gen == 2 and 57 or 55
    if type(order) == "table" then
      for i, mv in ipairs(order) do
        if not out[mv] then
          if i <= 50 then out[mv] = { kind = "TM", num = i }
          elseif i <= hmEnd then out[mv] = { kind = "HM", num = i - 50 } end
        end
      end
    end
    ctx.cache.machines = out
    return out
  end

  local function moveRow(ctx, source, id)
    local mv = ctx.data.moves and ctx.data.moves[id] or {}
    return { source = source, id = id,
      name = tostring(mv.name or id or "?"):gsub("_", " "), type = mv.type }
  end

  function D.moves(ctx, sp)
    ctx.cache.moves = ctx.cache.moves or {}
    if ctx.cache.moves[sp] then return ctx.cache.moves[sp] end
    local d = def(ctx, sp) or {}
    local rows = {}
    local function section(title, list)
      if #list == 0 then return end
      rows[#rows + 1] = { header = title }
      for _, r in ipairs(list) do rows[#rows + 1] = r end
    end

    local level, added, ord = {}, {}, 0
    local function addLevel(lv, move)
      if move == nil then return end
      lv = tonumber(lv) or 1
      local k = lv .. ":" .. tostring(move)
      if added[k] then return end
      added[k] = true
      ord = ord + 1
      local r = moveRow(ctx, "Lv" .. lv, move)
      r.level, r.ord = lv, ord
      level[#level + 1] = r
    end
    for _, mv in ipairs(d.level1Moves or {}) do addLevel(1, mv) end
    for _, l in ipairs(d.learnset or {}) do if type(l) == "table" then addLevel(l.level, l.move) end end
    for _, l in ipairs(d.levelMoves or {}) do if type(l) == "table" then addLevel(l.level, l.move) end end
    table.sort(level, function(a, b)
      if a.level ~= b.level then return a.level < b.level end
      return a.ord < b.ord
    end)
    section("LEVEL UP", level)

    local labels, machines = machineLabels(ctx), {}
    for _, mv in ipairs(d.tmhm or {}) do
      local m = labels[mv]
      local r = moveRow(ctx, m and m.num and ("%s%02d"):format(m.kind, m.num) or "TM", mv)
      r.sortKind = m and (m.kind == "HM" and 2 or 1) or 3
      r.sortNum = m and m.num or 999
      machines[#machines + 1] = r
    end
    table.sort(machines, function(a, b)
      if a.sortKind ~= b.sortKind then return a.sortKind < b.sortKind end
      return a.sortNum < b.sortNum
    end)
    section("TM/HM", machines)

    if ctx.gen == 2 then
      local egg = {}
      for _, mv in ipairs(d.eggMoves or {}) do egg[#egg + 1] = moveRow(ctx, "EGG", mv) end
      section("EGG MOVES", egg)
      if ctx.key == "crystal" then
        local tutor = {}
        for _, mv in ipairs(d.tutorMoves or {}) do tutor[#tutor + 1] = moveRow(ctx, "TUTOR", mv) end
        section("TUTOR", tutor)
      end
    end
    ctx.cache.moves[sp] = rows
    return rows
  end

  local function humanEffect(effect)
    local e = tostring(effect or ""):upper()
    if e == "" or e:find("NORMAL_HIT") or e:find("NO_ADDITIONAL") then
      return "An attack with no added effect."
    end
    e = e:gsub("^EFFECT_", ""):gsub("_EFFECT%d*$", ""):gsub("_EFFECT", ""):gsub("_", " ")
    return "Effect: " .. e .. "."
  end

  function D.moveDetail(ctx, id)
    local mv = ctx.data.moves and ctx.data.moves[id] or {}
    local acc = tonumber(mv.accuracy) or 0
    if acc > 100 then acc = math.floor(acc * 100 / 255 + 0.5) end
    local desc = mv.description
    if type(desc) == "string" then
      desc = desc:gsub("<NEXT>", " "):gsub("<[%u_]+>", ""):gsub("@", ""):gsub("\n", " ")
    else
      desc = humanEffect(mv.effect)
    end
    return {
      name = tostring(mv.name or id or "?"):gsub("_", " "), type = mv.type,
      power = tonumber(mv.power) or 0, accuracy = acc, pp = tonumber(mv.pp) or 0,
      desc = desc,
    }
  end

  ---------------------------------------------------------------------------
  -- Locations
  ---------------------------------------------------------------------------
  local function exclusiveOn(ctx)
    local function on(key)
      local v
      if mod.highlander and mod.highlander.option then
        local ok, got = pcall(mod.highlander.option, "other_settings", key)
        if ok then v = got end
      end
      return v == true
    end
    if ctx.gen == 1 then
      if on("gen1_features_migrated") then return on("gen1_exclusive") end
      return on("gen1_exclusive") or on("gen1_all_pkmn")
    end
    if on("gen2_features_migrated") then return on("gen2_exclusive") end
    return on("gen2_exclusive") or on("gen2_all_pkmn")
  end

  local function kindOf(loc, terrain)
    local t, low = tostring(terrain or ""):lower(), loc:lower()
    if t == "surf" or low:find("surf", 1, true) then return "surf" end
    if t == "fish" or low:find("fish", 1, true) or low:find("rod", 1, true) then return "fish" end
    if t == "headbutt" or low:find("headbutt", 1, true) then return "headbutt" end
    if low:find("contest", 1, true) then return "contest" end
    if t == "prize" or low:find("prize", 1, true) or low:find("game corner", 1, true) then
      return "prize"
    end
    if low:find("route", 1, true) or low:find("forest", 1, true)
        or low:find("safari", 1, true) or low:find("national park", 1, true) then
      return "grass"
    end
    return "cave"
  end

  -- Same colours as the old Locations chart.
  D.KIND_COLOR = {
    grass = { 31, 214, 56 }, cave = { 158, 158, 168 },
    headbutt = { 158, 102, 41 }, surf = { 31, 56, 184 },
    fish = { 102, 184, 242 }, contest = { 13, 107, 41 },
    prize = { 235, 199, 31 },
  }
  D.KIND_LEGEND = {
    { "grass", "GRASS" }, { "cave", "CAVES/INDOORS" }, { "surf", "SURF" },
    { "fish", "FISHING ROD" }, { "prize", "PRIZE/SHOP" },
    { "headbutt", "HEADBUTT TREES", gen2 = true }, { "contest", "BUG CONTEST", gen2 = true },
  }

  local SKIP = { "evolve", "trade", "gift", "starter", "fossil", "old amber",
    "revived", "event", "quest", "static" }

  function D.locations(ctx, sp)
    local rec = locationTable()[sp] or locationTable()[tostring(sp):upper()] or {}
    local key = ctx.key
    if key ~= "red" and key ~= "blue" and key ~= "yellow" and key ~= "gold"
        and key ~= "silver" and key ~= "crystal" then
      key = ctx.gen == 2 and "gold" or "red"
    end
    local lists = { rec[key] }
    if exclusiveOn(ctx) then
      if ctx.gen == 1 then
        lists[#lists + 1] = rec["x" .. key]
      elseif key == "gold" then lists[#lists + 1] = rec.silver
      elseif key == "silver" then lists[#lists + 1] = rec.gold
      else lists[#lists + 1] = rec.gold; lists[#lists + 1] = rec.silver end
    end
    local rows, dupe = {}, {}
    for _, list in ipairs(lists) do
      for _, r in ipairs(list or {}) do
        local loc = tostring(r.loc or r[1] or "")
        local level = tostring(r.level or r[3] or "")
        local rate = tostring(r.rate or r[4] or "")
        local terrain = r.terrain or r[2]
        local low, skip = loc:lower(), false
        for _, w in ipairs(SKIP) do
          if low:find(w, 1, true) then skip = true break end
        end
        local k = loc .. "|" .. level .. "|" .. rate
        if not skip and loc ~= "" and not dupe[k] then
          dupe[k] = true
          -- "12,13" is the same slot at two levels: one row each.
          for lv in (level .. ","):gmatch("([^,]*),") do
            lv = lv:gsub("^%s+", ""):gsub("%s+$", "")
            local k2 = loc .. "|" .. lv .. "|" .. rate
            if lv == level or not dupe[k2] then
              dupe[k2] = true
              rows[#rows + 1] = { loc = loc:upper(), level = lv, rate = rate,
                kind = kindOf(loc, terrain) }
            end
          end
        end
      end
    end
    return rows
  end

  local function natKey(s)
    return tostring(s or ""):lower():gsub("%d+", function(n) return ("%05d"):format(tonumber(n)) end)
  end
  local function firstLevel(r) return tonumber(tostring(r.level):match("%d+")) or 0 end
  local function rateOf(r) return tonumber(tostring(r.rate):match("%d+")) or -1 end

  D.SORTS = {
    { id = "location", label = "LOCATION" },
    { id = "location_rev", label = "REVERSE LOCATION" },
    { id = "level", label = "LEVEL" },
    { id = "level_rev", label = "REVERSE LEVEL" },
    { id = "rate", label = "RATE" },
    { id = "rate_rev", label = "REVERSE RATE" },
  }
  function D.sortLocations(rows, mode)
    table.sort(rows, function(a, b)
      local na, nb = natKey(a.loc), natKey(b.loc)
      if mode == "location_rev" then
        if na ~= nb then return na > nb end
      elseif mode == "level" or mode == "level_rev" then
        local la, lb = firstLevel(a), firstLevel(b)
        if la ~= lb then
          if mode == "level" then return la < lb end
          return la > lb
        end
      elseif mode == "rate" or mode == "rate_rev" then
        local ra, rb = rateOf(a), rateOf(b)
        if ra ~= rb then
          if mode == "rate" then return ra < rb end
          return ra > rb
        end
      end
      if na ~= nb then return na < nb end
      return firstLevel(a) < firstLevel(b)
    end)
    return rows
  end

  ---------------------------------------------------------------------------
  -- Owned-species repair: a Pokémon in the party or PC is proof it was
  -- caught, even when another mod's gift or trade forgot to mark the dex.
  ---------------------------------------------------------------------------
  function D.repairOwned(game)
    local save = type(game) == "table" and game.save
    if type(save) ~= "table" then return end
    local data = game.data or {}
    local pokemon = data.pokemon or {}
    local gen2 = GameVersion.generation and GameVersion.generation() == 2
    save.pokedex = type(save.pokedex) == "table" and save.pokedex or {}
    local dex = save.pokedex
    dex.seen = type(dex.seen) == "table" and dex.seen or {}
    local ownKey = gen2 and "caught" or "owned"
    dex[ownKey] = type(dex[ownKey]) == "table" and dex[ownKey] or {}
    local function mark(mon)
      if type(mon) ~= "table" or mon.isEgg == true then return end
      local sp = mon.species
      local d = sp and pokemon[sp]
      if type(d) ~= "table" or d.dex == nil then return end
      dex.seen[sp] = true
      dex[ownKey][sp] = true
    end
    local function scan(list)
      if type(list) ~= "table" then return end
      for _, mon in pairs(list) do mark(mon) end
    end
    scan(save.party)
    for _, box in pairs(type(save.boxes) == "table" and save.boxes or {}) do
      if type(box) == "table" and box.species ~= nil then mark(box) else scan(box) end
    end
    scan(save.box)
  end

  return D
end
