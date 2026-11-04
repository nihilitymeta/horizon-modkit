-- Every modkit callback the hooks goal added, written as a mod would write
-- them, each logging once when it runs; tools/hook-coverage.sh drives the
-- game through them beside tools/hook-probe and expects every line.
local modkit = require("@modkit")
local M = modkit.mod("modkit_probe")

local seen = {}
local function ran(name)
  if seen[name] then return end
  seen[name] = true
  horizon.log("MODKIT cb " .. name)
end

local P = M:players()
function P:on_tick(player) ran("Players:on_tick") end
function P:on_hurt(player, hit) ran("Players:on_hurt") end
function P:on_fall(player, fall) ran("Players:on_fall") end
function P:on_knockback(player, hit) ran("Players:on_knockback") end
function P:on_chat(player, line) ran("Players:on_chat") end
function P:on_command(player, line) ran("Players:on_command") end
function P:on_change_dimension(player, from, to) ran("Players:on_change_dimension") end
function P:on_sleep(player, x, y, z) ran("Players:on_sleep") end
function P:on_exp(player, amount) ran("Players:on_exp") end
function P:on_open_menu(player, menu, pos) ran("Players:on_open_menu") end

local Zombie = M:entity("minecraft:zombie")
function Zombie:on_fall(mob, fall) ran("Entity:on_fall") end
function Zombie:on_knockback(mob, hit) ran("Entity:on_knockback") end
function Zombie:on_equip(mob, slot, from, to) ran("Entity:on_equip") end
function Zombie:on_drops(mob, drops, source) ran("Entity:on_drops") end

local Stone = M:block("minecraft:stone")
function Stone:on_drops(block, drops, source) ran("Block:on_drops") end

local Planks = M:item("minecraft:oak_planks")
function Planks:on_crafted(item, player, recipe) ran("Item:on_crafted") end
local Stick = M:item("minecraft:stick")
function Stick:on_dropped(item, player, count) ran("Item:on_dropped") end
function Stick:on_hurt_enemy(item, player, target) ran("Item:on_hurt_enemy") end
local Apple = M:item("minecraft:apple")
function Apple:on_use_start(item, player, hand, duration) ran("Item:on_use_start") end

M:on("explosion", function(dimension, center, blocks) ran("M:on explosion") end)
M:on("entity_joined", function(dimension, id, kind, x, y, z, loaded) ran("M:on entity_joined") end, "minecraft:snowball")
M:on("projectile_launched", function(projectile, kind, player) ran("M:on projectile_launched") end, "minecraft:snowball")
M:on("projectile_impact", function(projectile, kind, owner, hit) ran("M:on projectile_impact") end, "minecraft:snowball")
M:on("mob_heal", function(mob, amount) ran("M:on mob_heal") end)
