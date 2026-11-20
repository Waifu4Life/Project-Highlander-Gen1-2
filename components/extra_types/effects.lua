-- Extra Types: how the new moves behave in battle.
--
-- Red/Blue/Yellow: the new effects (Draining Kiss, the stat changes on hit,
-- Metal Sound, Taunt) and PURSUIT, which hits a Pokemon that is being
-- switched out, at double power.
-- Gold/Silver/Crystal: Baby-Doll Eyes goes first, Draining Kiss heals 3/4,
-- Moonblast may lower SPCL.ATK, and Taunt.
--
-- TAUNT (both games, like Ruby/Sapphire/Emerald): for 2 turns the target
-- can only use moves that deal damage. If the target has not moved yet
-- that turn, that turn counts as the first. It ends early when the target
-- leaves the battle; a second Taunt on it fails.
local E = {}

-- Power-0 moves that still deal damage (or count as attacks in Gen 3):
-- Taunt never blocks these.
local TAUNT_ALLOWED = {
  STRUGGLE = true, BIDE = true, COUNTER = true, MIRROR_COAT = true,
  SEISMIC_TOSS = true, NIGHT_SHADE = true, DRAGON_RAGE = true, SONICBOOM = true,
  SUPER_FANG = true, PSYWAVE = true, FISSURE = true, GUILLOTINE = true,
  HORN_DRILL = true, PRESENT = true, MAGNITUDE = true, FLAIL = true,
  REVERSAL = true, RETURN = true, FRUSTRATION = true, HIDDEN_POWER = true,
}
E.TAUNT_TURNS = 2

-- Is this a move a taunted Pokemon may not use?
function E.tauntBlocks(moves, moveId)
  if type(moveId) ~= "string" or TAUNT_ALLOWED[moveId] then return false end
  local def = type(moves) == "table" and moves[moveId]
  return type(def) == "table" and (tonumber(def.power) or 0) == 0
end

E.TEXT = {
  fell = "%s\nfell for the\nTAUNT!",
  cant = "%s\ncan't use\n%s after\nthe TAUNT!",
  menu = "It can't be used\nafter the TAUNT!",
}

local function romText(data, label, fallback, ...)
  local ok, RomText = pcall(require, "src.core.RomText")
  if ok and type(RomText) == "function" then
    local okText, text = pcall(RomText, data, label, fallback, ...)
    if okText and type(text) == "string" then return text end
  end
  return string.format(fallback, ...)
end

-- "CLEFABLE" / "Enemy CLEFABLE", the game's own way. The game changed how
-- it is called (0.4.6: displayName(data, battler); before: displayName(battler)),
-- so both are tried and a plain fallback is kept.
local function displayName(battler, data)
  if not battler then return "?" end
  local ok, Registry = pcall(require, "src.battle.EffectRegistry")
  if ok and type(Registry) == "table" and type(Registry.displayName) == "function" then
    local okNew, name = pcall(Registry.displayName, data, battler)
    if okNew and type(name) == "string" and name:find(tostring(battler.name), 1, true) then
      return name
    end
    local okOld, oldName = pcall(Registry.displayName, battler)
    if okOld and type(oldName) == "string" then return oldName end
  end
  return battler.isPlayer and tostring(battler.name) or ("Enemy " .. tostring(battler.name))
end

---------------------------------------------------------------------------
-- Red/Blue/Yellow effect records (registered before the moves that use them)
---------------------------------------------------------------------------

-- A chance out of 256 to change a stat after the hit lands. Silent when the
-- change does nothing (the stat is already at its limit), and a substitute
-- blocks a drop on the foe, like the game's own side effects.
local function statOnHit(chance, who, stat, delta)
  return {
    kind = "secondary",
    run = function(ctx)
      local mon = who == "foe" and ctx.target or ctx.user
      if who == "foe" and ctx.target.substituteHP then return {} end
      if ctx.rng(0, 255) >= chance then return {} end
      local msgs = ctx.changeStage(mon, stat, delta, false)
      if type(msgs) ~= "table" or msgs.failed then return {} end
      return msgs
    end,
  }
end

