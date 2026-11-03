-- A goal class: decisions over a `mob` (modkit.mob) with a per-mob `self`
-- that keeps the goal's state for that mob and offers timers.
--
--   local Hunt = modkit.Goal {
--     name = "hunt",                            -- shown by /goals as <mod>:<entity>.hunt
--     flags = { "move", "look", "target" },   -- what the goal locks (as vanilla's Goal.Flag)
--     every_tick = false, interruptable = true,
--     can_use = function(self, mob) return mob:player_within(32) end,
--     can_continue = function(self, mob) ... end,   -- can_use again by default
--     start = function(self, mob) end,
--     tick = function(self, mob) end,
--     stop = function(self, mob) end,
--   }
local Mob = require("@modkit/mob")

local State = {}
State.__index = State

--- Counts a tick on timer `name` and tells whether `ticks` passed since it
--- last fired (then resets), so `if self:every("step", 20) then ... end`.
function State:every(name, ticks)
  local t = (self[name] or 0) + 1
  if t >= ticks then
    self[name] = 0
    return true
  end
  self[name] = t
  return false
end

--- Whether timer `name` is ready; when it is, it is set to `ticks` and
--- counts down a tick per call: `if self:cooldown("bite", 20) then bite() end`.
function State:cooldown(name, ticks)
  local left = self[name] or 0
  if left <= 0 then
    self[name] = ticks
    return true
  end
  self[name] = left - 1
  return false
end

local Goal = {}
Goal.__index = Goal

function Goal.new(def)
  assert(type(def) == "table" and type(def.can_use) == "function", "modkit.Goal: can_use(self, mob) is required")
  return setmetatable({ def = def, registered = {} }, Goal)
end

local function wrap(fn)
  if fn == nil then return nil end
  return function(view, state, out)
    return fn(setmetatable(state, State), Mob.wrap(view, out))
  end
end

--- Registers the goal with the game under `name` once, and answers it.
function Goal:register(name)
  if not self.registered[name] then
    local d = self.def
    horizon.goal(name, {
      flags = d.flags or {},
      every_tick = d.every_tick,
      interruptable = d.interruptable,
      can_use = wrap(d.can_use),
      can_continue = wrap(d.can_continue),
      start = wrap(d.start),
      tick = wrap(d.tick),
      stop = wrap(d.stop),
    })
    self.registered[name] = true
  end
  return name
end

return Goal
