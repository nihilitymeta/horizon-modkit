-- A mob as a goal or callback sees it: the view's fields (`mob.health`,
-- `mob.position`, `mob.target`, `mob.nearby`...) and methods that ask the
-- game to act, applied in order after the call.
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

-- Movement and looking.
function Mob:navigate_to(x, y, z, speed) self._out.navigate_to(x, y, z, speed or 1.0) end
function Mob:navigate_to_target(speed) self._out.navigate_to_target(speed or 1.0) end
function Mob:stop_navigation() self._out.stop_navigation() end
function Mob:move_toward(x, y, z, speed) self._out.move_toward(x, y, z, speed or 1.0) end
function Mob:look_at(x, y, z) self._out.look_at(x, y, z) end
function Mob:look_at_target() self._out.look_at_target() end
function Mob:jump() self._out.jump() end

-- Targets and fighting. `who` is "player", a mob id or nil.
function Mob:set_target(who) self._out.set_target(who) end
function Mob:attack(who) self._out.attack(who) end
function Mob:swing() self._out.swing() end
function Mob:hurt(who, amount) self._out.hurt(who, amount) end

-- Life. `convert` makes this mob one of `kind` (equipment and name kept).
function Mob:convert(kind) self._out.convert(kind) end
function Mob:summon(kind, x, y, z) self._out.summon(kind, x, y, z) end
function Mob:despawn() self._out.despawn() end
function Mob:heal(amount) self._out.heal(amount) end
function Mob:effect(name, ticks, amplifier) self._out.effect(name, ticks or 200, amplifier or 0) end

-- Reading.
function Mob:distance_to(p) return horizon.distance(self._view.position, p) end

--- Whether a player stands within `range` blocks.
function Mob:player_within(range)
  local p = self._view.nearest_player
  return p ~= nil and horizon.distance(self._view.position, p) <= range
end

--- The nearby mobs (nearest first) that `filter` accepts: a kind id, or a
--- function of the nearby record; all of them without one.
function Mob:nearby(filter)
  local out = {}
  for _, other in ipairs(self._view.nearby) do
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
