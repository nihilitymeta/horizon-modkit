# Ids a mod keeps reaching for

Vanilla's names, starting with the ones the example mod, the parasite mod and the engine's own checks use, so
they are known to work on 26.3. The full lists are vanilla's registries; the engine's [mods.md](https://github.com/whos-carmen/horizon/blob/main/docs/mods.md)
says what a template carries along.

## Item templates

| Template | Good for |
|---|---|
| `minecraft:feather`, `minecraft:stick`, `minecraft:bone` | a plain item with callbacks (the example feather, the scaffold's wand, the parasite's lure) |
| `minecraft:cookie`, `minecraft:apple`, `minecraft:mushroom_stew` | something eaten (`on_use_start`, `on_finished`; `crafting_remainder` for the bowl) |
| `minecraft:iron_sword` | a weapon; damage and durability through `components` |
| `minecraft:snowball` | a thrown item (an entity type of the mod's with `template = "minecraft:snowball"` flies as one) |
| `minecraft:pig_spawn_egg`, `minecraft:zombie_spawn_egg` | a spawn egg: the id ends in `_spawn_egg` and names the kind |

## Block templates

| Template | Good for |
|---|---|
| `minecraft:iron_block`, `minecraft:stone`, `minecraft:amethyst_block` | a plain block; `random_ticks = true` makes it tick |
| `minecraft:sculk` | the parasite hive: a block with stages and a block entity |
| `minecraft:chorus_plant` | a pipe or cable that joins its neighbours (`connects_to`) |
| `minecraft:oak_sign`, `minecraft:oak_wall_sign` | a sign of the mod's own |

## Mob templates

`minecraft:zombie` (the parasite), `minecraft:pig` (the example mob); any vanilla mob works, with its species'
movement, sounds and animation. `goals = "none"` leaves the behaviour to the scripts.

## Damage types

`minecraft:on_fire`, `minecraft:in_fire`, `minecraft:lava`, `minecraft:generic`, `minecraft:fall`,
`minecraft:player_attack`, `minecraft:mob_attack`: `hit.damage_type` in `on_hurt`, `cause.damage_type` in
`on_death`. `/damage @s 5 minecraft:generic` deals one from the chat.

## Death message keys

`cause` in `P:on_death` is the message's key: `death.attack.lava`, `death.attack.generic`,
`death.attack.fall`, `death.attack.mob` (`...player` for a player's blow), or nil.

## Sounds and particles

Sounds: `minecraft:entity.player.levelup`, `minecraft:entity.chicken.ambient`, `minecraft:entity.zombie.infect`,
`minecraft:entity.endermite.ambient`, `minecraft:entity.silverfish.hurt`.
Particles: `minecraft:happy_villager`, `minecraft:cloud`, `minecraft:heart`, `minecraft:end_rod`,
`minecraft:firework`, `minecraft:crimson_spore`.

## Status effects

`minecraft:speed`, `minecraft:slowness`, `minecraft:regeneration`, `minecraft:levitation`, `minecraft:glowing`,
`minecraft:nausea`, `minecraft:instant_health`; a mod's own as `<mod>:<name>` from `registry.mob_effect`.

## Inventory slots

`player:inventory()` is by number, 1 to 36: 1 to 9 the hotbar, 10 to 36 the main inventory, an empty slot
absent. `item.plain` on a stack is true when it carries no components beyond its template's.

## Equipment slots

`mainhand`, `offhand`, `head`, `chest`, `legs`, `feet`: `slot` in `E:on_equip`.
