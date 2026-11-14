-- Full Control: overwrite official Controls + extras (N2, analog, combos, item shortcuts).
-- JUKEBOX BUTTON (bind_jukebox, NONE by default) is read by components/jukebox.
return function(mod)
  local ACTIONS = {
    { key = "bind_up",     action = "up",         label = "UP BUTTON" },
    { key = "bind_down",   action = "down",       label = "DOWN BUTTON" },
    { key = "bind_left",   action = "left",       label = "LEFT BUTTON" },
    { key = "bind_right",  action = "right",      label = "RIGHT BUTTON" },
    { key = "bind_b1",     action = "b",          label = "B BUTTON" },
    { key = "bind_a1",     action = "a",          label = "A BUTTON" },
    { key = "bind_start",  action = "start",      label = "START BUTTON" },
    { key = "bind_select", action = "select",     label = "SELECT BUTTON" },
    { key = "bind_speedp", action = "speedUp",    label = "SPEED+ BUTTON", speed = true },
    { key = "bind_speedm", action = "speedDown",  label = "SPEED- BUTTON", speed = true },
    -- JUKEBOX (components/jukebox): held with a direction; never sent to the game
    { key = "bind_jukebox", action = "jukebox",   label = "JUKEBOX BUTTON", jukebox = true },
  }

  local DEFAULTS = {
    bind_up     = { key = "up",      pad = "dpup" },
    bind_down   = { key = "down",    pad = "dpdown" },
    bind_left   = { key = "left",    pad = "dpleft" },
    bind_right  = { key = "right",   pad = "dpright" },
    bind_b1     = { key = "x",       pad = "b" },
    bind_a1     = { key = "z",       pad = "a" },
    analog_left = true,
    bind_start  = { key = "escape",  pad = "start" },
    bind_select = { key = "tab",     pad = "back" },
    bind_speedp = { key = "",        pad = "rightshoulder" },
    bind_speedm = { key = "",        pad = "leftshoulder" },
    bind_jukebox = { key = "",       pad = "" },
    analog_right = false,
  }

  local schema = {}
  for _, row in ipairs(ACTIONS) do
    schema[#schema + 1] = {
      key = row.key, label = row.label, type = "bind", default = DEFAULTS[row.key],
    }
  end
  schema[#schema + 1] = {
    key = "analog_left", label = "LEFT ANALOG FOR D-PAD", type = "toggle",
    default = true,
  }
  schema[#schema + 1] = {
    key = "analog_right", label = "RIGHT ANALOG FOR D-PAD", type = "toggle",
    default = false,
  }
  -- On: SELECT + A / B / X / Y / LB run the game's display shortcuts
  -- (COLORS, TILT, ...) like they do without Full Control. Off: those
  -- buttons act normally while SELECT is held.
  schema[#schema + 1] = {
    key = "select_combos", label = "SELECT VISUAL COMBOS", type = "toggle",
    default = true,
  }

  mod.options:define(schema)

  local function packOf(key)
    local v = mod.options:get(key)
    if type(v) == "table" then return v end
    return DEFAULTS[key] or { key = "", pad = "" }
  end

  local KEY_SHORT = {
    escape = "ESC", backspace = "BKSP", ["return"] = "ENTER",
    kpenter = "ENTER", space = "SPC", rshift = "RSH", lshift = "LSH",
    lctrl = "LCTL", rctrl = "RCTL", lalt = "LALT", ralt = "RALT",
  }
  local PAD_SHORT = {
    dpup = "D-UP", dpdown = "D-DN", dpleft = "D-LT", dpright = "D-RT",
    leftshoulder = "LB", rightshoulder = "RB",
    leftstick = "LS", rightstick = "RS",
    triggerleft = "LT", triggerright = "RT",
    back = "BACK", start = "START", guide = "GUIDE",
    a = "A", b = "B", x = "X", y = "Y",
    ["rs_up"] = "RS-U", ["rs_down"] = "RS-D",
    ["rs_left"] = "RS-L", ["rs_right"] = "RS-R",
    ["ls_up"] = "LS-U", ["ls_down"] = "LS-D",
    ["ls_left"] = "LS-L", ["ls_right"] = "LS-R",
  }

  local function short(name, map)
    if not name or name == "" then return "--" end
    return map[name] or (tostring(name):upper():sub(1, 5))
  end

  local function bindLabel(key)
    local p = packOf(key)
    local k, d = short(p.key, KEY_SHORT), short(p.pad, PAD_SHORT)
    if k == "--" and d == "--" then return "NONE" end
    if d == "--" then return "KEY " .. k end
    if k == "--" then return "PAD " .. d end
    return k .. " +PAD " .. d
  end

  local function persistPack(game, key, pack)
    if mod.options and type(mod.options.set) == "function" then
      pcall(mod.options.set, mod.options, game, key, pack)
    end
    if game and game.writeOptions then pcall(game.writeOptions, game) end
  end

  local extras = { key = {}, pad = {} }

  local function applyBindings(game)
    local ok, Input = pcall(require, "src.core.Input")
    if not ok or type(Input) ~= "table" then return end
    extras.key, extras.pad = {}, {}
    local overlay = {}
    for _, row in ipairs(ACTIONS) do
      local p = packOf(row.key)
      if row.jukebox then
        -- read by the Jukebox itself, never mapped to a game button
      elseif row.item then
        if p.key and p.key ~= "" then extras.key[p.key] = "item" .. row.item end
        if p.pad and p.pad ~= "" then extras.pad[p.pad] = "item" .. row.item end
      elseif row.extra then
        if p.key and p.key ~= "" then extras.key[p.key] = row.action end
        if p.pad and p.pad ~= "" then extras.pad[p.pad] = row.action end
      else
        local entry = {}
        if p.key and p.key ~= "" then entry.key = p.key end
        if p.pad and p.pad ~= "" then entry.pad = p.pad end
        if next(entry) then overlay[row.action] = entry end
      end
    end
    if game and game.save then
      game.save.options = game.save.options or {}
      game.save.options.bindings = overlay
    end
    if type(Input.applyBindings) == "function" then
      pcall(Input.applyBindings, Input, overlay)
    end
    -- Official applyBindings LAYERS on GamepadMap defaults, so Start / Select
    -- / LB / RB keep their stock jobs. Replace pad maps with ours only.
    local pads, acts, claimed = {}, {}, {}
    for _, row in ipairs(ACTIONS) do
      local p = packOf(row.key)
      if not row.jukebox and p.pad and p.pad ~= "" then claimed[p.pad] = true end
    end
    for _, row in ipairs(ACTIONS) do
      local p = packOf(row.key)
      if not row.jukebox and p.pad and p.pad ~= "" then
        if row.speed then
          acts[p.pad] = row.action
        elseif not row.item and not row.extra then
          pads[p.pad] = row.action
        end
      end
    end
    Input.padBindings = pads
    Input.padActions = acts
    if game and game.input then
      game.input.padBindings = pads
      game.input.padActions = acts
    end
  end

  local function captureScreen(game, schemaKey)
    local Font = require("src.render.Font")
    local Sound = require("src.core.Sound")
    local Input = require("src.core.Input")
    local screen = {
      game = game,
      schemaKey = schemaKey,
      isOpaque = true,
      waiting = true,
    }
    function screen:uiSize() return 160, 144 end
    function screen:finish(kind, value)
      if not self.waiting then return end
      self.waiting = false
      local p = packOf(self.schemaKey)
      if kind == "clear" then
        persistPack(self.game, self.schemaKey, { key = "", pad = "" })
      elseif kind == "key" then
        persistPack(self.game, self.schemaKey, { key = value, pad = p.pad })
      elseif kind == "pad" then
        persistPack(self.game, self.schemaKey, { key = p.key, pad = value })
      end
      applyBindings(self.game)
      pcall(Sound.play, self.game and self.game.data, "Press_AB")
      if Input.armCapture then self.game.input.captureArmed = false end
      self.game.stack:pop()
    end
    function screen:update()
      if not self.waiting then return end
      local take = Input.takeCaptureEvents
      local ev = take and take(self.game.input or Input)
      if type(ev) ~= "table" then return end
      for _, e in ipairs(ev) do
        if e.phase == "pressed" then
          if e.kind == "key" then
            if e.value == "delete" or e.value == "kpdelete" then
              self:finish("clear")
              return
            end
            self:finish("key", e.value)
            return
          elseif e.kind == "pad" then
            self:finish("pad", e.value)
            return
          elseif e.kind == "joy" then
            self:finish("pad", "joy" .. tostring(e.value))
            return
          end
        end
      end
      -- Analog triggers are axes, not pad buttons.
      local pads = love.joystick and love.joystick.getJoysticks and love.joystick.getJoysticks()
      if type(pads) == "table" then
        for _, js in ipairs(pads) do
          if js.getGamepadAxis then
            local lt = js:getGamepadAxis("triggerleft") or 0
            local rt = js:getGamepadAxis("triggerright") or 0
            if lt >= 0.6 then self:finish("pad", "triggerleft") return end
            if rt >= 0.6 then self:finish("pad", "triggerright") return end
            if mod.options:get("analog_right") ~= true then
              local rx = js:getGamepadAxis("rightx") or 0
              local ry = js:getGamepadAxis("righty") or 0
              if rx >= 0.6 then self:finish("pad", "rs_right") return end
              if rx <= -0.6 then self:finish("pad", "rs_left") return end
              if ry >= 0.6 then self:finish("pad", "rs_down") return end
              if ry <= -0.6 then self:finish("pad", "rs_up") return end
            end
          end
        end
      end
    end
    function screen:draw()
      love.graphics.push("all")
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", 8, 40, 144, 64)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", 10, 42, 140, 60)
      love.graphics.setColor(0, 0, 0, 1)
      Font.draw("PRESS A KEY OR", 16, 52)
      Font.draw("GAMEPAD BUTTON", 16, 66)
      Font.draw("DELETE CLEARS", 16, 86)
      love.graphics.pop()
    end
    if Input.armCapture then
      pcall(Input.armCapture, game.input or Input)
    end
    game.stack:push(screen)
    return true
  end

  mod.exports.bindLabel = bindLabel
  mod.exports.capture = captureScreen
  mod.exports.applyBindings = applyBindings

  pcall(function()
    local BM = require("src.ui.BindingsMenu")
    if type(BM) == "table" and type(BM.commitBindings) == "function"
        and not BM._phFullCtl then
      BM._phFullCtl = true
      local orig = BM.commitBindings
      function BM:commitBindings(...)
        orig(self, ...)
        applyBindings(self.game)
      end
    end
  end)

  local heldBy
  local releaseHeld
  local function wrapInput()
    local ok, Input = pcall(require, "src.core.Input")
    if not ok or type(Input) ~= "table" then return end

    -- Input outlives a play session: EXIT GAME keeps it loaded while this file
    -- runs again for the next game. So keep the game's own handlers and wrap
    -- those every time. Stopping at "already wrapped" left the new session
    -- with no safety net below and the old session's settings in the handlers.
    local native = Input._phFullCtlNative
    if not native then
      native = {}
      for _, name in ipairs({ "keypressed", "keyreleased", "gamepadpressed",
          "gamepadreleased", "gamepadaxis", "padAction" }) do
        native[name] = Input[name]
      end
      Input._phFullCtlNative = native
    end

    -- Every press we generate remembers what physical control caused it,
    -- so a release that never arrives (window focus lost, Steam overlay,
    -- controller asleep/disconnected, a missed event) can be detected and
    -- cleared on the next frame instead of leaving the player walking.
    heldBy = {}
    local function remember(btn, source)
      if not (btn and source) then return end
      heldBy[btn] = heldBy[btn] or {}
      heldBy[btn][source.id] = source
    end

    -- Presses and releases go through the game's own per-source bookkeeping.
    -- Writing input.state and pressQueue by hand looks to Input:step like a
    -- scripted hold: a tap whose press AND release land before the next logic
    -- step (a slow frame, a map loading, a stick flick) is switched back on by
    -- step() with nothing left to release it, and the direction keeps going
    -- until it is pressed again.
    local function fireButton(input, btn, source)
      if not (input and btn) then return end
      remember(btn, source)
      if type(input.sourcePress) == "function" then
        pcall(input.sourcePress, input, btn, source.id)
        return
      end
      input.state = input.state or {}
      input.state[btn] = true
      input.pressQueue = input.pressQueue or {}
      input.pressQueue[#input.pressQueue + 1] = btn
    end

    local function releaseButton(input, btn, sourceId)
      if not (input and btn) then return end
      local sources = heldBy[btn]
      if sources then
        sources[sourceId] = nil
        if next(sources) == nil then heldBy[btn] = nil end
      end
      if type(input.sourceRelease) == "function" then
        pcall(input.sourceRelease, input, btn, sourceId)
        return
      end
      -- Another physical control still holds the same direction.
      if heldBy[btn] then return end
      if input.state then input.state[btn] = false end
    end

    -- The game's own name for this button's source, so its pad polling can
    -- repair a lost release and its focus recovery lands on the same entry.
    local function padSourceId(button)
      local okMap, GM = pcall(require, "src.core.GamepadMap")
      local name = okMap and GM.normalizePad and GM.normalizePad(button) or button
      return "pad:" .. tostring(name)
    end

    local origKey = native.keypressed
    if type(origKey) == "function" then
      function Input:keypressed(key, ...)
        self._phLastDevice = "key"
        local extra = extras.key[key]
        if extra and extra:sub(1, 4) == "item" then
          self._phItemTap = extra
          return
        end
        if extra then
          fireButton(self, extra, { id = "k:" .. key, kind = "key", key = key })
          return
        end
        return origKey(self, key, ...)
      end
    end
    local origKeyUp = native.keyreleased
    if type(origKeyUp) == "function" then
      function Input:keyreleased(key, ...)
        local extra = extras.key[key]
        if extra and extra:sub(1, 4) ~= "item" then
          releaseButton(self, extra, "k:" .. key)
          return
        end
        return origKeyUp(self, key, ...)
      end
    end

    -- The game now turns the left stick into pad presses of its own
    -- ("leftstick_up" ... or "lsup" ...) instead of moving the D-pad itself.
    -- Our pad map only holds the buttons Full Control binds, so those
    -- presses found nothing and LEFT ANALOG FOR D-PAD stopped working.
    local LEFT_STICK = {
      leftstick_up = "up", leftstick_down = "down",
      leftstick_left = "left", leftstick_right = "right",
      lsup = "up", lsdown = "down", lsleft = "left", lsright = "right",
    }
    local function padTarget(input, button)
      local mapped = (input.padBindings or {})[button]
      if mapped then return mapped end
      if LEFT_STICK[button] and mod.options:get("analog_left") ~= false then
        return LEFT_STICK[button]
      end
      return nil
    end

    local origPad = native.gamepadpressed
    function Input:gamepadpressed(joystick, button)
      self._phLastDevice = "pad"
      if self.captureArmed and type(origPad) == "function" then
        pcall(origPad, self, joystick, button)
      end
      if mod.options:get("select_combos") ~= false then
        local handled = false
        pcall(function()
          local Input = require("src.core.Input")
          local GM = require("src.core.GamepadMap")
          local held = Input.isDown and Input.isDown(game.input or Input, "select")
          local digit = held and GM.displayChordDigit and GM.displayChordDigit(button)
          if digit and type(game.keypressed) == "function" then
            game:keypressed(digit)
            handled = true
          end
        end)
        if handled then return end
      end
      local extra = extras.pad[button]
      if extra and extra:sub(1, 4) == "item" then
        self._phItemTap = extra
        return
      end
      local source = { id = padSourceId(button), kind = "pad",
        joystick = joystick, button = button }
      if extra then
        fireButton(self, extra, source)
        return
      end
      local mapped = padTarget(self, button)
      if mapped then
        fireButton(self, mapped, source)
      end
    end

    local origPadUp = native.gamepadreleased
    function Input:gamepadreleased(joystick, button)
      if self.captureArmed and type(origPadUp) == "function" then
        pcall(origPadUp, self, joystick, button)
      end
      local extra = extras.pad[button]
      if extra and extra:sub(1, 4) == "item" then
        return
      end
      -- Every direction this button holds, even if it was rebound since the
      -- press; then the game's own record, which covers presses it re-armed
      -- itself after a focus change.
      local id = padSourceId(button)
      for btn, sources in pairs(heldBy) do
        if sources[id] then releaseButton(self, btn, id) end
      end
      local target = extra or padTarget(self, button)
      if target then releaseButton(self, target, id) end
    end

    local origAct = native.padAction
    function Input:padAction(button)
      if extras.pad[button] then return nil end
      if self.padActions then return self.padActions[button] end
      if origAct then return origAct(self, button) end
      return nil
    end

    local origAxis = native.gamepadaxis
    if type(origAxis) == "function" then
      function Input:gamepadaxis(joystick, axis, value, ...)
        if math.abs(tonumber(value) or 0) >= 0.5 then
          self._phLastDevice = "pad"
        end
        local leftOn = mod.options:get("analog_left") ~= false
        local rightOn = mod.options:get("analog_right") == true
        if rightOn and (axis == "rightx" or axis == "righty") then
          self._phRsAxis = self._phRsAxis or { x = 0, y = 0 }
          if axis == "rightx" then self._phRsAxis.x = value end
          if axis == "righty" then self._phRsAxis.y = value end
          local x, y = self._phRsAxis.x, self._phRsAxis.y
          local ax, ay = math.abs(x), math.abs(y)
          local newDir = self._phRsDir
          if ax > 0.5 or ay > 0.5 then
            newDir = ax >= ay and (x > 0 and "right" or "left")
              or (y > 0 and "down" or "up")
          elseif ax < 0.3 and ay < 0.3 then
            newDir = nil
          end
          if newDir ~= self._phRsDir then
            if self._phRsDir then
              releaseButton(self, self._phRsDir, "rs")
            end
            if newDir then
              fireButton(self, newDir, { id = "rs", kind = "stick",
                joystick = joystick, dir = newDir })
            end
            self._phRsDir = newDir
          end
          return
        end
        if not rightOn and (axis == "rightx" or axis == "righty") then
          local name
          if axis == "rightx" and value >= 0.55 then name = "rs_right"
          elseif axis == "rightx" and value <= -0.55 then name = "rs_left"
          elseif axis == "righty" and value >= 0.55 then name = "rs_down"
          elseif axis == "righty" and value <= -0.55 then name = "rs_up"
          end
          local extra = name and extras.pad[name]
          if extra then
            if extra:sub(1, 4) == "item" then
              if self._phRsLatch ~= name then
                self._phItemTap = extra
                self._phRsLatch = name
              end
            elseif self._phRsHeld ~= name then
              -- Fire once per push and remember it, so letting the stick
              -- go actually releases the bound button.
              local previous = self._phRsHeld
                and extras.pad[self._phRsHeld]
              if previous then
                releaseButton(self, previous, "rsx:" .. self._phRsHeld)
              end
              fireButton(self, extra, { id = "rsx:" .. name, kind = "axis",
                joystick = joystick, axis = axis,
                sign = value > 0 and 1 or -1 })
              self._phRsHeld = name
            end
            return
          end
          if math.abs(value or 0) < 0.3 then
            self._phRsLatch = nil
            local was = self._phRsHeld
            if was and ((axis == "rightx" and (was == "rs_left" or was == "rs_right"))
                  or (axis == "righty" and (was == "rs_up" or was == "rs_down"))) then
              local bound = extras.pad[was]
              if bound then releaseButton(self, bound, "rsx:" .. was) end
              self._phRsHeld = nil
            end
          end
          return
        end
        if (axis == "leftx" or axis == "lefty") and not leftOn then return end
        if (axis == "rightx" or axis == "righty") and not rightOn then return end
        if axis == "triggerleft" or axis == "triggerright" then
          local extra = extras.pad[axis]
          if extra and math.abs(value or 0) >= 0.55 then
            if extra:sub(1, 4) == "item" then
              if not self._phTrigLatch then
                self._phItemTap = extra
                self._phTrigLatch = true
              end
            elseif not (heldBy[extra] and heldBy[extra]["t:" .. axis]) then
              fireButton(self, extra, { id = "t:" .. axis, kind = "axis",
                joystick = joystick, axis = axis, sign = 1 })
            end
            return
          elseif math.abs(value or 0) < 0.3 then
            self._phTrigLatch = false
            if extra and extra:sub(1, 4) ~= "item" then
              releaseButton(self, extra, "t:" .. axis)
            end
          end
        end
        return origAxis(self, joystick, axis, value, ...)
      end
    end

    -- Once per frame: drop any press whose physical control is no longer
    -- held. Normally the release event already did this; this only acts
    -- when that event was lost.
    local function physicallyHeld(src)
      if src.kind == "key" then
        return love.keyboard and love.keyboard.isDown(src.key) or false
      end
      local js = src.joystick
      if not js or (js.isConnected and not js:isConnected()) then return false end
      if src.kind == "pad" then
        -- a left-stick "button" is the stick pushed that way, not a button
        local name = tostring(src.button or "")
        local stickDir = name:match("^leftstick_(%a+)$") or name:match("^ls(%a+)$")
        if stickDir then
          local axis = (stickDir == "up" or stickDir == "down") and "lefty" or "leftx"
          local sign = (stickDir == "up" or stickDir == "left") and -1 or 1
          local ok, v = pcall(js.getGamepadAxis, js, axis)
          return ok and (tonumber(v) or 0) * sign >= 0.3
        end
        -- a trigger is an axis too; asking for it as a button always says no,
        -- which let go of anything bound to a trigger on the next frame
        if name == "triggerleft" or name == "triggerright" then
          local ok, v = pcall(js.getGamepadAxis, js, name)
          return ok and (tonumber(v) or 0) >= 0.2
        end
        local ok, down = pcall(js.isGamepadDown, js, src.button)
        return ok and down == true
      end
      if src.kind == "axis" then
        local ok, v = pcall(js.getGamepadAxis, js, src.axis)
        return ok and (tonumber(v) or 0) * (src.sign or 1) >= 0.3
      end
      if src.kind == "stick" then
        local okx, x = pcall(js.getGamepadAxis, js, "rightx")
        local oky, y = pcall(js.getGamepadAxis, js, "righty")
        x, y = okx and tonumber(x) or 0, oky and tonumber(y) or 0
        local ax, ay = math.abs(x), math.abs(y)
        if ax < 0.3 and ay < 0.3 then return false end
        local dir = ax >= ay and (x > 0 and "right" or "left")
          or (y > 0 and "down" or "up")
        return dir == src.dir
      end
      return true
    end

    releaseHeld = function(input, all)
      if not input then return end
      for btn, sources in pairs(heldBy) do
        for id, src in pairs(sources) do
          if all or not physicallyHeld(src) then
            if id == "rs" then input._phRsDir = nil end
            if id:sub(1, 4) == "rsx:" then input._phRsHeld = nil end
            releaseButton(input, btn, id)
          end
        end
      end
    end

    -- Directions the game itself is holding (a press it re-armed after a
    -- focus change, or a lost release). While playing on a controller, a
    -- direction the game still holds with no D-pad, stick or bound key behind
    -- it for ~1/4 second is released, the same as tapping it.
    local DIRS = {
      up = { pad = "dpup", axis = "lefty", sign = -1, keys = { "up", "w" } },
      down = { pad = "dpdown", axis = "lefty", sign = 1, keys = { "down", "s" } },
      left = { pad = "dpleft", axis = "leftx", sign = -1, keys = { "left", "a" } },
      right = { pad = "dpright", axis = "leftx", sign = 1, keys = { "right", "d" } },
    }
    local orphanFrames = {}

    local function inputHolds(input, dir)
      if type(input.isDown) == "function" then
        local ok, down = pcall(input.isDown, input, dir)
        if ok then return down == true end
      end
      return input.state and input.state[dir] == true or false
    end

    local function anythingHolds(input, dir, spec)
      if heldBy[dir] and next(heldBy[dir]) ~= nil then return true end
      -- The on-screen D-pad, another mod's scripted hold and raw joysticks
      -- are real holds we have no way to look up physically.
      local live = input.sources and input.sources[dir]
      if live then
        for id in pairs(live) do
          local kind = tostring(id):match("^(%a+):")
          if kind ~= "pad" and kind ~= "key" then return true end
        end
      end
      local bound = packOf("bind_" .. dir)
      if love.keyboard then
        for _, key in ipairs(spec.keys) do
          if love.keyboard.isDown(key) then return true end
        end
        if bound.key and bound.key ~= "" then
          local ok, down = pcall(love.keyboard.isDown, bound.key)
          if ok and down then return true end
        end
      end
      local pads = love.joystick and love.joystick.getJoysticks
        and love.joystick.getJoysticks() or {}
      for _, js in ipairs(pads) do
        if js.isGamepad and js:isGamepad() then
          for _, button in ipairs({ spec.pad, bound.pad }) do
            if button and button ~= "" and not button:find("_", 1, true) then
              local ok, down = pcall(js.isGamepadDown, js, button)
              if ok and down then return true end
            end
          end
          local ok, v = pcall(js.getGamepadAxis, js, spec.axis)
          if ok and (tonumber(v) or 0) * spec.sign >= 0.4 then return true end
        end
      end
      return false
    end

    local function dropDirection(input, dir)
      local live = input.sources and input.sources[dir]
      if live and type(input.sourceRelease) == "function" then
        local ids = {}
        for id in pairs(live) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
          pcall(input.sourceRelease, input, dir, id)
        end
      end
      if input.state then input.state[dir] = false end
    end

    -- Keyboard and controller alike: every source the game lists for the
    -- direction is checked on its own key / button (core/held_dirs.lua), so
    -- a key bound in the game's CONTROLS still counts as held. It used to run
    -- only after controller input, so on the keyboard a lost release kept
    -- the cursor going (the PokéBox) until that direction was pressed again.
    local held = mod.highlander and mod.highlander.heldDirs
    local function ourHold(dir)
      return heldBy[dir] ~= nil and next(heldBy[dir]) ~= nil
    end

    local function releaseOrphanDirections(input)
      if held then
        held.guard(input, orphanFrames, 15, ourHold)
        return
      end
      if input._phLastDevice ~= "pad" then
        for dir in pairs(DIRS) do orphanFrames[dir] = nil end
        return
      end
      for dir, spec in pairs(DIRS) do
        if inputHolds(input, dir) and not anythingHolds(input, dir, spec) then
          orphanFrames[dir] = (orphanFrames[dir] or 0) + 1
          if orphanFrames[dir] >= 15 then
            orphanFrames[dir] = nil
            dropDirection(input, dir)
          end
        else
          orphanFrames[dir] = nil
        end
      end
    end

    local releaseTracked = releaseHeld
    releaseHeld = function(input, all)
      releaseTracked(input, all)
      if input then releaseOrphanDirections(input) end
    end
  end
  wrapInput()

  local function stockControlsRow(row)
    if type(row) ~= "table" then return false end
    local key = (tostring(row.label or "") .. " " .. tostring(row.id or "")):upper()
    if key:find("FULL CONTROL", 1, true) or key:find("RUMBLE", 1, true)
        or key:find("TOUCH", 1, true) then
      return false
    end
    return key:find("CONTROL", 1, true) ~= nil
  end

  local function stripControls(page)
    if type(page) ~= "table" then return page end
    for _, field in ipairs({ "rows", "items", "view" }) do
      local list = page[field]
      if type(list) == "table" then
        for i = #list, 1, -1 do
          if stockControlsRow(list[i]) then table.remove(list, i) end
        end
      end
    end
    return page
  end

  -- core/scope.lua parks component ui.options.rows hooks away from the game Options
  -- list. Hide stock Controls by wrapping OptionsMenu.new instead.
  pcall(function()
    local OM = require("src.ui.OptionsMenu")
    if type(OM) == "table" and type(OM.new) == "function" and not OM._phHideCtl then
      OM._phHideCtl = true
      local orig = OM.new
      function OM.new(game, ...)
        return stripControls(orig(game, ...))
      end
    end
  end)


  pcall(function()
    mod.hooks:wrap("input.gamepad", function(nextFn, game, payload)
      payload = payload or {}
      if payload.phase ~= "pressed" then
        return nextFn(game, payload)
      end
      local button = payload.button
      local joystick = payload.joystick
      local top = game.stack and game.stack.top and game.stack:top()
      if top and type(top.finish) == "function" and top.schemaKey then
        top:finish("pad", button)
        return
      end
      if top and type(top.onGamepadPressed) == "function" then
        top:onGamepadPressed(button)
        return
      end
      local extra = extras.pad[button]
      if extra and extra:sub(1, 4) == "item" then
        if game.input then game.input._phItemTap = extra end
        return
      end
      local ok, Input = pcall(require, "src.core.Input")
      local mapped = ok and (extra or (Input.padBindings and Input.padBindings[button]))
      if mapped then
        pcall(Input.gamepadpressed, game.input or Input, joystick, button)
        return
      end
      local act = ok and Input.padActions and Input.padActions[button]
      if act == "speedUp" then game:_cycleSpeed(1) return end
      if act == "speedDown" then game:_cycleSpeed(-1) return end
      -- Select+ face chords stay off; raw Back is not Select.
    end)
  end)

  local function say(game, lines)
    if type(lines) == "string" then lines = { lines } end
    if type(lines) ~= "table" then return end
    pcall(function()
      local TextBox = require("src.ui.TextBox")
      if type(TextBox.new) == "function" then
        game.stack:push(TextBox.new(game, lines))
      end
    end)
  end

  -- Same path as jj_quick_select / item_shortcut: ephemeral BagMenu + USE.
  local function useShortcut(game, slot)
    if not game then return end
    local items = mod.highlander and mod.highlander.itemShortcuts
    local id = items and type(items.get) == "function" and items.get(game.save, slot)
    if type(id) ~= "string" or id == "" then
      say(game, { "No item on shortcut " .. tostring(slot) .. "." })
      return
    end
    local inventory = game.save and game.save.inventory or {}
    local qty = inventory[id]
    if qty == nil or qty == false or qty == 0 then
      say(game, { "Registered item is not in the BAG." })
      return
    end
    local okBag, BagMenu = pcall(require, "src.ui.BagMenu")
    local okMenu, Menu = pcall(require, "src.ui.Menu")
    if not okBag or type(BagMenu.new) ~= "function" then
      say(game, { "The item shortcut could not open the Bag." })
      return
    end
    local okList, list = pcall(BagMenu.new, game, {})
    if not okList or type(list) ~= "table" then
      say(game, { "The item shortcut could not open the Bag." })
      return
    end
    local row
    for _, candidate in ipairs(list.items or {}) do
      if candidate.value == id or candidate.id == id or candidate.itemId == id then
        row = candidate
        break
      end
    end
    row = row or { value = id, id = id, itemId = id, label = id }
    if type(list.onChoose) ~= "function" then
      say(game, { "That item cannot be used from this shortcut." })
      return
    end
    local depth = #(game.stack.states or {})
    pcall(game.stack.push, game.stack, list)
    local okChoose = pcall(list.onChoose, row, list)
    if not okChoose then
      if game.stack:top() == list then game.stack:pop() end
      say(game, { "The item could not be used." })
      return
    end
    local top = game.stack:top()
    if top == list then
      -- Modern bag may use the item without a USE/TOSS submenu.
      return
    end
    if okMenu and type(top) == "table" and type(top.items) == "table"
        and top.items[1] and type(top.items[1].onSelect) == "function" then
      game.stack:pop()
      pcall(top.items[1].onSelect)
    end
    if game.stack:top() == list then
      game.stack:pop()
    end
  end

  local tapLatch = {}
  local function pollShortcuts(game)
    local function fire(tag, extra)
      if type(extra) ~= "string" or extra:sub(1, 4) ~= "item" then return end
      if tapLatch[tag] then return end
      tapLatch[tag] = true
      local slot = tonumber(extra:match("%d"))
      if slot then useShortcut(game, slot) end
    end
    for key, extra in pairs(extras.key) do
      local down = love.keyboard.isDown(key)
      if down then fire("k:" .. key, extra) else tapLatch["k:" .. key] = nil end
    end
    local pads = love.joystick.getJoysticks and love.joystick.getJoysticks()
    if type(pads) == "table" then
      for _, js in ipairs(pads) do
        for pad, extra in pairs(extras.pad) do
          local down = false
          if pad:sub(1, 3) == "rs_" or pad:sub(1, 3) == "ls_" then
            -- axis handled in gamepadaxis
          elseif js.isGamepadDown then
            local ok, v = pcall(js.isGamepadDown, js, pad)
            down = ok and v == true
          end
          local tag = "p:" .. pad
          if down then fire(tag, extra) else tapLatch[tag] = nil end
        end
      end
    end
  end

  pcall(function()
    mod.hooks:wrap("core.update", function(nextFn, game, dt)
      local result = nextFn(game, dt)
      local input = game and game.input
      if input and input._phItemTap then
        local tap = input._phItemTap
        input._phItemTap = nil
        local slot = tonumber((tap or ""):match("%d"))
        if slot then useShortcut(game, slot) end
      end
      pollShortcuts(game)
      if releaseHeld and input then pcall(releaseHeld, input, false) end
      return result
    end)
  end)

  -- SPEED- at NORMAL goes round to the top speed, as SPEED+ at the top goes
  -- round to NORMAL. The game's newer GameSpeed.step stops SPEED- at NORMAL
  -- (older builds used GameSpeed.cycle both ways), so from NORMAL, where most
  -- play happens, SPEED- did nothing whichever button it was on. Set on the
  -- live game so every road to it (the bound button, a trigger, the "0" key)
  -- behaves the same, and a game started without Full Control is untouched.
  local function wrapSpeedCycle(game)
    if type(game) ~= "table" or rawget(game, "_phSpeedWrap") then return end
    local base = game._cycleSpeed
    if type(base) ~= "function" then return end
    game._phSpeedWrap = true
    game._cycleSpeed = function(self, dir, ...)
      local okGS, GS = pcall(require, "src.core.GameSpeed")
      if not (tonumber(dir) and dir < 0 and okGS and type(GS) == "table"
          and type(GS.step) == "function" and type(GS.cycle) == "function") then
        return base(self, dir, ...)
      end
      local step = GS.step
      GS.step = GS.cycle
      local ok, err = pcall(base, self, dir, ...)
      GS.step = step
      if not ok then error(err, 0) end
    end
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("game.ready", function(ev)
      wrapSpeedCycle(ev and ev.game)
      applyBindings(ev and ev.game)
      local input = ev and ev.game and ev.game.input
      local ok, Input = pcall(require, "src.core.Input")
      if input and ok and type(Input) == "table" then
        input.gamepadpressed = Input.gamepadpressed
        input.gamepadreleased = Input.gamepadreleased
        input.gamepadaxis = Input.gamepadaxis
        if rawget(input, "keypressed") ~= nil then input.keypressed = Input.keypressed end
        if rawget(input, "keyreleased") ~= nil then input.keyreleased = Input.keyreleased end
        input.padAction = Input.padAction
        input.padBindings = Input.padBindings
        input.padActions = Input.padActions
      end
    end)
    mod.events:on("save.loaded", function()
      applyBindings(nil)
    end)
    mod.events:on("mod.options_changed", function()
      applyBindings(nil)
    end)
  end

  pcall(function()
    local Game = require("src.core.Game")
    if type(Game) == "table" and type(Game.keypressed) == "function"
        and not Game._phFullCtlKeys then
      Game._phFullCtlKeys = true
      local orig = Game.keypressed
      function Game:keypressed(key, scancode, isrepeat)
        local extra = extras.key[key]
        if extra and type(extra) == "string" and extra:sub(1, 4) == "item" then
          local slot = tonumber(extra:match("%d"))
          if slot then useShortcut(self, slot) end
          return
        end
        return orig(self, key, scancode, isrepeat)
      end
    end
  end)
end
