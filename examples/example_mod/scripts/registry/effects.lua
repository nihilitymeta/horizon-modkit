-- The example mod's mob effect; scripts/registry.lua requires this file.
-- MOB EFFECTS: a category and a colour; the scripts give it
-- (scripts/server/example/effects.lua). It does nothing on its own.
registry.mob_effect("example_effect", { category = "beneficial", color = 0x7FD4FF })

registry.lang("en_us", { ["effect.example_mod.example_effect"] = "Exemplary" })

return nil
