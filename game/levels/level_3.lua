return {
  id = 3,
  exit = { side = "top", pos = 200, gap = 160 },
  obstacles = {
    -- Choke point sits at x=150-190, inside the corridor the entry (x~14)
    -- and exit (x=120-280) actually share, so it genuinely gates the path
    -- instead of sitting off to the side of it. Its gap is widened to 100px
    -- (was 60) and centered at the entry's own height (y=300), so the fish
    -- can thread it on something close to its entry heading, and land
    -- already inside the exit's x-range with no lateral correction needed
    -- afterward — the old mid-room placement (x=560) needed a near-reversal
    -- turn to get back to the exit after squeezing through.
    { x = 150, y = 40,  w = 40, h = 210 },
    { x = 150, y = 350, w = 40, h = 330 },
  },
}
