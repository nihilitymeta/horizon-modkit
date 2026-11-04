-- Settings, timers and saved data (guide: docs/guides/timers-and-data.md;
-- reference: docs/api.md, "The mod", "Timers and saved data").
-- See it in game: config/example_mod.json in the game folder after the first
-- run; "EXAMPLE timer" in the log two seconds after a load, a report every
-- minute, which culls example mobs past the settings' limit; /example report
-- reads the world's count, /example max 3 lowers the limit.
local modkit = require("@modkit")
local M = require("@example/mod")

-- The mod's settings: config/example_mod.json, written with these defaults
-- the first time, for the player to edit. Read at load; what the scripts
-- read is this table. A command below changes one and saves it.
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

-- A number read, or set and saved: the cull's limit.
M:command("example max [limit:integer]", 2, function(player, args)
  if args.limit then
    cfg.max_mobs = args.limit
    M:save_config()
    horizon.log(("EXAMPLE command max %d by %s"):format(cfg.max_mobs, player.name))
  end
  horizon.feedback(("at most %d example mobs; a nest breeds %d"):format(cfg.max_mobs, cfg.nest_breeds))
end)

return cfg
