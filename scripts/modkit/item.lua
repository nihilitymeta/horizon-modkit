-- An item class: callbacks for one item id, the mod's own (declared in
-- scripts/registry.lua) or a vanilla one.
--
--   local Wand = M:item("wand")
--   function Wand:on_use(item, player) end                   -- right click in the air; return true to take the use
--   function Wand:on_use_on(item, player, block, face) end   -- right click on a block; return true to take it
--   function Wand:on_hit(item, player, target) end           -- a blow with it; return true and the blow does nothing
--   function Wand:on_finished(item, player) end              -- eaten, drunk or used for its duration; return an id (and count) for what stays in the hand
--   function Wand:on_tick(item, player, slot, selected) end  -- every server tick in an inventory: keep it light
--   function Wand:on_crafted(item, player, recipe) end       -- a player took it from a crafting grid
--   function Wand:on_dropped(item, player, count) end        -- a player threw it
--   function Wand:on_hurt_enemy(item, player, target) end    -- a blow with it landed on target ({id, kind})
--   function Wand:on_use_start(item, player, hand, duration) end -- a use over time starts; return a number for the duration, true to stop it
--
-- `item` is `{id, count, damage, plain}` with `item:take(n)` and `item:give(n)`
-- on the acting player's inventory; `player`, `block` and `target` are the
-- engine's tables (docs/api.md). A callback is wired to the game's hook for
-- the item the moment it is defined.
local Player = require("@modkit/player")
local wrap_player = Player.wrap

local Item = {}

local Stack = {}
Stack.__index = Stack
function Stack:take(n) horizon.take_items(self.id, n or 1) end
function Stack:give(n) horizon.give_items(self.id, n or 1) end
local function wrap(item) return setmetatable(item, Stack) end

local CALLBACKS = {
  on_use = { "item_use", function(e, item, player)
    if e:on_use(wrap(item), wrap_player(player)) == true then horizon.cancel() end
  end },
  on_use_on = { "item_use_on", function(e, item, player, block, face)
    if e:on_use_on(wrap(item), wrap_player(player), block, face) == true then horizon.cancel() end
  end },
  on_hit = { "item_hit", function(e, item, player, target)
    if e:on_hit(wrap(item), wrap_player(player), target) == true then horizon.cancel() end
  end },
  on_finished = { "item_finished", function(e, item, player)
    local id, count = e:on_finished(wrap(item), wrap_player(player))
    if id ~= nil then horizon.set_result(id, count) end
  end },
  on_tick = { "item_tick", function(e, item, player, slot, selected)
    e:on_tick(wrap(item), wrap_player(player), slot, selected)
  end },
  on_crafted = { "item_crafted", function(e, player, recipe, item)
    e:on_crafted(wrap(item), wrap_player(player), recipe)
  end },
  on_dropped = { "item_dropped", function(e, player, item, count)
    e:on_dropped({ id = item, count = count }, wrap_player(player), count)
  end },
  on_hurt_enemy = { "item_hurt_enemy", function(e, item, player, target)
    e:on_hurt_enemy(wrap(item), wrap_player(player), target)
  end },
  on_use_start = { "item_use_start", function(e, item, player, hand, duration)
    local r = e:on_use_start(wrap(item), wrap_player(player), hand, duration)
    if r == true then horizon.cancel() elseif type(r) == "number" then horizon.set_duration(r) end
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
  local e = self
  horizon.on(hook, function(...)
    if e[name] then adapt(e, ...) end
  end, self.id)
end

return Item
