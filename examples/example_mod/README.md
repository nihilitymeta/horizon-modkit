# Example Mod

The example mod shows one of everything a Lua mod can do with [Horizon Modkit](../../README.md), with one file for
each concept. Each file starts with a comment that says what it shows and how to see it in the game. The
[guides](../../docs/guides) point at these files, and the [API reference](../../docs/api.md) describes every call
they make.

| File | What it shows |
|---|---|
| `horizon-mod.toml` | the manifest: capabilities, and `depends = ["horizon_modkit >= 0.7"]` |
| `scripts/registry.lua` | what the mod adds: it requires one module for each kind, in order |
| `scripts/registry/items.lua` | an item, a snack and a lure, with their names (`registry.lang`) |
| `scripts/registry/blocks.lua` | a block and a nest |
| `scripts/registry/mobs.lua` | a mob, its spawn egg and its natural spawns |
| `scripts/registry/effects.lua` | a mob effect |
| `scripts/registry/tabs.lua` | the creative tab, last, so it lists what the other modules declared |
| `scripts/server/init.lua` | what the mod does: it requires one file for each concept |
| `scripts/server/example/mod.lua` | the mod object that the other files share |
| `scripts/server/example/item.lua` | items and their callbacks |
| `scripts/server/example/lure.lua` | an item that summons a mob when used, and converts a zombie when it hits one |
| `scripts/server/example/block.lua` | a block with a state property, a block entity and ticks |
| `scripts/server/example/nest.lua` | a block with stages that grows, breeds mobs and is spent, with loot for each stage |
| `scripts/server/example/mob.lua` | a mob with goals and callbacks; the players who feed it become its keepers |
| `scripts/server/example/conversion.lua` | goals on a vanilla kind: zombies stalk players, and become example mobs |
| `scripts/server/example/players.lua` | what players do: joining, chatting (with a keeper's suffix), blocks, a refused bed |
| `scripts/server/example/command.lua` | commands |
| `scripts/server/example/timers_and_data.lua` | settings, timers, saved data, and a cull that follows the settings |
| `scripts/server/example/spawning.lua` | making mobs |
| `scripts/server/example/effects.lua` | sounds, particles, titles and status effects |

## Running it

Run the example mod next to the modkit, with Event Horizon's `engine-work` build:

```sh
horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/horizon-modkit/examples/example_mod
```

Then type `/example` in the chat to list its commands.

Every file logs an `EXAMPLE ...` line when its concept runs. `tools/example-check.sh` drives them all from a script,
and `tools/check.sh` loads the scripts without a game. [Testing](../../docs/testing.md) describes the other checks.