E.GEN1_EFFECTS = {
  -- Draining Kiss: heals 3/4 of the damage dealt.
  PH_DRAIN_3_4_EFFECT = {
    kind = "full",
    afterDamage = function(ctx)
      if ctx.brokeSub then return end
      local heal = math.max(1, math.floor((ctx.totalDealt or 0) * 3 / 4))
      ctx.battle.lastDamage = heal
      local mon = ctx.user.mon
      mon.hp = math.min(mon.stats.hp, mon.hp + heal)
      ctx.battle:drainNext(ctx.user, mon.hp)
      ctx.say(romText(ctx.battle.data, "_SuckedHealthText",
        "Sucked health from\n%s!", displayName(ctx.target, ctx.battle.data)))
    end,
  },
  -- 10% = 26/256, 30% = 77/256: the game's own odds for those chances.
  PH_ATTACK_DOWN_10_EFFECT = statOnHit(26, "foe", "attack", -1),
  PH_SPECIAL_DOWN_30_EFFECT = statOnHit(77, "foe", "special", -1),
  PH_DEFENSE_DOWN_30_EFFECT = statOnHit(77, "foe", "defense", -1),
  PH_DEFENSE_UP_10_EFFECT = statOnHit(26, "self", "defense", 1),
  -- Metal Sound: sharply lowers the foe's SPECIAL. Rolls accuracy.
  PH_SPECIAL_DOWN_2_EFFECT = {
    kind = "primary", accuracyChecked = true, missText = "butItFailed",
    run = function(ctx)
      return ctx.changeStage(ctx.target, "special", -2, true)
    end,
  },
  -- Taunt: rolls accuracy; fails on a Pokemon already taunted.
  PH_TAUNT_EFFECT = {
    kind = "primary", accuracyChecked = true,
    run = function(ctx)
      local target = ctx.target
      if target.phTaunt then
        return { romText(ctx.battle.data, "_ButItFailedText", "But it failed!"), failed = true }
      end
      target.phTaunt = E.TAUNT_TURNS
      return { string.format(E.TEXT.fell, displayName(target, ctx.battle.data)) }
    end,
  },
}

local function knowsMove(battler, moveId)
  for _, mv in ipairs(battler and battler.curMoves or {}) do
    if mv.id == moveId then return true end
  end
  return false
end

