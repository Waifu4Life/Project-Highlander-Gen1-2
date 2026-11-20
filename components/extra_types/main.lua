-- Extra Types (Mechanics > EXTRA TYPES).
--
-- Adds the Fairy moves and TMs (and Steel/Dark ones in Red/Blue/Yellow),
-- the Gen 6 typings, the extra Nurse Joys who hand out the TMs, and the
-- type chart choices. Everything new is added when the game loads; the
-- settings only switch types around, so they work at once, without a
-- restart:
--   * a typing setting OFF: those Pokemon have this game's own typing
--   * a moves setting OFF: those moves are Normal, and that setting's
--     Nurse Joys are gone. TMs already received stay, and still teach.
return function(mod)
  local D = mod:load("data.lua")
  local E = mod:load("effects.lua")

  local generation = 1
  pcall(function() generation = require("src.core.GameVersion").generation() end)
  if generation ~= 2 then generation = 1 end

  mod.options:define({
    { key = "steel_moves", label = "STEEL TYPE MOVES", type = "toggle",
      default = false, gens = { [1] = true } },
    { key = "steel_pkmn", label = "STEEL TYPE PKMN", type = "toggle",
      default = false, gens = { [1] = true } },
    { key = "dark_moves", label = "DARK TYPE MOVES", type = "toggle",
      default = false, gens = { [1] = true } },
    { key = "extra_steel_move", label = "EXTRA STEEL MOVE", type = "toggle",
      default = false, gens = { [2] = true } },
    { key = "extra_dark_move", label = "EXTRA DARK MOVE", type = "toggle",
      default = false, gens = { [2] = true } },
    { key = "fairy_moves", label = "FAIRY TYPE MOVES", type = "toggle",
      default = false },
    { key = "fairy_pkmn", label = "FAIRY TYPE PKMN", type = "toggle",
      default = false },
    { key = "vs_steel", label = "VS. STEEL TYPES", type = "choice",
      default = "gen2", choices = { { "GEN2", "gen2" }, { "GEN6", "gen6" } } },
    { key = "effectiveness", label = "EFFECTIVENESS", type = "choice",
      default = "gen1", choices = { { "GEN1", "gen1" }, { "GEN2", "gen2" } },
      gens = { [1] = true } },
    { key = "other_gen1_moves", label = "OTHER GEN1 MOVE CHANGES", type = "toggle",
      default = false, gens = { [1] = true } },
  })

  local function on(key)
    local ok, value = pcall(mod.options.get, mod.options, key)
    return ok and value == true
  end
  local function choice(key, default)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok and type(value) == "string" then return value end
    return default
  end

  local state = { generation = generation }

  -- Which setting owns a TM group's Nurse Joys and move types.
  function state.tmGroupOn(group)
    if group == "fairy" then return on("fairy_moves") end
    if generation == 2 then
      if group == "steel" then return on("extra_steel_move") end
      if group == "dark" then return on("extra_dark_move") end
      return false
    end
    if group == "steel" then return on("steel_moves") end
    if group == "dark" then return on("dark_moves") end
    return false
  end

  local function tmInGame(row)
    for _, g in ipairs(row.gens) do
      if g == generation then return true end
    end
    return false
  end

  ---------------------------------------------------------------------------
  -- Added once, when the game loads
  ---------------------------------------------------------------------------
  local content = mod.content
  local chart = content.type_chart

  local function speciesId(id)
    local aliases = D.ALIASES[id]
    if not aliases then
      return content.pokemon:get(id) ~= nil and id or nil
    end
    for _, alias in ipairs(aliases) do
      if content.pokemon:get(alias) ~= nil then return alias end
    end
    return nil
  end

  local function setRow(attacker, defender, multiplier)
    local id = attacker .. ">" .. defender
    if chart:get(id) ~= nil then
      chart:patch(id, { multiplier = multiplier })
    else
      chart:register(id, { multiplier = multiplier })
    end
  end

  local function ensureType(id, record)
    if chart:get(id) == nil then chart:register(id, record) end
  end

  local function registerAll()
    -- Types and their chart rows. Rows for a new type do nothing until a
    -- move or Pokemon has that type.
    ensureType("FAIRY", { name = "FAIRY", category = "special" })
    for _, r in ipairs(D.FAIRY_ROWS) do
      if chart:get(r[1]) ~= nil and chart:get(r[2]) ~= nil then
        setRow(r[1], r[2], r[3])
      end
    end
    if generation == 1 then
      ensureType("DARK", { name = "DARK", category = "special" })
      ensureType("STEEL", { name = "STEEL", category = "physical" })
      -- Struggle's type under OTHER GEN1 MOVE CHANGES: no chart rows, so
      -- it hits everything (Ghosts too) for normal damage.
      ensureType("TYPELESS", { name = "???", category = "physical" })
      for _, rows in ipairs({ D.DARK_ROWS, D.STEEL_ROWS }) do
        for _, r in ipairs(rows) do setRow(r[1], r[2], r[3]) end
      end
      -- Fairy against Dark/Steel, now that both exist.
      for _, r in ipairs(D.FAIRY_ROWS) do setRow(r[1], r[2], r[3]) end
      for _, r in ipairs(D.EFFECTIVENESS) do setRow(r[1], r[2], r.gen1) end
    end
    for _, r in ipairs(D.VS_STEEL) do setRow(r[1], r[2], r.gen2) end

    -- Effects. Gold runs Moonblast's and Metal Sound's effects itself
    -- (effects.lua adds their stat rows), but lists only effects a move
    -- already uses.
    if generation == 1 then
      for id, record in pairs(E.GEN1_EFFECTS) do
        if content.move_effects:get(id) == nil then
          content.move_effects:register(id, record)
        end
      end
    else
      for _, id in ipairs({ "EFFECT_SP_ATK_DOWN_HIT", "EFFECT_SP_DEF_DOWN_2" }) do
        if content.move_effects:get(id) == nil then
          content.move_effects:register(id, { kind = "full" })
        end
      end
      for id, record in pairs(E.GEN2_EFFECTS) do
        if content.move_effects:get(id) == nil then
          content.move_effects:register(id, record)
        end
      end
    end

    -- Moves.
    local function registerMove(id, spec, per)
      local record = {
        id = id, name = spec.name, type = spec.type, power = spec.power,
        accuracy = spec.accuracy, pp = spec.pp, effect = per.effect,
        priority = spec.priority,
        description = generation == 2 and (spec.text2 or spec.text) or spec.text,
      }
      local source = content.moves:get(per.animFrom)
      if generation == 2 then
        record.effectChance = per.effectChance or 0
        record.animation = source and source.animation or nil
      else
        record.anim = source and source.anim or nil
      end
      content.moves:register(id, record)
    end
    for _, row in ipairs(D.TMS) do
      local spec = D.MOVES[row.move]
      local per = generation == 2 and spec.gen2 or spec.gen1
      if tmInGame(row) and per and content.moves:get(row.move) == nil then
        registerMove(row.move, spec, per)
      end
    end

    -- TMs.
    for _, row in ipairs(D.TMS) do
      if tmInGame(row) then
        local id = "TM_" .. row.move
        local label = string.format("TM%02d", row.number)
        if content.items:get(id) == nil then
          if generation == 2 then
            content.items:register(id, {
              id = id, name = label, price = 3000,
              battleMenu = "ITEMMENU_NOUSE", canSelect = false, canToss = true,
              description = "?", fieldMenu = "ITEMMENU_PARTY",
              heldEffect = "HELD_NONE", heldParameter = 0,
              pocket = "TM_HM", pocketId = 4, propertyRaw = 64,
              teaches = row.move, tmLabel = label, tmNumber = row.number,
            })
          else
            content.items:register(id, {
              id = id, name = label, price = 3000,
              machine = { kind = "TM", move = row.move, number = row.number },
            })
          end
        end
      end
    end

    -- Red/Blue/Yellow: 1.72's Snatch move and TM stay known, hidden, so a
    -- save that has them loads intact; migrate() turns them into Taunt.
    if generation == 1 then
      for old, new in pairs(D.LEGACY_MOVES) do
        local spec = D.MOVES[new]
        if content.moves:get(old) == nil and spec and spec.gen1 then
          registerMove(old, spec, spec.gen1)
        end
      end
      for old, new in pairs(D.LEGACY_ITEMS) do
        local label
        for _, row in ipairs(D.TMS) do
          if "TM_" .. row.move == new then label = string.format("TM%02d", row.number) end
        end
        if content.items:get(old) == nil and label then
          content.items:register(old, { id = old, name = label, price = 0 })
        end
      end
    end

    -- Who can learn each TM (always, so a TM received keeps working).
    for _, row in ipairs(D.TMS) do
      if tmInGame(row) then
        local lists = D.LEARNERS[row.number]
        local ids = {}
        for _, id in ipairs(lists.gen1 or {}) do ids[#ids + 1] = id end
        if generation == 2 then
          for _, id in ipairs(lists.gen2 or {}) do ids[#ids + 1] = id end
        end
        for _, raw in ipairs(ids) do
          local id = speciesId(raw)
          local def = id and content.pokemon:get(id)
          if def then
            local list, has = {}, false
            for _, m in ipairs(def.tmhm or {}) do
              list[#list + 1] = m
              if m == row.move then has = true end
            end
            if not has then
              list[#list + 1] = row.move
              content.pokemon:patch(id, { tmhm = list })
            end
          end
        end
      end
    end
  end

  local okReg, errReg = pcall(registerAll)
  if not okReg then
    mod.log:warn("Extra Types: adding the new moves and TMs failed: %s", tostring(errReg))
  end

  -- Battle behaviour.
  pcall(function()
    if generation == 2 then E.installGen2(mod) else E.installGen1(mod) end
  end)
  -- Gold/Silver/Crystal number HM01-07 as 51-57, the same as our TM51-57,
  -- so the PACK's TM/HM pocket mixed them. HMs sort after every TM.
  if generation == 2 then
    pcall(function()
      local PackMenu = require("src.ui.gen2.PackMenu")
      if PackMenu.phHmLast then return end
      PackMenu.phHmLast = true
      local base = PackMenu.tmhmKey
      PackMenu.tmhmKey = function(self, itemId, ...)
        local key = base(self, itemId, ...)
        if type(key) == "number" and key < 1000
            and tostring(itemId):sub(1, 3) == "HM_" then
          return 500 + key
        end
        return key
      end
    end)
  end
  -- Red/Blue/Yellow: Taunt and Metronome get Gold's Metronome hand.
  if generation == 1 then
    pcall(function()
      local hand = mod:load("hand_anim.lua")(mod)
      hand.install()
      mod.exports.handAnim = hand
    end)
    -- Baby-Doll Eyes, Draining Kiss, Dazzling Gleam: their Gen 2 animations.
    pcall(function()
      local fairy = mod:load("fairy_anim.lua")(mod)
      fairy.install()
      mod.exports.fairyAnim = fairy
    end)
  end

  local nurses = mod:load("nurses.lua")(mod, D, state)

  ---------------------------------------------------------------------------
  -- Applied live (game start, save load, every settings change)
  ---------------------------------------------------------------------------
  local originalSpecies, originalMoves = {}, {}

  local function setSpeciesTypes(data, raw, target)
    local id = raw
    for _, alias in ipairs(D.ALIASES[raw] or { raw }) do
      if data.pokemon[alias] then id = alias break end
    end
    local def = data.pokemon[id]
    if not def then return end
    if originalSpecies[id] == nil then originalSpecies[id] = def.types end
    if not target then
      def.types = originalSpecies[id]
      return
    end
    local orig = originalSpecies[id] or {}
    if target[1] == target[2] and #orig == 1 then
      def.types = { target[1] }
    else
      def.types = { target[1], target[2] }
    end
  end

  local function setMoveType(data, id, typeId)
    local def = data.moves[id]
    if not def then return end
    if originalMoves[id] == nil then originalMoves[id] = def.type end
    def.type = typeId or originalMoves[id]
  end

  local function setLiveRow(data, attacker, defender, multiplier)
    local tc = data.type_chart
    if type(tc) ~= "table" or type(tc.matchups) ~= "table" then return end
    if not (tc.types and tc.types[attacker] and tc.types[defender]) then return end
    for _, m in ipairs(tc.matchups) do
      if m.attacker == attacker and m.defender == defender then
        m.multiplier = multiplier
        return
      end
    end
    tc.matchups[#tc.matchups + 1] = {
      attacker = attacker, defender = defender, multiplier = multiplier,
    }
  end

  local function aliasAnims(data)
    for _, row in ipairs(D.TMS) do
      local spec = D.MOVES[row.move]
      local per = generation == 2 and spec.gen2 or spec.gen1
      if per and tmInGame(row) then
        if generation == 2 then
          local anims = data.gen2BattleAnims and data.gen2BattleAnims.moves
          if type(anims) == "table" and anims[row.move] == nil then
            anims[row.move] = anims[per.animFrom]
          end
        else
          local anims = data.battle_anims and data.battle_anims.moveAnims
          if type(anims) == "table" and anims[row.move] == nil then
            anims[row.move] = anims[per.animFrom]
          end
        end
      end
    end
  end

  -- 1.74.0: Snatch -> Taunt in a save from 1.72/1.73 (Red/Blue/Yellow):
  -- the TM in the bag or the PC, and the move on every Pokemon.
  local function migrate(game)
    local save, data = game.save, game.data
    if generation ~= 1 or type(save) ~= "table" then return end
    local okBag, Bag = pcall(require, "src.inventory.Bag")
    for old, new in pairs(D.LEGACY_ITEMS) do
      if okBag and data.items and data.items[new] then
        local inBag = type(save.inventory) == "table" and tonumber(save.inventory[old]) or 0
        if inBag > 0 and Bag.add(save, new, inBag, data) ~= false then
          Bag.remove(save, old, inBag, data)
        end
        local inPc = type(save.pcItems) == "table" and tonumber(save.pcItems[old]) or 0
        if inPc > 0 and Bag.pcAdd(save, new, inPc, data) ~= false then
          Bag.pcRemove(save, old, inPc, data)
        end
      end
    end
    local function fixMon(mon)
      if type(mon) ~= "table" or type(mon.moves) ~= "table" then return end
      for i, slot in ipairs(mon.moves) do
        local id = type(slot) == "table" and slot.id or slot
        local new = D.LEGACY_MOVES[id]
        if new and data.moves[new] then
          if type(slot) == "table" then slot.id = new else mon.moves[i] = new end
        end
      end
    end
    for _, mon in ipairs(type(save.party) == "table" and save.party or {}) do fixMon(mon) end
    for _, box in ipairs(type(save.boxes) == "table" and save.boxes or {}) do
      for _, mon in ipairs(type(box) == "table" and box or {}) do fixMon(mon) end
    end
    if type(save.daycare) == "table" then fixMon(save.daycare.mon) end
  end

  local function apply(game)
    local data = game and game.data
    if type(data) ~= "table" or type(data.moves) ~= "table"
        or type(data.pokemon) ~= "table" then
      return
    end
    pcall(migrate, game)

    -- The new TM moves: their own type, or Normal while OFF.
    for _, row in ipairs(D.TMS) do
      if tmInGame(row) and data.moves[row.move] then
        local spec = D.MOVES[row.move]
        -- Gold's own Iron Tail, Steel Wing and Pursuit are never touched.
        local mine = generation == 1 or spec.gen2 ~= nil
        if mine then
          setMoveType(data, row.move,
            state.tmGroupOn(row.group) and spec.type or "NORMAL")
        end
      end
    end

    local fairyPkmn = on("fairy_pkmn")
    for id, target in pairs(D.FAIRY_PKMN) do
      setSpeciesTypes(data, id, fairyPkmn and target or nil)
    end

    if generation == 1 then
      local steelPkmn = on("steel_pkmn")
      for id, target in pairs(D.STEEL_PKMN) do
        setSpeciesTypes(data, id, steelPkmn and target or nil)
      end
      setMoveType(data, "BITE", on("dark_moves") and "DARK" or nil)
      local others = on("other_gen1_moves")
      for id, typeId in pairs(D.GEN1_OTHER_MOVES) do
        setMoveType(data, id, others and typeId or nil)
      end
      setMoveType(data, "STRUGGLE", others and "TYPELESS" or nil)
      local eff = choice("effectiveness", "gen1")
      for _, r in ipairs(D.EFFECTIVENESS) do
        setLiveRow(data, r[1], r[2], r[eff] or r.gen1)
      end
    else
      local fairyMoves = on("fairy_moves")
      for _, id in ipairs(D.GEN2_FAIRY_OLD_MOVES) do
        setMoveType(data, id, fairyMoves and "FAIRY" or nil)
      end
    end

    local vs = choice("vs_steel", "gen2")
    for _, r in ipairs(D.VS_STEEL) do
      setLiveRow(data, r[1], r[2], r[vs] or r.gen2)
    end

    -- Party Pokemon keep a copy of their typing in Gold.
    local party = game.save and game.save.party
    for _, mon in ipairs(type(party) == "table" and party or {}) do
      if type(mon) == "table" and mon.types ~= nil and mon.species then
        local def = data.pokemon[mon.species]
        if def and def.types then mon.types = def.types end
      end
    end

    aliasAnims(data)

    if generation == 1 then
      pcall(function() require("src.battle.TypeChart").load(data) end)
    end

    pcall(nurses.sync, game)
  end

  local liveGame
  local function applyLive(event)
    local game = type(event) == "table" and (event.game or event) or nil
    if type(game) ~= "table" or not game.data then
      game = liveGame
      if not game then
        local ok, Game = pcall(require, "src.core.Game")
        game = ok and Game or nil
      end
    end
    if type(game) ~= "table" then return end
    if game.data then liveGame = game end
    local ok, err = pcall(apply, game)
    if not ok then mod.log:warn("Extra Types: %s", tostring(err)) end
  end

  mod.events:always("game.ready", applyLive)
  mod.events:on("save.loaded", function() applyLive(nil) end)
  mod.events:on("map.entered", function()
    if liveGame then pcall(nurses.sync, liveGame) end
  end)
  mod.events:on("mod.options_changed", function() applyLive(nil) end)

  mod.exports.apply = function(game) applyLive(game) end
  mod.exports.nurses = nurses
  mod.exports.state = state
end
