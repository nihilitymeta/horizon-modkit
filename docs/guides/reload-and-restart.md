# Reload and Restart

Each kind of change needs a different step before it shows in the game, from least to most:

| Step | What it reloads |
|---|---|
| `/reload` | `scripts/init.lua` and what it requires; recipes, loot tables and tags |
| the resource-reload key | textures, models, blockstates and the lang file |
| restarting the game | `scripts/registry.lua` and `scripts/registry/`: a new or changed item, block, entity type, effect or creative tab |

## `/reload`

`/reload` reads the mod's scripts again and runs `scripts/init.lua` from the start. Handlers, goals, timers and
`require`d modules are dropped and declared again, and the settings are read again (`M:config`). The Lua state and
its globals stay.

Saved tables, such as `horizon.world_data()`, `player:data()`, `mob.data` and `block.data`, belong to the world, so
they stay too.

A script error during a reload appears in the log and in `/lua`, with its file and line. The mod keeps running with
what it had before the reload.

## Assets

The resource-reload key reads `assets/` again. A texture that you paint while the game runs shows at once.

## The registry script

The registry script and its modules run once, before the world loads, because what they declare gets ids that the
world keeps. Anything new in them, or a changed template, property or state, needs the game restarted. A world keeps
the blocks and mobs of a mod that it was saved with.

## Settings

The settings file, `config/<mod>.json`, is read at load and at `/reload`. A command that changes a setting calls
`M:save_config()`.

## Checking without a game

`cargo horizon-mod check <folder> --game <horizon-client> --dev-mod <modkit>` loads the scripts without a world, and
names the file and line of anything that fails. It takes about a second, so run it before any of the steps above
([getting started](../getting-started.md#4-check-it-without-a-game)).