function E.installGen1(mod)
  local ok, BattleState = pcall(require, "src.battle.BattleState")
  if not ok or type(BattleState) ~= "table" then
    mod.log:warn("Extra Types: no Gen 1 battle module; Pursuit and Taunt keep their plain effect")
    return
  end
  if BattleState._phExtraTypes then return end
  BattleState._phExtraTypes = true

  local function moveName(data, id)
    local def = data and data.moves and data.moves[id]
    return def and def.name or tostring(id)
  end

  -- TAUNT: a taunted Pokemon's status move fails when its turn comes
  -- (the foe's AI, or a move picked before the Taunt landed).
  local origPerform = BattleState.performMove
  BattleState.performMove = function(self, user, target, moveInst, isCalled)
    if user and user.phTaunt and not isCalled and type(moveInst) == "table"
        and E.tauntBlocks(self.data and self.data.moves, moveInst.id) then
      self:sayNext(string.format(E.TEXT.cant, displayName(user, self.data),
        moveName(self.data, moveInst.id)))
      return
    end
    return origPerform(self, user, target, moveInst, isCalled)
  end

  -- Taunt counts down at the end of each turn.
  local origEnd = BattleState.endOfTurn
  BattleState.endOfTurn = function(self, ...)
    for _, b in ipairs({ self.player or false, self.enemy or false }) do
      if b and b.phTaunt then
        b.phTaunt = b.phTaunt - 1
        if b.phTaunt <= 0 then b.phTaunt = nil end
      end
    end
    return origEnd(self, ...)
  end

  -- The move list refuses a status move while taunted...
  local origChoose = BattleState.chooseMove
  if type(origChoose) == "function" then
    BattleState.chooseMove = function(self, index, ...)
      local move = self.phase == "moveSelect" and self.player and self.player.curMoves
        and self.player.curMoves[index]
      if move and self.player.phTaunt and self.player.disabledSlot ~= index
          and (move.pp or 0) > 0 and E.tauntBlocks(self.data and self.data.moves, move.id) then
        self.moveIndex = index
        self:say(E.TEXT.menu)
        self.phase = "messages"
        self.afterQueue = "moveSelect"
        return true
      end
      return origChoose(self, index, ...)
    end
  end

  -- ...and with only status moves left it goes straight to Struggle.
  local origHasPP = BattleState.playerHasPP
  if type(origHasPP) == "function" then
    BattleState.playerHasPP = function(self, ...)
      local p = self.player
      if not (p and p.phTaunt) then return origHasPP(self, ...) end
      for i, mv in ipairs(p.curMoves or {}) do
        if (mv.pp or 0) > 0 and p.disabledSlot ~= i
            and not E.tauntBlocks(self.data and self.data.moves, mv.id) then
          return true
        end
      end
      return false
    end
  end

  -- The foe's AI picks among its attacks while taunted.
  local okAI, TrainerAI = pcall(require, "src.battle.TrainerAI")
  if okAI and type(TrainerAI) == "table" and type(TrainerAI.chooseMove) == "function" then
    local origAI = TrainerAI.chooseMove
    TrainerAI.chooseMove = function(battler, rng, battle, ...)
      local pick = origAI(battler, rng, battle, ...)
      local moves = battle and battle.data and battle.data.moves
      if not (battler and battler.phTaunt and type(pick) == "table"
          and E.tauntBlocks(moves, pick.id)) then
        return pick
      end
      local unlimited = battle.ruleset and battle.ruleset.enemyUnlimitedPP
      local ok = {}
      for i, mv in ipairs(battler.curMoves or {}) do
        if battler.disabledSlot ~= i and (unlimited or (mv.pp or 0) > 0)
            and not E.tauntBlocks(moves, mv.id) then
          ok[#ok + 1] = mv
        end
      end
      if #ok == 0 then return { id = "STRUGGLE", pp = 1, struggle = true } end
      rng = rng or love.math.random
      return ok[rng(1, #ok)]
    end
  end

  -- PURSUIT: when the player switches and the foe picked Pursuit, it hits
  -- the outgoing Pokemon first, at double power. Any other foe move is the
  -- one it picked here (no second pick).
  local origSwitch = BattleState.resolveSwitch
  BattleState.resolveSwitch = function(self, newMon)
    if self.kind == "link" or self.ghost or not knowsMove(self.enemy, "PURSUIT") then
      return origSwitch(self, newMon)
    end
    local action = self:enemyAction()
    local forced = self.enemyActionForced
    if not (type(action) == "table" and action.id == "PURSUIT") then
      self.enemyAction = function(s)
        s.enemyAction = nil
        s.enemyActionForced = forced
        return action
      end
      return origSwitch(self, newMon)
    end

    self.phase = "messages"
    self.afterQueue = "menu"
    local outgoing = self.player
    self:act(function()
      local def = self.data.moves.PURSUIT
      local base = def and def.power
      if base then def.power = base * 2 end
      self.enemyActionForced = true
      local okHit, err = pcall(self.executeAction, self, self.enemy, outgoing, action)
      if base then def.power = base end
      self.enemyActionForced = nil
      if not okHit then error(err, 0) end
    end)
    self:act(function()
      if self.result or self.player ~= outgoing
          or not outgoing.mon or outgoing.mon.hp <= 0 then
        self:endOfTurn()
        return
      end
      -- The foe already moved: the switch gives it no second move.
      self.enemyAction = function(s)
        s.enemyAction = nil
        s.enemyActionForced = true
        return nil
      end
      origSwitch(self, newMon)
    end)
  end
end

---------------------------------------------------------------------------
-- Gold/Silver/Crystal
---------------------------------------------------------------------------
E.GEN2_PRIORITY = { BABY_DOLL_EYES = 1 }

-- Gold's own effect records take (battle, attacker, defender, def, moveId,
-- sureHit); Taunt rolls its own accuracy.
E.GEN2_EFFECTS = {
  EFFECT_PH_TAUNT = {
    kind = "primary",
    run = function(self, attacker, defender, def, moveId, sureHit)
      if not sureHit and not self:accuracyRoll(def, attacker, defender) then
        self:markMissed()
        self:moveText("AttackMissedText", attacker, defender)
        return
      end
      local state = self:volatile(defender)
      if state.phTaunt then
        return self:failText(attacker, defender, "ButItFailedText", "ItFailedText")
      end
      state.phTaunt = E.TAUNT_TURNS
      self:emit({ kind = "message",
        text = string.format(E.TEXT.fell, self:battlerName(defender)) })
    end,
  },
}

function E.installGen2(mod)
  local okB, Battle = pcall(require, "src.battle.gen2.Battle")
  local okE, Effects = pcall(require, "src.battle.gen2.Effects")
  if not okB or not okE or type(Battle) ~= "table" or type(Effects) ~= "table" then
    mod.log:warn("Extra Types: no Gen 2 battle module")
    return
  end
  if Battle._phExtraTypes then return end
  Battle._phExtraTypes = true

  -- Moonblast and Metal Sound: the game knows both effects (no Gold move
  -- uses them) but has no stat-change row for them.
  Effects.STAT_CHANGES_ON_HIT = Effects.STAT_CHANGES_ON_HIT or {}
  if not Effects.STAT_CHANGES_ON_HIT.EFFECT_SP_ATK_DOWN_HIT then
    Effects.STAT_CHANGES_ON_HIT.EFFECT_SP_ATK_DOWN_HIT = { "specialAttack", -1, "foe" }
  end
  Effects.STAT_CHANGES = Effects.STAT_CHANGES or {}
  if not Effects.STAT_CHANGES.EFFECT_SP_DEF_DOWN_2 then
    Effects.STAT_CHANGES.EFFECT_SP_DEF_DOWN_2 = { "specialDefense", -2, "foe" }
  end

  -- Baby-Doll Eyes goes first (Quick Attack's priority).
  local origPriority = Battle.movePriority
  Battle.movePriority = function(self, moveId, ...)
    local p = E.GEN2_PRIORITY[moveId]
    if p then return p end
    return origPriority(self, moveId, ...)
  end

  -- Draining Kiss heals 3/4 of the damage instead of 1/2.
  local kissing = false
  local function finish(was, ok, ...)
    kissing = was
    if not ok then error((...), 0) end
    return ...
  end
  local origUse = Battle.useMove
  Battle.useMove = function(self, attacker, defender, moveId, ...)
    -- TAUNT: a taunted Pokemon's status move fails (not when called by
    -- Metronome, Mirror Move or Sleep Talk).
    if attacker and (self.copyDepth or 0) == 0 and self:volatile(attacker).phTaunt
        and E.tauntBlocks(self.data and self.data.moves, moveId) then
      local def = self:moveDef(moveId)
      self:emit({ kind = "message", text = string.format(E.TEXT.cant,
        self:battlerName(attacker), def and def.name or tostring(moveId)) })
      return
    end
    local was = kissing
    kissing = moveId == "DRAINING_KISS"
    return finish(was, pcall(origUse, self, attacker, defender, moveId, ...))
  end

  -- Taunted: status moves count as disabled (greyed out in the move list,
  -- skipped by the foe's AI, Struggle when nothing else is left).
  local origDisabled = Battle.moveDisabled
  Battle.moveDisabled = function(self, mon, moveId, ...)
    if origDisabled(self, mon, moveId, ...) then return true end
    return mon ~= nil and self:volatile(mon).phTaunt ~= nil
      and E.tauntBlocks(self.data and self.data.moves, moveId)
  end

  -- Taunt counts down at the end of each turn.
  local origCounters = Battle.tickCounters
  Battle.tickCounters = function(self, mon, ...)
    local state = mon and self:volatile(mon)
    if state and state.phTaunt then
      state.phTaunt = state.phTaunt - 1
      if state.phTaunt <= 0 then state.phTaunt = nil end
    end
    return origCounters(self, mon, ...)
  end

  -- The move list says why instead of "The move is disabled!".
  local okUi, Screen = pcall(require, "src.ui.gen2.BattleState")
  if okUi and type(Screen) == "table" and type(Screen.chooseMove) == "function" then
    local origChoose = Screen.chooseMove
    Screen.chooseMove = function(self, index, ...)
      local battle = self.battle
      local moves = self.phase == "moves" and type(self.playerMoves) == "function"
        and self:playerMoves()
      local move = moves and moves[index]
      if move and battle and battle.player and (move.pp or 0) > 0
          and battle:volatile(battle.player).phTaunt
          and E.tauntBlocks(battle.data and battle.data.moves, move.id) then
        local ok, res = pcall(origChoose, self, index, ...)
        if ok and self.phase == "refuse-move" then self.message = E.TEXT.menu end
        if not ok then error(res, 0) end
        return res
      end
      return origChoose(self, index, ...)
    end
  end
  local origDrain = Effects.drainAmount
  Effects.drainAmount = function(dealt, ...)
    if kissing then
      return math.max(1, math.floor((dealt or 0) * 3 / 4))
    end
    return origDrain(dealt, ...)
  end
end

return E
