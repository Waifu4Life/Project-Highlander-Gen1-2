-- Extra Types (Red/Blue/Yellow): Gold/Silver/Crystal's animations for the
-- three Fairy moves, the same ones they use in Gen 2:
--   Baby-Doll Eyes  <- CHARM (the hearts)
--   Draining Kiss   <- SWEET_KISS (the angel and its kiss)
--   Dazzling Gleam  <- FLASH (the sparkles)
--
-- fairy_anim_frames.lua was made by running Gold's own animation scripts
-- through the engine's Gen 2 animation runner, one entry per 60 Hz frame,
-- for both sides of the field; the 21 tiles it uses are in
-- assets/fairy_anims.png. Played through the Gen 1 animation player the
-- same way the Metronome hand is (hand_anim.lua).
return function(mod)
  local F = {}
  F.MOVES = {
    BABY_DOLL_EYES = { anim = "CHARM", sound = "LEER" },
    DRAINING_KISS = { anim = "SWEET_KISS", sound = "LOVELY_KISS" },
    DAZZLING_GLEAM = { anim = "FLASH", sound = "FLASH" },
  }
  local TS = "ph_fairy_anims"
  local FILE = "assets/fairy_anims.png"

  local frames
  local function bank()
    if frames == nil then
      local ok, got = pcall(mod.load, mod, "fairy_anim_frames.lua")
      frames = (ok and type(got) == "table" and got) or false
    end
    return frames or nil
  end

  local function sheet()
    local b = bank()
    local tiles = b and b.tiles or 0
    return {
      path = (mod.path or ".") .. "/" .. FILE,
      tiles = tiles, width = 64, height = math.ceil(tiles / 8) * 8,
    }
  end

  local XFLIP, YFLIP = 0x20, 0x40
  local function hasBit(v, b) return math.floor(v / b) % 2 == 1 end

  function F.steps(moveId, isPlayer)
    local spec = F.MOVES[moveId]
    local b = bank()
    local move = spec and b and b.moves and b.moves[spec.anim]
    local list = move and move[isPlayer and "player" or "enemy"]
    if not list then return nil end
    local steps = {}
    for _, f in ipairs(list) do
      local sprites = {}
      for _, e in ipairs(f) do
        local attr = e[5] or 0
        -- "f0": the move-animation palette, so Colored Moves paints them
        sprites[#sprites + 1] = { x = e[1], y = e[2], tile = e[4], ts = TS,
          xf = hasBit(attr, XFLIP), yf = hasBit(attr, YFLIP), obp = "f0" }
      end
      steps[#steps + 1] = { dur = 1, sprites = sprites }
    end
    steps[#steps + 1] = { dur = 1, sprites = {} }
    return steps
  end

  local bytes
  local function newImage()
    local G = love and love.graphics
    if not (G and G.newImage) then return nil end
    if bytes == nil then
      local ok, got = pcall(mod.read, mod, FILE)
      bytes = ok and got or false
    end
    local img
    if bytes then
      pcall(function()
        img = G.newImage(love.filesystem.newFileData(bytes, "fairy_anims.png"))
      end)
    end
    if not img then pcall(function() img = G.newImage(sheet().path) end) end
    if img then pcall(img.setFilter, img, "nearest", "nearest") end
    return img
  end

  -- Fills an AnimPlayer the way AnimPlayer:start does. False when the
  -- frames or the picture can't be loaded (the move's stand-in plays).
  function F.start(player, moveId, isPlayer)
    local data = player.data
    if type(data) ~= "table" then return false end
    local steps = F.steps(moveId, isPlayer)
    if not steps then return false end
    data.tilesheets = data.tilesheets or {}
    data.tilesheets[TS] = data.tilesheets[TS] or sheet()
    player.images = player.images or {}
    if player.images[TS] == nil and love and love.graphics and love.graphics.newImage then
      local img = newImage()
      if not img then return false end
      player.images[TS] = img
    end
    player.steps = steps
    player.events = { { sound = F.MOVES[moveId].sound, frame = 0 } }
    player.stepIndex, player.elapsed, player.eventCursor = 1, 0, 1
    player.stepLeft = player.steps[1].dur
    player.phHandAnim = moveId
    return true
  end

  function F.install()
    local ok, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
    if not ok or type(AnimPlayer) ~= "table" or AnimPlayer.phFairyAnim then return end
    local start = AnimPlayer.start
    AnimPlayer.phFairyAnim = true
    AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts, ...)
      if F.MOVES[moveId] then
        -- set before starting so Colored Moves knows which move it is
        self._phMove = moveId
        local okF, done = pcall(F.start, self, moveId, attackerIsPlayer and true or false)
        if okF and done then return end
      end
      return start(self, moveId, attackerIsPlayer, opts, ...)
    end
  end

  return F
end
