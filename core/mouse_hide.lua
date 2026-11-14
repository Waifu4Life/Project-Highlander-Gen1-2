-- Mouse pointer: hidden over the game window after 2 seconds without moving
-- or clicking, and back as soon as the mouse moves or a button is pressed.
-- Only the pointer over the game window is affected: it shows normally
-- everywhere else.
--
-- Checked once per frame from the mouse's position and buttons, so it needs
-- no input events and works on every screen (title, menus, battles, the mod
-- manager). The wait is counted in real time, so GAME SPEED doesn't change it.
return function(mod)
  local m = love and love.mouse
  if not (m and m.setVisible and m.getPosition) then return end
  -- phones / tablets: no pointer to hide
  local os_ = love.system and love.system.getOS and love.system.getOS()
  if os_ == "Android" or os_ == "iOS" then return end

  local IDLE = 2.0
  local lastX, lastY, lastActive
  local hidden = false

  local function clock()
    return love.timer and love.timer.getTime and love.timer.getTime() or os.clock()
  end

  local function show(on)
    if hidden == not on then return end
    hidden = not on
    pcall(m.setVisible, on)
  end

  local function anyButton()
    if not m.isDown then return false end
    local ok, down = pcall(m.isDown, 1, 2, 3)
    return ok and down == true
  end

  mod.hooks:wrap("core.update", function(nextFn, game, dt)
    local result = nextFn(game, dt)
    pcall(function()
      local now = clock()
      local x, y = m.getPosition()
      if lastX == nil or x ~= lastX or y ~= lastY or anyButton() then
        lastX, lastY, lastActive = x, y, now
        show(true)
      elseif now - (lastActive or now) >= IDLE then
        show(false)
      end
    end)
    return result
  end)
end
