# Spawning

Three ways a mob of yours appears: a spawn egg, natural spawns, and a script that makes one. The first two are
data in `scripts/registry.lua`; the third is `horizon.summon`. Example:
[scripts/example/spawning.lua](../../examples/example_mod/scripts/example/spawning.lua) and the registry's
`SPAWNING` section in [scripts/registry.lua](../../examples/example_mod/scripts/registry.lua). Reference:
[api.md, Spawning](../api.md#spawning).

```lua
-- Mobs made beside the player. A command has no world at hand, so the
-- summons run next tick, from a timer.
M:command("example spawn [count:integer]", 2, function(player, args)
  local count, p, dimension = args.count or 1, player.position, player.dimension
  horizon.after(1, function()
    for i = 1, count do
      local id = horizon.summon(dimension, "example_mod:example_mob", p.x + i, p.y, p.z)
      if id then modkit.effect(id, "minecraft:glowing", 100) end
    end
  end)
  horizon.feedback(("%d example mob(s) coming"):format(count))
end)
```

**A spawn egg** is an item whose id ends in `_spawn_egg` and names the kind:
`registry.item("example_mob_spawn_egg", { template = "minecraft:pig_spawn_egg" })`, with a model (the example
borrows the pig egg's texture; the parasite mod ships its own PNG).

**Natural spawns** are a NeoForge biome modifier: `registry.data("neoforge/biome_modifier/<name>", { type =
"neoforge:add_spawns", biomes = "#minecraft:is_overworld", spawners = { { type = "<mod>:<mob>", weight = 8,
min_count = 1, max_count = 2 } } })`, in the category of the mob's template (`monster`, `creature`; say
`category` to choose). The weight is against vanilla's (a zombie is 95). Both need a restart.

**From a script.** `horizon.summon(dimension, kind, x, y, z)` answers the new mob's id at once, so it can be
acted on (`modkit.effect`, `horizon.set_health`); `mob:summon(kind, x, y, z)` and `block:summon(kind, dx, dy,
dz)` do the same from a mob's or a block's callback. The parasite hive breeds that way.

**When one appears,** by any of the three, `E:on_spawned(ev)` runs with `ev.x`, `ev.y`, `ev.z`, `ev.dimension`
and `ev.natural`. The summon's own spawned callback is the place to dress a mob up.

See it in game: `/example spawn 2`; the egg in the Example Mod creative tab; at night, one on its own.
