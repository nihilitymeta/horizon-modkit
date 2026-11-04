-- A staged block with a block entity that breeds (guide: docs/guides/blocks.md;
-- reference: docs/api.md, "Blocks"). The nest is declared in
-- scripts/registry.lua with an enum `stage` state (dormant, growing, mature),
-- random ticks on every stage and a hoe tag. Here: it grows on its random
-- ticks, bone meal moves it a stage, a mature one charges and breeds an
-- example mob into the air over it, a spent one turns to sculk, its loot
-- differs by stage, and a mature one is only broken with a hoe.
-- See it in game: /example nest, place it, bone meal it twice (mature), wait
-- 20 seconds (an example mob climbs out), break it with a hoe (wheat);
-- /gamerule random_tick_speed 300 grows one on its own within seconds.
local M = require("@example/mod")
local cfg = require("@example/timers_and_data")

local Nest = M:block("example_nest")

-- Each placed nest has a block entity: `charge` counts the ticks since it
-- last bred and `bred` how many mobs it made, saved with the chunk.
Nest:block_entity { ticks = true, data = { charge = 0, bred = 0 } }
local NEXT_STAGE = { dormant = "growing", growing = "mature" }
local BREED_TICKS = 400

-- A random tick (the block declares `random_ticks` for every stage): a
-- quarter of them grow it a stage. block:handled() keeps the sculk
-- template's own random tick away, in every stage.
function Nest:on_random_tick(block)
  local next_stage = NEXT_STAGE[block.stage]
  if next_stage and math.random() < 0.25 then
    block:set("stage", next_stage)
    horizon.log(("EXAMPLE nest grew to %s"):format(next_stage))
  end
  block:handled()
end

-- Bone meal moves it a stage at once; a mature one stays mature. The click
-- is eaten, so the bone meal is kept. This runs once per hand (the main
-- hand, then the off hand a tick or two later, `held` the main hand's both
-- times), and the stage set by the first run is in place for the second:
-- the tick of the last meal, kept in block.data, tells the off hand's run
-- apart (a player's next click is four ticks away at the least).
function Nest:on_use(block, player, held)
  if held and held.item == "minecraft:bone_meal" then
    local data, now = block.data, horizon.ticks()
    local same_click = data ~= nil and data.meal_tick ~= nil and now - data.meal_tick < 4
    local next_stage = NEXT_STAGE[block.stage]
    if next_stage and not same_click then
      block:set("stage", next_stage)
      if data then data.meal_tick = now end
      horizon.log(("EXAMPLE nest bone mealed to %s by %s"):format(next_stage, player.name))
    end
    block:cancel()
  elseif block.data then
    player:action_bar(("a %s nest: charge %d, bred %d"):format(block.stage, block.data.charge, block.data.bred))
  end
end

-- Every server tick of a placed nest, with block.data; only a mature one
-- charges. Charged, it breeds an example mob into open air over it (the
-- summon answers at once: a block callback has the world at hand). One that
-- bred its share (cfg.nest_breeds) is spent: it drops what it was made of
-- and turns to sculk.
function Nest:on_block_entity_tick(block)
  local data = block.data
  if not data or block.stage ~= "mature" then return end
  data.charge = data.charge + 1
  if data.charge < BREED_TICKS or block:above() ~= "minecraft:air" then return end
  block:summon("example_mod:example_mob", 0, 1, 1)
  data.charge = 0
  data.bred = data.bred + 1
  horizon.log(("EXAMPLE nest bred an example mob (%d so far)"):format(data.bred))
  if data.bred >= cfg.nest_breeds then
    local l = block:light()
    block:broadcast(("the nest at %d %d %d is spent after %d example mob(s) (light %d/%d)"):format(block.x, block.y, block.z, data.bred, l.block, l.sky))
    block:drop("minecraft:wheat", 2)
    block:replace("minecraft:sculk")
    horizon.log(("EXAMPLE nest spent after %d"):format(data.bred))
  end
end

-- Its loot, by stage: the block is gone when the loot drops, so block.stage
-- comes from the state the engine names. A dormant nest drops itself, a
-- grown one wheat instead.
function Nest:on_drops(block, drops, source)
  if block.stage ~= "dormant" then
    drops[1] = { id = "minecraft:wheat", count = 2 }
  end
end

-- A mature nest is not broken by hand: it has to be hoed (player.held is
-- the main hand's stack). Return true and the block stays.
local function holds_hoe(player)
  local held = player.held
  return held ~= nil and held.item:sub(-4) == "_hoe"
end
function Nest:on_break(block, player)
  if block.stage == "mature" and not holds_hoe(player) then
    player:action_bar("a mature nest needs a hoe")
    horizon.log(("EXAMPLE nest kept from %s: no hoe"):format(player.name))
    return true
  end
  horizon.log(("EXAMPLE nest broken by %s while %s"):format(player.name, block.stage))
  return false
end

M:command("example nest", 2, function(player, args)
  player:give("example_mod:example_nest", 1)
  horizon.feedback("a nest given: place it and bone meal it twice")
end)

return Nest
