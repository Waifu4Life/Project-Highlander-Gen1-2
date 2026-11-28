-- BOXES HEAL (1.83.0, replaces the 1.76.0 HEAL BOXED PKMN menu row).
-- Gen 1 now works like Gen 2: a Pokémon is healed (full HP, no status,
-- full PP) the moment it goes into a box. There is no PC menu row in either
-- game any more.
--   Gen 2: nothing to do -- the engine's own Boxes.enterBox already heals.
--   Gen 1, three ways in:
--     * BILL's PC DEPOSIT (vanilla BoxMenu) and the Highlander PC both call
--       PikachuFollower.modifyHappiness(save, "DEPOSITED", mon) for each
--       Pokémon leaving the party, so that call is the hook.
--     * Boxes.deposit, for a catch or gift that goes straight to a box
--       because the party is full.
--     * Opening the PC heals anything already sitting in a box hurt (boxed
--       before this change, or by an import), silently.
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local gen2 = GameVersion.generation and GameVersion.generation() == 2
  if gen2 then return end

  local function heal(mon)
    if type(mon) ~= "table" then return end
    local maxHp = type(mon.stats) == "table" and tonumber(mon.stats.hp)
      or tonumber(mon.maxHp)
    if maxHp then mon.hp = maxHp end
    mon.status = nil
    local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
    local okD, Data = pcall(require, "src.core.Data")
    local moves = okD and type(Data) == "table" and Data.moves or nil
    if okP and type(Pokemon) == "table" and type(Pokemon.maxPP) == "function"
        and moves and type(mon.moves) == "table" then
      for _, mv in ipairs(mon.moves) do
        local def = type(mv) == "table" and moves[mv.id]
        if def then mv.pp = Pokemon.maxPP(def.pp, mv.ppUps) end
      end
    end
  end

  local function healAllBoxes(save)
    if type(save) ~= "table" then return end
    local ok, Boxes = pcall(require, "src.pokemon.Boxes")
    if not ok then return end
    local okB, boxes = pcall(Boxes.ensure, save)
    for _, box in ipairs(okB and boxes or {}) do
      if type(box) == "table" then
        for _, mon in ipairs(box) do pcall(heal, mon) end
      end
    end
  end

  -- Deposits from either PC.
  pcall(function()
    local Follower = require("src.world.PikachuFollower")
    if type(Follower) ~= "table" or type(Follower.modifyHappiness) ~= "function"
        or Follower._phBoxHeal then
      return
    end
    Follower._phBoxHeal = true
    local orig = Follower.modifyHappiness
    Follower.modifyHappiness = function(save, event, mon, ...)
      if event == "DEPOSITED" then pcall(heal, mon) end
      return orig(save, event, mon, ...)
    end
  end)

  -- Catches and gifts that go straight to a box.
  pcall(function()
    local Boxes = require("src.pokemon.Boxes")
    if type(Boxes) ~= "table" or type(Boxes.deposit) ~= "function"
        or Boxes._phBoxHeal then
      return
    end
    Boxes._phBoxHeal = true
    local orig = Boxes.deposit
    Boxes.deposit = function(save, mon, ...)
      pcall(heal, mon)
      return orig(save, mon, ...)
    end
  end)

  -- Anything already hurt in a box gets healed when the PC opens.
  pcall(function()
    mod.hooks:wrap("ui.pc.items", function(nextFn, game, items)
      if game and game.save then pcall(healAllBoxes, game.save) end
      return nextFn(game, items)
    end)
  end)
end
