-- Highlander PC: the Pokémon Storage screen for Red/Blue/Yellow/Green and
-- Gold/Silver/Crystal, drawn at the Game Boy's own 160x144 (Custom Borders
-- frames it like any other full screen).
--
--   rows 0-16     header: PARTY (and GRAB) badge | button help
--   rows 17-143   the party column (6 cells, never scrolls), a 4 px gap for
--                 the flashing up/down arrows, then on the right:
--     rows 17-37    the Pokemon under the cursor: name, LvXX, type tag(s)
--     rows 38-143   the big box: 5 across, 5 rows on screen, scrolling
--                   (48 rows in Gen 1, 56 in Gen 2)
--
-- A opens the Pokémon's menu. SELECT turns AUTO-GRAB on/off (off every
-- time the PC opens): with it on, A grabs a Pokémon and drops it (swap, or
-- to the end on an empty slot). In MULTIPLE SELECTIONS, A marks and SELECT
-- drops the group on the slot under the cursor. Hold START and press
-- Left/Right to jump a page (5 rows) up/down. B cancels / leaves.
-- Colours come from the Start Menu's COLOUR (paper, light, dark, ink), even
-- with that menu off.
return function(mod, S, gen2)
  local G = love.graphics
  local Font = require("src.render.Font")
  local MenuRepeat = require("src.ui.MenuRepeat")
  local Sound = require("src.core.Sound")
  local Strings = require("src.core.Strings")

  local W, H = 160, 144
  local ROW_Y = 17        -- top line of the first row
  local PITCH = 21        -- row height, line included (20 px inside)
  local CELL = 25         -- cell width, line included (24 px inside)
  local ROWS, COLS = 6, 5   -- party column: 6 rows
  local BOX_Y = 38          -- top line of the big box's first row
  local BOX_ROWS = 5        -- big box rows on screen
  local PARTY_X = 2       -- party column: lines at x 2 and 27
  local GAP_X = 28        -- arrows: x 28-31
  local GRID_X = 32       -- big box: lines at x 32, 57 ... 157
  local NAME_X = 33        -- info band: name + level from here ...
  local TAGS_X = 126       -- ... type tags on the right (x 126-157)

  ---------------------------------------------------------------- colours
  local FALLBACK = { { 232, 255, 232 }, { 96, 212, 112 }, { 32, 132, 56 }, { 16, 36, 16 } }
  local function palette(game)
    local start = mod.find and mod.find("highlander_start")
    local fn = start and start.exports and start.exports.palette
    if type(fn) == "function" then
      local ok, p = pcall(fn, game)
      if ok and type(p) == "table" and p[4] then return p end
    end
    return FALLBACK
  end

  local function rgb(c, a) G.setColor(c[1] / 255, c[2] / 255, c[3] / 255, a or 1) end
  local function rect(c, x, y, w, h)
    rgb(c)
    G.rectangle("fill", math.floor(x), math.floor(y), math.floor(w), math.floor(h))
  end
  local function now() return love.timer and love.timer.getTime() or 0 end

  ---------------------------------------------------------------- text
  -- Font tiles are dark on transparent: drawn as a mask in any colour. A TTF
  -- translation font is white coverage, so it takes the alpha path.
  local maskShader, alphaShader
  local function inkShader()
    if not G.newShader then return nil end
    if Font.ttfActive and Font.ttfActive() then
      if alphaShader == nil then
        local ok, sh = pcall(G.newShader, [[
          vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 p = Texel(tex, tc);
            return vec4(color.rgb, p.a * color.a);
          }
        ]])
        alphaShader = ok and sh or false
      end
      return alphaShader or nil
    end
    if maskShader == nil then
      local ok, sh = pcall(G.newShader, [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          vec4 p = Texel(tex, tc);
          float m = p.r < 0.5 ? p.a : 0.0;
          return vec4(color.rgb, m * color.a);
        }
      ]])
      maskShader = ok and sh or false
    end
    return maskShader or nil
  end

  local function encode(str)
    local ok, codes = pcall(Font.encode, tostring(str or ""))
    codes = (ok and type(codes) == "table") and codes or {}
    local widths, total = {}, 0
    for i, code in ipairs(codes) do
      local okA, a = pcall(Font.advanceOf, code)
      widths[i] = okA and tonumber(a) or 8
      total = total + widths[i]
    end
    return codes, widths, total
  end

  local function textWidth(str)
    local _, _, total = encode(str)
    return total
  end

  -- Draws text; when it's wider than maxW the letters are pulled 1 px
  -- closer, and anything still too long is cut.
  local function text(str, x, y, c, maxW)
    local codes, widths, total = encode(str)
    if #codes == 0 then return 0 end
    local squeeze = 0
    if maxW and total > maxW and #codes > 1 then
      squeeze = 1
      total = total - (#codes - 1)
    end
    local sh = inkShader()
    G.push("all")
    if sh then G.setShader(sh); rgb(c) else G.setColor(0, 0, 0, 1) end
    local pen = math.floor(x)
    for i, code in ipairs(codes) do
      if maxW and (pen - math.floor(x)) + widths[i] - squeeze > maxW + 1 then break end
      pcall(Font.drawCode, code, pen, math.floor(y))
      pen = pen + widths[i] - squeeze
    end
    G.pop()
    return math.min(total, maxW or total)
  end

  -- Splits a message into at most two lines that fit `maxW`.
  local function wrap(str, maxW)
    local lines = {}
    for part in (tostring(str or "") .. "\n"):gmatch("(.-)\n") do
      local line = ""
      for word in part:gmatch("%S+") do
        local try = line == "" and word or (line .. " " .. word)
        if line ~= "" and textWidth(try) > maxW then
          lines[#lines + 1] = line
          line = word
        else
          line = try
        end
      end
      lines[#lines + 1] = line
    end
    while #lines > 2 do
      lines[2] = lines[2] .. " " .. table.remove(lines, 3)
    end
    return lines
  end

  ---------------------------------------------------------------- pixel fonts
  -- Tiny letters for the header's button help (variable width, 5 tall).
  local TINY = {
    A = { "010", "101", "111", "101", "101" },
    B = { "110", "101", "110", "101", "110" },
    C = { "011", "100", "100", "100", "011" },
    D = { "110", "101", "101", "101", "110" },
    E = { "111", "100", "110", "100", "111" },
    G = { "0111", "1000", "1011", "1001", "0111" },
    J = { "001", "001", "001", "101", "010" },
    K = { "101", "101", "110", "101", "101" },
    L = { "100", "100", "100", "100", "111" },
    M = { "10001", "11011", "10101", "10001", "10001" },
    N = { "1001", "1101", "1011", "1001", "1001" },
    O = { "010", "101", "101", "101", "010" },
    P = { "110", "101", "110", "100", "100" },
    R = { "110", "101", "110", "101", "101" },
    S = { "011", "100", "010", "001", "110" },
    T = { "111", "010", "010", "010", "010" },
    U = { "101", "101", "101", "101", "111" },
    Y = { "101", "101", "010", "010", "010" },
    F = { "111", "100", "110", "100", "100" },
    H = { "101", "101", "111", "101", "101" },
    I = { "1", "1", "1", "1", "1" },
    W = { "10001", "10001", "10101", "11011", "10001" },
    ["?"] = { "110", "001", "010", "000", "010" },
    [":"] = { "0", "1", "0", "1", "0" },
    ["+"] = { "000", "010", "111", "010", "000" },
    ["/"] = { "001", "001", "010", "100", "100" },
  }
  local function pixWidth(set, str)
    local w = 0
    for ch in str:gmatch(".") do
      local g = set[ch]
      w = w + (g and #g[1] or 2) + 1
    end
    return math.max(0, w - 1)
  end

  local function pixText(set, str, x, y, c)
    rgb(c)
    local pen = x
    for ch in str:gmatch(".") do
      local g = set[ch]
      if g then
        for row, bits in ipairs(g) do
          for col = 1, #bits do
            if bits:sub(col, col) == "1" then
              G.rectangle("fill", pen + col - 1, y + row - 1, 1, 1)
            end
          end
        end
        pen = pen + #g[1] + 1
      else
        pen = pen + 3
      end
    end
  end

  ---------------------------------------------------------------- type tags
  -- The header takes turns: the Pokemon's name, then "LvXX" and its type(s)
  -- as small drawn tags (two types: stacked). Tags are 32x8: a light top
  -- edge, the type's colour, a dark bottom edge, white tiny letters with a
  -- grey shadow (right and below).
  local TAG_W, TAG_H = 32, 8
  local TAG_TEXT = { 248, 248, 248 }
  local TAG_SHADOW = { 128, 120, 112 }
  local TAG_EDGE = { 72, 64, 56 }
  local TYPE_TAGS = {
    NORMAL = { "NORMAL", { 168, 168, 120 } },
    FIRE = { "FIRE", { 240, 128, 48 } },
    WATER = { "WATER", { 104, 144, 240 } },
    ELECTRIC = { "ELECTR", { 232, 184, 32 } },
    GRASS = { "GRASS", { 120, 200, 80 } },
    ICE = { "ICE", { 112, 192, 200 } },
    FIGHTING = { "FIGHT", { 192, 48, 40 } },
    POISON = { "POISON", { 160, 64, 160 } },
    GROUND = { "GROUND", { 208, 168, 80 } },
    FLYING = { "FLYING", { 168, 144, 240 } },
    PSYCHIC = { "PSYCHC", { 248, 88, 136 } },
    PSYCHIC_TYPE = { "PSYCHC", { 248, 88, 136 } },
    BUG = { "BUG", { 168, 184, 32 } },
    ROCK = { "ROCK", { 184, 160, 56 } },
    GHOST = { "GHOST", { 112, 88, 152 } },
    DRAGON = { "DRAGON", { 112, 56, 248 } },
    DARK = { "DARK", { 112, 88, 72 } },
    STEEL = { "STEEL", { 152, 152, 176 } },
    FAIRY = { "FAIRY", { 232, 128, 168 } },
    CURSE_TYPE = { "???", { 104, 160, 144 } },
    CURSE = { "???", { 104, 160, 144 } },
  }
  local UNKNOWN_TAG = { 104, 160, 144 }

  local function lighter(c)
    return { math.floor(c[1] + (255 - c[1]) * 0.45), math.floor(c[2] + (255 - c[2]) * 0.45),
      math.floor(c[3] + (255 - c[3]) * 0.45) }
  end

  local function tagFor(game, t)
    local known = TYPE_TAGS[tostring(t or ""):upper()]
    if known then return known[1], known[2] end
    -- a type another mod added: its display name, cut to fit
    local name = tostring(t or "???")
    pcall(function()
      local TypeChart = require("src.battle.TypeChart")
      if type(TypeChart.displayName) == "function" then
        local v = TypeChart.displayName(t, game and game.data)
        if v then name = tostring(v) end
      end
    end)
    name = name:gsub("_TYPE$", ""):gsub("[^%w%?]", ""):upper()
    while #name > 1 and pixWidth(TINY, name) > TAG_W - 5 do name = name:sub(1, -2) end
    return name, UNKNOWN_TAG
  end

  local function drawTag(game, t, x, y)
    local label, fill = tagFor(game, t)
    local top = lighter(fill)
    pcall(function()
      local PaletteFX = require("src.render.PaletteFX")
      if type(PaletteFX.markTrueColor) == "function" then
        PaletteFX.markTrueColor(x, y, TAG_W, TAG_H)
      end
    end)
    rect(top, x + 1, y, TAG_W - 2, 1)
    rect(top, x, y + 1, TAG_W, 1)
    rect(fill, x + 1, y + 1, TAG_W - 2, TAG_H - 2)
    rect(fill, x, y + 2, TAG_W, TAG_H - 4)
    rect(TAG_EDGE, x, y + TAG_H - 2, 1, 1)
    rect(TAG_EDGE, x + TAG_W - 1, y + TAG_H - 2, 1, 1)
    rect(TAG_EDGE, x + 1, y + TAG_H - 1, TAG_W - 2, 1)
    local tx = x + math.floor((TAG_W - pixWidth(TINY, label) - 1) / 2)
    pixText(TINY, label, tx + 1, y + 1, TAG_SHADOW)
    pixText(TINY, label, tx, y + 2, TAG_SHADOW)
    pixText(TINY, label, tx + 1, y + 2, TAG_SHADOW)
    pixText(TINY, label, tx, y + 1, TAG_TEXT)
  end

  local function typesOf(game, mon)
    local def = game and game.data and game.data.pokemon and game.data.pokemon[mon.species]
    local list = (type(mon.types) == "table" and mon.types) or (def and def.types) or {}
    local out = {}
    for _, t in ipairs(list) do
      if t ~= nil and t ~= out[1] then out[#out + 1] = t end
    end
    return out
  end

  local function levelShown(game, mon)
    local ok, LevelDisplay = pcall(require, "src.ui.LevelDisplay")
    if not ok or type(LevelDisplay) ~= "table" or type(LevelDisplay.visible) ~= "function" then
      return true
    end
    local okV, v = pcall(LevelDisplay.visible, mon, "party", game)
    return not okV or v ~= false
  end


  ---------------------------------------------------------------- sound
  local GEN2_SFX = {
    Press_AB = "Sfx_ReadText2", Swap = "Sfx_SwitchPokemon",
    Withdraw_Deposit = "Sfx_ChoosePcOption", Denied = "Sfx_Wrong",
  }
  local function play(game, id)
    local data = game and game.data
    if not data then return end
    if gen2 then
      id = GEN2_SFX[id] or id
      local sfx = data.audio and data.audio.sfx
      local okR, key = pcall(Sound.resolve, data, id)
      if not (sfx and okR and sfx[key]) then return end
    end
    pcall(Sound.play, data, id)
  end

  local function cry(game, mon)
    local data = game and game.data
    if not (data and mon and mon.species) or mon.isEgg then return end
    if gen2 then
      local cries = data.audio and data.audio.cries
      if cries and not cries[mon.species] then return end
    end
    pcall(Sound.playCry, data, mon.species)
  end

  ---------------------------------------------------------------- icons
  local function drawIcon(self, mon, x, y, animate)
    if not mon then return end
    local icons = mod.highlander and mod.highlander.pokeIcons
    if icons and not mon.isEgg and icons.source("pc") == "followers" then
      local ok, drawn = pcall(icons.draw, self.game, mon, x, y, {
        animate = animate, counter = self.frames, size = 16, markTrueColor = false,
      })
      if ok and drawn then return end
    end
    G.push("all")
    G.setShader()
    G.setColor(1, 1, 1, 1)
    if gen2 then
      local r = self.renderer
      if r then
        r.clock = animate and self.frames or 0
        r.blink = r.clock
        pcall(r.drawIcon, r, mon, x, y)
      end
    elseif not (icons and icons.drawOriginal
        and icons.drawOriginal(self.game, mon, x, y, animate, animate and self.frames or 0)) then
      local okP, PartyMenu = pcall(require, "src.ui.PartyMenu")
      if okP then
        pcall(PartyMenu.drawIcon, self.game, mon, x, y, animate and true or false,
          animate and self.frames or 0)
      end
    end
    G.pop()
  end

  ---------------------------------------------------------------- screen
  local PC = { isMenu = true }
  PC.__index = PC
  PC.isOpaque = true
  PC.screenId = "highlander_pc"
  PC.highlanderPC = true

  function PC.new(game, opts)
    opts = opts or {}
    local self = setmetatable({ game = game, opts = opts }, PC)
    self.save = opts.save or game.save
    self.save.party = self.save.party or {}
    S.compact(self.save)
    self.frames, self.t = 0, 0
    self.hold = MenuRepeat.new(15, 4)
    local count = #S.flat(self.save)
    self.region = count > 0 and "box" or "party"
    self.partyIndex, self.boxIndex, self.scroll = 1, 1, 0
    if gen2 then
      local ok, PartyMenu = pcall(require, "src.ui.gen2.PartyMenu")
      if ok then
        local okN, r = pcall(PartyMenu.new, game, { save = self.save })
        if okN then self.renderer = r end
      end
    else
      -- The whole page is drawn in its own colours (no Game Boy palette pass).
      self.sgbPalettes = function()
        local ok, PaletteFX = pcall(require, "src.render.PaletteFX")
        if not ok then return nil end
        return { PaletteFX.zone(false, 0, 0, 19, 17) }
      end
    end
    return self
  end

  -- state -----------------------------------------------------------------
  function PC:flat() return S.flat(self.save) end
  function PC:party() return self.save.party end
  function PC:moving() return self.held ~= nil or self.multi ~= nil end

  function PC:partyLimit()
    return math.max(1, math.min(S.partyMax(), #self:party() + 1))
  end

  function PC:boxLimit()
    return math.max(1, math.min(S.capacity(), #self:flat() + 1))
  end

  function PC:totalRows() return math.ceil(S.capacity() / COLS) end

  function PC:selected()
    if self.region == "party" then
      return self:party()[self.partyIndex], "party", self.partyIndex
    end
    return self:flat()[self.boxIndex], "box", self.boxIndex
  end

  function PC:clamp()
    self.partyIndex = math.max(1, math.min(self.partyIndex, self:partyLimit()))
    self.boxIndex = math.max(1, math.min(self.boxIndex, self:boxLimit()))
    local row = math.floor((self.boxIndex - 1) / COLS)
    if self.region == "box" then
      if row < self.scroll then self.scroll = row end
      if row >= self.scroll + BOX_ROWS then self.scroll = row - BOX_ROWS + 1 end
    end
    self.scroll = math.max(0, math.min(self.scroll, self:totalRows() - BOX_ROWS))
  end

  function PC:say(msg)
    if not msg or msg == "" then return end
    self.message = { text = msg, until_ = now() + 2.5 }
  end

  function PC:refuse(msg)
    play(self.game, "Denied")
    self:say(msg)
  end

  function PC:close()
    if self.closed then return end
    self.closed = true
    local stack = self.game.stack
    if gen2 and type(self.opts.onClose) == "function" then
      return self.opts.onClose()
    end
    if stack:top() == self then stack:pop() end
    if type(self.opts.onCancel) == "function" then self.opts.onCancel() end
  end

  -- moving the cursor -----------------------------------------------------
  function PC:toBoxRow(row, col)
    self.region = "box"
    local limit = self:boxLimit()
    local idx = row * COLS + col + 1
    if idx > limit then idx = limit end
    self.boxIndex = idx
  end

  function PC:move(dir)
    if self.region == "party" then
      local limit = self:partyLimit()
      if dir == "up" then
        self.partyIndex = (self.partyIndex - 2) % limit + 1
      elseif dir == "down" then
        self.partyIndex = self.partyIndex % limit + 1
      else
        -- The big box starts one party cell down (the info band is beside the
        -- first cell): party 2 lines up with its first row on screen, party 3
        -- with the second... and party 1 goes to the first row too.
        local row = math.max(0, self.partyIndex - 2)
        self:toBoxRow(self.scroll + row, dir == "right" and 0 or COLS - 1)
      end
    else
      local limit = self:boxLimit()
      local idx = self.boxIndex
      local row, col = math.floor((idx - 1) / COLS), (idx - 1) % COLS
      local lastRow = math.floor((limit - 1) / COLS)
      local function toParty()
        self.region = "party"
        self.partyIndex = math.max(1, math.min(row - self.scroll + 2, self:partyLimit()))
      end
      if dir == "left" then
        if col == 0 then toParty() else self.boxIndex = idx - 1 end
      elseif dir == "right" then
        if col == COLS - 1 or idx + 1 > limit then toParty() else self.boxIndex = idx + 1 end
      elseif dir == "up" then
        if row > 0 then
          self.boxIndex = idx - COLS
        else
          local target = idx
          while target + COLS <= limit do target = target + COLS end
          self.boxIndex = target
        end
      elseif dir == "down" then
        if idx + COLS <= limit then
          self.boxIndex = idx + COLS
        elseif row < lastRow then
          self.boxIndex = limit
        else
          self.boxIndex = col + 1
        end
      end
    end
    self:clamp()
    play(self.game, "Press_AB")
  end

  -- START w/ Left/Right: a page (5 rows) up or down. In the big box the
  -- cursor goes 5 rows up/down and always stays in its column (stopping at
  -- the column's first or last slot); on the party column the big box beside
  -- it scrolls.
  function PC:jump(step)
    local pageSlots = BOX_ROWS * COLS
    local limit = self:boxLimit()
    local lastRow = math.floor((limit - 1) / COLS)
    local maxScroll = math.max(0, lastRow - BOX_ROWS + 1)
    local before = { self.boxIndex, self.scroll }
    if self.region == "box" then
      local idx = self.boxIndex
      local target = idx + step * pageSlots
      if target > limit then
        target = idx
        while target + COLS <= limit do target = target + COLS end
      elseif target < 1 then
        target = (idx - 1) % COLS + 1
      end
      self.boxIndex = target
      self.scroll = math.max(0, math.min(self.scroll + step * BOX_ROWS, maxScroll))
    else
      self.scroll = math.max(0, math.min(self.scroll + step * BOX_ROWS, maxScroll))
    end
    self:clamp()
    if self.boxIndex == before[1] and self.scroll == before[2] then return end
    play(self.game, "Press_AB")
  end

  -- actions ---------------------------------------------------------------
  function PC:grabOrDrop()
    local mon, side, index = self:selected()
    if self.multi then return self:multiPress(mon, side, index) end
    if self.held then
      local h = self.held
      local ok, why = S.drop(self.game, self.save, h.side, h.index, side, index)
      if not ok then return self:refuse(why) end
      self.held = nil
      play(self.game, "Swap")
      self:afterChange(side)
      return
    end
    if not mon then return end
    self.held = { side = side, index = index, mon = mon }
    play(self.game, "Press_AB")
  end

  function PC:afterChange(side)
    if side then self.region = side end
    self:clamp()
  end

  -- MULTIPLE SELECTIONS, A: mark or unmark a Pokémon. All the marks come
  -- from one side (party or big box); SELECT drops them (multiDrop).
  function PC:multiPress(mon, side, index)
    local m = self.multi
    if not mon then return end
    if #m.marks > 0 and m.side ~= side then
      return self:refuse(Strings("SELECT drops them\nhere."))
    end
    for i, marked in ipairs(m.marks) do
      if marked == mon then
        table.remove(m.marks, i)
        play(self.game, "Press_AB")
        return
      end
    end
    m.side = side
    m.marks[#m.marks + 1] = mon
    play(self.game, "Press_AB")
  end

  -- MULTIPLE SELECTIONS, SELECT: the marked Pokémon take the slot under the
  -- cursor and the ones after it (swapping with whoever is there), on
  -- either side. On an empty slot they go to the end of that side.
  function PC:multiDrop()
    local m = self.multi
    if #m.marks == 0 then
      return self:refuse(Strings("Mark a POKéMON\nwith A first."))
    end
    local _, side, index = self:selected()
    local ok, why = S.dropGroup(self.game, self.save, m.side, m.marks, side, index)
    if not ok then return self:refuse(why) end
    local moved = #m.marks
    self.multi = nil
    play(self.game, "Swap")
    self:afterChange(side)
    self:say(Strings("Moved %d POKéMON.", moved))
  end

  function PC:isMarked(mon)
    if not (self.multi and mon) then return false end
    for _, marked in ipairs(self.multi.marks) do
      if marked == mon then return true end
    end
    return false
  end

  function PC:openMenu()
    local mon, side = self:selected()
    if not mon then return end
    local items = { { label = Strings("SUMMARY"), action = "summary" } }
    -- Gen 2: held items (GIVE / TAKE), right under SUMMARY like the party
    -- menu's ITEM. An EGG can't hold anything.
    if gen2 and not mon.isEgg then
      items[#items + 1] = { label = Strings("ITEM"), action = "item" }
    end
    if side == "party" then
      items[#items + 1] = { label = Strings("SEND TO BOX"), action = "send" }
    else
      items[#items + 1] = { label = Strings("SEND TO PARTY"), action = "send" }
      items[#items + 1] = { label = Strings("RELEASE"), action = "release" }
    end
    items[#items + 1] = { label = Strings("MULTIPLE SELECTIONS"), action = "multi" }
    items[#items + 1] = { label = Strings("CANCEL"), action = "cancel" }
    self.menu = { items = items, index = 1 }
    play(self.game, "Press_AB")
  end

  function PC:summary(mon)
    local okS, Screens = pcall(require, "src.ui.Screens")
    if not okS then return end
    if gen2 then
      local game = self.game
      pcall(Screens.push, game, "Gen2SummaryMenu", {
        mon = mon, save = self.save,
        onClose = function() if game.stack:top() ~= self then game.stack:pop() end end,
      })
    else
      S.ensureStats(self.game, mon)
      pcall(Screens.push, self.game, "SummaryMenu", mon)
    end
  end

  -- ITEM: the game's own GIVE / TAKE menu (Gen2HeldItemMenu), drawn over
  -- the PC, with its PACK, swap question and texts. It works on a party slot,
  -- so for a boxed Pokémon it is pointed at that Pokémon instead; MAIL
  -- can't be given there (MAIL never goes in the BOX).
  function PC:heldItem(mon, side, index)
    local okM, Mail = pcall(require, "src.core.gen2.Mail")
    if okM and side == "party" and Mail.monHoldsMail(mon) then
      return self:refuse(Strings("Remove MAIL first."))
    end
    local okS, Screens = pcall(require, "src.ui.Screens")
    if not okS then return end
    local game = self.game
    local menu
    local ok, built = pcall(Screens.build, game, "Gen2HeldItemMenu", {
      save = self.save,
      slot = side == "party" and index or 0,
      items = game.data and game.data.items,
      onClose = function()
        if menu and game.stack:top() == menu then game.stack:pop() end
      end,
    })
    if not (ok and type(built) == "table") then
      mod.log:error("PC ITEM menu failed: %s", tostring(built))
      return self:refuse(Strings("Something went\nwrong. No change."))
    end
    menu = built
    if side == "box" then
      menu.mon = function() return mon end
      local canHold = menu.canHold
      menu.canHold = function(m, itemId)
        if okM and Mail.isMail(itemId) then return false end
        return canHold(m, itemId)
      end
    end
    game.stack:push(menu)
  end

  function PC:runMenu(item)
    self.menu = nil
    local mon, side, index = self:selected()
    if not (item and mon) or item.action == "cancel" then return end
    if item.action == "summary" then
      return self:summary(mon)
    elseif item.action == "item" then
      return self:heldItem(mon, side, index)
    elseif item.action == "send" then
      local ok, why = S.send(self.game, self.save, side, index)
      if not ok then return self:refuse(why) end
      cry(self.game, mon)
      self:clamp()
      local name = S.name(self.game, mon)
      if side == "party" then
        self:say(Strings("%s was\nstored in the BOX.", name))
      else
        self:say(Strings("%s is\ntaken out.", name))
      end
    elseif item.action == "release" then
      local why = S.releaseRefusal(self.game, self.save, mon)
      if why then
        if not gen2 and mon.species == "PIKACHU" then cry(self.game, mon) end
        return self:refuse(why)
      end
      self.confirm = { mon = mon, index = index, choice = 2 }
    elseif item.action == "multi" then
      self.multi = { side = side, marks = { mon } }
    end
  end

  function PC:updateMenu(input)
    local menu = self.menu
    local pressed = function(k) return input:wasPressed(k) end
    if pressed("b") then
      self.menu = nil
      play(self.game, "Press_AB")
    elseif pressed("up") then
      menu.index = (menu.index - 2) % #menu.items + 1
      play(self.game, "Press_AB")
    elseif pressed("down") then
      menu.index = menu.index % #menu.items + 1
      play(self.game, "Press_AB")
    elseif pressed("a") then
      play(self.game, "Press_AB")
      self:runMenu(menu.items[menu.index])
    end
  end

  function PC:updateConfirm(input)
    local c = self.confirm
    if input:wasPressed("b") then
      self.confirm = nil
      play(self.game, "Press_AB")
    elseif input:wasPressed("up") or input:wasPressed("down") then
      c.choice = c.choice == 1 and 2 or 1
      play(self.game, "Press_AB")
    elseif input:wasPressed("a") then
      self.confirm = nil
      play(self.game, "Press_AB")
      if c.choice ~= 1 then return end
      local name = S.name(self.game, c.mon)
      local ok, why = S.release(self.game, self.save, c.index, c.mon)
      if not ok then return self:refuse(why) end
      cry(self.game, c.mon)
      self:clamp()
      self:say(Strings("%s was\nreleased. Bye!", name))
    end
  end

  function PC:update(dt)
    self.frames = self.frames + 1
    self.t = self.t + (tonumber(dt) or 0)
    local input = self.game and self.game.input
    if not input then return end
    if self.message then
      if now() >= self.message.until_ then
        self.message = nil
      elseif input:wasPressed("a") or input:wasPressed("b")
          or input:wasPressed("start") then
        self.message = nil
        return
      end
    end
    if self.confirm then return self:updateConfirm(input) end
    if self.menu then return self:updateMenu(input) end
    local dir = MenuRepeat.direction(self.hold, input, { "up", "down", "left", "right" })
    if dir then
      self.message = nil
      if (dir == "left" or dir == "right") and input.isDown and input:isDown("start") then
        return self:jump(dir == "right" and 1 or -1)
      end
      return self:move(dir)
    end
    -- A: the menu, or grab/drop with AUTO-GRAB on (and always while a
    -- Pokémon is in hand); marks in MULTIPLE SELECTIONS.
    -- SELECT: AUTO-GRAB on/off, or DROP in MULTIPLE SELECTIONS.
    -- START w/ Left/Right: jump a page. B: cancel / leave.
    if input:wasPressed("a") then
      self.message = nil
      if self.multi or self.held or self.autoGrab then
        self:grabOrDrop()
      else
        self:openMenu()
      end
    elseif input:wasPressed("b") then
      play(self.game, "Press_AB")
      if self.held then self.held = nil; self:clamp()
      elseif self.multi then self.multi = nil; self:clamp()
      else self:close() end
    elseif input:wasPressed("select") then
      self.message = nil
      if self.multi then
        self:multiDrop()
      elseif not self.held then
        -- only for this visit: a new PC screen starts with it off
        self.autoGrab = not self.autoGrab
        play(self.game, "Press_AB")
      end
    end
  end

  ---------------------------------------------------------------- drawing
  local function cellRect(x, y) return x + 1, y + 1, CELL - 1, PITCH - 1 end

  local function frame(c, x, y, w, h, t)
    rect(c, x, y, w, t); rect(c, x, y + h - t, w, t)
    rect(c, x, y, t, h); rect(c, x + w - t, y, t, h)
  end

  local function arrow(x, y, up, c)
    -- 4 wide, 6 tall: head then stem
    if up then
      rect(c, x + 1, y, 2, 1); rect(c, x, y + 1, 4, 1); rect(c, x + 1, y + 2, 2, 4)
    else
      rect(c, x + 1, y, 2, 4); rect(c, x, y + 4, 4, 1); rect(c, x + 1, y + 5, 2, 1)
    end
  end

  -- Button help, all at once: what A / SELECT / B do on the left, the page
  -- jump on the right. Returns two lists of lines (left, right).
  local function pair(a, b) return a .. "  " .. b end
  function PC:helpLines()
    if self.menu or self.confirm then return { pair("A:OK", "B:BACK") }, {} end
    local jump = { "START+L/R", "JUMP SCROLL" }
    if self.held then return { pair("A:DROP", "B:CANCEL") }, jump end
    if self.multi then return { "A:MARK", pair("SELECT:DROP", "B:END") }, jump end
    if self.autoGrab then return { pair("A:GRAB", "SELECT:MENU") }, jump end
    return { pair("A:MENU", "SELECT:GRAB") }, jump
  end

  -- The band above the big box: the Pokemon under the cursor, its name with
  -- "LvXX" always on the line under it, and its type(s) as tags on the
  -- right, two types stacked. No level shown (an egg): the name is centred.
  function PC:drawMonInfo(mon, ink)
    local name = S.name(self.game, mon)
    local room = TAGS_X - 2 - NAME_X
    local level = tonumber(mon.level)
    local lv = (not mon.isEgg and level and levelShown(self.game, mon))
      and ("Lv" .. tostring(math.floor(level))) or nil
    if lv then
      text(name, NAME_X, 19, ink, room)
      text(lv, NAME_X, 29, ink, room)
    else
      text(name, NAME_X, 24, ink, room)
    end
    if mon.isEgg then return end
    local types = typesOf(self.game, mon)
    if #types >= 2 then
      drawTag(self.game, types[1], TAGS_X, 20)
      drawTag(self.game, types[2], TAGS_X, 29)
    elseif types[1] ~= nil then
      drawTag(self.game, types[1], TAGS_X, 24)
    end
  end

  function PC:drawCell(pal, mon, x, y, chosen, list, index, side)
    local cx, cy, cw, ch = cellRect(x, y)
    local held = self.held
    local origin = held and held.side == side and held.index == index
    local face = (origin or self:isMarked(mon)) and pal[2] or pal[1]
    rect(face, cx, cy, cw, ch)
    if mon and not origin then
      drawIcon(self, mon, cx + 4, cy + 2, chosen and not held)
    end
    if chosen then frame(pal[3], cx, cy, cw, ch, 2) end
  end

  function PC:draw()
    local pal = palette(self.game)
    local paper, light, dark, ink = pal[1], pal[2], pal[3], pal[4]
    G.push("all")
    G.setShader()
    rect(light, 0, 0, W, H)

    -- header
    -- PARTY: a small badge (tiny letters on a rounded dark tab). With
    -- AUTO-GRAB on, a second badge, GRAB (on an ink tab, darker than
    -- PARTY's, so it stands out), sits under it.
    local function badge(word, y, h, face, ink_)
      local bw = pixWidth(TINY, word) + 4
      local bx = PARTY_X + math.floor((26 - bw) / 2)
      rect(face, bx + 1, y, bw - 2, h)
      rect(face, bx, y + 1, bw, h - 2)
      pixText(TINY, word, bx + 2, y + math.floor((h - 5) / 2), ink_)
    end
    if self.autoGrab then
      badge("PARTY", 1, 7, dark, paper)
      badge("GRAB", 9, 7, ink, paper)
    else
      badge("PARTY", 4, 9, dark, paper)
    end
    local left, right = self:helpLines()
    local ly = #left >= 2 and 3 or 6
    for i, line in ipairs(left) do pixText(TINY, line, NAME_X, ly + (i - 1) * 7, ink) end
    local ry = #right >= 2 and 3 or 6
    for i, line in ipairs(right) do
      pixText(TINY, line, 158 - pixWidth(TINY, line), ry + (i - 1) * 7, ink)
    end
    local mon = self:selected()
    if mon then self:drawMonInfo(mon, ink) end

    -- party column
    local party = self:party()
    rect(ink, PARTY_X, ROW_Y, CELL + 1, ROWS * PITCH + 1)
    for i = 1, ROWS do
      local y = ROW_Y + (i - 1) * PITCH
      local chosen = self.region == "party" and self.partyIndex == i
        and not self.menu and not self.confirm
      self:drawCell(pal, party[i], PARTY_X, y, chosen, party, i, "party")
    end

    -- big box
    local flat = self:flat()
    rect(ink, GRID_X, BOX_Y, COLS * CELL + 1, BOX_ROWS * PITCH + 1)
    for r = 0, BOX_ROWS - 1 do
      for c = 0, COLS - 1 do
        local index = (self.scroll + r) * COLS + c + 1
        local x, y = GRID_X + c * CELL, BOX_Y + r * PITCH
        if index <= S.capacity() then
          local chosen = self.region == "box" and self.boxIndex == index
            and not self.menu and not self.confirm
          self:drawCell(pal, flat[index], x, y, chosen, flat, index, "box")
        else
          rect(light, x + 1, y + 1, CELL - 1, PITCH - 1)
        end
      end
    end

    -- arrows (flashing) when Pokémon are above / below the rows on screen
    if math.floor(now() * 3) % 2 == 0 then
      if self.scroll > 0 and #flat > 0 then arrow(GAP_X, BOX_Y + 2, true, ink) end
      if #flat > (self.scroll + BOX_ROWS) * COLS then
        arrow(GAP_X, BOX_Y + BOX_ROWS * PITCH - 7, false, ink)
      end
    end

    -- the Pokémon in hand floats over the cursor
    if self.held then
      local x, y
      if self.region == "party" then
        x, y = PARTY_X, ROW_Y + (self.partyIndex - 1) * PITCH
      else
        local idx = self.boxIndex - 1
        x = GRID_X + (idx % COLS) * CELL
        y = BOX_Y + (math.floor(idx / COLS) - self.scroll) * PITCH
      end
      drawIcon(self, self.held.mon, x + 9, y - 3, true)
    end

    if self.menu then self:drawMenu(pal) end
    if self.confirm then self:drawConfirm(pal) end
    if self.message then self:drawMessage(pal, self.message.text) end
    G.pop()
  end

  local function panel(pal, x, y, w, h)
    rect(pal[4], x, y, w, h)
    rect(pal[1], x + 1, y + 1, w - 2, h - 2)
  end

  local function pointer(c, x, y)
    rgb(c)
    G.polygon("fill", x, y, x, y + 6, x + 3, y + 3)
  end

  function PC:cursorY()
    if self.region == "party" then return ROW_Y + (self.partyIndex - 1) * PITCH end
    return BOX_Y + (math.floor((self.boxIndex - 1) / COLS) - self.scroll) * PITCH
  end

  function PC:drawMenu(pal)
    local items = self.menu.items
    local maxW = 0
    for _, item in ipairs(items) do maxW = math.max(maxW, textWidth(item.label)) end
    local w = math.min(152, maxW + 14)
    local h = #items * 10 + 5
    local x = 158 - w
    -- out of the cursor's way: on top when the cursor is low, else at the bottom
    local y = self:cursorY() >= 70 and ROW_Y + 2 or H - h - 1
    panel(pal, x, y, w, h)
    for i, item in ipairs(items) do
      local ty = y + 3 + (i - 1) * 10
      if i == self.menu.index then pointer(pal[4], x + 3, ty + 1) end
      text(item.label, x + 9, ty, pal[4], w - 11)
    end
  end

  function PC:drawMessage(pal, msg)
    panel(pal, 0, H - 24, W, 24)
    local lines = wrap(msg, W - 8)
    for i = 1, math.min(2, #lines) do
      text(lines[i], 4, H - 24 + 3 + (i - 1) * 10, pal[4], W - 8)
    end
  end

  function PC:drawConfirm(pal)
    local name = S.name(self.game, self.confirm.mon)
    self:drawMessage(pal, Strings("Release %s?", name))
    local w, h = 34, 25
    local x, y = W - w - 2, H - 24 - h - 1
    panel(pal, x, y, w, h)
    local choices = { Strings("YES"), Strings("NO") }
    for i, label in ipairs(choices) do
      local ty = y + 3 + (i - 1) * 10
      if i == self.confirm.choice then pointer(pal[4], x + 3, ty + 1) end
      text(label, x + 9, ty, pal[4], w - 11)
    end
  end

  return PC
end
