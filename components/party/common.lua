-- Highlander Party: pieces shared by the Gen 1 and Gen 2 screens.
--   * the A-menu order and the centred pop-up box
--   * the XP: label and bars
--   * type colours, the moves table and the small SELECT hint
--   * move descriptions for Gen 1 (bundled, from Crystal)
return function(mod)
  local Font = require("src.render.Font")
  local Assets = require("src.render.Assets")
  local G = love.graphics

  local C = {}

  ---------------------------------------------------------------------------
  -- A-menu order
  ---------------------------------------------------------------------------
  -- STATS, (Gen 2: MOVE, ITEM), SWITCH, RELEARN, RENAME, DISMISS/FOLLOW,
  -- TM field moves, HM field moves, anything else, CANCEL. Battle menus keep
  -- the game's own order.
  local ACTION_RANK = {
    STATS = 1, MOVE = 1.1, ITEM = 1.2, MAIL = 1.2, SWITCH = 2, RELEARN = 3,
    RENAME = 3.5, DISMISS = 4, FOLLOW = 4, RECALL = 4, WALK = 4,
    CANCEL = 99, QUIT = 99,
  }
  local TM_MOVES = {
    HEADBUTT = 2, ROCKSMASH = 8, SWEETSCENT = 12, DIG = 28, TELEPORT = 30,
    SOFTBOILED = 40, MILKDRINK = 41,
  }
  local HM_MOVES = {
    CUT = 1, FLY = 2, SURF = 3, STRENGTH = 4, FLASH = 5,
    WHIRLPOOL = 6, WATERFALL = 7,
  }
  local function clean(value)
    if type(value) ~= "string" then return nil end
    local out = value:upper():gsub("%b<>", ""):gsub("%b{}", "")
    out = out:gsub("[^A-Z]", "")
    return out ~= "" and out or nil
  end
  local function rank(entry)
    if type(entry) ~= "table" then return 50, 0 end
    if entry.relearn then return 3, 0 end
    if entry.highlanderRename then return 3.5, 0 end
    for _, field in ipairs({ "action", "id", "label" }) do
      local key = clean(entry[field])
      if key then
        if ACTION_RANK[key] then return ACTION_RANK[key], 0 end
        if TM_MOVES[key] then return 5, TM_MOVES[key] end
        if HM_MOVES[key] then return 6, HM_MOVES[key] end
      end
    end
    return 50, 0
  end

  -- Sorts in place; returns the new cursor row (1 for a fresh list), or nil
  -- when nothing needed doing.
  function C.orderActions(items, cursor)
    if type(items) ~= "table" or #items < 2 then return nil end
    if items._hlOrderedCount == #items then return nil end
    local fresh = items._hlOrderedCount == nil
    local selected = items[cursor or 1]
    local keyed = {}
    for i, entry in ipairs(items) do
      local r, sub = rank(entry)
      keyed[i] = { entry = entry, rank = r, sub = sub, index = i }
    end
    table.sort(keyed, function(x, y)
      if x.rank ~= y.rank then return x.rank < y.rank end
      if x.sub ~= y.sub then return x.sub < y.sub end
      return x.index < y.index
    end)
    -- A field move listed twice (taught, and again from No Learn HM) keeps
    -- only its first row, which is the game's own.
    local seen, out = {}, {}
    for _, k in ipairs(keyed) do
      local dup = (k.rank == 5 or k.rank == 6) and (k.rank .. ":" .. k.sub)
        or (k.rank == 3.5 and "rename") or nil
      if not (dup and seen[dup]) then
        if dup then seen[dup] = true end
        out[#out + 1] = k.entry
      end
    end
    for i = #items, 1, -1 do items[i] = nil end
    for i, entry in ipairs(out) do items[i] = entry end
    items._hlOrderedCount = #items
    if fresh then return 1 end
    for i, entry in ipairs(items) do
      if entry == selected then return i end
    end
    return cursor
  end

  -- The centred A-menu box. At most 8 rows show; with more, the list
  -- scrolls and small arrows say there is more above / below.
  C.POPUP_ROWS = 8
  -- Keeps `scroll` (0-based) so `index` is on screen; returns the new scroll.
  function C.popupScroll(n, index, scroll)
    local rows = C.POPUP_ROWS
    scroll = tonumber(scroll) or 0
    if n <= rows then return 0 end
    if index <= scroll then scroll = index - 1 end
    if index > scroll + rows then scroll = index - rows end
    return math.max(0, math.min(scroll, n - rows))
  end
  -- Layout in pixels/tiles for `labels` with the given scroll.
  function C.popupLayout(labels, scroll)
    local widest = 0
    for _, label in ipairs(labels) do
      local ok, w = pcall(Font.width, tostring(label or ""))
      w = (ok and tonumber(w)) or (#tostring(label or "") * 8)
      if w > widest then widest = w end
    end
    local n = #labels
    local visible = math.min(n, C.POPUP_ROWS)
    local scrolling = n > C.POPUP_ROWS
    local step = 16
    local tw = math.max(6, math.ceil(widest / 8) + 3 + (scrolling and 1 or 0))
    tw = math.min(20, tw)
    local innerH = visible * step
    local th = math.min(18, math.ceil((innerH + 8) / 8) + 1)
    local tx = (20 - tw) / 2
    local ty = math.floor((18 - th) / 2)
    local boxTop = ty * 8
    local firstY = boxTop + math.floor((th * 8 - innerH) / 2) + math.floor((step - 8) / 2)
    scroll = scrolling and math.max(0, math.min(tonumber(scroll) or 0, n - visible)) or 0
    return {
      tx = tx, ty = ty, tw = tw, th = th, step = step,
      labelX = tx * 8 + 16, cursorX = tx * 8 + 8, firstY = firstY,
      first = scroll + 1, last = scroll + visible, scroll = scroll,
      moreAbove = scroll > 0, moreBelow = scroll + visible < n,
      arrowX = (tx + tw) * 8 - 15,
    }
  end
  -- Pixel y of row `i` (absolute index) in a layout.
  function C.popupRowY(L, i)
    return L.firstY + (i - L.first) * L.step
  end
  -- The little up/down arrows of a scrolling A menu.
  function C.popupArrows(L)
    if L.moreAbove then
      local x, y = L.arrowX, L.firstY + 1
      for r = 0, 3 do C.rect({ 0, 0, 0 }, x + 3 - r, y + r, 1 + r * 2, 1) end
    end
    if L.moreBelow then
      local x, y = L.arrowX, C.popupRowY(L, L.last) + 2
      for r = 0, 3 do C.rect({ 0, 0, 0 }, x + r, y + r, 7 - r * 2, 1) end
    end
  end

  ---------------------------------------------------------------------------
  -- Pixels
  ---------------------------------------------------------------------------
  local function rgb(c, a)
    G.setColor((c[1] or 0) / 255, (c[2] or 0) / 255, (c[3] or 0) / 255, a or 1)
  end
  C.rgb = rgb
  local function rect(c, x, y, w, h)
    if w <= 0 or h <= 0 then return end
    rgb(c)
    G.rectangle("fill", x, y, w, h)
  end
  C.rect = rect

  local function blit(map, x, y, c)
    rgb(c)
    for r, line in ipairs(map) do
      for col = 1, #line do
        if line:sub(col, col) == "#" then
          G.rectangle("fill", x + col - 1, y + r - 1, 1, 1)
        end
      end
    end
  end
  C.blit = blit

  -- "XP:" drawn like the game's own "HP:" tiles (4 rows, bold).
  local XP_LABEL = {
    "##.#.####",
    ".##..##.#.#",
    ".##..####",
    "##.#.##...#",
  }
  -- Gen 1: black on white. x/y is the label tile's top-left (the same spot
  -- the HP tile would use); the letters sit on rows 2-5.
  function C.drawXpLabelGen1(x, y)
    rect({ 255, 255, 255 }, x, y + 1, 16, 6)
    blit(XP_LABEL, x + 1, y + 2, { 0, 0, 0 })
  end
  -- Gen 2: the HP badge's look (black plate, light letters), 16 px wide.
  function C.drawXpLabelGen2(x, y, letter)
    rect({ 0, 0, 0 }, x, y + 1, 16, 6)
    blit(XP_LABEL, x + 2, y + 2, letter or { 247, 214, 123 })
  end

  C.XP_BLUE = { 33, 140, 255 }

  -- A thin bar in the Gen 1 HP bar's shape: x is the left end pixel, w the
  -- fill width, y the tile top (bar on rows 2-5).
  function C.drawPixelBar(x, y, w, px, color, fromRight)
    rect({ 0, 0, 0 }, x + 1, y + 2, w, 1)
    rect({ 0, 0, 0 }, x + 1, y + 5, w, 1)
    rect({ 0, 0, 0 }, x, y + 3, 1, 2)
    rect({ 0, 0, 0 }, x + w + 1, y + 3, 1, 2)
    rect({ 255, 255, 255 }, x + 1, y + 3, w, 2)
    px = math.max(0, math.min(w, math.floor(px or 0)))
    if px > 0 then
      if fromRight then
        rect(color, x + 1 + w - px, y + 3, px, 2)
      else
        rect(color, x + 1, y + 3, px, 2)
      end
    end
    return px
  end

  ---------------------------------------------------------------------------
  -- Type colours (the Highlander HUD's), and type labels
  ---------------------------------------------------------------------------
  C.TYPE_COLORS = {
    NORMAL = { 200, 200, 168 }, FIRE = { 245, 172, 120 },
    WATER = { 157, 183, 245 }, ELECTRIC = { 250, 224, 120 },
    GRASS = { 181, 230, 29 }, ICE = { 188, 230, 230 },
    FIGHTING = { 214, 120, 115 }, POISON = { 193, 131, 193 },
    GROUND = { 235, 214, 157 }, FLYING = { 198, 183, 245 },
    PSYCHIC_TYPE = { 250, 146, 178 }, PSYCHIC = { 250, 146, 178 },
    BUG = { 198, 209, 110 }, ROCK = { 209, 193, 125 },
    GHOST = { 162, 146, 188 }, DRAGON = { 162, 125, 250 },
    DARK = { 162, 146, 136 }, STEEL = { 209, 209, 224 },
    FAIRY = { 244, 189, 201 }, CURSE_TYPE = { 157, 193, 183 },
  }
  local UNKNOWN_COLOR = { 216, 216, 216 }
  function C.typeColor(t)
    return C.TYPE_COLORS[tostring(t or "")] or UNKNOWN_COLOR
  end

  function C.typeName(t, data)
    local ok, TypeChart = pcall(require, "src.battle.TypeChart")
    if ok and type(TypeChart.displayName) == "function" then
      local ok2, name = pcall(TypeChart.displayName, t, data)
      if ok2 and name then return tostring(name) end
    end
    return (tostring(t or "???"):gsub("_TYPE$", ""):gsub("_", " "))
  end

  ---------------------------------------------------------------------------
  -- Proportional text (glyph widths read from the font sheets, like the HUD)
  ---------------------------------------------------------------------------
  local fontDef, pageList, sheetData, bounds = nil, nil, {}, {}
  function C.setFont(def)
    if def ~= fontDef then fontDef, pageList, bounds = def, nil, {} end
  end
  local function pages()
    if pageList then return pageList end
    local byId = {}
    local def = fontDef or {}
    if def.image then
      byId.main = { image = def.image, base = def.mainBase or 0x80, perRow = def.glyphsPerRow }
    end
    if def.imageExtra then
      byId.extra = { image = def.imageExtra, base = def.extraBase or 0x60, perRow = def.glyphsPerRow }
    end
    for id, page in pairs(def.pages or {}) do
      if type(page) == "table" and page.image and not page.inactive then
        byId[id] = { image = page.image, base = page.base or 0x80, perRow = page.glyphsPerRow }
      end
    end
    pageList = {}
    for _, page in pairs(byId) do pageList[#pageList + 1] = page end
    table.sort(pageList, function(a, b) return a.base > b.base end)
    return pageList
  end
  local function sheet(path)
    local cached = sheetData[path]
    if cached == nil then
      local ok, data = pcall(Assets.imageData, path)
      cached = ok and data or false
      sheetData[path] = cached
    end
    return cached or nil
  end
  local function measure(code)
    for _, page in ipairs(pages()) do
      if code >= page.base then
        local data = sheet(page.image)
        if not data then return nil end
        local w, h = data:getDimensions()
        local perRow = page.perRow or math.floor(w / 8)
        local index = code - page.base
        local x0 = (index % perRow) * 8
        local y0 = math.floor(index / perRow) * 8
        if x0 + 8 > w or y0 + 8 > h then return nil end
        local first, last
        for px = 0, 7 do
          for py = 0, 7 do
            local r, g, b, a = data:getPixel(x0 + px, y0 + py)
            if a > 0.5 and (r + g + b) / 3 < 0.75 then
              first = first or px
              last = px
              break
            end
          end
        end
        if not first then return 0, -1 end
        return first, last
      end
    end
    return nil
  end
  local function glyphBounds(code)
    local cached = bounds[code]
    if cached then return cached[1], cached[2] end
    local left, right
    local okTtf, ttf = pcall(Font.ttfActive)
    if okTtf and ttf and code >= 0x10000 then
      left, right = 0, math.max(0, (Font.advanceOf(code) or 8) - 2)
    else
      local ok, l, r = pcall(measure, code)
      if ok and l then left, right = l, r else left, right = 0, 7 end
    end
    bounds[code] = { left, right }
    return left, right
  end
  local function encode(text)
    local ok, codes = pcall(Font.encode, tostring(text or ""))
    return ok and codes or {}
  end
  local function layout(codes, gap)
    local items, width = {}, 0
    for i, code in ipairs(codes) do
      local left, right = glyphBounds(code)
      local w = right - left + 1
      if w <= 0 then
        items[i] = { code = code, offset = 0, advance = 3, blank = true }
        width = width + 3
      else
        items[i] = { code = code, offset = left, advance = w + gap }
        width = width + w + gap
      end
    end
    if #items > 0 and not items[#items].blank then width = width - gap end
    return items, width
  end
  local function drawRun(items, x, y)
    local pen = x
    for _, item in ipairs(items) do
      if not item.blank then Font.drawCode(item.code, pen - item.offset, y) end
      pen = pen + item.advance
    end
    return pen
  end
  -- Text in at most `budget` px: 1 px between letters, then none, then cut.
  function C.drawFit(text, x, y, budget)
    local codes = encode(text)
    local items, width = layout(codes, 1)
    if width > budget then items, width = layout(codes, 0) end
    if width > budget then
      local kept, used = {}, 0
      for _, item in ipairs(items) do
        if used + item.advance > budget then break end
        kept[#kept + 1] = item
        used = used + item.advance
      end
      items = kept
    end
    G.setColor(0, 0, 0, 1)
    return drawRun(items, x, y)
  end
  function C.fitWidth(text)
    local _, w = layout(encode(text), 1)
    return w
  end
  -- "35/35" with the slash at a fixed pixel.
  function C.drawPP(cur, max, slashX, y)
    local slash = (encode("/"))[1]
    local leftItems, leftW = layout(encode(tostring(cur)), 1)
    local rightItems = layout(encode(tostring(max)), 1)
    local slashW = 4
    G.setColor(0, 0, 0, 1)
    if slash then
      local l, r = glyphBounds(slash)
      slashW = math.max(1, r - l + 1)
      Font.drawCode(slash, slashX - l, y)
    end
    drawRun(leftItems, slashX - 1 - leftW, y)
    drawRun(rightItems, slashX + slashW + 1, y)
  end

  ---------------------------------------------------------------------------
  -- Mini font (the Dex's SELECT tag letters), for the hint under the table
  ---------------------------------------------------------------------------
  local MINI = {
    A = { "010", "101", "111", "101", "101" }, C = { "111", "100", "100", "100", "111" },
    D = { "110", "101", "101", "101", "110" }, E = { "111", "100", "110", "100", "111" },
    I = { "111", "010", "010", "010", "111" }, L = { "100", "100", "100", "100", "111" },
    N = { "110", "101", "101", "101", "101" }, O = { "111", "101", "101", "101", "111" },
    P = { "111", "101", "111", "100", "100" }, R = { "110", "101", "110", "101", "101" },
    S = { "111", "100", "111", "001", "111" }, T = { "111", "010", "010", "010", "010" },
    B = { "110", "101", "110", "101", "110" }, K = { "101", "101", "110", "101", "101" },
    M = { "10001", "11011", "10101", "10001", "10001" }, V = { "101", "101", "101", "101", "010" },
    W = { "10001", "10001", "10101", "11011", "10001" }, U = { "101", "101", "101", "101", "111" },
    ["/"] = { "001", "001", "010", "100", "100" },
    [":"] = { "0", "1", "0", "1", "0" }, [" "] = { "0", "0" , "0", "0", "0" },
  }
  function C.miniWidth(str)
    local w = 0
    for ch in tostring(str):gmatch(".") do w = w + #(MINI[ch] or MINI[" "])[1] + 1 end
    return math.max(0, w - 1)
  end
  function C.miniText(str, x, y, c)
    rgb(c or { 0, 0, 0 })
    for ch in tostring(str):gmatch(".") do
      local g = MINI[ch] or MINI[" "]
      for row = 1, 5 do
        local bits = g[row]
        for col = 1, #bits do
          if bits:sub(col, col) == "1" then G.rectangle("fill", x + col - 1, y + row - 1, 1, 1) end
        end
      end
      x = x + #g[1] + 1
    end
  end
  -- A grey rounded pill centred on the screen with mini text in it.
  function C.hintPill(str, y)
    local w = C.miniWidth(str) + 10
    local x = math.floor((160 - w) / 2)
    rgb({ 195, 195, 195 })
    G.rectangle("fill", x, y, w, 9, 3, 3)
    C.miniText(str, x + 5, y + 2, { 0, 0, 0 })
    return x, y, w, 9
  end

  ---------------------------------------------------------------------------
  -- Moves table (the Highlander HUD's, without the effectiveness column)
  ---------------------------------------------------------------------------
  C.TABLE = { left = 16, right = 144, sep = 103, top = 93, pitch = 9 }
  -- rows: { { name, type, pp, maxPp } or false, x4 }; returns the table rect.
  function C.drawMovesTable(rows, markTrueColor)
    local T = C.TABLE
    local bottom = T.top + 4 * T.pitch - 1
    G.push("all")
    G.setShader()
    -- outer frame
    rect({ 0, 0, 0 }, T.left - 1, T.top - 1, T.right - T.left + 2, bottom - T.top + 3)
    for i = 1, 4 do
      local top = T.top + (i - 1) * T.pitch
      local h = T.pitch - 1
      local row = rows[i]
      local fill = row and C.typeColor(row.type) or { 255, 255, 255 }
      rect(fill, T.left, top, T.sep - T.left, h)
      rect({ 255, 255, 255 }, T.sep + 1, top, T.right - T.sep - 1, h)
    end
    if markTrueColor then
      pcall(markTrueColor, T.left - 1, T.top - 1, T.right - T.left + 2, bottom - T.top + 3)
    end
    for i = 1, 4 do
      local y = T.top + (i - 1) * T.pitch
      local row = rows[i]
      if row then
        C.drawFit(row.name, T.left + 3, y, T.sep - T.left - 5)
        if row.pp and row.maxPp then
          C.drawPP(row.pp, row.maxPp, math.floor((T.sep + T.right) / 2) - 3, y)
        end
      else
        C.drawFit("-", T.left + 3, y, 20)
      end
    end
    G.pop()
  end

  ---------------------------------------------------------------------------
  -- Gen 1 move descriptions
  ---------------------------------------------------------------------------
  local descByIndex, descByKey
  local function loadDescriptions()
    if descByIndex then return end
    descByIndex, descByKey = {}, {}
    local ok, t = pcall(mod.load, mod, "move_descriptions.lua")
    if not ok or type(t) ~= "table" then return end
    for index, row in pairs(t) do
      descByIndex[index] = row
      if row.id then descByKey[clean(row.id)] = row end
      if row.name then descByKey[clean(row.name)] = row end
    end
  end
  function C.moveDescription(id, def, gen1)
    if type(def) == "table" and type(def.description) == "string"
        and def.description ~= "" then
      return def.description
    end
    loadDescriptions()
    local row = descByKey[clean(id)]
      or (type(def) == "table" and (descByKey[clean(def.name)]
        or descByIndex[tonumber(def.index) or tonumber(def.num) or -1]
        or descByIndex[tonumber(def.id) or -1]))
    if not row then return "" end
    return (gen1 and row.gen1) or row.text or ""
  end

  ---------------------------------------------------------------------------
  -- POKE ICONS > ICONS FOR PARTY (WILD FOLLOWERS or the game's own)
  ---------------------------------------------------------------------------
  function C.drawFollowerIcon(game, mon, x, y, animate, counter)
    local icons = mod.highlander and mod.highlander.pokeIcons
    if not (icons and icons.wants and icons.wants("party", "followers")) then return false end
    local ok, drew = pcall(icons.draw, game, mon, x, y,
      { animate = animate, counter = counter, size = 16 })
    return ok and drew == true
  end

  ---------------------------------------------------------------------------
  -- Menu sounds (the game's own: Gen 1 PRESS_AB, Gen 2 READ_TEXT_2)
  ---------------------------------------------------------------------------
  function C.menuSound(game, gen2)
    local data = game and game.data
    if not data then return end
    local okS, Sound = pcall(require, "src.core.Sound")
    if not okS then return end
    local name = gen2 and "Sfx_ReadText2" or "Press_AB"
    if gen2 then
      local sfx = data.audio and data.audio.sfx
      local okR, key = pcall(Sound.resolve, data, name)
      if not (sfx and okR and sfx[key]) then return end
    end
    pcall(Sound.play, data, name)
  end

  return C
end
