-- PokeMoves, Gen 2 (Gold/Silver/Crystal) side. main.lua loads this only in
-- Gen 2 games.
--
--   FORGETTABLE HMS   an HM move can be picked when a Pokemon forgets a move
--                     to learn a new one, in and out of battle
--   TMS FOREVER       using a TM doesn't use it up
--   INSTANT TMS/HMS   no "Want to use CUT?" style questions, and SELECT lists
--                     the usable field moves
--   NO LEARN HMS      field moves work for a Pokemon that could learn the HM
--                     (main.lua's firstLearner decides who)
return function(mod)
  local function on(key) return mod.options:enabled() and mod.options:get(key)==true end
  local Game2=require("src.core.Game2")
  local Screens=require("src.ui.Screens")
  local unpackAll = table.unpack or unpack
  local function pack(...) return { n = select("#", ...), ... } end

  -- The seven Gen 2 HMs; the game refuses to let these be forgotten.
  local HM = {
    CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
    WATERFALL = true, WHIRLPOOL = true,
  }

  ---------------------------------------------------------------------------
  -- FORGETTABLE HMS
  ---------------------------------------------------------------------------
  -- The game's own "forget a move" code stays in charge (questions, list,
  -- "1, 2 and... Poof!", sounds). For the one moment it checks the chosen
  -- move, an HM in that slot wears a stand-in id the HM check doesn't know.
  -- The stand-in points at the same move data, so every message still shows
  -- the real move name. If the move wasn't replaced, the HM is put back.
  local function asStandIn(moveId) return tostring(moveId) .. "@highlander" end

  local function withHmUnlocked(mon, slot, moveTables, run)
    local moves = type(mon) == "table" and mon.moves
    local real = type(moves) == "table" and moves[slot]
    if not (on("forgettable_hms") and type(real) == "table" and HM[real.id]) then
      return run()
    end
    local standInId = asStandIn(real.id)
    local added = {}
    for _, list in ipairs(moveTables) do
      if type(list) == "table" and list[standInId] == nil then
        list[standInId] = list[real.id]
        added[#added + 1] = list
      end
    end
    local standIn = {}
    for k, v in pairs(real) do standIn[k] = v end
    standIn.id = standInId
    moves[slot] = standIn
    local ok, err = pcall(run)
    if moves[slot] == standIn then moves[slot] = real end
    for _, list in ipairs(added) do list[standInId] = nil end
    if not ok then error(err, 0) end
  end

  local told = false
  local function noteUnlocked(moveId)
    if told then return end
    told = true
    pcall(function() mod.log:info("Forgettable HMs: %s can be forgotten", tostring(moveId)) end)
  end

  -- Out of battle: level-ups from Rare Candy, TMs/HMs, the Move Tutor...
  -- all show the game's "forget" move list (layout "forget"). Its A press
  -- calls opts.onChoose(slot); that call runs with the HM unlocked.
  local function unlockList(game, opts)
    if type(opts) ~= "table" or opts.layout ~= "forget" or opts._phForgetHm
        or type(opts.onChoose) ~= "function" then
      return
    end
    opts._phForgetHm = true
    local choose = opts.onChoose
    opts.onChoose = function(slot, ...)
      local extra = pack(...)
      local data = game and game.data
      local mon = opts.mon
      local real = type(mon) == "table" and type(mon.moves) == "table" and mon.moves[slot]
      if type(real) == "table" and HM[real.id] and on("forgettable_hms") then noteUnlocked(real.id) end
      withHmUnlocked(mon, slot, { opts.moves, data and data.moves },
        function() choose(slot, unpackAll(extra, 1, extra.n)) end)
    end
  end

  -- The hooks below are put in once per game session; each new install
  -- (every game.ready) swaps in its own handler, so the newest settings and
  -- code are always the ones used.
  Screens._phUnlockForgetList = unlockList
  pcall(function()
    if Screens._phForgetPushWrapped == true then return end
    Screens._phForgetPushWrapped = true
    local push = Screens.push
    Screens.push = function(game, id, opts, ...)
      local handler = Screens._phUnlockForgetList
      if id == "Gen2MoveDeleter" and type(handler) == "function" then
        pcall(handler, game, opts)
      end
      return push(game, id, opts, ...)
    end
  end)
  -- Second way in, for when the list is built without Screens.push.
  pcall(function()
    local MoveDeleter = require("src.ui.gen2.MoveDeleter")
    if MoveDeleter._phForgetNewWrapped == true then return end
    MoveDeleter._phForgetNewWrapped = true
    local new = MoveDeleter.new
    MoveDeleter.new = function(game, opts, ...)
      local handler = Screens._phUnlockForgetList
      if type(handler) == "function" then pcall(handler, game, opts) end
      return new(game, opts, ...)
    end
  end)

  -- In battle: the move list after "Delete an older move?" (phase
  -- "choose-forget"); A on an HM goes through like any other move.
  local function battleUpdate(original, self, ...)
    local input = self.game and self.game.input
    local choosing = self.phase == "choose-forget" and (self.messageTimer or 0) <= 0
      and input and input:wasPressed("a")
    local learn = choosing and self.pendingLearn
    local battle = self.battle
    local mon = learn and battle and battle.party and battle.party[learn.index]
    if not mon then return original(self, ...) end
    local real = type(mon.moves) == "table" and mon.moves[self.forgetIndex]
    if type(real) == "table" and HM[real.id] and on("forgettable_hms") then noteUnlocked(real.id) end
    local args = pack(...)
    local data = battle.data
    local gameData = self.game and self.game.data
    local result = pack()
    withHmUnlocked(mon, self.forgetIndex, { data and data.moves, gameData and gameData.moves },
      function() result = pack(original(self, unpackAll(args, 1, args.n))) end)
    return unpackAll(result, 1, result.n)
  end

  pcall(function()
    local BattleState = require("src.ui.gen2.BattleState")
    BattleState._phForgetUpdate = battleUpdate
    if BattleState._phForgetUpdateWrapped == true then return end
    BattleState._phForgetUpdateWrapped = true
    local update = BattleState.update
    BattleState.update = function(self, ...)
      local handler = BattleState._phForgetUpdate
      if type(handler) ~= "function" or type(self) ~= "table" then return update(self, ...) end
      return handler(update, self, ...)
    end
  end)

  ---------------------------------------------------------------------------
  -- TMS FOREVER
  ---------------------------------------------------------------------------
  Game2._phTmsForeverOn = function() return on("tms_forever") end
  if type(Game2.consumeItem) == "function" and Game2._phTmsForeverWrapped ~= true then
    Game2._phTmsForeverWrapped = true
    local consumeItem = Game2.consumeItem
    Game2.consumeItem = function(self, itemId, ...)
      local isTm = type(itemId) == "string" and itemId:sub(1, 3) == "TM_"
      local forever = Game2._phTmsForeverOn
      if isTm and type(forever) == "function" and forever() then return true end
      return consumeItem(self, itemId, ...)
    end
  end

  ---------------------------------------------------------------------------
  -- INSTANT TMS/HMS
  ---------------------------------------------------------------------------
  -- Field-move questions ("...used CUT!", "Want to SURF?"...) are answered
  -- YES at once. ROCK SMASH is handled further down.
  pcall(function()
    if Game2._phSkipHmSay or type(Game2.say)~="function" then return end
    Game2._phSkipHmSay=true
    local say=Game2.say
    local flavor={CUT=true,SURF=true,STRENGTH=true,FLASH=true,FLY=true,
      WHIRLPOOL=true,WATERFALL=true,DIG=true,TELEPORT=true,
      HEADBUTT=true,["ROCK SMASH"]=true,ROCK_SMASH=true,["SWEET SCENT"]=true}
    -- Word-boundary match (not plain substring): a real total engine hang
    -- was traced to this exact function. "CUT" via plain find(...,1,true)
    -- matches inside ordinary words like "CUTE" -- e.g. a generic "Wow,
    -- that's a cute Pokemon." story line -- which made this treat an
    -- unrelated message as an HM flavor-text prompt and skip actually
    -- displaying it, faking completion instead (see Game2:say below). That
    -- desync between what the engine expected and what actually happened
    -- is consistent with a silent total hang: nothing ever threw, so there
    -- was nothing to catch or log.
    local FLAVOR_WORDS = {
      "HEADBUTT", "ROCK SMASH", "ROCKSMASH", "CUT", "SURF", "STRENGTH",
      "FLASH", "WHIRLPOOL", "WATERFALL", "SWEET SCENT",
    }
    local function isFlavor(text)
      local s=tostring(text or ""):upper()
      if type(text)=="table" then
        local parts={}
        for _,row in ipairs(text) do parts[#parts+1]=tostring(row) end
        s=table.concat(parts," "):upper()
      end
      s=s:gsub("[\nvrft]"," ")
      for _, word in ipairs(FLAVOR_WORDS) do
        if s:find("%f[%a]" .. word:gsub(" ", "%%s") .. "%f[%A]") then
          return true
        end
      end
      return false
    end
    function Game2:say(text,onDone,opts)
      local s=tostring(text or ""):upper()
      local rock=s:find("ROCK SMASH",1,true) or s:find("ROCKSMASH",1,true)
      if on("instant_tmhm") and isFlavor(text) and not rock then
        local choice=type(opts)=="table" and opts.choice
        if type(choice)=="function" then pcall(choice,true) end
        if type(onDone)=="function" then pcall(onDone) end
        return self
      end
      return say(self,text,onDone,opts)
    end
  end)
  -- INSTANT TMS/HMS, SELECT: a list of the field moves the party can use
  -- here (FLASH, FLY, DIG, TELEPORT, SWEET SCENT) instead of the registered
  -- item; with nothing usable, SELECT does what it normally does.
  local nativeSelect = Game2.useSelectItem
  if type(nativeSelect) == "function" then Game2.useSelectItem=function(self,...)
    local world = self.world
    local idle = world and not world:busy() and not world.battleActive
    if not (on("instant_tmhm") and idle) then return nativeSelect(self,...) end
    local F=require("src.world.gen2.FieldMoves")
    local items={}
    local labels={
      SWEET_SCENT="SWEET SCENT", SWEETSCENT="SWEET SCENT",
      ROCK_SMASH="ROCK SMASH", ROCKSMASH="ROCK SMASH",
    }
    local function addMove(move)
      local mon=F.partyMoveUser(self.save.party,move,world:fieldContext())
      if not mon then return end
      items[#items+1]={label=labels[move] or move,onSelect=function()
        world:useFieldMove(move,mon)
      end}
    end
    for _,move in ipairs({
      "FLASH","FLY","DIG","TELEPORT",
      "SWEET_SCENT","SWEETSCENT",
    }) do
      addMove(move)
    end
    -- Drop duplicate labels if both SWEET_SCENT and SWEETSCENT resolved.
    local seen={}
    local uniq={}
    for _,row in ipairs(items) do
      if not seen[row.label] then
        seen[row.label]=true
        uniq[#uniq+1]=row
      end
    end
    items=uniq
    if #items==0 then return nativeSelect(self,...) end
    if mod.highlander and type(mod.highlander.openShortcutMenu)=="function"
        and mod.highlander.openShortcutMenu(self,items) then return end
    items[#items+1]={label="CANCEL"}
    local widest=6
    for _,row in ipairs(items) do
      widest=math.max(widest,#tostring(row.label or ""))
    end
    self.stack:push(require("src.ui.Menu").new(self,items,{
      tx=6, ty=1, tw=widest+2, th=#items*2+2,
    }))
  end end

  ---------------------------------------------------------------------------
  -- NO LEARN HMS, and INSTANT TMS/HMS for ROCK SMASH
  ---------------------------------------------------------------------------
  pcall(function()
    local F=require("src.world.gen2.FieldMoves")
    if type(F)~="table" or type(F.partyMoveUser)~="function" or F._phNoLearnField then return end
    F._phNoLearnField=true
    local orig=F.partyMoveUser
    function F.partyMoveUser(party,move,ctx)
      local mon=orig(party,move,ctx)
      if mon then return mon end
      if not on("no_learn_hms") then return nil end
      local game=require("src.core.Game")
      if type(mod.exports.firstLearner)=="function" then
        return mod.exports.firstLearner(game.data, game.save, move)
      end
      return nil
    end
  end)

  pcall(function()
    if Game2._phSmashSkip then return end
    Game2._phSmashSkip=true
    local function boxText(top)
      if type(top)~="table" then return "" end
      for _,k in ipairs({"text","str","message","msg","src","raw","body","label"}) do
        local v=top[k]
        if type(v)=="string" and v~="" then return v end
        if type(v)=="table" then
          local parts={}
          for _,row in ipairs(v) do parts[#parts+1]=tostring(row) end
          if #parts>0 then return table.concat(parts," ") end
        end
      end
      return ""
    end
    local function isSmash(top)
      local s=boxText(top):upper()
      return s:find("ROCK SMASH",1,true) or s:find("ROCKSMASH",1,true)
        or (s:find("SMASH",1,true) and (s:find("ROCK",1,true) or s:find("WANT",1,true) or s:find("USE",1,true)))
    end
    local function runCont(top)
      if type(top)~="table" then return end
      local choice=(type(top.opts)=="table" and top.opts.choice) or top.choice
      if type(choice)=="function" then pcall(choice,true) return end
      if type(top.onDone)=="function" then pcall(top.onDone) end
    end
    local function skipSmash(game)
      if not on("instant_tmhm") or not game or not game.stack or not game.stack.top then return end
      local n=0
      while n<4 do
        local top=game.stack:top()
        if type(top)~="table" or not isSmash(top) then break end
        n=n+1
        pcall(game.stack.pop, game.stack)
        runCont(top)
      end
    end
    pcall(function()
      mod.hooks:wrap("core.update", function(nextFn, game, dt)
        local r=nextFn(game, dt)
        skipSmash(game)
        return r
      end)
    end)
  end)

end
