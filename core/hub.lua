-- The PROJECTHIGHLANDER settings menu: its entry in the game's Options
-- menu, the main list (MECHANICS / SYSTEM / COSMETICS), and every page.
--   settings    core/settings.lua
--   state       shared tables from main.lua (optionsHooks is used here)
--   components  core/components.lua
return function(mod, settings, state, components)
  local Font = require("src.render.Font")
  local OptionsMenu = require("src.ui.OptionsMenu")
  local ListMenu = require("src.ui.ListMenu")
  if mod.ui and type(mod.ui.ListMenu) == "table" and type(mod.ui.ListMenu.new) == "function" then
    ListMenu = mod.ui.ListMenu
  end

  -- Gen 2's sub-menus have no BACK row (B leaves); Gen 1's options screen
  -- always adds one under the rows. Take it off Gen 1's pages too: the
  -- cursor wraps between the first and last row, and B still leaves.
  local OptionRows = require("src.ui.OptionRows")

  -- Gen 2's options screen prints a value at column 11 (8 characters, past
  -- the middle of the page), so values that fit on Gen 1's pages had to
  -- scroll here. Our pages draw it like Gen 1: the label from column 2, the
  -- value one line down from column 2 (":" then the value from column 3,
  -- 16 characters). Same box, cursor, ▼ and scrolling as Gold's screen.
  local function drawGen2Rows(self)
    local Chrome = require("src.ui.gen2.Chrome")
    local Marquee = require("src.ui.Marquee")
    local Strings = require("src.core.Strings")
    Chrome.clear()
    Chrome.textbox(0, 0, Chrome.SCREEN_W - 2, Chrome.SCREEN_H - 2)
    local layout, more = self:layout(self.scroll)
    local cursorY
    for _, slot in ipairs(layout) do
      local row = slot.row
      local hot = slot.index == self.index
      local key = tostring(row.id or row.label)
      local function fit(text, col)
        local room = 19 - col
        if hot then return Marquee.scroll(text, room, key) end
        return Marquee.clip(text, room)
      end
      if hot then cursorY = slot.labelY end
      Chrome.print(fit(Strings(row.label or ""), 2), 2, slot.labelY)
      if slot.valueY and type(row.value) == "function" then
        local ok, text = pcall(row.value, self.game)
        text = ok and tostring(text or "") or "?"
        if text ~= "" then
          Chrome.print(":", 2, slot.valueY)
          Chrome.print(fit(text, 3), 3, slot.valueY)
        end
      end
    end
    if cursorY then Chrome.cursor(1, cursorY) end
    if more then
      love.graphics.setColor(0, 0, 0, 1)
      Font.drawCode(Chrome.DOWN_ARROW, 1 * 8, 16 * 8)
    end
  end

  local function trimBack(page)
    local gen2 = false
    pcall(function() gen2 = require("src.core.GameVersion").generation() == 2 end)
    if gen2 then
      if type(page.layout) == "function" then
        page.drawPanel = function(self)
          local ok, err = pcall(drawGen2Rows, self)
          if not ok then
            mod.log:error("Gen 2 page drawing failed: %s", tostring(err))
            page.drawPanel = nil
          end
        end
      end
      return page
    end
    local baseUpdate = page.update
    page.update = function(self, dt, ...)
      local input = self.game and self.game.input
      local rows = self.view or self.rows or {}
      if input and #rows > 0 and (input:wasPressed("up") or input:wasPressed("down")) then
        local step = input:wasPressed("up") and -1 or 1
        self.index = ((self.index or 1) - 1 + step) % #rows + 1
        self.scroll = OptionRows.clampScroll(self.index, self.scroll or 0, #rows)
        return
      end
      return baseUpdate(self, dt, ...)
    end
    page.draw = function(self)
      local rows = self.view or self.rows or {}
      OptionRows.draw(self.game, rows, self.index, self.scroll or 0)
    end
    return page
  end

  local function labelFor(row, component)
    return settings:detailLabel(component, row)
  end

  -- What a row shows on the right: ON/OFF, or the name of the current choice.
  local function optionValue(component, row)
    local current = settings:get(component, row.key)
    if row.type == "toggle" then
      if current == false then return "OFF" end
      return "ON"
    end
    for _, choice in ipairs(row.choices or {}) do
      local shown, stored = choice[1], choice[2]
      if stored == current then return shown end
    end
    if current == nil or current == false then return "----" end
    return tostring(current)
  end

  -- Left/Right (or A) on a row: flip a toggle, or move to the previous/next
  -- choice, wrapping round at either end.
  local function stepOption(game, component, row, direction)
    local current = settings:get(component, row.key)
    if row.type == "toggle" then
      return settings:set(game, component, row.key, not current)
    end
    local choices = row.choices or {}
    local count = #choices
    if count == 0 then return false end
    local at = 1
    for i = 1, count do
      if choices[i][2] == current then at = i break end
    end
    local nextAt = ((at - 1) + (direction or 1)) % count + 1
    return settings:set(game, component, row.key, choices[nextAt][2])
  end

  -- Adds one component's option rows to a page body. Pages can mix rows
  -- from several components (Battle Screen, Overworld Screen); each row
  -- still reads and writes its own component's setting.
  local function addRows(body, component, schemaRows, skip)
    for _, row in ipairs(schemaRows or {}) do
      local hideOther = {
        gen1_all_pkmn = true, gen2_all_pkmn = true,
        gen1_features_migrated = true,
        gen1_exclusive = true, gen1_starters = true, gen1_fossil = true,
        gen1_fighting = true, gen1_eevee = true, gen1_linkc = true,
        gen1_mystery = true, gen1_legendary_persist = true,
        gen2_features_migrated = true,
        gen2_exclusive = true, gen2_starters = true, gen2_fossil = true,
        gen2_celebi = true, gen2_linkc = true, gen2_kanto_starters = true,
        gen2_birds = true, gen2_mew = true, gen2_roaming_hunter = true,
        gen2_legendary_persist = true,
        -- shown on the GAME CORNER page instead
        coins_2x = true, slot_odds = true, slot_bigger_payouts = true,
        slot_all_lucky = true,
      }
      if not (skip and skip[row.key]) and not row.hidden
          and row.key ~= "enabled"
          and row.key ~= "theme_by_game" and row.key ~= "border_by_game"
          and not (component.key == "other_settings" and hideOther[row.key])
          -- BLUE INTO GREEN only means something in Blue, PIKACHU SOUND
          -- only in Yellow.
          and not (row.key == "blue_into_green" and not (function()
            local ok, GV = pcall(require, "src.core.GameVersion")
            return ok and type(GV.get) == "function" and GV.get() == "blue"
          end)())
          and not (row.key == "pikachu_sound" and not (function()
            local ok, GV = pcall(require, "src.core.GameVersion")
            return ok and type(GV.get) == "function" and GV.get() == "yellow"
          end)())
          and not (row.key == "force_crystal_settings"
            and not (mod.find("crystal_animated_sprites_with_shiny_visuals")
              or (settings.byId and settings.byId["crystal_animated_sprites_with_shiny_visuals"])))
          -- GENDER MOD and BATTLE SPRITES mean nothing in Crystal (its own
          -- Boy/Girl and sprites); the NPC rows are Gen 1 only.
          and not ((row.key == "force_crystal_settings"
              or row.key == "crystalBattleSprites") and (function()
            local ok, GV = pcall(require, "src.core.GameVersion")
            return ok and type(GV.get) == "function" and GV.get() == "crystal"
          end)())
          and not (row.key == "crystalDexPictures" and (function()
            local ok, GV = pcall(require, "src.core.GameVersion")
            return ok and type(GV.get) == "function" and GV.get() == "crystal"
          end)())
          and not ((row.key == "crystalFrontNPCs" or row.key == "crystalOverworldNPCs")
            and (function()
              local ok, GV = pcall(require, "src.core.GameVersion")
              return ok and type(GV.generation) == "function" and GV.generation() == 2
            end)()) then
        local source = row
        if component.id == "custom_borders" and source.key == "border" then
          body[#body + 1] = {
            id = component.key .. ".border",
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.borderLabel) == "function" then
                return exports.borderLabel()
              end
              return optionValue(component, source)
            end,
            step = function(activeGame, direction)
              local exports = component.exports or {}
              if type(exports.stepBorder) == "function" then
                return exports.stepBorder(activeGame, direction)
              end
              return stepOption(activeGame, component, source, direction)
            end,
          }
        elseif component.id == "custom_borders" and source.key == "screen_ratio" then
          -- Shows whether Screen Ratio is actually running (16:9) or why not
          -- (WAITING, NO FRAME, PORTRAIT, FITS, ERROR); stepping is normal.
          body[#body + 1] = {
            id = component.key .. ".screen_ratio",
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.screenRatioLabel) == "function" then
                local ok, label = pcall(exports.screenRatioLabel)
                if ok and label then return label end
              end
              return optionValue(component, source)
            end,
            step = function(activeGame, direction)
              return stepOption(activeGame, component, source, direction)
            end,
          }
        elseif source.type == "custom" then
          -- Value and Left/Right handled by the component (e.g. Shortcuts'
          -- ITEM SHORTCUT rows cycle the Key Items in the current bag).
          body[#body + 1] = {
            id = component.key .. "." .. source.key,
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.customValue) == "function" then
                return exports.customValue(settings.activeGame, source.key)
              end
              return "----"
            end,
            step = function(activeGame, direction)
              local exports = component.exports or {}
              if type(exports.customStep) == "function" then
                return exports.customStep(activeGame or settings.activeGame,
                  source.key, direction or 1)
              end
              return false
            end,
          }
        elseif source.type == "bind" or source.type == "action" then
          body[#body + 1] = {
            id = component.key .. "." .. source.key,
            label = labelFor(source, component),
            value = function()
              local exports = component.exports or {}
              if type(exports.bindLabel) == "function" then
                return exports.bindLabel(source.key)
              end
              return optionValue(component, source)
            end,
            activate = function(activeGame)
              local exports = component.exports or {}
              if type(exports.capture) == "function" then
                return exports.capture(activeGame, source.key)
              end
            end,
            step = function(activeGame)
              local exports = component.exports or {}
              if type(exports.capture) == "function" then
                return exports.capture(activeGame, source.key)
              end
              return stepOption(activeGame, component, source, 1)
            end,
          }
        else
          local lockedCrystal = component.id == "crystal_animated_sprites_with_shiny_visuals"
            and (source.key == "crystalTrainers" or source.key == "crystalPlayerSprite")
            and settings:get("other_settings", "force_crystal_settings") ~= false
          local function forcedHero(game)
            game = game or settings.activeGame
            local girl = false
            local flags = game and game.save and game.save.flags
            if flags and flags.HIGHLANDER_PLAYER_GENDER == "girl" then girl = true end
            local player = game and game.save and game.save.player
            local g = player and player.gender
            if g == "girl" or g == "female" or g == 2 or g == "2" then girl = true end
            local gen2 = false
            local ok, GV = pcall(require, "src.core.GameVersion")
            if ok and type(GV) == "table" and type(GV.generation) == "function" then
              gen2 = GV.generation() == 2
            end
            if gen2 then
              return girl and "KRIS" or "GOLD"
            end
            return girl and "GREEN" or "RED"
          end
          body[#body + 1] = {
            id = component.key .. "." .. source.key,
            label = labelFor(source, component),
            value = function()
              if lockedCrystal then
                if source.key == "crystalTrainers" then return "ALL LOCK" end
                return forcedHero(settings.activeGame) .. " LOCK"
              end
              return optionValue(component, source)
            end,
            step = function(activeGame, direction)
              if lockedCrystal then return false end
              return stepOption(activeGame, component, source, direction)
            end,
          }
        end
      end
    end
  end

  -- Rows that live on another component's page, and rows a page leaves out.
  local MOVED_OTHER_BATTLE = {
    gen3_catch_rate = true, always_boosted_exp = true,
    modern_exp_share = true,
  }
  local MOVED_OTHER_OVERWORLD = {
    modern_stores = true, rematch_anyone = true,
    running_shoes = true, display_area_names = true, sparkling_hidden = true,
    use_repel_again = true,
  }
  -- MECHANICS > SAFARI ZONE (Gen 1 only: Gold/Silver/Crystal have none).
  local MOVED_OTHER_SAFARI = {
    infinite_safari = true, unlimited_safari_balls = true, safari_no_run = true,
  }
  local PAGE_SKIP = { other_settings = {} }
  for key in pairs(MOVED_OTHER_BATTLE) do PAGE_SKIP.other_settings[key] = true end
  for key in pairs(MOVED_OTHER_OVERWORLD) do PAGE_SKIP.other_settings[key] = true end
  for key in pairs(MOVED_OTHER_SAFARI) do PAGE_SKIP.other_settings[key] = true end

  local function pick(component, keys)
    local out = {}
    for _, row in ipairs(component and component.schema or {}) do
      if keys == nil or keys[row.key] then out[#out + 1] = row end
    end
    return out
  end

  local function addPageExtras(body, pageId)
    -- OTHER SETTINGS > HIGHLANDER DEX: the Highlander Dex's ON/OFF.
    if pageId == "other_settings" and settings.byId.highlander_pokedex then
      local dex = settings.byId.highlander_pokedex
      body[#body + 1] = {
        id = "other_settings.ph_pokedex",
        label = "HIGHLANDER DEX",
        value = function() return settings:isEnabled(dex) and "ON" or "OFF" end,
        step = function(activeGame)
          local changed = settings:setEnabled(activeGame, dex, not settings:isEnabled(dex))
          settings:persist(activeGame)
          return changed
        end,
      }
    end
    -- OTHER SETTINGS > HIGHLANDER BAG: OFF, a default pocket, or LAST
    -- OPENED (the default). OFF is the component's own switch.
    if pageId == "other_settings" and settings.byId.highlander_bag then
      local bag = settings.byId.highlander_bag
      local CHOICES = {
        { "OFF", "off" }, { "DEFAULT ITEMS", "items" }, { "DEFAULT TMs/HMs", "tmhm" },
        { "DEFAULT BALLS", "balls" }, { "DEFAULT KeyItems", "key" },
        { "LAST OPENED", "last" },
      }
      local function current()
        if not settings:isEnabled(bag) then return 1 end
        local value = settings:get(bag, "open_on") or "last"
        for i, choice in ipairs(CHOICES) do
          if choice[2] == value then return i end
        end
        return #CHOICES
      end
      body[#body + 1] = {
        id = "other_settings.ph_bag",
        label = "HIGHLANDER BAG",
        value = function() return CHOICES[current()][1] end,
        step = function(activeGame, direction)
          local index = (current() - 1 + (direction or 1)) % #CHOICES + 1
          local value = CHOICES[index][2]
          if value == "off" then
            settings:setEnabled(activeGame, bag, false)
          else
            settings:setEnabled(activeGame, bag, true)
            settings:set(activeGame, bag, "open_on", value)
          end
          settings:persist(activeGame)
          return true
        end,
      }
    end
    -- OTHER SETTINGS > HIGHLANDER PC: the Highlander PC's ON/OFF.
    if pageId == "other_settings" and settings.byId.highlander_pc then
      local pc = settings.byId.highlander_pc
      body[#body + 1] = {
        id = "other_settings.ph_pc",
        label = "HIGHLANDER PC",
        value = function() return settings:isEnabled(pc) and "ON" or "OFF" end,
        step = function(activeGame)
          local changed = settings:setEnabled(activeGame, pc, not settings:isEnabled(pc))
          settings:persist(activeGame)
          return changed
        end,
      }
    end
    -- OTHER SETTINGS > HIGHLANDER PARTY: the Highlander Party's ON/OFF.
    if pageId == "other_settings" and settings.byId.highlander_party then
      local party = settings.byId.highlander_party
      body[#body + 1] = {
        id = "other_settings.ph_party",
        label = "HIGHLANDER PARTY",
        value = function() return settings:isEnabled(party) and "ON" or "OFF" end,
        step = function(activeGame)
          local changed = settings:setEnabled(activeGame, party, not settings:isEnabled(party))
          settings:persist(activeGame)
          return changed
        end,
      }
    end
    if pageId == "battle_screen" then
      local colors = settings.byId.move_colors
      if colors then
        addRows(body, colors, pick(colors))
      end
      local other = settings.byId.other_settings
      if other then addRows(body, other, pick(other, MOVED_OTHER_BATTLE)) end
    end
  end

  local openHub
  local function openComponent(game, component)
    -- The page's own ON/OFF row (only for parts that have a switch).
    local function flipSwitch(activeGame)
      local nowOn = settings:isEnabled(component)
      local changed = settings:setEnabled(activeGame, component, not nowOn)
      settings:persist(activeGame)
      return changed
    end
    local enabledRow = {
      id = component.key .. ".enabled",
      label = component.enabledLabel or "ENABLED",
      value = function() return settings:isEnabled(component) and "ON" or "OFF" end,
      step = flipSwitch,
    }
    local body = {}
    addRows(body, component, component.schema, PAGE_SKIP[component.id])
    addPageExtras(body, component.id)
    if component.id == "highlander_start" then
      local exports = component.exports or {}
      body[#body + 1] = {
        id = "hstart.custom_icons", label = "CUSTOM ICONS",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          return exports.openCustomIcons and exports.openCustomIcons(activeGame)
        end,
      }
      -- HIDE ITEMS and CUSTOM RENAME: a page of rows the component builds.
      local function rowsPage(name, build)
        return function(activeGame)
          if type(exports[build]) ~= "function" then return false end
          local rows = exports[build](activeGame)
          local page = OptionsMenu.new(activeGame)
          page.rows, page.view = rows, rows
          page.index, page.scroll, page.sub = 1, 0, true
          page.highlanderComponent = name
          trimBack(page)
          activeGame.stack:push(page)
          return true
        end
      end
      body[#body + 1] = {
        id = "hstart.hide_items", label = "HIDE ITEMS",
        value = function() return "OPEN" end,
        activate = rowsPage("hstart_hide_items", "hideRows"),
      }
      local openRename = rowsPage("hstart_custom_rename", "renameRows")
      body[#body + 1] = {
        id = "hstart.custom_rename", label = "CUSTOM RENAME",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          if not openRename(activeGame) then return false end
          -- the names are drawn exactly as typed (Decapitalize skips them)
          local page = activeGame.stack:top()
          local draw = page.draw
          page.draw = function(self, ...)
            local Font = require("src.render.Font")
            Font._decapKeep = exports.keepNames and exports.keepNames(self.game) or {}
            Font._decapKeepOn = true
            local ok, err = pcall(draw, self, ...)
            Font._decapKeepOn = nil
            if not ok then error(err, 0) end
          end
          return true
        end,
      }
      body[#body + 1] = {
        id = "hstart.sort_menu", label = "SORT MENU",
        value = function() return "OPEN" end,
        activate = function(activeGame)
          return exports.openSort and exports.openSort(activeGame)
        end,
      }
    end
    -- Sub-menus are alphabetical unless the component declares its own
    -- row order (Full Control's buttons, PokeBall Shortcuts' directions).
    local rank = {}
    for i, key in ipairs(component.rowOrder or {}) do rank[key] = i end
    -- Other Settings and Battle Screen: every HIGHLANDER row goes first
    -- (alphabetical among themselves), ahead of the alphabetical rest.
    local pinHighlander = component.id == "other_settings"
      or component.id == "battle_screen"
    local function rowRank(row)
      if pinHighlander and tostring(row.label or ""):upper():find("^HIGHLANDER ") then
        return -1
      end
      local key = tostring(row.id or ""):match("^[^.]+%.(.+)$")
      return key and rank[key] or math.huge
    end
    table.sort(body, function(a, b)
      local ra, rb = rowRank(a), rowRank(b)
      if ra ~= rb then return ra < rb end
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    local rows = {}
    if not component.alwaysOn then rows[1] = enabledRow end
    for _, row in ipairs(body) do rows[#rows + 1] = row end
    if component.key == "steel" then
      rows[#rows + 1] = {
        id = "steel.copyright",
        label = "Copyright (c) zyrancz",
        value = function() return "" end,
      }
    end
    if component.key == "crystal" then
      -- Every game but Crystal: the note that the art comes from Crystal,
      -- right under the Gen 1 NPC rows (the rows above it need nothing from
      -- Crystal), with whether Crystal was found as its value.
      local exports = component.exports or {}
      local okV, GV = pcall(require, "src.core.GameVersion")
      local onCrystal = okV and type(GV.get) == "function" and GV.get() == "crystal"
      if not onCrystal then
        local NPC_ROWS = { ["crystal.crystalFrontNPCs"] = true,
          ["crystal.crystalOverworldNPCs"] = true }
        local at = 1
        while rows[at] and NPC_ROWS[rows[at].id] do at = at + 1 end
        table.insert(rows, at, {
          id = "crystal.needs_crystal",
          label = "Pokémon Crystal needs to be installed to have the Crystal Sprites w/ or w/o animation.",
          value = function()
            if type(exports.crystalAvailable) ~= "function" then return "" end
            local okA, found = pcall(exports.crystalAvailable)
            if okA and found then return "INSTALLED" end
            return "NOT INSTALLED"
          end,
        })
      end
      rows[#rows + 1] = {
        id = "crystal.copyright",
        label = "Copyright (c) TRW",
        value = function() return "" end,
      }
    end
    local page = OptionsMenu.new(game)
    page.rows, page.view = rows, rows
    page.index, page.scroll, page.sub = 1, 0, true
    page.highlanderComponent = component.id
    if component.key == "rumble" then
      -- PRESS SELECT TO TEST: SELECT on that row plays the chosen hit.
      local baseUpdate = page.update
      page.update = function(self, dt, ...)
        local input = self.game and self.game.input
        local row = self.rows and self.rows[self.index]
        if input and row and row.id == "rumble.test" and input:wasPressed("select") then
          local exports = component.exports or {}
          if type(exports.test) == "function" then pcall(exports.test) end
          return
        end
        return baseUpdate(self, dt, ...)
      end
    end
    trimBack(page)
    game.stack:push(page)
    return true
  end

  -- A page made only of rows from other components (OVERWORLD SCREEN).
  local function openRowsPage(game, pageId, sources)
    local body = {}
    for _, src in ipairs(sources) do
      local component = settings.byId[src.id]
      if component then addRows(body, component, pick(component, src.keys)) end
    end
    table.sort(body, function(a, b)
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    local page = OptionsMenu.new(game)
    page.rows, page.view = body, body
    page.index, page.scroll, page.sub = 1, 0, true
    page.highlanderComponent = pageId
    trimBack(page)
    game.stack:push(page)
    return true
  end

  local function otherSettingsPart()
    for _, component in ipairs(components) do
      if component.id == "other_settings" then return component end
    end
  end

  local GEN1_FEATURE_ROWS = {
    { key = "gen1_exclusive", label = "GET EXCLUSIVE PKMN FROM OTHER GEN1 GAMES" },
    { key = "gen1_starters", label = "GET ALL STARTERS" },
    { key = "gen1_fossil", label = "GET OTHER FOSSIL" },
    { key = "gen1_fighting", label = "GET OTHER FIGHTER" },
    { key = "gen1_eevee", label = "GET MORE EEVEES" },
    { key = "gen1_linkc", label = "TRADE W/ LINK C." },
    { key = "gen1_mystery", label = "GET ???" },
    { key = "gen1_legendary_persist", label = "INFINITE TRIES FOR LIMITED ENCOUNTERS" },
  }

  local GEN2_FEATURE_ROWS = {
    { key = "gen2_exclusive", label = "GET EXCLUSIVE PKMN FROM OTHER GEN2 GAMES" },
    { key = "gen2_starters", label = "GET ALL STARTERS" },
    { key = "gen2_fossil", label = "KIM FOSSIL TRADES" },
    { key = "gen2_celebi", label = "GS BALL / CELEBI" },
    { key = "gen2_linkc", label = "TRADE W/ LINK C." },
    { key = "gen2_kanto_starters", label = "GET OG STARTERS" },
    { key = "gen2_birds", label = "GET LEGEND. BIRDS" },
    { key = "gen2_mew", label = "GET MEW/MEWTWO" },
    { key = "gen2_roaming_hunter", label = "ROAMING HUNTER" },
    { key = "gen2_legendary_persist", label = "INFINITE TRIES FOR LIMITED ENCOUNTERS" },
  }

  local function migrateGen1Features(game, other)
    if not other then return end
    if settings:get(other, "gen1_features_migrated") == true then return end
    local master = settings:get(other, "gen1_all_pkmn") == true
    for _, row in ipairs(GEN1_FEATURE_ROWS) do
      settings:set(game, other, row.key, master)
    end
    settings:set(game, other, "gen1_features_migrated", true)
    settings:persist(game)
  end

  local function migrateGen2Features(game, other)
    if not other then return end
    if settings:get(other, "gen2_features_migrated") == true then return end
    local master = settings:get(other, "gen2_all_pkmn") == true
    for _, row in ipairs(GEN2_FEATURE_ROWS) do
      settings:set(game, other, row.key, master)
    end
    settings:set(game, other, "gen2_features_migrated", true)
    settings:persist(game)
  end

  local function openFeatureMenu(game, title, rows)
    local other = otherSettingsPart()
    if not other then return false end
    migrateGen1Features(game, other)
    migrateGen2Features(game, other)
    local pageRows = {}
    for _, source in ipairs(rows) do
      local row = source
      pageRows[#pageRows + 1] = {
        id = "other_settings." .. row.key,
        label = row.label,
        value = function()
          return settings:get(other, row.key) == true and "ON" or "OFF"
        end,
        step = function(activeGame)
          settings:set(activeGame, other, row.key,
            settings:get(other, row.key) ~= true)
          settings:persist(activeGame)
          return true
        end,
      }
    end
    -- Alphabetical, except GET ??? which always goes last (before CANCEL):
    -- "?" sorts ahead of every letter and put it on top.
    local LAST = { gen1_mystery = true }
    table.sort(pageRows, function(a, b)
      local la = LAST[tostring(a.id or ""):match("^other_settings%.(.+)$") or ""] and 1 or 0
      local lb = LAST[tostring(b.id or ""):match("^other_settings%.(.+)$") or ""] and 1 or 0
      if la ~= lb then return la < lb end
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    local page = OptionsMenu.new(game)
    page.rows, page.view = pageRows, pageRows
    page.index, page.scroll, page.sub = 1, 0, true
    page.highlanderComponent = "get_all_pkmn"
    trimBack(page)
    game.stack:push(page)
    return true
  end

  -- GAME CORNER: the coin clerk's 2X COINS FOR CASH (moved here from Other Settings)
  -- and the slot machine options. All four are stored on the Other Settings
  -- component, as 2X COINS always was.
  local function openGameCornerMenu(game)
    local other = otherSettingsPart()
    if not other then return false end
    local ODDS = { "normal", "generous", "lucky" }
    local ODDS_LABEL = { normal = "NORMAL", generous = "GENEROUS", lucky = "LUCKY" }
    local function toggleRow(key, label)
      return {
        id = "other_settings." .. key,
        label = label,
        value = function()
          return settings:get(other, key) == true and "ON" or "OFF"
        end,
        step = function(activeGame)
          settings:set(activeGame, other, key, settings:get(other, key) ~= true)
          settings:persist(activeGame)
          return true
        end,
      }
    end
    local pageRows = {
      toggleRow("coins_2x", "2X COINS FOR CASH"),
      toggleRow("slot_all_lucky", "ALL LUCKY SLOT M."),
      toggleRow("slot_bigger_payouts", "BIGGER PAYOUTS"),
      {
        id = "other_settings.slot_odds",
        label = "SLOT ODDS",
        value = function()
          return ODDS_LABEL[settings:get(other, "slot_odds")] or "NORMAL"
        end,
        step = function(activeGame, direction)
          local current = settings:get(other, "slot_odds") or "normal"
          local index = 1
          for i, v in ipairs(ODDS) do
            if v == current then index = i break end
          end
          local delta = (tonumber(direction) or 1) < 0 and -1 or 1
          index = (index - 1 + delta) % #ODDS + 1
          settings:set(activeGame, other, "slot_odds", ODDS[index])
          settings:persist(activeGame)
          return true
        end,
      },
    }
    table.sort(pageRows, function(a, b)
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    local page = OptionsMenu.new(game)
    page.rows, page.view = pageRows, pageRows
    page.index, page.scroll, page.sub = 1, 0, true
    page.highlanderComponent = "game_corner"
    trimBack(page)
    game.stack:push(page)
    return true
  end

  -- JUKEBOX: ALL SONGS on top (ON / OFF / SOME: one press turns them all
  -- Off, or all On when none is), then this game's songs A-Z: the playlist.
  -- The JUKEBOX BUTTON is in FULL CONTROL.
  local function openJukeboxMenu(game)
    local component = settings.byId.jukebox
    local JB = component and component.exports
    if not (JB and type(JB.list) == "function") then return false end
    local pageRows = {
      {
        id = "jukebox.all",
        label = "ALL SONGS",
        value = function() return JB.allLabel() end,
        step = function(activeGame)
          activeGame = activeGame or game
          JB.toggleAll(activeGame)
          settings:persist(activeGame)
          return true
        end,
      },
    }
    for _, entry in ipairs(JB.list()) do
      local song = entry
      pageRows[#pageRows + 1] = {
        id = "jukebox." .. song.name,
        label = song.label,
        value = function() return JB.isOn(song.name) and "ON" or "OFF" end,
        step = function(activeGame)
          activeGame = activeGame or game
          JB.toggle(activeGame, song.name)
          settings:persist(activeGame)
          return true
        end,
      }
    end
    local page = OptionsMenu.new(game)
    page.rows, page.view = pageRows, pageRows
    page.index, page.scroll, page.sub = 1, 0, true
    page.highlanderComponent = "jukebox"
    trimBack(page)
    game.stack:push(page)
    return true
  end

  local function openPokeIconsMenu(game)
    local rows = {
      { key = "party", label = "ICONS FOR PARTY" },
      { key = "pc", label = "ICONS FOR PC" },
    }
    local pageRows = {}
    for _, source in ipairs(rows) do
      local row = source
      pageRows[#pageRows + 1] = {
        id = "poke_icons." .. row.key,
        label = row.label,
        value = function()
          return settings:get("poke_icons", row.key) == "followers"
            and "WILD FOLLOWERS" or "ORIGINAL"
        end,
        step = function(activeGame)
          local nextv = settings:get("poke_icons", row.key) == "followers"
            and "original" or "followers"
          settings:set(activeGame, "poke_icons", row.key, nextv)
          settings:persist(activeGame)
          return true
        end,
      }
    end
    table.sort(pageRows, function(a, b)
      return tostring(a.label or "") < tostring(b.label or "")
    end)
    pageRows[#pageRows + 1] = {
      id = "poke_icons.copyright",
      label = "Copyright (c) YoDrehDenSwagAuf",
      value = function() return "" end,
    }
    local page = OptionsMenu.new(game)
    page.rows, page.view = pageRows, pageRows
    page.index, page.scroll, page.sub = 1, 0, true
    page.highlanderComponent = "poke_icons"
    trimBack(page)
    game.stack:push(page)
    return true
  end

  -- The main menu: three categories, each a list of pages in a fixed order.
  -- Labels written in mixed case ("Start Menu", "PokéMoves") are drawn as
  -- written: Decapitalize only re-cases runs of capitals.
  local CATEGORIES = {
    { id = "cat_mechanics", label = "MECHANICS", entries = {
      "battle_screen", "overworld", "pokemoves", "shortcuts",
      "game_corner", "safari_zone", "steel_typing",
    } },
    { id = "cat_system", label = "SYSTEM", entries = {
      "highlander_start", "other_settings",
      "full_control", "rumble", "get_all",
    } },
    { id = "cat_cosmetics", label = "COSMETICS", entries = {
      "jukebox", "custom_borders", "crystal_animated_sprites_with_shiny_visuals",
      "poke_icons",
    } },
  }
  -- Names in the menu, where they differ from the component's own.
  local ENTRY_LABEL = {
    highlander_start = "Start Menu",
    pokemoves = "PokéMoves",
    rumble = "CONT. RUMBLE",
  }

  local function entryItem(id)
    if id == "overworld" then
      return { id = "overworld_menu", label = "OVERWORLD SCREEN", action = "overworld" }
    elseif id == "game_corner" then
      return { id = "game_corner_menu", label = "GAME CORNER", action = "game_corner" }
    elseif id == "safari_zone" then
      local generation = 1
      pcall(function()
        local GV = require("src.core.GameVersion")
        if type(GV.generation) == "function" then generation = GV.generation() end
      end)
      if generation == 2 then return nil end
      return { id = "safari_zone_menu", label = "SAFARI ZONE", action = "safari_zone" }
    elseif id == "poke_icons" then
      return { id = "poke_icons_menu", label = "PokéIcons", action = "poke_icons" }
    elseif id == "jukebox" then
      if not settings.byId.jukebox then return nil end
      return { id = "jukebox_menu", label = "JUKEBOX", action = "jukebox" }
    elseif id == "get_all" then
      -- Only the running generation's page: Gen 1 carts get the Gen 1 one.
      local generation = 1
      pcall(function()
        local GV = require("src.core.GameVersion")
        if type(GV.generation) == "function" then generation = GV.generation() end
      end)
      if generation == 2 then
        return { id = "gen2_all_menu", label = "GET ALL POKéMON", action = "gen2_all" }
      end
      return { id = "gen1_all_menu", label = "GET ALL POKéMON", action = "gen1_all" }
    end
    local component = settings.byId[id]
    if not component or component.hubHidden then return nil end
    return {
      id = component.id,
      label = ENTRY_LABEL[id] or component.short,
      fullLabel = component.fullLabel,
      component = component,
      openOnly = true,
    }
  end

  local function marqueeLabel(full, elapsed, maxW)
    full = tostring(full or "")
    if full == "" or Font.width(full) <= maxW then return full end
    local loop = full .. "   "
    local loopW = math.max(1, Font.width(loop))
    local speed, wait = 22, 0.8
    local t = elapsed % (wait + loopW / speed)
    local ox = t > wait and (t - wait) * speed or 0
    local acc, start = 0, 1
    while start <= #loop do
      local w = Font.width(loop:sub(start, start))
      if acc + w > ox then break end
      acc = acc + w
      start = start + 1
    end
    local out, used, i, n = "", 0, start, #loop
    while used < maxW do
      local ch = loop:sub(((i - 1) % n) + 1, ((i - 1) % n) + 1)
      local w = Font.width(ch)
      if out ~= "" and used + w > maxW then break end
      out, used, i = out .. ch, used + w, i + 1
      if i > start + n then break end
    end
    return out
  end

  local openCategory

  -- One list screen (the main menu or a category), sharing the choose and
  -- update behaviour every hub list has always had.
  local function openList(game, title, buildItems)
    local menu
    -- Rebuild the rows, keeping the cursor on `keepId` (or where it was).
    local function refresh(keepId)
      if not menu then return end
      local before = menu.index or 1
      local rows = buildItems()
      menu.items = rows
      for i, row in ipairs(rows) do
        if keepId and row.id == keepId then menu.index = i return end
      end
      if before > #rows then before = #rows end
      if before < 1 then before = 1 end
      menu.index = before
    end
    menu = ListMenu.new(game, title, {}, {
      wrap = true,
      keyRepeat = true,
      onChoose = function(item, active)
        if not item then return end
        if item.cancel then
          active:close()
        elseif item.category then
          openCategory(game, item.category)
        elseif item.action == "poke_icons" then
          openPokeIconsMenu(game)
        elseif item.action == "overworld" then
          openRowsPage(game, "overworld_screen", {
            { id = "other_settings", keys = MOVED_OTHER_OVERWORLD },
          })
        elseif item.action == "game_corner" then
          openGameCornerMenu(game)
        elseif item.action == "safari_zone" then
          openRowsPage(game, "safari_zone", {
            { id = "other_settings", keys = MOVED_OTHER_SAFARI },
          })
        elseif item.action == "jukebox" then
          openJukeboxMenu(game)
        elseif item.action == "gen1_all" then
          openFeatureMenu(game, "GEN1 GET ALL PKMN", GEN1_FEATURE_ROWS)
        elseif item.action == "gen2_all" then
          openFeatureMenu(game, "GEN2 GET ALL PKMN", GEN2_FEATURE_ROWS)
        elseif item.component then
          openComponent(game, item.component)
        end
      end,
    })
    refresh()
    local listUpdate = menu.update
    menu.update = function(self, dt)
      -- Long names (fullLabel) scroll sideways in a 128 px slot.
      self._hubClock = (self._hubClock or 0) + (tonumber(dt) or 0)
      for _, row in ipairs(self.items or {}) do
        if row.fullLabel then row.label = marqueeLabel(row.fullLabel, self._hubClock, 128) end
      end
      -- Left/Right on a row that is a part's ON/OFF flips it in place.
      local row = self.items and self.items[self.index]
      local input = self.game and self.game.input
      local sideways = input and (input:wasPressed("left") or input:wasPressed("right"))
      if sideways and row and row.component and not row.openOnly then
        local part = row.component
        settings:setEnabled(self.game, part, not settings:isEnabled(part))
        settings:persist(self.game)
        refresh(row.id)
        return
      end
      return listUpdate(self, dt)
    end
    menu.screenId = mod.id .. ":settings"
    game.stack:push(menu)
    return true
  end

  -- A category: its pages in their set order, no BACK row (B leaves).
  openCategory = function(game, category)
    return openList(game, category.label, function()
      local items = {}
      for _, id in ipairs(category.entries) do
        local item = entryItem(id)
        if item then items[#items + 1] = item end
      end
      return items
    end)
  end

  openHub = function(game)
    return openList(game, "ProjectHighlander", function()
      local items = {}
      for _, category in ipairs(CATEGORIES) do
        items[#items + 1] = { id = category.id, label = category.label, category = category }
      end
      -- no BACK row: B leaves, like every sub-menu
      return items
    end)
  end

  -- START > HIDE ITEMS can add a mod's Options-menu row (one that opens
  -- something, Project Highlander's own included) to the Start Menu. The
  -- outermost link of the chain sees every row; the ones that aren't the
  -- game's own are remembered in the start component's "option_rows".
  mod.hooks:wrap("ui.options.rows", function(next, game, rows)
    local native = {}
    for _, r in ipairs(type(rows) == "table" and rows or {}) do native[r] = true end
    local out = next(game, rows)
    local start = settings.byId.highlander_start
    if type(out) ~= "table" or not start or not game then return out end
    local seen = {}
    for _, r in ipairs(out) do
      if type(r) == "table" and not native[r] and type(r.activate) == "function" then
        local label = tostring(r.label or r.id or "?")
        seen[#seen + 1] = { key = "opt:" .. tostring(r.id or label:upper()), label = label }
      end
    end
    local before = settings:get(start, "option_rows")
    local same = type(before) == "table" and #before == #seen
    if same then
      for i, r in ipairs(seen) do
        local b = before[i]
        if type(b) ~= "table" or b.key ~= r.key or b.label ~= r.label then same = false break end
      end
    end
    if not same then
      pcall(settings.set, settings, game, start, "option_rows", seen, true)
      settings:persist(game)
    end
    return out
  end, 100000)

  -- PROJECTHIGHLANDER in the game's Options menu, just above MODS.
  local optionsEntry = {
    id = "highlander_settings",
    label = "PROJECTHIGHLANDER",
    value = function() return "OPEN" end,
    activate = openHub,
    step = openHub,
  }
  mod.hooks:wrap("ui.options.rows", function(nextFn, game, rows)
    local list = nextFn(game, rows)
    if type(list) ~= "table" then return list end
    local insert = mod.ui and mod.ui.insertBefore
    if type(insert) == "function" then return insert(list, "MODS", optionsEntry) end
    list[#list + 1] = optionsEntry
    return list
  end)

  return { open = openHub, openComponent = openComponent }
end
