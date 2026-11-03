-- Settings, timers and saved data (guide: docs/guides/timers-and-data.md;
-- reference: docs/api.md, "Settings", "Timers and saved data").
-- See it in game: config/example_mod.json in the game folder after the first
-- run; "EXAMPLE timer" in the log two seconds after a load, a report every
-- minute; /example report reads the world's count.
local M = require("@example/mod")

-- The mod's settings: config/example_mod.json, written with these defaults
-- the first time, for the player to edit. Read at load; what the scripts
-- read is this table. A command below changes one and saves it.
local cfg = M:config {
  greeting = "Welcome to the example",
  report_minutes = 1,
}

-- Once, in 40 ticks (two seconds): a timer runs with the reads and actions
-- at hand.
horizon.after(40, function()
  horizon.log(("EXAMPLE timer: two seconds after the load, %d player(s) here"):format(#horizon.players()))
end)

-- Every so many minutes: the world's own saved table, kept through saves
-- (horizon.world_data(); a player's is player:data() or
-- horizon.player_data(uuid)), written back after the callback.
horizon.every(1200 * cfg.report_minutes, function()
  local w = horizon.world_data()
  w.reports = (w.reports or 0) + 1
  horizon.log(("EXAMPLE report %d: %d player(s), %d mob(s) loaded"):format(w.reports, #horizon.players(), #horizon.mobs()))
end)

M:command("example report", 0, function(player, args)
  local w = horizon.world_data()
  horizon.feedback(("%d report(s) so far in this world, one every %d minute(s)"):format(w.reports or 0, cfg.report_minutes))
end)

-- A setting changed from the game and saved to the file.
M:command("example greeting <text:text>", 2, function(player, args)
  cfg.greeting = args.text
  M:save_config()
  horizon.feedback(("the greeting is now %q"):format(cfg.greeting))
end)

return cfg
