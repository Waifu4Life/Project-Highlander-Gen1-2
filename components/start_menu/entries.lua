-- Highlander Start Menu: what each Start Menu row is.
--
-- Every row gets one KEY that is the same in Gen 1 and Gen 2, so a sorted
-- order (and a custom icon) follows the player from one game to the other:
--   the game's own rows   "pokedex", "party", "bag", "trainer", "save",
--                         "options", "pokegear", "mods", "quit", "contest"
--   our POKEBOX row       "pokebox"
--   other mods' rows      "mod:<their id>" (or their label, upper case)
return function()
  local Strings = require("src.core.Strings")
  local E = {}

  -- Gen 2 tags each row with a value; Gen 1 only has labels.
  local BY_VALUE = {
    pokedex = "pokedex", pokemon = "party", party = "party",
    pack = "bag", bag = "bag", item = "bag",
    pokegear = "pokegear", status = "trainer", trainer = "trainer",
    save = "save", option = "options", options = "options",
    mods = "mods", quit = "quit", quitContest = "contest",
    pokebox = "pokebox", link = "link",
  }
  -- The cart's own words for the Gen 1 rows (run through the translation
  -- catalog too, so a translated game is still recognised).
  local GEN1_WORDS = {
    { "POKéDEX", "pokedex" }, { "POKéMON", "party" }, { "ITEM", "bag" },
    { "SAVE", "save" }, { "OPTION", "options" }, { "MODS", "mods" },
    { "QUIT", "quit" },
  }
  E.BUILTIN = {
    pokedex = true, party = true, bag = true, trainer = true, save = true,
    options = true, pokegear = true, mods = true, quit = true,
    contest = true, pokebox = true, link = true,
  }
  -- Icon frame for each built-in row (icons.lua names).
  E.ICON = {
    pokedex = "pokedex", party = "party", bag = "bag", trainer = "trainer",
    save = "save", options = "options", pokegear = "pokegear",
    mods = "mods", quit = "quit", contest = "quit", pokebox = "pokebox",
    link = "link",
  }
  -- Until the player sorts the menu.
  E.DEFAULT_ORDER = {
    "pokedex", "party", "bag", "pokebox", "trainer", "save", "options",
    "mods", "quit",
  }

  local ACCENTS = {
    ["é"] = "E", ["É"] = "E", ["è"] = "E", ["ê"] = "E", ["à"] = "A",
    ["á"] = "A", ["â"] = "A", ["ä"] = "A", ["ç"] = "C", ["í"] = "I",
    ["ï"] = "I", ["ñ"] = "N", ["ó"] = "O", ["ô"] = "O", ["ö"] = "O",
    ["ú"] = "U", ["ü"] = "U",
  }
  -- Upper case, accents dropped, spaces tidied: "Poké Ball" -> "POKE BALL".
  function E.plain(text)
    text = tostring(text or "")
    for from, to in pairs(ACCENTS) do text = text:gsub(from, to) end
    text = text:upper():gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return text
  end

  local wordCache
  local function gen1Word(label)
    if not wordCache then
      wordCache = {}
      for _, pair in ipairs(GEN1_WORDS) do
        wordCache[E.plain(pair[1])] = pair[2]
        local ok, translated = pcall(Strings, pair[1])
        if ok and type(translated) == "string" then
          wordCache[E.plain(translated)] = pair[2]
        end
      end
    end
    return wordCache[E.plain(label)]
  end

  local function playerName(game)
    local player = game and game.save and game.save.player
    return player and player.name and E.plain(player.name) or ""
  end

  -- The row's key (see the top of this file).
  function E.keyOf(item, game)
    if type(item) ~= "table" then return "mod:?" end
    for _, field in ipairs({ "value", "id" }) do
      local v = item[field]
      if type(v) == "string" and BY_VALUE[v] then return BY_VALUE[v] end
    end
    local label = item.label
    local known = label and gen1Word(label)
    if known then return known end
    local name = playerName(game)
    if name ~= "" and E.plain(label) == name then return "trainer" end
    local own = (type(item.id) == "string" and item.id ~= "" and item.id)
      or (type(item.value) == "string" and item.value ~= "" and item.value)
      or E.plain(label)
    return "mod:" .. own
  end

  function E.isBuiltin(key) return E.BUILTIN[key] == true end

  -- Rows in the saved order. Keys the saved order doesn't mention (a mod
  -- installed later, Gen 2's POKeGEAR) go at the end -- just before QUIT
  -- when QUIT is last, so it stays the last tile until it's moved. A key
  -- seen twice gets "#2", "#3"... so two rows never share one slot.
  -- "-" in the order is an empty tile the player left in the SORT MENU; it
  -- comes back as { key = "-", gap = true } (trailing ones are dropped).
  -- Returns { { key, item }, ... }.
  E.GAP = "-"
  function E.sorted(items, order, game)
    if type(order) ~= "table" or #order == 0 then order = E.DEFAULT_ORDER end
    local rows, byKey, seen = {}, {}, {}
    for _, item in ipairs(items or {}) do
      local key = E.keyOf(item, game)
      seen[key] = (seen[key] or 0) + 1
      if seen[key] > 1 then key = key .. "#" .. seen[key] end
      local row = { key = key, item = item }
      rows[#rows + 1], byKey[key] = row, row
    end
    local out, placed = {}, {}
    for _, key in ipairs(order) do
      local row = byKey[key]
      if key == E.GAP then
        out[#out + 1] = { key = E.GAP, gap = true }
      elseif row and not placed[key] then
        out[#out + 1], placed[key] = row, true
      end
    end
    while out[#out] and out[#out].gap do table.remove(out) end
    local quitLast = out[#out] and out[#out].key == "quit" and table.remove(out)
    for _, row in ipairs(rows) do
      if not placed[row.key] then out[#out + 1] = row end
    end
    if quitLast then out[#out + 1] = quitLast end
    return out
  end

  return E
end
