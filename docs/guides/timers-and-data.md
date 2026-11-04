# Timers and saved data

Settings in a file the player can edit, timers that run later or every so often, and tables that are saved with
the world, a player or a mob. Example:
[scripts/example/timers_and_data.lua](../../examples/example_mod/scripts/example/timers_and_data.lua).
Reference: [api.md, Settings](../api.md#settings-mconfigdefaults), [Timers and saved data](../api.md#timers-and-saved-data).

```lua
local cfg = M:config {
  greeting = "Welcome to the example",
  report_minutes = 1,
  max_mobs = 12,     -- more example mobs than this and the minute timer culls the rest
  nest_breeds = 3,   -- example mobs a nest breeds before it is spent (scripts/example/nest.lua)
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

**Settings.** `M:config(defaults)` reads `config/<mod id>.json` from the game folder, fills in the defaults for
the keys it lacks and saves it when that added any, so the file is there to edit after the first run; the
table is what the scripts read. `M:save_config()` writes it back after a command changed it: a setting the
scripts act on, such as the cull's limit, is read live from the table.

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

**Timers.** `horizon.after(ticks, fn)` once, `horizon.every(ticks, fn)` repeating (20 ticks a second). Inside,
the world is at hand: reads, summons, blocks, every player. A timer is the way out of a callback that has no
world, or that reaches one player only.

**Saved tables.** `horizon.world_data()` on the world, `player:data()` on a player, `mob.data` on a mob,
`block.data` on a block with a block entity: a table, empty at first, written back after the callback, kept
through saves under the mod's own id apart from any other mod's. Numbers, strings, booleans and nested tables.

See it in game: `config/example_mod.json` after the first run, `/example report`, `/example greeting <text>`,
`/example max 1` with a few example mobs about (culled within the minute).
