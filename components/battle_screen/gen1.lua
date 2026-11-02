-- Battle Screen, Gen 1 (Red/Blue/Yellow):
--   * ENEMY HP COUNTER: "85/115" under the foe's HP bar (the bracket under
--     it drops 5 px to make room). Drawn inside the game's own HUD pass, so
--     it appears, colours and shakes exactly like the rest of the HUD.
--   * EXP bar (always on): Gen 2's blue EXP bar under your Pokemon's HP numbers. It
--     fills right to left with a rising tick while "gained EXP" is on
--     screen; at a new level it hits full, the level-up music plays and it
--     starts again from empty.
--   * HIGHLANDER HUD: the move menu as 3 columns x 4 rows (highlander_hud.lua).
--   * Caught-ball marker: a red-topped ball after a wild foe's name when it
--     is already in your Pokedex (black and white on the OG palettes).
return function(mod)
  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")
  local PaletteFX = require("src.render.PaletteFX")
  local BattleState = require("src.battle.BattleState")

  local ENEMY_DROP = 5
  local Growth = require("src.pokemon.Growth")
  local Pokemon = require("src.pokemon.Pokemon")
  local HUD = mod:load("highlander_hud.lua")(mod)

  -- Packaged mobile builds omit Lua's optional debug library.
  local function traceback(err)
    local library = rawget(_G, "debug")
    if type(library) == "table" and type(library.traceback) == "function" then
      return library.traceback(err, 2)
    end
    return tostring(err)
  end

  local function counterOn()
    local ok, value = pcall(mod.options.get, mod.options, "enemy_hp_counter")
    return ok and value == true
  end

  -- The EXP bar is always on (no row): it has been standard since Gen 2.
  local function expBarOn() return true end

  local function hudOn()
    local ok, value = pcall(mod.options.get, mod.options, "highlander_hud")
    return ok and value == true
  end

  local function wideLayout(battle)
    if not (battle and type(battle.wideLayout) == "function") then return false end
    local ok, wide = pcall(battle.wideLayout, battle)
    return ok and wide == true
  end

  -- The same conditions the game uses to draw the foe's HUD
  -- (BattleState:drawHUDs), plus the caught / nickname screens.
  local function enemyHudShown(battle, slide)
    if type(battle) ~= "table" or battle.fieldCleared or battle.blankForAskName
        or battle.result == "caught" then return false end
    local enemy = battle.enemy
    if not enemy or not enemy.mon or enemy.fainted or battle.showEnemyTrainer
        or battle.enemySendingOut or battle.enemyHudPending
        or battle.introBalls or (slide or 0) ~= 0 then return false end
    if type(battle.statusHUDVisible) == "function" and not battle:statusHUDVisible() then
      return false
    end
    if type(battle.growInScale) == "function" then
      local ok, scale = pcall(battle.growInScale, battle, enemy)
      if ok and scale then return false end
    end
    return true
  end

  local function isCaught(battle)
    if battle.kind ~= "wild" then return false end
    local owned = battle.game and battle.game.save
      and battle.game.save.pokedex and battle.game.save.pokedex.owned
    local species = battle.enemy and battle.enemy.mon and battle.enemy.mon.species
    return species ~= nil and owned and owned[species] == true or false
  end

  -- ---------------------------------------------------------------- caught ball
  -- Drawn in code: no ROM-derived image. 7x7 ball centred in its 8x8 tile.
  local CAUGHT_BALL = {
    "  ###  ",
    " #RRR# ",
    "#RRWRR#",
    "#######",
    "#WWWWW#",
    " #WWW# ",
    "  ###  ",
  }

  local function drawCaughtBall(x, y)
    local mono = PaletteFX.mode == "og" or PaletteFX.mode == "og_inv"
      or PaletteFX.mode == "classic"
    local ink = { 0.08, 0.08, 0.10, 1 }
    local top = mono and { 0.33, 0.33, 0.33, 1 } or { 0.91, 0.25, 0.25, 1 }
    local white = { 1, 1, 1, 1 }
    local g = love.graphics
    for row, line in ipairs(CAUGHT_BALL) do
      for col = 1, #line do
        local c = line:sub(col, col)
        local color = c == "#" and ink or c == "R" and top
          or c == "W" and white or nil
        if color then
          g.setColor(color)
          g.rectangle("fill", x + col - 1, y + row, 1, 1)
        end
      end
    end
    g.setColor(1, 1, 1, 1)
    if not mono then PaletteFX.markTrueColor(x, y, 8, 8) end
  end

  -- The game's own name placement (short names are pushed right).
  local function nameX(tx, name)
    local count = #Font.split(name or "")
    return tx * 8 + (count <= 2 and 16 or count <= 4 and 8 or 0)
  end

  local function shakeOf(battle)
    local fx = battle.fx or {}
    local sx, sy = fx.shakeX or 0, fx.shakeY or 0
    if sx == 0 and sy == 0 and (fx.shake or 0) > 0 then
      sx = (battle.frame or 0) % 4 < 2 and 2 or -2
    end
    return sx, sy, fx.hudShakeX or 0
  end

  local function flashing(battle)
    local fx = battle.fx or {}
    return (fx.flash or 0) > 0 and (battle.frame or 0) % 4 < 2
  end

  -- Drawn last (battle.overlay), after the colour pass, so it keeps its red.
  local function drawCaughtMarker(battle)
    if flashing(battle) or not enemyHudShown(battle, 0) or not isCaught(battle) then
      return
    end
    local sx, sy, hudShake = shakeOf(battle)
    local name = tostring(battle.enemy.name or "")
    local g = love.graphics
    g.push("all")
    g.setShader()
    if wideLayout(battle) then
      -- Wide box: name at (8, 8), level at x 88. Only when the ball fits.
      local x = 8 + Font.width(name) + 2
      if x + 7 <= 88 then drawCaughtBall(x + sx, 8 + sy) end
    else
      local x = nameX(1, name) + Font.width(name) + 2
      drawCaughtBall(x + sx + hudShake, sy)
    end
    g.pop()
  end

  -- ------------------------------------------------------------ enemy HP counter
  local function shownHP(battler)
    local mon = battler.mon
    local shown = tonumber(battler.shownHP or mon.hp) or 0
    if shown > (tonumber(mon.hp) or 0) then return math.ceil(shown) end
    return math.floor(shown)
  end

  -- Runs right after the game drew its HUD, on the same surface, so the
  -- colour pass treats these pixels exactly like the game's own.
  local function drawEnemyCounter(battle)
    local enemy = battle.enemy
    local maximum = math.max(0, math.floor(tonumber(enemy.mon.stats
      and enemy.mon.stats.hp) or 0))
    local current = math.max(0, math.min(maximum, shownHP(enemy)))
    local text = ("%d/%d"):format(current, maximum)
    local g = love.graphics
    local hudShake = battle.fx and battle.fx.hudShakeX or 0
    g.push("all")
    if hudShake ~= 0 then g.translate(hudShake, 0) end
    -- Clear the bracket (left tick + corner, bottom line + arrow) ...
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 8, 16, 8, 16)
    g.rectangle("fill", 16, 24, 72, 8)
    -- ... and draw the same tiles ENEMY_DROP px lower.
    HudTiles.tile(0x73, 8, 16 + ENEMY_DROP)
    HudTiles.tile(0x74, 8, 24 + ENEMY_DROP)
    for i = 2, 9 do HudTiles.tile(0x76, i * 8, 24 + ENEMY_DROP) end
    HudTiles.tile(0x78, 80, 24 + ENEMY_DROP)
    g.setColor(0, 0, 0, 1)
    Font.draw(text, 80 - Font.width(text), 23)
    g.pop()
  end

  -- ------------------------------------------------------------------ EXP bar
  -- Same conditions the game uses to draw your Pokemon's HUD.
  local function playerHudShown(battle, slide)
    if type(battle) ~= "table" or battle.fieldCleared or battle.blankForAskName
        or (slide or 0) ~= 0 then return false end
    local player = battle.player
    if not player or not player.mon or player.fainted or battle.safari
        or battle.demo or battle.showPlayerBack then return false end
    if type(battle.statusHUDVisible) == "function" and not battle:statusHUDVisible() then
      return false
    end
    return true
  end

  local BAR_PIXELS = 64          -- right edge x 144, fills leftward to x 80
  local BAR_SPEED = 1            -- pixels per logic frame (Gen 2's pace)
  local XP_BLUE = { 33 / 255, 140 / 255, 255 / 255, 1 }
  local PLAYER_DROP = 4

  -- Your Pokemon's bracket drops PLAYER_DROP px to make room for the bar,
  -- with Gen 2's thick end cap where the bar meets the bracket.
  local function drawPlayerBracket()
    local g = love.graphics
    g.push("all")
    g.setColor(1, 1, 1, 1)
    g.rectangle("fill", 72, 88, 80, 8)
    HudTiles.tile(0x73, 144, 88 - PLAYER_DROP)   -- right edge, longer
    HudTiles.tile(0x77, 144, 88 + PLAYER_DROP)
    for i = 10, 17 do HudTiles.tile(0x76, i * 8, 88 + PLAYER_DROP) end
    HudTiles.tile(0x6F, 72, 88 + PLAYER_DROP)
    g.setColor(0, 0, 0, 1)
    g.rectangle("fill", 144, 92, 5, 3)
    g.pop()
  end

  local function levelCap(battle)
    local consts = battle.data and battle.data.constants
    return consts and consts.levelCap or 100
  end

  local function expAt(battle, mon, level)
    local def = battle.data and battle.data.pokemon and battle.data.pokemon[mon.species]
    if not def then return 0 end
    return Growth.expForLevel(def.growthRate, level, battle.data.growth_rates) or 0
  end

  -- One animation per battle: the EXP the bar shows (shown) and the level it
  -- shows it for (level). It only moves while armed by a "gained" message.
  local bars = setmetatable({}, { __mode = "k" })

  local function barFor(battle)
    local mon = battle.player and battle.player.mon
    if not mon then return nil end
    local st = bars[battle]
    if not st or st.mon ~= mon then
      st = { mon = mon, level = mon.level, shown = mon.exp or 0,
        target = mon.exp or 0, armed = false, tick = nil }
      bars[battle] = st
    end
    return st
  end

  -- Where the bar must stop for now: the gain's target, or full when a new
  -- level is still waiting for its "grew to level" moment.
  local function stopPoint(battle, st)
    if st.level >= levelCap(battle) then return st.shown end
    return math.min(st.target, expAt(battle, st.mon, st.level + 1))
  end

  local function barPixels(battle, st)
    if st.level >= levelCap(battle) then return 0 end
    local from = expAt(battle, st.mon, st.level)
    local to = expAt(battle, st.mon, st.level + 1)
    local ratio = (st.shown - from) / math.max(1, to - from)
    ratio = math.max(0, math.min(1, ratio))
    local px = math.floor(BAR_PIXELS * ratio + 0.5)
    if ratio > 0 then px = math.max(1, px) end
    return px
  end

  -- The rising tick while the bar grows (assets/exp_bar_tick.wav).
  local tickSource
  local function playTick(battle, pixels)
    local pitch = 0.8 + 0.8 * math.max(0, math.min(BAR_PIXELS, pixels)) / BAR_PIXELS
    local data = battle and battle.data
    local played = false
    local okS, Sound = pcall(require, "src.core.Sound")
    local wav = (mod.path or ".") .. "/assets/exp_bar_tick.wav"
    if okS and type(Sound) == "table" and type(Sound.play) == "function" and data then
      data.audio = data.audio or {}
      data.audio.sfx = data.audio.sfx or {}
      data.audio.sfx.Sfx_HighlanderExpTick = data.audio.sfx.Sfx_HighlanderExpTick
        or { file = wav }
      local src
      played = pcall(function() src = Sound.play(data, "Sfx_HighlanderExpTick") end)
        and src ~= nil
      if played and (type(src) == "userdata" or type(src) == "table") then
        pcall(function() src:setPitch(pitch) end)
      end
    end
    if played then return end
    if tickSource == nil then
      tickSource = false
      pcall(function()
        local bytes = mod:read("assets/exp_bar_tick.wav")
        local file = love.filesystem.newFileData(bytes, "exp_bar_tick.wav")
        tickSource = love.audio.newSource(file, "static")
      end)
    end
    if tickSource then
      pcall(function()
        tickSource:stop()
        tickSource:setVolume(0.6)
        tickSource:setPitch(pitch)
        tickSource:play()
      end)
    end
  end

  -- One logic frame of the bar.
  local function stepBar(battle)
    local st = barFor(battle)
    if not st then return end
    local mon = st.mon
    local exp = tonumber(mon.exp) or 0
    -- Anything that lowers EXP or levels outside a gain: just follow it.
    if mon.level < st.level or exp < st.shown
        or (not st.armed and mon.level > st.level)
        or (not st.armed and battle.phase == "menu") then
      st.level, st.shown, st.target, st.armed = mon.level, exp, exp, false
      return
    end
    if not st.armed then return end
    -- A committed level-up: the full bar starts again from empty.
    while mon.level > st.level and st.level < levelCap(battle)
        and st.shown >= expAt(battle, mon, st.level + 1) do
      st.level = st.level + 1
      st.tick = 0
    end
    -- Hold while the level-up music plays or the stats box is open.
    local waiting = battle.waitingSound
    if battle.waitingUI or (waiting and not (type(waiting) == "table"
        and waiting.highlanderExpBar)) then
      return
    end
    local stop = stopPoint(battle, st)
    if st.shown < stop then
      local from = expAt(battle, mon, st.level)
      local to = expAt(battle, mon, st.level + 1)
      local perPixel = math.max(1, to - from) / BAR_PIXELS
      st.shown = math.min(stop, st.shown + perPixel * BAR_SPEED)
      local px = barPixels(battle, st)
      if not st.tick or px - st.tick >= 2 or st.shown >= stop then
        if px ~= st.tick then playTick(battle, px) end
        st.tick = px
      end
    elseif st.shown >= st.target and st.level >= mon.level then
      st.armed = false
    end
  end

  -- Stands in for a sound on the "gained EXP" page: the text waits (like
  -- WaitForSoundToFinish) until the bar reaches its stop point.
  local function barWaiter(battle)
    return {
      highlanderExpBar = true,
      isPlaying = function()
        local st = bars[battle]
        if not st or not st.armed or not expBarOn() then return false end
        return st.shown < stopPoint(battle, st)
      end,
      getDuration = function() return 10 end,
      getPitch = function() return 1 end,
      stop = function() end,
    }
  end

  -- battle.exp_gained fires inside the award, right before its "gained" text.
  local pendingGain = setmetatable({}, { __mode = "k" })
  mod.events:on("battle.exp_gained", function(ev)
    if type(ev) ~= "table" or type(ev.battle) ~= "table" then return end
    local battle = ev.battle
    pendingGain[battle] = nil
    if not expBarOn() or wideLayout(battle) then return end
    local active = battle.player and battle.player.mon
    if not ev.mon or ev.mon ~= active then return end
    -- The award has already added this gain to the Pokemon's EXP.
    local st = bars[battle]
    if not st or st.mon ~= ev.mon then
      local before = (tonumber(ev.mon.exp) or 0) - (tonumber(ev.gained) or 0)
      bars[battle] = { mon = ev.mon, level = ev.mon.level, shown = before,
        target = before, armed = false }
    end
    pendingGain[battle] = {
      mon = ev.mon,
      target = tonumber(ev.mon.exp) or 0,
      leveled = type(ev.levels) == "table" and #ev.levels > 0,
    }
  end)

  BattleState.__phOrig = BattleState.__phOrig or {}
  BattleState.__phOrig.sayNext = BattleState.__phOrig.sayNext or BattleState.sayNext
  local originalSayNext = BattleState.__phOrig.sayNext
  BattleState.sayNext = function(self, text, ...)
    local pend = type(self) == "table" and pendingGain[self] or nil
    if not pend then return originalSayNext(self, text, ...) end
    pendingGain[self] = nil
    if type(text) ~= "string" or not text:upper():find("EXP", 1, true) then
      return originalSayNext(self, text, ...)
    end
    local battle = self
    -- Arm right before the page shows, so the bar grows under the text.
    self:actNext(function()
      local st = barFor(battle)
      if st and st.mon == pend.mon then
        st.target = math.max(st.target, pend.target)
        st.armed = true
      end
    end)
    local result = originalSayNext(self, text, ...)
    local item = self.queue and self.queue[self.nextInsert or 0]
    if type(item) == "table" and item.text == text then
      item.waitForLearningSfx = function() return barWaiter(battle) end
      -- A new level: no button press, straight on to "grew to level" and
      -- its music the moment the bar is full.
      if pend.leveled then
        item.auto = true
        item.autoDelay = item.autoDelay or 0
      end
    end
    return result
  end

  BattleState.__phOrig.update = BattleState.__phOrig.update or BattleState.update
  local originalUpdate = BattleState.__phOrig.update
  BattleState.update = function(self, ...)
    local results = { originalUpdate(self, ...) }
    if type(self) == "table" and expBarOn() and not wideLayout(self) then
      local ok, err = pcall(stepBar, self)
      if not ok and not mod._expBarWarned then
        mod._expBarWarned = true
        mod.log:warn("EXP bar skipped: %s", tostring(err))
      end
    end
    return unpack(results)
  end

  -- Drawn last (battle.overlay), after the colour pass, so it stays blue.
  local function drawExpFill(battle)
    if not expBarOn() or wideLayout(battle) or flashing(battle) then return end
    if not playerHudShown(battle, (battle.introSlide or 0) > 0 and 1 or 0) then return end
    local st = bars[battle]
    if not st or st.mon ~= battle.player.mon then st = barFor(battle) end
    if not st then return end
    local px = barPixels(battle, st)
    if px <= 0 then return end
    local sx, sy = shakeOf(battle)
    local g = love.graphics
    g.push("all")
    g.setShader()
    g.setColor(XP_BLUE)
    g.rectangle("fill", 144 - px + sx, 92 + sy, px, 2)
    g.pop()
    PaletteFX.markTrueColor(144 - px + sx, 92 + sy, px, 2)
  end

  -- --------------------------------------------------------- Highlander HUD
  local function hudActive(battle)
    return type(battle) == "table" and battle.phase == "moveSelect" and hudOn()
      and not wideLayout(battle) and battle.player
      and type(battle.player.curMoves) == "table"
  end

  local function hudRows(battle)
    local rows = {}
    local data = battle.data or {}
    local enemyTypes = battle.enemy and battle.enemy.curTypes
    for i = 1, 4 do
      local mv = battle.player.curMoves[i]
      if mv and mv.id then
        local def = data.moves and data.moves[mv.id]
        local maxPp
        if def and def.pp then
          local ok, value = pcall(Pokemon.maxPP, def.pp, mv.ppUps)
          maxPp = ok and value or def.pp
        end
        rows[i] = {
          name = def and def.name or tostring(mv.id),
          type = def and def.type,
          pp = mv.pp, maxPp = maxPp,
          mult = def and HUD.multiplier(data, def.type, enemyTypes) or nil,
          disabled = battle.player.disabledSlot == i,
        }
      else
        rows[i] = false
      end
    end
    return rows
  end

  BattleState.__phOrig = BattleState.__phOrig or {}
  BattleState.__phOrig.drawTextArea = BattleState.__phOrig.drawTextArea
    or BattleState.drawTextArea
  local originalDrawTextArea = BattleState.__phOrig.drawTextArea
  -- The game's own move box and TYPE/PP box give way to one full-width box;
  -- its contents are drawn last (battle.overlay) so the colours survive.
  BattleState.drawTextArea = function(self, ...)
    if not hudActive(self) then return originalDrawTextArea(self, ...) end
    if type(self.bottomUIVisible) == "function" and not self:bottomUIVisible() then
      return
    end
    Font.drawBox(0, 12, 20, 6)
    love.graphics.setColor(0, 0, 0, 1)
  end

  -- The game clips your Pokemon's picture at row 8 during FIGHT, because its
  -- TYPE/PP box sits there. The Highlander HUD has no such box, so the
  -- picture stays whole.
  BattleState.__phOrig.drawPicsLayer = BattleState.__phOrig.drawPicsLayer
    or BattleState.drawPicsLayer
  local originalDrawPicsLayer = BattleState.__phOrig.drawPicsLayer
  BattleState.drawPicsLayer = function(self, slide, sx, sy, onlySide, skipMenuClip, ...)
    if hudActive(self) then skipMenuClip = true end
    return originalDrawPicsLayer(self, slide, sx, sy, onlySide, skipMenuClip, ...)
  end

  -- START during FIGHT opens the help screen (type colours and icons);
  -- A, B or START closes it. The battle waits while it is open.
  local helpOpen = setmetatable({}, { __mode = "k" })
  local hudUpdate = BattleState.update
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
    return hudUpdate(self, ...)
  end

  local function drawHighlanderHud(battle)
    if not hudActive(battle) then return end
    if type(battle.bottomUIVisible) == "function" and not battle:bottomUIVisible() then
      return
    end
    local sx, sy = shakeOf(battle)
    HUD.draw({
      rows = hudRows(battle),
      font = battle.data and battle.data.font,
      cursor = battle.moveIndex,
      swap = battle.moveSwapIndex,
      drawGlyph = function(code, x, y) Font.drawCode(code, x, y) end,
      x = sx, y = sy,
      markTrueColor = PaletteFX.markTrueColor,
    })
  end

  -- Start from the game's own drawHUDs every time the mod loads, so a second
  -- load in the same session never stacks on an older copy.
  BattleState.__phOrig = BattleState.__phOrig or {}
  BattleState.__phOrig.drawHUDs = BattleState.__phOrig.drawHUDs or BattleState.drawHUDs
  local originalDrawHUDs = BattleState.__phOrig.drawHUDs
  -- Older builds also wrapped drawZonePass; put the game's own back.
  if BattleState.__phOrig.drawZonePass then
    BattleState.drawZonePass = BattleState.__phOrig.drawZonePass
  end

  local function noop() end

  BattleState.drawHUDs = function(battle, slide, ...)
    if type(battle) ~= "table" then return originalDrawHUDs(battle, slide, ...) end
    -- Our caught ball replaces the game's own marker (shown by other mods).
    local ownsCaught = enemyHudShown(battle, slide) and isCaught(battle)
      and type(battle.drawCaughtBall) == "function"
    local nativeCaught = rawget(battle, "drawCaughtBall")
    if ownsCaught then battle.drawCaughtBall = noop end
    local results = { xpcall(originalDrawHUDs, traceback, battle, slide, ...) }
    if ownsCaught then battle.drawCaughtBall = nativeCaught end
    if not results[1] then error(results[2], 0) end
    if expBarOn() and not wideLayout(battle) and playerHudShown(battle, slide) then
      local okBar, errBar = pcall(drawPlayerBracket)
      if not okBar and not mod._expBracketWarned then
        mod._expBracketWarned = true
        mod.log:warn("EXP bar bracket skipped: %s", tostring(errBar))
      end
    end
    if counterOn() and enemyHudShown(battle, slide) then
      local ok, err = pcall(drawEnemyCounter, battle)
      if not ok and not mod._enemyHpWarned then
        mod._enemyHpWarned = true
        mod.log:warn("enemy HP counter skipped: %s", tostring(err))
      end
    end
    return unpack(results, 2)
  end

  mod.hooks:wrap("battle.overlay", function(next, battle)
    local result = next(battle)
    if type(battle) ~= "table" then return result end
    local okHud, errHud = pcall(drawHighlanderHud, battle)
    if not okHud and not mod._hudWarned then
      mod._hudWarned = true
      mod.log:warn("Highlander HUD skipped: %s", tostring(errHud))
    end
    local okXp, errXp = pcall(drawExpFill, battle)
    if not okXp and not mod._expFillWarned then
      mod._expFillWarned = true
      mod.log:warn("EXP bar skipped: %s", tostring(errXp))
    end
    local ok, err = pcall(drawCaughtMarker, battle)
    if not ok and not mod._caughtWarned then
      mod._caughtWarned = true
      mod.log:warn("caught marker skipped: %s", tostring(err))
    end
    if helpOpen[battle] and hudActive(battle) then
      local okHelp, errHelp = pcall(HUD.drawHelp, {
        data = battle.data, font = battle.data and battle.data.font,
        markTrueColor = PaletteFX.markTrueColor,
      })
      if not okHelp and not mod._helpWarned then
        mod._helpWarned = true
        mod.log:warn("Highlander HUD help skipped: %s", tostring(errHelp))
      end
    end
    return result
  end, 50)
end
