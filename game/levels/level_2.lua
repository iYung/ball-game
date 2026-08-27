return {
  id = 2,
  exit = { side = "right", pos = 300, gap = 160 },
  obstacles = {
    -- Shifted left of center so the wide, easy route (480px clear) curves
    -- toward the exit side (right); the narrower route (240px) on the left
    -- is still open but isn't the path of least resistance. Wide clearance
    -- on both sides means a single gentle sweep clears it — the fish-flip
    -- swim struggles with tight turns, so this avoids demanding one.
    { x = 280, y = 340, w = 480, h = 30 },
  },
}
