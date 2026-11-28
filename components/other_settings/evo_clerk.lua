-- EVOLUTION ITEM CLERK (1.83.0, Gold/Silver/Crystal). A second clerk on
-- Goldenrod Dept. Store 4F, standing one cell right of the floor's own clerk
-- behind the same counter. He sells all six evolution stones plus Metal
-- Coat, Dragon Scale, King's Rock and Up-Grade, all at ¥2100 -- what
-- Celadon Dept. Store charged for a stone in Red/Blue/Yellow.
--
-- How it's built, all on engine features rather than guesses:
--   * World:addRuntimeObject appends the clerk to the map's object list, so
--     he is pooled, drawn and collides like an extracted object and survives
--     reloads of the map for the rest of the run (it is not saved; he is
--     re-added the first time the floor is entered after loading).
--   * World:interactBody already calls npc.def.onTalk(world, npc) for a
--     talked-to object, and facingObjectCell already looks across counter
--     tiles, so talking to him from the aisle above works like the cart's.
--   * The shop itself is the game's own Gen2MartMenu (BUY / SELL / QUIT),
--     given a one-list shelf; only the prices are set here, because the
--     items' own ItemAttributes prices vary (Moon Stone is ¥0, King's Rock
--     and Metal Coat ¥100). Selling still pays half the item's own price.
return function(mod)
  local OWNER = "project_highlander_evo_clerk"
  local PRICE = 2100

  -- First id the item table knows wins, so a cache that spells one
  -- differently still gets the item rather than an empty row.
  local STOCK = {
    { "FIRE_STONE" },
    { "WATER_STONE" },
    { "THUNDERSTONE", "THUNDER_STONE" },
    { "LEAF_STONE" },
    { "MOON_STONE" },
    { "SUN_STONE" },
    { "METAL_COAT" },
    { "DRAGON_SCALE" },
    { "KINGS_ROCK", "KING_S_ROCK" },
    { "UP_GRADE", "UPGRADE" },
  }

  local function isFloor(mapId)
    local m = tostring(mapId or ""):upper():gsub("[^%w]", "")
    return m:find("GOLDENRODDEPTSTORE4F", 1, true) ~= nil
  end

  local function shelf(items)
    local list = {}
    for _, names in ipairs(STOCK) do
      for _, id in ipairs(names) do
        if type(items) ~= "table" or items[id] then
          list[#list + 1] = id
          break
        end
      end
    end
    return list
  end

  local function openShop(world, npc)
    local game = world and world.game
    if not (game and game.stack) then return false end
    pcall(function()
      if npc and world.player and type(npc.facePlayer) == "function" then
        npc:facePlayer(world.player)
      end
    end)
    local items = game.data and game.data.items
    local Screens = require("src.ui.Screens")
    local inst = Screens.push(game, "Gen2MartMenu", {
      save = game.save,
      items = items,
      marts = { lists = { shelf(items) } },
      martType = "STANDARD",
      martId = 0,
      text = world.text,
      onClose = function() game.stack:pop() end,
    })
    if type(inst) == "table" and type(inst.buildEntries) == "function" then
      local base = inst.buildEntries
      inst.buildEntries = function(self, ...)
        local r = base(self, ...)
        for _, entry in ipairs(self.entries or {}) do entry.price = PRICE end
        return r
      end
      inst:buildEntries()
    end
    return true
  end

  -- The floor's own clerk: the map object whose sprite is a clerk. Matched
  -- on the object list (not live NPCs) so the result doesn't depend on
  -- whether he's been drawn yet.
  local function vanillaClerk(def)
    for _, obj in ipairs(def and def.objects or {}) do
      if not obj.runtime and tostring(obj.sprite or ""):upper():find("CLERK", 1, true) then
        return obj
      end
    end
    return nil
  end

  local function ensureClerk(world)
    if type(world) ~= "table" or type(world.addRuntimeObject) ~= "function" then return end
    local map = world.map
    if not (map and isFloor(map.id)) then return end
    local def = (world.maps and world.maps[map.id]) or map.def
    if type(def) ~= "table" then return end
    for _, obj in ipairs(def.objects or {}) do
      if obj.owner == OWNER then return end
    end
    local clerk = vanillaClerk(def)
    if not (clerk and clerk.x and clerk.y) then
      if not world._phEvoClerkWarned then
        world._phEvoClerkWarned = true
        pcall(function() mod.log:warn("Evolution clerk: no clerk found on %s; not placed", tostring(map.id)) end)
      end
      return
    end
    -- Same look as the floor's clerk (sprite, palette, whatever fields the
    -- extractor gave him) minus everything that makes him HIM: his slot,
    -- his script and the flags/hours that could hide him.
    local SKIP = { index = true, runtime = true, owner = true, script = true,
      scriptKey = true, eventFlag = true, hours = true, text = true,
      onTalk = true, radius = true, trainer = true, kind = true }
    local obj = {}
    for k, v in pairs(clerk) do
      if not SKIP[k] and type(v) ~= "function" then obj[k] = v end
    end
    obj.x, obj.y = clerk.x + 1, clerk.y
    -- Faces the same way as the floor's clerk (STANDING_UP, toward the
    -- counter, on the cart); STANDING_DOWN if his own is unknown.
    obj.movement = type(clerk.movement) == "number" and clerk.movement or 6
    obj.name = "CLERK"
    obj.scriptKey = "ph_evo_clerk"
    obj.onTalk = openShop
    local ok, err = pcall(function() world:addRuntimeObject(map.id, obj, OWNER) end)
    if not ok then
      pcall(function() mod.log:error("Evolution clerk: %s", tostring(err)) end)
    end
  end

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      if game and game.world then pcall(ensureClerk, game.world) end
      return result
    end)
  end)

  pcall(function() mod.log:info("Evolution item clerk ready (Goldenrod Dept. Store 4F)") end)
end
