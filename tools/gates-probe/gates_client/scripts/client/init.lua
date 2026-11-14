-- The client half of the gates check: one retained icon marker and one
-- world_primitives draw. Both calls must return without an error; the line is
-- logged once after both ran. A refused marker is a WARN in the log, which
-- the check fails on, and a refused primitive raises here and never logs.
local marker = false
local drawn = false
local logged = false

local function maybe()
  if marker and drawn and not logged then
    logged = true
    horizon.log("GATE client markers ok")
  end
end

horizon.on("client_tick_post", function()
  if marker then
    return
  end
  local me = horizon.player()
  if not me then
    return
  end
  local p = me.position
  horizon.marker_set("gates_check", {
    kind = "icon",
    pos = { x = p.x, y = p.y + 3, z = p.z },
    size = 1,
    sprite = "item/diamond",
    color = 0xFFFF00FF,
  })
  marker = true
  maybe()
end)

horizon.on("world_primitives", function(event)
  if drawn then
    return
  end
  local c = event.camera
  local a = { x = c.x, y = c.y + 5, z = c.z }
  local b = { x = c.x + 2, y = c.y + 5, z = c.z }
  event.primitives.line(a, b, 0xFFFF0000, 1)
  drawn = true
  maybe()
end)
