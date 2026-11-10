-- The acting player's selected stack, for hooks whose events name none.
--
-- The native `right_click_block`, `attack_entity` and `destroy_block` events
-- name no held stack, and hand out no player table either. A callback that
-- needs the hand (a block's `on_use`, an item's `on_hit`) reads it here: the
-- player's selected hotbar slot, which the `player_item_held` hook reports,
-- looked up in that player's inventory. With one player on it is the acting
-- player's hand; with several players on the engine names no acting player,
-- so a callback that names nobody reads the first player of
-- `horizon.players()`.
--
-- The map is per uuid: one player's slot never moves another's. A cancelled
-- `player_item_held` still moves the map: the handler cannot tell whether a
-- later mod cancelled the change, so another mod's cancel desyncs it until
-- the next change (documented, not worked around).
local Held = {}

local selected = {} --- uuid text -> hotbar index, 0 to 8
local installed = false

--- Starts tracking the selected slot. Called when the first callback that
--- needs the hand is defined, and by the modkit's own scripts at load; one
--- handler serves every class. Joining seeds slot 0 (the server starts every
--- session there), leaving forgets the entry so a stale slot never follows a
--- uuid into its next session.
function Held.track()
  if installed then return end
  installed = true
  horizon.on("player_item_held", function(event)
    local p = event.player
    if p ~= nil and p.uuid ~= nil then selected[p.uuid] = event.to_slot end
  end)
  horizon.on("player_logged_in", function(event)
    local p = event.player
    if p ~= nil and p.uuid ~= nil then selected[p.uuid] = 0 end
  end)
  horizon.on("player_logged_out", function(event)
    local p = event.player
    if p ~= nil and p.uuid ~= nil then selected[p.uuid] = nil end
  end)
end

--- Gets a player's selected stack as `{item, count, plain}`, or nil for an
--- empty hand or with no player on. `item` is the stack's id. Without `uuid`
--- it reads the first player of `horizon.players()`: the acting player of
--- the callbacks whose events name nobody.
function Held.of(uuid: string?): { item: string, count: number, plain: boolean }?
  local id = uuid
  if id == nil then
    local players = horizon.players()
    local first = players[1]
    if first == nil then return nil end
    id = first.uuid
  end
  local inv = horizon.inventory(id)
  if inv == nil then return nil end
  local stack = inv[(selected[id] or 0) + 1]
  if stack == nil then return nil end
  return { item = stack.id, count = stack.count, plain = stack.plain }
end

return Held
