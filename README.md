# Horizon Modkit

Horizon Modkit is a Lua library for writing [Horizon](https://playhorizon.dev) mods. You declare items, blocks,
mobs, goals, players and commands as classes with callbacks, the way a NeoForge or Fabric mod declares them. You
don't need Rust or patches.

The modkit runs on Event Horizon ([whos-carmen/horizon](https://github.com/whos-carmen/horizon)), branch
`engine-work`. Scripted mods are an experimental feature of Event Horizon.

## Start here

- [Getting started](docs/getting-started.md) takes you from `cargo horizon-mod new` to an item of your own in the
  game.
- [The example mod](examples/example_mod) has one file for each concept, and each file says how to see it in the
  game.
- [Horizon Parasite Mod](https://github.com/whos-carmen/horizon-parasite-mod) is a mod built with the modkit.

## Guides

Each guide fits on one screen. It explains one concept with a code block taken from the example mod, and links to
the reference.

| Guide | What it covers |
|---|---|
| [Items](docs/guides/items.md) | an item's callbacks: used, used on a block, a blow, eaten, crafted, dropped |
| [Blocks](docs/guides/blocks.md) | state properties, block entities, random and scheduled ticks, placing and breaking |
| [Mobs and goals](docs/guides/mobs.md) | a mob's goals and callbacks, on your own mobs and on vanilla ones |
| [Players and events](docs/guides/players-and-events.md) | joining, dying, chatting, breaking blocks, picking up items, sleeping |
| [Commands](docs/guides/commands.md) | `/mymod ...` commands with typed arguments |
| [Timers and saved data](docs/guides/timers-and-data.md) | settings, timers, and tables saved with the world, a player or a mob |
| [Sounds and effects](docs/guides/sounds-and-effects.md) | sounds, particles, titles and status effects |
| [Spawning](docs/guides/spawning.md) | spawn eggs, natural spawning and summoning |
| [Models and animation](docs/guides/models-and-animation.md) | a mob's look and sounds, item and block models |
| [Reload and restart](docs/guides/reload-and-restart.md) | what each kind of change needs |

## Reference

- [API reference](docs/api.md): every class, function and callback of the modkit
- [Ids](docs/reference/ids.md): vanilla ids that mods often need
- [FAQ](docs/reference/faq.md): common problems and their fixes
- [Testing](docs/testing.md): what to look for in the game, and the scripts that check a mod
- The engine's [lua-bindings.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/lua-bindings.md):
  the engine API under the modkit

## A first mod

A mod needs a manifest and a script. The manifest, `horizon-mod.toml`, asks for scripts and names the modkit:

```toml
# horizon-mod.toml; scripts/init.lua below
capabilities = ["registries", "scripts"]
experimental = ["scripts"]
depends = ["horizon_modkit >= 0.7"]
```

The script, `scripts/init.lua`, gives a wand a right-click action:

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

To run it, start the game with the modkit and your mod:

```sh
horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/my_mod
```

You can also install both as `.hmod` files. `/reload` runs the scripts again. `scripts/registry.lua`, which declares
what the mod adds, runs once, when the game starts.

## Tools

The `tools/` folder holds scripts that check the modkit and your mods. Each one takes `HORIZON=/path/to/horizon`, a
built checkout of the engine.

| Script | What it does |
|---|---|
| `tools/check.sh` | loads the modkit, the example mod, the probes and a mod you name, without a game, and runs luau-lsp over them |
| `tools/scaffold-check.sh` | creates a mod with the template, then builds, checks and plays it |
| `tools/example-check.sh` | plays the example mod through every concept |
| `tools/hook-coverage.sh` | drives every hook the engine lists and every modkit callback |
| `tools/steps-check.sh` | shows one result for each part of the Lua API |
| `tools/docs-check.sh` | checks the links in the docs, and that each guide's code is in the example file it names |

[Testing](docs/testing.md) describes what each one shows.

## License

MIT.
