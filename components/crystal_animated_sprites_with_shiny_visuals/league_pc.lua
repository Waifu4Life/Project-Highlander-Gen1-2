-- PKMN LEAGUE (the Hall of Fame records in Red/Blue/Yellow's PC), 1.76.0.
--
-- The game's viewer loads each picture through the pokemon.sprite hook and
-- opens the path as a plain file, so the Crystal art this part serves (built
-- in memory, not a file) never loaded and the screen showed no picture at
-- all. The picture is drawn here instead, following CRYSTAL > POKéDEX
-- PICTURES like the PH Pokédex:
--   OG       the game's own picture, coloured by the screen's palette
--   CRYSTAL  Crystal's picture, animated per CRYSTAL > ANIMATIONS
--            (LOOP, or PLAY ONCE each time a Pokémon comes up)
-- A Pokémon Crystal has no art for falls back to its OG picture.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  if GameVersion.generation and GameVersion.generation() == 2 then return end
  local G = love.graphics

  -- engine/menus/league_pc.asm:98 (hlcoord 12, 5): a 7x7-tile picture
  local PIC_X, PIC_Y, PIC_SIZE = 12 * 8, 5 * 8, 56

  local function now() return love.timer and love.timer.getTime() or 0 end

  local function option(key)
    local ok, v = pcall(mod.options.get, mod.options, key)
    return ok and v or nil
  end

  local function crystalSource()
    local src = mod.exports and mod.exports.crystalSource
    if not (src and type(src.dexFrames) == "function") then return nil end
    local okA, avail = pcall(src.available)
    if not (okA and avail) then return nil end
    local pick = option("crystalDexPictures")
    return (pick == "crystal" or pick == true) and src or nil
  end

  ---------------------------------------------------------------- pictures
  local ogCache = {}
  local function ogImage(game, species)
    local hit = ogCache[species]
    if hit == nil then
      local def = game.data.pokemon and game.data.pokemon[species]
      local path = def and def.spriteFront
      local ok, img = false, nil
      if path then
        local okA, Assets = pcall(require, "src.render.Assets")
        if okA then ok, img = pcall(Assets.image, path) end
        if not (ok and img) then ok, img = pcall(G.newImage, path) end
      end
      hit = (ok and img) or false
      if hit and hit.setFilter then pcall(hit.setFilter, hit, "nearest", "nearest") end
      ogCache[species] = hit
    end
    return hit or nil
  end

  -- The record's own full-colour flag: BATTLE SPRITES = CRYSTAL marks the
  -- game's records full-colour while it serves Crystal art in battle.
  local function ogTrueColor(game, species)
    local fn = mod.exports and mod.exports.ogTrueColor
    if type(fn) == "function" then
      local ok, v = pcall(fn, species)
      if ok and v ~= nil then return v and true or false end
    end
    local def = game.data.pokemon and game.data.pokemon[species]
    return def and def.trueColor and true or false
  end

  local crystalCache = {}
  local function crystalSet(src, dex)
    local hit = crystalCache[dex]
    if hit == nil then
      hit = false
      local ok, set = pcall(src.dexFrames, dex)
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
      crystalCache[dex] = hit
    end
    return hit or nil
  end

  local function crystalFrame(set, start)
    local n = #set.images
    if n <= 1 then return set.images[1] end
    local total = 0
    for k = 1, n do total = total + (tonumber(set.durations[k]) or 120) end
    if total <= 0 then return set.images[1] end
    local t = (now() - start) * 1000
    if option("crystalAnimations") == "once" then
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

  local function markTrueColor(x, y, w, h)
    pcall(function()
      local PaletteFX = require("src.render.PaletteFX")
      if type(PaletteFX.markTrueColor) == "function" then
        PaletteFX.markTrueColor(x, y, w, h)
      end
    end)
  end

  local function drawPicture(screen, mon)
    local game = screen.game
    local species = mon.species
    -- the animation restarts each time a Pokémon comes up
    if screen.hlPicMon ~= mon then
      screen.hlPicMon = mon
      screen.hlPicStart = now()
    end
    local img, trueColor
    local src = crystalSource()
    if src then
      local def = game.data.pokemon and game.data.pokemon[species]
      local dex = def and tonumber(def.dex)
      local set = dex and crystalSet(src, dex)
      if set then img, trueColor = crystalFrame(set, screen.hlPicStart), true end
    end
    if not img then
      img, trueColor = ogImage(game, species), ogTrueColor(game, species)
    end
    if not img then return end
    local w, h = img:getDimensions()
    local sc = math.min(1, PIC_SIZE / w, PIC_SIZE / h)
    local dw, dh = math.floor(w * sc), math.floor(h * sc)
    -- centred across the window, resting on its bottom row (home/pics.asm)
    local x = PIC_X + math.floor((PIC_SIZE - dw) / 2)
    local y = PIC_Y + (PIC_SIZE - dh)
    G.push("all")
    G.setShader()
    G.setColor(1, 1, 1, 1)
    G.draw(img, x, y, 0, sc, sc)
    G.pop()
    -- the screen takes the Pokémon's palette (SET_PAL_POKEMON_WHOLE_SCREEN);
    -- full-colour art sits that recolour out
    if trueColor then markTrueColor(x, y, dw, dh) end
  end

  ---------------------------------------------------------------- the screen
  local function decorate(screen)
    if type(screen) ~= "table" or screen.hlLeaguePic
        or type(screen.draw) ~= "function" or type(screen.currentMon) ~= "function" then
      return screen
    end
    screen.hlLeaguePic = true
    local baseDraw = screen.draw
    screen.draw = function(self, ...)
      local mon = self:currentMon()
      local species = mon and mon.species
      -- the game's own draw, minus its picture
      local sprites = type(self.sprites) == "table" and self.sprites or nil
      local saved
      if sprites and species ~= nil then
        saved = sprites[species]
        sprites[species] = false
      end
      local ok, err = pcall(baseDraw, self, ...)
      if sprites and species ~= nil then sprites[species] = saved end
      if not ok then error(err, 0) end
      if mon then
        local okP, errP = pcall(drawPicture, self, mon)
        if not okP and not mod._hlLeagueWarned then
          mod._hlLeagueWarned = true
          mod.log:warn("league pc picture: %s", tostring(errP))
        end
      end
      G.setColor(1, 1, 1, 1)
    end
    return screen
  end

  local id = "LeaguePC"
  local inherited = mod.content.screens:get(id)
  local function maker(record)
    if type(record) == "function" then return record end
    return type(record) == "table" and record.new or nil
  end
  local record = {
    isMenu = true,
    new = function(game, ...)
      local make = maker(inherited) or require("src.ui.LeaguePC").new
      return decorate(make(game, ...))
    end,
  }
  if inherited then
    mod.content.screens:override(id, record)
  else
    mod.content.screens:register(id, record)
  end
end
