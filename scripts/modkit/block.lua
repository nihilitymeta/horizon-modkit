-- A block class: callbacks for one block, the mod's own or a vanilla one.
--
--   local Hive = M:block("hive")
--   Hive:block_entity { ticks = true, data = { charge = 0 } }   -- saved data per block, ticked
--   function Hive:on_block_entity_tick(block) end   -- every server tick, with block.data
--   function Hive:on_random_tick(block) end   -- the block declares random_ticks in its data
--   function Hive:on_tick(block) end          -- a scheduled tick (block:schedule_tick)
--   function Hive:on_use(block, player, held) end   -- a right click; block:cancel() eats it
--   function Hive:on_break(block, player) end        -- a player breaks it; return true to keep it
--   function Hive:on_place(block, player, item) end  -- a player placed it
--
-- `block` is the block at that moment: `block.x/y/z`, `block.dimension`,
-- `block.id`, its state properties as fields (`block.stage`), `block.data`
-- (the block entity's saved table, written back after the callback; nil
-- without a block entity), and methods that ask the game to act after the call.
local Block = {}
Block.__index = Block

--- The block over this one (`dy` blocks up, 1 by default), by id.
function Block:above(dy) return horizon.block(self.x, self.y + (dy or 1), self.z) end
--- The block under this one.
function Block:below(dy) return horizon.block(self.x, self.y - (dy or 1), self.z) end

function Block.new(mod, id)
  return setmetatable({ mod = mod, id = id }, Block)
end

--- Gives every placed block of this kind a block entity: `ticks` runs
--- `on_block_entity_tick` each server tick, `data` is what a new one starts
--- with (numbers, strings, booleans, nested tables; saved with the chunk).
function Block:block_entity(def)
  horizon.block_entity(self.id, def or {})
  return self
end

local Instance = {}
Instance.__index = function(self, key)
  local method = Instance[key]
  if method ~= nil then return method end
  local v = rawget(self, "props")[key]
  if v ~= nil or not rawget(self, "live") or type(key) ~= "string" then return v end
  -- A callback without the state's properties at hand reads them from the world.
  return horizon.block_property(self.x, self.y, self.z, key)
end

local function dimension_of(player) return player and player.dimension or "minecraft:overworld" end

local function instance(dimension, id, x, y, z, props, data)
  return setmetatable({ dimension = dimension, id = id, x = x, y = y, z = z, props = props or {}, live = props == nil, data = data }, Instance)
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
  horizon.on("random_tick", function(dimension, id, x, y, z, props, data)
    local b = mod.blocks[id]
    if b and b.on_random_tick then b:on_random_tick(instance(dimension, id, x, y, z, props, data)) end
  end)
  horizon.on("tick_block", function(dimension, id, x, y, z, props, data)
    local b = mod.blocks[id]
    if b and b.on_tick then b:on_tick(instance(dimension, id, x, y, z, props, data)) end
  end)
  horizon.on("block_entity_tick", function(dimension, id, x, y, z, data)
    local b = mod.blocks[id]
    if b and b.on_block_entity_tick then b:on_block_entity_tick(instance(dimension, id, x, y, z, nil, data)) end
  end)
  horizon.on("block_broken", function(x, y, z, id, player)
    local b = mod.blocks[id]
    if b and b.on_break and b:on_break(instance(dimension_of(player), id, x, y, z, nil, nil), player) == true then horizon.cancel() end
  end)
  horizon.on("block_placed", function(x, y, z, id, player, item)
    local b = mod.blocks[id]
    if b and b.on_place then b:on_place(instance(dimension_of(player), id, x, y, z, nil, nil), player, item) end
  end)
  horizon.on("right_click_block", function(x, y, z, id, face, player, held, data)
    local b = mod.blocks[id]
    if b and b.on_use then
      b:on_use(instance(player and player.dimension or "minecraft:overworld", id, x, y, z, {}, data), player, held, face)
    end
  end)
end

return Block
