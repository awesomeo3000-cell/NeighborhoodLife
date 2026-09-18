arg[2]='wardrobe-panel'
-- Resolve through the target root so the wrapper works from the Lua CLI and
-- from the installed-game Kahlua runner (whose working directory is the game).
dofile(arg[1] .. '/../tests/interfaces.lua')
