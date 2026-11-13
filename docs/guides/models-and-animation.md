# Models and Animation

A mob of your own is drawn as its template, unless its declaration says otherwise. It can name:

- a `texture` laid out as the template's texture
- a `model` of its own, with an `animation` set that moves its parts
- `sounds`

The worked example is the parasite mod's
[scripts/registry.lua](https://github.com/nihilitymeta/horizon-parasite-mod/blob/example-archive/scripts/registry.lua),
at the `example-archive` tag of that repository. It declares a mob with a zombie's layout, a swollen head and spines.
The reference is [A mob's look and sounds](../api.md#a-mobs-look-and-sounds).

```lua
registry.entity_type("parasite", {
  template = "minecraft:zombie",
  attributes = { max_health = 30, movement_speed = 0.3, attack_damage = 4, follow_range = 32 },
  size = { width = 0.6, height = 1.95 },
  texture = ns .. ":entity/parasite",
  model = ns .. ":entity/parasite",        -- below: a zombie's parts, a swollen head, spines down the back
  animation = "zombie",                     -- arms out, as a zombie walks
  sounds = { ambient = "minecraft:entity.endermite.ambient", hurt = "minecraft:entity.silverfish.hurt", death = "minecraft:entity.silverfish.death", step = "minecraft:entity.silverfish.step" },
  goals = "none",
  flags = { burns_in_day = false },
})
```

## The texture

The texture is `assets/<mod>/textures/entity/<name>.png`, laid out as the template's texture, such as a zombie's
64 by 64 pixels. The template's model wears it as it is. Without a texture, the mob uses the template's.

## The model

A model is written with `registry.asset("models/entity/<name>", { texture_size, parts })`, or as the same JSON
file. Its parts are named, and each part has:

- an `offset`
- a `rotation`, in degrees
- `cubes`, each with `origin`, `size`, `uv`, `inflate` and `mirror`
- `children`

This is how a vanilla model layer is written. The animation set moves the parts by name.

## The animation

The animation set is one of vanilla's, by name: `zombie` (arms out), `skeleton`, `quadruped` (a pig or a cow),
`iron_golem`, `spider`, and the others that the engine's
[mob-ai-hooks.md](https://github.com/nihilitymeta/horizon/blob/engine-work/docs/mob-ai-hooks.md) lists. The set moves
the parts with the names that it expects, such as `head`, `body`, `right_arm` and `left_leg`. A model of your own
must use those names for the parts that move.

## Sounds

`sounds` names vanilla's sound events for `ambient`, `hurt`, `death` and `step`.

## Items and blocks

Items and blocks are drawn from `assets/`, as vanilla's are:

- `items/<name>` names an item's model.
- `models/item/<name>` and `models/block/<name>` are the models.
- `blockstates/<name>` picks a block model for each state.

The example mod writes all of these as tables in its registry script, and uses vanilla textures.

A new or changed model needs the game restarted ([reload and restart](reload-and-restart.md)).
