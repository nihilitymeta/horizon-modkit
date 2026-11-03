# Horizon Modkit API

The modkit's classes and callbacks, over the engine's Lua hook API ([lua-bindings.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/lua-bindings.md)); the data a mod's files or registry script declare are in the engine's [mods.md](https://github.com/whos-carmen/horizon/blob/main/docs/mods.md).

## Declaring what the mod adds: `scripts/registry.lua`

The entity types, blocks, items, loot tables, recipes and tags a mod adds are declared in `scripts/registry.lua`,
which the game runs once at start (the engine's [lua-bindings.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/lua-bindings.md),
"Registering content from Lua"); JSON files under `data/` work too, and textures stay under `assets/`. The
modkit is not loaded there: the script is plain Luau with the `registry` table.

```lua
-- scripts/registry.lua
registry.entity_type("crawler", {
  template = "minecraft:zombie",
  attributes = { max_health = 30, movement_speed = 0.3, attack_damage = 4 },
  texture = registry.id .. ":entity/crawler",   -- assets/my_mod/textures/entity/crawler.png
  goals = "none",                                -- the class's goals are all it has
  flags = { burns_in_day = false },
})
registry.data("loot_table/entities/crawler", {
  type = "minecraft:entity",
  pools = { { rolls = 1, entries = { { type = "minecraft:item", name = "minecraft:slime_ball" } } } },
})
registry.block("hive", {
  template = "minecraft:sculk",
  properties = { hardness = 1.5, random_ticks = { property = "stage", values = { "dormant", "mature" } } },
  state_properties = { stage = { type = "enum", values = { "dormant", "mature" } } },
  default_state = { stage = "dormant" },
  item = true,
})
registry.data("minecraft:tags/block/mineable/hoe", { values = { registry.id .. ":hive" } })
```

## API

### `modkit.mod(id)`

The mod: `M:entity(name)`, `M:block(name)`, `M:item(name)` (`name` is `my_mod:name` unless it has a namespace already, so vanilla
kinds and blocks work), `M:on(hook, fn)` for a raw hook handler.

### Entities: `M:entity(name)`

| | |
|---|---|
| `E:goals { {priority, goal}, ... }` | goals every mob of this type gets, lower priority first |
| `E:target_goals { ... }` | the target selector's |
| `E.replace_goals = true` | drop the vanilla goals first (for a type that kept its template's) |
| `function E:on_spawned(ev)` | a mob of this type spawned: `ev.dimension`, `.kind`, `.x`, `.y`, `.z`, `.natural` |
| `function E:on_tick(mob)` | every server tick of every mob of this type (NeoForge's `tick`): `mob` is the view with `mob.data` and the host actions; keep it light |
| `function E:on_ai_tick(mob, state)` | every AI tick, as a goal of its own: the steering and fighting actions, `state` the goal's table |
| `function E:on_hurt(mob, hit)` | about to take damage: `hit.damage_type` (`minecraft:on_fire`...), `.causing`, `.direct` (entity ids, -1 none), `.amount`; `hit:set_amount(n)`, `hit:cancel()` refuses the hit. `mob` is `id` and `kind` only, no actions: the game is mid-hit |
| `function E:on_death(mob, cause)` | it died, by any cause: `cause.damage_type` (`minecraft:on_fire`...), `cause.causing` (the mob behind it, or 0), `cause.player` (the player credited, or nil); `mob` is `id` and `kind`, `mob.data` still readable |
| `function E:on_interact(mob, player, held)` | a player right-clicked it, before the mob and the item act; `held` has `item`, `count`, `plain` or is nil. Return `true` to take the click |

A callback is wired to the game's hook for the class's kind as soon as it is defined, so a kind without one costs
nothing each tick. `mob.data` in `on_tick`, `on_death` and `on_interact` is the mod's own saved table on that mob,
empty at first and kept with the mob through saves (the engine's attachment under the mod's id); what you change
in it is written back after the callback (a number keeps its NBT type, nil removes a key).

### Goals: `modkit.Goal { ... }`

Fields: `flags` (`"move"`, `"look"`, `"jump"`, `"target"`: what the goal locks, as vanilla's `Goal.Flag`),
`every_tick`, `interruptable`, and the callbacks `can_use(self, mob)` (required), `can_continue`, `start`, `tick`,
`stop`. `self` is this goal's state for this mob, a table you may write to, with
`self:every(name, ticks)` (true once per `ticks` calls) and `self:cooldown(name, ticks)` (true when ready, then
waits `ticks`). Ready-made: `modkit.goals.Wander(reach, wait, radius)`, `modkit.goals.HuntPlayer(range, speed, cooldown)`.

### The mob (`mob` in a goal or a callback)

Fields of the view: `id`, `kind`, `position`, `velocity` (`{x, y, z}`), `yaw`, `head_pitch`, `health`,
`max_health`, `age`, `on_ground`, `in_water`, `in_lava`, `hurt_time`, `last_hurt_by`, `target` (`"player"`, a mob
id or nil), `target_position`, `target_in_melee_range`, `navigation_done`, `nearest_player`, `home`, `nearby`
(in a goal; empty in a callback, where the world is not at hand). In a callback also `mob.dimension` and
`mob.data`; in `on_death` only `id` and `kind` remain.

| Method | Does |
|---|---|
| `mob:navigate_to(x, y, z, speed)`, `mob:navigate_to_target(speed)`, `mob:stop_navigation()` | paths |
| `mob:move_toward(x, y, z, speed)`, `mob:look_at(x, y, z)`, `mob:look_at_target()`, `mob:jump()` | steering |
| `mob:set_target(who)`, `mob:attack(who)`, `mob:swing()`, `mob:hurt(who, amount)` | fighting; `who` is `"player"`, a mob id or nil |
| `mob:convert(kind)`, `mob:effect(name, ticks, amplifier)` | life, in a goal |
| `mob:summon(kind, x, y, z)`, `mob:despawn()`, `mob:heal(amount)` | life, in a goal or a callback |
| `mob:set_health(h)`, `mob:kill()`, `mob:push(x, y, z)`, `mob:teleport(x, y, z)`, `mob:broadcast(line)` | by id, in a callback (`on_tick`, `on_death`, `on_interact`) |
| `mob:player_within(range)`, `mob:distance_to(p)`, `mob:nearby(filter)`, `mob:nearest(filter, range)` | reading; `filter` is a kind id or a function of a nearby record (`id`, `kind`, `position`, `distance`, `health`, `alive`, `hostile`, `baby`, `target`) |

Actions are applied in order after the callback returns; a script never holds the mob.

### Items: `M:item(name)`

| | |
|---|---|
| `function I:on_use(item, player)` | a right click in the air (or on a block that let it through); return `true` to take the use |
| `function I:on_use_on(item, player, block, face)` | a right click on a block (`block` has `x`, `y`, `z`, `id`; `face` is `{x, y, z}`); return `true` to take it |
| `function I:on_hit(item, player, target)` | a blow at `target` (`id`, `kind`, `position`) holding the item; return `true` and the blow does nothing |
| `function I:on_finished(item, player)` | eaten, drunk, or held for its `use_duration`; return an item id (and a count) for what stays in the hand |
| `function I:on_tick(item, player, slot, selected)` | every server tick the item sits in an inventory; keep it light |

`item` is `{id, count, damage, plain}` with `item:take(n)` and `item:give(n)` on the acting player's inventory.
The item itself is declared in `scripts/registry.lua` (`registry.item(name, { template = "minecraft:bone" })`)
with its model under `assets/`.

### Players: `M:players()`

| | |
|---|---|
| `function P:on_join(player)`, `on_leave`, `on_respawn` | a player joined the game, left it (by any path), respawned after a death |
| `function P:on_death(player, cause)` | a player died; `cause` is the death message's key (`death.attack.lava`) or nil |
| `function P:on_break_block(player, block)` | a player breaks a block (`block` has `x`, `y`, `z`, `id`); return `true` to keep it |
| `function P:on_place_block(player, block, item)` | a player placed a block from `item` |
| `function P:on_pickup(player, item, count)` | a player is about to pick up `count` of `item` (an id); return `true` to leave it |

### Reading the world

Inside any callback with a host (`on_tick`, `on_death`, `on_interact`, `on_spawned`, the block callbacks) the
engine's reads answer at once: `horizon.block(x, y, z)`, `horizon.block_property(x, y, z, key)`, `horizon.mob(id)`,
`horizon.mobs()`, `horizon.players()`, `horizon.player(name_or_uuid)`, `horizon.time()` (`day`, `time_of_day`,
`rain`, `thunder`) and `horizon.raycast(player, distance)` (what a player points at). `on_hurt` and goal functions
have no host: a goal reads its `mob` view instead. `mob:block_below()` and `block:above()` are the modkit's
shorthands for the block under a mob and over a block.

### Timers and saved data

`horizon.after(ticks, fn)` runs `fn` once after `ticks` server ticks, `horizon.every(ticks, fn)` every `ticks`
(a failing timer is logged, and a repeating one kept); inside, the reads and actions work. `horizon.world_data()`
is the mod's own saved table on the world and `horizon.player_data(player)` on a player (by name or UUID),
written back after the callback like `mob.data`, and kept through saves.

### Blocks: `M:block(name)`

| | |
|---|---|
| `function B:on_random_tick(block)` | the block's random tick (declare `random_ticks` in its data) |
| `function B:on_tick(block)` | a scheduled tick (`block:schedule_tick(delay)`) |
| `function B:on_use(block, player, held, face)` | a right click; `player` has `name`, `dimension`, `position`, `game_mode`; `held` has `item`, `count` |
| `B:block_entity { ticks = true, data = { charge = 0 } }` | every placed block of this kind gets a block entity: saved data per block (`data` is what a new one starts with), ticked each server tick when `ticks` |
| `function B:on_block_entity_tick(block)` | every server tick of a block with a block entity |
| `function B:on_break(block, player)` | a player breaks it; return `true` to keep it |
| `function B:on_place(block, player, item)` | a player placed it from `item` |

`block` has `x`, `y`, `z`, `dimension`, `id`, its state properties as fields (`block.stage`), `block.data` (the
block entity's saved table in every callback, nil for a block without one; what you change in it is saved after
the callback, a number keeps its NBT type, a key set to nil is gone), and `block:set(key, value)`,
`block:schedule_tick(delay)`, `block:handled()` (skip the vanilla tick), `block:cancel()` (eat the click),
`block:summon(kind, dx, dy, dz)`, `block:broadcast(line)`.

## Not yet

Models of your own, natural spawning, spawn eggs, timers and saved data per world or player, sounds and commands:
each arrives as the engine's hook points do.
