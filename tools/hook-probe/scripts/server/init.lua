-- One logging handler per Lua hook the in-game drives reach;
-- tools/hook-coverage.sh drives the game through each and
-- reads the log (a hook logs once per load; the engine's own "reloaded" line
-- shows /reload reran the scripts).
local seen = {}
local function saw(name)
  if seen[name] then
    return
  end
  seen[name] = true
  horizon.log("PROBE hook " .. name)
end
local function plain(name)
  horizon.on(name, function()
    saw(name)
  end)
end
local function by(name, kinds)
  for _, k in ipairs(kinds) do
    horizon.on(name, function()
      saw(name)
    end, k)
  end
end
local P, Z, PL = "example_mod:example_mob", "minecraft:zombie", "minecraft:player"
for _, n in ipairs({
  "server_tick",
  "world_lifecycle",
  "player_logged_in",
  "player_logged_out",
  "player_respawned",
  "player_died",
  "tick_block",
  "right_click_block",
  "block_entity_tick",
}) do
  plain(n)
end
-- A random tick of the example nest schedules a block tick, for tick_block.
horizon.on("random_tick", function(event)
  saw("random_tick")
  if event.state == "example_mod:example_nest" and not seen.tick_block then
    horizon.schedule_tick(10)
  end
end)
by("mob_spawned", { P, Z })
by("mob_ai_register", { P, Z })
by("register_goals", { P, Z })
by("entity_tick_post", { P, Z })
by("living_incoming_damage", { P, Z, PL })
by("mob_died", { P, Z })
by("mob_killed", { P, Z })
by("interact_entity", { P, Z })
-- Uses, crafts, drops, ticks, breaks and placements take no kind: one bare
-- handler hears every one, and the modkit keeps the ids it cares about.
for _, n in ipairs({
  "use_item",
  "use_item_on",
  "inventory_tick",
  "item_crafted",
  "item_dropped",
  "destroy_block",
  "place_block",
  "living_heal",
  "attack_entity",
}) do
  plain(n)
end
by("living_fall", { Z, PL })
by("living_knockback", { Z, PL })
by("living_equipment_change", { Z })
by("hurt_enemy", { P, Z })
for _, n in ipairs({ "living_entity_use_item_start", "living_entity_use_item_finish" }) do
  plain(n)
end
-- The player's own use reaches bare handlers; a mob's would filter by kind.
by("loot_drops", { "minecraft:stone", Z })
-- The second goal's hooks: commands, explosions, beds, orbs, menus,
-- projectiles, entities joining, the held slot.
for _, n in ipairs({
  "player_tick",
  "player_command",
  "player_chat",
  "explosion_detonate",
  "player_changed_dimension",
  "player_bed_enter",
  "player_exp_change",
  "player_container_open",
  "player_item_held",
}) do
  plain(n)
end
by("projectile_impact", { "minecraft:snowball" })
by("projectile_launch", { "minecraft:snowball" })
by("entity_join_level", { "minecraft:snowball", "minecraft:item", Z })
horizon.block_entity("hook_probe:probe", { ticks = true, data = { ticks = 0 } })
horizon.on("register_commands", function()
  saw("register_commands")
end)
horizon.command("probe", 0, function(player, args)
  saw("command")
  horizon.feedback("probe ok")
end)
