# Mobs and goals

A mob is an entity type declared in `scripts/registry.lua` (a vanilla mob as the template, the attributes that
differ, `goals = "none"` so the scripts give it all of its behaviour) and an entity class in a script with its
goals and callbacks. Example: [scripts/example/mob.lua](../../examples/example_mod/scripts/example/mob.lua),
declared in [scripts/registry.lua](../../examples/example_mod/scripts/registry.lua); goals on a vanilla kind in
[scripts/example/conversion.lua](../../examples/example_mod/scripts/example/conversion.lua). Reference:
[api.md, Entities](../api.md#entities-mentityname), [Goals](../api.md#goals-modkitgoal---),
[The mob](../api.md#the-mob-mob-in-a-goal-or-a-callback).

```lua
local Mob = M:entity("example_mob")

-- A goal of the mod's own: come to the nearest player within eight blocks.
-- `flags` say what it locks (move, look, jump, target), as vanilla's goals
-- do; `self` is this goal's table on this mob, with self:every(name, ticks)
-- and self:cooldown(name, ticks).
local Approach = modkit.Goal {
  flags = { "move", "look" },
  can_use = function(self, mob) return mob:player_within(8) end,
  tick = function(self, mob)
    local p = mob.nearest_player
    if not p then return end
    mob:look_at(p.x, p.y + 1.6, p.z)
    if mob.navigation_done or self:every("path", 20) then mob:navigate_to(p.x, p.y, p.z, 1.0) end
  end,
  stop = function(self, mob) mob:stop_navigation() end,
}

-- Its goals, lower priority first; modkit.goals has ready-made ones.
Mob:goals {
  { 1, Approach },
  { 5, modkit.goals.Wander(6, 80, 16) },
}
```

**Goals** are what a mob does when nothing more pressing applies: `can_use(self, mob)` says when, `tick` acts
each tick, `start` and `stop` bracket it, `flags` are what it locks (two goals that both move cannot run at
once), and the priority orders them. `modkit.goals.Wander` and `modkit.goals.HuntPlayer` are ready-made;
conversion.lua's `Stalk` and `Succumb` are two more. Inside a goal, `mob` is the view: `position`, `health`,
`target`, `nearest_player`, `navigation_done`, `nearby`, and the steering and fighting actions (`navigate_to`,
`look_at`, `attack`, `set_target`, `effect`, `summon`, `convert`).

**Callbacks** come as things happen: `on_spawned(ev)`, `on_tick(mob)`, `on_interact(mob, player, held)` (a
right click; return true to take it), `on_hurt(mob, hit)` (`hit:cancel()`, `hit:set_amount(n)`), `on_fall`,
`on_knockback`, `on_equip`, `on_death(mob, cause)`, `on_drops(mob, drops, source)` (change the loot in place).
`mob.data` in a callback is the mod's own saved table on that mob, kept through saves.

**Vanilla mobs too.** `M:entity("minecraft:zombie")` adds goals and callbacks to every zombie, beside the ones it
has. The example makes zombies stalk players and, beside an example mob for three seconds, become one:
`mob:nearest(kind, range)` reads the goal's view of the mobs around, `mob:convert(kind)` swaps the mob for another
kind, equipment and name kept.

```lua
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
```

**Its look** is the template's unless the declaration names a `texture`, a `model`, an `animation` set and
`sounds`: [models and animation](models-and-animation.md). **Where it appears:** [spawning](spawning.md).

See it in game: `/example spawn`, hold wheat and right-click it, hit it with the feather, set it on fire;
`/summon zombie` beside it and wait three seconds.
