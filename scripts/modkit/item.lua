-- An item class: callbacks for one item id, the mod's own (declared in
-- scripts/registry.lua) or a vanilla one.
--
--   local Wand = M:item("wand")
--   function Wand:on_use(item, player) end                   -- right click in the air; return true to take the use
--   function Wand:on_use_on(item, player, block, face) end   -- right click on a block; return true to take it
--   function Wand:on_hit(item, player, target) end           -- a blow with it; return true and the blow does nothing
--   function Wand:on_finished(item, player) end              -- eaten, drunk or used for its duration; return an id (and count) for what stays in the hand
--   function Wand:on_tick(slot, selected) end                -- every server tick in an inventory: keep it light
--   function Wand:on_crafted(item, player, recipe) end       -- a player took it from a crafting grid
--   function Wand:on_dropped(item, player, count) end        -- a player threw it
--   function Wand:on_hurt_enemy(item, player, target) end    -- a blow with it landed on target ({id, kind})
--   function Wand:on_use_start(item, player, hand, duration) end -- a use over time starts; return a number for the duration, true to stop it
--
-- `item` is `{id, count, damage, plain}` with `item:take(n)` and `item:give(n)`
-- on the acting player's inventory; `player`, `block` and `target` are the
-- engine's tables (docs/api.md, "Item classes"). A callback is wired to the game's hook the
-- moment it is defined. The hooks name no item, so the handler keeps the
-- stacks with this item's id; `on_use`, `on_use_on` and `on_hit` read the
-- acting player (`horizon.players()[1]`) and the hand they hold.
local Held = require("@modkit/held")
local Player = require("@modkit/player")
local wrap_player = Player.wrap

local Item = {}

local Stack = {}
Stack.__index = Stack
function Stack:take(n) horizon.take_items(self.id, n or 1) end
function Stack:give(n) horizon.give_items(self.id, n or 1) end
local function wrap(item) return setmetatable(item, Stack) end

-- The acting player of a use or a blow: the first player of the world.
-- The item events hand out no player table.
local function acting()
  return wrap_player(horizon.players()[1])
end

-- The player a uuid names, or a bare uuid table when the server does not
-- hold them. `player:` methods that take a uuid still reach them.
local function named(uuid)
  return wrap_player(horizon.player(uuid) or { uuid = uuid })
end

local CALLBACKS = {
  on_use = { "use_item", function(e, event)
    if event.stack.id ~= e.id then return end
    if e:on_use(wrap(event.stack), acting()) == true then horizon.cancel() end
  end },
  on_use_on = { "use_item_on", function(e, event)
    if event.stack.id ~= e.id then return end
    local pos = event.pos
    local block = { x = pos.x, y = pos.y, z = pos.z, id = horizon.block(pos.x, pos.y, pos.z) }
    if e:on_use_on(wrap(event.stack), acting(), block, event.face) == true then horizon.cancel() end
  end },
  on_hit = { "attack_entity", function(e, event)
    local held = Held.of()
    if held == nil or held.item ~= e.id then return end
    local item = wrap({ id = held.item, count = held.count, plain = held.plain })
    local pos = event.pos
    local target = { id = event.entity, kind = event.kind, position = { x = pos.x, y = pos.y, z = pos.z } }
    if e:on_hit(item, acting(), target) == true then horizon.cancel() end
  end },
  on_finished = { "living_entity_use_item_finish", function(e, event)
    if event.entity ~= nil or event.stack.id ~= e.id then return end
    local id, count = e:on_finished(wrap(event.stack), acting())
    if id ~= nil then event.result = { id = id, count = count or 1 } end
  end },
  on_tick = { "inventory_tick", function(e, event)
    e:on_tick(event.slot, event.selected)
  end },
  on_crafted = { "item_crafted", function(e, event)
    if event.stack.id ~= e.id then return end
    e:on_crafted(wrap(event.stack), named(event.player), event.recipe)
  end },
  on_dropped = { "item_dropped", function(e, event)
    if event.item ~= e.id then return end
    e:on_dropped(wrap({ id = event.item, count = event.count, damage = 0, plain = true }), named(event.player), event.count)
  end },
  on_hurt_enemy = { "hurt_enemy", function(e, event)
    if event.stack.id ~= e.id then return end
    e:on_hurt_enemy(wrap(event.stack), acting(), { id = event.entity, kind = event.kind })
  end },
  on_use_start = { "living_entity_use_item_start", function(e, event)
    if event.entity ~= nil or event.stack.id ~= e.id then return end
    local r = e:on_use_start(wrap(event.stack), acting(), event.hand, event.duration)
    if r == true then horizon.cancel() elseif type(r) == "number" then event.duration = r end
  end },
}

Item.__index = Item
Item.__newindex = function(self, key, value)
  rawset(self, key, value)
  local cb = CALLBACKS[key]
  if cb and value ~= nil then self:_listen(key, cb[1], cb[2]) end
end

function Item.new(mod, id)
  return setmetatable({ mod = mod, id = id, _hooked = {} }, Item)
end

function Item:_listen(name, hook, adapt)
  if self._hooked[hook] then return end
  self._hooked[hook] = true
  if name == "on_hit" then Held.track() end
  local e = self
  horizon.on(hook, function(event)
    if e[name] then adapt(e, event) end
  end)
end

return Item
