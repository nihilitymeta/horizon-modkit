-- One log line per step, from the hooks of the final build.
local function show(v)
  if type(v) ~= "table" then return tostring(v) end
  local parts = {}
  for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and "{..}" or tostring(x)) end
  table.sort(parts)
  return "{" .. table.concat(parts, " ") .. "}"
end
horizon.on("player_logged_in", function(event)
  local player = event.player
  local t = horizon.time()
  local b = horizon.block(math.floor(player.position.x), math.floor(player.position.y) - 1, math.floor(player.position.z))
  local hit = horizon.raycast(player.uuid, 8)
  horizon.log(("STEP1 reads: players=%d time.day=%s block_below=%s mobs=%d raycast=%s"):format(
    #horizon.players(), tostring(t.day), tostring(b), #horizon.mobs(), show(hit)))
  local w = horizon.world_data()
  w.launches = (w.launches or 0) + 1
  local p = horizon.player_data(player.uuid)
  p.joins = (p.joins or 0) + 1
  horizon.log(("STEP4 data: world.launches=%d player.joins=%d"):format(w.launches, p.joins))
end)
horizon.after(20, function() horizon.log("STEP4 timer: after 20 ticks") end)
horizon.on("living_incoming_damage", function(event)
  horizon.log(("STEP3 hurt: example mob %d takes %.1f of %s"):format(event.entity, event.amount, event.damage_type))
end, "example_mod:example_mob")
horizon.on("player_died", function(event) horizon.log(("STEP3 died: %s (%s)"):format(event.player, tostring(event.cause))) end)
horizon.on("player_respawned", function(event) horizon.log(("STEP3 respawned: %s at %.0f %.0f %.0f"):format(event.player.name, event.player.position.x, event.player.position.y, event.player.position.z)) end)
horizon.on("mob_spawned", function(event)
  horizon.log(("STEP6 spawned %s natural=%s"):format(event.kind, tostring(event.natural)))
end, "example_mod:example_mob")
horizon.command("stepfx", 0, function(player, args)
  local x, y, z = player.position.x, player.position.y, player.position.z
  horizon.sound("minecraft:entity.experience_orb.pickup", x, y, z, 1, 1)
  horizon.particles("minecraft:flame", x, y + 1, z, 10)
  horizon.title(player.uuid, "Step five")
  horizon.subtitle(player.uuid, "titles and sounds")
  horizon.action_bar(player.uuid, "action bar")
  horizon.feedback("STEP5 fx sent to " .. player.name)
end)
-- A command with arguments of three kinds, parsed by the engine from the usage.
horizon.command("probeadd <a:integer> <b:number> [label:word]", 0, function(player, args)
  horizon.feedback(("STEP5 args: %s = %s (a=%d b=%.2f)"):format(args.label or "sum", tostring(args.a + args.b), args.a, args.b))
end)

-- The helpers (the second goal's step 1): the settings file at load, then
-- one command that calls every helper once and logs what the reads answer.
local cfg = horizon.config()
cfg.runs = (cfg.runs or 0) + 1
cfg.limit = cfg.limit or 16
horizon.save_config(cfg)
-- Logged at the join: at load the game's log is not open yet.
horizon.on("player_logged_in", function(event) horizon.log(("STEP9 config: runs=%d limit=%d"):format(cfg.runs, cfg.limit)) end)

horizon.command("probehelpers", 0, function(player, args)
  local x, y, z = math.floor(player.position.x), math.floor(player.position.y), math.floor(player.position.z)
  -- A summon answers its id at once; an effect goes on the mob by that id,
  -- and on the player.
  local id = horizon.summon(player.dimension, "minecraft:zombie", x + 3, y, z)
  if id then horizon.effect(id, "minecraft:glowing", 400) end
  horizon.effect(player, "minecraft:speed", 400, 1)
  horizon.log(("STEP9 summon: zombie id=%s"):format(tostring(id)))
  -- Blocks: one set, one with a property, a box filled, a falling block, an item dropped.
  horizon.set_block(x + 2, y, z + 2, "minecraft:glowstone")
  horizon.set_block(x + 2, y, z + 3, "minecraft:oak_log", { axis = "x" })
  horizon.fill(x - 3, y, z - 3, x - 1, y + 1, z - 1, "minecraft:gold_block")
  horizon.falling_block(x + 0.5, y + 5, z - 2.5, "minecraft:sand", 0, 0, 0)
  horizon.drop_item(x + 0.5, y + 1, z + 3.5, "minecraft:emerald", 3)
  local l = horizon.light(x, y + 1, z)
  horizon.log(("STEP9 reads: light=%d/%d surface=%s floor=%s held=%s"):format(
    l.block, l.sky, tostring(horizon.surface_height(x, z)), tostring(horizon.surface_height(x, z, "ocean_floor")),
    player.held and player.held.item or "nothing"))
  local recipe = horizon.data("data/minecraft/recipe/stick.json")
  horizon.log(("STEP9 data: stick recipe type=%s"):format(type(recipe) == "table" and tostring(recipe.type) or "nil"))
  horizon.feedback("STEP9 helpers queued for " .. player.name)
  -- The glowstone set above, broken by the player in survival: its loot,
  -- with the block named from its state (the state_name helper).
  horizon.on("loot_drops", function(event)
    horizon.log(("STEP9 loot: %s state=%s table=%s drops=%d by %s"):format(
      event.block.id, event.block.state, event.table, #event.drops, event.player and event.player.name or "nobody"))
  end, "minecraft:glowstone")
  -- The named-player helpers and the console's commands reach nobody inside
  -- a player's own command: next tick they do.
  local name = player.name
  horizon.after(1, function()
    horizon.give_items(name, "minecraft:bread", 3)
    horizon.take_items(name, "minecraft:bread", 1)
    horizon.give_experience(name, 7)
    horizon.give_levels(name, 2)
    horizon.set_nickname(name, name .. " the Prober")
    horizon.run_command("time set 6000")
  end)
  horizon.after(3, function()
    local inv = horizon.inventory(name) or {}
    local stacks = 0
    for _ in pairs(inv) do stacks = stacks + 1 end
    horizon.log(("STEP9 named player: bread=%d stacks=%d carried_bread=%s time_of_day=%d"):format(
      horizon.count_items(name, "minecraft:bread") or 0, stacks, tostring((horizon.carried_items(name) or {})["minecraft:bread"]),
      horizon.time().time_of_day))
  end)
end)
