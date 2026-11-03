-- A block class: callbacks for one block, the mod's own or a vanilla one.
--
--   local Hive = M:block("hive")
--   function Hive:on_random_tick(block) end   -- the block declares random_ticks in its data
--   function Hive:on_tick(block) end          -- a scheduled tick (block:schedule_tick)
--   function Hive:on_use(block, player, held) end   -- a right click; block:cancel() eats it
--
-- `block` is the block at that moment: `block.x/y/z`, `block.dimension`,
-- `block.id`, its state properties as fields (`block.stage`), and methods
-- that ask the game to act after the call.
local Block = {}
Block.__index = Block

function Block.new(mod, id)
  return setmetatable({ mod = mod, id = id }, Block)
end

local Instance = {}
Instance.__index = function(self, key)
  local method = Instance[key]
  if method ~= nil then return method end
  return rawget(self, "props")[key]
end

local function instance(dimension, id, x, y, z, props)
  return setmetatable({ dimension = dimension, id = id, x = x, y = y, z = z, props = props or {} }, Instance)
end

--- Sets a state property of the block (`block:set("stage", "growing")`).
function Instance:set(key, value, flags) horizon.set_block_property(key, value, flags) end
--- Ticks the block again in `delay` ticks (`on_tick`).
function Instance:schedule_tick(delay) horizon.schedule_tick(delay) end
--- Takes the tick: the block's own (vanilla) tick is skipped.
function Instance:handled() horizon.handled() end
--- Eats the click: neither the block nor the held item acts.
function Instance:cancel() horizon.cancel() end
--- Makes a mob at an offset from the block's centre.
function Instance:summon(kind, dx, dy, dz)
  horizon.summon(self.dimension, kind, self.x + 0.5 + (dx or 0), self.y + (dy or 1), self.z + 0.5 + (dz or 0))
end
function Instance:broadcast(line) horizon.broadcast(line) end

--- Installs the mod's handlers once.
function Block.install(mod)
  horizon.on("random_tick", function(dimension, id, x, y, z, props)
    local b = mod.blocks[id]
    if b and b.on_random_tick then b:on_random_tick(instance(dimension, id, x, y, z, props)) end
  end)
  horizon.on("tick_block", function(dimension, id, x, y, z, props)
    local b = mod.blocks[id]
    if b and b.on_tick then b:on_tick(instance(dimension, id, x, y, z, props)) end
  end)
  horizon.on("right_click_block", function(x, y, z, id, face, player, held)
    local b = mod.blocks[id]
    if b and b.on_use then
      b:on_use(instance(player and player.dimension or "minecraft:overworld", id, x, y, z, {}), player, held, face)
    end
  end)
end

return Block
