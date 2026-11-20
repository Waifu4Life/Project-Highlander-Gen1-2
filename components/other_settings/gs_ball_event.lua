-- The GS Ball / Celebi event, Crystal's way, after the Hall of Fame.
--
-- Crystal: the event is already on the cart.  Its Goldenrod Pokecenter scene
-- asks BattleTowerAction GSBALL, which answers from sGSBallFlag
-- (src/script/gen2/specials/battle_tower.lua), and that flag is set by a
-- Japanese mobile-event download nobody can receive any more.  So on Crystal
-- this module only sets save.crystal.gsBall once the player is Champion and
-- lets the cart's own scripts do the rest: receptionist, Kurt, Azalea, the
-- Ilex shrine and Celebi.
--
-- Gold / Silver: none of that exists on the cart, so the same four scenes are
-- rebuilt from pokecrystal's scripts and text (maps/GoldenrodPokecenter1F.asm,
-- maps/KurtsHouse.asm, maps/AzaleaTown.asm, maps/IlexForest.asm), run on the
-- engine's own script VM so the walks, text boxes, emotes, sounds and the
-- battle behave like any cart cutscene.  Where Gold's maps differ from
-- Crystal's (the Ilex shrine clearing, Kurt's house exit), the path is worked
-- out from the live map instead of being copied blind.
--
-- Stages (save.flags.PH_GS_STAGE):
--   nil            not offered yet (offered after the Hall of Fame)
--   "have"         the receptionist handed it over; take it to Kurt
--   "at_kurt"      Kurt is studying it until the next day
--   "kurt_outside" Kurt ran out; he waits by his door in Azalea
--   "restless"     Kurt gave it back; take it to the Ilex Forest shrine
--   "done"         the GS Ball went into the shrine
return function(mod, h)
  local OWNER = "project_highlander_gen1_2"
  local GS = {}

  -- pokecrystal text, verbatim (\f is a new paragraph, \v scrolls a line).
  local T = {
    receptionist = "{PLAYER}, isn't it?\fCongratulations!\fAs a special deal,\na GS BALL has been\vsent just for you!\fPlease accept it!{DONE}",
    comeAgain = "Please do come\nagain!{DONE}",
    received = "{PLAYER} received\nGS BALL.{DONE}",
    pocket = "{PLAYER} put the\nGS BALL in\vthe KEY POCKET.{PROMPT}",
    kurtWhat = "Wh-what is that?\fI've never seen\none before.\fIt looks a lot\nlike a POKé BALL,\fbut it appears to\nbe something else.\fLet me check it\nfor you.{DONE}",
    kurtChecking = "I'm checking it\nnow.{DONE}",
    kurtAhHa = "Ah-ha! I see!\nSo…{DONE}",
    kurtShake = "{PLAYER}!\fThis BALL started\nto shake while I\vwas checking it.\fThere must be\nsomething to this!{DONE}",
    kurtRestless = "ILEX FOREST is\nrestless!\fWhat is going on?{DONE}",
    kurtBack = "{PLAYER}, here's\nyour GS BALL back!{DONE}",
    kurtGoSee = "Could you go see\nwhy ILEX FOREST is\vso restless?{DONE}",
    shrineAsk = "ILEX FOREST\nSHRINE…\fIt's in honor of\nthe forest's\vprotector…\fOh? What is this?\fIt's a hole.\nIt looks like the\fGS BALL would fit\ninside it.\fWant to put the GS\nBALL here?{DONE}",
    shrinePut = "{PLAYER} put in the\nGS BALL.{DONE}",
    kurtWhew = "Whew, wasn't that\nsomething!\f{PLAYER}, that was\nfantastic. Thanks!\fThe legends about\nthat SHRINE were\vreal after all.\fI feel inspired by\nwhat I just saw.\fIt motivates me to\nmake better BALLS!\fI'm going!{DONE}",
  }

  -- engine/overworld movement bytes (src/script/gen2/Movement.lua)
  local DIR = { down = 0, up = 1, left = 2, right = 3 }
  local function turn(d) return DIR[d] end
  local function step(d) return 0x0c + DIR[d] end
  local function bigStep(d) return 0x10 + DIR[d] end
  local SLOW_DOWN, FIX_FACING, REMOVE_FIXED, STEP_END = 0x08, 0x3b, 0x3a, 0x47
  local FACE = DIR -- turnobject takes the same 0-3

  local CELEBI_INDEX = 251
  local CELEBI_LEVEL = 30

  -- ---- small helpers ------------------------------------------------------

  local function flags(game)
    game.save.flags = game.save.flags or {}
    return game.save.flags
  end

  local function cart()
    local v
    pcall(function()
      local GameVersion = require("src.core.GameVersion")
      v = GameVersion.get and GameVersion.get()
    end)
    v = tostring(v or ""):lower()
    if v == "gold" or v == "silver" or v == "crystal" then return v end
    return nil
  end

  local function mapIdOf(world)
    return world and world.map and tostring(world.map.id or "") or ""
  end

  local function hasBall(save)
    return h.hasItem(save, "GS_BALL") or h.hasItem(save, "GSBALL")
  end

  local function dropBall(save)
    for _ = 1, 4 do
      if not hasBall(save) then return end
      h.takeItem(save, "GS_BALL")
      h.takeItem(save, "GSBALL")
    end
  end

  local function sfx(world, name, fallback)
    local ok, id = pcall(world.sfxIdNamed, world, name, fallback)
    return ok and id or fallback
  end

  local function musicId(game, name, fallback)
    local audio = game and game.data and game.data.audio
    local order = audio and audio.musicOrder
    if type(order) == "table" then
      for i, n in ipairs(order) do
        if n == name then return i - 1 end
      end
    end
    return fallback
  end

  local function eventId(world, name)
    local order = world and world.constants and world.constants.eventFlagOrder
    if type(order) ~= "table" then return nil end
    for i, n in pairs(order) do
      if n == name and type(i) == "number" then return i - 1 end
    end
    return nil
  end

  -- Champion = the Hall of Fame was entered, which is the bit the cart itself
  -- uses (HallOfFame.hasEntered: count > 0 or `entered`), or the E4 event flag.
  -- An EMPTY hallOfFame table is not proof of anything: every new Gen 2 save
  -- starts with { count = 0, teams = {} }.
  function GS.champion(save, world)
    if type(save) ~= "table" then return false end
    local okH, HoF = pcall(require, "src.core.gen2.HallOfFame")
    if okH and type(HoF) == "table" and type(HoF.hasEntered) == "function" then
      local ok, yes = pcall(HoF.hasEntered, save)
      if ok and yes then return true end
    end
    local hof = save.hallOfFame
    if type(hof) == "table" then
      if (tonumber(hof.count) or 0) > 0 or hof.entered == true then return true end
      if type(hof.teams) == "table" and hof.teams[1] ~= nil then return true end
    end
    if world and world.events then
      local id = eventId(world, "EVENT_BEAT_ELITE_FOUR")
      if id then
        local ok, set = pcall(world.events.get, world.events, id)
        if ok and set then return true end
      end
    end
    local f = save.flags or {}
    return (f.PH_CHAMPION or f.BEAT_ELITE_FOUR or f.EVENT_BEAT_ELITE_FOUR
      or f.HALL_OF_FAME) and true or false
  end

  local function stage(game) return flags(game).PH_GS_STAGE end
  local function setStage(game, s) flags(game).PH_GS_STAGE = s end

  local function enabled()
    return h.feat("gen2_celebi")
  end

  -- ---- running a scene ----------------------------------------------------
  --
  -- A scene is a row list for the VM.  `after` runs in Lua once the VM is
  -- idle again, which is how the steps the VM cannot express (spawning and
  -- removing our own actors, the bag, the stage) are chained between scripts.
  local seq = nil

  local function startScene(world, rows, after, talkNpc)
    if not (world and world.vm) then return false end
    if talkNpc then
      world.talkNpc = talkNpc
      if type(world.freezeNpc) == "function" then world:freezeNpc(talkNpc) end
      if talkNpc.def then world.vm.lastTalked = (talkNpc.def.index or 0) + 1 end
      local ok, started = pcall(world.vm.start, world.vm, rows)
      if not (ok and started) then return false end
      seq = { world = world, rows = rows, after = after, live = true }
      return true
    end
    world.queuedScript = rows
    seq = { world = world, rows = rows, after = after }
    return true
  end

  local function pumpScene()
    local s = seq
    if not s then return end
    local w = s.world
    if not s.live then
      if w.queuedScript == s.rows then return end -- still waiting to start
      s.live = true
    end
    if (w.vm and w.vm:running()) or w.battleActive then return end
    seq = nil
    if s.after then
      local ok, err = pcall(s.after, w)
      if not ok then pcall(function() mod.log:error("GS Ball scene: %s", tostring(err)) end) end
    end
  end

  local function busy(world)
    if seq then return true end
    if world.battleActive then return true end
    local ok, b = pcall(world.busy, world)
    if ok and b then return true end
    return world.player and world.player.moving or false
  end

  -- registers movement bytes on the VM under our own key
  local function moves(world, key, bytes)
    world.vm.movements = world.vm.movements or {}
    world.vm.movements[key] = bytes
    return key
  end

  -- the "verbosegiveitem GS_BALL" lines, for a ball the VM cannot index
  local function giveRows(rows)
    rows[#rows + 1] = { op = "rawtext", text = T.received, stay = true }
    rows[#rows + 1] = { op = "specialsound" }
    rows[#rows + 1] = { op = "rawtext", text = T.pocket }
    return rows
  end

  -- ---- our own actors -----------------------------------------------------

  local actors = {} -- name -> { npcId, mapId, objectId }

  local function spawnActor(world, name, sprite, x, y, movement)
    local mid = mapIdOf(world)
    local old = actors[name]
    if old and old.mapId == mid then return old end
    local objDef = {
      sprite = sprite, x = x, y = y, movement = movement or 6,
      eventFlag = 0xFFFF, hours = { -1, -1 }, radius = { x = 0, y = 0 },
      palette = 0, type = 0, sight = 0, name = name,
    }
    local ok, npcId = pcall(world.addRuntimeObject, world, mid, objDef, OWNER)
    if not (ok and npcId) then return nil end
    local a = { npcId = npcId, mapId = mid, objectId = (objDef.index or 0) + 1 }
    actors[name] = a
    return a
  end

  local function removeActor(world, name)
    local a = actors[name]
    if not a then return end
    actors[name] = nil
    pcall(world.removeRuntimeObject, world, a.npcId, OWNER)
  end

  local function removeAllActors(world)
    for name in pairs(actors) do removeActor(world, name) end
  end

  local function isOurActor(npc, name)
    return npc and npc.def and npc.def.runtime and npc.def.name == name
  end

  -- Kurt sits out the "kurt_outside" and "restless" stages: he is by his door
  -- in Azalea.  Masked for this visit only, so no story flag is touched.
  local function hideHouseKurt(world)
    local def = world.map and world.map.def
    if not def then return end
    local changed = false
    for i, obj in ipairs(def.objects or {}) do
      if obj.sprite == "SPRITE_KURT" and not obj.runtime then
        local index = obj.index or i
        local key = world.objectMaskKey and world:objectMaskKey(obj, index)
        if not (key and world.objectMasks and world.objectMasks[key]) then
          pcall(world.setObjectMask, world, obj, index, true)
          changed = true
        end
      end
    end
    if changed then pcall(world.rebuildPeople, world, { seamless = true }) end
  end

  -- Breadth-first walk for Kurt's run to the door, around the furniture and
  -- the player, whatever room layout the cart has.
  local function pathTo(world, fromX, fromY, goals, ignoreNpc)
    local map = world.map
    local blocked = {}
    for _, n in ipairs(world.npcs or {}) do
      if n ~= ignoreNpc and n.cellX then blocked[n.cellX .. "," .. n.cellY] = true end
    end
    local p = world.player
    if p then blocked[p.cellX .. "," .. p.cellY] = true end
    local goal = {}
    for _, g in ipairs(goals) do goal[g[1] .. "," .. g[2]] = true end
    local DIRS = { { "down", 0, 1 }, { "left", -1, 0 }, { "right", 1, 0 }, { "up", 0, -1 } }
    local start = fromX .. "," .. fromY
    local prev, queue, head = { [start] = false }, { { fromX, fromY } }, 1
    local found
    while queue[head] do
      local c = queue[head]
      head = head + 1
      local key = c[1] .. "," .. c[2]
      if goal[key] then found = key break end
      for _, d in ipairs(DIRS) do
        local nx, ny = c[1] + d[2], c[2] + d[3]
        local nk = nx .. "," .. ny
        if prev[nk] == nil and not blocked[nk] then
          local ok, walk = pcall(map.isWalkable, map, nx, ny)
          if (ok and walk) or goal[nk] then
            prev[nk] = { key, d[1] }
            queue[#queue + 1] = { nx, ny }
          end
        end
      end
    end
    if not found then return nil end
    local dirs = {}
    local k = found
    while prev[k] do
      table.insert(dirs, 1, prev[k][2])
      k = prev[k][1]
    end
    return dirs
  end

  -- ---- scene 1: Goldenrod Pokecenter 1F -----------------------------------
  -- maps/GoldenrodPokecenter1F.asm GoldenrodPokecenter1F_GSBallSceneLeft/Right
  local function receptionistScene(world, game)
    local p = world.player
    local right = p.cellX == 4
    local a = spawnActor(world, "ph_gs_receptionist", "SPRITE_LINK_RECEPTIONIST", 0, 7, 7)
    if not a then return false end
    local inBytes, outBytes = { step("up") }, {}
    local across = right and 4 or 3
    for _ = 1, across do inBytes[#inBytes + 1] = step("right") end
    inBytes[#inBytes + 1] = turn("down")
    inBytes[#inBytes + 1] = STEP_END
    for _ = 1, across do outBytes[#outBytes + 1] = step("left") end
    outBytes[#outBytes + 1] = step("down")
    outBytes[#outBytes + 1] = STEP_END
    local exitSfx = sfx(world, "Sfx_ExitBuilding", 35)
    local rows = {
      { op = "playsound", id = exitSfx },
      { op = "playmusic", id = musicId(game, "Music_ShowMeAround", 17) },
      { op = "applymovement", object = a.objectId, movement = moves(world, "ph_gs_rcp_in", inBytes) },
      { op = "turnobject", object = 0, facing = FACE.up },
      { op = "opentext" },
      { op = "rawtext", text = T.receptionist },
      { op = "waitbutton" },
    }
    giveRows(rows)
    rows[#rows + 1] = { op = "rawtext", text = T.comeAgain }
    rows[#rows + 1] = { op = "waitbutton" }
    rows[#rows + 1] = { op = "closetext" }
    rows[#rows + 1] = { op = "applymovement", object = a.objectId,
      movement = moves(world, "ph_gs_rcp_out", outBytes) }
    rows[#rows + 1] = { op = "playmapmusic" }
    rows[#rows + 1] = { op = "playsound", id = exitSfx }
    rows[#rows + 1] = { op = "end" }
    h.grantGsBall(game)
    setStage(game, "have")
    return startScene(world, rows, function(w)
      removeActor(w, "ph_gs_receptionist")
    end)
  end

  -- ---- scene 2: Kurt's house ----------------------------------------------
  -- maps/KurtsHouse.asm Kurt1's GS Ball arms
  local function kurtReady(game)
    local f = flags(game)
    local okC, Clock = pcall(require, "src.core.gen2.Clock")
    if okC and f.PH_GS_KURT_WDAY ~= nil then
      local ok, day = pcall(Clock.weekday, game.save)
      if ok and day ~= f.PH_GS_KURT_WDAY then return true end
    end
    local t = tonumber(f.PH_GS_KURT_TIME)
    return t ~= nil and os.time() - t >= 24 * 3600
  end

  local function kurtTalk(world, game, npc)
    local s = stage(game)
    if s == "have" and hasBall(game.save) then
      local f = flags(game)
      dropBall(game.save)
      setStage(game, "at_kurt")
      local okC, Clock = pcall(require, "src.core.gen2.Clock")
      if okC then
        local ok, day = pcall(Clock.weekday, game.save)
        if ok then f.PH_GS_KURT_WDAY = day end
      end
      f.PH_GS_KURT_TIME = os.time()
      return startScene(world, {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = T.kurtWhat },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      }, nil, npc)
    end
    if s ~= "at_kurt" then return false end
    if not kurtReady(game) then
      return startScene(world, {
        { op = "faceplayer" },
        { op = "opentext" },
        { op = "rawtext", text = T.kurtChecking },
        { op = "waitbutton" },
        { op = "rawtext", text = T.kurtAhHa },
        { op = "waitbutton" },
        { op = "closetext" },
        { op = "end" },
      }, nil, npc)
    end
    -- The next day: the ball shook, and Kurt runs out of the house.
    local doors = {}
    for _, wp in ipairs((world.map.def and world.map.def.warps) or {}) do
      doors[#doors + 1] = { wp.x, wp.y }
    end
    local path = pathTo(world, npc.cellX, npc.cellY, doors, npc) or {}
    local run = {}
    for _, d in ipairs(path) do run[#run + 1] = bigStep(d) end
    run[#run + 1] = STEP_END
    local kurtObject = (npc.def and npc.def.index or 0) + 1
    return startScene(world, {
      { op = "faceplayer" },
      { op = "opentext" },
      { op = "rawtext", text = T.kurtShake },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "pause", frames = 20 },
      { op = "showemote", emote = 0, object = kurtObject, frames = 30 },
      { op = "turnobject", object = 0, facing = FACE.down },
      { op = "playsound", id = sfx(world, "Sfx_Fly", 24) },
      { op = "applymovement", object = kurtObject, movement = moves(world, "ph_gs_kurt_run", run) },
      { op = "playsound", id = sfx(world, "Sfx_ExitBuilding", 35) },
      { op = "waitsfx" },
      { op = "end" },
    }, function(w)
      setStage(game, "kurt_outside")
      hideHouseKurt(w)
    end, npc)
  end

  -- ---- scene 3: Azalea Town -------------------------------------------------
  -- maps/AzaleaTown.asm AzaleaTown_GSBallScene: Kurt by his door, (6,5).
  local KURT_OUT_X, KURT_OUT_Y = 6, 5

  local function azaleaScene(world, game, kurt)
    local walk = { step("left"), step("left"), step("up"), turn("left"), STEP_END }
    local rows = {
      { op = "applymovement", object = 0, movement = moves(world, "ph_gs_azalea_walk", walk) },
      { op = "opentext" },
      { op = "rawtext", text = T.kurtRestless },
      { op = "turnobject", object = kurt.objectId, facing = FACE.right },
      { op = "rawtext", text = T.kurtBack },
      { op = "rawtext", text = T.kurtGoSee },
      { op = "waitbutton" },
    }
    giveRows(rows)
    rows[#rows + 1] = { op = "turnobject", object = kurt.objectId, facing = FACE.left }
    rows[#rows + 1] = { op = "closetext" }
    rows[#rows + 1] = { op = "end" }
    h.grantGsBall(game)
    setStage(game, "restless")
    return startScene(world, rows)
  end

  local function kurtOutsideTalk(world, game, npc)
    return startScene(world, {
      { op = "faceplayer" },
      { op = "opentext" },
      { op = "rawtext", text = T.kurtGoSee },
      { op = "waitbutton" },
      { op = "turnobject", object = (npc.def.index or 0) + 1, facing = FACE.left },
      { op = "closetext" },
      { op = "end" },
    }, nil, npc)
  end

  -- ---- scene 4: Ilex Forest shrine ----------------------------------------
  -- maps/IlexForest.asm IlexForestShrineScript
  local SHRINE_X, SHRINE_Y = 8, 22

  local function kurtEpilogue(world, game)
    local p = world.player
    local fromX = math.max(0, p.cellX - 5)
    -- walk in along the clearing's row, as far out as the map allows
    while fromX < p.cellX - 1 do
      local ok, walk = pcall(world.map.isWalkable, world.map, fromX, p.cellY)
      if ok and walk then break end
      fromX = fromX + 1
    end
    local steps = p.cellX - 1 - fromX
    if steps < 1 then return end
    local a = spawnActor(world, "ph_gs_kurt_ilex", "SPRITE_KURT", fromX, p.cellY, 9)
    if not a then return end
    local inBytes, outBytes = {}, {}
    for _ = 1, steps do
      inBytes[#inBytes + 1] = step("right")
      outBytes[#outBytes + 1] = step("left")
    end
    inBytes[#inBytes + 1] = STEP_END
    outBytes[#outBytes + 1] = STEP_END
    startScene(world, {
      { op = "applymovement", object = a.objectId, movement = moves(world, "ph_gs_kurt_in", inBytes) },
      { op = "turnobject", object = 0, facing = FACE.left },
      { op = "opentext" },
      { op = "rawtext", text = T.kurtWhew },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "applymovement", object = a.objectId, movement = moves(world, "ph_gs_kurt_out", outBytes) },
      { op = "end" },
    }, function(w) removeActor(w, "ph_gs_kurt_ilex") end)
  end

  local function celebiScene(world, game)
    local before = h.countSpecies(game.save, "CELEBI")
    local backAway = { FIX_FACING, SLOW_DOWN, REMOVE_FIXED, STEP_END }
    startScene(world, {
      { op = "opentext" },
      { op = "rawtext", text = T.shrinePut },
      { op = "waitbutton" },
      { op = "closetext" },
      { op = "pause", frames = 20 },
      { op = "showemote", emote = 0, object = 0, frames = 20 },
      { op = "musicfadeout", id = 0, fade = 16 },
      { op = "applymovement", object = 0, movement = moves(world, "ph_gs_back_away", backAway) },
      { op = "pause", frames = 30 },
      { op = "turnobject", object = 0, facing = FACE.up },
      { op = "pause", frames = 20 },
      { op = "cry", id = CELEBI_INDEX },
      { op = "loadwildmon", species = CELEBI_INDEX, level = CELEBI_LEVEL },
      { op = "startbattle" },
      { op = "reloadmapafterbattle" },
      { op = "pause", frames = 20 },
      { op = "end" },
    }, function(w)
      if h.countSpecies(game.save, "CELEBI") > before then
        flags(game).PH_CELEBI_CAUGHT = true
        kurtEpilogue(w, game)
      end
    end)
  end

  local function shrineInteract(world, game)
    return startScene(world, {
      { op = "opentext" },
      { op = "rawtext", text = T.shrineAsk },
      { op = "yesorno" },
      { op = "closetext" },
      { op = "end" },
    }, function(w)
      if not (w.vm and w.vm.scriptVar == 1) then return end
      dropBall(game.save)
      setStage(game, "done")
      celebiScene(w, game)
    end)
  end

  -- ---- Crystal: unlock the cart's own event --------------------------------
  local function crystalUnlock(game)
    if flags(game).PH_GS_CRYSTAL then return end
    local okS, Save = pcall(require, "src.core.gen2.Save")
    if not (okS and type(Save.crystalState) == "function") then return end
    local crystal = Save.crystalState(game.save)
    if crystal.gsBall == nil then crystal.gsBall = "have" end
    flags(game).PH_GS_CRYSTAL = true
  end

  -- ---- saves from the old "ball on the floor" version ----------------------
  local OLD = { "PH_GS_MSG", "PH_GS_GIVEN", "PH_GS_PICKED", "PH_GS_AT_KURT",
    "PH_GS_READY", "PH_GS_GIVEN_DAY", "PH_GS_KURT_DAY", "PH_GS_KURT_HOURS",
    "PH_GS_KURT_WALL" }

  local function migrate(game, world, which)
    local f = flags(game)
    if f.PH_GS_V2 then return end
    f.PH_GS_V2 = true
    local any = false
    for _, k in ipairs(OLD) do if f[k] ~= nil then any = true end end
    if not any then return end
    local champ = GS.champion(game.save, world)
    if which == "crystal" or not champ then
      -- The old version handed the ball out too early (or, on Crystal,
      -- instead of the cart's own scene).  Take it back; the real event
      -- plays once the player is Champion.
      if not f.PH_CELEBI_CAUGHT then dropBall(game.save) end
    elseif f.PH_CELEBI_CAUGHT then
      f.PH_GS_STAGE = "done"
    elseif f.PH_GS_READY then
      f.PH_GS_STAGE = "restless"
      if not hasBall(game.save) then h.grantGsBall(game) end
    elseif f.PH_GS_AT_KURT then
      f.PH_GS_STAGE = "at_kurt"
      f.PH_GS_KURT_TIME = tonumber(f.PH_GS_KURT_WALL) or os.time()
    elseif hasBall(game.save) then
      f.PH_GS_STAGE = "have"
    end
    for _, k in ipairs(OLD) do f[k] = nil end
  end

  -- ---- entry points -------------------------------------------------------

  local lastMap = nil

  function GS.update(game)
    local world = game and game.world
    if not (world and world.map and world.player and game.save) then return end
    local which = cart()
    if not which then return end
    pumpScene()
    local mid = mapIdOf(world)
    if mid ~= lastMap then
      -- runtime actors live on the map def for the whole run; drop them
      for name, a in pairs(actors) do
        if a.mapId ~= mid then removeActor(world, name) end
      end
      lastMap = mid
    end
    migrate(game, world, which)
    if not enabled() then return end
    if which == "crystal" then
      if GS.champion(game.save, world) then crystalUnlock(game) end
      return
    end
    local s = stage(game)
    if mid == "KURTS_HOUSE" and (s == "kurt_outside" or s == "restless") then
      hideHouseKurt(world)
    end
    if mid == "AZALEA_TOWN" and (s == "kurt_outside" or s == "restless") then
      local kurt = spawnActor(world, "ph_gs_kurt_outside", "SPRITE_KURT",
        KURT_OUT_X, KURT_OUT_Y, 8)
      local p = world.player
      if kurt and s == "kurt_outside" and p.cellX == 9 and p.cellY == 6
          and not busy(world) then
        azaleaScene(world, game, kurt)
      end
      return
    end
    if mid == "GOLDENROD_POKECENTER_1F" and s == nil and not busy(world) then
      local p = world.player
      if p.cellY == 7 and (p.cellX == 3 or p.cellX == 4)
          and GS.champion(game.save, world) then
        receptionistScene(world, game)
      end
    end
  end

  -- A press on an object.  True when the event took it.
  function GS.talk(world, npc)
    local game = world and world.game
    if not (game and game.save and npc and enabled()) then return false end
    local which = cart()
    if which ~= "gold" and which ~= "silver" then return false end
    if seq then return true end
    if isOurActor(npc, "ph_gs_kurt_outside") then
      return kurtOutsideTalk(world, game, npc)
    end
    if isOurActor(npc, "ph_gs_receptionist") or isOurActor(npc, "ph_gs_kurt_ilex") then
      return true
    end
    if mapIdOf(world) == "KURTS_HOUSE" and npc.def
        and npc.def.sprite == "SPRITE_KURT" and not npc.def.runtime then
      return kurtTalk(world, game, npc)
    end
    return false
  end

  -- A press on a tile.  True when the event took it.
  function GS.interact(world, fx, fy)
    local game = world and world.game
    if not (game and game.save and enabled()) then return false end
    local which = cart()
    if which ~= "gold" and which ~= "silver" then return false end
    if mapIdOf(world) ~= "ILEX_FOREST" then return false end
    if not (fx == SHRINE_X and fy == SHRINE_Y) then return false end
    if world.player and world.player.facing ~= "up" then return false end
    if stage(game) ~= "restless" or not hasBall(game.save) then return false end
    return shrineInteract(world, game)
  end

  function GS.reset(world)
    seq = nil
    if world then removeAllActors(world) end
  end

  return GS
end
