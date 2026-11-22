## Pusher Force Aggregation Checklist

- [x] Rewrite `Sim.advance` Pass 1 — `lua/game/pusher_sim.lua` — replace the single sequential loop with a classification pass: each commanded pusher is evaluated against the start-of-tick matrix position and sorted into `contacts` (step target lands on a matrix cell) or `non_contacts` (everything else)

- [x] Implement `Sim.advance` Pass 2 — `lua/game/pusher_sim.lua` — collect unique direction vectors from all contact pushers, detect opposing conflicts on the same axis (→ `blocked = true`), sum into a net `(dx, dy)`, attempt one combined matrix move with bounds/gap/pusher-overlap checks, move all contact pushers to their individual target cells on success

- [x] Implement `Sim.advance` Pass 3 — `lua/game/pusher_sim.lua` — non-contact pushers act sequentially in original order after the matrix has moved; they may not step into the matrix's new position (attempting to do so sets `blocked = true`)

- [x] Remove inside-pusher passenger logic — `lua/game/pusher_sim.lua` — deleted the `pusher_inside` flag and `nc.inside` passenger special-casing added during development; pushers are never inside the matrix (enforced by `footprint_clear`), so the extra branches were dead code

- [x] Add same-direction deduplication test — `tests/test_pusher_scene.lua` — two pushers at (1,5) and (1,6) both going right; asserts matrix moves one cell to (3,5), not two

- [x] Add perpendicular/diagonal test — `tests/test_pusher_scene.lua` — pusher at (1,5) going right + pusher at (3,4) going down; asserts matrix moves diagonally to (3,6) and a negate op at (4,6) fires

- [x] Add opposing-conflict test — `tests/test_pusher_scene.lua` — pusher at (1,5) going right + pusher at (4,5) going left; asserts `scene.status == "fail"`

- [x] Add non-push below-matrix test — `tests/test_pusher_scene.lua` — pusher at (2,7) going down (outside and moving away from matrix at (2,5)–(3,6)); asserts matrix y stays at 5

- [x] Update follower-carry unit test — `tests/test_pushers.lua` — replaced impossible "inside pusher drags matrix" scenario (pusher at (1,6) inside the matrix) with a valid "follower carry" test: pusher at (0,5) pushes the matrix right twice, ending with matrix at x=3 and pusher at x=2

- [x] Fix gap test pusher position — `tests/test_pushers.lua` — changed gap-shove test pusher from (1,3) (inside the 2×2 matrix at (1,2)) to (0,2) (outside, one cell left), so the test correctly verifies that an outside pusher cannot shove the matrix onto a gap cell

- [x] Write design doc — `docs/design/pusher-force-aggregation.md` — documents goal, affected files, the three-pass model, the before/after behaviour table, what stays the same, and open questions

- [x] Write physics reference — `docs/pusher-physics.md` — ASCII diagrams covering the invariant (pushers never inside matrix), all three force-combination cases (same direction, perpendicular, opposing), landing outcomes table, and the open diagonal-corner-cell question
