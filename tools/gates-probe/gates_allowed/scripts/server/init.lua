-- The capability gates, allowed side: this mod declares `world-settings` and
-- `server-admin`, so the rule, the time and the display slot it writes must
-- take effect, while a rule off the allow-list and a wrong-kind value still
-- fail, and a kick of a name nobody has is a silent no-op (docs/lua-bindings.md).
-- tools/gates-check.sh runs the command and reads the GATE lines.
local function check(name, ok, detail)
  horizon.log(("GATE %s %s%s"):format(name, ok and "ok" or "BAD", detail and (" " .. detail) or ""))
end

horizon.command("gatesallowed", 0, function(player)
  local level = player.dimension
  local day_before = horizon.level_day_time(level) or -1
  -- A writable rule; then the allow-list's two refusals, raised at the call.
  -- `mob_griefing` defaults to true, so writing false differs from the value
  -- the world holds: a write that slipped past the gate shows below.
  horizon.level_set_game_rule(level, "keep_inventory", true)
  local ok, err = pcall(function()
    horizon.level_set_game_rule(level, "mob_griefing", false)
  end)
  check("rule allow-list", not ok and tostring(err):find("not writable from Lua", 1, true) ~= nil)
  ok, err = pcall(function()
    horizon.level_set_game_rule(level, "keep_inventory", 7)
  end)
  check("rule type", not ok and tostring(err):find("takes a boolean", 1, true) ~= nil)
  horizon.level_set_day_time(level, 6000)
  -- No player has this name: the kick resolves nobody and is a no-op, not an
  -- error. The check never kicks the one player in the game.
  ok, err = pcall(horizon.kick, "gates-nobody", "the gates check")
  check("kick unknown", ok, not ok and tostring(err) or nil)
  -- Both timers return handles; the `every` is cancelled at its second firing,
  -- and the same handle is cancelled again (false: nothing pending).
  local count = 0
  local handle = 0
  local first, again
  local after = horizon.after(1000, function() end)
  handle = horizon.every(1, function()
    count = count + 1
    if count == 2 then
      first = horizon.cancel_timer(handle)
      again = horizon.cancel_timer(handle)
    end
  end)
  check(
    "timer handles",
    type(after) == "number" and type(handle) == "number" and horizon.cancel_timer(after) == true,
    ("after=%s every=%s"):format(tostring(after), tostring(handle))
  )
  -- The display slot: the objective name is in the mod's own namespace
  -- (`<mod id>.<name>`), which the engine's own Lua test passes whole.
  local objective = horizon.mod_id .. ".pts"
  horizon.scoreboard_add_objective(objective, "dummy")
  horizon.scoreboard_set_display("sidebar", objective)
  -- The queued writes run at the tick's end: read back a tick later.
  horizon.after(1, function()
    local rule = horizon.level_game_rule(level, "keep_inventory")
    check("rule write", rule == true, ("keep_inventory=%s"):format(tostring(rule)))
    local grief = horizon.level_game_rule(level, "mob_griefing")
    -- The read-back is logged, not only judged: a write that got through shows
    -- as `mob_griefing=false` here and fails the check's line.
    check("rule allow-list unchanged", grief == true, ("mob_griefing=%s"):format(tostring(grief)))
    local day = horizon.level_day_time(level) or -1
    check("day time", day >= 6000 and day < 6100, ("before=%d after=%d"):format(day_before, day))
    local shown = horizon.scoreboard_display_objective("sidebar")
    horizon.scoreboard_clear_display("sidebar")
    horizon.after(1, function()
      local cleared = horizon.scoreboard_display_objective("sidebar")
      check(
        "display",
        shown == "gates_allowed.pts" and cleared == nil,
        ("shown=%s cleared=%s"):format(tostring(shown), tostring(cleared))
      )
    end)
  end)
  -- Ten ticks after the cancel: the count must still be 2.
  horizon.after(12, function()
    local stopped = count == 2 and first == true and again == false
    check("timer cancel", stopped, ("count=%d first=%s again=%s"):format(count, tostring(first), tostring(again)))
  end)
end)
