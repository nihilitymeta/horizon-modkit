# Timers and Saved Data

This guide covers three things that keep a mod's state:

- settings, in a file that players can edit
- timers, which run code later or at intervals
- saved tables, which are kept with the world, a player or a block with a block entity

The examples come from
[scripts/server/example/timers_and_data.lua](../../examples/example_mod/scripts/server/example/timers_and_data.lua). The reference
is [`M:config`](../api.md#mconfigdefaults) and [Timers and saved data](../api.md#timers-and-saved-data).

The example reads its settings, logs a line two seconds after loading, and every minute counts its mobs and culls
the ones over the limit:

```lua
local cfg = M:config {
  greeting = "Welcome to the example",
  report_minutes = 1,
  max_mobs = 12,     -- more example mobs than this and the minute timer culls the rest
  nest_breeds = 3,   -- example mobs a nest breeds before it is spent (scripts/server/example/nest.lua)
}

-- Once, in 40 ticks (two seconds): a timer runs with the reads and actions
-- at hand.
horizon.after(40, function()
  horizon.log(("EXAMPLE timer: two seconds after the load, %d player(s) here"):format(#horizon.players()))
end)

-- Every so many minutes: the world's own saved table, kept through saves
-- (horizon.world_data(); a player's is player:data() or
-- horizon.player_data(uuid)), written back after the callback. Then the
-- cull: example mobs past the settings' limit are killed by a command, as
-- the console would run it.
horizon.every(1200 * cfg.report_minutes, function()
  local w = horizon.world_data()
  w.reports = (w.reports or 0) + 1
  local count = 0
  for _, m in ipairs(horizon.mobs()) do
    if m.kind == "example_mod:example_mob" then count = count + 1 end
  end
  horizon.log(("EXAMPLE report %d: %d player(s), %d mob(s) loaded, %d example mob(s)"):format(w.reports, #horizon.players(), #horizon.mobs(), count))
  if count > cfg.max_mobs then
    modkit.run_command(("kill @e[type=example_mod:example_mob,sort=random,limit=%d]"):format(count - cfg.max_mobs))
    horizon.broadcast(("%d example mob(s) culled: the world holds %d"):format(count - cfg.max_mobs, cfg.max_mobs))
    horizon.log(("EXAMPLE cull: %d example mob(s) over %d"):format(count - cfg.max_mobs, cfg.max_mobs))
  end
end)
```

## Settings

`M:config(defaults)` reads `config/<mod id>.json` from the game folder. It fills in the defaults for the keys that
the file lacks, and saves the file when that added any, so the file is there to edit after the first run. The scripts
read the settings from the table it returns.

`M:save_config()` writes the table back after a command has changed it. The cull reads its limit from the table each
time, so a change takes effect at once:

```lua
M:command("example max [limit:integer]", 2, function(player, args)
  if args.limit then
    cfg.max_mobs = args.limit
    M:save_config()
    horizon.log(("EXAMPLE command max %d by %s"):format(cfg.max_mobs, player.name))
  end
  horizon.feedback(("at most %d example mobs; a nest breeds %d"):format(cfg.max_mobs, cfg.nest_breeds))
end)
```

## Timers

- `horizon.after(ticks, fn)` runs `fn` once, after *ticks* ticks.
- `horizon.every(ticks, fn)` runs `fn` every *ticks* ticks.

There are 20 ticks in a second. Inside a timer the whole world is at hand: reads, summons, blocks and every player.
A timer is the way out of a callback that can't reach the world, or that reaches one player only.

## Saved tables

| Table | Where it is kept |
|---|---|
| `horizon.world_data()` | the world |
| `player:data()` | a player |
| `mob.data` | a mob, in a callback with a host |
| `block.data` | a block with a block entity, in the ticks |

Each table is empty at first. It is written back after the callback, and kept through saves under the mod's own id,
apart from any other mod's data. It can hold numbers, strings, booleans and nested tables. The saved table is
fetched per callback: a table stored from an earlier callback (an upvalue) is stale and writes nothing, so read
`mob.data` again in the callback that changes it. A click names no block
data; a goal and the mid-event callbacks read `mob.data` as nil, and indexing that nil raises.

## See it in the game

- After the first run, open `config/example_mod.json` in the game folder.
- Type `/example report`, or `/example greeting <text>`.
- Type `/example max 1` with a few example mobs about. They are culled within the minute.
