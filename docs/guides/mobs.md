# Mobs and Goals

A mob has two parts. You declare its entity type in `scripts/registry.lua` or a module it requires: a vanilla mob as
the template, the attributes that differ, and `goals = "none"`, so that your scripts give it all its behaviour. Then
an entity class in a script gives it goals and callbacks.

The examples on this page come from the example mod:

- [scripts/server/example/mob.lua](../../examples/example_mod/scripts/server/example/mob.lua): a mob of the mod's own
- [scripts/server/example/conversion.lua](../../examples/example_mod/scripts/server/example/conversion.lua): goals added to a
  vanilla mob
- [scripts/registry/mobs.lua](../../examples/example_mod/scripts/registry/mobs.lua): the mob's declaration

The reference is [Entity classes](../api.md#entity-classes), [Goals](../api.md#goals) and
[The mob](../api.md#the-mob).

## A mob that follows players

This mob walks up to the nearest player, and wanders when nobody is near:

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

## Goals

A goal is something a mob does when nothing more pressing applies:

- `can_use(self, mob)` decides when the goal starts.
- `tick` acts each tick while it runs.
- `start` and `stop` run when it starts and stops.
- `flags` say what the goal locks. Two goals that both lock movement can't run at once.
- The priority orders the goals. A lower number comes first.

`modkit.goals.Wander` and `modkit.goals.HuntPlayer` are ready to use. conversion.lua's `Stalk` and `Succumb` are two
more examples.

Inside a goal, `mob` is a view of the mob: `position`, `health`, `target`, `nearest_player`, `navigation_done` and
`nearby`, with the steering and fighting actions, such as `navigate_to`, `look_at`, `attack`, `set_target`,
`effect`, `summon` and `convert`.

## Callbacks

Callbacks run when something happens to the mob:

| Callback | When it runs |
|---|---|
| `on_spawned(ev)` | the mob spawns |
| `on_tick(mob)` | every tick |
| `on_interact(mob, player, held)` | a player right-clicks it. Return true to take the click |
| `on_hurt(mob, hit)` | it is about to take damage. `hit:cancel()` refuses it, `hit.amount = n` changes it |
| `on_fall`, `on_knockback` | it is about to land, or to be knocked back. Assign the fields to change them |
| `on_equip` | its equipment changes |
| `on_death(mob, cause)` | it dies. `cause.player` is the killer's uuid, or nil |
| `on_drops(mob, drops, source)` | its loot is about to drop. Change `drops` in place |

Each mob keeps its own saved table, `mob.data`, read from `horizon.entity_data` on first use and written back
after the callback, as the feeding count in mob.lua does. It reads nil in a goal and where there is no host.

## Vanilla mobs

`M:entity("minecraft:zombie")` adds goals and callbacks to every zombie, next to the goals it already has. The
example makes zombies stalk players. A zombie that stays next to an example mob for three seconds becomes one.
`mob:nearest(kind, range)` finds the mobs around, and `mob:convert(kind)` replaces the zombie with another kind,
keeping its equipment and name:

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

## Look and spawning

A mob looks like its template unless its declaration names a `texture`, a `model`, an `animation` set and `sounds`.
The [models and animation](models-and-animation.md) guide covers these. The [spawning](spawning.md) guide covers
where mobs appear.

## See it in the game

- `/example spawn`, then hold wheat and right-click the mob, hit it with the feather, and set it on fire.
- `/summon zombie` next to an example mob, then wait three seconds.
