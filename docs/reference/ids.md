# Common Ids

These are vanilla ids that mods often need. Most of them are used by the example mod or the engine's own checks, so
they are known to work on Minecraft 26.3. The full lists are vanilla's registries. The engine's
[mods.md](https://github.com/nihilitymeta/horizon/blob/main/docs/mods.md) describes what a template carries over to a
mod's item, block or mob.

## Item templates

| Template | Use it for |
|---|---|
| `minecraft:feather`, `minecraft:stick`, `minecraft:bone` | a plain item with callbacks, such as the example feather, the template's wand and the example lure |
| `minecraft:cookie`, `minecraft:apple`, `minecraft:mushroom_stew` | something to eat, with `on_use_start` and `on_finished`; `crafting_remainder` gives back the bowl |
| `minecraft:iron_sword` | a weapon; set damage and durability through `components` |
| `minecraft:snowball` | a thrown item; an entity type of the mod's with `template = "minecraft:snowball"` flies as one |
| `minecraft:pig_spawn_egg`, `minecraft:zombie_spawn_egg` | a spawn egg; the id must end in `_spawn_egg` and name the kind |

## Block templates

| Template | Use it for |
|---|---|
| `minecraft:iron_block`, `minecraft:stone`, `minecraft:amethyst_block` | a plain block; `random_ticks = true` makes it tick |
| `minecraft:sculk` | a block with stages and a block entity, such as the example nest |
| `minecraft:chorus_plant` | a pipe or cable that joins its neighbours, with `connects_to` |
| `minecraft:oak_sign`, `minecraft:oak_wall_sign` | a sign of the mod's own |

## Mob templates

`minecraft:pig` is the example mob's template, and `minecraft:zombie` is the example of goals added to a vanilla
kind. Any vanilla mob works as a template, and brings its species' movement, sounds and animation.
`goals = "none"` leaves the behaviour to your scripts.

## Damage types

`minecraft:on_fire`, `minecraft:in_fire`, `minecraft:lava`, `minecraft:generic`, `minecraft:fall`,
`minecraft:player_attack` and `minecraft:mob_attack`.

These appear as `hit.damage_type` in `on_hurt` and `cause.damage_type` in `on_death`. To deal one from the chat, type
`/damage @s 5 minecraft:generic`.

## Death message keys

The *cause* of `P:on_death` is the death message's key, or nil. For example: `death.attack.lava`,
`death.attack.generic`, `death.attack.fall` and `death.attack.mob`. A player's blow adds `.player`.

## Sounds and particles

Sounds: `minecraft:entity.player.levelup`, `minecraft:entity.chicken.ambient`, `minecraft:entity.zombie.infect`,
`minecraft:entity.endermite.ambient` and `minecraft:entity.silverfish.hurt`.

Particles: `minecraft:happy_villager`, `minecraft:cloud`, `minecraft:heart`, `minecraft:end_rod`,
`minecraft:firework` and `minecraft:crimson_spore`.

## Status effects

`minecraft:speed`, `minecraft:slowness`, `minecraft:regeneration`, `minecraft:levitation`, `minecraft:glowing`,
`minecraft:nausea` and `minecraft:instant_health`. A mod's own effect, from `registry.mob_effect`, is
`<mod>:<name>`.

## Inventory slots

`player:inventory()` numbers the slots from 1 to 36. Slots 1 to 9 are the hotbar and 10 to 36 are the main
inventory. An empty slot is absent. On a stack, `item.plain` is true when it has no components beyond its
template's.

## Equipment slots

`mainhand`, `offhand`, `head`, `chest`, `legs` and `feet`, as the *slot* of `E:on_equip`. Some mobs also have `body`
and `saddle`.
