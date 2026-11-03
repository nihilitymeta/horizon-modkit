# Horizon Modkit

A library for mods of [Horizon](https://playhorizon.dev) written in Lua: entities, blocks and goals as classes with
lifecycle callbacks, the way a NeoForge or Fabric mod declares them, over the engine's Lua hook API. Install it
beside your mod; your mod says `depends = ["horizon_modkit"]` and `require("modkit")`.

It needs a game built from the engine fork [whos-carmen/horizon](https://github.com/whos-carmen/horizon), branch
`engine-work` (its `docs/lua-bindings.md` is the layer under this one; `docs/mods.md` the data files). Status:
experimental, as the `scripts` capability is.

## A mod with it

```toml
# horizon-mod.toml
capabilities = ["registries", "scripts"]
experimental = ["scripts"]
depends = ["horizon_modkit"]
```

```lua
-- scripts/init.lua
local modkit = require("modkit")
local M = modkit.mod("my_mod")

-- An entity: data/my_mod/horizon/entity_type/crawler.json declares it (a vanilla template with
-- your attributes, size, texture, flags and "goals": "none"); this is what it does.
local Crawler = M:entity("crawler")
Crawler:goals {
  { 1, modkit.goals.HuntPlayer(32, 1.2, 20) },
  { 5, modkit.goals.Wander(6) },
}
function Crawler:on_spawned(ev) horizon.log("crawler at " .. ev.x .. " " .. ev.y .. " " .. ev.z) end

-- A goal of your own: `self` is the goal's state for that mob (with timers), `mob` the mob.
local Bite = modkit.Goal {
  flags = { "look" },
  can_use = function(self, mob) return mob.target_in_melee_range end,
  tick = function(self, mob)
    if self:cooldown("bite", 20) then mob:attack("player") end
  end,
}
Crawler:goals { { 0, Bite } }

-- Goals on a vanilla mob too.
local Zombie = M:entity("minecraft:zombie")
Zombie:goals { { 0, modkit.Goal { flags = {}, can_use = function(self, mob) return mob:nearest("my_mod:crawler", 2) ~= nil end,
  tick = function(self, mob) if self:every("t", 60) then mob:convert("my_mod:crawler") end end } } }

-- A block: data/my_mod/horizon/block/hive.json declares it (template, states, random_ticks).
local Hive = M:block("hive")
function Hive:on_random_tick(block)
  if block.stage == "mature" then block:summon("my_mod:crawler", 0, 1, 1); block:handled() end
end
function Hive:on_use(block, player, held)
  if held and held.item == "minecraft:bone_meal" then block:set("stage", "growing"); block:cancel() end
end
```

Run: `horizon-client … --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my_mod` (or install both `.hmod`s and
turn them on). Edits are live on `/reload`. With `--dev-tools`, `/goals <mob>` shows the goals with their names,
`/lua` the mods, their handlers and errors ([dev-tools.md](https://github.com/whos-carmen/horizon/blob/egui-tools/docs/dev-tools.md)).

## API

### `modkit.mod(id)`

The mod: `M:entity(name)`, `M:block(name)` (`name` is `my_mod:name` unless it has a namespace already, so vanilla
kinds and blocks work), `M:on(hook, fn)` for a raw hook handler.

### Entities: `M:entity(name)`

| | |
|---|---|
| `E:goals { {priority, goal}, ... }` | goals every mob of this type gets, lower priority first |
| `E:target_goals { ... }` | the target selector's |
| `E.replace_goals = true` | drop the vanilla goals first (for a type that kept its template's) |
| `function E:on_tick(mob, state)` | every AI tick, as a goal of its own |
| `function E:on_spawned(ev)` | a mob of this type spawned: `ev.dimension`, `.x`, `.y`, `.z`, `.natural` |

### Goals: `modkit.Goal { ... }`

Fields: `flags` (`"move"`, `"look"`, `"jump"`, `"target"`: what the goal locks, as vanilla's `Goal.Flag`),
`every_tick`, `interruptable`, and the callbacks `can_use(self, mob)` (required), `can_continue`, `start`, `tick`,
`stop`. `self` is this goal's state for this mob, a table you may write to, with
`self:every(name, ticks)` (true once per `ticks` calls) and `self:cooldown(name, ticks)` (true when ready, then
waits `ticks`). Ready-made: `modkit.goals.Wander(reach, wait, radius)`, `modkit.goals.HuntPlayer(range, speed, cooldown)`.

### The mob (`mob` in a goal)

Fields of the view: `id`, `kind`, `position`, `velocity` (`{x, y, z}`), `yaw`, `head_pitch`, `health`,
`max_health`, `age`, `on_ground`, `in_water`, `in_lava`, `hurt_time`, `last_hurt_by`, `target` (`"player"`, a mob
id or nil), `target_position`, `target_in_melee_range`, `navigation_done`, `nearest_player`, `home`, `nearby`.

| Method | Does |
|---|---|
| `mob:navigate_to(x, y, z, speed)`, `mob:navigate_to_target(speed)`, `mob:stop_navigation()` | paths |
| `mob:move_toward(x, y, z, speed)`, `mob:look_at(x, y, z)`, `mob:look_at_target()`, `mob:jump()` | steering |
| `mob:set_target(who)`, `mob:attack(who)`, `mob:swing()`, `mob:hurt(who, amount)` | fighting; `who` is `"player"`, a mob id or nil |
| `mob:convert(kind)`, `mob:summon(kind, x, y, z)`, `mob:despawn()`, `mob:heal(amount)`, `mob:effect(name, ticks, amplifier)` | life |
| `mob:player_within(range)`, `mob:distance_to(p)`, `mob:nearby(filter)`, `mob:nearest(filter, range)` | reading; `filter` is a kind id or a function of a nearby record (`id`, `kind`, `position`, `distance`, `health`, `alive`, `hostile`, `baby`, `target`) |

Actions are applied in order after the callback returns; a script never holds the mob.

### Blocks: `M:block(name)`

| | |
|---|---|
| `function B:on_random_tick(block)` | the block's random tick (declare `random_ticks` in its data) |
| `function B:on_tick(block)` | a scheduled tick (`block:schedule_tick(delay)`) |
| `function B:on_use(block, player, held, face)` | a right click; `player` has `name`, `dimension`, `position`, `game_mode`; `held` has `item`, `count` |

`block` has `x`, `y`, `z`, `dimension`, `id`, its state properties as fields (`block.stage`), and
`block:set(key, value)`, `block:schedule_tick(delay)`, `block:handled()` (skip the vanilla tick), `block:cancel()`
(eat the click), `block:summon(kind, dx, dy, dz)`, `block:broadcast(line)`.

## Not yet

Block entities with saved data, hurt/death/interact callbacks on entities, models of your own, natural spawning,
spawn eggs: each arrives as the engine's hook points do. The registry entries (entity types, blocks, items) stay in
your mod's data files for now.

## License

MIT.
