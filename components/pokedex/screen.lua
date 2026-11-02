-- PH Pokédex screens (Gen 1 and Gen 2): list, OPTION, SEARCH, entry page,
-- STATS / FAMILY / MOVES pop-ups and the LOCATIONS chart. Everything is drawn
-- at the Game Boy's own 160x144, so Custom Borders frames it like any other
-- full screen. Gold/Silver/Crystal's nest map and UNOWN MODE are the game's
-- own screens, shown inside the same frame.
return function(mod, D)
  local G = love.graphics
  local Font = require("src.render.Font")
  local MenuRepeat = require("src.ui.MenuRepeat")
  local Sound = require("src.core.Sound")
  local Strings = require("src.core.Strings")

  local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }
  local GREY = { 104, 104, 112 }
  local YELLOW = { 248, 224, 64 }
  local ROW_BG = { 64, 64, 76 }

  -- One frame colour per game.
  local THEMES = {
    red = { main = { 208, 56, 40 }, dark = { 120, 20, 16 }, light = { 248, 160, 136 } },
    blue = { main = { 48, 96, 216 }, dark = { 16, 40, 128 }, light = { 152, 184, 248 } },
    green = { main = { 56, 160, 72 }, dark = { 16, 88, 32 }, light = { 152, 224, 152 } },
    yellow = { main = { 232, 184, 24 }, dark = { 136, 96, 8 }, light = { 248, 224, 128 } },
    gold = { main = { 200, 144, 40 }, dark = { 112, 72, 8 }, light = { 240, 208, 128 } },
    silver = { main = { 144, 152, 168 }, dark = { 72, 80, 96 }, light = { 216, 220, 232 } },
    crystal = { main = { 64, 152, 208 }, dark = { 16, 72, 128 }, light = { 168, 216, 240 } },
  }

  local function themeFor(ctx)
    local key = ctx.key
    if key == "blue" and mod.highlander and mod.highlander.option then
      local ok, v = pcall(mod.highlander.option, "other_settings", "blue_into_green")
      if ok and v == true then key = "green" end
    end
    return THEMES[key] or (ctx.gen == 2 and THEMES.gold or THEMES.red)
  end

  ---------------------------------------------------------------------------
  -- Drawing primitives
  ---------------------------------------------------------------------------
  local function rgb(c, a) G.setColor(c[1] / 255, c[2] / 255, c[3] / 255, a or 1) end
  local function rect(c, x, y, w, h)
    rgb(c)
    G.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
  end
  local function box(x, y, w, h, border, fill)
    rect(border, x, y, w, h)
    rect(fill, x + 1, y + 1, w - 2, h - 2)
  end
  local function pill(c, x, y, w, h, r)
    rgb(c)
    G.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h), r or 3, r or 3)
  end
  local function arrow(x, y, c)
    rgb(c)
    G.polygon("fill", x, y, x, y + 7, x + 4, y + 3.5)
  end
  local function now() return love.timer and love.timer.getTime() or 0 end

  -- Font tiles are dark on transparent: draw them as a mask in any colour.
  -- A TTF translation font is white coverage, so it takes the alpha path.
  local maskShader, alphaShader
  local function inkShader()
    if not G.newShader then return nil end
    if Font.ttfActive and Font.ttfActive() then
      if alphaShader == nil then
        local ok, sh = pcall(G.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 p = Texel(tex, tc);
            return vec4(color.rgb, p.a * color.a);
          }
        ]])
        alphaShader = ok and sh or false
      end
      return alphaShader or nil
    end
    if maskShader == nil then
      local ok, sh = pcall(G.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc);
          float m = p.r < 0.5 ? p.a : 0.0;
          return vec4(color.rgb, m * color.a);
        }
      ]])
      maskShader = ok and sh or false
    end
    return maskShader or nil
  end

  local function withInk(c, fn)
    local sh = inkShader()
    G.push("all")
    if sh then G.setShader(sh); rgb(c) else G.setColor(0, 0, 0, 1) end
    local ok, err = pcall(fn)
    G.pop()
    if not ok then error(err, 0) end
  end

  -- ':' '%' and the feet/inch marks are drawn as pixels: the Gen 1 and Gen 2
  -- charmaps don't agree on them.
  local SPECIAL = { [":"] = 5, ["%"] = 7, ["'"] = 3, ['"'] = 5 }
  local function drawSpecial(ch, x, y, c)
    if ch == ":" then
      rect(c, x + 1, y + 2, 2, 2); rect(c, x + 1, y + 5, 2, 2)
    elseif ch == "%" then
      rect(c, x, y + 1, 2, 2); rect(c, x + 4, y + 5, 2, 2)
      for i = 0, 7 do rect(c, x + 5 - math.floor(i * 5 / 7), y + i, 1, 1) end
    elseif ch == "'" then
      rect(c, x + 1, y, 1, 3)
    elseif ch == '"' then
      rect(c, x + 1, y, 1, 3); rect(c, x + 3, y, 1, 3)
    end
  end

  local tokCache, tokCount = {}, 0
  local function tokenize(str)
    str = tostring(str or "")
    local hit = tokCache[str]
    if hit then return hit end
    local toks = {}
    for seg, sp in str:gmatch("([^:%%'\"]*)([:%%'\"]?)") do
      if seg ~= "" then
        local ok, codes = pcall(Font.encode, seg)
        codes = (ok and type(codes) == "table") and codes or {}
        local ws, w = {}, 0
        for i, code in ipairs(codes) do
          local ok2, a = pcall(Font.advanceOf, code)
          ws[i] = ok2 and tonumber(a) or 8
          w = w + ws[i]
        end
        toks[#toks + 1] = { codes = codes, ws = ws, w = w }
      end
      if sp ~= "" then toks[#toks + 1] = { sp = sp, w = SPECIAL[sp] } end
      if seg == "" and sp == "" then break end
    end
    tokCount = tokCount + 1
    if tokCount > 3000 then tokCache, tokCount = {}, 0 end
    tokCache[str] = toks
    return toks
  end

  local function textWidth(str)
    local w = 0
    for _, t in ipairs(tokenize(str)) do w = w + t.w end
    return w
  end

  local function drawTokens(toks, pen, ty, c, single, from, to, squeeze)
    for _, t in ipairs(toks) do
      if t.sp then
        drawSpecial(t.sp, pen, ty, c)
        pen = pen + t.w
      else
        local a, b = 1, #t.codes
        if t == single then a, b = from, to or #t.codes end
        withInk(c, function()
          for i = a, b do
            Font.drawCode(t.codes[i], pen, ty)
            pen = pen + t.ws[i] - squeeze
          end
        end)
      end
    end
  end

  -- Text mixing letters with drawn marks (King's Rock, B:Back...) that is too
  -- long: drawn once into a small picture, then shown through a window that
  -- scrolls (marquee) or simply stops at the edge.
  local scrollCache, scrollCount = {}, 0
  local function drawScrolled(str, toks, total, x, y, c, o)
    local maxW = o.maxW
    local key = str .. "|" .. c[1] .. "," .. c[2] .. "," .. c[3]
    local cv = scrollCache[key]
    if cv == nil then
      local okC, canvas = pcall(G.newCanvas, total, 10)
      cv = false
      if okC and canvas then
        canvas:setFilter("nearest", "nearest")
        G.push("all")
        G.setCanvas(canvas)
        G.origin()
        G.setScissor()
        G.clear(0, 0, 0, 0)
        pcall(drawTokens, toks, 0, 0, c, nil, 1, nil, 0)
        G.pop()
        cv = canvas
      end
      scrollCount = scrollCount + 1
      if scrollCount > 200 then scrollCache, scrollCount = {}, 0 end
      scrollCache[key] = cv
    end
    if not cv then return 0 end
    local over, off = total - maxW, 0
    if o.marquee then
      local hold, speed = 1.2, 24
      local period = hold * 2 + over / speed
      local ph = (now() + (o.phase or 0)) % period
      if ph >= hold then off = math.min(over, math.floor((ph - hold) * speed)) end
    end
    local px = x
    if o.align == "right" then px = x - maxW
    elseif o.align == "center" then px = x + math.floor(((o.width or 0) - maxW) / 2) end
    G.push("all")
    G.setShader()
    G.setColor(1, 1, 1, 1)
    G.setBlendMode("alpha", "premultiplied")
    G.draw(cv, G.newQuad(off, 0, maxW, 10, total, 10), math.floor(px), math.floor(y))
    G.pop()
    return maxW
  end

  -- opts: maxW, align ("right" at x / "center" in width), squeeze (px per
  -- gap allowed before giving up, default 2), marquee (scroll long text),
  -- phase (marquee offset in seconds).
  local function text(str, x, y, c, o)
    o = o or {}
    local toks = tokenize(str)
    local total = 0
    for _, t in ipairs(toks) do total = total + t.w end
    local single = #toks == 1 and toks[1].codes and toks[1] or nil
    local squeeze, from, to = 0, 1, nil
    local maxW = o.maxW
    if maxW and total > maxW and not single then
      return drawScrolled(tostring(str or ""), toks, total, x, y, c, o)
    end
    if maxW and total > maxW and single then
      local n = #single.codes
      local gaps = math.max(1, n - 1)
      local need = math.ceil((total - maxW) / gaps)
      if need <= (o.squeeze or 0) then
        squeeze = need
        total = total - squeeze * gaps
      else
        local function fitsFrom(s)
          local w = 0
          for i = s, n do
            w = w + single.ws[i]
            if w > maxW then return false end
          end
          return true
        end
        if o.marquee then
          local maxStart = 1
          while maxStart < n and not fitsFrom(maxStart) do maxStart = maxStart + 1 end
          local step, hold = 0.22, 1.2
          local period = hold * 2 + (maxStart - 1) * step
          local ph = (now() + (o.phase or 0)) % period
          from = 1
          if ph >= hold then from = math.min(maxStart, 1 + math.floor((ph - hold) / step)) end
        end
        local w = 0
        to = from - 1
        for i = from, n do
          if w + single.ws[i] > maxW then break end
          w = w + single.ws[i]
          to = i
        end
        total = w
      end
    end
    local px = x
    if o.align == "right" then px = x - total
    elseif o.align == "center" then px = x + math.floor(((o.width or 0) - total) / 2) end
    drawTokens(toks, math.floor(px), math.floor(y), c, single, from, to, squeeze)
    return total
  end

  local function wrap(str, maxW, maxLines)
    local lines, cur = {}, ""
    for word in tostring(str or ""):gmatch("%S+") do
      local try = cur == "" and word or (cur .. " " .. word)
      if textWidth(try) <= maxW or cur == "" then
        cur = try
      else
        lines[#lines + 1] = cur
        cur = word
        if #lines >= maxLines then return lines end
      end
    end
    if cur ~= "" and #lines < maxLines then lines[#lines + 1] = cur end
    return lines
  end

  local function hint(parts, y)
    -- parts: { { "B", "BACK" }, ... } drawn as "B:BACK  A:INFO" on a pill
    local strs = {}
    for _, p in ipairs(parts) do strs[#strs + 1] = p[1] .. ":" .. p[2] end
    local s = table.concat(strs, "  ")
    local w = textWidth(s) + 16
    pill(BLACK, math.floor(80 - w / 2), y, w, 12, 4)
    text(s, math.floor(80 - w / 2), y + 2, WHITE, { align = "center", width = w })
  end

  local function arrowHint(a, b, y)
    local w1, w2 = textWidth(a), textWidth(b)
    local w = w1 + w2 + 26
    local x = math.floor(80 - w / 2)
    pill(BLACK, x, y, w, 12, 4)
    text(a, x + 8, y + 2, WHITE)
    arrow(x + 8 + w1 + 3, y + 2, WHITE)
    text(b, x + 18 + w1, y + 2, WHITE)
  end

  local MINI = {
    S = { "111", "100", "111", "001", "111" }, E = { "111", "100", "110", "100", "111" },
    L = { "100", "100", "100", "100", "111" }, C = { "111", "100", "100", "100", "111" },
    T = { "111", "010", "010", "010", "010" }, O = { "111", "101", "101", "101", "111" },
    A = { "010", "101", "111", "101", "101" }, I = { "111", "010", "010", "010", "111" },
    N = { "110", "101", "101", "101", "101" }, [":"] = { "0", "1", "0", "1", "0" },
    [" "] = { "0", "0", "0", "0", "0" },
  }
  local MINI_LABEL = "SELECT: LOCATIONS"
  local function miniWidth(str)
    local w = 0
    for ch in str:gmatch(".") do w = w + #(MINI[ch] or MINI[" "])[1] + 1 end
    return w - 1
  end
  local function miniText(str, x, y, c)
    for ch in str:gmatch(".") do
      local g = MINI[ch] or MINI[" "]
      for row = 1, 5 do
        local bits = g[row]
        for col = 1, #bits do
          if bits:sub(col, col) == "1" then rect(c, x + col - 1, y + row - 1, 1, 1) end
        end
      end
      x = x + #g[1] + 1
    end
  end
  -- A small tag in a corner of the nest map: x/y is its top-left, or with
  -- right = true, x is its right edge.
  local function selectBox(x, y, right)
    local w = miniWidth(MINI_LABEL) + 6
    if right then x = x - w end
    G.push("all")
    G.setShader()
    rect(BLACK, x, y, w, 9)
    rect(WHITE, x + 1, y + 1, w - 2, 7)
    miniText(MINI_LABEL, x + 3, y + 2, BLACK)
    G.pop()
  end

  ---------------------------------------------------------------------------
  -- Pictures
  ---------------------------------------------------------------------------
  local imageCache = {}
  local function loadImage(path)
    if not path then return nil end
    local hit = imageCache[path]
    if hit == nil then
      local ok, img = false, nil
      local okA, Assets = pcall(require, "src.render.Assets")
      if okA then ok, img = pcall(Assets.image, path) end
      if not ok or not img then ok, img = pcall(G.newImage, path) end
      hit = (ok and img) or false
      if hit and hit.setFilter then hit:setFilter("nearest", "nearest") end
      imageCache[path] = hit
    end
    return hit or nil
  end

  local fourShader
  local function colorShader()
    if fourShader == nil then
      local ok, sh = pcall(G.newShader, [[
        extern vec3 c0; extern vec3 c1; extern vec3 c2; extern vec3 c3;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc);
          vec3 m = p.r > 0.83 ? c0 : (p.r > 0.5 ? c1 : (p.r > 0.17 ? c2 : c3));
          return vec4(m, p.a);
        }
      ]])
      fourShader = ok and sh or false
    end
    return fourShader or nil
  end

  local function sendFour(sh, colors)
    for i = 1, 4 do
      local c = colors[i] or colors[#colors] or { 0, 0, 0 }
      local r, g, b = c[1] or 0, c[2] or 0, c[3] or 0
      if r > 1 or g > 1 or b > 1 then r, g, b = r / 255, g / 255, b / 255 end
      sh:send("c" .. (i - 1), { r, g, b })
    end
  end

  local function crystalOption(key)
    if not (mod.highlander and mod.highlander.option) then return nil end
    local ok, v = pcall(mod.highlander.option, "crystal_animated_sprites_with_shiny_visuals", key)
    return ok and v or nil
  end

  -- Crystal's pictures: always in Crystal itself, and in the other five
  -- games when CRYSTAL > POKéDEX PICTURES is ON.
  local function crystalSource(self)
    local handle = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
    local src = handle and handle.exports and handle.exports.crystalSource
    if not (src and type(src.dexFrames) == "function") then return nil end
    local okA, avail = pcall(src.available)
    if not (okA and avail) then return nil end
    if self.ctx.key == "crystal" then return src end
    return crystalOption("crystalDexPictures") == true and src or nil
  end

  -- The species' own Gen 1 colours (the same ones the game's Pokédex uses).
  local function gen1Colors(ctx, sp)
    local okF, PaletteFX = pcall(require, "src.render.PaletteFX")
    if not okF then return nil end
    local function valid(c)
      return type(c) == "table" and type(c[1]) == "table" and #c >= 4 and c or nil
    end
    local okC, c = pcall(PaletteFX.monPal, ctx.data, sp)
    c = okC and valid(c) or nil
    if not c and PaletteFX.monPalName then
      local okN, name = pcall(PaletteFX.monPalName, ctx.data, sp)
      if okN and name then
        local okP, pal = pcall(PaletteFX.pal, ctx.data, name)
        c = okP and valid(pal) or nil
        local pals = ctx.data.palettes and ctx.data.palettes.palettes
        if not c and type(pals) == "table" then c = valid(pals[name]) end
      end
    end
    if not c then
      local pals = ctx.data.palettes
      local name = pals and pals.pokemon and pals.pokemon[sp]
      c = name and pals.palettes and valid(pals.palettes[name]) or nil
    end
    if c and PaletteFX.effectiveColors then
      local okE, e = pcall(PaletteFX.effectiveColors, c)
      if okE and valid(e) then c = e end
    end
    return c
  end

  local crystalCache = {}
  local function crystalSet(src, no)
    local hit = crystalCache[no]
    if hit == nil then
      hit = false
      local ok, set = pcall(src.dexFrames, no)
      if ok and type(set) == "table" and type(set.images) == "table" then
        local images = {}
        for _, data in ipairs(set.images) do
          local okI, img = pcall(G.newImage, data)
          if okI and img then
            img:setFilter("nearest", "nearest")
            images[#images + 1] = img
          end
        end
        if #images > 0 then hit = { images = images, durations = set.durations or {} } end
      end
      crystalCache[no] = hit
    end
    return hit or nil
  end

  -- ANIMATIONS: LOOP repeats; PLAY ONCE plays once each time a Pokémon is
  -- shown, then rests on its first frame.
  local function crystalFrame(set, start)
    local n = #set.images
    if n <= 1 or not start then return set.images[1] end
    local total = 0
    for k = 1, n do total = total + (tonumber(set.durations[k]) or 120) end
    if total <= 0 then return set.images[1] end
    local t = (now() - start) * 1000
    if crystalOption("crystalAnimations") == "once" then
      if t >= total then return set.images[1] end
    else
      t = t % total
    end
    local acc = 0
    for k = 1, n do
      acc = acc + (tonumber(set.durations[k]) or 120)
      if t < acc then return set.images[k] end
    end
    return set.images[1]
  end

  -- A coloured picture of `sp` centred in a size x size square at x, y.
  -- animate: a slot name ("main") whose animation restarts when its
  -- Pokémon changes; without it the first frame is shown.
  local function drawPicture(self, sp, x, y, size, animate)
    local ctx = self.ctx
    local img, trueColor, colors
    local src = crystalSource(self)
    if src then
      local set = crystalSet(src, D.dexNo(ctx, sp))
      if set then
        local start
        if animate then
          self.animSlots = self.animSlots or {}
          local slot = self.animSlots[animate]
          if not slot or slot.sp ~= sp then
            slot = { sp = sp, start = now() }
            self.animSlots[animate] = slot
          end
          start = slot.start
        end
        img, trueColor = crystalFrame(set, start), true
      end
    end
    if not img then
      -- The game's own picture, straight from its files (no sprite swaps).
      local def = D.def(ctx, sp)
      local path = def and def.spriteFront
      img, trueColor = loadImage(path), def and def.trueColor and true or false
      if ctx.gen == 2 then
        local okP, Palettes = pcall(require, "src.world.gen2.Palettes")
        if okP and ctx.data.gen2Palettes then
          local okC, c = pcall(Palettes.monColors, ctx.data.gen2Palettes, sp)
          if okC then colors = c end
        end
      else
        colors = gen1Colors(ctx, sp)
      end
    end
    if not img then return end
    local w, h = img:getDimensions()
    local sc = math.min(1, size / w, size / h)
    local dx = math.floor(x + (size - w * sc) / 2)
    local dy = math.floor(y + (size - h * sc) / 2)
    G.push("all")
    G.setColor(1, 1, 1, 1)
    local function body() G.draw(img, dx, dy, 0, sc, sc) end
    if trueColor or not colors then
      G.setShader()
      body()
    elseif ctx.gen == 2 then
      local okG, GbcPalette = pcall(require, "src.render.GbcPalette")
      if okG and GbcPalette.available and GbcPalette.available() then
        GbcPalette.with(colors, body)
      else
        body()
      end
    else
      local sh = colorShader()
      if sh then G.setShader(sh); sendFour(sh, colors) end
      body()
    end
    G.pop()
  end

  local function questionMark(x, y, size, c)
    G.push("all")
    G.translate(x + math.floor(size / 2) - 12, y + math.floor(size / 2) - 12)
    G.scale(3, 3)
    text("?", 0, 0, c or GREY)
    G.pop()
  end

  local function playCry(ctx, sp)
    if not sp then return end
    local cries = ctx.data.audio and ctx.data.audio.cries
    if ctx.gen == 2 and cries and not cries[sp] then return end
    pcall(Sound.playCry, ctx.data, sp)
  end

  local function trueColorZones()
    local ok, PaletteFX = pcall(require, "src.render.PaletteFX")
    if not ok then return nil end
    return { PaletteFX.zone(false, 0, 0, 19, 17) }
  end

  local function repeatFor(ctx)
    local delay = ctx.gen == 2 and MenuRepeat.GEN2_DELAY or MenuRepeat.GEN1_DELAY
    local rate = ctx.gen == 2 and MenuRepeat.GEN2_RATE or MenuRepeat.GEN1_RATE
    return MenuRepeat.new(delay or 16, rate or 4)
  end

  local function pressed(input, k)
    local ok, v = pcall(input.wasPressed, input, k)
    return ok and v
  end

  -- The game's own menu blip on A and B (Gen 1 PRESS_AB, Gen 2 READ_TEXT_2).
  local function abSound(game, input)
    if not (pressed(input, "a") or pressed(input, "b")) then return end
    local data = game and game.data
    if not data then return end
    local GV = require("src.core.GameVersion")
    local gen2 = GV.generation and GV.generation() == 2
    local name = gen2 and "Sfx_ReadText2" or "Press_AB"
    if gen2 then
      local sfx = data.audio and data.audio.sfx
      local okR, key = pcall(Sound.resolve, data, name)
      if not (sfx and okR and sfx[key]) then return end
    end
    pcall(Sound.play, data, name)
  end

  ---------------------------------------------------------------------------
  -- LOCATIONS chart (its own screen: it opens from the nest map)
  ---------------------------------------------------------------------------
  local Loc = {}
  Loc.__index = Loc
  Loc.isOpaque = true
  Loc.screenId = "highlander_pokedex_locations"
  Loc.highlanderPokedex = true

  local LOC_ROWS = 8

  function Loc.new(owner, sp)
    local self = setmetatable({}, Loc)
    self.game, self.ctx, self.theme = owner.game, owner.ctx, owner.theme
    self.sp = sp
    self.sortIdx = 1
    self.rows = D.sortLocations(D.locations(self.ctx, sp), D.SORTS[1].id)
    self.sel, self.scroll = 1, 0
    self.hold = repeatFor(self.ctx)
    if self.ctx.gen == 1 then self.sgbPalettes = function() return trueColorZones() end end
    return self
  end

  function Loc:clamp()
    local n = #self.rows
    self.sel = math.max(1, math.min(self.sel, math.max(1, n)))
    if self.sel <= self.scroll then self.scroll = self.sel - 1 end
    if self.sel > self.scroll + LOC_ROWS then self.scroll = self.sel - LOC_ROWS end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, n - LOC_ROWS)))
  end

  function Loc:update()
    local input = self.game and self.game.input
    if not input then return end
    abSound(self.game, input)
    if self.popup == "legend" then
      if pressed(input, "a") or pressed(input, "b") or pressed(input, "select") then
        self.popup = nil
      end
      return
    end
    if self.popup == "sort" then
      if pressed(input, "b") then self.popup = nil return end
      if pressed(input, "up") then
        self.sortCursor = (self.sortCursor - 2) % #D.SORTS + 1
      elseif pressed(input, "down") then
        self.sortCursor = self.sortCursor % #D.SORTS + 1
      elseif pressed(input, "a") then
        self.sortIdx = self.sortCursor
        D.sortLocations(self.rows, D.SORTS[self.sortIdx].id)
        self.sel, self.scroll = 1, 0
        self.popup = nil
      end
      return
    end
    if pressed(input, "b") then
      local st = self.game.stack
      if st:top() == self then st:pop() end
      return
    end
    if pressed(input, "a") then
      self.popup, self.sortCursor = "sort", self.sortIdx
      return
    end
    if pressed(input, "select") then
      self.popup = "legend"
      return
    end
    local dir = MenuRepeat.direction(self.hold, input, { "up", "down", "left", "right" })
    if dir == "up" then self.sel = self.sel - 1
    elseif dir == "down" then self.sel = self.sel + 1
    elseif dir == "left" then self.sel = self.sel - LOC_ROWS; self.scroll = self.scroll - LOC_ROWS
    elseif dir == "right" then self.sel = self.sel + LOC_ROWS; self.scroll = self.scroll + LOC_ROWS end
    self:clamp()
  end

  function Loc:draw()
    G.push("all")
    G.setShader()
    local th = self.theme
    rect(th.main, 0, 0, 160, 144)
    box(2, 2, 156, 126, WHITE, BLACK)
    local sortBy = D.SORTS[self.sortIdx].id
    text("LOCATION", 6, 5, sortBy:find("^location") and YELLOW or WHITE)
    text("LV", 112, 5, sortBy:find("^level") and YELLOW or WHITE, { align = "right" })
    text("RATE", 154, 5, sortBy:find("^rate") and YELLOW or WHITE, { align = "right" })
    rect(WHITE, 4, 14, 152, 1)
    if #self.rows == 0 then
      text("NOT FOUND IN", 2, 52, WHITE, { align = "center", width = 156 })
      text("THE WILD.", 2, 64, WHITE, { align = "center", width = 156 })
    end
    for i = 1, LOC_ROWS do
      local idx = self.scroll + i
      local r = self.rows[idx]
      if not r then break end
      local y = 17 + (i - 1) * 13
      if idx == self.sel then rect(ROW_BG, 4, y - 1, 152, 11) end
      local lw = textWidth(r.level)
      text(r.loc, 6, y + 1, D.KIND_COLOR[r.kind] or WHITE,
        { maxW = math.min(84, 112 - lw - 10), marquee = true, phase = i * 0.37 })
      text(r.level, 112, y + 1, WHITE, { align = "right" })
      text(r.rate, 154, y + 1, WHITE, { align = "right" })
    end
    if #self.rows > LOC_ROWS then
      local travel = math.floor((self.sel - 1) / math.max(1, #self.rows - 1) * 96)
      rect(th.light, 156, 17 + travel, 1, 8)
    end
    if self.popup then
      box(12, 16, 136, 110, BLACK, WHITE)
      if self.popup == "legend" then
        text("COLOR CODES", 22, 22, BLACK)
        local y = 36
        for _, item in ipairs(D.KIND_LEGEND) do
          if self.ctx.gen == 2 or not item.gen2 then
            text(item[2], 22, y, D.KIND_COLOR[item[1]], { maxW = 120 })
            y = y + 11
          end
        end
        hint({ { "B", "BACK" } }, 131)
      else
        text("SORT BY", 22, 22, BLACK)
        for k, item in ipairs(D.SORTS) do
          local y = 36 + (k - 1) * 12
          if k == self.sortCursor then arrow(20, y, BLACK) end
          text(item.label, 28, y, BLACK, { maxW = 116, squeeze = 1 })
        end
        hint({ { "A", "SORT" }, { "B", "BACK" } }, 131)
      end
    else
      -- the three controls take turns, like the list's SELECT / START
      local turn = math.floor(now() / 2) % 3
      if turn == 0 then hint({ { "A", "SORT" } }, 131)
      elseif turn == 1 then hint({ { "SELECT", "COLOR CODES" } }, 131)
      else hint({ { "B", "BACK" } }, 131) end
    end
    G.pop()
  end

  ---------------------------------------------------------------------------
  -- Main screen
  ---------------------------------------------------------------------------
  local Screen = {}
  Screen.__index = Screen
  Screen.isOpaque = true
  Screen.screenId = "highlander_pokedex"
  Screen.highlanderPokedex = true

  local LIST_ROWS = 7
  local MOVE_ROWS = 8
  local MENU = { { "INFO", "AREA", "CRY", "PRNT" }, { "STATS", "FAMILY", "MOVES" } }
  local MENU_X = { { 10, 50, 90, 122 }, { 10, 60, 115 } }

  local MODE_INFO = {
    NAT = { "POKéDEX MODE", "PKMN ARE SORTED", "BY DEX NUMBER." },
    NEW = { "NEW POKéDEX MODE", "PKMN ARE SORTED", "BY EVOLUTION." },
    OLD = { "OLD POKéDEX MODE", "PKMN ARE SORTED", "BY DEX NUMBER." },
    ["A-Z"] = { "A TO Z MODE", "PKMN ARE SORTED", "ALPHABETICALLY." },
    UNOWN = { "UNOWN MODE", "UNOWN ARE SORTED", "BY CATCH ORDER." },
  }

  function Screen.new(game, opts)
    opts = opts or {}
    tokCache, tokCount = {}, 0
    pcall(D.repairOwned, game)
    local self = setmetatable({ game = game, opts = opts }, Screen)
    self.ctx = D.context(game)
    self.theme = themeFor(self.ctx)
    self.hold = repeatFor(self.ctx)
    if self.ctx.gen == 1 then
      self.sgbPalettes = function() return trueColorZones() end
    else
      local ok, Native = pcall(require, "src.ui.gen2.PokedexMenu")
      if ok and Native and Native.new then
        local okN, helper = pcall(Native.new, game, {})
        if okN then self.helper = helper end
      end
    end
    self.modes = D.modes(self.ctx)
    self.mode = self.modes[1]
    local last = game.save and game.save.lastDexMode
    for _, m in ipairs(self.modes) do if m == last then self.mode = m end end
    self.index, self.scroll = 1, 0
    self.view = "list"
    self:rebuild()
    if opts.entrySpecies then
      for i, r in ipairs(self.rows) do
        if r.species == opts.entrySpecies then self.index = i end
      end
      self:ensureVisible()
      self:openEntry(opts.entrySpecies, opts.newEntry == true)
    end
    return self
  end

  function Screen:rebuild()
    self.rows = self.results or D.rows(self.ctx, self.mode)
    self.seenCount, self.ownCount = D.totals(self.ctx)
    self.index = math.max(1, math.min(self.index or 1, math.max(1, #self.rows)))
    self:ensureVisible()
  end

  function Screen:ensureVisible()
    if self.index <= self.scroll then self.scroll = self.index - 1 end
    if self.index > self.scroll + LIST_ROWS then self.scroll = self.index - LIST_ROWS end
    self.scroll = math.max(0, math.min(self.scroll, math.max(0, #self.rows - LIST_ROWS)))
  end

  function Screen:current() return self.rows[self.index] end

  function Screen:close()
    local save = self.game.save
    if save then save.lastDexMode = self.mode end
    local stack = self.game.stack
    if self.ctx.gen == 2 then
      if self.opts.onClose then return self.opts.onClose() end
      if stack:top() == self then stack:pop() end
      return
    end
    if stack:top() == self then stack:pop() end
    if self.opts.onCancel then self.opts.onCancel() end
  end

  function Screen:openEntry(sp, newEntry)
    self.entrySp = sp
    self.entryData = D.entry(self.ctx, sp)
    self.newEntry = newEntry and true or false
    self.page = 1
    self.menuRow, self.menuCol = 1, 1
    self.view = "entry"
    playCry(self.ctx, sp)
  end

  -- Gold/Silver/Crystal's own nest map and UNOWN MODE, shown in our frame.
  function Screen:pushNative(view, sp)
    local h = self.helper
    if not h then return false end
    if not h.__phWrapped then
      h.__phWrapped = true
      local owner = self
      local baseUpdate, baseDraw = h.update, h.draw
      h.update = function(this, dt, ...)
        local input = this.game and this.game.input
        if this.__phView == "area" and input and pressed(input, "select") then
          owner:openLocations(this.__phSpecies)
          return
        end
        baseUpdate(this, dt, ...)
        if this.__phView and this.view ~= this.__phView then
          this.__phView = nil
          local st = this.game.stack
          if st:top() == this then st:pop() end
        end
      end
      h.draw = function(this, ...)
        baseDraw(this, ...)
        if this.__phView == "area" then selectBox(8, 19) end
      end
      h.drawsWidescreen = function() return false end
      h.wantsFillScale = function() return false end
      h.isOpaque = true
      h.screenId = "highlander_pokedex_native"
    end
    if sp then
      h.rows = { { species = sp, dex = D.dexNo(self.ctx, sp), seen = true,
        caught = D.isOwned(self.ctx, sp) } }
      h.index, h.scroll = 1, 0
    end
    h.view, h.__phView, h.__phSpecies = view, view, sp
    if view == "area" then h.areaRegion = nil; h.areaBlink = 0 end
    if view == "unown" then h.unownIndex = 0 end
    self.game.stack:push(h)
    return true
  end

  function Screen:openArea(sp)
    if self.ctx.gen == 2 then return self:pushNative("area", sp) end
    local ok, Screens = pcall(require, "src.ui.Screens")
    if not ok then return end
    local okP, map = pcall(Screens.push, self.game, "TownMap", { nestSpecies = sp })
    if not okP or type(map) ~= "table" then return end
    local owner = self
    local baseUpdate, baseDraw = map.update, map.draw
    map.update = function(this, dt, ...)
      local input = owner.game.input
      if input and pressed(input, "select") then
        owner:openLocations(sp)
        return
      end
      return baseUpdate(this, dt, ...)
    end
    map.draw = function(this, ...)
      local r = baseDraw(this, ...)
      selectBox(158, 133, true)
      return r
    end
  end

  function Screen:openLocations(sp)
    if not sp then return end
    self.game.stack:push(Loc.new(self, sp))
  end

  function Screen:print(sp)
    local okP, Printer = pcall(require, "src.core.Printer")
    local okT, TextBox = pcall(require, "src.render.TextBox")
    if not (okP and okT) then return end
    local saved, err = Printer.save("dex_" .. tostring(sp), 160, 144, function()
      self:drawEntry(true)
    end)
    local name = D.name(self.ctx, sp)
    local msg
    if saved then
      msg = Strings("Printed %s's\ndata!\f", name) .. Printer.savedWhereText(saved)
    else
      msg = Strings("Printer error!\n%s", tostring(err))
    end
    self.game.stack:push(TextBox.new(self.game, msg))
  end

  -------------------------------------------------------------------- input
  function Screen:optionItems()
    local items = {}
    for _, m in ipairs(self.modes) do items[#items + 1] = m end
    local h = self.helper
    if h and h.unownUnlocked then
      local ok, on = pcall(h.unownUnlocked, h)
      if ok and on then items[#items + 1] = "UNOWN" end
    end
    return items
  end

  function Screen:update(dt)
    local input = self.game and self.game.input
    if not input then return end
    abSound(self.game, input)
    local v = self.view
    if v == "list" then return self:updateList(input) end
    if v == "option" then return self:updateOption(input) end
    if v == "search" then return self:updateSearch(input) end
    if v == "entry" then return self:updateEntry(input) end
    if v == "moves" then return self:updateMoves(input) end
    if v == "family" then
      local n = #self:familyPages()
      if n > 1 and pressed(input, "up") then
        self.familyPage = (self.familyPage - 2) % n + 1
        return
      elseif n > 1 and pressed(input, "down") then
        self.familyPage = self.familyPage % n + 1
        return
      end
    end
    if pressed(input, "a") or pressed(input, "b") then self.view = "entry" end
  end

  function Screen:updateList(input)
    if pressed(input, "b") then
      if self.results then
        self.results = nil
        self.index, self.scroll = 1, 0
        self:rebuild()
      else
        self:close()
      end
      return
    end
    if pressed(input, "select") then
      self.view = "option"
      self.optionIndex = 1
      for i, m in ipairs(self:optionItems()) do if m == self.mode then self.optionIndex = i end end
      return
    end
    if pressed(input, "start") then
      self.view = "search"
      self.searchIndex = 1
      self.searchTypes = D.searchTypes(self.ctx)
      self.searchT1 = self.searchT1 or 1
      self.searchT2 = self.searchT2 or 0
      self.searchMsg = nil
      return
    end
    if pressed(input, "a") then
      local row = self:current()
      if row and row.seen then self:openEntry(row.species) end
      return
    end
    local n = #self.rows
    if n == 0 then return end
    local dir, edge = MenuRepeat.direction(self.hold, input, { "up", "down", "left", "right" })
    if dir == "up" then
      if self.index > 1 then self.index = self.index - 1 elseif edge then self.index = n end
    elseif dir == "down" then
      if self.index < n then self.index = self.index + 1 elseif edge then self.index = 1 end
    elseif dir == "left" or dir == "right" then
      -- Gen 1's page jump: the list moves seven, the cursor keeps its row.
      local step = dir == "right" and LIST_ROWS or -LIST_ROWS
      if n <= LIST_ROWS then
        self.index = step > 0 and n or 1
      else
        local row = self.index - self.scroll
        self.scroll = math.max(0, math.min(n - LIST_ROWS, self.scroll + step))
        self.index = math.max(1, math.min(n, self.scroll + row))
      end
    end
    self:ensureVisible()
  end

  function Screen:updateOption(input)
    local items = self:optionItems()
    if pressed(input, "b") then self.view = "list" return end
    if pressed(input, "up") then
      self.optionIndex = (self.optionIndex - 2) % #items + 1
    elseif pressed(input, "down") then
      self.optionIndex = self.optionIndex % #items + 1
    elseif pressed(input, "a") then
      local m = items[self.optionIndex]
      self.view = "list"
      if m == "UNOWN" then
        self:pushNative("unown")
        return
      end
      if m ~= self.mode or self.results then
        self.mode = m
        if self.game.save then self.game.save.lastDexMode = m end
        self.results = nil
        self.index, self.scroll = 1, 0
        self:rebuild()
      end
    end
  end

  function Screen:updateSearch(input)
    local types = self.searchTypes or {}
    if self.searchMsg and now() > self.searchMsg then self.searchMsg = nil end
    if pressed(input, "b") then self.view = "list" return end
    if pressed(input, "up") then
      self.searchIndex = (self.searchIndex - 2) % 4 + 1
    elseif pressed(input, "down") then
      self.searchIndex = self.searchIndex % 4 + 1
    elseif (pressed(input, "left") or pressed(input, "right")) and #types > 0 then
      local d = pressed(input, "right") and 1 or -1
      if self.searchIndex == 1 then
        self.searchT1 = (self.searchT1 - 1 + d) % #types + 1
      elseif self.searchIndex == 2 then
        self.searchT2 = (self.searchT2 + d) % (#types + 1)
      end
    elseif pressed(input, "a") then
      if self.searchIndex == 4 then self.view = "list" return end
      if self.searchIndex == 3 then
        local t1 = types[self.searchT1]
        local t2 = self.searchT2 > 0 and types[self.searchT2] or nil
        local found = D.search(self.ctx, t1, t2)
        if #found == 0 then
          self.searchMsg = now() + 1.5
        else
          self.results = found
          self.index, self.scroll = 1, 0
          self:rebuild()
          self.view = "list"
        end
      end
    end
  end

  function Screen:menuEnabled(label)
    local owned = D.isOwned(self.ctx, self.entrySp)
    if label == "INFO" or label == "MOVES" then return owned end
    return true
  end

  function Screen:updateEntry(input)
    local pages = self.entryData and self.entryData.pages or {}
    if self.newEntry then
      if pressed(input, "a") or pressed(input, "b") then
        if self.page < #pages then self.page = self.page + 1 else self:close() end
      end
      return
    end
    if pressed(input, "b") then self.view = "list" return end
    local row = MENU[self.menuRow]
    if pressed(input, "right") then
      self.menuCol = self.menuCol % #row + 1
    elseif pressed(input, "left") then
      self.menuCol = (self.menuCol - 2) % #row + 1
    elseif pressed(input, "up") or pressed(input, "down") then
      self.menuRow = self.menuRow == 1 and 2 or 1
      self.menuCol = math.min(self.menuCol, #MENU[self.menuRow])
    elseif pressed(input, "a") then
      local label = MENU[self.menuRow][self.menuCol]
      if not self:menuEnabled(label) then return end
      local sp = self.entrySp
      if label == "INFO" then
        if #pages > 1 then self.page = self.page % #pages + 1 end
      elseif label == "AREA" then self:openArea(sp)
      elseif label == "CRY" then playCry(self.ctx, sp)
      elseif label == "PRNT" then self:print(sp)
      elseif label == "STATS" then self.view = "stats"
      elseif label == "FAMILY" then self:openFamily()
      elseif label == "MOVES" then
        self.view = "moves"
        self.moveRows = D.moves(self.ctx, sp)
        self.moveScroll, self.moveDetail = 0, nil
        self.moveSel = 1
        for i, r in ipairs(self.moveRows) do
          if not r.header then self.moveSel = i break end
        end
      end
    end
  end

  function Screen:updateMoves(input)
    if self.moveDetail then
      if pressed(input, "a") or pressed(input, "b") then self.moveDetail = nil end
      return
    end
    if pressed(input, "b") then self.view = "entry" return end
    local rows = self.moveRows or {}
    local n = #rows
    if pressed(input, "a") then
      local r = rows[self.moveSel]
      if r and not r.header then self.moveDetail = D.moveDetail(self.ctx, r.id) end
      return
    end
    if n == 0 then return end
    local dir = MenuRepeat.direction(self.hold, input, { "up", "down", "left", "right" })
    if not dir then return end
    local function selectable(i) return rows[i] and not rows[i].header end
    if dir == "up" or dir == "down" then
      local step = dir == "down" and 1 or -1
      local i = self.moveSel
      for _ = 1, n do
        i = i + step
        if i < 1 then i = n elseif i > n then i = 1 end
        if selectable(i) then break end
      end
      self.moveSel = i
    else
      local step = dir == "right" and MOVE_ROWS or -MOVE_ROWS
      local t = math.max(1, math.min(n, self.moveSel + step))
      local d = step > 0 and 1 or -1
      while rows[t] and not selectable(t) do t = t + d end
      if not rows[t] then
        t = math.max(1, math.min(n, self.moveSel + step))
        while rows[t] and not selectable(t) do t = t - d end
      end
      if rows[t] then
        self.moveSel = t
        self.moveScroll = self.moveScroll + step
      end
    end
    if self.moveSel <= self.moveScroll then self.moveScroll = self.moveSel - 1 end
    if self.moveSel > self.moveScroll + MOVE_ROWS then self.moveScroll = self.moveSel - MOVE_ROWS end
    -- keep a section title on screen above its first move
    if self.moveScroll > 0 and rows[self.moveScroll] and rows[self.moveScroll].header
        and self.moveSel == self.moveScroll + 1 then
      self.moveScroll = self.moveScroll - 1
    end
    self.moveScroll = math.max(0, math.min(self.moveScroll, math.max(0, n - MOVE_ROWS)))
  end

  --------------------------------------------------------------------- draw
  function Screen:draw()
    G.push("all")
    G.setShader()
    local v = self.view
    if v == "list" then self:drawList()
    elseif v == "option" then self:drawOption()
    elseif v == "search" then self:drawSearch()
    elseif v == "entry" then self:drawEntry(false)
    elseif v == "stats" then self:drawStats()
    elseif v == "family" then self:drawFamily()
    elseif v == "moves" then self:drawMoves() end
    G.pop()
  end

  local function ball(cx, cy)
    rgb({ 232, 48, 48 })
    G.arc("fill", cx, cy, 3, math.pi, 2 * math.pi)
    rgb(WHITE)
    G.arc("fill", cx, cy, 3, 0, math.pi)
    rect(BLACK, cx - 3, cy, 7, 1)
  end

  function Screen:drawList()
    local th, ctx = self.theme, self.ctx
    rect(th.main, 0, 0, 160, 144)
    local row = self:current()
    -- picture
    box(2, 2, 60, 60, WHITE, WHITE)
    if row and row.seen then drawPicture(self, row.species, 4, 4, 56, "main")
    else questionMark(4, 4, 56) end
    -- seen / own
    box(2, 66, 60, 62, WHITE, BLACK)
    if self.results then
      text("FOUND", 6, 70, WHITE)
      text(tostring(#self.results), 58, 80, WHITE, { align = "right" })
    else
      text("SEEN", 6, 70, WHITE)
      text(tostring(self.seenCount or 0), 58, 80, WHITE, { align = "right" })
    end
    text("OWN", 6, 94, WHITE)
    text(tostring(self.ownCount or 0), 58, 104, WHITE, { align = "right" })
    if row then text(("No.%03d"):format(row.dex or 0), 6, 117, th.light) end
    -- list
    box(66, 2, 86, 126, WHITE, BLACK)
    for i = 1, LIST_ROWS do
      local idx = self.scroll + i
      local r = self.rows[idx]
      if not r then break end
      local y = 6 + (i - 1) * 17
      if idx == self.index then
        rgb(th.light)
        G.setLineWidth(2)
        G.rectangle("line", 69, y, 80, 15, 3, 3)
        G.setLineWidth(1)
      end
      if r.seen then
        if r.owned then ball(73, y + 7.5) end
        text(D.name(ctx, r.species), 78, y + 4, WHITE, { maxW = 73, squeeze = 1 })
      else
        text("-----", 80, y + 4, WHITE)
      end
    end
    if #self.rows == 0 then text("NO DATA", 66, 60, WHITE, { align = "center", width = 86 }) end
    box(153, 2, 5, 126, WHITE, BLACK)
    if #self.rows > 1 then
      local travel = math.floor((self.index - 1) / (#self.rows - 1) * 114)
      rect(th.light, 154, 4 + travel, 3, 8)
    end
    if math.floor(now() / 2) % 2 == 0 then
      arrowHint("SELECT", "OPTION", 131)
    else
      arrowHint("START", "SEARCH", 131)
    end
  end

  local function titlePill(label)
    pill(BLACK, 6, 4, 72, 13, 5)
    text(label, 6, 7, WHITE, { align = "center", width = 72 })
  end

  function Screen:drawOption()
    rect(self.theme.main, 0, 0, 160, 144)
    titlePill("OPTION")
    local items = self:optionItems()
    box(6, 22, 148, 72, WHITE, BLACK)
    for i, m in ipairs(items) do
      local y = 30 + (i - 1) * 16
      text((MODE_INFO[m] or { m })[1], 22, y, WHITE, { maxW = 130 })
      if i == self.optionIndex then arrow(13, y, WHITE) end
    end
    box(6, 100, 148, 40, WHITE, BLACK)
    local info = MODE_INFO[items[self.optionIndex]]
    if info then
      text(info[2], 11, 108, WHITE, { maxW = 138 })
      text(info[3], 11, 122, WHITE, { maxW = 138 })
    end
  end

  function Screen:drawSearch()
    local ctx = self.ctx
    rect(self.theme.main, 0, 0, 160, 144)
    titlePill("SEARCH")
    box(6, 22, 148, 72, WHITE, BLACK)
    local types = self.searchTypes or {}
    local labels = { "TYPE1", "TYPE2", "BEGIN SEARCH!!", "CANCEL" }
    for i, label in ipairs(labels) do
      local y = 30 + (i - 1) * 16
      text(label, 24, y, WHITE)
      if i == self.searchIndex then arrow(14, y, WHITE) end
      if i <= 2 then
        local t = i == 1 and types[self.searchT1] or (self.searchT2 > 0 and types[self.searchT2] or nil)
        if t then
          local c = D.typeColor(t)
          pill(c, 84, y - 2, 64, 11)
          text(D.typeName(ctx, t), 84, y, D.inkOn(c), { align = "center", width = 64, maxW = 60 })
        else
          text("-----", 84, y, WHITE, { align = "center", width = 64 })
        end
      end
    end
    box(6, 100, 148, 40, WHITE, BLACK)
    if self.searchMsg then
      text("NO PKMN FOUND!", 11, 114, WHITE, { maxW = 138 })
    else
      text("SEARCH SEEN PKMN", 11, 108, WHITE, { maxW = 138 })
      text("BY THEIR TYPES.", 11, 122, WHITE, { maxW = 138 })
    end
  end

  function Screen:drawEntry(printing)
    local th, ctx = self.theme, self.ctx
    local sp = self.entrySp
    local e = self.entryData or {}
    rect(th.main, 0, 0, 160, 144)
    box(2, 2, 60, 60, WHITE, WHITE)
    if sp and D.isSeen(ctx, sp) then drawPicture(self, sp, 4, 4, 56, "main") else questionMark(4, 4, 56) end
    -- data panel
    -- data panel and type row: one solid black shape, no white outline
    -- (green lines stay visible under the picture, at y 62-63, and under
    -- the whole P.1 / type row, at y 74-75, before the description box)
    rect(BLACK, 64, 2, 94, 62)
    rect(BLACK, 32, 64, 126, 10)
    text(("No.%03d"):format(D.dexNo(ctx, sp)), 68, 5, WHITE)
    if ctx.gen == 2 and self.helper and self.helper.drawFootprint then
      G.push("all")
      G.setColor(1, 1, 1, 1)
      pcall(self.helper.drawFootprint, self.helper, sp, 140 / 8, 4 / 8)
      G.pop()
    end
    text(D.name(ctx, sp), 68, 15, WHITE, { maxW = 86, squeeze = 1 })
    text(e.kind or "", 68, 24, WHITE, { maxW = 86, marquee = true })
    local owned = e.owned
    text("HT", 68, 33, WHITE)
    text("WT", 68, 42, WHITE)
    if e.metric then
      text(owned and ("%.1fm"):format(tonumber(e.m) or 0) or "???m", 154, 33, WHITE, { align = "right" })
      text(owned and ("%.1fkg"):format(tonumber(e.kg) or 0) or "???kg", 154, 42, WHITE, { align = "right" })
    else
      local h = owned and ("%d'%02d\""):format(e.ft or 0, e.inch or 0) or "?'??\""
      text(h, 96, 33, WHITE)
      text(owned and ("%.1flb"):format(e.lb or 0) or "???lb", 96, 42, WHITE)
    end
    local cr = D.catchRate(ctx, sp)
    -- "CatchRate": two words, no space, each keeps its capital
    local cw = text("CATCH", 66, 51, WHITE, { maxW = 36, squeeze = 1 })
    text("RATE", 66 + cw, 51, WHITE, { maxW = 29, squeeze = 1 })
    text(cr and tostring(cr) or "---", 156, 51, WHITE, { align = "right" })
    local types = D.types(ctx, sp)
    for i = 1, math.min(2, #types) do
      local x = i == 1 and 35 or 96
      local c = D.typeColor(types[i])
      pill(c, x, 64, 59, 10)
      text(D.typeName(ctx, types[i]), x, 65, D.inkOn(c),
        { align = "center", width = 59, maxW = 57, squeeze = 1 })
    end
    -- page tab and description
    local pages = e.pages or {}
    rect(BLACK, 2, 64, 28, 10)
    text("P." .. tostring(self.page or 1), 5, 65, WHITE)
    box(2, 76, 156, 44, WHITE, BLACK)
    local lines = pages[self.page or 1] or {}
    for i = 1, math.min(3, #lines) do
      text(lines[i], 6, 67 + i * 13, WHITE, { maxW = 149, squeeze = 1 })
    end
    if #pages > 1 and (self.page or 1) < #pages and now() % 1 < 0.7 then
      rgb(WHITE)
      G.polygon("fill", 148, 112, 154, 112, 151, 116)
    end
    if printing or self.newEntry then return end
    -- the two rows of actions
    box(2, 122, 156, 21, WHITE, BLACK)
    for r, row in ipairs(MENU) do
      local y = r == 1 and 124 or 134
      for c, label in ipairs(row) do
        local x = MENU_X[r][c]
        text(label, x, y, self:menuEnabled(label) and WHITE or GREY)
        if r == self.menuRow and c == self.menuCol and now() % 0.8 < 0.55 then
          arrow(x - 6, y, WHITE)
        end
      end
    end
  end

  function Screen:drawStats()
    local th, ctx = self.theme, self.ctx
    local rows, total = D.stats(ctx, self.entrySp)
    rect(th.main, 0, 0, 160, 144)
    box(2, 2, 156, 126, WHITE, BLACK)
    text("STATS", 8, 8, YELLOW)
    text("TOTAL", 84, 8, YELLOW)
    text(tostring(total), 152, 8, YELLOW, { align = "right" })
    local step = #rows >= 6 and 16 or 19
    for i, r in ipairs(rows) do
      local y = 28 + (i - 1) * step
      text(r[1], 8, y, WHITE, { maxW = 60 })
      rect({ 56, 56, 64 }, 72, y, 52, 7)
      rect(WHITE, 72, y, math.max(1, math.floor(52 * math.min(255, r[2]) / 255 + 0.5)), 7)
      text(tostring(r[2]), 152, y, WHITE, { align = "right" })
    end
    hint({ { "B", "BACK" } }, 131)
  end

  -- FAMILY. Every evolution line from the first stage to a last one is one
  -- page (Eevee has five, Tyrogue three, Oddish and Poliwag two); UP and DOWN
  -- change page. A page has 1 to 3 Pokémon:
  --   1: centred.
  --   2: first top-left, name to its right; second lower right, its method
  --      and name to its left.
  --   3: first top-left, name to its right; second right in the middle,
  --      method and name to its left; third bottom-left, method and name to
  --      its right.
  function Screen:familyPages()
    local members = D.family(self.ctx, self.entrySp)
    local kids, root = {}, members[1]
    for _, m in ipairs(members) do
      if m.parent then
        kids[m.parent] = kids[m.parent] or {}
        table.insert(kids[m.parent], m)
      end
    end
    local pages = {}
    local function walk(m, path)
      local line = {}
      for k, v in ipairs(path) do line[k] = v end
      line[#line + 1] = m
      local list = kids[m.species]
      if not list or #list == 0 then
        pages[#pages + 1] = line
      else
        for _, c in ipairs(list) do walk(c, line) end
      end
    end
    if root then walk(root, {}) end
    return pages
  end

  function Screen:openFamily()
    self.view = "family"
    self.familyPage = 1
    local found = false
    for k, line in ipairs(self:familyPages()) do
      for _, m in ipairs(line) do
        if m.species == self.entrySp then found = true break end
      end
      if found then self.familyPage = k break end
    end
  end

  function Screen:drawFamily()
    local th, ctx = self.theme, self.ctx
    rect(th.main, 0, 0, 160, 144)
    box(2, 2, 156, 126, BLACK, WHITE) -- a white page: pictures keep their own white
    local pages = self:familyPages()
    local n = #pages
    self.familyPage = math.max(1, math.min(self.familyPage or 1, math.max(1, n)))
    local line = pages[self.familyPage] or {}

    local function draw1(m, px, py, tx, my, ny, right)
      local seen = D.isSeen(ctx, m.species)
      if seen then drawPicture(self, m.species, px, py, 56) else questionMark(px, py, 56) end
      local name = seen and D.name(ctx, m.species) or "?????"
      local o = { maxW = 86, squeeze = 1 }
      if right then o.align = "right" end
      if m.method and my then
        text(m.method, tx, my, th.dark,
          { align = o.align, maxW = 86, marquee = true, phase = 0.5 })
      end
      text(name, tx, ny, BLACK, o)
    end

    if #line == 1 then
      local m = line[1]
      local seen = D.isSeen(ctx, m.species)
      if seen then drawPicture(self, m.species, 52, 24, 56) else questionMark(52, 24, 56) end
      text(seen and D.name(ctx, m.species) or "?????", 2, 84, BLACK,
        { align = "center", width = 156 })
      text("DOES NOT EVOLVE.", 2, 100, th.dark, { align = "center", width = 156 })
    elseif #line == 2 then
      draw1(line[1], 6, 3, 66, nil, 25)
      draw1(line[2], 98, 64, 94, 82, 91, true)
    elseif #line >= 3 then
      draw1(line[1], 6, 3, 66, nil, 25)
      draw1(line[2], 98, 34, 94, 55, 64, true)
      draw1(line[3], 6, 71, 66, 100, 109)
    end

    if n > 1 then
      -- page counter with up/down marks, top-right
      local label = ("%d/%d"):format(self.familyPage, n)
      local w = textWidth(label)
      text(label, 154, 5, th.dark, { align = "right" })
      rgb(th.dark)
      local ax = 154 - w - 8
      G.polygon("fill", ax, 9, ax + 6, 9, ax + 3, 5)
      G.polygon("fill", ax, 11, ax + 6, 11, ax + 3, 15)
    end
    hint({ { "B", "BACK" } }, 131)
  end

  function Screen:drawMoves()
    local th, ctx = self.theme, self.ctx
    local rows = self.moveRows or {}
    rect(th.main, 0, 0, 160, 144)
    box(2, 2, 156, 126, WHITE, BLACK)
    text("MOVES", 8, 5, YELLOW)
    text(D.name(ctx, self.entrySp), 152, 5, WHITE, { align = "right", maxW = 84 })
    if #rows == 0 then
      text("NO MOVES.", 2, 60, WHITE, { align = "center", width = 156 })
    end
    for i = 1, MOVE_ROWS do
      local idx = self.moveScroll + i
      local r = rows[idx]
      if not r then break end
      local y = 16 + (i - 1) * 13
      if r.header then
        rect(th.main, 6, y, 142, 11)
        text(r.header, 10, y + 2, WHITE)
      else
        if idx == self.moveSel then rect(ROW_BG, 5, y - 1, 145, 13) end
        text(r.source, 8, y + 2, WHITE, { maxW = 32 })
        local c = D.typeColor(r.type)
        pill(c, 42, y, 106, 11)
        text(r.name, 46, y + 2, D.inkOn(c), { maxW = 98 })
      end
    end
    if #rows > MOVE_ROWS then
      local travel = math.floor((self.moveSel - 1) / math.max(1, #rows - 1) * 96)
      rect(th.light, 152, 16 + travel, 3, 8)
    end
    hint({ { "A", "INFO" }, { "B", "BACK" } }, 131)
    local d = self.moveDetail
    if d then
      box(8, 28, 144, 90, WHITE, BLACK)
      local c = D.typeColor(d.type)
      pill(c, 10, 30, 140, 12)
      local ink = D.inkOn(c)
      text(d.name, 14, 32, ink, { maxW = 84 })
      text(D.typeName(ctx, d.type), 146, 32, ink, { align = "right", maxW = 50 })
      text("POWER", 14, 47, YELLOW)
      text("ACC.", 70, 47, YELLOW)
      text("PP", 116, 47, YELLOW)
      text(d.power > 1 and tostring(d.power) or "---", 14, 57, WHITE)
      text(d.accuracy > 0 and (tostring(d.accuracy) .. "%") or "---", 70, 57, WHITE)
      text(tostring(d.pp), 116, 57, WHITE)
      local lines = wrap(d.desc, 132, 4)
      for i, line in ipairs(lines) do text(line, 14, 70 + (i - 1) * 11, WHITE) end
    end
  end

  return Screen
end
