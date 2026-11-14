-- Held directions: is a direction the game holds still really held?
--
-- The game keeps, for every button, the list of sources holding it
-- ("key:up", "pad:dpleft", "touch:up", "mod:...", Full Control's "k:w" ...).
-- When a release gets lost (a tap whose press and release land between two
-- logic steps, a focus change, another mod), the button stays on with
-- nothing behind it and the player, or a menu cursor, keeps going until that
-- direction is pressed again.
--
-- heldBy(input, dir) asks each source: a key is checked on the keyboard, a
-- pad button / stick direction / trigger on the connected controllers. Any
-- other source (the on-screen D-pad, a mod's scripted hold, a raw joystick)
-- can't be looked up, so it counts as held. That makes it safe on keyboard
-- and controller alike, with any key the player has bound.
--
-- guard(input, counters, frames) lets go of a direction the game has held
-- with nothing behind it for `frames` calls in a row (default 15, 1/4 s),
-- the same as tapping it. Returns true when it let go of something.
return function()
  local H = {}
  local DIRS = { "up", "down", "left", "right" }

  -- stick "buttons" are the stick pushed that way: axis and sign
  local STICK = {
    leftstick_up = { "lefty", -1 }, leftstick_down = { "lefty", 1 },
    leftstick_left = { "leftx", -1 }, leftstick_right = { "leftx", 1 },
    lsup = { "lefty", -1 }, lsdown = { "lefty", 1 },
    lsleft = { "leftx", -1 }, lsright = { "leftx", 1 },
    rightstick_up = { "righty", -1 }, rightstick_down = { "righty", 1 },
    rightstick_left = { "rightx", -1 }, rightstick_right = { "rightx", 1 },
    rsup = { "righty", -1 }, rsdown = { "righty", 1 },
    rsleft = { "rightx", -1 }, rsright = { "rightx", 1 },
  }

  -- true / false, or nil when it can't be told (counts as held)
  local function keyDown(key)
    local kb = love and love.keyboard
    if not (kb and kb.isDown) or key == "" then return nil end
    local ok, down = pcall(kb.isDown, key)
    if not ok then return nil end
    return down == true
  end

  local function padDown(button)
    local js = love and love.joystick
    if not (js and js.getJoysticks) then return nil end
    local okL, list = pcall(js.getJoysticks)
    if not okL or type(list) ~= "table" then return nil end
    if #list == 0 then return false end
    local stick = STICK[button]
    local known = false
    for _, j in ipairs(list) do
      if stick or button == "triggerleft" or button == "triggerright" then
        if j.getGamepadAxis then
          local ok, v = pcall(j.getGamepadAxis, j, stick and stick[1] or button)
          if ok and type(v) == "number" then
            known = true
            if stick and v * stick[2] >= 0.25 then return true end
            if not stick and v >= 0.2 then return true end
          end
        end
      elseif j.isGamepadDown then
        local ok, down = pcall(j.isGamepadDown, j, button)
        if ok then
          known = true
          if down then return true end
        end
      end
    end
    if not known then return nil end
    return false
  end

  function H.sourceHeld(id)
    id = tostring(id or "")
    local kind, rest = id:match("^([%w_]+):(.*)$")
    if kind == "key" or kind == "k" then return keyDown(rest) end
    if kind == "pad" then return padDown(rest) end
    return nil
  end

  -- Does anything still hold `dir`? `extra(dir)` may add sources of its own.
  function H.heldBy(input, dir, extra)
    if extra and extra(dir) then return true end
    local live = input.sources and input.sources[dir]
    if type(live) ~= "table" then return false end
    for id, on in pairs(live) do
      if on and H.sourceHeld(id) ~= false then return true end
    end
    return false
  end

  function H.drop(input, dir)
    local live = input.sources and input.sources[dir]
    if type(live) == "table" and type(input.sourceRelease) == "function" then
      local ids = {}
      for id in pairs(live) do ids[#ids + 1] = id end
      for _, id in ipairs(ids) do pcall(input.sourceRelease, input, dir, id) end
    end
    if input.state then input.state[dir] = false end
  end

  function H.guard(input, counters, frames, extra)
    if type(input) ~= "table" or type(input.state) ~= "table" then return false end
    frames = frames or 15
    local dropped = false
    for _, dir in ipairs(DIRS) do
      if input.state[dir] == true and not H.heldBy(input, dir, extra) then
        counters[dir] = (counters[dir] or 0) + 1
        if counters[dir] >= frames then
          counters[dir] = nil
          H.drop(input, dir)
          dropped = true
        end
      else
        counters[dir] = nil
      end
    end
    return dropped
  end

  return H
end
