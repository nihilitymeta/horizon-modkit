-- Every modkit callback the hooks goal added, written as a mod would write
-- them, each logging once when it runs; tools/hook-coverage.sh drives the
-- game through them beside tools/hook-probe and expects every line.
local modkit = require("@modkit")
local M = modkit.mod("modkit_probe")

local seen = {}
local function ran(name)
  if seen[name] then
    return
  end
  seen[name] = true
  horizon.log("MODKIT cb " .. name)
end

local P = M:players()
-- The acting player's hand (`horizon.acting_player().held`, the selected
-- slot): log each change of it, so tools/steps-check.sh can see it move with
-- the hotbar. One player is all the harness drives: a second player's hand
-- cannot be shown here. The first tick also logs the ticking player beside
-- the list's first, so the checks can see they match. One player is all the
-- harness drives: the uuids match even for players()[1], so this only proves
-- a player arrives (not nil), not which lookup named them.
local last_held = false
local tick_checked = false
function P:on_tick(player)
  ran("Players:on_tick")
  if not tick_checked then
    tick_checked = true
    local first = horizon.players()[1]
    horizon.log(
      ("MODKIT tick: %s first=%s match=%s"):format(
        player.uuid,
        first and first.uuid or "none",
        tostring(first ~= nil and first.uuid == player.uuid)
      )
    )
  end
  local held = player.held and player.held.item or "empty"
  if held ~= last_held then
    last_held = held
    horizon.log("MODKIT held: " .. held)
  end
end
function P:on_hurt(player, hit)
  ran("Players:on_hurt")
end
function P:on_fall(player, fall)
  ran("Players:on_fall")
end
function P:on_knockback(player, hit)
  ran("Players:on_knockback")
end
function P:on_chat(player, line)
  ran("Players:on_chat")
end
function P:on_command(player, line)
  ran("Players:on_command")
end
function P:on_change_dimension(player, from, to)
  ran("Players:on_change_dimension")
end
function P:on_sleep(player, x, y, z)
  ran("Players:on_sleep")
end
function P:on_exp(player, amount)
  ran("Players:on_exp")
end
function P:on_open_menu(player, menu, pos)
  ran("Players:on_open_menu")
end

local Zombie = M:entity("minecraft:zombie")
function Zombie:on_fall(mob, fall)
  ran("Entity:on_fall")
end
function Zombie:on_knockback(mob, hit)
  ran("Entity:on_knockback")
end
function Zombie:on_equip(mob, slot, from, to)
  ran("Entity:on_equip")
end
function Zombie:on_drops(mob, drops, source)
  ran("Entity:on_drops")
end
-- Per-mob saved data (`mob.data`): both mobs count into the SAME key
-- `clicks`, so one shared table would show: two clicks on one example mob
-- read 1 then 2, and the zombie's first click reads 1 only when its table is
-- its own. Each line logs both mobs' value of `clicks` (the other read live
-- through `horizon.entity_data`), so the zombie's line also proves the
-- example mob's value is still 2 afterwards.
local example_id: number? = nil
local zombie_id: number? = nil
local function other_clicks(id: number?): string
  if id == nil then
    return "none"
  end
  local other = horizon.entity_data(id)
  local n = other ~= nil and other.clicks or nil
  return n ~= nil and tostring(n) or "none"
end
function Zombie:on_interact(mob, player, held)
  ran("Entity:on_interact")
  zombie_id = mob.id
  local d = mob.data
  d.clicks = (d.clicks or 0) + 1
  horizon.log(
    ("MODKIT mobdata %s %d clicks=%d example_clicks=%s"):format(mob.kind, mob.id, d.clicks, other_clicks(example_id))
  )
end

local ExampleMob = M:entity("example_mod:example_mob")
function ExampleMob:on_interact(mob, player, held)
  ran("Entity:on_interact")
  example_id = mob.id
  local d = mob.data
  d.clicks = (d.clicks or 0) + 1
  horizon.log(
    ("MODKIT mobdata %s %d clicks=%d zombie_clicks=%s"):format(mob.kind, mob.id, d.clicks, other_clicks(zombie_id))
  )
end

local Stone = M:block("minecraft:stone")
function Stone:on_drops(block, drops, source)
  ran("Block:on_drops")
end
-- A click with the acting player's hand: the drive right-clicks stone while
-- holding a stick, so the logged hand is the stick.
function Stone:on_use(block, player, held)
  ran("Block:on_use")
  horizon.log(("MODKIT blockuse held=%s by=%s"):format(held and held.item or "empty", player.uuid))
end

local Planks = M:item("minecraft:oak_planks")
function Planks:on_crafted(item, player, recipe)
  ran("Item:on_crafted")
end
local Stick = M:item("minecraft:stick")
function Stick:on_dropped(item, player, count)
  ran("Item:on_dropped")
end
function Stick:on_hurt_enemy(item, player, target)
  ran("Item:on_hurt_enemy")
end
local Apple = M:item("minecraft:apple")
function Apple:on_use_start(item, player, hand, duration)
  ran("Item:on_use_start")
end

M:on("explosion_detonate", function(event)
  ran("M:on explosion")
end)
M:on("entity_join_level", function(event)
  ran("M:on entity_joined")
end, "minecraft:snowball")
M:on("projectile_launch", function(event)
  ran("M:on projectile_launched")
end, "minecraft:snowball")
M:on("projectile_impact", function(event)
  ran("M:on projectile_impact")
end, "minecraft:snowball")
M:on("living_heal", function(event)
  ran("M:on mob_heal")
end)
