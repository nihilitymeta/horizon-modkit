-- The example mod's creative tab; scripts/registry.lua requires this file,
-- last, so the tab lists what the other modules declared.
local ns = registry.id -- "example_mod"

-- CREATIVE TABS: a title, an icon, the items in order.
registry.creative_tab("example", {
  title = "Example Mod",
  icon = ns .. ":example_item",
  items = {
    ns .. ":example_item",
    ns .. ":example_snack",
    ns .. ":example_lure",
    ns .. ":example_block",
    ns .. ":example_nest",
    ns .. ":example_mob_spawn_egg",
  },
})

return nil
