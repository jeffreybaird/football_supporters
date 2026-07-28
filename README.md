# Football Supporters

A recommender that answers two questions: **which club should you support**, and
**what kind of supporter are you**. You answer 13 questions about temperament
(not about football clubs), set four priority sliders, and the app places you as
a point in a 4-dimensional space and finds the nearest club in it — either within
one league, or across every league at once as a "Football Profile".

Live: <https://football-supporters.lennonbaird.com>

**This repository is source-available, not open source.** You may read it; you
may not fork, run, copy, or reuse it. See [LICENSE](LICENSE).

---

## Contents

- [Running it locally](#running-it-locally)
- [The model](#the-model) — axes, questions, loadings
- [The algorithm](#the-algorithm) — scoring, matching, archetypes
  - [1. Answers → axis vector](#1-answers--axis-vector)
  - [2. Sliders → axis weights](#2-sliders--axis-weights)
  - [3. Amplification](#3-amplification)
  - [4. Club ranking](#4-club-ranking)
  - [5. `sim` vs. `match` — two different numbers](#5-sim-vs-match--two-different-numbers)
  - [6. The chooser](#6-the-chooser-close-alternates)
  - [7. Football Profile](#7-football-profile-all-leagues-at-once)
  - [8. The archetype lattice](#8-the-archetype-lattice)
- [Why the client and server both score](#why-the-client-and-server-both-score)
- [Application structure](#application-structure)
- [Data model](#data-model)
- [Request flow](#request-flow)
- [Crests](#crests)
- [Privacy](#privacy)
- [Tests](#tests)
- [Deployment](#deployment)

---

## Running it locally

```bash
bundle install
cp .env.example .env                 # then fill in SECRET_KEY_BASE
bundle exec rake db:migrate          # creates db/development.sqlite3
bundle exec rake db:seed             # leagues + clubs
bundle exec puma -C config/puma.rb   # http://localhost:4000
bundle exec rspec                    # the suite
bundle exec rubocop                  # lint
```

Nothing above needs the network: crests fall back to the copies committed under
`public/images` whenever `CREST_BASE_URL` is blank.

Two URLs worth knowing:

- `/` — the quiz. Lands in Football Profile mode; `?league=<slug>` starts in
  single-league mode instead.
- `/coach` — the analyst view. Same scorer, but it exposes the raw axis vector,
  the live full ranking, the per-question loadings, and the archetype ordering.
  Deliberately unlinked from the quiz.

---

## The model

Everything reduces to **four axes** (`Quiz::Data::AXES`), each on a 0–10 scale:

| Axis        | Roughly                                                          |
|-------------|------------------------------------------------------------------|
| **Vibe**    | Size and status. Do you want the giant or the underdog?          |
| **Play**    | Style of football. Control and grind, or risk and chaos?          |
| **Ethics**  | Ownership and conduct. Does what happens off the pitch matter?    |
| **Fanbase** | Belonging. Do you want to fit in with the crowd, or not care?     |

Both a person and a club are a point in that space. A club's coordinates are
columns on its row (`teams.vibe/play/ethics/fanbase`). A person's coordinates are
derived from their answers.

**13 questions** (`Quiz::Data::Q`), each with 4 options. A question is not "which
club do you like" — it is temperamental ("Your ideal way to win", "Someone is
clearly wrong in a comment section. You…"). Each question carries:

- `load` — a 4-vector of **loadings**: how strongly this question speaks to each
  axis. `[0.9, 0.5, 0, 0]` means "mostly a Vibe question, partly a Play question,
  says nothing about Ethics or Fanbase".
- `a[i].v` — each option's 4-vector of **values**, with `nil` on any axis the
  option is silent about.

So a question contributes to an axis only where its loading is positive *and*
the chosen option has a value there. That is what lets one question inform two
axes at different strengths without a separate question per axis.

**4 sliders** (`Quiz::Data::SLIDERS`), one per axis, 1–10, asked after the
questions: how much does each of these things actually matter to you.

---

## The algorithm

The whole pipeline lives in `app/services/quiz/`. It is pure maths over data —
no DB access inside the scorer; it is handed the league's teams.

```
answers ──▶ score_axes ──▶ vec (raw 4-vector)
                             │
              weights ──▶ normalise ──▶ w
                             │
                             ├──▶ amplify(vec) ──▶ u ──▶ rank_teams ──▶ ranking ──▶ chooser ──▶ pick + alternates
                             │
                             └──▶ archetype nearest-cell ──▶ label + sentence
```

### 1. Answers → axis vector

`Quiz::Score.score_axes` — a loadings-weighted mean per axis. For each axis *k*:

```
vec[k] = Σ (load_k × value_k) / Σ load_k     over answered questions where
                                             load_k > 0 and value_k is not nil
```

An axis with no evidence at all defaults to `5.0` (dead centre) rather than `0`,
so silence reads as neutrality, not as an extreme.

This vector is **league-independent** — it describes the person, not a shortlist
of clubs. That is what makes the Football Profile cheap: score the axes once,
reuse across every league.

Answers are stored as a `{ question_id => option_index }` map, not a positional
array, because the client shuffles question order. Older positional rows are
normalised to the id map on read (`Score.answers_by_id`), so a link shared a year
ago still scores identically today.

### 2. Sliders → axis weights

Raw 1–10 slider values are normalised to sum to 1:

```
w[k] = weights[k] / Σ weights
```

Only the *balance* matters. Sliding everything to the top is identical to leaving
everything in the middle — which the UI says out loud, because otherwise people
max everything out and wonder why nothing moved.

### 3. Amplification

Before matching, the user's vector is stretched **outward from the centroid of
the league's clubs**:

```
centroid[k] = mean of all clubs' coordinate k
u[k]        = clamp(centroid[k] + (vec[k] − centroid[k]) × AMPLIFY, 0, 10)
```

Why: real answer sets cluster near the middle, and so does the club cloud. Without
amplification a large majority of takers land on whichever club happens to sit
nearest the centre, and the quiz feels broken — everyone gets the same answer.
Amplification pushes moderate people out toward the edges of the space so the
ranking discriminates.

`AMPLIFY` is **per league** (`leagues.amplify`), because leagues differ in how
tightly their clubs cluster. Current values: Premier League and NWSL 2.5, Liga MX
2.1, MLS 1.8, Ligue 1 1.7, La Liga 1.6, Bundesliga and Serie A 1.4, Première
Ligue Féminine 1.2, WSL 1.1. `1.0` disables it.

Amplification is a **ranking device only**. It never touches the displayed match
percentage or the archetype — see below.

### 4. Club ranking

Weighted Euclidean distance from the amplified user point to each club:

```
dist(t) = √( Σ w[k] × (u[k] − t[k])² )
sim(t)  = 1 / (1 + dist(t))
```

Sorted by `sim` descending, ties broken by the club's position in the supplied
list — a stable sort that matches the browser's, so client and server agree
exactly on ties.

### 5. `sim` vs. `match` — two different numbers

This trips people up, so it is worth stating plainly. There are two similarity
numbers and they are computed differently on purpose:

|         | `sim`                            | `match` (the "% match" you see)             |
|---------|----------------------------------|---------------------------------------------|
| Formula | `1 / (1 + dist)`                 | `1 − raw_dist / DIAMETER`                   |
| Input   | **amplified** vector `u`         | **raw** vector `vec`                        |
| Shape   | steep, non-linear                | linear across the space                      |
| Used by | ranking, ordering, the chooser   | display only                                 |

`DIAMETER = 10.0`: axes span 0–10 and the normalised weights sum to 1, so the
largest possible weighted distance is `√(1 × 10²) = 10`.

`sim` is deliberately steep — that is what makes it good at ordering and terrible
as a human-facing percentage. And because `match` is computed from the raw vector,
it is comparable *across leagues* even though each league amplifies differently.
A profile can honestly say "83% Bundesliga, 71% MLS" precisely because
amplification was kept out of that number.

### 6. The chooser (close alternates)

The result page sometimes says "or maybe you're more…". A club is offered as an
alternate when it sits within `CHOOSER_THRESHOLD` weighted distance of the
winner, capped at `MAX_CHOICES` (3):

```ruby
rank.select.with_index { |r, i| i.zero? || (r.dist - rank[0].dist) < chooser_threshold }
    .first(max_choices)
```

Both are per-league columns (`leagues.chooser_threshold`, `leagues.max_choices`),
currently 0.20–0.27 and 3. `Result#gap` — the distance between #1 and #2 — is
what the page uses to decide between "your club" and "a close call".

### 7. Football Profile (all leagues at once)

`Quiz::ProfileScore` is the default mode. The axis vector is league-independent,
so it is computed once and then each league is resolved with the ordinary
per-league scorer under that league's own tuning:

```ruby
vec = Score.score_axes(answers)
leagues.map { |l| Score.call(teams: l.scored_teams, answers:, weights:, **l.scoring_params).rank.first }
```

Each entry carries `match_pct` (the raw-distance number, rounded) so the leagues
are legitimately comparable. A league with no clubs is skipped — an empty cloud
has no centroid to amplify against.

### 8. The archetype lattice

The profile's headline ("The Terrace Dreamer", "The Student of the Game") comes
from `Quiz::Archetype`, and it is the most involved part of the system.

**The space.** Each axis is given three anchor levels — low/mid/high, calibrated
as roughly the p20/p50/p80 of the observed vector distribution. Three levels on
four axes is a **3×3×3×3 = 81-cell lattice**, each cell keyed by a 4-character
code reading V-P-E-F (`"HMLH"`). Those 81 cells are mapped onto **18 archetypes**
by an explicit table. Several cells share an archetype by design — for example
all nine `H-*-*-L` cells are *The Student of the Game*: if the badge is incidental
to you, the rest of your answers stop mattering.

**Selection is nearest-centroid**, under the same normalised slider weights the
club scorer uses — the same operation as picking a club, one level coarser.

**Why not just bucket each axis?** Because bucketing is separable. On a clean
lattice, nearest-cell factorises into four independent per-axis choices, and a
positive weight on an axis can never change which cell wins — every weighting
picks the same archetype. Measured over a 256-vector probe grid, an unscattered
lattice moved the #1 archetype on **0%** of probes. The sliders would be
decorative.

**So the lattice is scattered.** Each cell's centroid is displaced off its lattice
point by a small symmetric cross-axis coupling:

```
s[k]    = anchor[k] − MID[k]
cell[k] = anchor[k] + SCATTER × (Σs − s[k])
```

A combination that is extreme on several axes gets nudged further out. That breaks
separability: reweighting an axis now moves the winner, and the ranking re-sorts
live as you drag a slider. `SCATTER = 0.12`; the sensitivity it buys, as share of
probe vectors whose archetype changes when the sliders move:

```
0.0 → 0%    0.06 → 19%    0.12 → 31%    0.2 → 39%    0.4 → 59%
```

Correctness does not bound this — all 81 cells still resolve to their own code
under lopsided weights at every value listed. Higher just trades fidelity (each
centroid drifting from the anchors its cell is meant to stand for) for slider
sensitivity. Both directions are pinned in `spec/services/quiz/archetype_spec.rb`.

**The archetype uses the raw vector, never the amplified one.** Amplification is
a device for reaching the club cloud; the archetype describes the person as they
actually answered.

**Centroids are derived, not authored.** `CELL_VECS` is computed from `LEVELS` and
`SCATTER`, so recalibrating the anchors moves every centroid with them. The
browser is shipped `LEVELS`, `CELLS` and `SCATTER` — *not* the centroids — and
rebuilds them itself, so there is exactly one definition of the scatter.

> The level anchors are currently **provisional**: only Ethics has an empirically
> derived mid. Vibe, Play and Fanbase mids are the midpoint of their own low/high,
> adopted when the axes went from two levels to three. They want recalibrating
> against real responses, and again whenever the question set changes.

---

## Why the client and server both score

The quiz is client-rendered so the ranking updates live as you drag a slider —
that responsiveness is the point of the sliders. But a shared `/q/:slug` page is
server-rendered, for social unfurls and for people without JS.

So the same algorithm exists twice: in Ruby (`app/services/quiz/`) and in JS
(`views/quiz/index.erb`). That is a real drift risk, handled three ways:

1. **One dataset.** The browser is handed exactly the payload the server scores
   with — `Quiz::ClientData` builds `window.QUIZ_DATA`, and `GET /leagues/:slug`
   returns the identical structure for live league switching. There is no separate
   client copy of the questions, loadings, clubs, or tuning constants.
2. **Derived, not duplicated.** Anything computable is shipped as its inputs, not
   its outputs — the archetype centroids being the clearest case.
3. **Transcription, stated as such.** The JS `archetypeFor` / `rankArchetypes` are
   literal transcriptions of `Archetype#call` / `#rank`, and both sides say so in
   comments. The specs assert stored results re-score to the same pick, so a
   divergence surfaces as a failing shared-page test rather than as two different
   answers for one person.

---

## Application structure

Modular Sinatra (`class App < Sinatra::Base`) on Puma, Sequel over SQLite, ERB
views, vanilla JS. No Rails, no Hotwire, no build step. Conventions live in
`CLAUDE.md` and `.claude/`.

```
app.rb                       the Sinatra app — thin routes + view helpers
config/
  environment.rb             boot: dotenv, DB, models, services
  database.rb                the single global DB handle (SQLite, WAL)
  puma.rb
app/
  models/                    Sequel models
    league.rb                a competition; owns its scoring tuning
    team.rb                  a club; #vector is its 4 coordinates
    quiz_result.rb           a completed quiz, shareable at /q/:slug
    feedback.rb              a feedback-form submission
  services/quiz/
    data.rb                  AXES, the 13 questions + loadings, SLIDERS, defaults
    score.rb                 the recommender: score_axes, rank_teams, chooser
    archetype.rb             the 81-cell lattice, 18 archetypes, nearest-centroid
    profile_score.rb         one answer set scored against every league
    answer_validation.rb     shared coercion/validation of answers + weights
    create.rb                persist a single-league result, mint a slug
    create_profile.rb        persist a cross-league profile, mint a slug
    client_data.rb           the browser payload for one league
    profile_data.rb          the browser payload for all leagues
    fingerprint.rb           coarse, non-reversible taker grouping
    seed.rb                  leagues + clubs
  services/feedbacks/        create + notify (email via Resend)
  clients/resend.rb          the only place the email vendor is called
  current.rb                 thread-local request context, reset per request
views/
  layout.erb                 shell, OG/meta tags
  quiz/index.erb             the entire client app: questions, sliders, result,
                             coach view, and the JS transcription of the scorer
  quiz/result.erb            server-rendered single-league share page
  quiz/profile_result.erb    server-rendered profile share page
  quiz/_badge.erb            crest or initials
  quiz/not_found.erb
  feedback/
public/
  css/app.css                one stylesheet, CSS-variable tokens
  js/share.js                copy-link + Web Share API
  images/<league>/           committed crest fallback
db/
  migrate/                   Sequel migrations, run by the deploy gate
  seed-data/                 club data + the archetype source doc
spec/                        RSpec: models, services, requests
deploy/                      compose.yaml, Caddyfile, swap.sh, litestream.yml
```

Rules the code holds to: routes parse params, call one service, and render.
Domain logic is in services returning `dry-monads` Results with tagged failures
(`Failure([:validation, errors])`), never bare booleans. User-facing rows are
soft-deleted (`deleted_at`), never destroyed — every read path goes through a
`kept` dataset.

---

## Data model

```
leagues ──1:N──▶ teams
   │                ▲
   │                │ N:M (quiz_result_teams)
   └──1:N──▶ quiz_results ─┘
```

- **`leagues`** — `slug`, `name`, `position`, `active`, plus the scoring tuning
  that makes a league self-describing: `amplify`, `chooser_threshold`,
  `max_choices`. Adding a league is data, not code: one row plus its clubs.
- **`teams`** — `league_id`, `name`, the four coordinate columns, `blurb`
  (result-page copy), `crest` (a `"<league-slug>/<file>.png"` path), `position`.
- **`quiz_results`** — `slug` (the share URL), `answers` and `weights` (JSON),
  `pick` (denormalised for OG tags and cheap lookups), `league_id`, `profile`,
  `fingerprint`. A profile row has `league_id` nil and stores the archetype label
  in `pick`.
- **`quiz_result_teams`** — which clubs a taker was actually *shown*: the winner
  plus any alternates the chooser offered, or every league's winner for a profile.
  Answers "which takers were pointed at this club?".

Results store **inputs, not outputs**. The ranking is re-derived on every read of
`/q/:slug`, so a shared link always reflects the live algorithm and live club
data. `pick` is a denormalised convenience, not the source of truth.

Current data: 10 leagues, 186 clubs — men's and women's, Europe and North
America.

---

## Request flow

| Route              | Does                                                                       |
|--------------------|----------------------------------------------------------------------------|
| `GET /`            | The quiz. Embeds `QUIZ_DATA` (single league) and, in the default profile mode, `QUIZ_PROFILE` (all leagues) so landing needs no fetch. |
| `GET /coach`       | Same page with the analyst view enabled.                                    |
| `GET /leagues/:slug` | One league's dataset as JSON — the league picker swaps without a reload.  |
| `GET /leagues`     | Every active league's dataset, for profile mode.                            |
| `POST /quizzes`    | Persist a completed quiz; returns `{ slug, url }`. 422 on validation, 409 on conflict. |
| `GET /q/:slug`     | The server-rendered share page. Re-scores from stored inputs; 404 on unknown or soft-deleted. |
| `GET/POST /feedback` | Plain-form feedback; stored, then emailed if Resend is configured.        |
| `GET /up`          | Liveness — 200 once the process can reach the DB.                           |

Submission is validated hard before it is stored: all 13 questions answered, each
option index in range for *its* question, exactly 4 weights each 1–10
(`Quiz::AnswerValidation`). Slugs are `SecureRandom.urlsafe_base64(8)` with a
unique index as the real guard and a bounded retry on collision.

---

## Crests

Club crests are served from a DigitalOcean Spaces CDN in production and from the
committed copies in `public/images` otherwise — controlled by `CREST_BASE_URL`,
where **blank counts as unset** (the deploy writes every config line into `.env`
whether or not it has a value, so an unconfigured CDN arrives as `""`).

One wrinkle worth knowing: the CDN's object keys are Unicode-**decomposed** (NFD)
for the accented names, because the upload normalised them, while the files on
disk and the names in the seed are composed (NFC). Object keys match byte for
byte, so "Köln" in the wrong form is a 403. `App#crest_url` converts on the way
out for the CDN and deliberately does not for the local fallback.

---

## Privacy

No accounts, no login, no tracking scripts, no cookies beyond the session. A
submission stores its answers, its weights, and a `fingerprint`: a SHA-256 of a
server-side salt with the IP, User-Agent and Accept-Language. It is coarse and
non-reversible — enough to group one taker's submissions or count distinct
takers, and it recovers neither the IP nor the headers. It is not an identity and
not an auth token; two people behind one NAT on the same browser can collide, and
that is acceptable for what it is used for. The salt is `FINGERPRINT_SALT`, so it
can be rotated per deploy.

Feedback submissions store the message and an optional email. The destination
inbox lives only in the environment — never in source, never in a rendered page.

---

## Tests

```bash
bundle exec rspec
bundle exec rubocop
```

Tests are treated as a contract: an existing test is a specification, not an
obstacle, and a previously-passing test that fails after a change means the
change broke intended behaviour. Every behaviour addition ships with a spec that
would fail without it. The interesting ones are the scorer specs — they pin the
things a refactor would quietly break: that `match` stays raw-distance-derived
while `sim` stays amplified, that legacy positional answer arrays still score
identically to the id map, that all 81 archetype cells resolve to their own code
under lopsided weights, and that the scatter stays in the band where sliders
actually move the result.

---

## Deployment

Push to `main` → GitHub Actions runs the suite as a gate → builds a Docker image
→ ships it to a DigitalOcean droplet over SSH → runs `rake db:migrate` (also a
gate) → blue/green swap behind Caddy, which terminates TLS. SQLite is replicated
continuously to object storage by Litestream. Config and secrets are written into
a `.env` on the runner at deploy time and scp'd across — never committed, never
in cloud-init.

The deploy is the only path to production, and it always runs the tests.

---

## License

Copyright (c) 2026 Jeffrey Baird. All rights reserved.

Source-available, **not** open source. You may read this code and quote short
excerpts with attribution. You may not fork, mirror, copy, modify, run, deploy,
or reuse it — including its questionnaire, scoring model, archetype taxonomy,
coefficients, or written copy — without prior written permission. Full terms in
[LICENSE](LICENSE).

Club crests, club names, and competition names are the property of their
respective owners and are used here for identification only.
