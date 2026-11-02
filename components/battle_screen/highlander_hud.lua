-- HIGHLANDER HUD: the move menu as one full-width box, 3 columns x 4 rows.
--   column 1  the move name on its type's colour, with the selection arrow
--   column 2  PP, lined up on the "/"
--   column 3  how well the move hits the foe: 0x, ½x, 1x or 2x
-- Shared by Gen 1 (gen1.lua) and Gen 2 (gen2.lua); each passes its own rows
-- and its own way of drawing a glyph in black.
return function(mod)
  local Font = require("src.render.Font")

  local M = {}

  -- Layout inside the battle text box (x 0-159, y 96-143). The box frame
  -- keeps x 0-4 / 156-159 and y 96-101 / 138-143.
  -- Rows are 8 px for 7-px letters, so the text sits 1 px down from each
  -- row's top line: a gap above the capitals, and letters with a tail
  -- (g, p, y) just touch the line below.
  local TEXT_DROP = 1
  local LEFT, RIGHT = 5, 155
  local NAME_X1, SEP1 = 5, 99          -- name column x 5-98
  local PP_X1, SEP2 = 100, 140         -- PP column x 100-139
  local ICON_X1 = 141                  -- icon column x 141-155
  local ROW_TOP, ROW_PITCH = 102, 9    -- rows at y 102, 111, 120, 129
  local LAST_ROW_BOTTOM = 137
  local ARROW_X = 6
  local NAME_START = 13
  local NAME_END = SEP1 - 2            -- last pixel a name may use

  -- Light type colours, dark enough to read and light enough for black text.
  M.TYPE_COLORS = {
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
  local DISABLED_COLOR = { 176, 176, 176 }

  -- Effectiveness icons (drawn in code from the user's artwork, 7 px tall).
  local DIGITS = {
    ["0"] = { ".###.", "##.##", "##.##", "##.##", "##.##", "##.##", ".###." },
    ["1"] = { ".##..", "###..", ".##..", ".##..", ".##..", ".##..", "####." },
    ["2"] = { ".###.", "##.##", "...##", "..##.", ".##..", "##...", "#####" },
    half = { ".#....#.", "##....#.", ".#...#..", "###.#...", "...#.##.",
      "..#....#", ".#....#.", "#....###" },
  }
  local SMALL_X = { "##.##", ".###.", "..#..", ".###.", "##.##" }

  local function blit(map, x, y)
    for r, line in ipairs(map) do
      for c = 1, #line do
        if line:sub(c, c) == "#" then
          love.graphics.rectangle("fill", x + c - 1, y + r - 1, 1, 1)
        end
      end
    end
  end

  -- x10 multiplier -> icon. 4x shows as 2x and ¼x as ½x.
  local function drawIcon(mult, x, y)
    local key
    if mult == nil then return end
    if mult <= 0 then key = "0"
    elseif mult < 10 then key = "half"
    elseif mult == 10 then key = "1"
    else key = "2" end
    local map = DIGITS[key]
    local width = #map[1] + 1 + #SMALL_X[1]
    local left = x + math.floor((RIGHT - ICON_X1 + 1 - width) / 2)
    -- 7-row icons drop with the text; the 8-row ½ fills its row.
    if #map < 8 then y = y + TEXT_DROP end
    love.graphics.setColor(0, 0, 0, 1)
    blit(map, left, y)
    blit(SMALL_X, left + #map[1] + 1, y + #map - 5)
  end

  -- ------------------------------------------------- proportional glyph widths
  -- Each glyph's visible columns, read once straight from the font sheet's
  -- pixels (CPU side, no drawing), so 13 letters fit where 13 full 8-px
  -- tiles would not.
  local Assets = require("src.render.Assets")
  local fontDef
  local pageList
  local sheetData = {}
  local bounds = {}

  function M.setFont(def)
    if def ~= fontDef then
      fontDef, pageList, bounds = def, nil, {}
    end
  end

  -- The same pages Font.load builds (main $80, extra $60, mod pages), highest
  -- base first, so a code resolves to the sheet the game draws it from.
  local function pages()
    if pageList then return pageList end
    local byId = {}
    local def = fontDef or {}
    if def.image then
      byId.main = { image = def.image, base = def.mainBase or 0x80,
        perRow = def.glyphsPerRow }
    end
    if def.imageExtra then
      byId.extra = { image = def.imageExtra, base = def.extraBase or 0x60,
        perRow = def.glyphsPerRow }
    end
    for id, page in pairs(def.pages or {}) do
      if type(page) == "table" and page.image and not page.inactive then
        byId[id] = { image = page.image, base = page.base or 0x80,
          perRow = page.glyphsPerRow }
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

  local SPACE_ADVANCE = 3

  local function layout(codes, gap)
    local items, width = {}, 0
    for i, code in ipairs(codes) do
      local left, right = glyphBounds(code)
      local w = right - left + 1
      if w <= 0 then
        items[i] = { code = code, offset = 0, advance = SPACE_ADVANCE, blank = true }
        width = width + SPACE_ADVANCE
      else
        items[i] = { code = code, offset = left, advance = w + gap }
        width = width + w + gap
      end
    end
    if #items > 0 and not items[#items].blank then width = width - gap end
    return items, width
  end

  local function drawRun(items, x, y, drawGlyph)
    local pen = x
    for _, item in ipairs(items) do
      if not item.blank then drawGlyph(item.code, pen - item.offset, y) end
      pen = pen + item.advance
    end
    return pen
  end

  local function encode(text)
    local ok, codes = pcall(Font.encode, tostring(text or ""))
    return ok and codes or {}
  end

  local function firstCode(text, fallback)
    local codes = encode(text)
    return (#codes == 1 and codes[1]) or fallback
  end

  -- A name in at most `budget` px: 1 px between letters, then none, then cut.
  local function drawName(text, x, y, budget, drawGlyph)
    local codes = encode(text)
    local items, width = layout(codes, 1)
    if width > budget then items, width = layout(codes, 0) end
    if width > budget then
      local kept, used = {}, 0
      for _, item in ipairs(items) do
        local w = item.blank and item.advance or (item.advance)
        if used + w > budget then break end
        kept[#kept + 1] = item
        used = used + w
      end
      items = kept
    end
    drawRun(items, x, y, drawGlyph)
  end

  local function drawPP(cur, max, y, drawGlyph)
    local slash = firstCode("/", nil)
    local leftItems, leftW = layout(encode(tostring(cur)), 1)
    local rightItems = layout(encode(tostring(max)), 1)
    local center = math.floor((PP_X1 + SEP2 - 1) / 2) + 1
    local slashLeft = center - 2
    local slashW = 4
    if slash then
      local l, r = glyphBounds(slash)
      slashW = math.max(1, r - l + 1)
      slashLeft = center - math.floor(slashW / 2)
      drawGlyph(slash, slashLeft - l, y)
    end
    drawRun(leftItems, slashLeft - 1 - leftW, y, drawGlyph)
    drawRun(rightItems, slashLeft + slashW + 1, y, drawGlyph)
  end

  -- ctx = {
  --   rows = { { name, type, pp, maxPp, mult, disabled } or false, x4 },
  --   cursor = 1-4, swap = 1-4 or nil,
  --   drawGlyph = function(code, x, y) (black), finish = function() or nil,
  --   x = 0, y = 0 (shake offset), markTrueColor = function(x, y, w, h) or nil,
  --   font = the game's data.font (where the glyph widths are read from),
  -- }
  function M.draw(ctx)
    M.setFont(ctx.font)
    local g = love.graphics
    g.push("all")
    g.setShader()
    g.translate(ctx.x or 0, ctx.y or 0)
    local drawGlyph = ctx.drawGlyph
    -- Cells
    for i = 1, 4 do
      local top = ROW_TOP + (i - 1) * ROW_PITCH
      local bottom = i == 4 and LAST_ROW_BOTTOM or top + ROW_PITCH - 2
      local h = bottom - top + 1
      local row = ctx.rows[i]
      local fill = { 255, 255, 255 }
      if row then
        fill = row.disabled and DISABLED_COLOR
          or M.TYPE_COLORS[row.type or ""] or UNKNOWN_COLOR
      end
      g.setColor(fill[1] / 255, fill[2] / 255, fill[3] / 255, 1)
      g.rectangle("fill", NAME_X1, top, SEP1 - NAME_X1, h)
      g.setColor(1, 1, 1, 1)
      g.rectangle("fill", PP_X1, top, SEP2 - PP_X1, h)
      g.rectangle("fill", ICON_X1, top, RIGHT - ICON_X1 + 1, h)
    end
    -- Grid lines
    g.setColor(0, 0, 0, 1)
    for i = 1, 3 do
      g.rectangle("fill", LEFT, ROW_TOP + i * ROW_PITCH - 1, RIGHT - LEFT + 1, 1)
    end
    g.rectangle("fill", SEP1, ROW_TOP, 1, LAST_ROW_BOTTOM - ROW_TOP + 1)
    g.rectangle("fill", SEP2, ROW_TOP, 1, LAST_ROW_BOTTOM - ROW_TOP + 1)
    if ctx.markTrueColor then
      pcall(ctx.markTrueColor, LEFT + (ctx.x or 0), ROW_TOP + (ctx.y or 0),
        RIGHT - LEFT + 1, LAST_ROW_BOTTOM - ROW_TOP + 1)
    end
    -- Text and icons
    local arrow = firstCode("▶", 0xED)
    local hollow = firstCode("▷", 0xEC)
    for i = 1, 4 do
      local rowTop = ROW_TOP + (i - 1) * ROW_PITCH
      local y = rowTop + TEXT_DROP
      local row = ctx.rows[i]
      g.setColor(0, 0, 0, 1)
      if i == ctx.cursor then
        local l = glyphBounds(arrow)
        drawGlyph(arrow, ARROW_X - l, y)
      elseif ctx.swap == i then
        local l = glyphBounds(hollow)
        drawGlyph(hollow, ARROW_X - l, y)
      end
      if row then
        drawName(row.name, NAME_START, y, NAME_END - NAME_START + 1, drawGlyph)
        if row.pp and row.maxPp then drawPP(row.pp, row.maxPp, y, drawGlyph) end
        g.setColor(0, 0, 0, 1)
        drawIcon(row.mult, ICON_X1, rowTop)
      else
        drawName("-", NAME_START, y, NAME_END - NAME_START + 1, drawGlyph)
      end
    end
    if ctx.finish then pcall(ctx.finish) end
    g.pop()
  end

  -- ------------------------------------------------------------- Help (START)
  -- Type names in their own colour (a deeper shade of the HUD colour, so it
  -- reads on white) and what each effectiveness icon means.
  M.TEXT_COLORS = {
    NORMAL = { 150, 150, 110 }, FIRE = { 230, 80, 30 }, WATER = { 50, 100, 230 },
    ELECTRIC = { 215, 165, 0 }, GRASS = { 70, 165, 30 }, ICE = { 50, 170, 180 },
    FIGHTING = { 190, 45, 40 }, POISON = { 155, 60, 155 },
    GROUND = { 180, 140, 50 }, FLYING = { 125, 100, 225 },
    PSYCHIC_TYPE = { 230, 60, 115 }, PSYCHIC = { 230, 60, 115 },
    BUG = { 130, 150, 20 }, ROCK = { 150, 125, 35 }, GHOST = { 110, 85, 150 },
    DRAGON = { 110, 55, 240 }, DARK = { 105, 80, 65 }, STEEL = { 120, 120, 155 },
    FAIRY = { 215, 100, 140 }, CURSE_TYPE = { 90, 150, 135 },
  }
  local TYPE_ORDER = {
    "NORMAL", "FIRE", "WATER", "ELECTRIC", "GRASS", "ICE", "FIGHTING",
    "POISON", "GROUND", "FLYING", "PSYCHIC_TYPE", "BUG", "ROCK", "GHOST",
    "DRAGON", "DARK", "STEEL", "FAIRY", "CURSE_TYPE",
  }

  -- Draws any font glyph in the current colour (the sheets are black ink).
  local tintShader
  local function tint()
    if tintShader == nil then
      local ok, shader = pcall(love.graphics.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 t = Texel(tex, tc);
          float lum = (t.r + t.g + t.b) / 3.0;
          float ink = t.a * step(lum, 0.6);
          return vec4(color.rgb, ink * color.a);
        }
      ]])
      tintShader = ok and shader or false
    end
    return tintShader or nil
  end

  local function plainGlyph(code, x, y) Font.drawCode(code, x, y) end

  local function typesIn(data)
    local present = {}
    local chart = data and data.type_chart
    for id in pairs(chart and chart.types or {}) do present[id] = true end
    for _, row in ipairs(chart and chart.matchups or {}) do
      present[row.attacker], present[row.defender] = true, true
    end
    local okTC, TypeChart = pcall(require, "src.battle.TypeChart")
    if not next(present) and okTC then
      for id in pairs(TypeChart.TYPES or {}) do present[id] = true end
    end
    local list = {}
    for _, id in ipairs(TYPE_ORDER) do
      if present[id] then
        local name = id == "CURSE_TYPE" and "???" or id
        if okTC and type(TypeChart.displayName) == "function" then
          local ok, shown = pcall(TypeChart.displayName, id, data)
          if ok and shown then name = shown end
        end
        list[#list + 1] = { id = id, name = name }
      end
    end
    return list
  end

  -- The game's own casing: mixed case when its strings are ("Type/").
  local function label(caps, mixed)
    local ok, Strings = pcall(require, "src.core.Strings")
    local useMixed = false
    if ok then
      local okT, sample = pcall(Strings, "TYPE/")
      useMixed = okT and type(sample) == "string" and sample:find("%l") ~= nil
    end
    return useMixed and mixed or caps
  end

  local function box(x, y, w, h)
    local g = love.graphics
    g.setShader()
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", x, y, w, h)
    g.setShader(tint())
    g.setColor(0, 0, 0, 1)
    local B = Font.BORDER or {}
    local tl, tr, bl, br = B.tl or 0x79, B.tr or 0x7B, B.bl or 0x7D, B.br or 0x7E
    local hz, vt = B.h or 0x7A, B.v or 0x7C
    local cols, rows = w / 8, h / 8
    Font.drawCode(tl, x, y)
    Font.drawCode(tr, x + w - 8, y)
    Font.drawCode(bl, x, y + h - 8)
    Font.drawCode(br, x + w - 8, y + h - 8)
    for i = 1, cols - 2 do
      Font.drawCode(hz, x + i * 8, y)
      Font.drawCode(hz, x + i * 8, y + h - 8)
    end
    for j = 1, rows - 2 do
      Font.drawCode(vt, x, y + j * 8)
      Font.drawCode(vt, x + w - 8, y + j * 8)
    end
  end

  -- ctx = { data = the game's data, font = data.font, markTrueColor = fn or nil }
  function M.drawHelp(ctx)
    M.setFont(ctx.font)
    local g = love.graphics
    g.push("all")
    box(0, 0, 160, 144)
    g.setShader(tint())
    local budget = 46

    g.setColor(0, 0, 0, 1)
    drawName(label("TYPES", "Types"), 10, 9, 140, plainGlyph)
    local types = typesIn(ctx.data)
    for i, t in ipairs(types) do
      local col = (i - 1) % 3
      local row = math.floor((i - 1) / 3)
      local c = M.TEXT_COLORS[t.id] or { 0, 0, 0 }
      g.setColor(c[1] / 255, c[2] / 255, c[3] / 255, 1)
      drawName(t.name, 10 + col * 48, 19 + row * 9, budget, plainGlyph)
    end

    local top = 19 + math.ceil(#types / 3) * 9 + 4
    g.setColor(0, 0, 0, 1)
    drawName(label("EFFECTIVENESS", "Effectiveness"), 10, top, 140, plainGlyph)
    local lines = {
      { 0, label("NO EFFECT", "No effect") },
      { 5, label("NOT VERY EFFECTIVE", "Not very effective") },
      { 10, label("NORMAL DAMAGE", "Normal damage") },
      { 20, label("SUPER EFFECTIVE", "Super effective") },
    }
    for i, line in ipairs(lines) do
      local y = top + 10 + (i - 1) * 9
      g.setShader()
      drawIcon(line[1], 8, y - 1)
      g.setShader(tint())
      g.setColor(0, 0, 0, 1)
      drawName(line[2], 26, y, 126, plainGlyph)
    end
    g.pop()
    if ctx.markTrueColor then pcall(ctx.markTrueColor, 0, 0, 160, 144) end
  end

  -- x10 type multiplier, one matchup row at a time with flooring between
  -- (the battle's own rule, so 4x and ¼x happen and Steel/Fairy rows count).
  function M.multiplier(data, moveType, defenderTypes)
    if not moveType or type(defenderTypes) ~= "table" then return nil end
    local matchups = data and data.type_chart and data.type_chart.matchups
    local mult = 10
    for _, row in ipairs(matchups or {}) do
      if row.attacker == moveType then
        for _, defender in ipairs(defenderTypes) do
          if row.defender == defender then
            mult = math.floor(mult * row.multiplier / 10)
            break
          end
        end
      end
    end
    return mult
  end

  return M
end
