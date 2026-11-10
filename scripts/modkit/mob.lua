-- A mob as a goal or a lifecycle callback sees it: the view's fields
-- (`mob.health`, `mob.position`, `mob.target`, `mob.nearby`...) and methods
-- that ask the game to act, applied in order after the call.
--
-- In a goal (`can_use`, `tick`...) the mob is wrapped with the goal's `out`
-- table: steering, fighting and life actions on this mob. In a lifecycle
-- callback (`on_tick`, `on_death`, `on_interact`) it is wrapped with the
-- hook's dimension; the actions there go by the mob's id (`set_health`,
-- `push`, `teleport`, `kill`, `remove`, `summon`, `broadcast`). The events
-- carry no per-mob saved table and no view, so `dimension` may be nil and the
-- view's fields (position, health...) read nil outside a goal. `on_hurt`,
-- `on_fall` and `on_knockback` have neither.
local Mob = {}
Mob.__index = function(self, key)
  local method = Mob[key]
  if method ~= nil then return method end
  return (rawget(self, "_view") :: any)[key]
end

--- Creates a mob from the view and the `out` table of a goal call.
function Mob.wrap(view, out)
  return setmetatable({ _view = view, _out = out }, Mob)
end

--- Creates a mob from the view (or `{id, kind}`) of a lifecycle hook, with
--- the dimension the mob is in and `data`, its saved table (nil: the native
--- hooks carry none).
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
--- Walks a path to a position, at `speed` (1.0). In a goal.
function Mob:navigate_to(x, y, z, speed) goal_out(self, "navigate_to").navigate_to(x, y, z, speed or 1.0) end
--- Walks a path to the mob's target, at `speed` (1.0). In a goal.
function Mob:navigate_to_target(speed) goal_out(self, "navigate_to_target").navigate_to_target(speed or 1.0) end
--- Stops walking. In a goal.
function Mob:stop_navigation() goal_out(self, "stop_navigation").stop_navigation() end
--- Steps straight toward a position, with no path. In a goal.
function Mob:move_toward(x, y, z, speed) goal_out(self, "move_toward").move_toward(x, y, z, speed or 1.0) end
--- Turns the head toward a position. In a goal.
function Mob:look_at(x, y, z) goal_out(self, "look_at").look_at(x, y, z) end
--- Turns the head toward the target. In a goal.
function Mob:look_at_target() goal_out(self, "look_at_target").look_at_target() end
--- Jumps. In a goal.
function Mob:jump() goal_out(self, "jump").jump() end

-- Targets and fighting (goals). `who` is "player", a mob id or nil.
--- Sets the mob's target: "player", a mob id, or nil to clear it. In a goal.
function Mob:set_target(who) goal_out(self, "set_target").set_target(who) end
--- Attacks `who`, as the mob's melee attack does. In a goal.
function Mob:attack(who) goal_out(self, "attack").attack(who) end
--- Swings the arm. In a goal.
function Mob:swing() goal_out(self, "swing").swing() end
--- Deals `amount` damage to `who`. In a goal.
function Mob:hurt(who, amount) goal_out(self, "hurt").hurt(who, amount) end
--- Replaces the mob with one of `kind`, keeping its equipment and name. In a goal.
function Mob:convert(kind) goal_out(self, "convert").convert(kind) end
--- Gives a status effect for `ticks` (200) at `amplifier` (0). In a goal, or
--- a callback with a host.
function Mob:effect(name, ticks, amplifier)
  if self._out then
    self._out.effect(name, ticks or 200, amplifier or 0)
  elseif self.dimension then
    horizon.effect(self._view.id, name, ticks or 200, amplifier or 0)
  else
    error("mob:effect needs a goal or a hook with a host (not on_hurt)", 2)
  end
end

-- Life: in a goal through its actions, in a callback through the host.
--- Makes a mob of `kind` at a position. In a goal, or a callback with a host.
function Mob:summon(kind, x, y, z)
  if self._out then self._out.summon(kind, x, y, z) else host_action(self, "summon", kind, x, y, z) end
end
--- Removes the mob, with no death and no loot. In a goal, or a callback
--- with a host.
function Mob:despawn()
  if self._out then self._out.despawn() else host_action(self, "remove_mob") end
end
Mob.remove = Mob.despawn
--- Adds `amount` health. In a goal, or a callback with a host.
function Mob:heal(amount)
  if self._out then self._out.heal(amount); return end
  if not self.dimension then error("mob:heal needs a goal or a hook with a host (not on_hurt)", 2) end
  local health = self._view.health
  if health == nil then error("mob:heal needs the mob's view (not on_death)", 2) end
  self:set_health(health + amount)
end

-- By id, in a callback with a host.
--- Sets the health, up to the mob's maximum.
function Mob:set_health(health: number) host_action(self, "set_mob_health", health) end
--- Kills the mob as `/kill` does, with its loot.
function Mob:kill() host_action(self, "kill_mob") end
--- Adds to the mob's velocity.
function Mob:push(x: number, y: number, z: number) host_action(self, "push_mob", x, y, z) end
--- Moves the mob at once, as `/tp` does.
function Mob:teleport(x: number, y: number, z: number) host_action(self, "teleport_mob", x, y, z) end
--- Sends a chat line to every player.
function Mob:broadcast(line: string) horizon.broadcast(line) end

-- Reading.
--- Gets the distance to a position, in blocks.
function Mob:distance_to(p: Vec3): number return horizon.distance(self._view.position, p) end
--- Gets the id of the block under the mob. Needs a callback with a host.
function Mob:block_below(): string
  local p = self._view.position
  return horizon.block(math.floor(p.x), math.floor(p.y) - 1, math.floor(p.z))
end

--- Checks whether a player stands within `range` blocks.
function Mob:player_within(range: number): boolean
  local p = self._view.nearest_player
  return p ~= nil and horizon.distance(self._view.position, p) <= range
end

--- Gets the nearby mobs that `filter` accepts, nearest first. `filter` is a
--- kind id or a function of the nearby record; all of them without one.
--- Empty outside a goal, where the world is not at hand.
function Mob:nearby(filter: (string | (Nearby) -> boolean)?): { Nearby }
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

--- Gets the nearest mob that `filter` accepts within `range` blocks, or nil.
function Mob:nearest(filter: (string | (Nearby) -> boolean)?, range: number?): Nearby?
  for _, other in ipairs(self:nearby(filter)) do
    if range == nil or other.distance <= range then return other end
  end
  return nil
end

return Mob
