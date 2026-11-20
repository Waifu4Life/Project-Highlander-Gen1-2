-- Extra Types (Red/Blue/Yellow): Gold/Silver/Crystal's Metronome animation,
-- used by Taunt and by Metronome itself.
--
-- pokecrystal BattleAnim_Metronome: the hand (BATTLE_ANIM_OBJ_METRONOME_HAND,
-- 72,88) swings in a flat ellipse while a sparkle (METRONOME_SPARKLE, 72,80)
-- is added every 8 frames, 5 times, each one waving sideways as it sinks;
-- then 48 more frames. Every frame is worked out here the way
-- engine/battle_anims/functions.asm moves the objects, and handed to the
-- game's animation player as ready-made steps. The 6 tiles (the hand's 4
-- and the sparkle's 2) are in assets/metronome_hand.png.
return function(mod)
  local H = {}
  H.MOVES = { TAUNT = true, METRONOME = true }
  local TS = "ph_metronome_hand"
  local FILE = "assets/metronome_hand.png"
  local SHEET = {
    path = (mod.path or ".") .. "/" .. FILE,
    tiles = 6, width = 48, height = 8,
  }

  -- engine/math/sine.asm `sine_table 32`, calc_sine_wave: a signed result.
  local SINE = {}
  for i = 0, 31 do SINE[i] = math.floor(math.sin(i * math.pi / 32) * 256 + 0.5) end
  local function sine(angle, amp)
    angle = angle % 64
    local negative = angle >= 32
    if negative then angle = angle - 32 end
    local r = math.floor(amp * SINE[angle] / 256)
    return negative and -r or r
  end
  local function cosine(angle, amp) return sine(angle + 0x10, amp) end
  local function wrap(v) return v % 256 end

  -- (dx, dy, tile): BATTLE_ANIM_OAMSET_1B (hand), 14/15 (sparkle)
  local HAND = { { -8, -8, 0 }, { 0, -8, 1 }, { -8, 0, 2 }, { 0, 0, 3 } }
  local SPARKLE_EVERY, SPARKLES, TAIL = 8, 5, 48

  -- One object's OAM entries. On the foe's turn the objects are mirrored
  -- to the other side (InitBattleAnimBuffer with FIX_COORDS): x = -76 - x
  -- with the X offset negated, y = fixY - y.
  local function place(out, isPlayer, x, y, fixY, xOff, yOff, parts)
    local bx, by
    if isPlayer then
      bx, by = x + xOff, y + yOff
    else
      bx, by = (-10 * 8 + 4) - x - xOff, (fixY - y) + yOff
    end
    for _, p in ipairs(parts) do
      out[#out + 1] = { x = wrap(bx + p[1]), y = wrap(by + p[2]), tile = p[3],
                        ts = TS, xf = false, yf = false, obp = "e4" }
    end
  end

  function H.steps(isPlayer)
    local total = SPARKLE_EVERY * SPARKLES + TAIL
    local steps = {}
    for f = 0, total - 1 do
      local sprites = {}
      for n = 0, SPARKLES - 1 do
        local age = f - n * SPARKLE_EVERY
        if age >= 0 then
          -- BATTLE_ANIM_FUNC_METRONOME_SPARKLE_SKETCH
          local xOff = cosine(2 * age, 8)
          local yOff = math.floor((age + 1) / 4)
          if yOff < 0x20 then
            local tile = 4 + math.floor(age / 5) % 2
            place(sprites, isPlayer, 72, 80, 128, xOff, yOff, { { -4, -4, tile } })
          end
        end
      end
      -- BATTLE_ANIM_FUNC_METRONOME_HAND
      place(sprites, isPlayer, 72, 88, 144, cosine(2 * f, 8), sine(2 * f, 2), HAND)
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
        img = G.newImage(love.filesystem.newFileData(bytes, "metronome_hand.png"))
      end)
    end
    if not img then pcall(function() img = G.newImage(SHEET.path) end) end
    if img then pcall(img.setFilter, img, "nearest", "nearest") end
    return img
  end

  -- Fills an AnimPlayer the way AnimPlayer:start does. False if the
  -- picture can't be loaded (the game's own animation plays instead).
  function H.start(player, moveId, isPlayer)
    local data = player.data
    if type(data) ~= "table" then return false end
    data.tilesheets = data.tilesheets or {}
    data.tilesheets[TS] = data.tilesheets[TS] or SHEET
    player.images = player.images or {}
    if player.images[TS] == nil and love and love.graphics and love.graphics.newImage then
      -- one per player: AnimPlayer:release() frees its images at battle end
      local img = newImage()
      if not img then return false end
      player.images[TS] = img
    end
    player.steps = H.steps(isPlayer)
    player.events = { { sound = "METRONOME", frame = 0 } }
    player.stepIndex, player.elapsed, player.eventCursor = 1, 0, 1
    player.stepLeft = player.steps[1].dur
    player.phHandAnim = moveId
    return true
  end

  function H.install()
    local ok, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
    if not ok or type(AnimPlayer) ~= "table" or AnimPlayer.phHandAnim then return end
    local start = AnimPlayer.start
    AnimPlayer.phHandAnim = true
    AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts, ...)
      if H.MOVES[moveId] then
        local okH, done = pcall(H.start, self, moveId, attackerIsPlayer and true or false)
        if okH and done then return end
      end
      return start(self, moveId, attackerIsPlayer, opts, ...)
    end
  end

  return H
end
