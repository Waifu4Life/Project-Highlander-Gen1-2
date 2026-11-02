-- Highlander PC storage: one big box laid over the game's own boxes.
--
-- The save keeps its normal shape (Gen 1: 12 boxes of 20, Gen 2: 14 boxes
-- of 20), so turning the PC off, or exporting a cartridge save, still sees
-- ordinary boxes. This file only reads them as ONE list (box 1 first) and
-- writes that list back packed: box 1 full, then box 2, and so on, with
-- every empty slot at the very end.
--
-- Every change is planned on copies (the party and the big list), checked,
-- and only then written. If anything fails half-way, the old party and boxes
-- are put back, so a move either happens completely or not at all.
return function(mod, gen2)
  local Strings = require("src.core.Strings")
  local Boxes = gen2 and require("src.core.gen2.Boxes") or require("src.pokemon.Boxes")
  local Mail = gen2 and require("src.core.gen2.Mail") or nil

  local S = {}

  ---------------------------------------------------------------- sizes
  -- Read every time: a companion mod may change the box count or size.
  function S.counts()
    if gen2 then
      return tonumber(Boxes.NUM_BOXES) or 14, tonumber(Boxes.MONS_PER_BOX) or 20
    end
    return tonumber(Boxes.COUNT) or 12, tonumber(Boxes.CAPACITY) or 20
  end

  function S.capacity()
    local count, size = S.counts()
    return count * size
  end

  function S.partyMax()
    if gen2 then return tonumber(Boxes.PARTY_SIZE) or 6 end
    local ok, Party = pcall(require, "src.pokemon.Party")
    return ok and tonumber(Party.MAX) or 6
  end

  local function boxAt(save, index)
    if gen2 then return Boxes.box(save, index) end
    return Boxes.ensure(save)[index]
  end

  local function copy(list)
    local out = {}
    for i, v in ipairs(list or {}) do out[i] = v end
    return out
  end
  S.copy = copy

  ------------------------------------------------------------ big list
  -- Every boxed Pokémon in box order, gaps skipped.
  function S.flat(save)
    local out = {}
    local count = S.counts()
    for b = 1, count do
      local box = boxAt(save, b)
      if type(box) == "table" then
        for _, mon in ipairs(box) do out[#out + 1] = mon end
      end
    end
    return out
  end

  -- Packs the list back into the boxes. The box tables themselves are kept
  -- (the game may hold on to them); only their contents change. The game's
  -- current box becomes the first one with room, so a catch with a full
  -- party lands at the end of the big box.
  local function writeFlat(save, list)
    local count, size = S.counts()
    for b = 1, count do
      local box = boxAt(save, b)
      if type(box) == "table" then
        for i = #box, 1, -1 do box[i] = nil end
        for i = 1, size do
          local mon = list[(b - 1) * size + i]
          if mon == nil then break end
          box[i] = mon
        end
      end
    end
    local current = math.floor(#list / size) + 1
    save.currentBox = math.max(1, math.min(count, current))
  end

  -- Pack the boxes without changing the order (opening the PC).
  function S.compact(save)
    if not save then return end
    pcall(writeFlat, save, S.flat(save))
  end

  ------------------------------------------------------------ names
  function S.speciesName(game, mon)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return (def and def.name) or tostring(mon.species or "?")
  end

  function S.name(game, mon)
    if not mon then return "" end
    if mon.isEgg then return Strings("EGG") end
    local nick = mon.nickname
    if type(nick) == "string" and not nick:match("^%s*$") then return nick end
    return S.speciesName(game, mon)
  end

  ------------------------------------------------------------ rules
  local function healthy(mon, entering)
    if not mon or mon.isEgg then return false end
    if entering and gen2 then return (mon.maxHp or mon.hp or 1) > 0 end
    if mon.hp == nil then return true end
    return mon.hp > 0
  end

  local function sleepingPikachu(game, mon)
    if gen2 then return false end
    local ok, Follower = pcall(require, "src.world.PikachuFollower")
    if not ok or type(Follower) ~= "table" then return false end
    local okA, disabled = pcall(Follower.isFollowingDisabled, game.overworld)
    local okB, starter = pcall(Follower.isStarterPikachu, game.save, mon)
    return okA and okB and disabled and starter and true or false
  end

  local function set(list)
    local out = {}
    for _, mon in ipairs(list) do out[mon] = true end
    return out
  end

  -- Checks a planned party and big list. Returns nil when fine, or the
  -- message to show.
  local function check(game, save, party, flat)
    if #party < 1 then return Strings("You can't deposit\nthe last POKéMON!") end
    if #party > S.partyMax() then return Strings("The party is full!") end
    if #flat > S.capacity() then return Strings("The BOX is full!") end
    local before = set(save.party or {})
    local after = set(party)
    local changed = false
    for mon in pairs(before) do
      if not after[mon] then
        changed = true
        if Mail and Mail.monHoldsMail(mon) then
          return Strings("Remove MAIL first.")
        end
        if sleepingPikachu(game, mon) then
          return Strings("There isn't any\nresponse...")
        end
      end
    end
    for mon in pairs(after) do
      if not before[mon] then
        changed = true
        if Mail and Mail.monHoldsMail(mon) then
          return Strings("MAIL can't leave\nthe BOX.")
        end
      end
    end
    if changed then
      local ok = false
      for _, mon in ipairs(party) do
        if healthy(mon, not before[mon]) then ok = true break end
      end
      if not ok then return Strings("You can't deposit\nthe last POKéMON!") end
    end
    return nil
  end

  ------------------------------------------------------------ commit
  local function leaveParty(game, mon)
    if gen2 then
      pcall(Boxes.enterBox, mon, game.data)
    else
      local ok, Follower = pcall(require, "src.world.PikachuFollower")
      if ok and type(Follower.modifyHappiness) == "function" then
        pcall(Follower.modifyHappiness, game.save, "DEPOSITED", mon)
      end
    end
  end

  local function joinParty(game, mon)
    if gen2 then
      -- Boxes.withdraw's healing: status cleared, HP full (an egg stays 0).
      mon.status, mon.statusTurns = nil, nil
      if mon.isEgg then mon.hp = 0 else mon.hp = mon.maxHp or mon.hp end
    else
      S.ensureStats(game, mon)
    end
  end

  function S.ensureStats(game, mon)
    if gen2 or not mon then return end
    local ok, Stats = pcall(require, "src.pokemon.Stats")
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    if ok and def then pcall(Stats.ensure, def, mon) end
  end

  local function fill(target, list)
    for i = #target, 1, -1 do target[i] = nil end
    for i, v in ipairs(list) do target[i] = v end
  end

  -- Writes a planned party and big list to the save. Returns true, or
  -- false and the message to show (nothing changed in that case).
  function S.commit(game, save, party, flat)
    local why = check(game, save, party, flat)
    if why then return false, why end
    save.party = save.party or {}
    local oldParty, oldFlat = copy(save.party), S.flat(save)
    local oldBox = save.currentBox
    local letters, oldLetters
    if Mail then
      letters = Mail.state(save).party
      oldLetters = {}
      for i = 1, Mail.PARTY_LENGTH do oldLetters[i] = letters[i] end
    end
    local before, after = set(oldParty), set(party)
    local ok, err = pcall(function()
      local byMon = {}
      if letters then
        for i, mon in ipairs(oldParty) do byMon[mon] = oldLetters[i] end
      end
      for _, mon in ipairs(oldParty) do
        if not after[mon] then leaveParty(game, mon) end
      end
      for _, mon in ipairs(party) do
        if not before[mon] then joinParty(game, mon) end
      end
      fill(save.party, party)
      if letters then
        for i = 1, Mail.PARTY_LENGTH do letters[i] = byMon[save.party[i]] end
      end
      writeFlat(save, flat)
    end)
    if ok then return true end
    mod.log:error("PC change undone: %s", tostring(err))
    pcall(fill, save.party, oldParty)
    pcall(writeFlat, save, oldFlat)
    save.currentBox = oldBox
    if letters then
      for i = 1, Mail.PARTY_LENGTH do letters[i] = oldLetters[i] end
    end
    return false, Strings("Something went\nwrong. No change.")
  end

  ------------------------------------------------------------ moves
  -- side: "party" or "box"; index into the party or the big list.
  local function lists(save)
    return copy(save.party), S.flat(save)
  end

  local function pick(P, F, side) if side == "party" then return P end return F end

  local function indexOf(list, mon)
    for i, v in ipairs(list) do if v == mon then return i end end
  end

  -- Drop a held Pokémon on a slot: swap with the Pokémon there, or, on an
  -- empty slot, move it to the end of that side.
  function S.drop(game, save, fromSide, fromIndex, toSide, toIndex)
    local P, F = lists(save)
    local A, B = pick(P, F, fromSide), pick(P, F, toSide)
    local mon = A[fromIndex]
    if not mon then return false, Strings("That POKéMON\nmoved already.") end
    if fromSide == toSide and fromIndex == toIndex then return true end
    if B[toIndex] then
      A[fromIndex], B[toIndex] = B[toIndex], mon
    else
      table.remove(A, fromIndex)
      B[#B + 1] = mon
    end
    return S.commit(game, save, P, F)
  end

  -- START > SEND TO BOX / SEND TO PARTY: to the end of the other side.
  function S.send(game, save, fromSide, fromIndex)
    local P, F = lists(save)
    local A = pick(P, F, fromSide)
    local B = fromSide == "party" and F or P
    local mon = A[fromIndex]
    if not mon then return false end
    if B == P and #P >= S.partyMax() then return false, Strings("The party is full!") end
    if B == F and #F >= S.capacity() then return false, Strings("The BOX is full!") end
    table.remove(A, fromIndex)
    B[#B + 1] = mon
    local ok, why = S.commit(game, save, P, F)
    return ok, why, mon
  end

  -- Why a boxed Pokémon can't be released (nil when it can).
  function S.releaseRefusal(game, save, mon)
    if not mon then return Strings("That slot is empty.") end
    if mon.isEgg then return Strings("You can't release\nan EGG!") end
    if Mail and Mail.monHoldsMail(mon) then return Strings("Remove MAIL first.") end
    if not gen2 then
      local okV, GV = pcall(require, "src.core.GameVersion")
      local player = save.player or {}
      if okV and GV.isYellow and GV.isYellow() and mon.species == "PIKACHU"
          and mon.otId == player.id and mon.ot == player.name then
        return Strings("%s looks\nunhappy about it!", S.name(game, mon))
      end
    end
    return nil
  end

  function S.release(game, save, index, mon)
    local P, F = lists(save)
    if F[index] ~= mon then return false, Strings("That POKéMON\nmoved already.") end
    local why = S.releaseRefusal(game, save, mon)
    if why then return false, why end
    table.remove(F, index)
    return S.commit(game, save, P, F)
  end

  -- MULTIPLE SELECTIONS. marks = { mon, mon, ... } all from `side`, in the
  -- order they were marked; dropped (START) on `toSide` at `at`:
  --   * each takes the slot at, at+1, ..., swapping with whoever is there
  --     (the same side works too: the Pokémon trade places)
  --   * past the last Pokémon (an empty slot) they're added at the end
  function S.dropGroup(game, save, side, marks, toSide, at)
    local P, F = lists(save)
    local A, B = pick(P, F, side), pick(P, F, toSide)
    for _, mon in ipairs(marks) do
      if not indexOf(A, mon) then
        return false, Strings("That POKéMON\nmoved already.")
      end
    end
    local count = #B
    local appends = {}
    for k, mon in ipairs(marks) do
      local d = at + k - 1
      if d <= count then
        local other = B[d]
        if other ~= mon then
          A[indexOf(A, mon)] = other
          B[d] = mon
        end
      else
        appends[#appends + 1] = mon
      end
    end
    for _, mon in ipairs(appends) do
      table.remove(A, indexOf(A, mon))
      B[#B + 1] = mon
    end
    if B == P and #P > S.partyMax() then return false, Strings("Not enough room\nin the party!") end
    return S.commit(game, save, P, F)
  end

  ------------------------------------------------------------ catching
  -- Gen 2 checks the CURRENT box before a ball is thrown and refuses when
  -- it's full. Point it at the first box with room right before the throw,
  -- so catches keep filling the big box until all of it is full.
  -- (Gen 1's own catch already moves on to the next box with room.)
  function S.firstBoxWithRoom(save)
    local count, size = S.counts()
    for b = 1, count do
      local box = boxAt(save, b)
      if type(box) == "table" and #box < size then return b end
    end
  end

  function S.attachCatch()
    if not gen2 then return end
    mod.events:on("screen.pushed", function(event)
      local screen = type(event) == "table" and (event.state or event.screen) or nil
      if type(screen) ~= "table" or screen.highlanderPcCatch
          or (screen.screenId ~= "Gen2BattleState" and screen.screenId ~= "BattleState")
          or type(screen.useItem) ~= "function" then return end
      screen.highlanderPcCatch = true
      local useItem = screen.useItem
      screen.useItem = function(self, itemId, ...)
        local save, battle = self.save, self.battle
        local data = self.game and self.game.data
        local item = data and data.items and data.items[itemId]
        if save and battle and battle.wild and not battle.over
            and item and item.pocket == "BALL"
            and #(save.party or {}) >= S.partyMax() then
          local free = S.firstBoxWithRoom(save)
          if free then pcall(Boxes.setCurrent, save, free) end
        end
        return useItem(self, itemId, ...)
      end
    end)
  end

  return S
end
