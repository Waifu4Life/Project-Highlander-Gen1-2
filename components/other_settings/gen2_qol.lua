-- Gen 2 side of five Other Settings / Battle Screen / Overworld Screen
-- options. Gen 1 has its own versions in main.lua; this file only runs in
-- Gold, Silver and Crystal.
--
--   GET BOOSTED EXP    every Pokemon earns traded-Pokemon EXP, and the
--                      battle text says "a boosted"
--   MODERN EXP SHARE   after a win, the Pokemon that didn't fight (awake,
--                      not eggs) get half EXP, announced in one line
--   SPARKLING HIDDEN   a small twinkling cross over every hidden item still
--   ITEMS              on the map
--   SHOW AREA NAMES    the new area's name in a box at the bottom of the
--                      screen for 2 seconds when you walk into it
--   MODERN STORES      "OWN n" in the top-left corner of the Poke Mart buy
--                      list for the highlighted item
--
-- None of this runs in link battles.
return function(mod)
  local okVersion, Version = pcall(require, "src.core.GameVersion")
  if not (okVersion and type(Version.generation) == "function"
      and Version.generation() == 2) then
    return
  end

  ---------------------------------------------------------------------------
  -- Settings
  ---------------------------------------------------------------------------
  local function setting(key)
    local ok, value = pcall(mod.options.get, mod.options, key)
    if ok then return value end
    return nil
  end

  local function isOn(key)
    return setting(key) == true
  end

  -- MODERN EXP SHARE is a choice row; older builds stored true/false.
  local function shareIsOn()
    local value = setting("modern_exp_share")
    return value == "on" or value == true
  end

  local function isLinkBattle(battle)
    return battle ~= nil and (battle.kind == "link" or (battle.linkBattle and true) or false)
  end

  -- Patch a game class once, however many times this file is loaded.
  local function patchOnce(class, flag, apply)
    if type(class) ~= "table" or class[flag] then return end
    class[flag] = true
    apply(class)
  end

  ---------------------------------------------------------------------------
  -- MODERN EXP SHARE
  ---------------------------------------------------------------------------
  -- The game hands out EXP to the Pokemon that fought as usual. Right after
  -- that, the ones that sat on the bench get their half through the game's
  -- own giveExperiencePass, so levelling up and new moves work normally.
  local benchPayout = { running = false, keepFullShare = false }

  local function canEarnExp(mon)
    if type(mon) ~= "table" then return false end
    if mon.isEgg or mon.egg then return false end
    return (mon.hp or 0) > 0
  end

  local function playerParty(battle)
    if type(battle) ~= "table" then return nil end
    local candidates = {
      battle.party,
      battle.save and battle.save.party,
      battle.game and battle.game.save and battle.game.save.party,
    }
    for _, party in ipairs(candidates) do
      if type(party) == "table" then return party end
    end
    return nil
  end

  local function benchExpAmount(battle, loser, def, first)
    local yield = 0
    if type(def) == "table" then yield = def.baseExp or def.expYield or 0 end
    local level = (loser and loser.level) or 1
    local amount = math.floor(math.floor(yield * level / 7) / 2)
    local function boost() amount = math.floor(amount * 3 / 2) end
    if first and (first.traded or isOn("always_boosted_exp")) then boost() end
    if battle.trainer ~= nil then boost() end
    if first and first.item == "LUCKY_EGG" then boost() end
    if amount < 1 then amount = 1 end
    return amount
  end

  local function announce(battle, text)
    if type(battle.emit) == "function" then
      pcall(battle.emit, battle, { kind = "message", text = text })
    elseif type(battle.sayNext) == "function" then
      pcall(battle.sayNext, battle, text)
    end
  end

  -- foughtMons: set of party Pokemon that already got their EXP.
  local function payTheBench(battle, loser, def, foughtMons)
    if benchPayout.running or not shareIsOn() or isLinkBattle(battle) then return end
    if not (loser and def and type(battle.giveExperiencePass) == "function") then
      return
    end
    local party = playerParty(battle)
    if not party then return end

    local benchSlots = {}
    for slot, mon in ipairs(party) do
      if canEarnExp(mon) and not foughtMons[mon] then
        benchSlots[#benchSlots + 1] = slot
      end
    end
    if #benchSlots == 0 then return end

    local amount = benchExpAmount(battle, loser, def, party[benchSlots[1]])
    if #benchSlots == 1 then
      announce(battle, ("One more got\n%d EXP!"):format(amount))
    else
      announce(battle, ("%d others got\n%d EXP each!"):format(#benchSlots, amount))
    end

    benchPayout.running, benchPayout.keepFullShare = true, true
    local ok, err = pcall(battle.giveExperiencePass, battle, loser, def,
      benchSlots, 2, false)
    benchPayout.running, benchPayout.keepFullShare = false, false

    if not ok then
      if mod.log then mod.log:warn("bench EXP failed: %s", tostring(err)) end
      return
    end
    -- The one summary line above replaces the game's per-Pokemon lines.
    local isBench = {}
    for _, slot in ipairs(benchSlots) do isBench[slot] = true end
    for _, event in ipairs(type(battle.events) == "table" and battle.events or {}) do
      if type(event) == "table" and event.kind == "experience" and isBench[event.index] then
        event.text = nil
      end
    end
  end

  pcall(function()
    patchOnce(require("src.battle.gen2.Battle"), "_phBenchExp", function(Battle)
      if type(Battle.giveExperiencePass) ~= "function" then return end
      local givePass = Battle.giveExperiencePass
      function Battle:giveExperiencePass(loser, def, recipients, count, halved, silent)
        local result = givePass(self, loser, def, recipients, count, halved, silent)
        local normalAward = count == nil or count == 1
        if normalAward and not silent and shareIsOn() and not benchPayout.running then
          local party = playerParty(self) or {}
          local fought = {}
          for _, slot in ipairs(recipients or {}) do
            if party[slot] then fought[party[slot]] = true end
          end
          payTheBench(self, loser, def, fought)
        end
        return result
      end
    end)
  end)

  ---------------------------------------------------------------------------
  -- GET BOOSTED EXP (also keeps the bench payout from being halved again)
  ---------------------------------------------------------------------------
  pcall(function()
    mod.hooks:wrap("exp.gain", function(nextFn, ctx)
      if type(ctx) == "table" then
        if benchPayout.keepFullShare and ctx.halved then ctx.halved = false end
        if isOn("always_boosted_exp") and not isLinkBattle(ctx.battle) then
          ctx.traded = true
        end
      end
      return nextFn(ctx)
    end)
  end)

  -- Gold/Silver/Crystal pick the "boosted" wording from isOutsider, not from
  -- the EXP numbers, so both need telling.
  pcall(function()
    patchOnce(require("src.battle.gen2.Battle"), "_phBoostedText", function(Battle)
      if type(Battle.isOutsider) == "function" then
        local isOutsider = Battle.isOutsider
        function Battle:isOutsider(mon)
          if isOn("always_boosted_exp") and not isLinkBattle(self) then return true end
          return isOutsider(self, mon)
        end
      end
      if type(Battle.emit) == "function" then
        local emit = Battle.emit
        function Battle:emit(event)
          if isOn("always_boosted_exp") and type(event) == "table"
              and event.kind == "experience" and type(event.text) == "string"
              and not event.text:find("boosted", 1, true) then
            event.text = event.text:gsub(" gained ", " gained a boosted ", 1)
          end
          return emit(self, event)
        end
      end
    end)
  end)

  ---------------------------------------------------------------------------
  -- SPARKLING HIDDEN ITEMS
  ---------------------------------------------------------------------------
  pcall(function()
    local Hidden = require("src.world.gen2.HiddenItems")
    patchOnce(require("src.world.gen2.World"), "_phHiddenSparkles", function(World)
      if type(World.drawWorldBody) ~= "function" then return end
      local drawBody = World.drawWorldBody
      World.drawWorldBody = function(self, scale, ...)
        local result = drawBody(self, scale, ...)
        if not (isOn("sparkling_hidden") and self.map and self.camera
            and type(Hidden.unfound) == "function") then
          return result
        end
        local spots = Hidden.unfound(self.map.def, self.events) or {}
        if #spots == 0 then return result end
        scale = scale or 1
        local clock = (love.timer and love.timer.getTime()) or 0
        local gfx = love.graphics
        gfx.push("all")
        for _, spot in ipairs(spots) do
          -- centre of the 16x16 tile, on screen
          local cx = (spot.x * 16 + 8 - self.camera.x) * scale
          local cy = (spot.y * 16 + 8 - self.camera.y) * scale
          local glow = 0.4 + 0.6 * math.abs(math.sin(clock * 4 + spot.x + spot.y))
          gfx.setColor(1, 1, 0.65, glow)
          gfx.rectangle("fill", cx - 3 * scale, cy, 7 * scale, scale)
          gfx.rectangle("fill", cx, cy - 3 * scale, scale, 7 * scale)
        end
        gfx.pop()
        return result
      end
    end)
  end)

  ---------------------------------------------------------------------------
  -- SHOW AREA NAMES
  ---------------------------------------------------------------------------
  local SHOW_SECONDS = 2
  local BOX_TEXT_WIDTH = 136
  local lastGame
  local banner -- { game = ..., text = ..., secondsLeft = ... } while showing

  local function nameForMap(mapId, map)
    local def = map
    if type(map) == "table" and type(map.def) == "table" then def = map.def end
    if type(def) == "table" then
      for _, field in ipairs({ "label", "name", "title", "displayName" }) do
        local value = def[field]
        if type(value) == "string" and value ~= "" then
          return (value:gsub("\n", " "))
        end
      end
    end
    if type(mapId) ~= "string" then return nil end
    -- "Route29" / "VioletCity_Mart" -> "Route 29" / "Violet City Mart"
    local name = mapId:gsub("_", " ")
    name = name:gsub("(%l)(%u)", "%1 %2")
    name = name:gsub("(%a)(%d)", "%1 %2")
    return name
  end

  -- Crystal shows its own sign for some areas; never show ours on top.
  local function gameShowsSign(game)
    return game and game.world and game.world.mapSign ~= nil and game.world.mapSign ~= false
  end

  local function walkingAround(game)
    if not game then return false end
    local top = game.stack and game.stack:top()
    if top then return top.isOverworld == true and not top.textbox end
    local world = game.world
    return game.phase == "play" and world ~= nil and world.map ~= nil
      and not world.textbox and not world.mapSetup
  end

  local function bannerShowing(game)
    if not banner or banner.game ~= game or banner.secondsLeft <= 0 then return false end
    if not isOn("display_area_names") then return false end
    return walkingAround(game) and not gameShowsSign(game)
  end

  -- At most two lines; a name too long for two ends in "...".
  local function bannerLines(text, Font)
    local function width(s) return Font.width(s) or #s * 8 end
    local lines = {}
    for word in text:gmatch("%S+") do
      local last = lines[#lines]
      if last and width(last .. " " .. word) <= BOX_TEXT_WIDTH then
        lines[#lines] = last .. " " .. word
      else
        lines[#lines + 1] = word
      end
    end
    if #lines > 2 then
      lines = { lines[1], lines[2] .. "..." }
    end
    return lines, width
  end

  pcall(function()
    mod.events:on("game.ready", function(event)
      lastGame = event and (event.game or event)
      banner = nil
    end)
  end)

  pcall(function()
    mod.events:on("map.entered", function(event)
      banner = nil
      if type(event) ~= "table" or not isOn("display_area_names") then return end
      -- Not when a save is loaded, only when you actually walk somewhere.
      if event.via == "boot" or event.via == "continue" then return end
      local game = event.game or lastGame
      if not game or gameShowsSign(game) then return end
      local text = nameForMap(event.mapId, event.map)
      if text then
        banner = { game = game, text = text, secondsLeft = SHOW_SECONDS }
      end
    end)
  end)

  -- The 2 seconds only count down while the banner is actually on screen.
  pcall(function()
    mod.hooks:wrap("input.step", function(nextFn, game, dt)
      lastGame = game or lastGame
      if banner then
        if banner.game ~= game or not isOn("display_area_names") then
          banner = nil
        elseif bannerShowing(game) then
          banner.secondsLeft = banner.secondsLeft - math.max(0, tonumber(dt) or 0)
        end
      end
      return nextFn(game, dt)
    end)
  end)

  pcall(function()
    mod.hooks:wrap("render.hud", function(nextFn, game, viewport)
      local result = nextFn(game, viewport)
      if type(viewport) ~= "table" or not bannerShowing(game) then return result end
      local Font = require("src.render.Font")
      local gfx = love.graphics
      local lines, width = bannerLines(banner.text or "", Font)
      local boxH = (#lines > 1) and 36 or 24
      local boxTop = 140 - boxH
      gfx.push("all")
      gfx.translate(viewport.gameX or 0, viewport.gameY or 0)
      local scale = viewport.scale or 1
      gfx.scale(scale, scale)
      -- white box, 1px black frame, text centred
      gfx.setColor(1, 1, 1, 1)
      gfx.rectangle("fill", 4, boxTop, 152, boxH)
      gfx.setColor(0, 0, 0, 1)
      gfx.setLineWidth(1)
      gfx.rectangle("line", 4.5, boxTop + 0.5, 151, boxH - 1)
      for i, line in ipairs(lines) do
        Font.draw(line, math.floor((160 - width(line)) / 2), boxTop + 8 + (i - 1) * 12)
      end
      gfx.pop()
      return result
    end)
  end)

  ---------------------------------------------------------------------------
  -- MODERN STORES
  ---------------------------------------------------------------------------
  -- How many of an item you have: the inventory count, or (if the save keeps
  -- a bag list instead) every stack of it added up.
  local function countOwned(game, itemId)
    local save = game and game.save
    if not (save and itemId) then return 0 end
    local direct = save.inventory and tonumber(save.inventory[itemId])
    if direct then return math.max(0, math.floor(direct)) end
    local total = 0
    local function addStacks(list)
      if type(list) ~= "table" then return end
      if list.id == itemId then total = total + (tonumber(list.count or list.qty) or 0) end
      for _, entry in ipairs(list) do addStacks(entry) end
    end
    addStacks(save.bag)
    addStacks(save.inventory)
    return total
  end

  local function addOwnCounter(mart, game)
    if type(mart) ~= "table" or mart.screenId ~= "Gen2MartMenu" or mart._phOwnCounter then
      return
    end
    local slot = type(mart.drawUnder) == "function" and "drawUnder"
      or (type(mart.draw) == "function" and "draw") or nil
    if not slot then return end
    mart._phOwnCounter = true
    local original = mart[slot]
    mart[slot] = function(self, ...)
      local result = original(self, ...)
      if not isOn("modern_stores") then return result end
      if self.phase ~= "buy" and self.phase ~= "buyQuantity" then return result end
      local entry = self.entries and self.entries[self.index]
      if not (entry and entry.id) then return result end
      local Font = require("src.render.Font")
      local gfx = love.graphics
      gfx.push("all")
      gfx.setColor(1, 1, 1, 1)
      gfx.rectangle("fill", 0, 0, 80, 16)
      gfx.setColor(0, 0, 0, 1)
      Font.draw("OWN " .. countOwned(game or self.game, entry.id), 4, 4)
      gfx.pop()
      return result
    end
  end

  pcall(function()
    mod.events:on("screen.pushed", function(event)
      if type(event) ~= "table" then return end
      local screen = event.state
      local game = event.game or (type(screen) == "table" and screen.game) or lastGame
      if game then addOwnCounter(screen, game) end
    end, -1000)
  end)
end
