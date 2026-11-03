-- Goals that come with the library.
local Goal = require("modkit.goal")
local goals = {}

--- Wander: every `wait` ticks (80) with nobody within `radius` (32) blocks,
--- walk to a point up to `reach` (6) blocks away.
function goals.Wander(reach, wait, radius)
  reach, wait, radius = reach or 6, wait or 80, radius or 32
  return Goal.new {
    name = "wander",
    flags = { "move" },
    can_use = function(self, mob)
      return self:every("wait", wait) and not mob:player_within(radius)
    end,
    start = function(self, mob)
      local p = mob.position
      mob:navigate_to(p.x + math.random(-reach, reach), p.y, p.z + math.random(-reach, reach), 0.8)
    end,
    can_continue = function(self, mob) return not mob.navigation_done end,
    stop = function(self, mob) mob:stop_navigation() end,
  }
end

--- Hunt: target the nearest player within `range` (32), walk at them at
--- `speed` (1.2) and hit every `cooldown` (20) ticks when in reach.
function goals.HuntPlayer(range, speed, cooldown)
  range, speed, cooldown = range or 32, speed or 1.2, cooldown or 20
  return Goal.new {
    name = "hunt_player",
    flags = { "move", "look", "target" },
    can_use = function(self, mob) return mob:player_within(range) end,
    start = function(self, mob) mob:set_target("player") end,
    tick = function(self, mob)
      mob:look_at_target()
      if mob.navigation_done or self:every("path", 10) then mob:navigate_to_target(speed) end
      if mob.target_in_melee_range and self:cooldown("hit", cooldown) then
        mob:swing()
        mob:attack("player")
      end
    end,
    stop = function(self, mob)
      mob:stop_navigation()
      mob:set_target(nil)
    end,
  }
end

return goals
