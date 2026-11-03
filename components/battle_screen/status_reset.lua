-- Battle Screen > STATUS C. RESET (Off by default).
-- Like Pokemon Legends: Arceus: when a battle ends, every Pokemon in your
-- party loses its status condition (PSN, BRN, PAR, SLP, FRZ). HP and
-- fainted Pokemon are left as they are.
-- Runs on battle.ended, after the game has put the battle back into the
-- party (Gen 1: the party IS the save's; Gen 2: Battle.party IS save.party).
-- Link battles and the old man / PROF.OAK demo keep the normal rules.
return function(mod)
  local function on()
    local ok, v = pcall(mod.options.get, mod.options, "status_reset")
    return ok and v == true
  end

  local function clear(mon)
    if type(mon) ~= "table" then return end
    mon.status = nil
    mon.sleepTurns = nil   -- Gen 1 sleep counter
    mon.statusTurns = nil  -- Gen 2 sleep counter
    mon.cartStatus = nil   -- Gen 2 raw status byte from the cartridge save
  end

  local function clearParty(party)
    if type(party) ~= "table" then return end
    for _, mon in ipairs(party) do clear(mon) end
  end

  -- The battle the event is about, and the party it used.
  local function partyOf(battle)
    if type(battle) ~= "table" then return nil end
    -- Gen 2 screen (ui/gen2/BattleState) carries the engine in .battle
    local engine = type(battle.battle) == "table" and battle.battle or nil
    for _, b in ipairs({ battle, engine }) do
      if type(b) == "table" then
        if b.linkBattle or b.kind == "link" or b.demo then return nil end
      end
    end
    if engine and type(engine.party) == "table" then return engine.party end
    if type(battle.party) == "table" and battle.save then return battle.party end
    local game = battle.game
    local save = (type(game) == "table" and game.save) or battle.save
    return type(save) == "table" and save.party or nil
  end

  mod.events:on("battle.ended", function(event)
    if not on() or type(event) ~= "table" then return end
    pcall(clearParty, partyOf(event.battle))
  end)
end
