-- Other Settings: LEARN TMS FASTER and FAST PKMN CENTER (Gen 1 and Gen 2).
--
-- LEARN TMS FASTER: no "Booted up a TM!" prompt, no "is trying to learn /
-- delete an older move?" questions and no "1, 2 and... Poof!" lines. With
-- four moves the forget list comes up straight away (B gives up quietly),
-- and only "<PKMN> learned <MOVE>!" is shown.
--
-- FAST PKMN CENTER: Nurse Joy asks one question. NO: "Thank you! Come
-- again!". YES: the heal machine runs as usual, then "All done! Thank you,
-- come again!".
return function(mod)
  local function on(key)
    local ok, value = pcall(mod.options.get, mod.options, key)
    return ok and value == true
  end

  local generation = 1
  pcall(function()
    local GV = require("src.core.GameVersion")
    if type(GV.generation) == "function" then generation = GV.generation() end
  end)

  local TEXT = {
    welcome = "Welcome to the\nPOKéMON CENTER!\fMay I heal your\nPOKéMON?",
    no = "Thank you!\nCome again!",
    done = "All done! Thank\nyou, come again!",
  }

  local okRT, RomText = pcall(require, "src.core.RomText")
  local function romLine(data, label, ...)
    if not okRT then return nil end
    local ok, text = pcall(RomText, data, label, nil, ...)
    if ok and type(text) == "string" and text ~= "" then return text end
    return nil
  end

  -- A screen that shows nothing: the frame after it is pushed it takes itself
  -- off and runs `fn`, so the code that pushed a text box carries on as if
  -- the box had been read.
  local function skipState(game, fn)
    local state = { isOpaque = false, phSkipText = true }
    function state:update()
      if game and game.stack and game.stack:top() == self then game.stack:pop() end
      if fn then fn() end
    end
    function state:draw() end
    return state
  end

  local function copy(t)
    local out = {}
    for k, v in pairs(t or {}) do out[k] = v end
    return out
  end

  ---------------------------------------------------------------------------
  -- Red / Blue / Yellow
  ---------------------------------------------------------------------------
  local function installGen1()
    local okT, TextBox = pcall(require, "src.render.TextBox")
    if not okT or type(TextBox) ~= "table" or type(TextBox.new) ~= "function" then return end
    if TextBox._phFastQol then return end
    TextBox._phFastQol = true

    -- The nurse's visit in progress (FAST PKMN CENTER), or nil.
    local visit

    local function bootText(game, text)
      local data = game and game.data
      for _, label in ipairs({ "_BootedUpTMText", "_BootedUpHMText" }) do
        local line = romLine(data, label)
        if line and text:sub(1, #line) == line then return true end
      end
      return false
    end

    local origNew = TextBox.new
    TextBox.new = function(game, text, onDone, opts, ...)
      if type(text) == "string" then
        local v = visit
        if v then
          if type(opts) == "table" and type(opts.choice) == "function"
              and v.hello and text:sub(1, #v.hello) == v.hello then
            local choice = opts.choice
            local newOpts = copy(opts)
            newOpts.choiceLabels, newOpts.choiceBox = nil, nil
            newOpts.choice = function(yes)
              v.healed = yes and true or false
              return choice(yes)
            end
            return origNew(game, TEXT.welcome, onDone, newOpts, ...)
          end
          if (v.need and text == v.need) or (v.fit and text == v.fit) then
            return skipState(game, onDone)
          end
          if v.bye and text == v.bye then
            return origNew(game, v.healed and TEXT.done or TEXT.no, onDone, opts, ...)
          end
        end
        -- "Booted up a TM! It contained X. Teach X to a POKéMON?": YES.
        if type(opts) == "table" and type(opts.choice) == "function"
            and on("learn_tms_faster") and bootText(game, text) then
          local choice = opts.choice
          return skipState(game, function() choice(true) end)
        end
      end
      return origNew(game, text, onDone, opts, ...)
    end

    -- FAST PKMN CENTER: the game's own visit (machine, music, Pikachu's hop
    -- in Yellow), with its texts swapped as they come up.
    pcall(function()
      local OW = require("src.world.OverworldController")
      if type(OW) ~= "table" or type(OW.nurseHeal) ~= "function" or OW._phFastNurse then return end
      OW._phFastNurse = true
      local origHeal = OW.nurseHeal
      function OW:nurseHeal(onDone, npc, ...)
        if not on("fast_pkmn_center")
            or (self.map and self.map.id == "PEWTER_POKECENTER" and self.pikachuPewterSleepScene) then
          return origHeal(self, onDone, npc, ...)
        end
        local game = self.game or require("src.core.Game")
        local data = game and game.data
        local v = {
          hello = romLine(data, "_PokemonCenterWelcomeText"),
          need = romLine(data, "_NeedYourPokemonText"),
          fit = romLine(data, "_PokemonFightingFitText"),
          bye = romLine(data, "_PokemonCenterFarewellText"),
          healed = false,
        }
        if not (v.hello and v.bye) then return origHeal(self, onDone, npc, ...) end
        visit = v
        local function finish(...)
          if visit == v then visit = nil end
          if onDone then return onDone(...) end
        end
        local ok, err = pcall(origHeal, self, finish, npc, ...)
        if not ok then
          if visit == v then visit = nil end
          error(err, 0)
        end
      end
    end)

    -- LEARN TMS FASTER: the forget list for a TM / HM straight away.
    pcall(function()
      local MLM = require("src.ui.MoveLearnMenu")
      if type(MLM) ~= "table" or type(MLM.enter) ~= "function" or MLM._phFastTm then return end
      MLM._phFastTm = true

      -- A TM / HM is being taught while the party menu under it is in its
      -- TM/HM mode (ABLE / NOT ABLE). Level-up learning never has that.
      local function teachingMachine(game)
        local states = game and game.stack and game.stack.states
        for _, state in ipairs(states or {}) do
          if type(state) == "table" and state.tmhm then return true end
        end
        return false
      end

      local origEnter = MLM.enter
      function MLM:enter(...)
        if self._phFast == nil then
          self._phFast = on("learn_tms_faster") and teachingMachine(self.game) or false
        end
        if self._phFast then
          self:askForget()
          return
        end
        return origEnter(self, ...)
      end

      -- B on the list: no "Abandon learning?", no "did not learn".
      local origAbandon = MLM.confirmAbandon
      function MLM:confirmAbandon(...)
        if not self._phFast then return origAbandon(self, ...) end
        self.selecting = false
        local game = self.game
        if game.stack:top() == self then game.stack:pop() end
        if self.onDone then self.onDone(false) end
      end

      -- A move picked: only "<PKMN> learned <MOVE>!".
      local origFinish = MLM.finish
      function MLM:finish(learned, ...)
        if not (self._phFast and learned) then return origFinish(self, learned, ...) end
        local TextBox = require("src.render.TextBox")
        local game = self.game
        self.selecting = false
        if game.stack:top() == self then game.stack:pop() end
        pcall(function()
          require("src.world.PikachuFollower").onMoveLearned(game.save, self.mon, self.newMoveId)
        end)
        local mdef = game.data.moves[self.newMoveId]
        local name = self:monName()
        local moveName = mdef and mdef.name or tostring(self.newMoveId)
        local msg = romLine(game.data, "_LearnedMove1Text", name, moveName)
          or (name .. " learned\n" .. moveName .. "!")
        local opts
        if type(TextBox.soundOpts) == "function" then
          local okS, o = pcall(TextBox.soundOpts, game, self.learnedSound or "Get_Item1")
          if okS then opts = o end
        end
        local onDone = self.onDone
        game.stack:push(TextBox.new(game, msg, function()
          if onDone then onDone(true) end
        end, opts))
      end
    end)
  end

  ---------------------------------------------------------------------------
  -- Gold / Silver / Crystal
  ---------------------------------------------------------------------------
  local HM_MOVES = {
    CUT = true, FLY = true, SURF = true, STRENGTH = true, FLASH = true,
    WATERFALL = true, WHIRLPOOL = true,
  }

  local function installGen2TMs()
    local okP, PackMenu = pcall(require, "src.ui.gen2.PackMenu")
    local okG, Game2 = pcall(require, "src.core.Game2")
    local okS, Screens = pcall(require, "src.ui.Screens")
    if not (okP and okG and okS) or type(PackMenu) ~= "table" or type(Game2) ~= "table"
        or type(PackMenu.openTeachParty) ~= "function"
        or type(Game2.learnMoveOn) ~= "function" then
      return
    end
    if Game2._phFastTm then return end
    Game2._phFastTm = true

    -- Set while the PACK's teach party hands its pick to learnMoveOn.
    local armed = false

    local origOpen = PackMenu.openTeachParty
    function PackMenu:openTeachParty(row, ...)
      if not on("learn_tms_faster") then return origOpen(self, row, ...) end
      local push = Screens.push
      Screens.push = function(game, id, opts, ...)
        if id == "Gen2PartyMenu" and type(opts) == "table"
            and type(opts.onChoose) == "function" then
          local choose = opts.onChoose
          opts.onChoose = function(...)
            armed = true
            local ok, err = pcall(choose, ...)
            armed = false
            if not ok then error(err, 0) end
          end
        end
        return push(game, id, opts, ...)
      end
      local ok, err = pcall(origOpen, self, row, ...)
      Screens.push = push
      if not ok then error(err, 0) end
    end

    local origLearn = Game2.learnMoveOn
    function Game2:learnMoveOn(mon, moveId, onDone, ...)
      if not armed then return origLearn(self, mon, moveId, onDone, ...) end
      armed = false
      local moves = type(mon) == "table" and mon.moves or nil
      if type(moves) ~= "table" or #moves < 4 then
        return origLearn(self, mon, moveId, onDone, ...)
      end
      for _, move in ipairs(moves) do
        if move.id == moveId then return origLearn(self, mon, moveId, onDone, ...) end
      end
      local TextBox = require("src.render.TextBox")
      local Strings = require("src.core.Strings")
      local moveDef = (self.data.moves or {})[moveId]
      local moveName = (moveDef and moveDef.name) or moveId
      local name = mon.nickname or mon.name or mon.species or "?"
      local entry = { id = moveId, pp = moveDef and moveDef.pp or 0,
        maxPp = moveDef and moveDef.pp or 0 }
      local function finish(learned)
        if onDone then onDone(learned) end
      end
      local pushList
      local function pickMove()
        self.stack:push(TextBox.new(self, Strings("Which move should\nbe forgotten?"), nil,
          { stay = { onShown = pushList } }))
      end
      pushList = function()
        Screens.push(self, "Gen2MoveDeleter", {
          mon = mon,
          moves = self.data.moves,
          layout = "forget",
          onCancel = function()
            self.stack:pop() -- the move list
            self.stack:pop() -- the question it stood on
            finish(false)
          end,
          onChoose = function(slot)
            local old = mon.moves[slot]
            self.stack:pop() -- the move list
            if old and HM_MOVES[old.id] then
              return self:say(Strings("HM moves can't be\nforgotten now."), pushList)
            end
            self.stack:pop() -- the question
            mon.moves[slot] = entry
            pcall(function()
              require("src.mods.Runtime").emit("pokemon.move_learned",
                { mon = mon, moveId = moveId })
            end)
            local opts
            if type(TextBox.soundOpts) == "function" then
              local okO, o = pcall(TextBox.soundOpts, self, "Sfx_DexFanfare5079")
              if okO then opts = o end
            end
            self:say(Strings("%s learned\n%s!", name, moveName),
              function() finish(true) end, opts)
          end,
        })
      end
      pickMove()
    end
  end

  -- FAST PKMN CENTER on Gold / Silver / Crystal: the nurse's own script
  -- (PokecenterNurseScript), with the greetings and the long lines taken
  -- out. The heal, the machine, the music, the Pokerus check and the bow all
  -- stay as the game runs them.
  local TEXT_OPS = { writetext = true, farwritetext = true }

  local function scriptList(vm, key)
    if type(key) == "table" then return key end
    return vm.scripts and vm.scripts[key]
  end

  local function firstText(list)
    for _, cmd in ipairs(list or {}) do
      if TEXT_OPS[cmd.op] then return cmd.text end
    end
  end

  -- The tail after the heal ("Thank you for waiting... We hope to see you
  -- again!", then the bow): one line of ours, the bow kept.
  local function rewriteTail(list, from, text)
    local out = { { op = "rawtext", text = text, stay = true } }
    local afterText = true
    local seenFirst = false
    for i = from, #list do
      local cmd = list[i]
      if TEXT_OPS[cmd.op] then
        seenFirst = true
        afterText = true
      elseif cmd.op == "pause" and afterText then
        afterText = false
      else
        afterText = false
        if seenFirst then out[#out + 1] = cmd end
      end
    end
    return out
  end

  local function buildNurse(vm, key)
    local root = scriptList(vm, key)
    local first = root and root[1]
    if not (first and first.op == "jumpstd" and first.std == "PokecenterNurseScript") then
      return nil
    end
    -- The list with the YES/NO, found from the std script.
    local seen, queue, ask = {}, { first.script }, nil
    while #queue > 0 and not ask do
      local k = table.remove(queue, 1)
      local list = scriptList(vm, k)
      if list and not seen[list] then
        seen[list] = true
        for _, cmd in ipairs(list) do
          if cmd.op == "yesorno" then ask = list break end
        end
        if not ask then
          for _, cmd in ipairs(list) do
            if cmd.script then queue[#queue + 1] = cmd.script end
          end
        end
      end
    end
    if not ask then return nil end
    local y
    for i, cmd in ipairs(ask) do
      if cmd.op == "yesorno" then y = i break end
    end
    local noCmd = ask[y + 1]
    if not (noCmd and noCmd.op == "iffalse" and noCmd.script) then return nil end
    local noList = scriptList(vm, noCmd.script)
    if not noList then return nil end

    local out = { { op = "opentext" } }
    -- Crystal clears its POKECOM CENTER welcome event here: commands that
    -- are not text stay.
    for j = 1, y - 1 do
      local op = ask[j].op
      if not (TEXT_OPS[op] or op == "promptbutton" or op == "opentext") then
        out[#out + 1] = ask[j]
      end
    end
    out[#out + 1] = { op = "rawtext", text = TEXT.welcome, stay = true }
    out[#out + 1] = { op = "yesorno" }
    out[#out + 1] = { op = "iffalse", script = rewriteTail(noList, 1, TEXT.no) }
    -- "We'll need your POKEMON." and its pause go.
    local i = y + 2
    if ask[i] and TEXT_OPS[ask[i].op] then
      i = i + 1
      if ask[i] and ask[i].op == "pause" then i = i + 1 end
    end
    -- Everything up to the next text runs as the game has it; a branch that
    -- goes to the same thank-you text gets our line as well.
    local tailText
    local tailAt
    for j = i, #ask do
      if TEXT_OPS[ask[j].op] then tailText, tailAt = ask[j].text, j break end
    end
    if not tailAt then return nil end
    local doneTail = rewriteTail(ask, tailAt, TEXT.done)
    for j = i, tailAt - 1 do
      local cmd = ask[j]
      if cmd.script and (cmd.op == "iftrue" or cmd.op == "iffalse" or cmd.op == "sjump") then
        local target = scriptList(vm, cmd.script)
        if target and firstText(target) == tailText then
          local c = copy(cmd)
          c.script = doneTail
          cmd = c
        end
      end
      out[#out + 1] = cmd
    end
    for _, cmd in ipairs(doneTail) do out[#out + 1] = cmd end
    return out
  end

  local function installGen2Nurse()
    pcall(function()
      mod.hooks:wrap("world.talk", function(nextFn, world, npc, ...)
        local vm = type(world) == "table" and world.vm
        local key = type(npc) == "table" and npc.def and npc.def.scriptKey
        if not (vm and key and on("fast_pkmn_center")) then
          return nextFn(world, npc, ...)
        end
        local okB, list = pcall(buildNurse, vm, key)
        if not okB or not list then return nextFn(world, npc, ...) end
        local saved = rawget(vm, "start")
        local start = vm.start
        rawset(vm, "start", function(self, k, ...)
          rawset(vm, "start", saved)
          if k == key then return start(self, list, ...) end
          return start(self, k, ...)
        end)
        local result = { pcall(nextFn, world, npc, ...) }
        if rawget(vm, "start") ~= saved then rawset(vm, "start", saved) end
        if not result[1] then error(result[2], 0) end
        return (table.unpack or unpack)(result, 2)
      end)
    end)
  end

  if generation == 2 then
    pcall(installGen2TMs)
    installGen2Nurse()
  else
    pcall(installGen1)
  end
end
