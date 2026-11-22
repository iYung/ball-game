# Pusher Physics

Rules for how pushers interact with the matrix: what can push, how forces combine, and what the matrix can land on.

---

## Invariant: pushers are never inside the matrix

The game enforces this at all times via `footprint_clear`. A pusher can only push the matrix by stepping **into** it from outside. A pusher that is not currently adjacent to the matrix cannot push it, regardless of direction.

```
✓ Valid — outside → in      ✗ Never happens             No push — moving away

P→ M  M                     M  M                        M  M  P↓
   M  M                     P? M                        M  M
                             (inside: impossible)        P below, going down — not contact
```

---

## Force combination

All pushers are classified at the **start** of a tick using start-of-tick positions. Contact pushers (outside, stepping into the matrix) all act together in one combined move. The matrix moves exactly once per tick.

### Same direction — deduplicated to one cell

```
Before          After

   M  M            M  M
P→ M  M   →   P→  M  M
P→ M  M        P→ M  M
```

`(+1,0) + (+1,0)` → dedup → `(+1,0)` — matrix moves one cell, not two.

### Perpendicular — diagonal move

Both pushers step **into** the matrix from outside — one from the left, one from above.

```
Before             After

      P↓                      
P→ M  M    →   P  P          
   M  M               M  M   
                       M  M  
```

`(+1,0) + (0,+1)` = `(+1,+1)` — matrix moves diagonally.

### Opposing — conflict → puzzle fails

```
P→ M  M  P←
   M  M
```

`(+1,0) + (-1,0)` → conflict → **blocked → puzzle fails**

Same rule applies to up vs down.

---

## What the matrix can land on

| Landing | What happens |
|---|---|
| Op tile | `_process_footprint` detects the newly entered cell and fires the op. Run continues. |
| A pusher | Pass 2 checks non-contact pushers against the new footprint before moving. Overlap → **blocked → puzzle fails**. |
| Off grid | `Sim.blocked` rejects any position where the footprint extends past the grid boundary. **Blocked → puzzle fails.** |
| Gap cell | `Sim.blocked` checks every cell the footprint would cover. Any overlap with a gap → **blocked → puzzle fails.** |

---

## Open question — diagonal corner cells

For a diagonal move `(+1,+1)` the matrix jumps from start to destination in one step. The two "corner" cells it clips through — `(start.x+dx, start.y)` and `(start.x, start.y+dy)` — are **not** currently validated.

```
Start          Destination    Corner cells (not checked)

P→ M  M            P  P             P  P
   M  M    →          M  M             ?  M  M
   P↓                 M  M          ?     M  M
```

A gap or wall at a corner cell does not currently block the move. Decision needed: should diagonal moves require the corner cells to be clear?
