# Frequently Asked Questions

## Where is the log?

The log is `logs/latest.log` in the game folder. A mod's lines start with `[lua:<mod id>]`, and a script error
includes its file and line.

With `--dev-tools`, two commands help too: `/lua` lists the mods with their handlers and errors, and `/goals <mob>`
shows a mob's goals.

## Why does my change do nothing?

Each kind of file reloads in its own way:

- `scripts/init.lua` and what it requires reload with `/reload`.
- `scripts/registry.lua` needs the game restarted.
- Assets reload with the resource-reload key.

[Reload and restart](../guides/reload-and-restart.md) has the details.

## Why does the game say my mod is not loaded?

The mod's `depends` asks for a newer modkit than the one installed. The log says which version it found:

```
Horizon: Lua mod my_mod not loaded: it needs horizon_modkit >= 0.7 (found 0.6.0)
```

Update the modkit, or lower the version in `depends` ([Versions](../api.md#versions)).

## Why is `horizon.on("player_jioned")` refused?

The hook name is misspelled. The game refuses an unknown hook when the script loads, and names the line.
`cargo horizon-mod check` reports it without a game, and luau-lsp marks it in your editor
([getting started](../getting-started.md#4-check-it-without-a-game)).

## Why does a give to another player do nothing?

Inside a player's own callback, such as their click or their command, only that player is reached. Give the item on
the next tick instead, with `horizon.after(1, function() ... end)`
([players and events](../guides/players-and-events.md)).

## Why does my block's click run twice?

The game tries the main hand and then the off hand, and `on_use` runs for each. Make the callback do something that
is the same when done twice, such as lighting a lamp rather than toggling it, or read the block's state first
([blocks](../guides/blocks.md)).

## What does `unknown action schedule_tick` mean?

The block method was called where it does not work:

- `block:schedule_tick` and `block:handled()` work in `on_random_tick` and `on_tick` only.
- `block:set` works there, and in `on_use` and `on_block_entity_tick`.
- `block:replace` needs the world at hand, so it does not work in the two ticks.

## Why does nothing I log at load show?

The log is not open yet when the scripts first run. Log from a timer, such as `horizon.after(1, ...)`, or from
`on_join`.

## Why does the bed callback never run?

The game's own checks come first. It must be night in the overworld, with no monster near the bed. Type
`/time set night` and try again.

## Where do my settings go?

Settings go to `config/<mod id>.json` in the game folder. The file is written with the defaults on the first run
([timers and saved data](../guides/timers-and-data.md)).

## Can a script draw a screen, run on the client, or add a key binding?

No. Every script runs on the server side of the game. Titles, the action bar, chat and commands are a script's user
interface. The engine's
[lua-bindings.md](https://github.com/whos-carmen/horizon/blob/engine-work/docs/lua-bindings.md) lists what is not
there yet, and the shape it is planned to take.
