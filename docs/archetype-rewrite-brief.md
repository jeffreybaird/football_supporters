# Brief: rewrite the football-club archetypes

Hand this file to a Claude session **together with the current archetype copy**
(`config/locales/en.yml` and `config/locales/fr.yml`, under `content.archetypes`).
The goal is to rewrite the 18 archetype descriptions so they match how takers are
actually scored now — **less ethics-focused, and never claiming on-pitch success.**

---

## Why this is being done

The quiz's scoring model changed. Two framings in the current copy no longer match
the model:

1. **Ethics used to dominate** which club/archetype a taker got; it's now demoted to
   one signal among four. The copy still reads morality-first ("conscience,"
   "decency," "honest," "earned not bought").
2. **The copy promises winning/trophies** ("Weekend Giant," "here for the trophies,"
   "Trophy Collector"). The model has **no success axis at all** — it can't select for
   it — so any archetype that got matched to Tottenham / Leverkusen / Monaco reads as a
   mismatch. (Worked example below.)

Your job is prose only: re-frame the personalities. You are **not** changing the model.

---

## The four axes the quiz measures

Every taker and club is a vector `[Vibe, Play, Ethics, Fanbase]`. The axes measure
**taste and temperament, never achievement:**

- **Vibe** — appetite for winning-as-status and how loudly/assertively you carry your
  fandom (wanting the strong team to win and telling everyone, vs. quiet support or
  rooting for upsets).
- **Play** — the style of football you want: control vs. chaos, attacking risk vs.
  pragmatic results, plan vs. instinct.
- **Ethics** — how much a club's *conduct and values* affect your support, vs. not
  caring as long as you win.
- **Fanbase** — your relationship to the crowd and community: belonging in a
  collective vs. a private, individual relationship to the club.

There is **no "trophies / success / greatness" dimension.** Nothing in the scoring
knows or cares whether a club actually wins.

---

## What changed in scoring (so you understand *why* ethics recedes)

- **Old model:** raw answers matched directly to clubs and stretched outward. Because
  almost everyone self-reports as highly ethical (the average ethics answer is the
  highest, most inflated of the four axes), "morally good" clubs became magnets and
  results collapsed onto them.
- **New model:** each axis is **de-biased** — standardized against the *typical* taker —
  then placed into the league's popularity-weighted spread of clubs. Since ethics is the
  most inflated axis, a high-ethics answer is now treated as **normal rather than
  distinguishing.** Only an *unusually* high or low ethics answer moves the result.
  Vibe, Play, Fanbase, and club popularity now do the real work.

---

## The two hard rules

