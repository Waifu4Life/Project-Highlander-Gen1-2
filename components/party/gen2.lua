-- Highlander Party, Gold/Silver/Crystal. The game's own party list and stats
-- screen keep their behaviour; this changes how they look:
--   party   3 lines per Pokémon (name / level + HP / XP), no prompt box, the
--           A menu as a pop-up in the middle, SELECT quick-swap
--   stats   white lower half, type labels in colour, the moves table with a
--           SELECT hint (SELECT still opens Gold's own move screen)
return function(mod, C)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")
  local LevelDisplay = require("src.ui.LevelDisplay")
  local Strings = require("src.core.Strings")
  local G = love.graphics

  local unpackValues = table.unpack or unpack
  local function pack(...) return { n = select("#", ...), ... } end
  local WHITE, BLACK = { 255, 255, 255 }, { 0, 0, 0 }

  local function req(name)
    local ok, m = pcall(require, name)
    return ok and m or nil
  end
  local Mon = req("src.battle.gen2.Mon")
  local drawMoveDetail
  local HpBar = req("src.battle.gen2.HpBar")

  ---------------------------------------------------------------------------
  -- Party list
  ---------------------------------------------------------------------------
  -- 24 px per Pokémon (no CANCEL row: B backs out), 1 px down from the top.
  local PITCH, TOP = 24, 1

  local function expFraction(menu, mon)
    if (mon.level or 1) >= 100 then return 1 end
    if not (Mon and HpBar and HpBar.expFraction) then return 0 end
    local data = menu.game and menu.game.data or {}
    local def = data.pokemon and data.pokemon[mon.species]
    local okG, growth = pcall(Mon.growthFor, data, def and def.growthRate)
    if not okG then return 0 end
    local ok, f = pcall(HpBar.expFraction, mon, growth, Mon.experienceForLevel)
    return ok and tonumber(f) or 0
  end

  -- "XP:" badge + six cells + end cap, under the HP bar (columns 4-12).
  local function drawXpRow(menu, mon, y)
    local px = math.floor(expFraction(menu, mon) * 48 + 0.0001)
    local hud = menu.hud
    local colors = hud and hud.expColors and hud:expColors() or nil
    local letter = colors and colors[2] or nil
    C.drawXpLabelGen2(32, y, letter)
    if hud and hud.available and hud:available() then
      for cell = 0, 5 do
        local filled = math.max(0, math.min(8, px - cell * 8))
        hud:drawTile("hpBar", 0x60, 0x62 + filled, 6 + cell, y / 8, colors)
      end
      hud:drawTile("hpBar", 0x60, 0x6b, 12, y / 8, colors)
    else
      C.drawPixelBar(47, y, 48, px, C.XP_BLUE)
    end
  end

  local function drawPopup(menu)
    local sub = menu.submenu
    local labels = {}
    for i, item in ipairs(sub.items or {}) do labels[i] = item.label end
    local index = sub.index or 1
    sub.hlScroll = C.popupScroll(#labels, index, sub.hlScroll)
    local L = C.popupLayout(labels, sub.hlScroll)
    Chrome.box(L.tx, L.ty, L.tw, L.th)
    for i = L.first, L.last do
      Chrome.print(labels[i], L.labelX / 8, C.popupRowY(L, i) / 8)
    end
    Chrome.cursor(L.cursorX / 8, C.popupRowY(L, index) / 8)
    C.popupArrows(L)
  end

  -- Laid out like the Gen 1 list: icon, name, level (and status) on the
  -- first line; HP bar and HP numbers on the second; XP bar on the third.
  local function drawParty(self)
    local PartyMenu = require("src.ui.gen2.PartyMenu")
    local wasBattle = Font.useBattleExtra(true)
    Chrome.clear()
    local statuses = self.game and self.game.data and self.game.data.gen2Statuses
    for i, mon in ipairs(self.party) do
      local y0 = TOP + (i - 1) * PITCH
      local nameY, dataY = y0 / 8, (y0 + 8) / 8
      if i == self.index then
        Chrome.cursor(0, dataY)
      elseif self.switchFrom == i then
        Chrome.cursor(0, dataY, true)
      end
      local ix, iy = 8, y0 + self:iconBob(i, mon)
      if mon.isEgg or not C.drawFollowerIcon(self.game, mon, ix, iy,
          i == self.index, self.clock or 0) then
        self:drawIcon(mon, ix, iy)
      end
      local hp = self:shownHpFor(i, mon)
      local row = PartyMenu.rowFor(mon, hp, statuses)
      Chrome.print(row.name, 3, nameY)
      if row.level and LevelDisplay.visible(mon, "party", self.game) then
        Chrome.print(row.level, 13, nameY)
      end
      if row.status then Chrome.print(row.status, 17, nameY) end
      if self.tmhm then
        local able = self:tmhmAble(mon)
        if able then Chrome.print(able, 12, dataY) end
      elseif row.hp then
        self:drawHpBar(mon, 4, dataY, hp)
        Chrome.print(row.hp, 13, dataY)
        local ok, err = pcall(drawXpRow, self, mon, y0 + 16)
        if not ok and not mod._xp2Warned then
          mod._xp2Warned = true
          mod.log:warn("party XP bar skipped: %s", tostring(err))
        end
      end
    end
    Font.useBattleExtra(wasBattle)
    -- Item results ("HP restored...") and refusals still need their box.
    if self.itemResult and self.itemResult.text and not self:itemResultClimbing() then
      Chrome.textbox(0, 12, 18, 4)
      local line = 14
      for part in tostring(self.itemResult.text):gmatch("[^\n]+") do
        if line <= 16 then Chrome.print(part, 1, line) end
        line = line + 2
      end
    elseif #self.party == 0 then
      Chrome.box(0, 14, 20, 4)
      Chrome.print(Strings(PartyMenu.PROMPTS.none), 1, 16)
    end
    if self.submenu then drawPopup(self) end
    G.setColor(1, 1, 1, 1)
  end

  local function decorateParty(menu)
    if type(menu) ~= "table" then return menu end
    menu.highlanderParty = true
    menu.drawPanel = drawParty
    -- No CANCEL row: the cursor only walks the Pokémon (B still backs out).
    menu.count = function(self) return math.max(1, #self.party) end
    menu.isCancel = function(self) return self.index > #self.party end
    if menu.index > #menu.party then menu.index = math.max(1, #menu.party) end
    local nativeUpdate = menu.update
    menu.update = function(self, dt, ...)
      local input = self.game and self.game.input
      if input and input.wasPressed and not self.submenu and not self.itemResult
          and not self.softboiledFrom and not self.battle and not self.tmhm
          and self.wantsSubmenu and not self.wantsBattleSubmenu
          and self.save and self.party == self.save.party
          and input:wasPressed("select") then
        if self.switchFrom then
          self:finishSwitch()
        elseif self.party[self.index] and #self.party > 1 then
          self:beginSwitch(self.index)
        end
        return
      end
      local out = pack(nativeUpdate(self, dt, ...))
      local sub = self.submenu
      if sub and not sub.battle then
        local index = C.orderActions(sub.items, sub.index)
        if index then sub.index = index end
      end
      return unpackValues(out, 1, out.n)
    end
    return menu
  end

  ---------------------------------------------------------------------------
  -- Stats screen
  ---------------------------------------------------------------------------
  local WHITE_ROW = { WHITE, WHITE, WHITE, BLACK }

  local function typeIds(self)
    local def = self:speciesDef()
    local list = (self.mon and self.mon.types) or (def and def.types) or {}
    local out = {}
    for _, t in ipairs(list) do
      if t and t ~= out[1] then out[#out + 1] = t end
    end
    return out
  end

  local function drawTypeLabels(self)
    local data = self.game and self.game.data
    for i, t in ipairs(typeIds(self)) do
      local y = 113 + (i - 1) * 12
      C.rgb(C.typeColor(t))
      G.rectangle("fill", 3, y, 68, 11, 2, 2)
      local name = C.typeName(t, data)
      local w = C.fitWidth(name)
      C.drawFit(name, 3 + math.floor((68 - w) / 2), y + 2, 64)
    end
  end

  -- Gold's move screen, re-spaced like the Gen 1 one: the moves sit higher
  -- with a little more room, the Type/Attk row and description lower, and the
  -- TYPE tab is drawn with the box's own border pieces (no broken edge).
  local GbcPalette = req("src.render.GbcPalette")
  local MOVE_TOP, MOVE_STEP = 16, 17
  local function borderCode(code, x, y)
    G.setColor(1, 1, 1, 1)
    if GbcPalette and GbcPalette.available() then
      local previous = G.getShader and G.getShader() or nil
      GbcPalette.use(Chrome.DEFAULT_BOX_PALETTE)
      Font.drawCode(code, x, y)
      G.setShader(previous)
    else
      G.setColor(0, 0, 0, 1)
      Font.drawCode(code, x, y)
    end
    G.setColor(0, 0, 0, 1)
  end
  local function tiles(text) return #Font.split(tostring(text or "")) end

  function drawMoveDetail(self)
    local mon = self.mon or {}
    local data = self.game and self.game.data
    Chrome.clear()
    Chrome.textbox(0, 1, 18, 9)
    Chrome.textbox(0, 11, 18, 5)
    local name = mon.nickname or mon.name or mon.species or "?"
    local level
    if LevelDisplay.visible(mon, "summary", self.game) then
      local SM = require("src.ui.gen2.SummaryMenu")
      level = SM.levelText and SM.levelText(mon.level) or nil
    end
    C.rect(WHITE, 38, 8, (tiles(name) + tiles(level)) * 8 + 2, 8)
    Chrome.print(name, 5, 1)
    if level then Chrome.print(level, 5 + tiles(name), 1) end
    if self.index > 1 then Chrome.print("◀", 16, 0) end
    if self.index < #self.party then Chrome.print("▶", 18, 0) end

    local moves = self:moveList()
    for slot = 1, 4 do
      local y = (MOVE_TOP + (slot - 1) * MOVE_STEP) / 8
      local entry = moves[slot]
      if entry then
        Chrome.print(self:moveName(entry), 2, y)
        Chrome.print(Strings("PP"), 10, y + 1)
        Chrome.print(Chrome.number(entry.pp, 2), 13, y + 1)
        Chrome.print("/", 15, y + 1)
        local maxPp = Mon and Mon.maxPpOf(entry, data) or entry.pp
        Chrome.print(Chrome.number(maxPp, 2), 16, y + 1)
      else
        Chrome.print("-", 2, y)
        Chrome.print("--", 10, y + 1)
      end
    end

    -- the TYPE tab over the lower box's top-left corner
    local B = Font.BORDER
    -- clear the tab's area but keep the upper box's left line running down
    -- into the tab's corner, so the two frames join
    C.rect(WHITE, 8, 80, 48, 16)
    C.rect(WHITE, 0, 88, 8, 8)
    borderCode(B.tl, 0, 80)
    for i = 1, 5 do borderCode(B.h, i * 8, 80) end
    borderCode(B.tr, 48, 80)
    borderCode(B.v, 0, 88)
    borderCode(B.bl, 48, 88)
    -- right side: run the upper box's line down through the lower box's
    -- top-right corner, so the two frames join there too
    borderCode(B.v, 152, 88)
    borderCode(B.tr, 152, 88)
    if self.swapFrom then
      Chrome.print(Strings("Where?"), 1, 99 / 8)
    else
      Chrome.print(Strings("TYPE/"), 1, 11)
      local entry = moves[self.moveIndex]
      local def = entry and self:moveDef(entry.id)
      Chrome.print(def and C.typeName(def.type, data) or "---", 2, 99 / 8)
      Chrome.print(Strings("ATTK/"), 11, 99 / 8)
      local power = def and tonumber(def.power) or 0
      Chrome.print(power >= 2 and Chrome.number(power, 3) or "---", 16, 99 / 8)
      local text = def and def.description or ""
      local y = 114
      for line in (tostring(text) .. "<NEXT>"):gmatch("(.-)<NEXT>") do
        if y > 128 then break end
        if line ~= "" then Chrome.print(line, 1, y / 8) end
        y = y + 14
      end
    end
    if #moves > 0 then
      if self.swapFrom then
        Chrome.cursor(1, (MOVE_TOP + (math.min(self.swapFrom, #moves) - 1) * MOVE_STEP) / 8, true)
      end
      Chrome.cursor(1, (MOVE_TOP + (math.min(self.moveIndex, #moves) - 1) * MOVE_STEP) / 8)
    end
  end

  local function decorateSummary(summary)
    if type(summary) ~= "table" then return summary end
    summary.highlanderSummary = true
    -- A little room on the left edge and the top row.
    local nativeDrawPlacements = summary.drawPlacements
    summary.drawPlacements = function(self, list, palette)
      local moved = {}
      for i, e in ipairs(list or {}) do
        local x, y = e.x, e.y
        if x == 0 then x = 0.25 end
        if y == 0 then y = 0.25 end
        -- blue page: the stats column 2 px lower, off the line above it
        -- (SPEED's number, the last row, stays put: lower would leave the screen)
        if self.page == 3 and not self.moveDetail and e.x >= 11 and e.y >= 8
            and e.y < 17 then
          y = y + 0.25
        end
        moved[i] = { text = e.text, x = x, y = y }
      end
      return nativeDrawPlacements(self, moved, palette)
    end
    local nativeUpdate = summary.update
    summary.update = function(self, ...)
      local input = self.game and self.game.input
      if input and input.wasPressed and not self.moveDetail
          and (input:wasPressed("a") or input:wasPressed("b")
            or input:wasPressed("left") or input:wasPressed("right")) then
        C.menuSound(self.game, true)
      end
      return nativeUpdate(self, ...)
    end
    summary.lowerColors = function() return WHITE_ROW end
    summary.drawPageBackground = function()
      G.setColor(1, 1, 1, 1)
      G.rectangle("fill", 0, 64, 160, 80)
      G.setColor(0, 0, 0, 1)
    end

    local nativePink = summary.pinkPlacements
    summary.pinkPlacements = function(self)
      local out = {}
      for _, e in ipairs(nativePink(self)) do
        local typeCell = (e.x == 0 and e.y == 14) or (e.x == 1 and (e.y == 15 or e.y == 16))
        if not typeCell then out[#out + 1] = e end
      end
      return out
    end

    summary.drawPinkPage = function(self)
      local mon = self.mon or {}
      local maxHp = mon.maxHp or (mon.stats and mon.stats.hp) or 0
      if self.hud and self.hud:available() then
        self.hud:drawHpBar(mon.hp, maxHp, 0.25, 9, WHITE)
      elseif HpBar then
        HpBar.drawWithLabel(self.palettes, mon.hp, maxHp, 0, 9, Font)
      end
      self:drawVerticalDivider(9)
      self:drawPlacements(self:pinkPlacements(), self:lowerColors())
      local fraction = 0
      if HpBar and Mon then
        local ok, f = pcall(HpBar.expFraction, mon, self:growth(), Mon.experienceForLevel)
        fraction = ok and f or 0
      end
      if self.hud and self.hud:available() then
        self.hud:drawExpBar(fraction, 11, 16, WHITE)
      elseif HpBar then
        HpBar.drawExp(self.palettes, fraction, 11 * 8, 16 * 8 + 3)
      end
      self:pageTile(0x40, 10, 16, WHITE_ROW)
      self:pageTile(0x41, 19, 16, WHITE_ROW)
      C.setFont(self.game and self.game.data and self.game.data.font)
      drawTypeLabels(self)
    end

    summary.drawMoveDetail = drawMoveDetail

    summary.greenPlacements = function(self)
      return {
        { text = Strings("ITEM"), x = 0, y = 8 },
        { text = self:itemName() or "---", x = 6, y = 8 },
        { text = Strings("MOVES"), x = 0, y = 10 },
      }
    end

    summary.drawGreenPage = function(self)
      self:drawPlacements(self:greenPlacements(), self:lowerColors())
      local ok, w = pcall(Font.width, Strings("MOVES"))
      local x = (ok and tonumber(w) or 40) + 3
      C.rect(BLACK, x, 82, 2, 2)
      C.rect(BLACK, x, 85, 2, 2)
      local data = self.game and self.game.data
      C.setFont(data and data.font)
      local rows, moves = {}, self:moveList()
      for i = 1, 4 do
        local entry = moves[i]
        if entry then
          local def = self:moveDef(entry.id)
          rows[i] = { name = self:moveName(entry), type = def and def.type,
            pp = entry.pp, maxPp = Mon and Mon.maxPpOf(entry, data) or (def and def.pp) }
        else
          rows[i] = false
        end
      end
      C.drawMovesTable(rows)
      C.hintPill("SELECT: REORDER AND DESCRIPTIONS", 134)
      G.setColor(0, 0, 0, 1)
    end
    return summary
  end

  return { decorateParty = decorateParty, decorateSummary = decorateSummary }
end
