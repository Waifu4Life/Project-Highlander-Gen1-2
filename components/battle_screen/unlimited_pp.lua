-- Battle Screen > UNLIMITED PP (Off by default: borderline cheating).
-- Your active Pokemon's moves never lose PP. The PP each move had before it
-- runs is put back afterwards, so normal use (and Gen 2's Spite on you)
-- can't lower it; PP that goes up (Leppa/Mystery Berry) is kept.
-- Link battles keep the normal rules so both games stay in step.
return function(mod)
  local function on()
    local ok, v = pcall(mod.options.get, mod.options, "unlimited_pp")
    return ok and v == true
  end

  local function pack(...) return { n = select("#", ...), ... } end
  local function unpackN(t, i) return (table.unpack or unpack)(t, i, t.n) end

  -- { entry, pp } for every move table in list
  local function snapshot(list, out)
    if type(list) ~= "table" then return out end
    for _, m in pairs(list) do
      if type(m) == "table" and tonumber(m.pp) then out[#out + 1] = { m, tonumber(m.pp) } end
    end
    return out
  end

  local function restore(saved)
    for _, s in ipairs(saved) do
      local now = tonumber(s[1].pp)
      if now and now < s[2] then s[1].pp = s[2] end
    end
  end

  local function guarded(saved, fn, ...)
    local res = pack(pcall(fn, ...))
    restore(saved)
    if not res[1] then error(res[2], 0) end
    return unpackN(res, 2)
  end

  local GameVersion = require("src.core.GameVersion")
  local generation = type(GameVersion.generation) == "function" and GameVersion.generation() or 1

  if generation == 2 then
    -- Gen 2 works on the party mon itself (Battle:useMove spends the PP)
    local Battle = require("src.battle.gen2.Battle")
    if type(Battle) ~= "table" or type(Battle.useMove) ~= "function" or Battle._phUnlimitedPP then return end
    Battle._phUnlimitedPP = true
    local orig = Battle.useMove
    Battle.useMove = function(self, ...)
      local mon = type(self) == "table" and self.player or nil
      if not on() or self.linkBattle or type(mon) ~= "table" then return orig(self, ...) end
      return guarded(snapshot(mon.moves, {}), orig, self, ...)
    end
  else
    -- Gen 1: BattleState:performMove spends the PP of the move used
    local BattleState = require("src.battle.BattleState")
    if type(BattleState) ~= "table" or type(BattleState.performMove) ~= "function"
        or BattleState._phUnlimitedPP then return end
    BattleState._phUnlimitedPP = true
    local orig = BattleState.performMove
    BattleState.performMove = function(self, user, ...)
      if not on() or type(self) ~= "table" or self.kind == "link" or type(user) ~= "table"
          or not user.isPlayer then
        return orig(self, user, ...)
      end
      local saved = snapshot(user.curMoves, {})
      if type(user.mon) == "table" then snapshot(user.mon.moves, saved) end
      return guarded(saved, orig, self, user, ...)
    end
  end
end