**Rule 1 — Ethics is a light accent, not the theme.** Lead each personality with its
dominant *non-ethics* axis (Vibe / Play / Fanbase). Strip the moralizing vocabulary
("conscience," "decency," "honest," "earned not bought," "stands for something," "trust
with your name") unless the cheat sheet marks the archetype genuinely Ethics-HIGH — and
even then, one light beat, sharing the stage.

**Rule 2 — Name the appetite, not the achievement.** No label or sentence may assert
on-pitch success — trophies, winning, "giant," "winners" as *fact*. State what kind of
football and fandom the taker *wants*, never what a club has *won*. The model cannot
match on success, so any such claim will read as a mismatch against the actual clubs.

---

## What to edit — and what NOT to touch

- **EDIT ONLY the copy:** `config/locales/en.yml` and `config/locales/fr.yml`, under
  `content.archetypes.<id>.label` and `content.archetypes.<id>.sentence`. Rewrite
  English, then update French to a faithful translation of your new English. Keep the
  two files' key sets identical.
- **Renames are display-only.** Changing a label (e.g. "Weekend Giant" → "The Light
  Brigade") changes only the `label` string. **Never change the archetype `id`/key** —
  the id is also a key in `config/quiz/archetypes.yml` (the 81-cell map); renaming the
  key unhooks the archetype from its cells and breaks scoring.
- **DO NOT TOUCH the scoring model:** `config/quiz/archetypes.yml` (`levels`, `cells`,
  `scatter`). Do not add, remove, reorder, or merge archetypes. Which taker-profile maps
  to which archetype is fixed — you are re-framing prose, not re-modelling.

---

## Per-archetype axis cheat sheet (derived from the `cells` lattice)

Numbers are the mean level across the cells that map to each archetype, on a
**0 = all-Low … 2 = all-High** scale. `HIGH` ≥ 1.5, `low` ≤ 0.5, else mid. Write each
personality around its HIGH/low axes.

**Turning a level into copy:** Vibe HIGH = wants winners/status, loud & assertive · low
= underdog-friendly, quiet. Play HIGH = attacking, chaos, risk · low = fine with
pragmatic/defensive results (Play sits at mid for most archetypes, so it rarely leads).
Ethics HIGH = conduct/values matter · low = doesn't care how success comes. Fanbase HIGH
= craves the crowd/collective · low = private, individual.

| archetype id | Vibe | Play | Ethics | Fanbase | lead the copy with… |
|---|---|---|---|---|---|
| **Ethics-LOW → strip ethics entirely** (current copy contradicts the profile — do these first) | | | | | |
| `big_club_believer` | **2.0** | **2.0** | 0.5 | 1.0 | attack, ambition, spectacle; indifferent to the boardroom |
| `glory_hunter` | **2.0** | 1.0 | 0.5 | **2.0** | winners + belonging, loud, no questions asked *(already ethics-free — good model)* |
| `trophy_collector` | **2.0** | 0.5 | 0.0 | 1.0 | status and silverware appetite; doesn't care how or how pretty |
| `terrace_dreamer` | 1.0 | 0.8 | 0.4 | **2.0** | the terrace, songs, atmosphere; belonging over principle |
| `hometown_diehard` | 0.0 | 1.0 | 0.5 | **2.0** | local roots and the crowd, blood not merit |
| `easygoing_supporter` | 1.0 | 1.0 | 0.0 | 1.0 | relaxed, takes the game as it comes, not precious |
| `free_agent` | 1.0 | 1.0 | 0.0 | 0.0 | unattached, individual; follows entertainment, no tribe |
| `local_casual` | 0.0 | 1.0 | 0.0 | 0.5 | low-key local, mild attachment, no crusades |
| **Ethics-NEUTRAL → keep ethics out of the spotlight** | | | | | |
| `everyfan` | 1.0 | 1.0 | 1.0 | 0.5 | broad, balanced fan; no single defining axis |
| `student_of_the_game` | **2.0** | 1.0 | 1.0 | 0.0 | appreciates quality/winning, watches solo/analytically |
| **Ethics-HIGH → keep ONE light beat, still lead with the stronger axis; modernize away from preachiness** | | | | | |
| `club_idealist` | 1.2 | 1.4 | **1.8** | **2.0** | *the* values archetype — pair principles with belonging, lighten the sermon |
| `principled_fan` | 1.0 | 1.0 | **2.0** | 0.5 | values-driven but solitary — individual, not communal |
| `parish_purist` | 0.0 | 1.0 | **2.0** | **2.0** | small-club purity + community; ethics understated |
| `cathedral_builder` | **2.0** | 0.5 | **2.0** | **2.0** | grand and communal; lead with collective/ambition, ethics one thread |
| `weekend_giant` | **2.0** | **2.0** | **2.0** | 1.0 | big, all-out attacking, glorious-doomed — see worked example |
| `pragmatic_winner` | **2.0** | 0.5 | **1.5** | 1.0 | win ugly but honest — lead with results-over-style |
| `family_day` | 0.0 | 1.0 | **1.5** | 0.0 | wholesome, low-key, decent — gentle/domestic, not moralizing |
| `local_enthusiast` | 0.0 | 1.0 | **1.5** | 1.0 | community-minded local who cares how the club acts — understated |

---

## Worked example: `weekend_giant`

**The problem.** Its cell (`HHHM`: high Vibe, high Play, high Ethics) selects for big,
maximally-attacking clubs. But maximal-attacking clubs are the thrilling **nearly-men**,
not the grinding winners — the actual serial winner (Man City, controlled/low-Play) maps
to `student_of_the_game` instead. So this archetype collects **Tottenham, Bayer
Leverkusen, Monaco, San Diego FC** — coherent as "thrilling and ambitious," incoherent
against the old label "Weekend Giant" and copy "here for the trophies." It broke Rule 2.

**The fix** (label rename is display-only; id stays `weekend_giant`):

- **Old label:** "The Weekend Giant"
- **New label:** "The Light Brigade"
- **Old sentence:** "You want the big club, the full ground, and a team that goes at
  people and wins. Nothing modest about it — you're here for the trophies and the
  swagger… Ideally the club carries itself well while it's collecting them."
- **New sentence:** "You want the big club, the full ground, and a team that charges at
  everything with the handbrake off. Glory over caution, the magnificent doomed run over
  a safe nil-nil — you'd rather go over the top in style than grind one out. Whether the
  cabinet keeps up is beside the point; the charge is the point."

This turns "these aren't winners" from a bug into the *identity* of the archetype.

---

## Rename watchlist (Rule 2 applies to the name, not just the copy)

Besides `weekend_giant`, these labels themselves assert achievement and are rename
candidates, not just rewrite candidates:

- `trophy_collector` — "Trophy Collector" names a won-trophy count the model can't see.
  Reframe to the *appetite* for status/silverware (e.g. wanting the club that acts like
  it should be winning), not a record of winning.
- `pragmatic_winner` — "Winner" as fact. Reframe to results-over-style *taste*.
- `glory_hunter`, `big_club_believer` — check the copy for stray "honest/earned/win"
  claims; the names are borderline (they name a pursuit, not an achievement).
