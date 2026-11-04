# Example Mod

The example mod shows one of everything a Lua mod can do with [Horizon Modkit](../../README.md), with one file for
each concept. Each file starts with a comment that says what it shows and how to see it in the game. The
[guides](../../docs/guides) point at these files, and the [API reference](../../docs/api.md) describes every call
they make.

| File | What it shows |
|---|---|
| `horizon-mod.toml` | the manifest: capabilities, and `depends = ["horizon_modkit >= 0.7"]` |
| `scripts/registry.lua` | what the mod adds: an item, a snack, a lure, a block, a nest, a mob and its egg, an effect and a creative tab |
| `scripts/init.lua` | what the mod does: it requires one file for each concept |
| `scripts/example/mod.lua` | the mod object that the other files share |
| `scripts/example/item.lua` | items and their callbacks |
| `scripts/example/lure.lua` | an item that summons a mob when used, and converts a zombie when it hits one |
| `scripts/example/block.lua` | a block with a state property, a block entity and ticks |
| `scripts/example/nest.lua` | a block with stages that grows, breeds mobs and is spent, with loot for each stage |
| `scripts/example/mob.lua` | a mob with goals and callbacks; the players who feed it become its keepers |
| `scripts/example/conversion.lua` | goals on a vanilla kind: zombies stalk players, and become example mobs |
| `scripts/example/players.lua` | what players do: joining, chatting (with a keeper's suffix), blocks, a refused bed |
| `scripts/example/command.lua` | commands |
| `scripts/example/timers_and_data.lua` | settings, timers, saved data, and a cull that follows the settings |
| `scripts/example/spawning.lua` | making mobs |
| `scripts/example/effects.lua` | sounds, particles, titles and status effects |

## Running it

Run the example mod next to the modkit, with the fork's `engine-work` build:

```sh
horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/horizon-modkit/examples/example_mod
```

Then type `/example` in the chat to list its commands.

Every file logs an `EXAMPLE ...` line when its concept runs. `tools/example-check.sh` drives them all from a script,
and `tools/check.sh` loads the scripts without a game. [Testing](../../docs/testing.md) describes the other checks.
