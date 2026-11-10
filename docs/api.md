# Horizon Modkit API Reference

This page describes every function, class and callback of the modkit. The modkit is written over the engine's own
Lua API, which has its own references:

- [lua-bindings.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/lua-bindings.md) describes the
  `horizon` table and the `registry` table.
- [hook-points.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/api/hook-points.md) lists every
  engine hook point and the Lua handler it reaches.
- [mods.md](https://github.com/whos-carmen/horizon/blob/main/docs/mods.md) describes the data files a mod declares.

For a walkthrough, start with [getting started](getting-started.md) and the [guides](../README.md#guides).

## Conventions

The examples on this page use these names:

| Name | What it is |
|---|---|
| `modkit` | the library, from `local modkit = require("@modkit")` |
| `M` | a mod, from `modkit.mod(id)` |
| `E`, `B`, `I`, `P` | an entity class, a block class, an item class and the players class of a mod |
| `mob`, `block`, `player`, `item` | the tables a callback receives |

A callback is a function that you define on a class, such as `function I:on_use(item, player)`. The modkit
connects it to the game's hook as soon as you define it, so a callback that you never define costs nothing.

An *id* is a namespaced name, such as `minecraft:zombie` or `my_mod:wand`. The mod's methods, such as `M:item`, add
the mod's own id to a name without a namespace.

Positions are block coordinates. A *tick* is one server tick; the game runs 20 ticks a second.

## What a callback can reach

Some callbacks run while the game has the world at hand (the engine calls this a *host*). Others run in the middle
of an event, such as a hit, when the game cannot act on the world. This decides which functions work inside a
callback.

- **With the whole world**: a timer, `E:on_tick`, `E:on_death` and `B:on_block_entity_tick`. The world reads, the
  actions and every player work. Saved tables are the world's, the players' and each mob's (`mob.data`): a block
  click names no block data.
- **In a player's own action**: the item callbacks, `B:on_use`, `E:on_interact`, `P:on_join` and a command. The
  reads and actions work. The native events name no player, so the modkit reads the acting player
  (`horizon.acting_player()`): the one who acted, even with several players on. A command queues summons and
  block changes for the next tick.
- **In a random or scheduled tick**: `B:on_random_tick` and `B:on_tick` read blocks only, and act through
  `block:set`, `block:schedule_tick`, `block:handled` and `block:summon`.
- **In a goal**: the goal reads its `mob` view and acts through the mob's goal methods only.
- **In the middle of an event**: `E:on_hurt`, `E:on_fall`, `E:on_knockback`, `P:on_hurt`, `P:on_fall`,
  `P:on_knockback` and `P:on_chat` have no host. Only the callback's own methods, such as `hit:cancel()`, and
  assignments to the event's fields, such as `hit.amount = n`, work.

When a callback cannot do something, queue it for the next tick with a timer:

```lua
horizon.after(1, function()
  local p = horizon.player(name)
  if p then modkit.player(p):give("my_mod:wand", 1) end
end)
```

Actions run in order after the callback returns. A script never holds the mob, block or player itself.

## Versions

The modkit's version is written once, in its `horizon-mod.toml`. A mod names the oldest modkit it works with in its
own manifest:

```toml
depends = ["horizon_modkit >= 0.7"]
```

The game checks this when it loads the mod. If the installed modkit is older, the game does not load the mod, and
the log says what it found:

```
Horizon: Lua mod my_mod not loaded: it needs horizon_modkit >= 0.7 (found 0.6.0), ...
```

`cargo horizon-mod check` reports the same problem without starting the game.

### `modkit.VERSION`

The modkit's version, such as `"0.7.0"`. The engine reads it from the modkit's manifest. A mod that depends on the
modkit can also read it as `horizon.libraries.horizon_modkit`.

## Editor support

The modkit ships `types/horizon.d.lua`, a copy of the engine's generated Luau type definitions. It declares the
`horizon` and `registry` tables, every engine function, the signature of every hook handler, and the tables a script
receives. The modkit's own classes are annotated with these types.

To use it, point [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) at the file as a definitions file. Your
editor then completes `M:entity`, `M:block`, `M:item`, `M:players`, `M:command` and the `player`, `mob` and `block`
tables, and marks a misspelled function or hook name.

A mod's `.luaurc` names the modkit checkout, so that `require("@modkit")` resolves. The Lua template of
`cargo horizon-mod new` writes one for you. To check a mod from a shell:

```sh
luau-lsp analyze --definitions @horizon=/path/to/horizon-modkit/types/horizon.d.lua --platform=standard scripts
```

## The registry script

A mod declares what it adds (entity types, blocks, items, mob effects, creative tabs, menu types, loot tables,
recipes and tags) in `scripts/registry.lua`. The game runs this script once, at start. The modkit is not loaded
there: the script is plain Luau with the engine's `registry` table. The engine's
[lua-bindings.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/lua-bindings.md) describes that
table. JSON files under `data/` work as well, and textures stay under `assets/`.

A mod that adds a lot can split the script into modules under `scripts/registry/`. `scripts/registry.lua` requires
them in order, with `require("@registry/items")` for `scripts/registry/items.lua`. Each module runs once, with the
same `registry` table. Add `"registry": "scripts/registry"` to `.luaurc` so that luau-lsp finds them. The modules
can't be required from `scripts/init.lua`.

`registry.lang(locale, entries)` names what a module adds. The entries of every call for a locale go into one
`assets/<id>/lang/<locale>.json`, so each module can name its own things:

```lua
registry.lang("en_us", { ["item.my_mod.wand"] = "Wand" })
```

A key given twice is an error that names both calls. A locale written with `registry.lang` can't also be a lang
file of the mod or a `registry.asset("lang/<locale>")`.

This script declares a mob, its loot, and a block with two stages that a hoe mines:

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

A change to this script needs the game restarted.

### A mob's look and sounds

An entity type can name a look of its own. Each of these falls back to the template's when you leave it out.

- `texture`: `<id>:entity/<name>`, a PNG laid out as the template's texture
- `model`: `<id>:entity/<name>`, which is `assets/<id>/models/entity/<name>.json`, or a table written with
  `registry.asset("models/entity/<name>", {...})`. A model has a `texture_size` and `parts` by name. Each part has an
  `offset`, a `rotation` in degrees, `cubes` (each with `origin`, `size`, `uv`, `inflate` and `mirror`) and `children`.
- `animation`: the vanilla animation set that moves the parts by their vanilla names, such as `zombie`, `skeleton`,
  `quadruped`, `iron_golem` or `spider`
- `sounds`: vanilla sound events by `ambient`, `hurt`, `death` and `step`

The [models and animation](guides/models-and-animation.md) guide has a worked model.

### Spawn eggs and natural spawning

A spawn egg is an item whose id ends in `_spawn_egg` and names the kind before it:

```lua
registry.item("crawler_spawn_egg", { template = "minecraft:zombie_spawn_egg" })
```

Give it a texture and model of your own under `assets/`.

Natural spawning is a NeoForge biome modifier:

```lua
registry.data("neoforge/biome_modifier/crawlers", {
  type = "neoforge:add_spawns",
  biomes = "#minecraft:is_overworld",
  spawners = { { type = registry.id .. ":crawler", weight = 20, minCount = 1, maxCount = 3 } },
})
```

The mob spawns in the category of its template, such as `monster` or `creature`. Add `category` to a spawner entry
to choose another. Both need the game restarted.

## The inspect stick

The modkit declares one item of its own, `horizon_modkit:inspect_stick`, in its `scripts/registry.lua`, and handles
its clicks in its `scripts/init.lua`. A mod writes nothing for it. Only a click that holds the stick asks the
engine's `horizon.dev.inspect(who, what)` from the `interact_entity` and `right_click_block` hooks, and cancels the
click when the engine answers true; anything else keeps its vanilla click. A stick in the off hand alone never
opens the windows on a block: `right_click_block` names no hand, and the selected slot it reads is the main hand's.
The [inspect stick guide](guides/inspect-stick.md) says how to use it.

## The modkit table

### `modkit.mod(id)`

Creates a new mod object. Call it once per mod, at the top of `scripts/init.lua`.

- *id*: the mod's id, as in its manifest

**Returns**: the mod, with the methods under [The mod](#the-mod).

```lua
local modkit = require("@modkit")
local M = modkit.mod("my_mod")
```

### `modkit.Goal(def)`

Creates a new goal class. Add it to an entity class with `E:goals` or `E:target_goals`.

- *def*: the goal's definition, with the fields under [Goals](#goals)

**Returns**: the goal class.

### `modkit.goals.Wander(reach, wait, radius)`

Creates a goal that walks the mob to a random point near it. Every *wait* ticks, if no player is within *radius*
blocks, the mob walks to a point up to *reach* blocks away. The goal is named `wander` and locks movement.

- *reach*: the farthest the point may be, in blocks; 6 by default
- *wait*: the ticks between walks; 80 by default
- *radius*: the distance within which a player stops the wander; 32 by default

**Returns**: the goal class.

### `modkit.goals.HuntPlayer(range, speed, cooldown)`

Creates a goal that hunts the nearest player. The mob targets a player within *range*, walks at them, and hits
them every *cooldown* ticks while they are in reach. The goal is named `hunt_player` and locks movement, looking and
targeting.

- *range*: the distance within which a player is hunted; 32 by default
- *speed*: the walking speed; 1.2 by default
- *cooldown*: the ticks between hits; 20 by default

**Returns**: the goal class.

### `modkit.player(t)`

Adds the player methods to a player table. Callbacks already receive wrapped players. Use this for a player that
you read from the world, such as the result of `horizon.player(name)`.

- *t*: a player table from the engine

**Returns**: the same table, with the methods under [The player](#the-player).

```lua
local p = horizon.player("Alex")
if p then modkit.player(p):give("minecraft:bread", 3) end
```

### `modkit.set_block(x, y, z, id, props, flags)`

Sets a block, as `/setblock` does. Works in a callback with a host, except a random or scheduled tick; there,
`block:set` changes a property instead.

- *x*, *y*, *z*: the block's position
- *id*: the new block's id
- *props*: the state properties that differ from the default, such as `{ axis = "x" }`
- *flags*: the flags of vanilla's `Level.setBlock`; 3 by default, which tells the neighbours and the clients

### `modkit.fill(x1, y1, z1, x2, y2, z2, id, props)`

Fills a box with one block state, as `/fill … strict` does. The blocks go straight into the chunks, and no
neighbour is told. The box may be at most 256 by 256 columns, at any height. A chunk that is not loaded is left out.

- *x1*, *y1*, *z1*, *x2*, *y2*, *z2*: two opposite corners of the box
- *id*: the block's id
- *props*: the state properties that differ from the default

### `modkit.drop_item(x, y, z, id, count)`

Drops an item entity at a position.

- *x*, *y*, *z*: the position
- *id*: the id of a plain item
- *count*: the size of the stack; 1 by default

### `modkit.falling_block(x, y, z, id, vx, vy, vz)`

Throws a falling block from a position. It lands and places itself as sand does.

- *x*, *y*, *z*: the position of the block's bottom centre
- *id*: the block's id
- *vx*, *vy*, *vz*: the velocity, in blocks per tick

### `modkit.light(x, y, z)`

Gets the light level at a position.

- *x*, *y*, *z*: the position

**Returns**: a table with `block` and `sky`, each from 0 to 15.

### `modkit.surface_height(x, z, heightmap)`

Gets the height of a column.

- *x*, *z*: the column
- *heightmap*: one of `world_surface` (the default), `motion_blocking`, `motion_blocking_no_leaves` and
  `ocean_floor`

**Returns**: the height, or nil where nothing is loaded.

### `modkit.run_command(line)`

Runs a command as the server console does, at permission level 4, with no output. Use it for what the API has no
function for yet, such as the time, the weather, `/tp` of a player, or game rules.

Inside a player's own callback (a click or a command), queue the command with `horizon.after(1, …)`.

- *line*: the command, with or without its slash

### `modkit.data(path)`

Reads a data file from the game's resources, including those of content mods.

- *path*: the file's path, such as `data/minecraft/recipe/stick.json`

**Returns**: a JSON file as a table, any other file as a string, or nil when the file does not exist.

### `modkit.effect(target, name, ticks, amplifier)`

Gives a status effect to a mob or a player, as `/effect give` does.

- *target*: a mob id, a player table, a player name or a UUID
- *name*: the effect's id, such as `minecraft:speed`
- *ticks*: how long it lasts; 200 by default, -1 for ever
- *amplifier*: the effect's level minus one; 0 by default

### `modkit.sound(name, x, y, z, volume, pitch)`

Plays a sound for the players in range of a position, as `/playsound` does.

- *name*: the sound event, such as `minecraft:entity.player.levelup`
- *x*, *y*, *z*: the position
- *volume*: the volume; 1 by default. Above 1, the sound reaches past 16 blocks
- *pitch*: the pitch; 1 by default

### `modkit.particles(name, x, y, z, count, spread, speed)`

Shows particles to the players near a position, as `/particle` does.

- *name*: a simple particle type, such as `minecraft:happy_villager`
- *x*, *y*, *z*: the position
- *count*: how many particles
- *spread*: how far they spread, in blocks
- *speed*: their speed

### `modkit.title(player, text, subtitle)`

Shows a title across a player's screen.

- *player*: a player table, a name or a UUID
- *text*: the title
- *subtitle*: a line under the title

### `modkit.action_bar(player, text)`

Shows a line over a player's hotbar.

- *player*: a player table, a name or a UUID
- *text*: the line

### `modkit.tell(player, text)`

Sends a chat line to one player.

- *player*: a player table, a name or a UUID
- *text*: the line

### `modkit.distance(a, b)`

Gets the distance between two positions.

- *a*, *b*: tables with `x`, `y` and `z`

**Returns**: the distance in blocks.

### `modkit.log(msg)`

Writes a line to the game log, tagged with the mod's id. A line logged while the scripts first load is lost,
because the log is not open yet; log from a timer or from `P:on_join` instead.

- *msg*: the line

## The mod

The object that `modkit.mod(id)` returns. Its methods create the classes of the mod.

### `M:entity(name)`

Gets the entity class for an entity type, creating it the first time.

- *name*: the type's name; a name without a namespace is the mod's own, and `minecraft:zombie` adds behaviour to
  every zombie

**Returns**: the entity class, described under [Entity classes](#entity-classes).

### `M:block(name)`

Gets the block class for a block, creating it the first time.

- *name*: the block's name; a mod's own or a vanilla one

**Returns**: the block class, described under [Block classes](#block-classes).

### `M:item(name)`

Gets the item class for an item, creating it the first time.

- *name*: the item's name; a mod's own or a vanilla one, such as `minecraft:stick`

**Returns**: the item class, described under [Item classes](#item-classes).

### `M:players()`

Gets the players class of the mod, creating it the first time.

**Returns**: the players class, described under [The players class](#the-players-class).

### `M:command(usage, level, fn)`

Adds a command to the server's command tree. The chat box completes it as it completes vanilla's commands. The game
checks the arguments and answers a wrong one with a usage line before *fn* runs.

- *usage*: the command's words, then its arguments. `<name:kind>` is a required argument and `[name:kind]` an
  optional one. The kinds are `word`, `text` (the rest of the line), `integer`, `number`, `boolean`, `player`,
  `item` and `block_pos`
- *level*: the operator level a player needs; 0 is everyone, 2 is operators (as for `/give`) and 4 is the console.
  You can leave it out, which means 0
- *fn*: a function of the player and a table of the arguments by name, plus `args.raw`, the whole line

Several commands may share their first word; the game merges them into one tree. Inside *fn*,
`horizon.feedback(text)` answers the player.

```lua
M:command("mymod count [kind:word]", 2, function(player, args)
  horizon.feedback(("counting %s"):format(args.kind or "everything"))
end)
```

### `M:config(defaults)`

Gets the mod's settings from `config/<id>.json` in the game folder. Every mod's settings share that folder, as on
NeoForge. Keys that the file lacks are filled in from *defaults*, and the file is saved when that added any, so the
file is there to edit after the first run. Works at load, with no host.

- *defaults*: the settings and their default values

**Returns**: the settings table. The scripts read the settings from it.

```lua
local cfg = M:config { max_crawlers = 12, hive_charge = 400 }
```

### `M:save_config()`

Saves the settings table back to the mod's settings file, such as after a command changed a setting.

### `M:on(hook, fn, kind)`

Registers a handler for an engine hook, as `horizon.on` does. Use it for the hooks that no class covers. Every
handler takes one event table:

- `explosion_detonate`, with `event.dimension`, `event.center` and `event.blocks`: remove entries from `blocks` to
  spare those blocks
- `entity_join_level`, with a kind such as `minecraft:arrow`: any entity joining the level, with `event.dimension`,
  `event.entity`, `event.kind`, `event.pos` and `event.loaded_from_disk`; `horizon.cancel()` keeps it out
- `projectile_impact`, with a kind such as `minecraft:snowball`: `event.projectile`, `event.kind`, `event.owner`,
  and the entity half (`event.entity`, `event.entity_kind`) or the block half (`event.block`, `event.face`) of
  the hit, with `event.at`. Branch on `event.entity`: on an entity hit `event.block` and `event.face` are still
  `{0, 0, 0}`, and on a block hit `event.entity` is nil and `event.entity_kind` is `""`
- `projectile_launch`, with a kind such as `minecraft:snowball`: `event.player` (the shooter's table, or nil),
  `event.entity` and `event.kind`
- `living_heal`, with `event.entity` and `event.amount`: every living entity that is about to heal; every handler
  hears every entity

The parameters:

- *hook*: the hook's name; the game refuses an unknown name when the script loads
- *fn*: the handler, with the hook's one event table
- *kind*: a mob, entity, block or projectile id that limits the handler to that kind, on the hooks whose
  signature takes one

### `M:qualify(name)`

Gets the full id of a name.

- *name*: a name, with or without a namespace

**Returns**: *name* when it has a namespace, otherwise `<mod id>:<name>`.

## Entity classes

An entity class holds the goals and callbacks of one entity type: the mod's own, or a vanilla one. `M:entity(name)`
returns it.

```lua
local Crawler = M:entity("crawler")
Crawler:goals { { 1, modkit.goals.HuntPlayer() }, { 5, modkit.goals.Wander() } }
function Crawler:on_death(mob, cause)
  horizon.log(("a crawler died of %s"):format(cause.damage_type))
end
```

### `E:goals(list)`

Adds goals that every mob of this type gets.

- *list*: a sequence of `{ priority, goal }` pairs; a lower priority runs first

**Returns**: the entity class.

### `E:target_goals(list)`

Adds goals to the mob's target selector, which picks what the mob attacks.

- *list*: a sequence of `{ priority, goal }` pairs

**Returns**: the entity class.

### `E.replace_goals`

Whether the vanilla goals are removed before the class's goals are added. False by default. Set it for a type that
keeps its template's goals, or for a vanilla kind, when the class should give all the behaviour.

### `E:on_spawned(ev)`

Called when a mob of this type spawns, by any means.

- *ev*: a table with `dimension`, `kind`, `x`, `y`, `z` and `natural`, which is true for a natural spawn

### `E:on_tick(mob)`

Called every server tick for every mob of this type. Keep it light. This is NeoForge's `tick`.

- *mob*: the mob's live view, read with `horizon.mob`, with the actions by id and the mob's saved table
  (`mob.data`, fetched from `horizon.entity_data` on first use). Skipped when the mob is dead or gone and has
  no live view. The rule for every entity callback: one that documents `mob` as the live view (`E:on_tick`,
  `E:on_interact`) never runs viewless, while one that documents `mob` as id and kind only still runs.

### `E:on_ai_tick(mob, state)`

Called every AI tick, as a goal of its own. The mob's goal actions, such as steering and fighting, work here.

- *mob*: the mob, as a goal sees it
- *state*: the goal's table for this mob

### `E:on_hurt(mob, hit)`

Called when a mob of this type is about to take damage. The game is in the middle of the hit, so *mob* has only `id`
and `kind`, and no other action works. It still runs when the mob has no live view.

- *mob*: the mob's `id` and `kind`
- *hit*: the [hit](#hit)

### `E:on_death(mob, cause)`

Called when a mob of this type dies, by any cause.

- *mob*: the mob's `id` and `kind`; the view is gone with the mob. Its saved table (`mob.data`) is read from
  `horizon.entity_data` on first use, or nil when the entity is already gone. It still runs when the mob has no
  live view
- *cause*: a table with `damage_type` (such as `minecraft:on_fire`), `causing` (the id of the mob behind the death,
  or 0) and `player` (the uuid of the player credited with the kill, or nil)

### `E:on_interact(mob, player, held)`

Called when a player right-clicks a mob of this type, before the mob and the item act.

- *mob*: the mob's live view, read with `horizon.mob`, with the actions by id and the mob's saved table
  (`mob.data`, fetched from `horizon.entity_data` on first use). Skipped when the mob is dead or gone and has
  no live view, as `E:on_tick`
- *player*: the acting player (`horizon.acting_player()`), with their selected stack in `held`
- *held*: the stack in the hand being tried (`item`, `count` and `plain`), main hand then off hand, or nil when that hand is empty

**Returns**: true to take the click, so that neither the mob nor the item acts.

### `E:on_fall(mob, fall)`

Called when a mob of this type is about to land. There is no host, so *mob* has only `id` and `kind`.
It still runs when the mob has no live view.

- *mob*: the mob's `id` and `kind`
- *fall*: the [fall](#fall)

### `E:on_knockback(mob, hit)`

Called when a mob of this type is about to be knocked back. There is no host. It still runs when the mob
has no live view.

- *mob*: the mob's `id` and `kind`
- *hit*: the [knockback](#knockback)

### `E:on_equip(mob, slot, from, to)`

Called when an equipment slot of a mob of this type takes a different stack.

- *mob*: the mob's `id` and `kind`. It still runs when the mob has no live view
- *slot*: `mainhand`, `offhand`, `head`, `chest`, `legs`, `feet`, `body` or `saddle`
- *from*: the item table that was there, or nil
- *to*: the item table that is there now, or nil

### `E:on_drops(mob, drops, source)`

Called when a mob of this type died and its loot is about to drop.

- *mob*: the mob's `id` and `kind`. It still runs when the mob has no live view
- *drops*: the [drops](#drops-and-source)
- *source*: where the loot comes from, described under [drops and source](#drops-and-source)

## Goals

A goal is something a mob does when nothing more pressing applies, as vanilla's goals are. `modkit.Goal(def)`
creates one from a definition with these fields:

| Field | Description |
|---|---|
| `name` | the goal's name; `/goals` shows it as `<mod>:<entity>.<name>` |
| `flags` | what the goal locks: any of `"move"`, `"look"`, `"jump"` and `"target"`, as vanilla's `Goal.Flag`. Two goals that lock the same thing do not run at once |
| `every_tick` | true to call `tick` every tick rather than every other tick |
| `interruptable` | false to keep a more pressing goal (a lower priority number) from stopping this one; true by default |
| `can_use(self, mob)` | required. Checks whether the goal should start |
| `can_continue(self, mob)` | checks whether a running goal should go on; `can_use` by default |
| `start(self, mob)` | called when the goal starts |
| `tick(self, mob)` | called each tick while the goal runs |
| `stop(self, mob)` | called when the goal stops |

In each function, *self* is the goal's state for this mob, a table you can write to, and *mob* is the mob as a goal
sees it. The mob's view is copied before each call, and its actions run after it.

```lua
local Approach = modkit.Goal {
  name = "approach",
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
```

### `self:every(name, ticks)`

Counts a call on the timer *name* and checks whether *ticks* calls have passed since it last fired. When they have,
the timer starts again.

- *name*: the timer's name
- *ticks*: the number of calls between two firings

**Returns**: true once every *ticks* calls; false otherwise.

### `self:cooldown(name, ticks)`

Checks whether the timer *name* is ready. When it is, the timer is set to *ticks* and counts down by one each call.

- *name*: the timer's name
- *ticks*: the number of calls to wait after it fires

**Returns**: true if the timer is ready; false otherwise.

## The mob

The `mob` table that a goal or an entity callback receives. Its fields are a copy of the mob's state, taken before
the call.

| Field | Description |
|---|---|
| `id`, `kind` | the mob's entity id and its type's id |
| `position`, `velocity` | tables with `x`, `y` and `z` |
| `yaw`, `head_pitch` | where it faces |
| `health`, `max_health` | its health |
| `age` | its age in ticks |
| `on_ground`, `in_water`, `in_lava` | where it stands |
| `hurt_time`, `last_hurt_by` | how recently it was hurt, and by whom |
| `target` | what it targets: `"player"`, a mob id, or nil |
| `target_position`, `target_in_melee_range` | where its target is, and whether it can hit it |
| `navigation_done` | true when it walks no path |
| `nearest_player` | the nearest player's position, or nil |
| `home` | `x`, `y`, `z` and `radius`, or nil |
| `nearby` | in a goal: the mobs within its follow range, nearest first (`id`, `kind`, `position`, `distance`, `health`, `alive`, `hostile`, `baby`, `target`). Empty in a callback |
| `dimension` | in a callback with a host only: the mob's dimension |
| `data` | in a callback with a host only: the mob's saved table, fetched from `horizon.entity_data` on first use, written back after the call. Nil in a goal and where there is no host (`E:on_hurt`, `E:on_fall`, `E:on_knockback`), and nil when the entity is gone. On a client copy an unknown id reads as an empty table, so a table is no proof the entity exists there |

In `E:on_hurt`, `E:on_fall` and `E:on_knockback` only `id` and `kind` remain: the game is in the middle of the
event, and the helper is refused there, as `horizon.world_data()` is. Every other entity callback reads
`mob.data`: the view callbacks (`E:on_tick`, `E:on_interact`), `E:on_death`, `E:on_equip` and `E:on_drops`.

### Moving and looking

These methods work in a goal only. *speed* is 1.0 by default.

- `mob:navigate_to(x, y, z, speed)`: walks a path to a position
- `mob:navigate_to_target(speed)`: walks a path to the mob's target
- `mob:stop_navigation()`: stops walking
- `mob:move_toward(x, y, z, speed)`: steps straight toward a position, with no path
- `mob:look_at(x, y, z)`: turns the head toward a position
- `mob:look_at_target()`: turns the head toward the target
- `mob:jump()`: jumps

### Fighting

These methods work in a goal only. *who* is `"player"`, a mob id, or nil.

- `mob:set_target(who)`: sets the mob's target; nil clears it
- `mob:attack(who)`: attacks, as the mob's melee attack does
- `mob:swing()`: swings the arm
- `mob:hurt(who, amount)`: deals *amount* damage
- `mob:convert(kind)`: replaces the mob with one of *kind*, keeping its equipment and name, as a zombie that drowns
  becomes a drowned

### Living

These methods work in a goal, and in a callback with a host.

- `mob:effect(name, ticks, amplifier)`: gives a status effect, as `modkit.effect` does
- `mob:summon(kind, x, y, z)`: makes a mob at a position. In a callback, returns the new mob's id
- `mob:despawn()`: removes the mob, with no death and no loot. `mob:remove()` is the same
- `mob:heal(amount)`: adds health

These methods work in a callback with a host only.

- `mob:set_health(health)`: sets the health, up to the mob's maximum
- `mob:kill()`: kills the mob as `/kill` does, with its loot
- `mob:push(x, y, z)`: adds to the mob's velocity
- `mob:teleport(x, y, z)`: moves the mob at once, as `/tp` does
- `mob:broadcast(line)`: sends a chat line to every player

### Reading

- `mob:player_within(range)`: checks whether a player stands within *range* blocks. Returns true if one does; false
  otherwise
- `mob:distance_to(p)`: gets the distance to a position *p*
- `mob:nearby(filter)`: gets the nearby mobs that *filter* accepts, nearest first. *filter* is a kind id, or a
  function of a nearby record that returns true for the mobs to keep. Returns all nearby mobs without a filter
- `mob:nearest(filter, range)`: gets the nearest mob that *filter* accepts within *range* blocks, or nil
- `mob:block_below()`: gets the id of the block under the mob. Needs a callback with a host

## Item classes

An item class holds the callbacks of one item: the mod's own, or a vanilla one. `M:item(name)` returns it. The item
itself is declared in `scripts/registry.lua`, such as
`registry.item("wand", { template = "minecraft:stick" })`, with its model under `assets/`.

```lua
local Wand = M:item("wand")
function Wand:on_use(item, player)
  player:effect("minecraft:levitation", 20, 1)
  return true
end
```

In every item callback, *item* is the stack, a table with `id`, `count`, `damage` and `plain`. `plain` is true when
the stack has no components beyond its template's. Two methods act on the acting player's inventory:

- `item:take(n)`: takes *n* of the item, 1 by default, the main hand first
- `item:give(n)`: gives *n* of the item, 1 by default

The use, use-on, hit, hurt-enemy, start and finish hooks take no kind: every use wakes one handler, which keeps
the stacks with its own id. The acting *player* is the player who acted (`horizon.acting_player()`), correct
with several players on.

### `I:on_use(item, player)`

Called when a player right-clicks with the item in the air, or on a block that lets the click through.

- *item*: the stack in hand
- *player*: the player who clicked

**Returns**: true to take the click, so nothing else acts on it.

### `I:on_use_on(item, player, block, face)`

Called when a player right-clicks a block with the item.

- *item*: the stack in hand
- *player*: the player who clicked
- *block*: the block, with `x`, `y`, `z` and `id`
- *face*: the side that was clicked, as a direction with `x`, `y` and `z`; `{0, 1, 0}` is the top

**Returns**: true to take the click.

### `I:on_hit(item, player, target)`

Called when a player attacks while holding the item, before the damage. The event names no stack, so the modkit
reads the acting player's selected slot: the hand they hit with.

- *item*: the stack in hand
- *player*: the attacker
- *target*: the entity attacked, with `id`, `kind` and `position`

**Returns**: true to cancel the blow.

### `I:on_hurt_enemy(item, player, target)`

Called after a blow with the item has landed and dealt its damage.

- *item*: the stack in hand
- *player*: the attacker
- *target*: the entity hit, with `id` and `kind`

### `I:on_use_start(item, player, hand, duration)`

Called when a player starts to use the item over time, such as eating, drinking or drawing a bow. A mob's own
starts reach bare handlers with that mob's entity set; the callback keeps the player's own (`entity` nil).

- *item*: the stack in hand
- *player*: the player
- *hand*: `"main"` or `"off"`
- *duration*: how long the use takes, in ticks

**Returns**: a number of ticks to change the duration, or true to stop the use.

### `I:on_finished(item, player)`

Called when a player has finished using the item: eaten, drunk, or held for the item's `use_duration`. A mob's own
finishes reach bare handlers too; the callback keeps the player's own.

- *item*: the stack in hand
- *player*: the player

**Returns**: an item id, and optionally a count, for what stays in the hand. Return nothing to keep the game's own
result.

### `I:on_tick(slot, selected)`

Called every server tick for every stack of every item in every player's inventory. Keep it light. The ticking
stack is not on the event, and neither is its player, so the callback takes only the slot and whether it is the
held one.

- *slot*: the slot as the inventory saves it: 0 to 35, armour 100 to 103, the off hand -106
- *selected*: true if this is the held stack

### `I:on_crafted(item, player, recipe)`

Called when a player takes the item from a crafting grid. *player* is the uuid's table, read with
`horizon.player`.

- *item*: the crafted stack
- *player*: the player
- *recipe*: the recipe's id

### `I:on_dropped(item, player, count)`

Called when a player throws the item, with the drop key or from a menu. Items scattered at death do not count.
*player* is the uuid's table, read with `horizon.player`.

- *item*: the stack thrown
- *player*: the player
- *count*: how many were thrown

## Block classes

A block class holds the callbacks of one block: the mod's own, or a vanilla one. `M:block(name)` returns it. Each
block class registers its callbacks for its own block id, so the game calls them for this block alone. Other
blocks' random ticks, hundreds a second, never reach Lua.

```lua
local Lamp = M:block("lamp")
function Lamp:on_use(block, player, held)
  if block.lit ~= "true" then block:set("lit", "true") end
  block:cancel()
end
```

### `B:block_entity(def)`

Gives every placed block of this kind a block entity, which holds saved data per block. Call it at load.

- *def*: a table with `ticks`, true to call `B:on_block_entity_tick` each server tick, and `data`, the table a new
  block entity starts with (numbers, strings, booleans and nested tables)

**Returns**: the block class.

### `B:on_random_tick(block)`

Called on the block's random tick. The block must declare `random_ticks` in its data.

- *block*: the [block](#the-block)

### `B:on_tick(block)`

Called on a scheduled tick that `block:schedule_tick` asked for.

- *block*: the [block](#the-block)

### `B:on_block_entity_tick(block)`

Called every server tick for every placed block that has a ticking block entity.

- *block*: the [block](#the-block), with `block.data`

### `B:on_use(block, player, held, face)`

Called when a player right-clicks the block. The game tries the main hand and then the off hand, so this runs once
for each. Make the callback do something that is the same when done twice, such as lighting a lamp rather than
toggling it, or read the block's state first.

- *block*: the [block](#the-block), without `data`: a click names no block data
- *player*: the acting player (`horizon.acting_player()`): the one who clicked
- *held*: the selected stack (`item`, `count` and `plain`), or nil
- *face*: the side that was clicked

### `B:on_break(block, player)`

Called when a player breaks the block, once the game has allowed it.

- *block*: the [block](#the-block), without `data`
- *player*: the acting player (`horizon.acting_player()`): the one who broke it

**Returns**: true to keep the block, so nothing breaks or drops.

### `B:on_place(block, player, item)`

Called after a player has placed the block. To stop a placement, take the click in an item's `I:on_use_on`.

- *block*: the [block](#the-block), without `data`
- *player*: the acting player (`horizon.acting_player()`): the one who placed it
- *item*: the stack it was placed from

### `B:on_drops(block, drops, source)`

Called when the block was broken by a player, an explosion or a mob, and its loot is about to drop. The block is
already gone, so its state properties come from the state that the game names.

- *block*: the [block](#the-block), without `data`, as it was
- *drops*: the [drops](#drops-and-source)
- *source*: where the loot comes from, with `tool`, `player` and `explosion`

## The block

The `block` table that a block callback receives.

| Field | Description |
|---|---|
| `x`, `y`, `z` | its position |
| `dimension` | its dimension |
| `id` | its id |
| a state property's name | that property's value as the state spells it, such as `block.stage`; a boolean reads `"true"` or `"false"` |
| `data` | the block entity's saved table in the ticks, written back after the callback; nil for a block without one, and in `B:on_use`, `B:on_break`, `B:on_place` and `B:on_drops` |

The mod's changes to `block.data` are saved after the callback. A number keeps its NBT type, and a key set to nil is
removed.

These methods change the block:

- `block:set(key, value, flags)`: sets a state property, such as `block:set("stage", "growing")`. Works in
  the two ticks and `B:on_block_entity_tick`: a click's host drops it, so a click replaces the block instead
- `block:schedule_tick(delay)`: asks for a scheduled tick in *delay* ticks. Works in the random and scheduled ticks
  only
- `block:handled()`: skips the block's own vanilla tick. Works in the random and scheduled ticks only
- `block:cancel()`: takes the click, so neither the block nor the held item acts. Works in `B:on_use`
- `block:replace(id, props, flags)`: replaces the block, as `modkit.set_block` does. Not in the random and
  scheduled ticks; the new block starts with its default data

These methods act around the block. They need a callback with a host, except where noted.

- `block:summon(kind, dx, dy, dz)`: makes a mob at an offset from the block's bottom centre; *dy* is 1 by default,
  which is on top of the block.
  Returns the mob's id. In a random or scheduled tick, the mob is made after the level's pass, and nothing is
  returned
- `block:drop(id, count)`: drops *count* of an item over the block; 1 by default
- `block:broadcast(line)`: sends a chat line to every player

These methods read the world:

- `block:above(dy)`: gets the id of the block *dy* blocks above; 1 by default
- `block:below(dy)`: gets the id of the block *dy* blocks below; 1 by default
- `block:light()`: gets the light over the block, as `modkit.light` does

## The players class

The players class holds the callbacks for what every player does. `M:players()` returns it.

```lua
local Players = M:players()
function Players:on_join(player)
  player:title("Welcome", player.name)
end
```

### `P:on_join(player)`

Called when a player joins the game.

- *player*: the player

### `P:on_leave(player)`

Called when a player leaves the game, by any path.

- *player*: the player

### `P:on_respawn(player)`

Called when a player respawns after a death.

- *player*: the player

### `P:on_death(uuid, cause)`

Called when a player dies. The event names the dead player by uuid only: their name is unrecoverable.

- *uuid*: the dead player's uuid
- *cause*: the death message's key, such as `death.attack.lava`, or nil

### `P:on_tick(player)`

Called every server tick for every living player, each time with that player. Keep it light.

- *player*: the acting player (`horizon.acting_player()`): the one whose tick ended

### `P:on_break_block(player, block)`

Called when a player breaks any block.

- *player*: the acting player (`horizon.acting_player()`): the one who broke it
- *block*: the block, with `x`, `y`, `z` and `id`

**Returns**: true to keep the block.

### `P:on_place_block(player, block, item)`

Called after a player has placed any block.

- *player*: the acting player (`horizon.acting_player()`): the one who placed it
- *block*: the block, with `x`, `y`, `z` and `id`
- *item*: the stack it was placed from

### `P:on_pickup(player, item, count)`

Called when a player is about to pick up items from the ground. *player* is the uuid's table, read with
`horizon.player`.

- *player*: the player
- *item*: the item's id
- *count*: how many

**Returns**: true to leave the items on the ground.

### `P:on_hurt(player, hit)`

Called when a player is about to take damage. The game is in the middle of the hit: *player* has only `id` and
`kind`, and no other action works. Assign `hit.amount = n` to change the damage.

- *player*: the player's `id` and `kind`
- *hit*: the [hit](#hit)

### `P:on_fall(player, fall)`

Called when a player is about to land. There is no host.

- *player*: the player's `id` and `kind`
- *fall*: the [fall](#fall)

### `P:on_knockback(player, hit)`

Called when a player is about to be knocked back. There is no host.

- *player*: the player's `id` and `kind`
- *hit*: the [knockback](#knockback)

### `P:on_command(player, line)`

Called when a player types a command, before it runs. No player's state is in place here, so `player:reply` is the
only way to answer: other `player:` methods, such as `give` and `tell`, reach nobody.

- *player*: the player, with `player:reply(text)`
- *line*: the command, without its slash

**Returns**: true to stop the command.

### `P:on_chat(player, line)`

Called when a player's chat line is about to go out, after the chat filter. There is no host: a returned
string answers the sender, and neither saved tables nor the world reads work here.

- *player*: the player's `uuid` and `name`
- *line*: the line

**Returns**: true to drop the line, so nobody sees it; a string to answer the sender with, as a line only they
see; or nil to send the line as it is. The line itself can't change: a signed message would no longer verify.

### `P:on_change_dimension(player, from, to)`

Called when a player arrives in another dimension. Only a dedicated server reports this; the game window's own
server does not.

- *player*: the player
- *from*: the dimension they left
- *to*: the dimension they arrived in

### `P:on_sleep(player, x, y, z)`

Called when a player is about to enter a bed. The game's own checks come first: it must be night in the overworld,
with no monster within eight blocks.

- *player*: the player
- *x*, *y*, *z*: the bed's position

**Returns**: true to keep the player out of the bed. This ends the dispatch, so another mod's `on_sleep` is not
called.

### `P:on_exp(player, amount)`

Called when a player is about to gain experience from an orb, after Mending's share. Assign `amount` through the
returned number: the writeback does not clamp.

- *player*: the player
- *amount*: the experience points

**Returns**: a number to change the amount.

### `P:on_open_menu(player, menu, pos)`

Called when a player opens a menu.

- *player*: the player
- *menu*: the menu's type, such as `minecraft:generic_9x3` or `minecraft:crafting`
- *pos*: the position of the menu's block, or nil

## The player

The `player` table that a callback receives. Its fields are a copy of the player's state:

| Field | Description |
|---|---|
| `uuid`, `name` | who the player is |
| `dimension`, `position` | where they are; `position` has `x`, `y` and `z` |
| `game_mode` | 0 survival, 1 creative, 2 adventure, 3 spectator |
| `health` | their health |
| `held` | the player's selected hotbar stack (`{item, count, plain}`), or nil when the hand is empty: the engine hands it out on the player tables, and a bare hook seed reads it from `horizon.player(uuid)`. A command's own player table carries the engine's hand instead |

The methods below work in any callback with a host, and in a timer. Inside another player's callback, such as their
click or their command, only that player is reached: a give to someone else does nothing, and their inventory reads
nil. Do it from a timer instead.

### Inventory

- `player:give(id, n)`: gives *n* of a plain item, 1 by default, where it fits. Nothing drops
- `player:take(id, n)`: takes up to *n* of a plain item, 1 by default, the main hand first
- `player:inventory()`: gets the 36 slots, numbered 1 to 36 with the hotbar first, as item tables. An empty slot is
  absent
- `player:count(id)`: gets how many of a plain item the player carries
- `player:carried()`: gets every plain item the player carries, with how many, by id

### Status

- `player:effect(name, ticks, amplifier)`: gives a status effect, as `modkit.effect` does
- `player:experience(points)`: gives experience, as an orb does
- `player:levels(n)`: gives levels; a negative number takes them away
- `player:nickname(name)`: sets the name shown in chat and the tab list; nil shows their own name again

### Messages

- `player:tell(text)`: sends a chat line to the player
- `player:action_bar(text)`: shows a line over their hotbar
- `player:title(text, subtitle)`: shows a title, and a subtitle under it
- `player:title_times(fade_in, stay, fade_out)`: sets how long titles fade in, stay and fade out, in ticks

### Reading

- `player:data()`: gets the mod's saved table on the player, or nil
- `player:raycast(distance)`: gets the first block within *distance* along the player's look, 64 by default.
  Returns a table with `id`, the point hit (`x`, `y`, `z`) and the `block` position, or nil
- `player:block_below()`: gets the id of the block under the player's feet
- `player:distance_to(p)`: gets the distance to a position *p*

## Callback tables

### Hit

The *hit* of `E:on_hurt` and `P:on_hurt`.

| Member | Description |
|---|---|
| `damage_type` | the damage type, such as `minecraft:on_fire` |
| `causing`, `direct` | the ids of the entity behind the damage and of the one that dealt it, or -1 for none |
| `amount` | the damage; assign it to change the damage |
| `hit:set_amount(n)` | sets the damage, as assigning `amount` does |
| `hit:cancel()` | refuses the hit |

### Fall

The *fall* of `E:on_fall` and `P:on_fall`.

| Member | Description |
|---|---|
| `distance`, `multiplier` | the fall's distance and damage multiplier; assign them to change the fall |
| `fall:set_distance(n)`, `fall:set_multiplier(n)` | change them, as assigning does |
| `fall:cancel()` | removes the fall damage |

### Knockback

The *hit* of `E:on_knockback` and `P:on_knockback`.

| Member | Description |
|---|---|
| `strength` | the raw knockback strength; assign it to change the push |
| `x`, `z` | the direction; assign them to steer it |
| `damage_type`, `causing`, `direct` | as in a [hit](#hit) |
| `hit:set_strength(n)` | sets the strength, as assigning does |
| `hit:cancel()` | removes the knockback |

### Drops and source

The *drops* of `E:on_drops` and `B:on_drops` is a sequence of item tables, `{id, count, damage, plain}`. Change it in
place: add entries, change counts, or remove some. The game reads it back after the callback. An entry whose id
matches the stack at that place keeps that stack's components.

The *source* has these fields:

| Field | Description |
|---|---|
| `table` | the loot table's id |
| `dimension`, `origin` | where the loot drops |
| `block` | for a block: `x`, `y`, `z`, `id` and `state` |
| `entity` | for a mob: `id` and `kind` |
| `player` | the player credited, or nil |
| `tool` | the item table of the tool used, or nil |
| `explosion` | the explosion's radius, or nil |
| `used` | true once the loot has been used |

## Timers and saved data

These are engine functions. The modkit has no wrapper for them, and none is needed.

### `horizon.after(ticks, fn)`

Runs a function once, after a number of server ticks. Inside it, the world reads and the actions work, and every
player can be reached.

- *ticks*: how many ticks to wait
- *fn*: the function

### `horizon.every(ticks, fn)`

Runs a function every *ticks* server ticks. A timer that fails is logged and kept.

- *ticks*: the interval
- *fn*: the function

### `horizon.world_data()`

Gets the mod's saved table on the world.

**Returns**: the table, written back after the callback and kept through saves.

### `horizon.player_data(player)`

Gets the mod's saved table on a player. `player:data()` is the same.

- *player*: a name or a UUID

**Returns**: the table, or nil for a player the server does not hold.

### `horizon.entity_data(id)`

Gets the mod's saved table on an entity. `mob.data` is the same, fetched on the first use in a callback with a
host.

- *id*: the entity's id

**Returns**: the table, written back after the call and kept with the entity. Nil on a server when the entity is
not in the level. On a client copy an unknown id reads as an empty table, so a table is no proof the entity
exists there.

## Reading the world

Inside a callback with a host, these engine functions answer at once:

- `horizon.block(x, y, z)` and `horizon.block_property(x, y, z, key)`
- `horizon.mob(id)` and `horizon.mobs()`
- `horizon.players()` and `horizon.player(name_or_uuid)`
- `horizon.time()`, with `day`, `time_of_day`, `rain` and `thunder`
- `horizon.raycast(player, distance)`

A goal reads its `mob` view instead. The engine's
[lua-bindings.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/lua-bindings.md) describes each one.
