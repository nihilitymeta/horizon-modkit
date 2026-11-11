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
--   function Hive:on_drops(block, drops, source) end -- its loot is about to drop: change `drops` ({id, count} entries) in place
--
-- `block` is the block at that moment: `block.x/y/z`, `block.dimension`,
-- `block.id`, its state properties as fields (`block.stage`), `block.data`
-- (the block entity's saved table, written back after the callback; nil
-- without a block entity), and methods that ask the game to act after the call.
--
-- The native events name no player and no held stack, so `player` is the
-- acting player (`horizon.acting_player()`), and `held` is their selected
-- stack (`{item, count, plain}`, or nil): with several players on, the one
-- who clicked.
local Player = require("@modkit/player")

local Block = {}
Block.__index = Block

--- Gives every placed block of this kind a block entity, which holds saved
--- data per block. `ticks` calls `on_block_entity_tick` each server tick;
--- `data` is the table a new one starts with.
function Block:block_entity(def: { ticks: boolean?, data: Data? }?)
  horizon.block_entity(self.id, def or {})
  return self
end

local Instance = {}
Instance.__index = function(self, key)
  local method = Instance[key]
  if method ~= nil then
    return method
  end
  local v = (rawget(self, "props") :: any)[key]
  if v ~= nil or not rawget(self, "live") or type(key) ~= "string" then
    return v
  end
  -- A callback without the state's properties at hand reads them from the world.
  return horizon.block_property(self.x, self.y, self.z, key)
end

-- The state properties in a state's name (`ns:hive[stage=dormant,lit=true]`), as the
-- instance's `props`; `{}` for a block without any.
local function props_of(state: string?): Props
  local out = {}
  local inside = state and state:match("%[(.*)%]")
  if inside then
    for k, v in inside:gmatch("([%w_]+)=([^,%]]+)") do
      out[k] = v
    end
  end
  return out
end

local function instance(dimension, id, x, y, z, props, data)
  return setmetatable(
    { dimension = dimension, id = id, x = x, y = y, z = z, props = props or {}, live = props == nil, data = data },
    Instance
  )
end

--- Sets a state property of the block: `block:set("stage", "growing")`. In
--- the two ticks and B:on_block_entity_tick; a click's host drops it (use
--- `block:replace` there).
function Instance:set(key: string, value: string, flags: number?)
  horizon.set_block_property(key, value, flags)
end
--- Asks for a scheduled tick (`on_tick`) in `delay` ticks. In the random
--- and scheduled ticks only.
function Instance:schedule_tick(delay: number)
  horizon.schedule_tick(delay)
end
--- Skips the block's own vanilla tick. In the random and scheduled ticks only.
function Instance:handled()
  horizon.handled()
end
--- Takes the click, so neither the block nor the held item acts.
function Instance:cancel()
  horizon.cancel()
end
--- Makes a mob at an offset from the block's bottom centre (`dy` 1 by
--- default) and returns its id. In a random or scheduled tick the mob is
--- made after the level's pass, and nil is returned.
function Instance:summon(kind: string, dx: number?, dy: number?, dz: number?): number?
  return horizon.summon(self.dimension, kind, self.x + 0.5 + (dx or 0), self.y + (dy or 1), self.z + 0.5 + (dz or 0))
end
--- Replaces the block with another, such as `block:replace("minecraft:air")`,
--- with its state properties and `Level.setBlock` flags (3). Not in a
--- random or scheduled tick: there `block:set` changes a property. The new
--- block starts with its default data.
function Instance:replace(id: string, props: Props?, flags: number?)
  horizon.set_block(self.x, self.y, self.z, id, props, flags)
end
--- Drops `count` (1) of an item over the block.
function Instance:drop(id: string, count: number?)
  horizon.drop_item(self.x + 0.5, self.y + 1, self.z + 0.5, id, count)
end
--- Gets the `{block, sky}` light at the block over this one.
function Instance:light(): Light
  return horizon.light(self.x, self.y + 1, self.z)
end
--- Sends a chat line to every player.
function Instance:broadcast(line: string)
  horizon.broadcast(line)
end
--- Gets the id of the block `dy` (1) blocks above this one.
function Instance:above(dy: number?): string
  return horizon.block(self.x, self.y + (dy or 1), self.z)
end
--- Gets the id of the block `dy` (1) blocks below this one.
function Instance:below(dy: number?): string
  return horizon.block(self.x, self.y - (dy or 1), self.z)
end

-- The acting player of a click, a break or a placement. The native events
-- name none. Skipped when the hook names no acting player.
local function acting()
  return Player.wrap(horizon.acting_player())
end

--- Creates a new block class, with its hooks registered for its id alone,
--- so the engine calls them for this block's ticks and events only. The
--- breaks and placements have no kind filter: the handler keeps the blocks
--- with its own id.
function Block.new(mod, id)
  local b = setmetatable({ mod = mod, id = id }, Block)
  horizon.on("random_tick", function(event)
    if b.on_random_tick then
      b:on_random_tick(
        instance(event.dimension, id, event.pos.x, event.pos.y, event.pos.z, event.state_props, event.data)
      )
    end
  end, id)
  horizon.on("tick_block", function(event)
    if b.on_tick then
      b:on_tick(instance(event.dimension, id, event.pos.x, event.pos.y, event.pos.z, event.state_props, event.data))
    end
  end, id)
  horizon.on("block_entity_tick", function(event)
    if b.on_block_entity_tick then
      b:on_block_entity_tick(
        instance(event.dimension, id, event.pos.x, event.pos.y, event.pos.z, nil, event.entity.data)
      )
    end
  end, id)
  horizon.on("destroy_block", function(event)
    if event.state ~= id then
      return
    end
    local player = acting()
    if player == nil then
      return
    end
    if
      b.on_break
      and b:on_break(instance(horizon.time().dimension, id, event.pos.x, event.pos.y, event.pos.z, nil, nil), player)
        == true
    then
      horizon.cancel()
    end
  end)
  horizon.on("place_block", function(event)
    if event.state ~= id then
      return
    end
    local player = acting()
    if player == nil then
      return
    end
    if b.on_place then
      b:on_place(
        instance(horizon.time().dimension, id, event.pos.x, event.pos.y, event.pos.z, nil, nil),
        player,
        event.stack
      )
    end
  end)
  -- The block is gone when its loot drops: its properties come from the
  -- state the engine names (`event.block.state`), not from the world.
  horizon.on("loot_drops", function(event)
    local at = event.block
    if at == nil or at.id ~= id then
      return
    end
    if b.on_drops then
      b:on_drops(instance(event.dimension, id, at.x, at.y, at.z, props_of(at.state), nil), event.drops, event)
    end
  end, id)
  return b
end

-- Installs the mod's handlers once (the clicks are not registered by block).
function Block.install(mod)
  horizon.on("right_click_block", function(event)
    local pos = event.pos
    local id = horizon.block(pos.x, pos.y, pos.z)
    local b = mod.blocks[id]
    if b and b.on_use then
      local player = acting()
      if player == nil then
        return
      end
      b:on_use(instance(horizon.time().dimension, id, pos.x, pos.y, pos.z, nil, nil), player, player.held, event.face)
    end
  end)
end

return Block
