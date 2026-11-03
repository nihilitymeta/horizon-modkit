-- The mod object the other files share: one `modkit.mod` per mod. Each file
-- gets it with `require("@example/mod")`, which runs this once; `@example`
-- is the alias in .luaurc for scripts/example, which the game's `require`
-- resolves the same way.
local modkit = require("@modkit")
return modkit.mod("example_mod")
