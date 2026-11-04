-- Blocks: a class per block id (guide: docs/guides/blocks.md; reference:
-- docs/api.md, "Block classes"). The block is declared in scripts/registry.lua
-- with a `lit` state of its own, random ticks and an item. `block` is the
-- block at that moment: x, y, z, id, its state properties as fields
-- (strings, as the state spells them: block.lit is "true" or "false"), and
-- block.data, the block entity's saved table.
-- See it in game: /example lamp, place it, right-click it (lit for five
-- seconds), leave it (a random tick lights it on its own now and then),
-- break it (glowstone dust too).
local M = require("@example/mod")

local Lamp = M:block("example_block")

-- Every placed block of this kind gets a block entity: saved data of its own,
-- kept with the chunk, and a tick every server tick when `ticks`.
Lamp:block_entity { ticks = true, data = { lit_ticks = 0 } }

-- A right click lights it; the click is eaten, so the held item does nothing.
-- The game tries the main hand and then the off hand, and this runs for
-- each, so it does one thing that is the same done twice (a toggle would
-- flip back).
function Lamp:on_use(block, player, held)
  if block.lit ~= "true" then
    block:set("lit", "true")
    horizon.log(("EXAMPLE block lit by %s"):format(player.name))
  end
  block:cancel()
end

-- Every server tick of a placed block, with block.data: count the lit ticks
-- and go dark after 100 (five seconds). Keep this light: it runs for every
-- placed block, every tick.
function Lamp:on_block_entity_tick(block)
  local data = block.data
  if not data or block.lit ~= "true" then return end
  data.lit_ticks = data.lit_ticks + 1
  if data.lit_ticks >= 100 then
    data.lit_ticks = 0
    block:set("lit", "false")
    horizon.log("EXAMPLE block dimmed after 100 ticks of light")
  end
end

-- A random tick (the block declares `random_ticks`; a vanilla template's own
-- random tick would run after this unless block:handled() is called): ask
-- for a scheduled tick ten ticks later.
function Lamp:on_random_tick(block)
  block:schedule_tick(10)
end

-- The scheduled tick: a dark lamp lights itself. block:schedule_tick and
-- block:handled() work in these two ticks only; block:set works here, in
-- on_use and in on_block_entity_tick.
function Lamp:on_tick(block)
  if block.lit ~= "true" then
    block:set("lit", "true")
    horizon.log("EXAMPLE block lit by its scheduled tick")
  end
end

-- Placed by a player from an item; broken by one (return true to keep it).
function Lamp:on_place(block, player, item)
  player:action_bar(("a lamp at %d %d %d"):format(block.x, block.y, block.z))
  horizon.log(("EXAMPLE block placed by %s"):format(player.name))
end
function Lamp:on_break(block, player)
  horizon.log(("EXAMPLE block broken by %s"):format(player.name))
  return false
end

-- Its loot is about to drop: `drops` is a list of {id, count} to change in
-- place; `source` says who (player, tool, explosion). A player gets dust too.
function Lamp:on_drops(block, drops, source)
  if source.player then drops[#drops + 1] = { id = "minecraft:glowstone_dust", count = 2 } end
end

return Lamp
