# FAQ

**Where is the log?** `logs/latest.log` in the game folder; a mod's lines are `[lua:<mod id>]`, a script error
has its file and line. With `--dev-tools`, `/lua` in the game lists the mods, their handlers and errors, and
`/goals <mob>` a mob's goals.

**My change does nothing.** `scripts/init.lua` and what it requires reload with `/reload`; `scripts/registry.lua`
needs the game restarted; assets need the resource-reload key ([reload and restart](../guides/reload-and-restart.md)).

**The game says the mod is not loaded.** Its `depends` names a modkit version newer than the one installed:
`Horizon: Lua mod my_mod not loaded: it needs horizon_modkit >= 0.7 (found 0.6.0)`. Update the modkit, or lower
the floor ([api.md, Versions](../api.md#versions)).

**`horizon.on("player_jioned")`: no such hook.** The hook name is misspelled; the game refuses it at load with
the line. `cargo horizon-mod check` says so without a game, and luau-lsp marks it in the editor
([getting started](../getting-started.md#4-check-without-a-game)).

**A give to another player does nothing.** Inside a player's own callback (their click, their command) only
that player is reached. Do it next tick: `horizon.after(1, function() ... end)`
([players and events](../guides/players-and-events.md)).

**My block's click runs twice.** The game tries the main hand and then the off hand, and `on_use` runs for
each. Do one thing that is the same done twice (light the lamp, not toggle it), or read the state first
([blocks](../guides/blocks.md)).

**`unknown action schedule_tick`.** `block:schedule_tick` and `block:handled()` work in `on_random_tick` and
`on_tick` only; `block:set` works there, in `on_use` and in `on_block_entity_tick`; `block:replace` needs a world
at hand (not the two ticks).

**Nothing I log at load shows.** The log is not open yet when the scripts first run; log from a timer
(`horizon.after(1, ...)`) or from `on_join`.

**The bed callback never runs.** The game's own checks come first: night in the overworld, no monster near.
`/time set night`.

**Where do my settings go?** `config/<mod id>.json` in the game folder, written with the defaults on the first
run ([timers and saved data](../guides/timers-and-data.md)).

**Can a script draw a screen, run on the client, or add a keybind?** No: every script runs on the server side
of the game; titles, the action bar, chat and commands are the UI. The engine's
[lua-bindings.md](https://github.com/whos-carmen/horizon/blob/lua-bindings/docs/lua-bindings.md) lists what is
not there yet and the shape it will take.
