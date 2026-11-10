-- A rect and a line of text on the draw hooks; tools/hud-check.sh starts a
-- game with this probe and reads the log. Each handler logs once when it
-- runs, and draws with the batch methods: a failing draw call is an error
-- of the handler, which the check reports.
local seen = {}
local function saw(name, extra)
  if seen[name] then return end
  seen[name] = true
  horizon.log("PROBE hud " .. name .. (extra and (" " .. extra) or ""))
end
horizon.on("hud", function(event)
  saw("hud")
  local batch = event.batch
  local x, y = event.corners.place("top_left", 120, 20)
  batch.fill(x, y, 120, 20, 4278190080)
  batch.text("hud probe", 10, 10, 16777215, true)
  if event.corners.shown("top_left") then batch.fill(0, 0, 1, 1, 1) end
end)
horizon.on("gui_layer_post", function(event)
  saw("gui_layer_post", event.layer)
  event.batch.fill(0, 0, 2, 2, 4278190080)
  event.batch.text("layer probe", 10, 24, 16777215, false)
end)
