# Spawning

A mob of yours can appear in three ways: from a spawn egg, by natural spawning, and from a script. The first two are
data in `scripts/registry.lua`. The third is `horizon.summon`.

The examples come from [scripts/example/spawning.lua](../../examples/example_mod/scripts/example/spawning.lua) and
the `SPAWNING` section of [scripts/registry.lua](../../examples/example_mod/scripts/registry.lua). The reference is
[Spawn eggs and natural spawning](../api.md#spawn-eggs-and-natural-spawning).

This command makes mobs next to the player who typed it:

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

## A spawn egg

A spawn egg is an item whose id ends in `_spawn_egg` and names the mob's kind:

```
registry.item("example_mob_spawn_egg", { template = "minecraft:pig_spawn_egg" })
```

Give it a model. The example uses the pig egg's texture; a PNG of your own goes under
`assets/<mod>/textures/item/`.

## Natural spawning

Natural spawning is a NeoForge biome modifier:

```
registry.data("neoforge/biome_modifier/<name>", {
  type = "neoforge:add_spawns",
  biomes = "#minecraft:is_overworld",
  spawners = { { type = "<mod>:<mob>", weight = 8, minCount = 1, maxCount = 2 } },
})
```

The mob spawns in the category of its template, such as `monster` or `creature`. Add `category` to a spawner entry
to choose another. The weight is compared with vanilla's: a zombie's is 95.

Spawn eggs and natural spawning both need the game restarted.

## From a script

`horizon.summon(dimension, kind, x, y, z)` makes a mob and returns its id at once, so you can act on it, such as
with `modkit.effect`. `mob:summon(kind, x, y, z)` and `block:summon(kind, dx, dy, dz)` do the same from a mob's or a
block's callback. The example nest breeds mobs this way ([blocks](blocks.md)), and the lure summons one on the
clicked face ([items](items.md)).

## When a mob appears

However a mob appears, `E:on_spawned(ev)` runs with `ev.x`, `ev.y`, `ev.z`, `ev.dimension` and `ev.natural`. This is
the place to dress a mob up.

## See it in the game

- Type `/example spawn 2`.
- Find the egg in the Example Mod creative tab.
- Wait for night, when one appears on its own.
