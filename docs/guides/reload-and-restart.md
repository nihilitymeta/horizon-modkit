# Reload and restart

What a change needs, from least to most.

```
/reload            scripts/init.lua and what it requires run again; recipes, loot tables and tags reload
resource reload     the resource-reload key: textures, models, blockstates, the lang file
restart the game   scripts/registry.lua: a new or changed item, block, entity type, effect or creative tab
```

**`/reload`** reads the mod's scripts again and runs `scripts/init.lua` afresh: handlers, goals, timers and
`require`d modules are forgotten and declared again, settings are read again (`M:config`); the Lua state and its
globals stay. Saved tables (`world_data`, `player:data()`, `mob.data`, `block.data`) are on the world, so they stay. A script error at reload is in the
log and in `/lua` with its file and line; the mod keeps running with what loaded.

**Assets** (the resource-reload key) are read again from `assets/`; a texture painted while the game runs shows
at once.

**The registry** script runs once, before the world loads, because what it declares gets ids the world holds:
anything new in it, or a changed template, property or state, needs the game started again. A world keeps the
blocks and mobs of a mod it was saved with.

**Settings** (`config/<mod>.json`) are read at load and at `/reload`; a command that changes one calls
`M:save_config()`.

**Headless.** `cargo horizon-mod check <folder> --game <horizon-client> --dev-mod <modkit>` loads the scripts
without a world and says which file and line fails, in a second, before any of the above
([getting started](../getting-started.md#4-check-without-a-game)).
