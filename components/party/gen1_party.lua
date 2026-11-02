-- Highlander Party, Gen 1 roster. The game's own PartyMenu keeps every
-- behaviour (items, TMs, stones, battle switches, field moves, Softboiled);
-- this only changes how it looks and adds SELECT quick-swap:
--   * 24 px per Pokémon, no bottom text box
--   * an XP bar under the HP bar
--   * the A menu as a pop-up in the middle of the screen
return function(mod, C)
  local Font = require("src.render.Font")
  local HudTiles = require("src.render.HudTiles")
  local LevelDisplay = require("src.ui.LevelDisplay")
  local PaletteFX = require("src.render.PaletteFX")
  local Status = require("src.battle.Status")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local Sound = require("src.core.Sound")
  local G = love.graphics

  local unpackValues = table.unpack or unpack
  local function pack(...) return { n = select("#", ...), ... } end

  local PITCH = 24
  local TOP = 2 -- a little room above the first Pokémon
  local function entryY(i) return TOP + (i - 1) * PITCH end

  local function partyOf(menu)
    return menu.party or (menu.game.save and menu.game.save.party) or {}
  end

  local function expFraction(game, mon)
    local data = game.data
    local def = data.pokemon[mon.species]
    if not def or (mon.level or 1) >= 100 then return 1 end
    local Growth = require("src.pokemon.Growth")
    local okA, from = pcall(Growth.expForLevel, def.growthRate, mon.level, data.growth_rates)
    local okB, to = pcall(Growth.expForLevel, def.growthRate, mon.level + 1, data.growth_rates)
    if not (okA and okB and from and to) or to <= from then return 0 end
    return math.max(0, math.min(1, ((mon.exp or 0) - from) / (to - from)))
  end

  local function sgbPalettes(self, game)
    local P = PaletteFX
    local base = P.pal(game.data, "GREENBAR")
    if not base then return nil end
    local zones = { P.whole(base) }
    local mew = P.pal(game.data, "MEWMON")
    if mew then zones[#zones + 1] = P.zone(mew, 1, 0, 2, 17) end
    if not (self.tmhm or self.evoStone) then
      for i, mon in ipairs(partyOf(self)) do
        local hp = mon.hp
        if self.heal and self.heal.mon == mon then hp = self.heal.from end
        local bar = P.pal(game.data, P.barPalName(hp, mon.stats.hp))
        local y = entryY(i)
        local r1, r2 = math.floor((y + 10) / 8), math.floor((y + 13) / 8)
        if bar then zones[#zones + 1] = P.zone(bar, 5, r1, 11, r2) end
      end
    end
    return zones
  end

  local function drawXp(game, mon, y0)
    local y = y0 + 13
    -- "XP:" label where the HP tile sits, then the bar under the HP bar
    -- (fill x 48-95, the same pixels the HP fill uses).
    G.setColor(1, 1, 1, 1)
    C.drawXpLabelGen1(32, y)
    local px = math.floor(expFraction(game, mon) * 48 + 0.0001)
    C.drawPixelBar(47, y, 48, px, C.XP_BLUE)
    if px > 0 then PaletteFX.markTrueColor(48, y + 3, px, 2) end
  end

  local function drawPopup(self)
    local labels = {}
    for i, entry in ipairs(self.subItems or {}) do labels[i] = entry.label end
    local index = self.subIndex or 1
    self.hlPopupScroll = C.popupScroll(#labels, index, self.hlPopupScroll)
    local L = C.popupLayout(labels, self.hlPopupScroll)
    Font.drawBox(L.tx, L.ty, L.tw, L.th)
    G.setColor(0, 0, 0, 1)
    for i = L.first, L.last do
      Font.draw(labels[i], L.labelX, C.popupRowY(L, i))
    end
    Font.drawCode(Theme.cursor, L.cursorX, C.popupRowY(L, index))
    C.popupArrows(L)
    G.setColor(0, 0, 0, 1)
  end

  local function draw(self)
    G.setColor(1, 1, 1, 1)
    G.rectangle("fill", 0, 0, 160, 144)
    G.setColor(0, 0, 0, 1)
    local game = self.game
    local party = partyOf(self)
    if #party == 0 then Font.draw(Strings("No POKéMON!"), 16, 64) end
    local barZoned = PaletteFX.shader() ~= nil
      and PaletteFX.pal(game.data, "GREENBAR") ~= nil
    local PartyMenu = require("src.ui.PartyMenu")
    for i, mon in ipairs(party) do
      if not (self.swapAnim and self.swapAnim.blank[i]) then
        local def = game.data.pokemon[mon.species]
        local y = entryY(i)
        G.setColor(1, 1, 1, 1)
        if not C.drawFollowerIcon(game, mon, 8, y, i == self.index, self.blink or 0) then
          local icons = mod.highlander and mod.highlander.pokeIcons
          if not (icons and icons.drawOriginal
              and icons.drawOriginal(game, mon, 8, y, i == self.index, self.blink or 0)) then
            PartyMenu.drawIcon(game, mon, 8, y, i == self.index, self.blink or 0)
          end
        end
        G.setColor(0, 0, 0, 1)
        Font.draw(mon.nickname or (def and def.name) or mon.species, 24, y)
        if LevelDisplay.visible(mon, "party", game) then
          if mon.level < 100 then
            HudTiles.tile(0x6E, 104, y)
            Font.draw(tostring(mon.level), 112, y)
          else
            Font.draw(tostring(mon.level), 104, y)
          end
        end
        if self.tmhm or self.evoStone then
          local can = false
          if self.tmhm then
            for _, m in ipairs(def and def.tmhm or {}) do
              if m == self.tmhm.move then can = true break end
            end
          else
            for _, evo in ipairs(def and def.evolutions or {}) do
              if evo.method == "ITEM" and evo.item == self.evoStone then can = true break end
            end
          end
          Font.draw(Strings(can and "ABLE" or "NOT ABLE"), 96, y + 8)
        else
          if mon.hp <= 0 then
            Font.draw(Strings("FNT"), 136, y)
          elseif mon.status then
            Font.draw(Status.hudLabelFor(game.data.statuses, mon.status), 136, y)
          end
          local shown, shownPx = mon, nil
          if self.heal and self.heal.mon == mon then
            shown = { hp = math.floor(self.heal.shown), stats = mon.stats }
            shownPx = self.heal.px
          end
          G.setColor(1, 1, 1, 1)
          HudTiles.drawHPBar(game.data, 4, (y + 8) / 8, shown, nil, barZoned, nil, shownPx)
          G.setColor(0, 0, 0, 1)
          Font.draw(("%3d/%3d"):format(shown.hp, mon.stats.hp), 104, y + 8)
          local ok, err = pcall(drawXp, game, mon, y)
          if not ok and not mod._xpWarned then
            mod._xpWarned = true
            mod.log:warn("party XP bar skipped: %s", tostring(err))
          end
        end
        G.setColor(0, 0, 0, 1)
        local cursorY = y + 8
        if i == self.index and not self.cursorsErased then
          Font.drawCode((self.chosenHollow or self.submenu) and Theme.cursorHollow
            or Theme.cursor, 0, cursorY)
        end
        if (i == self.swapFrom or i == self.softboiledFrom) and i ~= self.index
            and not self.cursorsErased then
          Font.drawCode(Theme.cursorHollow, 0, cursorY)
        end
      end
    end
    -- A medicine's "recovered" line still needs somewhere to show.
    if self.message then
      Font.drawBox(0, 12, 20, 6)
      G.setColor(0, 0, 0, 1)
      local ly = 112
      for line in (tostring(self.message) .. "\n"):gmatch("([^\n]*)\n") do
        Font.draw(line, 8, ly)
        ly = ly + 16
      end
    end
    if self.submenu and type(self.subItems) == "table" then drawPopup(self) end
    G.setColor(1, 1, 1, 1)
  end

  -- SELECT on the list: pick a Pokémon up, SELECT (or A) again puts it down.
  local function canSwap(menu)
    return not menu.battle and not menu.pickOnly and not menu.tmhm
      and not menu.evoStone and not menu.onSwitch and not menu.forceSwitch
      and not menu.softboiledFrom
      and (not menu.party or menu.party == menu.game.save.party)
  end

  local function quickSwap(menu, input)
    if menu.submenu or menu.heal or menu.swapAnim or not canSwap(menu) then return false end
    if menu.swapFrom and input:wasPressed("b") then
      menu.swapFrom = nil
      pcall(Sound.play, menu.game.data, "Press_AB")
      return true
    end
    if not input:wasPressed("select") then return false end
    local party = partyOf(menu)
    if menu.swapFrom then
      local from, to = menu.swapFrom, menu.index
      menu.swapFrom = nil
      if party[from] and party[to] and from ~= to then
        party[from], party[to] = party[to], party[from]
      end
      menu.swapAnim = { blank = { [from] = true }, to = to, phase = 1, frames = 0 }
      local ok, src = pcall(Sound.play, menu.game.data, "Swap")
      menu.swapAnim.src = ok and src or nil
    elseif #party > 1 and party[menu.index] then
      menu.swapFrom = menu.index
      pcall(Sound.play, menu.game.data, "Press_AB")
    end
    return true
  end

  local function wrapUpdate(nativeUpdate)
    return function(menu, dt, ...)
      local input = menu.game and menu.game.input
      if input and input.wasPressed and quickSwap(menu, input) then return end
      -- The A menu loops: Up on the first row goes to the last, and back.
      if input and input.wasPressed and menu.submenu and type(menu.subItems) == "table" then
        local n = #menu.subItems
        if n > 1 and input:wasPressed("up") and (menu.subIndex or 1) <= 1 then
          menu.subIndex = n
          return
        elseif n > 1 and input:wasPressed("down") and (menu.subIndex or 1) >= n then
          menu.subIndex = 1
          return
        end
      end
      if not menu.submenu then menu.hlPopupScroll = 0 end
      local out = pack(nativeUpdate(menu, dt, ...))
      if menu.submenu and not menu.battle then
        local index = C.orderActions(menu.subItems, menu.subIndex)
        if index then menu.subIndex = index end
      end
      return unpackValues(out, 1, out.n)
    end
  end

  local function decorate(menu)
    if type(menu) ~= "table" then return menu end
    local nativeUpdate = menu.update
    menu.draw = draw
    menu.update = wrapUpdate(nativeUpdate)
    menu.sgbPalettes = sgbPalettes
    menu.highlanderParty = true
    return menu
  end

  return { decorate = decorate, entryY = entryY }
end
