-- The acting player's selected stack, for hooks whose event names none.
--
-- The native `right_click_block`, `attack_entity` and `destroy_block` events
-- name no held stack, and hand out no player table either. A callback that
-- needs the hand (a block's `on_use`, an item's `on_hit`) reads it here: the
-- selected hotbar slot, which the `player_item_held` hook reports, looked up
-- in the player's inventory. With one player on it is the acting player's
-- hand; with several players on the engine names no acting player, so this
-- reads the first player of `horizon.players()`.
local Held = {}

local selected = {} --- uuid text -> hotbar index, 0 to 8
local installed = false

--- Starts tracking the selected slot. Called when the first callback that
--- needs the hand is defined; one handler serves every class.
function Held.track()
  if installed then return end
  installed = true
  horizon.on("player_item_held", function(event)
    local p = event.player
    if p ~= nil and p.uuid ~= nil then selected[p.uuid] = event.to_slot end
  end)
end

--- Gets the acting player's selected stack as `{item, count, plain}`, or nil
--- for an empty hand or with no player on. `item` is the stack's id.
function Held.of(): { item: string, count: number, plain: boolean }?
  local players = horizon.players()
  local first = players[1]
  if first == nil then return nil end
  local inv = horizon.inventory(first.uuid)
  if inv == nil then return nil end
  local stack = inv[(selected[first.uuid] or 0) + 1]
  if stack == nil then return nil end
  return { item = stack.id, count = stack.count, plain = stack.plain }
end

return Held
