-- START > CUSTOM ICONS: every other mod's Start Menu row, each with a grid
-- picker for its icon.
--
-- ctx (from main.lua):
--   id, page, choices     component id, page.lua, icons.lua choices
--   modRows()             { { key, label }, ... } known mod rows
--   getIcon(key)          chosen frame or nil (AUTO)
--   setIcon(game, key, frame|nil)
return function(ctx)
  local Font = require("src.render.Font")
  local Sound = require("src.core.Sound")
  local Entries = ctx.entries
  local ListMenu = ctx.ListMenu
  if not (ListMenu and type(ListMenu.new) == "function") then
    local ok, module = pcall(require, "src.ui.ListMenu")
    ListMenu = ok and module or nil
  end
  local okPal, PaletteFX = pcall(require, "src.render.PaletteFX")
  if not okPal then PaletteFX = nil end

  local W, H = 160, 144
  local GRID = { cols = 7, perPage = 35, x = 4, y = 17, cell = 20, stepX = 22,
    stepY = 21, line = 123 }

  local function beep(game)
    if game and game.data then pcall(Sound.play, game.data, "Press_AB") end
  end

  local function shortName(label)
    local raw = tostring(label or "MENU")
    if raw:find("<PO>", 1, true) or raw:upper():find("GEAR", 1, true) then
      return "Pokégear"
    end
    local name = Entries.plain(raw)
    if #name > 12 then name = name:sub(1, 11) .. "." end
    return name ~= "" and name or "MENU"
  end

  local function choiceName(frame)
    for _, c in ipairs(ctx.choices) do
      if c[2] == (frame or "auto") then return c[1] end
    end
    return "AUTO"
  end

  local function centre(str, y)
    str = tostring(str)
    while #str > 1 and Font.width(str) > W - 16 do str = str:sub(1, -2) end
    Font.draw(str, math.floor((W - Font.width(str)) / 2), y)
  end

  local function newPicker(game, row, onDone)
    local picker = { game = game, isOpaque = true,
      screenId = ctx.id .. ":icon_picker", index = 1 }
    local current = ctx.getIcon(row.key) or "auto"
    for i, c in ipairs(ctx.choices) do
      if c[2] == current then picker.index = i break end
    end
    function picker:uiSize() return W, H end
    function picker:sgbPalettes(g)
      g = g or self.game
      if PaletteFX and g and g.data then
        return PaletteFX.wholeNamed(g.data, "MEWMON")
      end
    end
    local function close(self)
      if self.game.stack:top() == self then self.game.stack:pop() end
    end
    function picker:update()
      local input = self.game.input
      if not input then return end
      local n = #ctx.choices
      local move = (input:wasPressed("left") and -1)
        or (input:wasPressed("right") and 1)
        or (input:wasPressed("up") and -GRID.cols)
        or (input:wasPressed("down") and GRID.cols)
      if move then
        self.index = (self.index - 1 + move) % n + 1
      elseif input:wasPressed("a") then
        beep(self.game)
        local frame = ctx.choices[self.index][2]
        ctx.setIcon(self.game, row.key, frame ~= "auto" and frame or nil)
        close(self)
        if onDone then onDone() end
      elseif input:wasPressed("b") then
        beep(self.game)
        close(self)
      end
    end
    function picker:draw()
      love.graphics.push("all")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, W, H)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("CHOOSE ICON", 8, 4)
      local page = math.floor((self.index - 1) / GRID.perPage) + 1
      local pages = math.ceil(#ctx.choices / GRID.perPage)
      local p = ("%d/%d"):format(page, pages)
      Font.draw(p, W - 8 - Font.width(p), 4)
      love.graphics.rectangle("fill", 4, 15, 152, 1)
      for s = 1, GRID.perPage do
        local i = (page - 1) * GRID.perPage + s
        local c = ctx.choices[i]
        if not c then break end
        local x = GRID.x + ((s - 1) % GRID.cols) * GRID.stepX
        local y = GRID.y + math.floor((s - 1) / GRID.cols) * GRID.stepY
        local v = i == self.index and 0 or 0.72
        love.graphics.setColor(v, v, v, 1)
        love.graphics.rectangle("fill", x, y, GRID.cell, GRID.cell)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x + 2, y + 2, GRID.cell - 4, GRID.cell - 4)
        local pad = math.floor((GRID.cell - ctx.page.ICON) / 2)
        ctx.page.drawIcon(c[2], x + pad, y + pad, 0)
      end
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 4, GRID.line, 152, 1)
      centre(ctx.choices[self.index][1], GRID.line + 3)
      centre(shortName(row.label), GRID.line + 12)
      love.graphics.pop()
    end
    return picker
  end

  local CustomIcons = {}

  function CustomIcons.open(game)
    if not (ListMenu and game and game.stack) then return false end
    local menu
    local function build()
      local items = {}
      for _, row in ipairs(ctx.modRows()) do
        items[#items + 1] = { id = row.key, label = shortName(row.label),
          right = choiceName(ctx.getIcon(row.key)), row = row }
      end
      if #items == 0 then
        items[1] = { id = "none", label = "NO MOD ENTRIES", right = "----" }
      end
      items[#items + 1] = { id = "back", label = "BACK", cancel = true }
      return items
    end
    menu = ListMenu.new(game, "CUSTOM ICONS", build(), {
      wrap = true, keyRepeat = true,
      onChoose = function(item, active)
        if not item then return end
        if item.cancel then
          if active and active.close then active:close() end
        elseif item.row then
          game.stack:push(newPicker(game, item.row, function()
            local keep = menu.index
            menu.items = build()
            menu.index = math.min(keep, #menu.items)
          end))
        end
      end,
    })
    menu.screenId = ctx.id .. ":settings"
    game.stack:push(menu)
    return true
  end

  return CustomIcons
end
