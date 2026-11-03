# Horizon Modkit

A library for [Horizon](https://playhorizon.dev) mods written in Lua: entities, blocks and goals as classes with
lifecycle callbacks, the way a NeoForge or Fabric mod declares them. Install it beside your mod; your mod says
`depends = ["horizon_modkit"]` and `require("modkit")`. It needs a game built from the engine fork
[whos-carmen/horizon](https://github.com/whos-carmen/horizon), branch `engine-work`. Experimental, as the
`scripts` capability is.

**Reference:** [docs/api.md](docs/api.md) (entities, goals, the mob, blocks, `scripts/registry.lua`).
The engine's [lua-bindings.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/lua-bindings.md)
is the layer under it.

## A mod with it

```toml
# horizon-mod.toml
capabilities = ["registries", "scripts"]
experimental = ["scripts"]
depends = ["horizon_modkit"]
```

```lua
-- scripts/registry.lua: what the mod adds (or JSON under data/)
registry.entity_type("crawler", { template = "minecraft:zombie", attributes = { max_health = 30 }, goals = "none" })
registry.block("hive", { template = "minecraft:sculk", item = true })
```

```lua
-- scripts/init.lua: what it does
local modkit = require("modkit")
local M = modkit.mod("my_mod")

local Crawler = M:entity("crawler")
Crawler:goals { { 1, modkit.goals.HuntPlayer(32, 1.2, 20) }, { 5, modkit.goals.Wander(6) } }
function Crawler:on_hurt(mob, hit) if hit.damage_type == "minecraft:on_fire" then hit:cancel() end end
function Crawler:on_interact(mob, player, held)
  mob.data.pets = (mob.data.pets or 0) + 1      -- saved with the mob
  return true                                   -- the click is taken
end

local Hive = M:block("hive")
Hive:block_entity { ticks = true, data = { charge = 0 } }
function Hive:on_block_entity_tick(block)
  block.data.charge = block.data.charge + 1
  if block.data.charge >= 400 then block:summon("my_mod:crawler", 0, 1, 1); block.data.charge = 0 end
end
```

Run: `horizon-client … --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my_mod` (or install both `.hmod`s and
turn them on). Scripts reload on `/reload`; the registry script runs at start. With `--dev-tools`, `/goals <mob>`
shows a mob's goals and `/lua` the mods, their handlers and errors.

## License

MIT.
