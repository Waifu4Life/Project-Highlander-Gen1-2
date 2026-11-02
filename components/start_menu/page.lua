-- Highlander Start Menu: the 160x144 page, its input, and the SORT MENU.
--
--   rows 0-15    clock bar (clock on the left, page number on the right)
--   rows 17-134  2 columns x 5 rows of 77x22 tiles: 16px icon + name
--   rows 136-143 button hints (Safari Zone: steps and balls)
--
-- Gen 1 draws in four grays and colours the page through its SGB palette
-- pass; Gen 2 has no such pass, so the COLOUR is drawn directly.
--
-- ctx (from main.lua):
--   entries            entries.lua
--   icons              icons.lua (frame map)
--   image(path)        loads a component image
--   palette(game)      the COLOUR's 4 colours { paper, light, dark, ink }
--   clockMode()        "off", "device", "play", "ingame" or "rotation"
--   iconFor(key)       custom icon for a row, or nil
--   nameFor(key)       CUSTOM RENAME name for a row, or nil
--   order()            the saved order (list of keys)
--   saveOrder(keys)    stores a new order
--   openSort(game)     opens the SORT MENU
--   log                component log
return function(ctx)
  local Font = require("src.render.Font")
  local Sound = require("src.core.Sound")
  local Strings = require("src.core.Strings")
  local E = ctx.entries

  local Page = {}
  local W, H = 160, 144
  local PAPER, LIGHT, DARK, INK = 1, 0.82, 0.34, 0
  local COLS, PER_PAGE = 2, 10
  local TILE_W, TILE_H, TILE_X = 77, 22, { 2, 81 }
  local TILE_Y, ROW_STEP = 17, 24
  local BAR_H, FOOT_Y = 16, 136
  local ICON, LABEL_X = 16, 20

  ---------------------------------------------------------------------------
  -- drawing helpers
  ---------------------------------------------------------------------------
  local tint -- nil = grays (Gen 1), else the COLOUR's 4 colours (Gen 2)

  local function rgb(shade)
    if tint then
      local c = (shade >= 0.9 and tint[1]) or (shade >= 0.6 and tint[2])
        or (shade >= 0.2 and tint[3]) or tint[4]
      return c[1] / 255, c[2] / 255, c[3] / 255
    end
    return shade, shade, shade
  end

  local function box(x, y, w, h, shade)
    local r, g, b = rgb(shade)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.rectangle("fill", math.floor(x), math.floor(y),
      math.floor(w), math.floor(h))
  end

  -- Font tiles and icons are black on transparent; draw them as a mask in
  -- any shade so white text can sit on dark tiles. A TTF translation font
  -- is white coverage, so it takes the alpha path instead.
  local maskShader, alphaShader
  local function inkShader()
    if not love.graphics.newShader then return nil end
    if Font.ttfActive and Font.ttfActive() then
      if alphaShader == nil then
        local ok, s = pcall(love.graphics.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            return vec4(color.rgb, Texel(tex, tc).a * color.a);
          }
        ]])
        alphaShader = ok and s or false
      end
      return alphaShader or nil
    end
    if maskShader == nil then
      local ok, s = pcall(love.graphics.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc);
          return vec4(color.rgb, (p.r < 0.5 ? p.a : 0.0) * color.a);
        }
      ]])
      maskShader = ok and s or false
    end
    return maskShader or nil
  end

  local function inked(shade, fn)
    local shader = inkShader()
    love.graphics.push("all")
    if shader then
      love.graphics.setShader(shader)
      local r, g, b = rgb(shade)
      love.graphics.setColor(r, g, b, 1)
    else
      love.graphics.setColor(0, 0, 0, 1)
    end
    local ok, result = pcall(fn)
    love.graphics.pop()
    return ok and result or 0
  end

  local function fit(text, width)
    text = tostring(text or "")
    if Font.width(text) <= width then return text end
    if Font.split and Font.spansFitting then
      local spans = Font.split(text)
      local n = Font.spansFitting(spans, width - Font.width("."))
      if n < 1 then return "" end
      return text:sub(1, spans[n].to) .. "."
    end
    while #text > 1 and Font.width(text .. ".") > width do
      text = text:sub(1, -2)
    end
    return text .. "."
  end

  local function text(str, x, y, shade, maxWidth)
    if maxWidth then str = fit(str, maxWidth) end
    return inked(shade, function()
      return Font.draw(str, math.floor(x), math.floor(y))
    end)
  end

  local function centred(str, y, shade)
    str = fit(str, W - 4)
    text(str, math.floor((W - Font.width(str)) / 2), y, shade)
  end

  -- "SUN 23:11": the colons are drawn as dots, since Gen 1 and Gen 2 spell
  -- ":" differently in their charmaps.
  local function clockText(str, x, y, shade)
    local pen = math.floor(x)
    for part, colon in tostring(str):gmatch("([^:]*)(:?)") do
      if part ~= "" then pen = pen + text(part, pen, y, shade) end
      if colon ~= "" then
        box(pen + 1, y + 2, 2, 2, shade)
        box(pen + 1, y + 5, 2, 2, shade)
        pen = pen + 4
      end
      if part == "" and colon == "" then break end
    end
  end

  -- icons: one row of 16x16 frames
  local sheet, quads, sheetFailed
  local function loadSheet()
    if sheet then return true end
    if sheetFailed then return false end
    local ok, img = pcall(ctx.image, ctx.icons.sheet)
    if not ok or not img then
      sheetFailed = true
      ctx.log:warn("could not load %s: %s", ctx.icons.sheet, tostring(img))
      return false
    end
    if img.setFilter then img:setFilter("nearest", "nearest") end
    local w, h = img:getDimensions()
    quads = {}
    for name, frame in pairs(ctx.icons.frames) do
      if (frame + 1) * ICON <= w and h >= ICON then
        quads[name] = love.graphics.newQuad(frame * ICON, 0, ICON, ICON, w, h)
      end
    end
    sheet = img
    return true
  end

  local function icon(name, x, y, shade)
    if loadSheet() then
      local quad = quads[name] or quads.generic
      if quad then
        inked(shade, function()
          love.graphics.draw(sheet, quad, math.floor(x), math.floor(y))
        end)
        return
      end
    end
    box(x + 2, y + 2, ICON - 4, ICON - 4, shade)
  end

  -- For the CUSTOM ICONS picker: always plain grays.
  function Page.drawIcon(name, x, y, shade)
    local saved = tint
    tint = nil
    pcall(icon, name, x, y, shade or INK)
    tint = saved
  end
  Page.ICON = ICON

  ---------------------------------------------------------------------------
  -- rows on the page
  ---------------------------------------------------------------------------
  local function iconName(key)
    local custom = ctx.iconFor(key)
    if custom then return custom end
    if key:sub(1, 8) == "mod:opt:" then return "options" end
    return E.ICON[key:gsub("#%d+$", "")] or "generic"
  end

  -- Short names for the rows that don't fit beside the icon. Only used
  -- when the real name is too wide, so a translation that fits is kept.
  local SHORT = { pokedex = "PK DEX", party = "PKMN", pokebox = "PK BOX" }
  local PLURAL = { ITEM = "ITEMS" }

  local function rowName(row, game, width)
    local item, key = row.item, row.key
    local custom = ctx.nameFor and ctx.nameFor(key)
    if custom then return custom end
    local label = item.label
    if key == "trainer" and (label == nil or label == "") then
      local player = game and game.save and game.save.player
      label = player and player.name or "TRAINER"
    end
    label = tostring(label or "MENU")
    label = PLURAL[label:upper()] or label
    if width and SHORT[key] and Font.width(label) > width then
      return SHORT[key]
    end
    return label
  end
  Page.rowName = rowName

  -- Which tile each row sits on: rows fill the tiles in order; an empty
  -- tile (gap) holds nothing the cursor can land on.
  local function layout(rows)
    local slots, at = {}, {}
    for i = 1, #rows do
      at[i] = i
      -- (in the SORT MENU, empty tiles are "open": the cursor can go there)
      if not rows[i].gap or rows[i].open then slots[i] = i end
    end
    local total = math.max(1, math.ceil(#rows / PER_PAGE)) * PER_PAGE
    return slots, at, total
  end

  local function tileXY(slot)
    local s = (slot - 1) % PER_PAGE
    return TILE_X[s % COLS + 1], TILE_Y + math.floor(s / COLS) * ROW_STEP
  end

  local function tile(row, slot, selected, game)
    local x, y = tileXY(slot)
    local edge = selected and INK or DARK
    -- 1px frame with clipped corners, like the cartridge's own boxes
    box(x + 1, y, TILE_W - 2, 1, edge)
    box(x + 1, y + TILE_H - 1, TILE_W - 2, 1, edge)
    box(x, y + 1, 1, TILE_H - 2, edge)
    box(x + TILE_W - 1, y + 1, 1, TILE_H - 2, edge)
    box(x + 1, y + 1, TILE_W - 2, TILE_H - 2, selected and DARK or PAPER)
    if selected then box(x + 2, y + 1, TILE_W - 4, 1, LIGHT) end
    local ink = selected and PAPER or INK
    icon(iconName(row.key), x + 2, y + 3, ink)
    local room = TILE_W - LABEL_X - 2
    local custom = ctx.nameFor and ctx.nameFor(row.key)
    if custom then
      -- a CUSTOM RENAME name is drawn exactly as typed (Decapitalize skips it)
      Font._decapKeep, Font._decapKeepOn = { [custom] = true }, true
      pcall(text, custom, x + LABEL_X, y + 7, ink, room)
      Font._decapKeepOn = nil
    else
      text(rowName(row, game, room), x + LABEL_X, y + 7, ink, room)
    end
  end

  local function backdrop()
    box(0, 0, W, H, PAPER)
    for y = BAR_H + 4, FOOT_Y - 4, 8 do
      for x = 4, W - 1, 8 do box(x, y, 1, 1, LIGHT) end
    end
    box(0, 0, W, BAR_H - 2, DARK)
    box(0, BAR_H - 2, W, 2, LIGHT)
  end

  local function footer(hint)
    box(0, FOOT_Y, W, H - FOOT_Y, DARK)
    centred(hint, FOOT_Y, PAPER)
  end

  local function tiles(rows, current, game, page, decorate)
    local slots = layout(rows)
    local first = (page - 1) * PER_PAGE
    for s = 1, PER_PAGE do
      local index = slots[first + s]
      if index then decorate(rows[index], s, index) end
    end
  end

  ---------------------------------------------------------------------------
  -- clock
  ---------------------------------------------------------------------------
  local DAYS = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }

  local function playedText(game)
    local t = game and game.save and game.save.playTime
    local hours, minutes
    if type(t) == "table" then -- Gen 2: { hours, minutes, ... }
      hours, minutes = tonumber(t.hours) or 0, tonumber(t.minutes) or 0
    else -- Gen 1: seconds
      local s = tonumber(t) or 0
      hours, minutes = s / 3600, (s / 60) % 60
    end
    return ("PLAY %d:%02d"):format(math.max(0, math.floor(hours)),
      math.max(0, math.floor(minutes)) % 60)
  end

  -- Gold/Silver/Crystal's own clock (the one Mom's wheel and the Pokegear
  -- show): "GAME MON 10:30".
  local function gameText(game)
    local save = game and game.save
    local ok, Clock = pcall(require, "src.core.gen2.Clock")
    if not (ok and save and type(Clock) == "table") then return nil end
    local okT, hour, minute, day = pcall(function()
      return Clock.hour(save), Clock.minute(save), Clock.weekday(save)
    end)
    if not (okT and hour and minute) then return nil end
    return ("GAME %s %02d:%02d"):format(DAYS[(tonumber(day) or 0) + 1] or "",
      math.floor(hour) % 24, math.floor(minute) % 60)
  end

  -- "SUN 2026-10-18 23:50" fills the bar; with more than one page the
  -- day is left off to make room for the page number.
  local function deviceText(short)
    local ok, now = pcall(os.date, "*t")
    if ok and type(now) == "table" then
      local date = ("%04d-%02d-%02d %02d:%02d"):format(now.year, now.month,
        now.day, now.hour, now.min)
      if short then return date end
      return (DAYS[now.wday] or "") .. " " .. date
    end
  end

  -- ROTATION shows each clock for this many seconds in turn.
  local ROTATE_EVERY = 3

  -- The clock to show and its text ("off" -> nil).
  local function headerClock(game, hs, short)
    local mode = ctx.clockMode()
    if mode == "ingame" and not hs.gen2 then mode = "device" end
    if mode == "rotation" then
      local list = { "device", "play" }
      if hs.gen2 then list[3] = "ingame" end
      mode = list[math.floor((hs.time or 0) / ROTATE_EVERY) % #list + 1]
    end
    if mode == "off" then return nil, mode end
    if mode == "ingame" then
      local t = gameText(game)
      if t then return t, mode end
      mode = "device"
    end
    if mode == "device" then
      local t = deviceText(short)
      if t then return t, mode end
    end
    return playedText(game), "play"
  end

  ---------------------------------------------------------------------------
  -- the Start Menu page
  ---------------------------------------------------------------------------
  local function safariHint(game)
    local ow = game and game.overworld
    local safari = game and game.save and game.save.safari
    if not (safari and ow and ow.map and ow.inSafariStepZone
        and ow:inSafariStepZone()) then
      return nil
    end
    local steps = math.max(0, math.floor(safari.steps or 0))
    local balls = math.max(0, math.floor(safari.balls or 0))
    local long = ("STEP %d/500 BALL %d"):format(steps, balls)
    if Font.width(long) <= W - 4 then return long end
    return ("%d/500  %d"):format(steps, balls)
  end

  local function drawConfirm(hs)
    local x, y, w, h = 16, 44, 128, 56
    box(x, y, w, h, INK)
    box(x + 1, y + 1, w - 2, h - 2, PAPER)
    box(x + 2, y + 2, w - 4, 1, DARK)
    box(x + 2, y + h - 3, w - 4, 1, DARK)
    local a, b
    if hs.confirm == "contest" then
      a, b = Strings("END THE"), Strings("CONTEST?")
    else
      a, b = Strings("RETURN TO"), Strings("TITLE?")
    end
    text(a, x + math.floor((w - Font.width(a)) / 2), y + 8, INK)
    text(b, x + math.floor((w - Font.width(b)) / 2), y + 18, INK)
    local function button(label, bx, on)
      box(bx, y + 32, 40, 14, INK)
      box(bx + 1, y + 33, 38, 12, on and DARK or PAPER)
      label = Strings(label)
      text(label, bx + math.floor((40 - Font.width(label)) / 2), y + 35,
        on and PAPER or INK)
    end
    button("YES", x + 16, hs.yes)
    button("NO", x + w - 56, not hs.yes)
  end

  function Page.draw(menu)
    local hs, game = menu.hs, menu.game
    tint = hs.gen2 and ctx.palette(game) or nil
    love.graphics.push("all")
    love.graphics.setShader()
    backdrop()
    local rows = hs.rows
    local _, at, total = layout(rows)
    local pages = total / PER_PAGE
    local page = math.floor(((at[hs.index] or 1) - 1) / PER_PAGE) + 1
    -- the page number lives here (and only here); the full device date
    -- fills the bar, so it shows only while there's a single page
    local clock, shown = headerClock(game, hs, pages > 1)
    local fullDate = shown == "device" and pages == 1
    if clock then clockText(clock, fullDate and 2 or 4, 4, PAPER) end
    if not fullDate then
      local p = ("%d/%d"):format(page, pages)
      text(p, W - 4 - Font.width(p), 4, PAPER)
    end
    if #rows == 0 then
      centred(Strings("NO MENU ITEMS"), 68, INK)
    else
      tiles(rows, hs.index, game, page, function(row, s, index)
        tile(row, s, index == hs.index, game)
      end)
    end
    local hint = safariHint(game)
    hint = hint or Strings("A OK  B BACK")
    footer(hint)
    if hs.confirm then drawConfirm(hs) end
    love.graphics.pop()
    tint = nil
  end

  -- Left/Right: the other column on the same row (or the nearest filled
  -- row on this page). Up/Down: a row up/down in the same column, wrapping
  -- round all pages and skipping empty tiles.
  local function step(rows, index, dx, dy)
    if #rows == 0 then return index end
    local slots, at, total = layout(rows)
    local slot = at[index] or 1
    local lines = total / COLS
    local col, line = (slot - 1) % COLS, math.floor((slot - 1) / COLS)
    if dy ~= 0 then
      for n = 1, lines - 1 do
        local l = (line + dy * n) % lines
        local hit = slots[l * COLS + col + 1]
        if hit then return hit end
      end
    else
      local other = 1 - col
      if slots[line * COLS + other + 1] then return slots[line * COLS + other + 1] end
      local perPage = PER_PAGE / COLS
      local top = math.floor(line / perPage) * perPage
      for d = 1, perPage - 1 do
        for _, l in ipairs({ line - d, line + d }) do
          if l >= top and l < top + perPage and slots[l * COLS + other + 1] then
            return slots[l * COLS + other + 1]
          end
        end
      end
    end
    return index
  end
  Page.step = step

  local DIRS = { left = { -1, 0 }, right = { 1, 0 }, up = { 0, -1 }, down = { 0, 1 } }
  local function pressedDir(input)
    for name, d in pairs(DIRS) do
      if input:wasPressed(name) then return d end
    end
  end

  local function beep(game)
    if game and game.data then pcall(Sound.play, game.data, "Press_AB") end
  end

  local function answerConfirm(menu, yes)
    local hs, game = menu.hs, menu.game
    local kind = hs.confirm
    hs.confirm = nil
    if not yes then
      if hs.gen2 then menu.phase = nil end
      return
    end
    if hs.gen2 then
      if kind == "contest" then menu:confirmQuitContest() else menu:confirmQuit() end
    else
      game.stack:pop()
      if type(game.returnToTitle) == "function" then game:returnToTitle() end
    end
  end

  function Page.update(menu, dt)
    local hs, game = menu.hs, menu.game
    local input = game and game.input
    if not input then return end
    hs.time = (hs.time or 0) + (dt or 0)
    hs.refresh(menu)

    if hs.confirm then
      if pressedDir(input) then
        hs.yes = not hs.yes
      elseif input:wasPressed("a") then
        beep(game)
        answerConfirm(menu, hs.yes)
      elseif input:wasPressed("b") or input:wasPressed("start") then
        answerConfirm(menu, false)
      end
      return
    end

    local d = pressedDir(input)
    if d then
      hs.select(menu, step(hs.rows, hs.index, d[1], d[2]))
      return
    end
    if input:wasPressed("select") and #hs.rows > 0 then
      beep(game)
      ctx.openSort(game)
      return
    end

    local row = hs.rows[hs.index]
    if input:wasPressed("a") and row then
      if row.key == "quit" or row.key == "contest" then
        beep(game)
        hs.confirm, hs.yes = row.key, row.key == "contest"
        return
      end
      if hs.gen2 then
        menu.list.index = row.itemIndex
        menu:choose(row.item.value, row.itemIndex)
        return
      end
    end
    if hs.gen2 then
      if input:wasPressed("b") or input:wasPressed("start") then menu:close() end
      return
    end
    -- Gen 1: A (open the row) and B/START (close) are the game's own menu
    -- behaviour, so hand those to it with the cursor on our row. Anything
    -- else other mods taught the menu (hotkeys) reaches it too.
    menu.index = row and row.itemIndex or menu.index
    hs.nativeUpdate(menu, dt)
  end

  ---------------------------------------------------------------------------
  -- SORT MENU: A picks a tile up, A again swaps it with the one under the
  -- cursor; B drops it / leaves.
  ---------------------------------------------------------------------------
  function Page.newSort(game, rows, gen2, id)
    local s = {
      game = game, isOpaque = true, screenId = id .. ":sort_menu",
      highlanderStartFull = true, highlanderStartMenu = true,
      rows = {}, index = 1, held = nil, clock = 0,
    }
    -- Every tile of every page can be picked, empty ones included, and
    -- there's always at least one empty tile to move a row into.
    local real = 0
    for i, row in ipairs(rows or {}) do
      if row.gap then
        s.rows[i] = { key = E.GAP, gap = true, open = true }
      else
        s.rows[i] = row
        real = real + 1
      end
    end
    local total = math.max(1, math.ceil((#s.rows + 1) / PER_PAGE)) * PER_PAGE
    if real == 0 then total = 0 end
    while #s.rows < total do
      s.rows[#s.rows + 1] = { key = E.GAP, gap = true, open = true }
    end
    for i, row in ipairs(s.rows) do
      if not row.gap then s.index = i break end
    end

    -- The order to save: empty tiles as "-", none at the end.
    local function keys()
      local out = {}
      for i, row in ipairs(s.rows) do out[i] = row.key end
      while out[#out] == E.GAP do out[#out] = nil end
      return out
    end

    function s:uiSize() return W, H end
    function s:sgbPalettes()
      return { { colors = ctx.palette(self.game), x = 0, y = 0, w = W, h = H } }
    end
    function s:drawWidescreen(w, h)
      love.graphics.push("all")
      love.graphics.setShader()
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 0, 0, w or love.graphics.getWidth(),
        h or love.graphics.getHeight())
      love.graphics.pop()
    end

    local function leave(self)
      if self.game.stack:top() == self then self.game.stack:pop() end
    end

    function s:update(dt)
      self.clock = self.clock + (dt or 0)
      local input = self.game.input
      if not input then return end
      if real == 0 then
        if input:wasPressed("a") or input:wasPressed("b")
            or input:wasPressed("start") then
          beep(self.game); leave(self)
        end
        return
      end
      local d = pressedDir(input)
      if d then
        self.index = step(self.rows, self.index, d[1], d[2])
      elseif input:wasPressed("a") then
        local row = self.rows[self.index]
        if not row or (row.gap and not self.held) then return end
        beep(self.game)
        if not self.held then
          self.held = self.index
        else
          local a, b = self.held, self.index
          self.rows[a], self.rows[b] = self.rows[b], self.rows[a]
          self.held = nil
          if a ~= b then ctx.saveOrder(keys(), self.game) end
        end
      elseif input:wasPressed("b") or input:wasPressed("start") then
        beep(self.game)
        if self.held then self.held = nil else leave(self) end
      end
    end

    function s:draw()
      tint = gen2 and ctx.palette(self.game) or nil
      love.graphics.push("all")
      love.graphics.setShader()
      backdrop()
      text(Strings("SORT MENU"), 4, 4, PAPER)
      local _, at, total = layout(self.rows)
      local pages = total / PER_PAGE
      local page = math.floor(((at[self.index] or 1) - 1) / PER_PAGE) + 1
      if pages > 1 then
        local p = ("%d/%d"):format(page, pages)
        text(p, W - 4 - Font.width(p), 4, PAPER)
      end
      if real == 0 then
        centred(Strings("OPEN START"), 60, INK)
        centred(Strings("ONCE FIRST"), 72, INK)
      else
        tiles(self.rows, self.index, self.game, page, function(row, slot, index)
          local held = self.held == index
          local cursor = index == self.index
          local x, y = tileXY(slot)
          if row.gap then
            -- an empty tile: just its corners (solid when the cursor is on it)
            local shade = (cursor and not self.held) and INK or DARK
            for _, c in ipairs({ { 0, 0 }, { TILE_W - 3, 0 }, { 0, TILE_H - 1 },
                { TILE_W - 3, TILE_H - 1 } }) do
              box(x + c[1], y + c[2], 3, 1, shade)
            end
            for _, c in ipairs({ { 0, 0 }, { TILE_W - 1, 0 }, { 0, TILE_H - 3 },
                { TILE_W - 1, TILE_H - 3 } }) do
              box(x + c[1], y + c[2], 1, 3, shade)
            end
          else
            tile(row, slot, held or (cursor and not self.held), self.game)
          end
          if held then
            -- picked up: a small arrow in the corner
            box(x + TILE_W - 9, y + 3, 5, 1, PAPER)
            box(x + TILE_W - 8, y + 4, 3, 1, PAPER)
            box(x + TILE_W - 7, y + 5, 1, 1, PAPER)
          elseif cursor and self.held then
            -- where the held tile will go: a thick frame
            box(x + 1, y + 1, TILE_W - 2, 1, INK)
            box(x + 1, y + TILE_H - 2, TILE_W - 2, 1, INK)
            box(x + 1, y + 1, 1, TILE_H - 2, INK)
            box(x + TILE_W - 2, y + 1, 1, TILE_H - 2, INK)
          end
        end)
      end
      local hint
      if real == 0 then hint = Strings("B BACK")
      elseif self.held then hint = Strings("A PLACE  B CANCEL")
      else hint = Strings("A MOVE  B DONE") end
      footer(hint)
      love.graphics.pop()
      tint = nil
    end

    return s
  end

  return Page
end
