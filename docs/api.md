# Horizon Modkit API

The modkit's classes and callbacks, over the engine's Lua hook API ([lua-bindings.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/lua-bindings.md); every hook point of the engine and the Lua handler it reaches: [hook-points.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/api/hook-points.md)); the data a mod's files or registry script declare are in the engine's [mods.md](https://github.com/whos-carmen/horizon/blob/main/docs/mods.md).

## Versions

The modkit's version is written once, in its `horizon-mod.toml`; `modkit.VERSION` reads it from the engine
(`horizon.libraries.horizon_modkit` in a mod that depends on it). A mod names the least version it needs with
`depends = ["horizon_modkit >= 0.7"]`: the game checks it at load and does not load the mod when the modkit is
older, with a log line that says what it found (`Horizon: Lua mod my_mod not loaded: it needs horizon_modkit >= 0.7
(found 0.6.0), ...`); `cargo horizon-mod check` says the same without a game.

## Starting a mod

`cargo horizon-mod new <path> --template lua` scaffolds a scripted mod on the modkit: a manifest with
`registries` and `scripts` and `depends = ["horizon_modkit"]`, `scripts/registry.lua` with one item (a wand),
`scripts/init.lua` with its `on_use`, `assets/<id>/lang/en_us.json`, a `.luaurc` that names the modkit checkout
beside it for an editor, and a README. `cargo horizon-mod build` packs it, `cargo horizon-mod check` reads the
`.hmod`, `cargo horizon-mod run -- --dev-mod /path/to/horizon-modkit` plays it.

`cargo horizon-mod check <folder> --game <horizon-client> --dev-mod /path/to/horizon-modkit` loads the scripts
headlessly in the game's Lua runtime before any world: a script that fails to load, a hook `horizon.on` does not
know, a command that errors when declared, each with its file and line, exit code 1. The modkit's
`tools/check.sh` runs it on the modkit itself and on a mod folder given (`--self-test` shows a misspelled hook
refused with its line).

## In an editor

`types/horizon.d.lua` (the engine's generated `docs/api/horizon.d.lua`) declares `horizon` and `registry`, every
function, every hook's handler signature and the tables a script gets; the modkit's own classes are annotated with
them. With [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) in the editor, pointed at that file as a
definitions file, `M:entity`, `M:block`, `M:item`, `M:players`, `M:command` and the `player`, `mob` and `block`
tables complete, and a misspelled function or hook is marked. A mod's `.luaurc` names this checkout so
`require("@modkit")` resolves (the Lua template writes one). From a shell:

```sh
luau-lsp analyze --definitions @horizon=/path/to/horizon-modkit/types/horizon.d.lua --platform=standard scripts
```

`tools/check.sh` runs it on the modkit and on the mods given, after the headless load.

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

The mod: `M:entity(name)`, `M:block(name)`, `M:item(name)`, `M:players()`, `M:command(usage, level, fn)` (`name` is `my_mod:name` unless it has a namespace already, so vanilla
kinds and blocks work), `M:config(defaults)` for its settings, `M:on(hook, fn)` for a raw hook handler.

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
| `function E:on_fall(mob, fall)` | about to land: `fall.distance`, `fall.multiplier`; `fall:set_distance(n)`, `fall:set_multiplier(n)`, `fall:cancel()` (no fall damage). `mob` is `id` and `kind` only: no host |
| `function E:on_knockback(mob, hit)` | about to be pushed back: `hit.strength` (raw), `hit.x`, `hit.z` (the direction), `hit.damage_type`, `hit.causing`; `hit:set_strength(n)`, `hit:cancel()`. No host |
| `function E:on_equip(mob, slot, from, to)` | an equipment slot (`mainhand`, `offhand`, `head`...) took a different stack: `from` and `to` are item tables or nil |
| `function E:on_drops(mob, drops, source)` | it died and its loot is about to drop: `drops` is a sequence of `{id, count, damage, plain}` to change in place (add entries, change counts, remove some); `source` has `table`, `player` (the killer, or nil), `tool` |

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
| `mob:convert(kind)` | life, in a goal |
| `mob:effect(name, ticks, amplifier)`, `mob:summon(kind, x, y, z)`, `mob:despawn()`, `mob:heal(amount)` | life, in a goal or a callback (`effect` as `/effect give`: 200 ticks and amplifier 0 by default; `summon` in a callback answers the new mob's id) |
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
| `function I:on_crafted(item, player, recipe)` | a player took it from a crafting grid (`recipe` the recipe's id) |
| `function I:on_dropped(item, player, count)` | a player threw `count` of it |
| `function I:on_hurt_enemy(item, player, target)` | a blow with it landed on `target` (`id`, `kind`), after the damage (`on_hit` is before it) |
| `function I:on_use_start(item, player, hand, duration)` | a use over time starts (eating, drinking, drawing; `hand` `"main"` or `"off"`, `duration` in ticks): return a number to change the duration, `true` to stop the use |

`item` is `{id, count, damage, plain}` with `item:take(n)` and `item:give(n)` on the acting player's inventory.
The item itself is declared in `scripts/registry.lua` (`registry.item(name, { template = "minecraft:bone" })`)
with its model under `assets/`.

### Players: `M:players()`, and the player

| | |
|---|---|
| `function P:on_join(player)`, `on_leave`, `on_respawn` | a player joined the game, left it (by any path), respawned after a death |
| `function P:on_death(player, cause)` | a player died; `cause` is the death message's key (`death.attack.lava`) or nil |
| `function P:on_break_block(player, block)` | a player breaks a block (`block` has `x`, `y`, `z`, `id`); return `true` to keep it |
| `function P:on_place_block(player, block, item)` | a player placed a block from `item` |
| `function P:on_pickup(player, item, count)` | a player is about to pick up `count` of `item` (an id); return `true` to leave it |
| `function P:on_tick(player)` | every server tick of every living player; keep it light |
| `function P:on_hurt(player, hit)` | about to take damage: `hit.damage_type`, `hit.causing`, `hit.amount`; `hit:set_amount(n)`, `hit:cancel()`. `player` is `id` and `kind` only (mid-hit: no host, no name) |
| `function P:on_fall(player, fall)`, `function P:on_knockback(player, hit)` | as the entity's, for players (`player` is `id` and `kind`; no host) |
| `function P:on_command(player, line)` | typed a command (without its slash), before it runs; return `true` to stop it; `player:reply(text)` answers (the only way here: no player's state is in place) |
| `function P:on_chat(player, line)` | a chat line, after the chat filter, before anyone sees it (`player` is `uuid` and `name` only: no host); return `true` to drop it, a string to send instead (unsigned) |
| `function P:on_change_dimension(player, from, to)` | arrived in another level (a dedicated server tells it; the window's own server does not) |
| `function P:on_sleep(player, x, y, z)` | entering the bed at that position; return `true` to keep them out |
| `function P:on_exp(player, amount)` | about to gain `amount` experience from an orb; return a number to change it |
| `function P:on_open_menu(player, menu, pos)` | opened a menu: `menu` its type (`minecraft:generic_9x3`, `minecraft:crafting`...), `pos` its block (`{x, y, z}`) or nil |

What has no class: `M:on("explosion", function(dimension, center, blocks) ... end)` (take entries out of `blocks` to spare them),
`M:on("entity_joined", fn, "minecraft:arrow")` (any entity joining the level, by kind; `horizon.cancel()` keeps it out),
`M:on("projectile_impact", fn, "minecraft:snowball")` and `M:on("projectile_launched", fn, kind)`, `M:on("mob_heal", fn)` (every
living entity about to heal, by id only).

`player`, in these and in every other callback that names one (`on_interact`, the item and block callbacks, a
command), is the engine's table (`uuid`, `name`, `dimension`, `position`, `game_mode`, `health`, and `held`, the
main hand's `{item, count, plain}`, for the player whose action the callback hears) with methods on it; a player
read from the world (`horizon.player(name)`) gets them with `modkit.player(t)`:

| | |
|---|---|
| `player:give(id, n)`, `player:take(id, n)` | `n` (1) of a plain item into their inventory where it fits (nothing drops), or out of it, the main hand first; from any callback with a host, a timer too |
| `player:inventory()`, `player:count(id)`, `player:carried()` | the 36 slots by number (1 to 36, the hotbar first; an empty slot is absent) of `{id, count, damage, plain}`; how many of a plain item they carry; every plain item with how many, by id. Reads, answered at once |
| `player:effect(name, ticks, amplifier)` | a status effect as `/effect give` gives it (200 ticks, amplifier 0 by default; -1 forever) |
| `player:experience(points)`, `player:levels(n)` | experience as an orb gives it, levels (negative takes them) |
| `player:nickname(name)` | the name shown in chat and the tab list; nil shows their own again |
| `player:tell(text)`, `player:action_bar(text)`, `player:title(text, subtitle)`, `player:title_times(fade_in, stay, fade_out)` | words on their screen |
| `player:data()`, `player:raycast(distance)`, `player:block_below()`, `player:distance_to(p)` | the mod's saved table on them, what they point at, the block under their feet, a distance |

Inside another player's callback (their click, their command) only that player is reached: a give to someone
else does nothing then, and their inventory reads nil. Do it from a timer (`horizon.after(1, ...)`) or a mob or
block callback instead.

### Reading the world

Inside any callback with a host (`on_tick`, `on_death`, `on_interact`, `on_spawned`, the block callbacks) the
engine's reads answer at once: `horizon.block(x, y, z)`, `horizon.block_property(x, y, z, key)`, `horizon.mob(id)`,
`horizon.mobs()`, `horizon.players()`, `horizon.player(name_or_uuid)`, `horizon.time()` (`day`, `time_of_day`,
`rain`, `thunder`) and `horizon.raycast(player, distance)` (what a player points at). `on_hurt` and goal functions
have no host: a goal reads its `mob` view instead. `mob:block_below()` and `block:above()` are the modkit's
shorthands for the block under a mob and over a block.

### The world

From any callback with a host (not `on_hurt`, not a goal):

| | |
|---|---|
| `modkit.set_block(x, y, z, id, props, flags)`, `block:replace(id, props, flags)` | a block set as `/setblock` does: `id` with its state properties (`{ axis = "x" }`, the rest default) and `Level.setBlock`'s flags (3: neighbours told, clients see it). Not in a random or scheduled tick (there `block:set` changes a property) |
| `modkit.fill(x1, y1, z1, x2, y2, z2, id, props)` | a box of one state straight into the chunks, as `/fill ... strict`; at most 256 by 256 columns |
| `modkit.drop_item(x, y, z, id, count)`, `block:drop(id, count)` | an item entity at the point, or over the block |
| `modkit.falling_block(x, y, z, id, vx, vy, vz)` | a falling block thrown from the point at that velocity, which lands as sand does |
| `modkit.light(x, y, z)`, `block:light()` | `{block, sky}` light, 0 to 15, at a position or over a block |
| `modkit.surface_height(x, z, heightmap)` | the column's top by `world_surface` (default), `motion_blocking`, `motion_blocking_no_leaves` or `ocean_floor`; nil where nothing is loaded |
| `modkit.run_command(line)` | a command as the server's console runs it (level 4, no output). Not inside a player's own callback (a click, a command): queue it with `horizon.after(1, ...)` there. What the API has no method for yet (time and weather, `/tp` of a player, game rules) goes through it |
| `modkit.data(path)` | a data file of the game's resources (`data/minecraft/recipe/stick.json`): JSON as a table, any other file as a string, nil for none |
| `modkit.effect(target, name, ticks, amplifier)` | a status effect on a mob (by id) or a player, as `mob:effect` and `player:effect` |

### Settings: `M:config(defaults)`

`local cfg = M:config { max_crawlers = 12, hive_charge = 400 }` at the top of `init.lua` reads the mod's own
settings file, `config/<id>.json` in the game folder (the `config/` every mod's settings share, as on NeoForge),
fills in the defaults for the keys it lacks and saves it when that added any, so the file is there to edit after
the first run; the table is what the scripts read. `M:save_config()` writes it back after a command changed it.
Both work at load, with no host.

### Commands and effects

`M:command(usage, level, fn)` puts a command in the server's tree (`"mymod count [kind:word] [n:integer]"`:
the words, then `<name:kind>` required and `[name:kind]` optional arguments; kinds `word`, `text`, `integer`,
`number`, `boolean`, `player`, `item`, `block_pos`) for players of operator `level` and above, and runs
`fn(player, args)` with the arguments by name; `horizon.feedback(text)` answers the player. Effects, from any
callback with a host: `modkit.sound(name, x, y, z, volume, pitch)` for the players in range,
`modkit.particles(name, x, y, z, count, spread, speed)` for the players near, `modkit.title(player, text, subtitle)`,
`modkit.action_bar(player, text)`, `modkit.tell(player, text)` (`player` a table or a name).

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
| `function B:on_use(block, player, held, face)` | a right click; `player` has `name`, `dimension`, `position`, `game_mode`; `held` has `item`, `count`. It runs once per hand (the main hand, then the off hand, as the game tries both; `held` is the main hand's both times): do one thing that is the same done twice, such as lighting a lamp rather than toggling it, or read the state first |
| `B:block_entity { ticks = true, data = { charge = 0 } }` | every placed block of this kind gets a block entity: saved data per block (`data` is what a new one starts with), ticked each server tick when `ticks` |
| `function B:on_block_entity_tick(block)` | every server tick of a block with a block entity |
| `function B:on_break(block, player)` | a player breaks it; return `true` to keep it |
| `function B:on_place(block, player, item)` | a player placed it from `item` |
| `function B:on_drops(block, drops, source)` | a player, an explosion or a mob broke it and its loot is about to drop: `drops` as `E:on_drops`; `source.tool`, `source.player`, `source.explosion` |

Each block class registers its callbacks with the engine for its own block id (`horizon.on(hook, fn, id)`), so
`on_random_tick`, `on_tick`, `on_block_entity_tick`, `on_break` and `on_place` run for this block's ticks and events
alone; other blocks' random ticks (hundreds a second across the loaded world) never reach Lua.

`block` has `x`, `y`, `z`, `dimension`, `id`, its state properties as fields (`block.stage`; strings as the state spells them, `"true"` for a boolean), `block.data` (the
block entity's saved table in every callback, nil for a block without one; what you change in it is saved after
the callback, a number keeps its NBT type, a key set to nil is gone), and `block:set(key, value)` (in `on_use`, the ticks and `on_block_entity_tick`),
`block:schedule_tick(delay)` and `block:handled()` (skip the vanilla tick), in `on_random_tick` and `on_tick` only, `block:cancel()` (eat the click),
`block:summon(kind, dx, dy, dz)` (the mob's id, in a callback with a host), `block:replace(id, props, flags)`,
`block:drop(id, count)`, `block:light()`, `block:above()`, `block:below()`, `block:broadcast(line)`.

### A mob's look and sounds

`registry.entity_type(name, def)` may give the mob a `model` of its own (`registry.id .. ":entity/" .. name`:
`assets/<id>/models/entity/<name>.json`, or `registry.asset("models/entity/<name>", {...})`: `texture_size` and
`parts` by name, each with `offset`, `rotation` in degrees, `cubes` of `origin`, `size`, `uv`, `inflate`, `mirror`,
and `children`), an `animation` set that moves the parts by their vanilla names (`zombie`, `skeleton`, `quadruped`,
`iron_golem`, `spider`...), and `sounds` by `ambient`, `hurt`, `death` and `step`. The parasite mod's
`scripts/registry.lua` has a worked model.

### Spawning

In `scripts/registry.lua`: a spawn egg is an item whose id ends in `_spawn_egg` and names the kind
(`registry.item("crawler_spawn_egg", { template = "minecraft:zombie_spawn_egg" })`, with a texture and model of
your own under `assets/`); natural spawning is a biome modifier
(`registry.data("neoforge/biome_modifier/crawlers", { type = "neoforge:add_spawns", biomes = "#minecraft:is_overworld",
spawners = { { type = registry.id .. ":crawler", weight = 20, min_count = 1, max_count = 3 } } })`), in the
category of the mob's template (`monster`, `creature`...; say `category` to choose). Both need a restart.

## Not yet

Nothing from the plan is left; what a hook point does not cover yet is listed in the engine's docs.
