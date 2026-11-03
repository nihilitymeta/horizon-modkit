-- An item class: callbacks for one item id, the mod's own (declared in
-- scripts/registry.lua) or a vanilla one.
--
--   local Wand = M:item("wand")
--   function Wand:on_use(item, player) end                   -- right click in the air; return true to take the use
--   function Wand:on_use_on(item, player, block, face) end   -- right click on a block; return true to take it
--   function Wand:on_hit(item, player, target) end           -- a blow with it; return true and the blow does nothing
--   function Wand:on_finished(item, player) end              -- eaten, drunk or used for its duration; return an id (and count) for what stays in the hand
--   function Wand:on_tick(item, player, slot, selected) end  -- every server tick in an inventory: keep it light
--
-- `item` is `{id, count, damage, plain}` with `item:take(n)` and `item:give(n)`
-- on the acting player's inventory; `player`, `block` and `target` are the
-- engine's tables (docs/api.md). A callback is wired to the game's hook for
-- the item the moment it is defined.
local Item = {}

local Stack = {}
Stack.__index = Stack
function Stack:take(n) horizon.take_items(self.id, n or 1) end
function Stack:give(n) horizon.give_items(self.id, n or 1) end
local function wrap(item) return setmetatable(item, Stack) end

local CALLBACKS = {
  on_use = { "item_use", function(e, item, player)
    if e:on_use(wrap(item), player) == true then horizon.cancel() end
  end },
  on_use_on = { "item_use_on", function(e, item, player, block, face)
    if e:on_use_on(wrap(item), player, block, face) == true then horizon.cancel() end
  end },
  on_hit = { "item_hit", function(e, item, player, target)
    if e:on_hit(wrap(item), player, target) == true then horizon.cancel() end
  end },
  on_finished = { "item_finished", function(e, item, player)
    local id, count = e:on_finished(wrap(item), player)
    if id ~= nil then horizon.set_result(id, count) end
  end },
  on_tick = { "item_tick", function(e, item, player, slot, selected)
    e:on_tick(wrap(item), player, slot, selected)
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
