# Prompt for Claude Code: Replace quiz archetype system

Replace the fan archetype system with the new finalized set. The attached file `football-fan-archetypes-final-v2.md` is the source of truth for archetype names, descriptions, and the cell-to-archetype mapping. Do not invent, rename, or reorganize archetypes beyond what it specifies.

## Current state (important — read first)

The existing system (in the module containing `LEVELS` and `ARCHETYPES`) uses:
- **Binary Vibe, Play, Fanbase (H/L) and ternary Ethics (H/M/L)** — 24 archetypes keyed by 4-char codes like `"HHHH"` in V-P-E-F order.
- A `vec` per archetype aligned to `Quiz::Data::AXES`, which suggests assignment may be nearest-prototype-vector.
- `LEVELS` anchor values per axis that appear empirically derived.

The new system requires **H/M/L on all four axes** (81 cells → 19 archetypes). This is a scoring change, not just a content swap.

## Task

1. **Find how archetype assignment currently works.** Trace from quiz axis scores to archetype selection. Determine whether it uses nearest-vector matching on `vec`, threshold discretization via `LEVELS`, or something else. Also determine how the `LEVELS` anchor values were originally derived (script, seed data, hand-tuned).
2. **Add mid levels to Vibe, Play, and Fanbase in `LEVELS`.** If you can find and rerun the original derivation method, use it. If not, use the midpoint of the existing low/high anchors and clearly flag this as provisional in a code comment and in your summary.
3. **Replace `ARCHETYPES` with the 19 new archetypes.** Keep the existing 4-char key convention, now spanning all 81 codes (V-P-E-F, each H/M/L). Use the explicit 81-line "cell → archetype mapping" section of the doc — not the compressed patterns, which are for human readability only (two archetypes require multiple patterns). Since multiple codes share an archetype, structure this as an 81-entry code→archetype-id lookup plus a 19-entry archetype table (label + sentence), rather than duplicating content 81 times.
4. **Change assignment to discretize-then-lookup**: bucket each axis score into H/M/L using `LEVELS` (match the existing bucketing approach — nearest anchor or thresholds — extended to three levels), build the 4-char code, look up the archetype. Remove `vec` unless something else consumes it; if something does, report what before deciding.
5. **Write the 19 `sentence` values in the established voice**: warm, second-person, "You want a club that…" style, matching the length and tone of the current sentences. Base them on the descriptions in the doc. These will be reviewed, so keep them in one obvious place.
6. Update all references to the 24 removed archetypes (The Dreamer, The Connoisseur, The Traditionalist, The Perfectionist, The Romantic, The Aficionado, The Communitarian, The Quiet Conscience, The True Believer, The Showman, The Institution, The Pragmatist, The Firebrand, The Enthusiast, The Regular, The Easygoer, The Ultra, The Headliner, The Empire Loyalist, The Winner, The Loyalist, The Thrill-Seeker, The Diehard, The Stoic) anywhere they appear: result screens, share text, tests, seeds.

## Verification (required)

Add or update tests asserting:
- Every one of the 81 codes maps to exactly one of the 19 archetypes; archetype count is exactly 19 and names match the doc.
- Spot checks against the doc: HHHH → The Club Idealist; HLMH → The Glory Hunter; MMLH → The Terrace Dreamer; MLMM → The Everyfan; LLLL → The Local Casual.
- Discretization: axis scores at/near the anchor values land in the expected buckets, including the new mid buckets.

Run the full test suite before finishing. If assignment works differently than assumed anywhere above, stop and report the discrepancy instead of guessing.


# Football Fan Archetypes — Final (19 groups, exact 81/81 partition)

**Code:** Vibe – Play – Ethics – Fanbase, each H/M/L.

- **Vibe:** H = drawn to size and glory · M = competitive but realistic · L = smaller local side
- **Play:** H = front-foot attacking · M = possession and control · L = defensive / counter
- **Ethics:** H = clean ownership matters · M = owners you can live with · L = blind eye
- **Fanbase:** H = full belonging, march and sing · M = identity without immersion · L = follows on own terms

Groups marked with two patterns require both; every cell matches exactly one group.

