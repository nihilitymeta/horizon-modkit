-- The capability gates, refused side: this mod declares only `scripts`, so
-- every helper that needs `world-settings` or `server-admin` must fail at the
-- call with a text naming the helper and the capability, and change nothing.
-- tools/gates-check.sh runs the command and reads the GATE lines.
local function refused(helper, capability, fn)
  local ok, err = pcall(fn)
  if ok then
    horizon.log(("GATE denied %s BAD: the call returned without an error"):format(helper))
    return
  end
  local text = tostring(err)
  if text:find(helper, 1, true) and text:find(capability, 1, true) then
    horizon.log(("GATE denied %s ok"):format(helper))
  else
    horizon.log(("GATE denied %s BAD: %s"):format(helper, text))
  end
end

horizon.command("gatesdenied", 0, function(player)
  local level = player.dimension
  local day = horizon.level_day_time(level) or -1
  local mode = player.game_mode
  local rule = horizon.level_game_rule(level, "keep_inventory")
  refused("level_set_day_time", "world-settings", function()
    horizon.level_set_day_time(level, 6000)
  end)
  refused("level_set_weather", "world-settings", function()
    horizon.level_set_weather(level, 0, 6000, true, false)
  end)
  refused("set_game_mode", "world-settings", function()
    horizon.set_game_mode(player.uuid, 1)
  end)
  refused("level_set_game_rule", "world-settings", function()
    horizon.level_set_game_rule(level, "keep_inventory", true)
  end)
  refused("kick", "server-admin", function()
    horizon.kick("gates-nobody", "the gates check")
  end)
  refused("whitelist_add", "server-admin", function()
    horizon.whitelist_add("gates-nobody", "gates-nobody")
  end)
  refused("whitelist_remove", "server-admin", function()
    horizon.whitelist_remove("gates-nobody", "gates-nobody")
  end)
  -- A gate that let a call through would queue it: a tick later, the write
  -- would show. The day clock advances a tick or two on its own.
  horizon.after(1, function()
    local day_after = horizon.level_day_time(level) or -1
    local me = horizon.player(player.uuid)
    local mode_after = me and me.game_mode or -1
    local rule_after = horizon.level_game_rule(level, "keep_inventory")
    local same = day_after - day <= 5 and day_after < 3000 and mode_after == mode and rule_after == rule
    horizon.log(
      ("GATE denied unchanged %s day=%d->%d mode=%s->%s rule=%s->%s"):format(
        same and "ok" or "BAD",
        day,
        day_after,
        tostring(mode),
        tostring(mode_after),
        tostring(rule),
        tostring(rule_after)
      )
    )
  end)
end)
