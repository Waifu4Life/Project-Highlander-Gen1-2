-- Extra Types: the extra Nurse Joy left of the PC in some Pokemon Centers.
--
-- The first talk gives that center's TM; later talks only say goodbye.
-- Each Joy belongs to one setting (Fairy, Steel or Dark moves): while it is
-- OFF she is not there. A TM is given once per save, so turning a setting
-- OFF and ON again never gives a second copy.
return function(mod, D, state)
  local N = {}
  local OWNER = "highlander_extra_types"

  local function store(save)
    save.modData = save.modData or {}
    local s = save.modData.highlander_extra_types
    if type(s) ~= "table" then
      s = {}
      save.modData.highlander_extra_types = s
    end
    s.got = type(s.got) == "table" and s.got or {}
    -- 1.74.0 swapped TM59 and TM62 (Iron Tail 59 -> 62, Snatch 62 -> Taunt
    -- 59): a save from before keeps "already given" on the right Joy.
    if s.tmNumbers ~= 2 then
      s.got[59], s.got[62] = s.got[62], s.got[59]
      s.tmNumbers = 2
    end
    return s
  end

  local function tmRow(number)
    for _, row in ipairs(D.TMS) do
      if row.number == number then return row end
    end
  end

  local function itemId(number)
    return "TM_" .. tmRow(number).move
  end

  local function gotText(data, number)
    local row = tmRow(number)
    local move = data and data.moves and data.moves[row.move]
    local name = move and move.name or row.move
    return string.format(D.TEXT.got, string.format("TM%02d %s", number, name))
  end

  -- The live Gen 1 overworld, or nil.
  local function gen1Overworld(game)
    local stack = game and game.stack
    for _, st in ipairs(stack and stack.states or {}) do
      if type(st) == "table" and st.isOverworld then return st end
    end
    if type(game) == "table" and type(game.overworld) == "table" then
      return game.overworld
    end
    return nil
  end

  local function mapsOf(game)
    if state.generation == 2 then
      local world = game and game.world
      return world and world.maps or (game and game.data and game.data.maps)
    end
    return game and game.data and game.data.maps
  end

  ---------------------------------------------------------------- giving
  local function giveTm(game, number)
    local save = game.save
    local s = store(save)
    if s.got[number] then return "had" end
    local Bag = require("src.inventory.Bag")
    local ok, added = pcall(Bag.add, save, itemId(number), 1, game.data)
    if not ok or added == false then return "full" end
    s.got[number] = true
    return "given"
  end

  -- Red/Blue/Yellow
  local function talkGen1(game, ow, npc, number)
    local TextBox = require("src.render.TextBox")
    local function release() npc.frozen = false end
    if npc.facePlayer and ow.player then pcall(npc.facePlayer, npc, ow.player) end
    local function bye()
      game.stack:push(TextBox.new(game, D.TEXT.bye, release))
    end
    if store(game.save).got[number] then
      bye()
      return
    end
    game.stack:push(TextBox.new(game, D.TEXT.gift, function()
      local result = giveTm(game, number)
      if result == "full" then
        game.stack:push(TextBox.new(game, D.TEXT.full, release))
        return
      end
      local opts = {
        auto = {
          sound = function()
            local Sound = require("src.core.Sound")
            return Sound.play(game.data, "Get_Item1")
          end,
          wait = true,
        },
      }
      local okBox, box = pcall(TextBox.new, game, gotText(game.data, number), bye, opts)
      if not okBox then box = TextBox.new(game, gotText(game.data, number), bye) end
      game.stack:push(box)
    end))
  end

  -- Gold/Silver/Crystal
  local function talkGen2(world, npc, number)
    local game = world.game or require("src.core.Game")
    if npc and npc.facePlayer and world.player then
      pcall(npc.facePlayer, npc, world.player)
    end
    if store(game.save).got[number] then
      world:showText(D.TEXT.bye)
      return true
    end
    world:showText(D.TEXT.gift, function()
      local result = giveTm(game, number)
      if result == "full" then
        world:showText(D.TEXT.full)
        return
      end
      pcall(world.playSfxNamed, world, "Sfx_GetTm")
      world:showText(gotText(game.data, number), function()
        world:showText(D.TEXT.bye)
      end)
    end)
    return true
  end

  -- Red/Blue/Yellow talk: the Joy has no TEXT_* of her own.
  pcall(function()
    mod.hooks:wrap("world.talk", function(nextFn, ow, npc, ...)
      local def = type(npc) == "table" and npc.def
      local number = type(def) == "table" and def.phExtraTm
      if state.generation == 1 and number then
        local game = (type(ow) == "table" and ow.game) or require("src.core.Game")
        talkGen1(game, ow, npc, number)
        return true
      end
      return nextFn(ow, npc, ...)
    end)
  end)

  ---------------------------------------------------------------- objects
  local function gen2NurseTemplate(def)
    for _, obj in ipairs(def.objects or {}) do
      if obj.sprite == "SPRITE_NURSE" and not obj.runtime then return obj end
    end
  end

  local function newObject(def, spot)
    if state.generation == 2 then
      local template = gen2NurseTemplate(def)
      local obj = {}
      for k, v in pairs(template or {}) do
        if k ~= "index" and k ~= "script" and k ~= "scriptKey" then
          obj[k] = type(v) == "table" and { unpack(v) } or v
        end
      end
      if type(template and template.radius) == "table" then
        obj.radius = { x = template.radius.x, y = template.radius.y }
      end
      obj.sprite = obj.sprite or "SPRITE_NURSE"
      obj.eventFlag = obj.eventFlag or 65535
      obj.movement = obj.movement or 6
      obj.x, obj.y = spot.x, spot.y
      obj.phExtraTm = spot.tm
      obj.onTalk = function(world, npc) return talkGen2(world, npc, spot.tm) end
      return obj
    end
    return {
      sprite = "SPRITE_NURSE", movement = "STAY", range = "DOWN",
      x = spot.x, y = spot.y, name = "NURSE JOY",
      text = "TEXT_PH_EXTRA_NURSE", phExtraTm = spot.tm,
    }
  end

  local function findOurs(def)
    for i, obj in ipairs(def.objects or {}) do
      if obj.runtime and obj.owner == OWNER and obj.phExtraTm then return obj, i end
    end
  end

  local function liveHost(game)
    if state.generation == 2 then
      local world = game and game.world
      if type(world) == "table" and type(world.addRuntimeObject) == "function" then
        return world
      end
      return nil
    end
    local ow = gen1Overworld(game)
    if type(ow) == "table" and type(ow.addRuntimeObject) == "function" then return ow end
    return nil
  end

  local function addNurse(game, maps, spot)
    local def = maps[spot.map]
    if not def then return end
    local obj = newObject(def, spot)
    local host = liveHost(game)
    if host then
      local ok = pcall(host.addRuntimeObject, host, spot.map, obj, OWNER)
      if ok then return end
    end
    def.objects = def.objects or {}
    local index = 0
    for _, o in ipairs(def.objects) do
      if (o.index or 0) > index then index = o.index end
    end
    obj.index, obj.runtime, obj.owner = index + 1, true, OWNER
    table.insert(def.objects, obj)
  end

  local function removeNurse(game, maps, mapId)
    local def = maps[mapId]
    local obj, i = def and findOurs(def)
    if not obj then return end
    local host = liveHost(game)
    if host and type(host.removeRuntimeObject) == "function" then
      local ok, done = pcall(host.removeRuntimeObject, host,
        mapId .. "_obj_" .. tostring(obj.index), OWNER)
      if ok and done then return end
    end
    table.remove(def.objects, i)
  end

  -- Puts each Joy in or out of her center to match the settings.
  function N.sync(game)
    local maps = mapsOf(game)
    if type(maps) ~= "table" then return end
    for _, spot in ipairs(D.NURSES[state.generation] or {}) do
      local def = maps[spot.map]
      if type(def) == "table" then
        local want = state.tmGroupOn(tmRow(spot.tm).group)
        local have = findOurs(def)
        if want and not have then
          addNurse(game, maps, spot)
        elseif have and not want then
          removeNurse(game, maps, spot.map)
        end
      end
    end
  end

  N.store = store
  N.giveTm = giveTm
  return N
end