| # | Name | Pattern(s) | Description |
|---|---|---|---|
| 1 | The Club Idealist | H-H-H-H | Wants a clean giant that attacks and a terrace that sings. Almost nothing qualifies. |
| 2 | The Weekend Giant | H-H-H-M | Big club, front-foot football, devoted but chill — and no blood money. |
| 3 | The Big-Club Believer | H-H-(M/L)-M | Big club, on the front foot, devoted but chill; here for the football, not the boardroom. |
| 4 | The Cathedral Builder | H-(M/L)-H-H | A clean giant that controls the ball, worshipped from the stands. |
| 5 | The Pragmatic Winner | H-(M/L)-(H/M)-M | Whatever style wins; trophies are the point — but blood money is a step too far. |
| 6 | The Glory Hunter | H-*-(M/L)-H | Total devotion to a giant, whatever the style, no questions asked. |
| 7 | The Trophy Collector | H-(M/L)-L-M | Winning is the point, full stop. The cabinet does the talking. |
| 8 | The Student of the Game | H-*-*-L | Loves the sport itself — systems, players, moments. The badge is incidental. |
| 9 | The Club Idealist | M-(M/L)-H-H · M-H-(H/M)-H | Believes in a well-run, competitive club with real culture — the realistic dream. |
| 10 | The Terrace Dreamer | M-(M/L)-M-H · M-*-L-H | The club is family and the terrace is home; ethics get a passing grade, not an audit. |
| 11 | The Everyfan | M-*-M-(M/L) | The reasonable center: competes, tolerable owners, healthy attachment, any style. |
| 12 | The Principled Fan | M-*-H-(M/L) | Ethics first, football second, identity third. |
| 13 | The Easygoing Supporter | M-*-L-M | Loves the club without sweating the details. Football is meant to be enjoyed. |
| 14 | The Free Agent | M-*-L-L | Goes wherever the game takes them; no strings, no regrets. |
| 15 | The Parish Purist | L-*-H-H | Clean local club, any style, full voice. Football as civic virtue. |
| 16 | The Hometown Diehard | L-*-(M/L)-H | The local club is family; the singing never stops. |
| 17 | The Local Enthusiast | L-*-(H/M)-M | Loves the town team whatever the style; won't overlook bad owners. |
| 18 | The Family Day | L-*-(H/M)-L | Local ground, kids in tow, ice cream after no matter the score. |
| 19 | The Local Casual | L-*-L-(M/L) | They'll go if someone hands them tickets. |

## Full cell → archetype mapping (for implementation)

Order: Vibe-Play-Ethics-Fanbase.

```
H-H-H-H → The Impossible Romantic
H-H-H-M → The Weekend Giant
H-H-H-L → The Student of the Game
H-H-M-H → The Glory Hunter
H-H-M-M → The Big-Club Believer
H-H-M-L → The Student of the Game
H-H-L-H → The Glory Hunter
H-H-L-M → The Big-Club Believer
H-H-L-L → The Student of the Game
H-M-H-H → The Cathedral Builder
H-M-H-M → The Pragmatic Winner
H-M-H-L → The Student of the Game
H-M-M-H → The Glory Hunter
H-M-M-M → The Pragmatic Winner
H-M-M-L → The Student of the Game
H-M-L-H → The Glory Hunter
H-M-L-M → The Trophy Collector
H-M-L-L → The Student of the Game
H-L-H-H → The Cathedral Builder
H-L-H-M → The Pragmatic Winner
H-L-H-L → The Student of the Game
H-L-M-H → The Glory Hunter
H-L-M-M → The Pragmatic Winner
H-L-M-L → The Student of the Game
H-L-L-H → The Glory Hunter
H-L-L-M → The Trophy Collector
H-L-L-L → The Student of the Game
M-H-H-H → The Club Idealist
M-H-H-M → The Principled Fan
M-H-H-L → The Principled Fan
M-H-M-H → The Club Idealist
M-H-M-M → The Everyfan
M-H-M-L → The Everyfan
M-H-L-H → The Terrace Dreamer
M-H-L-M → The Easygoing Supporter
M-H-L-L → The Free Agent
M-M-H-H → The Club Idealist
M-M-H-M → The Principled Fan
M-M-H-L → The Principled Fan
M-M-M-H → The Terrace Dreamer
M-M-M-M → The Everyfan
M-M-M-L → The Everyfan
M-M-L-H → The Terrace Dreamer
M-M-L-M → The Easygoing Supporter
M-M-L-L → The Free Agent
M-L-H-H → The Club Idealist
M-L-H-M → The Principled Fan
M-L-H-L → The Principled Fan
M-L-M-H → The Terrace Dreamer
M-L-M-M → The Everyfan
M-L-M-L → The Everyfan
M-L-L-H → The Terrace Dreamer
M-L-L-M → The Easygoing Supporter
M-L-L-L → The Free Agent
L-H-H-H → The Parish Purist
L-H-H-M → The Local Enthusiast
L-H-H-L → The Family Day
L-H-M-H → The Hometown Diehard
L-H-M-M → The Local Enthusiast
L-H-M-L → The Family Day
L-H-L-H → The Hometown Diehard
L-H-L-M → The Local Casual
L-H-L-L → The Local Casual
L-M-H-H → The Parish Purist
L-M-H-M → The Local Enthusiast
L-M-H-L → The Family Day
L-M-M-H → The Hometown Diehard
L-M-M-M → The Local Enthusiast
L-M-M-L → The Family Day
L-M-L-H → The Hometown Diehard
L-M-L-M → The Local Casual
L-M-L-L → The Local Casual
L-L-H-H → The Parish Purist
L-L-H-M → The Local Enthusiast
L-L-H-L → The Family Day
L-L-M-H → The Hometown Diehard
L-L-M-M → The Local Enthusiast
L-L-M-L → The Family Day
L-L-L-H → The Hometown Diehard
L-L-L-M → The Local Casual
L-L-L-L → The Local Casual
```