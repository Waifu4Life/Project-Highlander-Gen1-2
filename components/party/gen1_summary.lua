-- Highlander Party, Gen 1 summary: Gold's three pages rebuilt for Red, Blue,
-- Yellow and Green, plus Gold's move screen (SELECT on the moves page).
--   pink   HP, status, type labels, EXP
--   green  the moves table
--   blue   ID No., OT and the stats (one SPECIAL row: Gen 1 has one)
-- Left/Right turn pages, A goes to the next page (closes on the last), Up/Down
-- walk the party, B closes.
return function(mod, C)
  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")
  local LevelDisplay = require("src.ui.LevelDisplay")
  local PaletteFX = require("src.render.PaletteFX")
  local Status = require("src.battle.Status")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local Sound = require("src.core.Sound")
  local G = love.graphics

  local PINK, GREEN, BLUE = 1, 2, 3
  -- the three page colours (Gold's stats-screen palettes)
  local PAGE_COLORS = {
    { 255, 123, 255 }, { 173, 230, 30 }, { 120, 250, 250 },
  }
  local BLACK, WHITE = { 0, 0, 0 }, { 255, 255, 255 }
  -- the move screen's list: first name at y 15, one move every 17 px
  local MOVE_TOP, MOVE_STEP = 16, 17

  local frontPics = {}
  local function frontPic(path)
    local img = frontPics[path]
    if img ~= nil then return img or nil end
    local ok, loaded = pcall(love.graphics.newImage, path)
    frontPics[path] = (ok and loaded) or false
    return frontPics[path] or nil
  end

  local Summary = { isMenu = true }
  Summary.__index = Summary
  Summary.isOpaque = true

  local function inBattle(game)
    for _, s in ipairs((game.stack and game.stack.states) or {}) do
      if type(s) == "table" and s.isBattle then return true end
    end
    return false
  end

  function Summary.new(game, mon)
    local Stats = require("src.pokemon.Stats")
    local self = setmetatable({ game = game, page = PINK }, Summary)
    self.highlanderSummary = true
    -- Up/Down walk the party only when this Pokémon is in it.
    local party = game.save and game.save.party or {}
    for i, m in ipairs(party) do
      if m == mon then self.party, self.index = party, i break end
    end
    self.battle = inBattle(game)
    self:setMon(mon, true)
    return self
  end

  function Summary:setMon(mon, opening)
    local game = self.game
    pcall(require("src.pokemon.Stats").ensure, game.data.pokemon[mon.species], mon)
    self.mon = mon
    self.moveIndex = 1
    self.swapFrom = nil
    self.sprite, self.spriteTrueColor = nil, false
    local Sprites = require("src.pokemon.Sprites")
    local ok, path, trueColor = pcall(Sprites.path, game.data, mon.species, "front",
      { mon = mon, kind = "summary" })
    if ok and path then
      self.sprite = frontPic(path)
      self.spriteTrueColor = self.sprite and trueColor or false
    end
    if opening then
      self.whiteHold = tonumber(require("src.render.Transition").flashFrames(game)) or 0
      if self.whiteHold > 0 then return end
      self.whiteHold = 0
    end
    pcall(Sound.playCry, game.data, mon.species)
  end

  function Summary:sgbPalettes(game)
    local P = PaletteFX
    local mon = self.mon
    local bar = P.pal(game.data, P.barPalName(mon.hp, mon.stats.hp))
      or P.pal(game.data, "GREENBAR")
    if not bar then return nil end
    if self.moveDetail then return { P.whole(bar) } end
    return { P.whole(bar), P.zone(P.monPal(game.data, mon.species), 0, 0, 6, 6) }
  end

  ---------------------------------------------------------------- controls
  function Summary:close()
    if self.closing then return end
    self.closing = true
    local Transition = require("src.render.Transition")
    self.game.stack:push(Transition.whiteFlash(self.game, nil, function()
      self.game.stack:pop()
    end))
  end

  function Summary:switchMon(delta)
    if not self.party then return end
    local nextIndex = self.index + delta
    local mon = self.party[nextIndex]
    if not mon then return end
    self.index = nextIndex
    self:setMon(mon)
  end

  function Summary:turnPage(delta)
    local page = self.page + delta
    if page > BLUE then page = PINK end
    if page < PINK then page = BLUE end
    self.page = page
  end

  function Summary:updateMoveDetail(input)
    local moves = self.mon.moves or {}
    local count = math.max(1, #moves)
    if input:wasPressed("up") then
      self.moveIndex = self.moveIndex > 1 and self.moveIndex - 1 or count
    elseif input:wasPressed("down") then
      self.moveIndex = self.moveIndex < count and self.moveIndex + 1 or 1
    elseif input:wasPressed("a") then
      -- Moves can't be re-ordered in the middle of a battle.
      if self.battle then return end
      if self.swapFrom then
        local from, to = self.swapFrom, self.moveIndex
        self.swapFrom = nil
        if from ~= to and moves[from] and moves[to] then
          moves[from], moves[to] = moves[to], moves[from]
          pcall(Sound.play, self.game.data, "Swap")
        end
      elseif moves[self.moveIndex] then
        self.swapFrom = self.moveIndex
      end
    elseif input:wasPressed("right") then
      if not self.swapFrom then self:switchMon(1) end
    elseif input:wasPressed("left") then
      if not self.swapFrom then self:switchMon(-1) end
    elseif input:wasPressed("b") or input:wasPressed("select") then
      if self.swapFrom then
        self.moveIndex = self.swapFrom
        self.swapFrom = nil
      else
        self.moveDetail = false
      end
    end
  end

  function Summary:update()
    if self.closing then return end
    if self.whiteHold and self.whiteHold > 0 then
      self.whiteHold = self.whiteHold - 1
      if self.whiteHold == 0 then pcall(Sound.playCry, self.game.data, self.mon.species) end
      return
    end
    local input = self.game.input
    if input:wasPressed("a") then C.menuSound(self.game, false)
    elseif input:wasPressed("b") then C.menuSound(self.game, false) end
    if self.moveDetail then return self:updateMoveDetail(input) end
    if input:wasPressed("b") then return self:close() end
    if input:wasPressed("left") then
      C.menuSound(self.game, false)
      return self:turnPage(-1)
    end
    if input:wasPressed("right") then
      C.menuSound(self.game, false)
      return self:turnPage(1)
    end
    if input:wasPressed("a") then
      if self.page == BLUE then return self:close() end
      return self:turnPage(1)
    end
    if input:wasPressed("up") then return self:switchMon(-1) end
    if input:wasPressed("down") then return self:switchMon(1) end
    if input:wasPressed("select") and self.page == GREEN then
      self.moveDetail = true
      self.moveIndex = 1
      self.swapFrom = nil
    end
  end

  ------------------------------------------------------------------ drawing
  local function black() G.setColor(0, 0, 0, 1) end

  local function printLevel(x, y, level)
    if level < 100 then
      HudTiles.statusTile(0x6E, x, y)
      x = x + 8
    end
    black()
    Font.draw(tostring(level), x, y)
  end

  -- Gold's page arrows: 5 px wide, 7 rows (2,3,4,5,4,3,2), drawn in an
  -- 8x8 cell at x, y.
  local ARROW_W = { 2, 3, 4, 5, 4, 3, 2 }
  local function arrowLeft(x, y)
    for r, w in ipairs(ARROW_W) do C.rect(BLACK, x + 7 - w, y + r - 1, w, 1) end
  end
  local function arrowRight(x, y)
    for r, w in ipairs(ARROW_W) do C.rect(BLACK, x + 1, y + r - 1, w, 1) end
  end

  local function colon(x, y)
    C.rect(BLACK, x, y + 2, 2, 2)
    C.rect(BLACK, x, y + 5, 2, 2)
  end

  -- Gold's page squares, pixel for pixel: the open page 13x12 with a white
  -- notch pointing down, the others 9x8. `dy` moves the whole row.
  -- centred in the square (its middle column is x + 7)
  local NOTCH = { { 4, 5 }, { 4, 5 }, { 5, 3 }, { 5, 3 }, { 6, 1 }, { 6, 1 } }
  local function pageSquare(tx, ty, color, active, dy)
    local x, y = tx * 8, ty * 8 + (dy or 0)
    if active then
      C.rect(BLACK, x + 1, y + 4, 13, 12)
      C.rect(color, x + 2, y + 5, 11, 10)
      for r, n in ipairs(NOTCH) do C.rect(WHITE, x + 1 + n[1], y + 6 + r, n[2], 1) end
      PaletteFX.markTrueColor(x + 1, y + 4, 13, 12)
    else
      C.rect(BLACK, x + 4, y + 8, 9, 8)
      C.rect(color, x + 5, y + 9, 7, 6)
      PaletteFX.markTrueColor(x + 4, y + 8, 9, 8)
    end
  end

  function Summary:drawUpperHalf()
    local mon, data = self.mon, self.game.data
    local def = data.pokemon[mon.species] or {}
    local drewCrystal = false
    local crystal = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
    local portrait = crystal and crystal.exports and crystal.exports.drawPortrait
    if type(portrait) == "function" then
      local okP, drew = pcall(portrait, mon, 0, 0, 56, 56)
      drewCrystal = okP and drew == true
    end
    if self.sprite and not drewCrystal then
      local pw, ph = self.sprite:getDimensions()
      local py = math.max(0, 56 - ph)
      local px = math.max(0, 56 - math.floor((8 - pw / 8) / 2) * 8 - pw)
      G.setColor(1, 1, 1, 1)
      G.draw(self.sprite, px + pw, py, 0, -1, 1)
      if self.spriteTrueColor then PaletteFX.markTrueColor(px, py, pw, ph) end
    end
    black()
    HudTiles.statusTile(0x74, 64, 2)
    Font.drawCode(0xF2, 72, 2)
    Font.draw(("%03d"):format(def.dex or 0), 80, 2)
    if LevelDisplay.visible(mon, "summary", self.game) then printLevel(112, 2, mon.level) end
    black()
    Font.draw(mon.nickname or def.name or mon.species, 64, 18)
    Font.draw("/", 72, 34)
    Font.draw(def.name or mon.species, 80, 34)
    -- page arrows and squares (◀ at 12,6 / ▶ at 19,6)
    -- 2 px lower than Gold's, like the text above them.
    arrowLeft(96, 50)
    arrowRight(152, 50)
    for i, tx in ipairs({ 13, 15, 17 }) do
      pageSquare(tx, 5, PAGE_COLORS[i], i == self.page, 2)
    end
    C.rect(BLACK, 0, 62, 160, 2)
  end

  local function divider(tx)
    C.rect(BLACK, tx * 8 + 3, 64, 2, 80)
  end

  function Summary:drawTypeLabels()
    local data = self.game.data
    local def = data.pokemon[self.mon.species] or {}
    local types = {}
    for _, t in ipairs(def.types or {}) do
      if t and t ~= types[1] then types[#types + 1] = t end
    end
    for i, t in ipairs(types) do
      local y = 113 + (i - 1) * 12
      local c = C.typeColor(t)
      C.rgb(c)
      G.rectangle("fill", 3, y, 68, 11, 2, 2)
      PaletteFX.markTrueColor(3, y, 68, 11)
      local name = C.typeName(t, data)
      local w = C.fitWidth(name)
      C.drawFit(name, 3 + math.floor((68 - w) / 2), y + 2, 64)
    end
  end

  function Summary:expNumbers()
    local mon, data = self.mon, self.game.data
    local def = data.pokemon[mon.species] or {}
    local Growth = require("src.pokemon.Growth")
    local function at(level)
      local ok, v = pcall(Growth.expForLevel, def.growthRate, level, data.growth_rates)
      return ok and tonumber(v) or 0
    end
    local exp = tonumber(mon.exp) or 0
    if mon.level >= 100 then return exp, 0, 1 end
    local from, to = at(mon.level), at(mon.level + 1)
    local frac = to > from and math.max(0, math.min(1, (exp - from) / (to - from))) or 0
    return exp, math.max(0, to - exp), frac
  end

  function Summary:drawPinkPage()
    local mon, data = self.mon, self.game.data
    local barZoned = PaletteFX.shader() ~= nil and PaletteFX.pal(data, "GREENBAR") ~= nil
    G.setColor(1, 1, 1, 1)
    HudTiles.drawHPBar(data, 0.25, 9, mon, nil, barZoned)
    black()
    Font.draw(("%3d/%3d"):format(mon.hp, mon.stats.hp), 10, 80)
    divider(9)
    black()
    Font.draw(Strings("STATUS/"), 2, 96)
    local status = (mon.hp or 0) <= 0 and Strings("FNT")
      or (mon.status and Status.hudLabelFor(data.statuses, mon.status)) or Strings("OK")
    Font.draw(status, 48, 104)
    self:drawTypeLabels()
    black()
    local exp, toNext, frac = self:expNumbers()
    Font.draw(Strings("EXP POINTS"), 80, 72)
    Font.draw(("%7d"):format(exp), 104, 80)
    Font.draw(Strings("LEVEL UP"), 80, 96)
    Font.draw(("%7d"):format(toNext), 104, 104)
    if LevelDisplay.visible(mon, "summary", self.game) then
      Font.draw(Strings("TO"), 112, 112)
      printLevel(136, 112, math.min(100, mon.level + 1))
    end
    local px = C.drawPixelBar(87, 128, 64, math.floor(frac * 64 + 0.0001), C.XP_BLUE, true)
    if px > 0 then PaletteFX.markTrueColor(88 + 64 - px, 131, px, 2) end
  end

  function Summary:tableRows()
    local data = self.game.data
    local rows = {}
    for i = 1, 4 do
      local mv = (self.mon.moves or {})[i]
      local mdef = mv and data.moves[mv.id]
      if mv and mdef then
        local okP, maxPP = pcall(require("src.pokemon.Pokemon").maxPP, mdef.pp, mv.ppUps)
        rows[i] = { name = mdef.name or mv.id, type = mdef.type, pp = mv.pp,
          maxPp = okP and maxPP or mdef.pp }
      else
        rows[i] = false
      end
    end
    return rows
  end

  function Summary:drawGreenPage()
    black()
    local label = Strings("MOVES")
    Font.draw(label, 2, 80)
    local ok, w = pcall(Font.width, label)
    colon((ok and tonumber(w) or #label * 8) + 3, 80)
    C.setFont(self.game.data.font)
    C.drawMovesTable(self:tableRows(), PaletteFX.markTrueColor)
    local x, y, pw, ph = C.hintPill("SELECT: REORDER AND DESCRIPTIONS", 134)
    PaletteFX.markTrueColor(x, y, pw, ph)
  end

  function Summary:drawBluePage()
    local mon, game = self.mon, self.game
    black()
    HudTiles.statusTile(0x73, 2, 72)
    HudTiles.statusTile(0x74, 10, 72)
    Font.drawCode(0xF2, 18, 72)
    black()
    Font.draw(("%05d"):format(mon.otId or game.save.player.id or 0), 18, 80)
    Font.draw(Strings("OT/"), 2, 96)
    Font.draw(mon.ot or game.save.player.name or "RED", 18, 104)
    divider(10)
    black()
    local stats = {
      { "ATTACK", mon.stats.attack }, { "DEFENSE", mon.stats.defense },
      { "SPECIAL", mon.stats.special }, { "SPEED", mon.stats.speed },
    }
    for i, s in ipairs(stats) do
      Font.draw(Strings(s[1]), 88, 66 + (i - 1) * 16)
      Font.draw(("%3d"):format(s[2] or 0), 136, 74 + (i - 1) * 16)
    end
  end

  function Summary:drawMoveDetail()
    local mon, data = self.mon, self.game.data
    local def = data.pokemon[mon.species] or {}
    local B = Font.BORDER
    Font.drawBox(0, 1, 20, 11)
    Font.drawBox(0, 11, 20, 7)
    local name = mon.nickname or def.name or mon.species
    local okW, nw = pcall(Font.width, name)
    nw = okW and tonumber(nw) or #name * 8
    local levelW = LevelDisplay.visible(mon, "summary", self.game) and 24 or 0
    -- 2 px of the frame line cleared on the left so the name isn't glued to it
    C.rect(WHITE, 38, 8, math.ceil((nw + levelW) / 8) * 8 + 2, 8)
    black()
    Font.draw(name, 40, 8)
    if levelW > 0 then printLevel(40 + math.ceil(nw / 8) * 8, 8, mon.level) end
    if self.party then
      if self.index > 1 then arrowLeft(128, 0) end
      if self.index < #self.party then arrowRight(144, 0) end
    end
    local moves = mon.moves or {}
    black()
    for slot = 1, 4 do
      local y = MOVE_TOP + (slot - 1) * MOVE_STEP
      local mv = moves[slot]
      local mdef = mv and data.moves[mv.id]
      if mv and mdef then
        Font.draw(mdef.name or mv.id, 16, y)
        HudTiles.statusTile(0x72, 80, y + 8)
        HudTiles.statusTile(0x72, 88, y + 8)
        black()
        local okP, maxPP = pcall(require("src.pokemon.Pokemon").maxPP, mdef.pp, mv.ppUps)
        Font.draw(("%2d/%2d"):format(mv.pp or 0, okP and maxPP or mdef.pp or 0), 104, y + 8)
      else
        Font.draw("-", 16, y)
        Font.draw("--", 80, y + 8)
      end
    end
    -- the TYPE plaque over the lower box's top-left corner
    C.rect(WHITE, 0, 80, 56, 16)
    black()
    Font.drawCode(B.tl, 0, 80)
    for i = 1, 5 do Font.drawCode(B.h, i * 8, 80) end
    Font.drawCode(B.tr, 48, 80)
    Font.drawCode(B.v, 0, 88)
    Font.drawCode(B.bl, 48, 88)
    if self.swapFrom then
      Font.draw(Strings("Where?"), 8, 99)
    else
      Font.draw(Strings("TYPE/"), 8, 88)
      local mv = moves[self.moveIndex]
      local mdef = mv and data.moves[mv.id]
      Font.draw(mdef and C.typeName(mdef.type, data) or "---", 16, 99)
      Font.draw(Strings("ATTK/"), 88, 99)
      local power = mdef and tonumber(mdef.power) or 0
      Font.draw(power >= 2 and ("%3d"):format(power) or "---", 128, 99)
      local text = mdef and C.moveDescription(mv.id, mdef, true) or ""
      local y = 114
      for line in (tostring(text) .. "<NEXT>"):gmatch("(.-)<NEXT>") do
        if y > 128 then break end
        if line ~= "" then Font.draw(line, 8, y) end
        y = y + 14
      end
    end
    if #moves > 0 then
      if self.swapFrom then
        Font.drawCode(Theme.cursorHollow, 8, MOVE_TOP + (math.min(self.swapFrom, #moves) - 1) * MOVE_STEP)
      end
      Font.drawCode(Theme.cursor, 8, MOVE_TOP + (math.min(self.moveIndex, #moves) - 1) * MOVE_STEP)
    end
  end

  function Summary:draw()
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, 160, 144)
    local ok, err = pcall(function()
      if self.moveDetail then
        self:drawMoveDetail()
      else
        self:drawUpperHalf()
        if self.page == GREEN then
          self:drawGreenPage()
        elseif self.page == BLUE then
          self:drawBluePage()
        else
          self:drawPinkPage()
        end
      end
    end)
    if not ok and not mod._summaryWarned then
      mod._summaryWarned = true
      mod.log:warn("summary draw: %s", tostring(err))
    end
    G.setColor(1, 1, 1, 1)
    if self.whiteHold and self.whiteHold > 0 then
      G.rectangle("fill", 0, 0, 160, 144)
    end
  end

  return Summary
end
