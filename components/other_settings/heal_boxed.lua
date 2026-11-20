-- HEAL BOXED PKMN (1.76.0): a row under BILL's PC in the Pokémon Center PC
-- (and the bedroom PC that opens the same menu). Choosing it plays the
-- Pokémon Center's healing jingle, heals every Pokémon stored in the boxes
-- (full HP, no status, full PP) and says so.
--   Gen 1: the PC menu's own rows come through the ui.pc.items hook.
--   Gen 2: the whose-PC menu (Gen2CenterPcMenu) gets one more entry.
-- Gen 2 already heals a Pokémon as it goes into a box, so there it mostly
-- tidies up Pokémon boxed by other means (an import, an older save).
return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local gen2 = GameVersion.generation and GameVersion.generation() == 2

  local ROW_ID = "highlander_heal_boxed"

  -- The PC menu's text box is 16 tiles wide: 13 letters fit after the
  -- cursor, so <PK><MN> (two tiles) keeps the label inside the frame.
  local function label(mixed)
    return mixed and "Heal Boxed <PK><MN>" or "HEAL BOXED <PK><MN>"
  end
  local function message(mixed)
    return mixed and "All stored Pokémon\nhave been healed!"
      or "All stored POKéMON\nhave been healed!"
  end

  ---------------------------------------------------------------- healing
  local function healGen1(mon)
    if type(mon) ~= "table" then return end
    local maxHp = type(mon.stats) == "table" and tonumber(mon.stats.hp)
      or tonumber(mon.maxHp)
    if maxHp then mon.hp = maxHp end
    mon.status = nil
    local okP, Pokemon = pcall(require, "src.pokemon.Pokemon")
    local okD, Data = pcall(require, "src.core.Data")
    local moves = okD and type(Data) == "table" and Data.moves or nil
    if okP and moves and type(mon.moves) == "table" then
      for _, mv in ipairs(mon.moves) do
        local def = type(mv) == "table" and moves[mv.id]
        if def then mv.pp = Pokemon.maxPP(def.pp, mv.ppUps) end
      end
    end
  end

  local function healGen2(mon, data)
    if type(mon) ~= "table" or mon.isEgg then return end
    mon.hp = mon.maxHp or mon.hp
    mon.status = nil
    mon.statusTurns = nil
    local ok, Mon = pcall(require, "src.battle.gen2.Mon")
    if ok and type(Mon.restoreAllPp) == "function" then
      pcall(Mon.restoreAllPp, mon, data)
    end
  end

  -- Every box, read fresh (a companion mod may change the box count).
  local function healBoxes(game)
    local save = game and game.save
    if type(save) ~= "table" then return 0 end
    local healed = 0
    if gen2 then
      local Boxes = require("src.core.gen2.Boxes")
      for b = 1, tonumber(Boxes.NUM_BOXES) or 14 do
        local ok, box = pcall(Boxes.box, save, b)
        if ok and type(box) == "table" then
          for _, mon in ipairs(box) do
            healGen2(mon, game.data)
            healed = healed + 1
          end
        end
      end
    else
      local Boxes = require("src.pokemon.Boxes")
      local ok, boxes = pcall(Boxes.ensure, save)
      for _, box in ipairs(ok and boxes or {}) do
        if type(box) == "table" then
          for _, mon in ipairs(box) do
            healGen1(mon)
            healed = healed + 1
          end
        end
      end
    end
    return healed
  end

  local function jingle(game)
    pcall(function()
      require("src.core.Music").playOnce(game.data,
        gen2 and "Music_HealPokemon" or "Music_PkmnHealed")
    end)
  end

  -- Mixed-case text (a translation or modern-text mod) shows the label the
  -- same way. The all-caps games still write "BILL's PC" and "PROF.OAK's",
  -- so an 's (or 'd, 'r ...) after a capital doesn't count.
  local function hasLower(s)
    if type(s) ~= "string" then return false end
    return (s:gsub("'%l+", "")):find("%l") ~= nil
  end

  ------------------------------------------------------------------ Gen 1
  if not gen2 then
    mod.hooks:wrap("ui.pc.items", function(nextFn, game, items)
      local out = nextFn(game, items)
      if type(out) ~= "table" or not (game and game.save) then return out end
      for _, row in ipairs(out) do
        if row.highlanderHealBoxed then return out end
      end
      -- the game's own labels are still their English source here: the box
      -- PC row is BILL'S PC (or SOMEONE'S PC before meeting Bill)
      local Strings = require("src.core.Strings")
      local at = 1
      for i, row in ipairs(out) do
        if row.label == Strings.source("BILL'S PC")
            or row.label == Strings.source("SOMEONE'S PC") then
          at = i
          break
        end
      end
      local text = game.data and game.data.text or {}
      local mixed = hasLower(text.LogOffPCText) or hasLower(text.BillsPCText)
      local TextBox = require("src.render.TextBox")
      table.insert(out, at + 1, {
        highlanderHealBoxed = true,
        label = label(mixed),
        keepOpen = true,
        onSelect = function()
          healBoxes(game)
          jingle(game)
          game.stack:push(TextBox.new(game, message(mixed)))
        end,
      })
      return out
    end)
    return
  end

  ------------------------------------------------------------------ Gen 2
  local function decorate(menu)
    if type(menu) ~= "table" or menu.highlanderHealBoxed
        or type(menu.buildEntries) ~= "function" or type(menu.choose) ~= "function" then
      return menu
    end
    menu.highlanderHealBoxed = true
    local mixed = false
    for _, entry in ipairs(menu.entries or {}) do
      if entry.id == "bills" or entry.id == "turnoff" then
        mixed = mixed or hasLower(entry.label)
      end
    end

    local baseBuild = menu.buildEntries
    menu.buildEntries = function(self, ...)
      baseBuild(self, ...)
      local entries = self.entries or {}
      for _, entry in ipairs(entries) do
        if entry.id == ROW_ID then return end
      end
      local at = 0
      for i, entry in ipairs(entries) do
        if entry.id == "bills" then at = i break end
      end
      table.insert(entries, at + 1, { id = ROW_ID, label = label(mixed) })
      self.entries = entries
    end
    pcall(menu.buildEntries, menu)

    local baseChoose = menu.choose
    menu.choose = function(self, ...)
      local entry = self.entries and self.entries[self.index]
      if entry and entry.id == ROW_ID then
        healBoxes(self.game)
        jingle(self.game)
        local pages = {}
        local page = {}
        for line in (message(mixed) .. "\n"):gmatch("([^\n]*)\n") do
          page[#page + 1] = line
        end
        pages[1] = page
        self:say(pages)
        return
      end
      return baseChoose(self, ...)
    end
    return menu
  end

  local id = "Gen2CenterPcMenu"
  local inherited = mod.content.screens:get(id)
  local function maker(record)
    if type(record) == "function" then return record end
    return type(record) == "table" and record.new or nil
  end
  local record = {
    new = function(game, ...)
      local make = maker(inherited) or require("src.ui.gen2.CenterPcMenu").new
      return decorate(make(game, ...))
    end,
  }
  if inherited then
    mod.content.screens:override(id, record)
  else
    mod.content.screens:register(id, record)
  end
end
