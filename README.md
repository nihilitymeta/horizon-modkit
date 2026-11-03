# Horizon Modkit

A library for [Horizon](https://playhorizon.dev) mods written in Lua: items, blocks, mobs, goals, players and
commands as classes with callbacks, the way a NeoForge or Fabric mod declares them, over the engine fork
[whos-carmen/horizon](https://github.com/whos-carmen/horizon) (branch `engine-work`, the game to run them
with). No Rust, no patches. Experimental, as the `scripts` capability is.

## Start here

- [Getting started](docs/getting-started.md): from `cargo horizon-mod new` to an item of your own in the game.
- [The example mod](examples/example_mod): one of everything, a file per concept, each saying how to see it.
- [Horizon Parasite Mod](https://github.com/whos-carmen/horizon-parasite-mod): a real mod built with this.

## Guides

One screen each, one code block lifted from the example mod, a link to the reference.

| | |
|---|---|
| [Items](docs/guides/items.md) | an item's callbacks: used, used on a block, a blow, eaten, crafted, dropped |
| [Blocks](docs/guides/blocks.md) | a state of its own, a block entity, random and scheduled ticks, placed and broken |
| [Mobs and goals](docs/guides/mobs.md) | a mob's goals and callbacks, vanilla mobs too |
| [Players and events](docs/guides/players-and-events.md) | join, death, chat, blocks, pickups, sleep |
| [Commands](docs/guides/commands.md) | `/mymod ...` with typed arguments |
| [Timers and saved data](docs/guides/timers-and-data.md) | settings, timers, tables saved with the world, a player or a mob |
| [Sounds and effects](docs/guides/sounds-and-effects.md) | sounds, particles, titles, status effects |
| [Spawning](docs/guides/spawning.md) | eggs, natural spawns, summons |
| [Models and animation](docs/guides/models-and-animation.md) | a mob's look and sounds, item and block models |
| [Reload and restart](docs/guides/reload-and-restart.md) | what a change needs |

**Reference:** [docs/api.md](docs/api.md), every class and callback; [ids](docs/reference/ids.md) a mod keeps
reaching for; the [FAQ](docs/reference/faq.md). The engine's
[lua-bindings.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/lua-bindings.md) is the layer
under it all.

## In short

```toml
# horizon-mod.toml; scripts/init.lua below
capabilities = ["registries", "scripts"]
experimental = ["scripts"]
depends = ["horizon_modkit >= 0.7"]
```

```lua
local modkit = require("@modkit")
local M = modkit.mod("my_mod")

-- A right click with the wand, in the air or on a block: a word to everyone,
-- sparks where the player stands. Return true and the click is taken
-- (nothing else acts on it).
local Wand = M:item("wand")
function Wand:on_use(item, player)
  local p = player.position
  horizon.broadcast(("%s waves the wand"):format(player.name))
  modkit.particles("minecraft:happy_villager", p.x, p.y + 1, p.z, 12, 0.5, 0.05)
  return true
end
```

Run: `horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my_mod` (or install both
`.hmod`s). Scripts reload on `/reload`; `scripts/registry.lua`, what the mod adds, runs at start.

## Tools

`tools/check.sh` loads the modkit, the example mod and a mod given headlessly in the game's runtime and runs
luau-lsp over them; `tools/scaffold-check.sh` builds, checks and plays a scaffolded mod; `tools/example-check.sh`
plays the example mod through every concept; `tools/docs-check.sh` checks the docs' links and that every
guide's code is in the example it names. Each takes `HORIZON=/path/to/horizon` (built).

## License

MIT.
