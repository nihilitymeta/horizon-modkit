-- A mob as a goal or a lifecycle callback sees it: the view's fields
-- (`mob.health`, `mob.position`, `mob.target`, `mob.nearby`...) and methods
-- that ask the game to act, applied in order after the call.
--
-- In a goal (`can_use`, `tick`...) the mob is wrapped with the goal's `out`
-- table: steering, fighting and life actions on this mob. In a lifecycle
-- callback (`on_tick`, `on_death`, `on_interact`) it is wrapped with the
-- hook's dimension and `mob.data`, the mod's saved table on the mob; the
-- actions there go by the mob's id (`set_health`, `push`, `teleport`,
-- `kill`, `remove`, `summon`, `broadcast`). `on_hurt` has neither.
local Mob = {}
Mob.__index = function(self, key)
  local method = Mob[key]
  if method ~= nil then return method end
  return rawget(self, "_view")[key]
end

--- Wraps a view and an `out` table of a goal call.
function Mob.wrap(view, out)
  return setmetatable({ _view = view, _out = out }, Mob)
end

--- Wraps a view (or `{id, kind}`) of a lifecycle hook with a host: the
--- dimension the mob is in and `data`, its saved table (nil when the hook
--- has none).
function Mob.host(view, dimension, data)
  return setmetatable({ _view = view, dimension = dimension, data = data }, Mob)
end

local function goal_out(self, name)
  local out = self._out
  if not out then error("mob:" .. name .. " works in a goal only (can_use, tick...)", 3) end
  return out
end

local function host_action(self, name, ...)
  if not self.dimension then error("mob:" .. name .. " needs a hook with a host (not on_hurt)", 3) end
  horizon[name](self.dimension, self._view.id, ...)
end

-- Movement and looking (goals).
function Mob:navigate_to(x, y, z, speed) goal_out(self, "navigate_to").navigate_to(x, y, z, speed or 1.0) end
function Mob:navigate_to_target(speed) goal_out(self, "navigate_to_target").navigate_to_target(speed or 1.0) end
function Mob:stop_navigation() goal_out(self, "stop_navigation").stop_navigation() end
function Mob:move_toward(x, y, z, speed) goal_out(self, "move_toward").move_toward(x, y, z, speed or 1.0) end
function Mob:look_at(x, y, z) goal_out(self, "look_at").look_at(x, y, z) end
function Mob:look_at_target() goal_out(self, "look_at_target").look_at_target() end
function Mob:jump() goal_out(self, "jump").jump() end

-- Targets and fighting (goals). `who` is "player", a mob id or nil.
function Mob:set_target(who) goal_out(self, "set_target").set_target(who) end
function Mob:attack(who) goal_out(self, "attack").attack(who) end
function Mob:swing() goal_out(self, "swing").swing() end
function Mob:hurt(who, amount) goal_out(self, "hurt").hurt(who, amount) end
function Mob:convert(kind) goal_out(self, "convert").convert(kind) end
function Mob:effect(name, ticks, amplifier) goal_out(self, "effect").effect(name, ticks or 200, amplifier or 0) end

-- Life: in a goal through its actions, in a callback through the host.
function Mob:summon(kind, x, y, z)
  if self._out then self._out.summon(kind, x, y, z) else host_action(self, "summon", kind, x, y, z) end
end
--- Out of the world with no death and no loot.
function Mob:despawn()
  if self._out then self._out.despawn() else host_action(self, "remove_mob") end
end
Mob.remove = Mob.despawn
function Mob:heal(amount)
  if self._out then self._out.heal(amount) else self:set_health(self._view.health + amount) end
end

-- By id, in a callback with a host.
--- Health, cut to the mob's maximum.
function Mob:set_health(health) host_action(self, "set_mob_health", health) end
--- Dies as `/kill` does: it falls and drops its loot.
function Mob:kill() host_action(self, "kill_mob") end
--- Adds to the mob's velocity.
function Mob:push(x, y, z) host_action(self, "push_mob", x, y, z) end
--- Moves it at once, as `/tp` does.
function Mob:teleport(x, y, z) host_action(self, "teleport_mob", x, y, z) end
function Mob:broadcast(line) horizon.broadcast(line) end

-- Reading.
function Mob:distance_to(p) return horizon.distance(self._view.position, p) end
--- The block the mob stands on (a callback with a host; see docs/api.md).
function Mob:block_below()
  local p = self._view.position
  return horizon.block(math.floor(p.x), math.floor(p.y) - 1, math.floor(p.z))
end

--- Whether a player stands within `range` blocks.
function Mob:player_within(range)
  local p = self._view.nearest_player
  return p ~= nil and horizon.distance(self._view.position, p) <= range
end

--- The nearby mobs (nearest first) that `filter` accepts: a kind id, or a
--- function of the nearby record; all of them without one. Empty outside a
--- goal: only there the world is at hand.
function Mob:nearby(filter)
  local out = {}
  for _, other in ipairs(self._view.nearby or {}) do
    if filter == nil
      or (type(filter) == "string" and other.kind == filter)
      or (type(filter) == "function" and filter(other)) then
      out[#out + 1] = other
    end
  end
  return out
end

--- The nearest mob `filter` accepts within `range` blocks, or nil.
function Mob:nearest(filter, range)
  for _, other in ipairs(self:nearby(filter)) do
    if range == nil or other.distance <= range then return other end
  end
  return nil
end

return Mob
