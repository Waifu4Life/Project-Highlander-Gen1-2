-- Battle Screen, Gen 2 (Gold/Silver/Crystal):
--   * ENEMY HP COUNTER: a plain "85/115" readout under the foe's own HP bar,
--     right-aligned to the bar's end. The bracket's corner, bottom line and
--     arrow are dropped 2 px so the numbers never touch them.
--   * HIGHLANDER HUD: the move menu as 3 columns x 4 rows (highlander_hud.lua).
--   * Caught-ball marker: the game's own caught marker on wild foes is
--     recoloured (red top, white bottom).
-- Everything else is the game's own HUD.
return function(mod)
  local Chrome = require("src.ui.gen2.Chrome")
  local Font = require("src.render.Font")

  local function counterOn()
    local ok, value = pcall(mod.options.get, mod.options, "enemy_hp_counter")
    return ok and value == true
  end

  -- Ink only (no text-box white behind each letter), in the game's own font.
  local function printInk(text, x, y)
    local _, drawGlyph, finish = Chrome.paletteGlyphs({
      { 255, 255, 255 }, { 128, 128, 128 }, { 0, 0, 0 }, { 0, 0, 0 },
    }, false, true)
    if not drawGlyph then
      love.graphics.setColor(0, 0, 0, 1)
      return Font.draw(text, x, y)
    end
    local pen = x
    for _, code in ipairs(Font.encode(text)) do
      drawGlyph(code, pen, y)
      pen = pen + Font.advanceOf(code)
    end
    finish()
  end

  local function textWidth(text)
    local width = 0
    for _, code in ipairs(Font.encode(text)) do
      width = width + (Font.advanceOf(code) or 8)
    end
    return width
  end

  -- screen:hudHp(mon, side) is the animated bar value.
  local function shownHp(screen, mon)
    if type(screen.hudHp) == "function" then
      local ok, value = pcall(screen.hudHp, screen, mon, "enemy")
      if ok and value ~= nil then return tonumber(value) or 0 end
    end
    if screen.shownEnemyHP ~= nil then return tonumber(screen.shownEnemyHP) or 0 end
    return tonumber(mon.hp) or 0
  end

  local function drawCounter(screen)
    if not counterOn() or type(screen) ~= "table" then return end
    if type(screen.activeMon) ~= "function" or not screen.showEnemyHud then return end
    if type(screen.statusHUDVisible) == "function" and not screen:statusHUDVisible() then return end
    if type(screen.hudCleared) == "function" and screen:hudCleared("enemy") then return end
    local enemy = screen:activeMon("enemy")
    if not enemy then return end
    local maxHp = math.max(1, math.floor(tonumber((enemy.stats and enemy.stats.hp)
      or enemy.maxHp or 1) or 1))
    local shown = math.max(0, math.min(maxHp, math.floor(shownHp(screen, enemy) + 0.5)))
    local text = ("%d/%d"):format(shown, maxHp)

    local G = love.graphics
    G.push("all")
    G.setShader()
    -- Erase the bracket's lower rows, then draw the same pixels 2 px lower.
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 13, 27, 3, 4)
    G.rectangle("fill", 9, 29, 4, 2)
    G.rectangle("fill", 16, 30, 72, 1)
    G.rectangle("fill", 79, 27, 7, 3)
    G.setColor(0, 0, 0, 1)
    G.rectangle("fill", 9, 27, 4, 2)   -- left edge, 2 px longer
    G.rectangle("fill", 9, 29, 5, 1)
    G.rectangle("fill", 9, 30, 6, 1)
    G.rectangle("fill", 10, 31, 6, 1)
    G.rectangle("fill", 11, 32, 77, 1) -- bottom line
    G.rectangle("fill", 80, 29, 2, 1)  -- arrow
    G.rectangle("fill", 80, 30, 4, 1)
    G.rectangle("fill", 80, 31, 6, 1)
    local useExtra = type(Font.useBattleExtra) == "function"
    local was = useExtra and Font.useBattleExtra(true)
    local okInk, err = pcall(function() printInk(text, 80 - textWidth(text), 23) end)
    if useExtra then Font.useBattleExtra(was) end
    G.pop()
    if not okInk then error(err, 0) end
  end

  -- --------------------------------------------------------- Highlander HUD
  local HUD = mod:load("highlander_hud.lua")(mod)
  local BattleState = require("src.ui.gen2.BattleState")
  local GbcPalette = require("src.render.GbcPalette")
  local okMon, Mon = pcall(require, "src.battle.gen2.Mon")

  local function hudOn()
    local ok, value = pcall(mod.options.get, mod.options, "highlander_hud")
    return ok and value == true
  end

  local function hudRows(screen)
    local rows = {}
    local data = screen.game and screen.game.data or {}
    local battle = screen.battle
    local fighter = battle and battle.player
    local enemyTypes
    if battle and battle.enemy and type(battle.battlerTypes) == "function" then
      local ok, types = pcall(battle.battlerTypes, battle, battle.enemy)
      if ok then enemyTypes = types end
    end
    local moves = type(screen.playerMoves) == "function" and screen:playerMoves() or {}
    for i = 1, 4 do
      local move = moves[i]
      if move and move.id then
        local def = data.moves and data.moves[move.id]
        local moveType = def and def.type
        -- Hidden Power shows (and hits as) its own type.
        if def and def.effect == "EFFECT_HIDDEN_POWER" and fighter
            and type(battle.hiddenPower) == "function" then
          local ok, _, hpType = pcall(battle.hiddenPower, battle, fighter)
          if ok and hpType then moveType = hpType end
        end
        local maxPp = move.maxPp
        if not maxPp and okMon and type(Mon.maxPpOf) == "function" then
          local ok, value = pcall(Mon.maxPpOf, move, data)
          if ok then maxPp = value end
        end
        local disabled = false
        if fighter and type(battle.moveDisabled) == "function" then
          local ok, value = pcall(battle.moveDisabled, battle, fighter, move.id)
          disabled = ok and value and true or false
        end
        rows[i] = {
          name = (def and def.name) or tostring(move.id),
          type = moveType, pp = move.pp or 0, maxPp = maxPp,
          mult = moveType and HUD.multiplier(data, moveType, enemyTypes) or nil,
          disabled = disabled,
        }
      else
        rows[i] = false
      end
    end
    return rows
  end

  BattleState.__phOrig = BattleState.__phOrig or {}
  BattleState.__phOrig.drawBottom = BattleState.__phOrig.drawBottom
    or BattleState.drawBottom
  local originalDrawBottom = BattleState.__phOrig.drawBottom
  BattleState.drawBottom = function(self, ox, ...)
    if type(self) ~= "table" or self.phase ~= "moves" or not hudOn()
        or (ox or 0) ~= 0 then
      return originalDrawBottom(self, ox, ...)
    end
    if type(self.bottomUIVisible) == "function" and not self:bottomUIVisible() then
      love.graphics.setColor(1, 1, 1, 1)
      return
    end
    local previousBgp = GbcPalette.setBgp(self:exitFadeBgp())
    Chrome.box(0, 12, 20, 6)
    local ok, err = pcall(function()
      local _, drawGlyph, finish = Chrome.paletteGlyphs({
        { 255, 255, 255 }, { 128, 128, 128 }, { 0, 0, 0 }, { 0, 0, 0 },
      }, false, true)
      HUD.draw({
        rows = hudRows(self),
        font = self.game and self.game.data and self.game.data.font,
        cursor = self.moveIndex,
        swap = self.moveSwapIndex,
        drawGlyph = drawGlyph or function(code, x, y) Font.drawCode(code, x, y) end,
        finish = finish,
      })
    end)
    GbcPalette.setBgp(previousBgp)
    love.graphics.setColor(1, 1, 1, 1)
    if not ok and not mod._hudWarned then
      mod._hudWarned = true
      mod.log:warn("Highlander HUD skipped: %s", tostring(err))
    end
  end

  local function hudActive(screen)
    if type(screen) ~= "table" or screen.phase ~= "moves" or not hudOn() then
      return false
    end
    if type(screen.wideLayout) == "function" then
      local ok, wide = pcall(screen.wideLayout, screen)
      if ok and wide then return false end
    end
    return true
  end

  -- START during FIGHT opens the help screen (type colours and icons);
  -- A, B or START closes it. The battle waits while it is open.
  local helpOpen = setmetatable({}, { __mode = "k" })
  BattleState.__phOrig.update = BattleState.__phOrig.update or BattleState.update
  local originalUpdate = BattleState.__phOrig.update
  BattleState.update = function(self, ...)
    if type(self) == "table" then
      local input = self.game and self.game.input
      local pressed = function(key)
        return input and type(input.wasPressed) == "function" and input:wasPressed(key)
      end
      if helpOpen[self] then
        if not hudActive(self) then
          helpOpen[self] = nil
        else
          if pressed("a") or pressed("b") or pressed("start") then helpOpen[self] = nil end
          return
        end
      elseif hudActive(self) and pressed("start") then
        helpOpen[self] = true
        return
      end
    end
    return originalUpdate(self, ...)
  end

  local function drawHelp(screen)
    if not (helpOpen[screen] and hudActive(screen)) then return end
    local data = screen.game and screen.game.data
    HUD.drawHelp({ data = data, font = data and data.font })
  end

  -- Recolour the native caught marker (black top -> red) on wild fights.
  local CAUGHT_MAP = {
    "  ###  ",
    " #RRR# ",
    "#RRWRR#",
    "#######",
    "#WWWWW#",
    " #WWW# ",
    "  ###  ",
  }
  local function drawCaughtMarker(screen)
    if type(screen) ~= "table" or type(screen.activeMon) ~= "function"
        or not screen.showEnemyHud then return end
    if type(screen.statusHUDVisible) == "function" and not screen:statusHUDVisible() then return end
    if type(screen.hudCleared) == "function" and screen:hudCleared("enemy") then return end
    local enemy = screen:activeMon("enemy")
    if not enemy then return end
    local kind = screen.kind or (screen.battle and screen.battle.kind)
    if kind and kind ~= "wild" then return end
    local save = screen.game and screen.game.save
    local owned = save and save.pokedex and save.pokedex.owned
    local species = enemy.species or (enemy.mon and enemy.mon.species)
    if not (owned and species and owned[species] == true) then return end
    local G = love.graphics
    local RED, WHT, INK = { 0.91, 0.25, 0.25 }, { 1, 1, 1 }, { 0.08, 0.08, 0.10 }
    G.push("all")
    G.setShader()
    for y, row in ipairs(CAUGHT_MAP) do
      for x = 1, #row do
        local c = row:sub(x, x)
        local col = c == "#" and INK or c == "R" and RED or c == "W" and WHT or nil
        if col then
          G.setColor(col[1], col[2], col[3], 1)
          G.rectangle("fill", 8 + x - 1, 8 + y - 1, 1, 1)
        end
      end
    end
    pcall(function()
      local PaletteFX = require("src.render.PaletteFX")
      if PaletteFX.markTrueColor then PaletteFX.markTrueColor(8, 8, 7, 7) end
    end)
    G.pop()
  end

  mod.hooks:wrap("battle.overlay", function(next, screen)
    local result = next(screen)
    pcall(drawCaughtMarker, screen)
    local ok, err = pcall(drawCounter, screen)
    if not ok and not mod._enemyHpWarned then
      mod._enemyHpWarned = true
      mod.log:warn("enemy HP counter skipped: %s", tostring(err))
    end
    local okHelp, errHelp = pcall(drawHelp, screen)
    if not okHelp and not mod._helpWarned then
      mod._helpWarned = true
      mod.log:warn("Highlander HUD help skipped: %s", tostring(errHelp))
    end
    return result
  end, 1000)
end
