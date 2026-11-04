-- Goals on a vanilla kind, and a conversion (guide: docs/guides/mobs.md;
-- reference: docs/api.md, "Entities", "Goals"). M:entity("minecraft:zombie")
-- adds goals to every zombie beside the ones it has: with an example mob at
-- its side for three seconds it succumbs and becomes one (mob:convert keeps
-- its equipment and name); otherwise it stalks the nearest player from afar,
-- below its melee attack (2 in vanilla), so a fight still wins.
-- See it in game: /example spawn, then /summon zombie beside it and wait
-- three seconds; /goals @e[type=zombie,sort=nearest,limit=1] lists
-- example_mod:zombie.succumb and zombie.stalk.
local modkit = require("@modkit")
local M = require("@example/mod")

local Zombie = M:entity("minecraft:zombie")

-- No flags: it runs beside whatever else the zombie does. mob:nearest(kind,
-- range) reads the goal's view of the mobs around (nearest first).
local Succumb = modkit.Goal {
  name = "succumb",
  flags = {},
  can_use = function(self, mob) return mob:nearest("example_mod:example_mob", 2.5) ~= nil end,
  start = function(self, mob) self.ticks = 0 end,
  tick = function(self, mob)
    self.ticks = self.ticks + 1
    if self.ticks == 60 then
      mob:effect("minecraft:nausea", 100)
      mob:convert("example_mod:example_mob")
      horizon.log("EXAMPLE conversion: a zombie became an example mob")
    end
  end,
}

-- A low priority: the zombie's own attack goal (1) wins when it has a target.
local Stalk = modkit.Goal {
  name = "stalk",
  flags = { "move", "look" },
  can_use = function(self, mob) return mob:player_within(24) end,
  tick = function(self, mob)
    local p = mob.nearest_player
    if not p then return end
    mob:look_at(p.x, p.y + 1.6, p.z)
    if mob.navigation_done or self:every("path", 20) then mob:navigate_to(p.x, p.y, p.z, 1.1) end
  end,
  stop = function(self, mob) mob:stop_navigation() end,
}

Zombie:goals { { 0, Succumb }, { 3, Stalk } }

return Zombie
