# Example Mod

One of everything a Lua mod does on [Horizon Modkit](../../README.md), a file per concept, each starting with a
comment that says what it shows and how to see it in game. The guides in [docs/guides](../../docs/guides) point at
these files; [docs/api.md](../../docs/api.md) is the reference.

```
horizon-mod.toml              # the manifest: capabilities, depends = ["horizon_modkit >= 0.7"]
scripts/registry.lua          # what it adds: an item, a snack, a block, a mob and its egg, an effect, a tab
scripts/init.lua              # what it does: requires one file per concept
scripts/example/mod.lua       # the mod object the files share
scripts/example/item.lua      # items and their callbacks
scripts/example/block.lua     # a block with a state, a block entity and ticks
scripts/example/mob.lua       # a mob with goals and callbacks
scripts/example/players.lua   # what players do
scripts/example/command.lua   # commands
scripts/example/timers_and_data.lua   # settings, timers, saved data
scripts/example/spawning.lua  # making mobs
scripts/example/effects.lua   # sounds, particles, titles, status effects
```

Run it beside the modkit, from the fork's `engine-work` build:

```sh
horizon-client --dev-tools --dev-mod /path/to/horizon-modkit --dev-mod /path/to/horizon-modkit/examples/example_mod
```

Then `/example` in the chat lists its commands. Every file logs an `EXAMPLE ...` line when its concept runs;
`tools/example-check.sh` drives them all from a script, and `tools/check.sh` loads the scripts without a game.
