# Models and animation

A mob of yours is drawn as its template unless its declaration says otherwise: a `texture` laid out as the
template's, or a `model` of its own with an `animation` set that moves its parts, and `sounds`. The worked
example is the parasite mod's
[scripts/registry.lua](https://github.com/whos-carmen/horizon-parasite-mod/blob/example-block/scripts/registry.lua),
a zombie's layout with a swollen head and spines. Reference: [api.md, A mob's look and sounds](../api.md#a-mobs-look-and-sounds).

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

**The texture** is `assets/<mod>/textures/entity/<name>.png`, in the template's layout (a zombie's 64 by 64),
so the template's model wears it as it is. With no texture, the template's.

**The model** is `registry.asset("models/entity/<name>", { texture_size, parts })` (or the JSON file): parts by
name, each with `offset`, `rotation` in degrees, `cubes` of `origin`, `size`, `uv`, `inflate`, `mirror`, and
`children`, as a vanilla layer is written. The part names are what the animation set moves.

**The animation** set is one of vanilla's, by name: `zombie` (arms out), `skeleton`, `quadruped` (a pig, a cow),
`iron_golem`, `spider`, and the rest the engine's [mob-ai-hooks.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/mob-ai-hooks.md)
lists; it moves the parts named as that set names them (`head`, `body`, `right_arm`, `left_leg`...), so a model
of your own keeps those names for the parts that move.

**Sounds** are `ambient`, `hurt`, `death` and `step`, vanilla's sound events by name.

**Items and blocks** are drawn from `assets/` as vanilla's are: `items/<name>` names the model,
`models/item/<name>` and `models/block/<name>` are the models, `blockstates/<name>` picks a block model per
state. The example mod writes all of them as tables in its registry script and borrows vanilla textures.

A new or changed model needs the game restarted ([reload and restart](reload-and-restart.md)).
