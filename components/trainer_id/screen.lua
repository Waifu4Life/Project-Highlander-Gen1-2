-- Highlander Trainer ID (Project Highlander Gen1+2): Gold's trainer card
-- rebuilt for Red, Blue, Yellow and Green, drawn entirely by this file.
--
-- Same grid as Gold's card (20x18 tiles, two framed halves sharing row 8):
--   top half   NAME/ at (2,2), the divider on row 3, ID No at (2,4),
--              MONEY at (2,6), the portrait in the 5x7 box at (14,1)
--   page 1     STATUS plaque, POKéDEX (owned), PLAY TIME with the blinking
--              colon, BADGES▶
--   page 2     BADGES plaque, the eight Kanto leaders with their numbers;
--              an earned badge spins beside its leader
-- Left/Right turn the page, A turns it (closes on page 2), B/START close.
--
-- The frame, notches, divider, ID No, plaques, colon and cursor are small
-- pixel maps below; the screen is drawn in true colour (no palette pass).
return function(mod)
  local Font = require("src.render.Font")
  local Strings = require("src.core.Strings")
  local G = love.graphics

  local COLORS = {
    ["."] = { 1, 1, 1, 1 },
    ["o"] = { 222 / 255, 140 / 255, 115 / 255, 1 },
    ["B"] = { 58 / 255, 41 / 255, 255 / 255, 1 },
    ["#"] = { 0, 0, 0, 1 },
  }

  local TILES = {
    frame = {
      "BBBBBBBB", "BBBBoooB", "BBBBoooB", "BBBBoooB",
      "BoooBBBB", "BoooBBBB", "BoooBBBB", "BBBBBBBB",
    },
    -- top-right corner of a half: white cut at the lower left
    notchHigh = {
      "BBBBBBBB", ".BBBoooB", "..BBoooB", "...BoooB",
      "....BBBB", ".....BBB", "......BB", ".......B",
    },
    -- bottom-left corner of a half: white cut at the upper right
    notchLow = {
      "B.......", "BB......", "BBB.....", "BBBB....",
      "BoooB...", "BoooBB..", "BoooBBB.", "BBBBBBBB",
    },
    divider = {
      "........", "........", "........", "########",
      "########", "........", "........", "........",
    },
    dividerEnd = {
      "##......", "####....", "######..", "########",
      "########", "........", "........", "........",
    },
    idNo = {
      "................",
      ".#.###..........",
      ".#.#.B#.........",
      ".#.#..#.#..#.B#B",
      ".#.#..#.##.#.#.#",
      ".#.#.B#.#.##.#.#",
      ".#.###..#..#.B#B",
      "................",
    },
    status = {
      "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
      "........................................",
      "........................................",
      "...####.#####..###..#####.#...#..####...",
      "..#.......#...#...#...#...#...#.#.......",
      "..#####...#...#...#...#...#...#.#####...",
      "......#...#...#####...#...#...#.....#...",
      "..####....#...#...#...#....###..####....",
    },
    badges = {
      "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB",
      "........................................",
      "........................................",
      "...###....###..####...###..####..####...",
      "...#..#..#...#.#...#.#.....#....#.......",
      "...#####.#...#.#...#.#..##.####.#####...",
      "...#...#.#####.#...#.#...#.#........#...",
      "...#####.#...#.####...###..####.####....",
    },
    colon = {
      "........", "........", "...##...", "...##...",
      "........", "...##...", "...##...", "........",
    },
    cursor = {
      ".##.....", ".###....", ".####...", ".#####..",
      ".####...", ".###....", ".##.....", "........",
    },
  }

  local tileCache = {}
  local function tileImage(name)
    local hit = tileCache[name]
    if hit ~= nil then return hit or nil end
    local rows = TILES[name]
    local ok, img = pcall(function()
      local data = love.image.newImageData(#rows[1], #rows)
      for y, row in ipairs(rows) do
        for x = 1, #row do
          local c = COLORS[row:sub(x, x)] or COLORS["."]
          data:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4])
        end
      end
      local image = G.newImage(data)
      image:setFilter("nearest", "nearest")
      return image
    end)
    tileCache[name] = (ok and img) or false
    return tileCache[name] or nil
  end

  local function tile(name, tx, ty)
    local img = tileImage(name)
    if img then
      G.setColor(1, 1, 1, 1)
      G.draw(img, tx * 8, ty * 8)
    end
  end

  local assetCache = {}
  local function asset(rel)
    local hit = assetCache[rel]
    if hit ~= nil then return hit or nil end
    local img
    if mod.assets and type(mod.assets.image) == "function" then
      local ok, loaded = pcall(function() return mod.assets:image(rel) end)
      if ok then img = loaded end
    end
    if not img and type(mod.read) == "function" then
      pcall(function()
        local bytes = mod:read(rel)
        local file = love.filesystem.newFileData(bytes, rel)
        img = G.newImage(file)
      end)
    end
    if img then pcall(img.setFilter, img, "nearest", "nearest") end
    assetCache[rel] = img or false
    return img
  end

  local function text(s, x, y)
    G.setColor(0, 0, 0, 1)
    Font.draw(s, x, y)
  end

  local function padLeft(s, width)
    s = tostring(s)
    if #s >= width then return s end
    return (" "):rep(width - #s) .. s
  end

  -- Gold's money: six digits wide, the ¥ just before the first real digit.
  local function moneyText(amount)
    local digits = ("%06d"):format(math.max(0, math.min(999999, math.floor(tonumber(amount) or 0))))
    local first = digits:find("[1-9]") or #digits
    return (" "):rep(first - 1) .. "\xc2\xa5" .. digits:sub(first)
  end

  -----------------------------------------------------------------------
  -- The portrait: whatever the game would show on its own card (the
  -- Gender Mod / Crystal art when set), trimmed to its drawn pixels and
  -- stood on the bottom of Gold's 5x7 box.
  -----------------------------------------------------------------------
  local BOX_X, BOX_Y, BOX_W, BOX_H = 112, 8, 40, 56
  -- art wider than the box may lean left up to the divider's arrow
  local LEFT_LIMIT = 104
  -- a plain grey Red gets Gold's player colours
  local SKIN = { 236, 168, 120 }
  local RED = { 216, 64, 48 }

  local function loadPortrait(game)
    local Assets = require("src.render.Assets")
    local Sprites = require("src.pokemon.Sprites")
    local okP, path, trueColor = pcall(Sprites.playerPath, game.data, "front",
      { kind = "trainer_card" })
    if not (okP and path) then return nil end
    local resolved = path
    pcall(function() resolved = Assets.resolve(path) or path end)
    local okD, data = pcall(love.image.newImageData, resolved)
    if not (okD and data) then return nil end
    local w, h = data:getDimensions()

    -- A file of the Crystal component's (Gender Mod art) is mirrored the
    -- same way the game's own card mirrors it.
    local flip = false
    pcall(function()
      local h2 = mod.find and mod.find("crystal_animated_sprites_with_shiny_visuals")
      local ex = h2 and h2.exports
      if ex and type(ex.isCrystalImage) == "function" then
        local probe = G.newImage(resolved)
        flip = ex.isCrystalImage(probe) and true or false
        probe:release()
      end
    end)

    -- Coloured art keeps its colours; a grey pic (the game's own Red) is
    -- tinted, and its white paper is dropped.
    local colored = trueColor and true or false
    if not colored then
      for y = 0, h - 1 do
        for x = 0, w - 1 do
          local r, g, b, a = data:getPixel(x, y)
          if a > 0.05 and math.max(r, g, b) - math.min(r, g, b) > 0.08 then
            colored = true
            break
          end
        end
        if colored then break end
      end
    end
    if not colored then
      data:mapPixel(function(_, _, r, g, b, a)
        if a <= 0.05 then return 0, 0, 0, 0 end
        local l = (r + g + b) / 3
        if l > 0.85 then return 0, 0, 0, 0 end
        if l > 0.5 then return SKIN[1] / 255, SKIN[2] / 255, SKIN[3] / 255, 1 end
        if l > 0.2 then return RED[1] / 255, RED[2] / 255, RED[3] / 255, 1 end
        return 0, 0, 0, 1
      end)
    end

    local x1, y1, x2, y2 = w, h, -1, -1
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        local r, g, b, a = data:getPixel(x, y)
        local paper = r > 0.97 and g > 0.97 and b > 0.97
        if a > 0.05 and not paper then
          if x < x1 then x1 = x end
          if x > x2 then x2 = x end
          if y < y1 then y1 = y end
          if y > y2 then y2 = y end
        end
      end
    end
    if x2 < x1 then return nil end

    local okI, img = pcall(G.newImage, data)
    if not okI then return nil end
    img:setFilter("nearest", "nearest")
    local cw, ch = x2 - x1 + 1, y2 - y1 + 1
    local maxW = BOX_X + BOX_W - LEFT_LIMIT
    local dw, dh = math.min(cw, maxW), math.min(ch, BOX_H)
    -- clip evenly from both sides, and from the top when too tall
    local sx = x1 + math.floor((cw - dw) / 2)
    local sy = y1 + (ch - dh)
    -- centred in the box, standing on its bottom edge
    local px = BOX_X + math.floor((BOX_W - dw) / 2)
    if px < LEFT_LIMIT then px = LEFT_LIMIT end
    if px + dw > BOX_X + BOX_W then px = BOX_X + BOX_W - dw end
    return {
      img = img, flip = flip, w = w,
      quad = G.newQuad(sx, sy, dw, dh, w, h),
      x = px, y = BOX_Y + BOX_H - dh, dw = dw, dh = dh,
    }
  end

  -----------------------------------------------------------------------
  -- Kanto badges
  -----------------------------------------------------------------------
  -- number tag at CELL; leader face at +10,+7; badge at +0,+7
  local CELL = {
    { 16, 81 }, { 48, 81 }, { 80, 81 }, { 112, 81 },
    { 16, 105 }, { 48, 105 }, { 80, 105 }, { 112, 105 },
  }

  local function ownedBadges(game)
    local owned = {}
    local save = game and game.save or {}
    local inventory = save.inventory or {}
    local ok, Badges = pcall(require, "src.inventory.Badges")
    if ok and Badges then
      for i, entry in ipairs(Badges.list(game.data)) do
        if i > 8 then break end
        if inventory[Badges.itemFor(entry)] then owned[i] = true end
      end
    end
    return owned
  end

  -- Gold's badge spin: the badge itself on every 4th step, the three shine
  -- frames in between, mirrored for the second half of the turn.
  local function badgeFrame(step, index0)
    if step % 4 == 0 then return index0 end
    return 7 + (step % 4)
  end

  -----------------------------------------------------------------------
  local Card = { isMenu = true }
  Card.__index = Card
  Card.isOpaque = true

  function Card.new(game, opts)
    opts = opts or {}
    local self = setmetatable({}, Card)
    self.game = game
    self.onCancel = opts.onCancel or opts.onClose
    self.page = 1
    self.frames = 0
    self.highlanderTrainerId = true
    local ok, pic = pcall(loadPortrait, game)
    if ok then
      self.portrait = pic
    elseif not mod._tidWarned then
      mod._tidWarned = true
      mod.log:warn("trainer id portrait: %s", tostring(pic))
    end
    return self
  end

  -- The whole page is drawn in its own colours.
  function Card:sgbPalettes()
    local ok, PaletteFX = pcall(require, "src.render.PaletteFX")
    if not ok then return nil end
    return { PaletteFX.zone(false, 0, 0, 19, 17) }
  end

  function Card:pages() return 2 end

  local function blip(game)
    local data = game and game.data
    if not data then return end
    local ok, Sound = pcall(require, "src.core.Sound")
    if ok then pcall(Sound.play, data, "Press_AB") end
  end

  function Card:close()
    if self.closed then return end
    self.closed = true
    self.game.stack:pop()
    if self.onCancel then self.onCancel() end
  end

  function Card:update()
    self.frames = self.frames + 1
    local input = self.game and self.game.input
    if not input or self.closed then return end
    if input:wasPressed("b") or input:wasPressed("start") then
      blip(self.game)
      return self:close()
    end
    if input:wasPressed("right") or input:wasPressed("left") then
      blip(self.game)
      self.page = self.page == 1 and 2 or 1
      return
    end
    if input:wasPressed("a") then
      blip(self.game)
      if self.page == 1 then
        self.page = 2
      else
        return self:close()
      end
    end
  end

  ------------------------------------------------------------- drawing
  -- Gold's TrainerCard_InitBorder: d + 4 rows starting at row ty.
  local function frame(ty, interiorRows)
    for x = 0, 19 do tile("frame", x, ty) end
    tile("frame", 0, ty + 1)
    tile("notchHigh", 18, ty + 1)
    tile("frame", 19, ty + 1)
    for row = 2, interiorRows + 1 do
      tile("frame", 0, ty + row)
      tile("frame", 19, ty + row)
    end
    local notch = ty + interiorRows + 2
    tile("frame", 0, notch)
    tile("notchLow", 1, notch)
    tile("frame", 19, notch)
    for x = 0, 19 do tile("frame", x, ty + interiorRows + 3) end
  end

  function Card:drawPortrait()
    local p = self.portrait
    if not p then return end
    G.setColor(1, 1, 1, 1)
    if p.flip then
      G.draw(p.img, p.quad, p.x + p.dw, p.y, 0, -1, 1)
    else
      G.draw(p.img, p.quad, p.x, p.y)
    end
  end

  function Card:drawTopHalf()
    local save = self.game.save or {}
    local player = save.player or {}
    frame(0, 5)
    for x = 1, 12 do tile("divider", x, 3) end
    tile("dividerEnd", 13, 3)
    text(Strings("NAME/"), 16, 16)
    text(player.name or "RED", 56, 16)
    tile("idNo", 2, 4)
    text(("%05d"):format(math.floor(tonumber(player.id) or 0) % 100000), 40, 32)
    text(Strings("MONEY"), 16, 48)
    text(moneyText(save.money), 56, 48)
    self:drawPortrait()
  end

  function Card:ownedCount()
    local n = 0
    local dex = self.game.save and self.game.save.pokedex
    for _, has in pairs((dex and dex.owned) or {}) do
      if has then n = n + 1 end
    end
    return n
  end

  function Card:drawStatus()
    tile("status", 2, 8)
    text(Strings("POKéDEX"), 16, 80)
    text(padLeft(self:ownedCount(), 3), 120, 80)
    text(Strings("PLAY TIME"), 16, 96)
    local t = math.floor(tonumber(self.game.save and self.game.save.playTime) or 0)
    text(padLeft(math.min(9999, math.floor(t / 3600)), 4), 88, 96)
    -- the colon blinks every 32 frames, like Gold's
    if math.floor(self.frames / 32) % 2 == 0 then tile("colon", 15, 12) end
    text(("%02d"):format(math.floor(t / 60) % 60), 128, 96)
    text(Strings("BADGES"), 96, 120)
    tile("cursor", 18, 15)
  end

  function Card:drawBadges()
    tile("badges", 2, 8)
    local nums = asset("assets/badge_numbers.png")
    local faces = asset("assets/kanto_leaders_gen1.png")
    local badges = asset("assets/kanto_badges.png")
    local owned = ownedBadges(self.game)
    local step = math.floor(self.frames / 8) % 8
    G.setColor(1, 1, 1, 1)
    for i = 1, 8 do
      local fx, fy = CELL[i][1], CELL[i][2]
      if nums then
        local iw, ih = nums:getDimensions()
        G.draw(nums, G.newQuad(0, (i - 1) * 8, 8, 8, iw, ih), fx, fy)
      end
      if faces then
        local iw, ih = faces:getDimensions()
        G.draw(faces, G.newQuad(0, (i - 1) * 16, 22, 16, iw, ih), fx + 10, fy + 7)
      end
      if owned[i] and badges then
        local iw, ih = badges:getDimensions()
        local q = G.newQuad(0, badgeFrame(step, i - 1) * 16, 16, 16, iw, ih)
        if step >= 4 then
          G.draw(badges, q, fx + 16, fy + 7, 0, -1, 1)
        else
          G.draw(badges, q, fx, fy + 7)
        end
      end
    end
  end

  function Card:draw()
    G.push("all")
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, 160, 144)
    local ok, err = pcall(function()
      self:drawTopHalf()
      frame(8, 6)
      if self.page == 2 then self:drawBadges() else self:drawStatus() end
    end)
    if not ok and not mod._tidDrawWarned then
      mod._tidDrawWarned = true
      mod.log:warn("trainer id draw: %s", tostring(err))
    end
    G.pop()
    G.setColor(1, 1, 1, 1)
  end

  return Card
end
