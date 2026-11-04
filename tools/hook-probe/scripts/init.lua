-- One logging handler per Lua hook Event Horizon's docs/api/hook-points.md lists;
-- tools/hook-coverage.sh drives the game through each and
-- reads the log (a hook logs once per load; the engine's own "reloaded" line
-- shows /reload reran the scripts).
local seen = {}
local function saw(name)
  if seen[name] then return end
  seen[name] = true
  horizon.log("PROBE hook " .. name)
end
local function plain(name) horizon.on(name, function() saw(name) end) end
local function by(name, kinds)
  for _, k in ipairs(kinds) do horizon.on(name, function() saw(name) end, k) end
end
local P, Z = "example_mod:example_mob", "minecraft:zombie"
for _, n in ipairs({ "server_tick", "world_lifecycle", "player_joined", "player_left", "player_respawned",
  "player_died", "tick_block", "right_click_block", "block_entity_tick" }) do plain(n) end
-- A random tick of the example nest schedules a block tick, for tick_block.
horizon.on("random_tick", function(dimension, block)
  saw("random_tick")
  if block == "example_mod:example_nest" and not seen.tick_block then horizon.schedule_tick(10) end
end)
by("mob_spawned", { P, Z }); by("mob_ai_register", { P, Z }); by("mob_tick", { P, Z }); by("mob_hurt", { P, Z })
by("mob_died", { P, Z }); by("mob_killed", { P, Z }); by("mob_interact", { P, Z })
by("item_use", { "minecraft:stick" }); by("item_use_on", { "minecraft:stick" }); by("item_hit", { "minecraft:stick" })
by("item_tick", { "minecraft:stick" }); by("item_finished", { "minecraft:apple", "minecraft:potion" })
by("item_picked_up", { "minecraft:slime_ball" })
by("block_placed", { "minecraft:stone" }); by("block_broken", { "minecraft:stone" })
-- The second goal's hooks: players, falls, heals, knockback, commands,
-- crafting, drops, loot, projectiles, explosions, beds, orbs, menus,
-- equipment, entities joining, blows landing, uses starting.
for _, n in ipairs({ "player_tick", "player_hurt", "player_fall", "player_knockback", "mob_heal", "player_command", "player_chat",
  "explosion", "player_changed_dimension", "player_bed_enter", "player_exp_change", "player_container_open" }) do plain(n) end
by("mob_fall", { Z }); by("mob_knockback", { Z }); by("mob_equipped", { Z })
by("item_crafted", { "minecraft:oak_planks" }); by("item_dropped", { "minecraft:stick" })
by("loot_drops", { "minecraft:stone", Z }); by("item_hurt_enemy", { "minecraft:stick", "minecraft:netherite_sword" })
by("item_use_start", { "minecraft:apple" })
by("projectile_impact", { "minecraft:snowball" }); by("projectile_launched", { "minecraft:snowball" })
by("entity_joined", { "minecraft:snowball", "minecraft:item", Z })
horizon.block_entity("hook_probe:probe", { ticks = true, data = { ticks = 0 } })
horizon.command("probe", 0, function(player, args) saw("command"); horizon.feedback("probe ok") end)
