# frozen_string_literal: true

require_relative "data"

module Quiz
  # Turns a user's 4-axis vector (Quiz::Data::AXES: Vibe, Play, Ethics, Fanbase)
  # into an abstract "kind of club you want" — a short archetype label plus a
  # descriptive sentence.
  #
  # The space is a 3 x 3 x 3 x 3 grid: H/M/L on every axis, 81 CELLS, keyed by a
  # 4-char code reading V-P-E-F. Those 81 cells are partitioned across 18
  # ARCHETYPES by an explicit mapping (db/seed-data/football-fan-archetypes-final-v2.md)
  # — several cells share an archetype, so the mapping is a lookup table, not a
  # formula, and the copy lives once per archetype rather than once per cell.
  #
  # Selection is NEAREST-CENTROID over the 81 cells, under the same normalised
  # slider weights Quiz::Score applies to clubs — the same operation as club
  # selection, one level coarser. It is deliberately NOT per-axis bucketing:
  # bucketing is separable, so nearest-cell would factorise per axis and no
  # positive weighting could ever change the winner. Measured over a 256-vector
  # probe grid, an unscattered grid moves the #1 archetype on 0% of probes.
  #
  # So CELL_VECS scatters each cell off its lattice point by a small symmetric
  # cross-axis coupling (see SCATTER): a combination that is extreme on several
  # axes is nudged further out. That breaks separability — reweighting an axis
  # can move the #1 pick and the whole ranking re-sorts live as the sliders move
  # — while every cell still resolves to its own code, including under lopsided
  # weights.
  #
  # Deliberately data-first: LEVELS, CELLS and SCATTER are shipped to the browser
  # (Quiz::ProfileData -> window ARCHETYPE) so the live client and this server
  # build the SAME centroids and run the SAME selection, and can't drift. The
  # centroids themselves are NOT shipped — both sides derive them, so there is
  # one definition. Keep the JS `archetypeFor` in views/quiz/index.erb a literal
  # transcription of #call.
  module Archetype
    module_function

    # Per-axis level values. Percentiles of the raw user-vector distribution:
    # "low" = p20, "mid" = p50, "high" = p80. RECALIBRATE from real responses
    # once you have them, and again whenever the question set changes — these
    # were derived from simulated answers and Ethics in particular will move.
    #
    # PROVISIONAL: only Ethics has an empirically derived "mid". The Vibe, Play
    # and Fanbase mids are the midpoint of their own low/high, adopted when the
    # axes went from two levels to three. They are placeholders for a real p50
    # and should be replaced in the same pass that recalibrates the rest.
    LEVELS = {
      "Vibe" => { "low" => 4.14, "mid" => 5.235, "high" => 6.33 },   # mid provisional: (low + high) / 2
      "Play" => { "low" => 5.00, "mid" => 6.07, "high" => 7.14 },    # mid provisional: (low + high) / 2
      "Ethics" => { "low" => 2.00, "mid" => 4.12, "high" => 6.24 },  # mid is a real p50
      "Fanbase" => { "low" => 4.07, "mid" => 5.105, "high" => 6.14 } # mid provisional: (low + high) / 2
    }.freeze

    LEVEL_ORDER = %w[low mid high].freeze
    CODE_LEVEL = { "L" => "low", "M" => "mid", "H" => "high" }.freeze
    LEVEL_CODE = CODE_LEVEL.invert.freeze

    # The 81 cells, in V-P-E-F order, mapped to the archetype that owns them.
    # Transcribed from the "Full cell -> archetype mapping" table in
    # db/seed-data/football-fan-archetypes-final-v2.md. Several cells share an
    # archetype by design (e.g. :student_of_the_game owns all nine H-*-*-L cells:
    # if the badge is incidental to you, the rest of the answers stop mattering).
    CELLS = {
      "HHHH" => :club_idealist, "HHHM" => :weekend_giant, "HHHL" => :student_of_the_game,
      "HHMH" => :glory_hunter, "HHMM" => :big_club_believer, "HHML" => :student_of_the_game,
      "HHLH" => :glory_hunter, "HHLM" => :big_club_believer, "HHLL" => :student_of_the_game,
      "HMHH" => :cathedral_builder, "HMHM" => :pragmatic_winner, "HMHL" => :student_of_the_game,
      "HMMH" => :glory_hunter, "HMMM" => :pragmatic_winner, "HMML" => :student_of_the_game,
      "HMLH" => :glory_hunter, "HMLM" => :trophy_collector, "HMLL" => :student_of_the_game,
      "HLHH" => :cathedral_builder, "HLHM" => :pragmatic_winner, "HLHL" => :student_of_the_game,
      "HLMH" => :glory_hunter, "HLMM" => :pragmatic_winner, "HLML" => :student_of_the_game,
      "HLLH" => :glory_hunter, "HLLM" => :trophy_collector, "HLLL" => :student_of_the_game,
      "MHHH" => :club_idealist, "MHHM" => :principled_fan, "MHHL" => :principled_fan,
      "MHMH" => :club_idealist, "MHMM" => :everyfan, "MHML" => :everyfan,
      "MHLH" => :terrace_dreamer, "MHLM" => :easygoing_supporter, "MHLL" => :free_agent,
      "MMHH" => :club_idealist, "MMHM" => :principled_fan, "MMHL" => :principled_fan,
      "MMMH" => :terrace_dreamer, "MMMM" => :everyfan, "MMML" => :everyfan,
      "MMLH" => :terrace_dreamer, "MMLM" => :easygoing_supporter, "MMLL" => :free_agent,
      "MLHH" => :club_idealist, "MLHM" => :principled_fan, "MLHL" => :principled_fan,
      "MLMH" => :terrace_dreamer, "MLMM" => :everyfan, "MLML" => :everyfan,
      "MLLH" => :terrace_dreamer, "MLLM" => :easygoing_supporter, "MLLL" => :free_agent,
      "LHHH" => :parish_purist, "LHHM" => :local_enthusiast, "LHHL" => :family_day,
      "LHMH" => :hometown_diehard, "LHMM" => :local_enthusiast, "LHML" => :family_day,
      "LHLH" => :hometown_diehard, "LHLM" => :local_casual, "LHLL" => :local_casual,
      "LMHH" => :parish_purist, "LMHM" => :local_enthusiast, "LMHL" => :family_day,
      "LMMH" => :hometown_diehard, "LMMM" => :local_enthusiast, "LMML" => :family_day,
      "LMLH" => :hometown_diehard, "LMLM" => :local_casual, "LMLL" => :local_casual,
      "LLHH" => :parish_purist, "LLHM" => :local_enthusiast, "LLHL" => :family_day,
      "LLMH" => :hometown_diehard, "LLMM" => :local_enthusiast, "LLML" => :family_day,
      "LLLH" => :hometown_diehard, "LLLM" => :local_casual, "LLLL" => :local_casual
    }.freeze

    # The 18 archetypes. This is the copy table — the one place to edit a label
    # or a sentence. Order follows the source doc.
    ARCHETYPES = {
      club_idealist: {
        "label" => "The Club Idealist",
        "sentence" => "You're looking for a club that stands for something, not just a name on a fixture list. It matters to you that the people in charge care about more than the next result, and that ambition doesn't come at the cost of decency. You want to walk into the ground and feel that what happens here means something, to you and to everyone else who shows up."
      },
      weekend_giant: {
        "label" => "The Weekend Giant",
        "sentence" => "You want a club that fills the stands and plays to win, but you're not interested in shortcuts or secrets. You'll watch every match, cheer every goal, but you won't trade your conscience for a cup. The victories have to feel earned, or they don't feel like victories at all."
      },
      big_club_believer: {
        "label" => "The Big-Club Believer",
        "sentence" => "You want a club that attacks, that gives you a reason to count down the days until kickoff. What happens on the pitch is what matters to you. The rest—the boardroom, the finances—you leave to someone else."
      },
      cathedral_builder: {
        "label" => "The Cathedral Builder",
        "sentence" => "You want to see a team that moves the ball with purpose, led by people you'd trust with your own name. You want to stand shoulder to shoulder with a crowd that feels every pass and every goal as much as you do."
      },
      pragmatic_winner: {
        "label" => "The Pragmatic Winner",
        "sentence" => "You want a club that gets the job done, no matter how it looks. A win is a win, as long as it's honest. You'll take the scrappy goals and the hard-fought points, but you won't celebrate a title that was bought instead of earned."
      },
      glory_hunter: {
        "label" => "The Glory Hunter",
        "sentence" => "You want a club that fills your Saturdays, the kind you'd wear on your back and sing for until your voice is gone. However they play, whoever's in charge, you're there for every minute, no questions asked."
      },
      trophy_collector: {
        "label" => "The Trophy Collector",
        "sentence" => "You want a club that brings home trophies, and you won't say sorry for wanting silverware. The rest—how they play, who owns them—doesn't matter as much as what's in the cabinet. That's what you'll remember, and that's what you'll show off."
      },
      student_of_the_game: {
        "label" => "The Student of the Game",
        "sentence" => "You love the game for its own sake—the way a move unfolds, the players who make you sit up and take notice, the moments you replay in your mind days later. You'll follow a club, but only if it fits your love of football. The badge is just a detail."
      },
      terrace_dreamer: {
        "label" => "The Terrace Dreamer",
        "sentence" => "You want a club where the faces are familiar and the songs feel like your own. The stand is a second home, and the people around you are more than strangers. You hope the owners are decent, and you trust what you're told."
      },
      everyfan: {
        "label" => "The Everyfan",
        "sentence" => "You want a club that holds its own, with owners you can accept, and a place in your week that feels real but doesn't take over your life. However they play, you're just glad to call it yours."
      },
      principled_fan: {
        "label" => "The Principled Fan",
        "sentence" => "You want a club you can support without second thoughts. Who owns it and how they act comes first. The football and the sense of belonging matter, but not enough to ignore what's wrong."
      },
      easygoing_supporter: {
        "label" => "The Easygoing Supporter",
        "sentence" => "You want a club you can enjoy without needing to study up. Football is supposed to be a good afternoon out, not another job. You're not going to ruin it by worrying about the finances."
      },
      free_agent: {
        "label" => "The Free Agent",
        "sentence" => "You want to watch football your way—wherever the best match is, whoever's on the pitch. No club owns your loyalty, and you don't feel bad about it for a second."
      },
      parish_purist: {
        "label" => "The Parish Purist",
        "sentence" => "You want your local club, run the right way, and you want to be in the stands singing for them. However they play, it's about the town having something to call its own and making sure it's cared for."
      },
      hometown_diehard: {
        "label" => "The Hometown Diehard",
        "sentence" => "You want the club just down the road, and you want every bit of it—every home match, every away trip, every song until your voice is gone. It's family, and you don't keep score with family."
      },
      local_enthusiast: {
        "label" => "The Local Enthusiast",
        "sentence" => "You want the team that belongs to your town, whatever kind of football they play. It's one good thing in your week, not the only thing. But if the owners don't respect the place, you won't stand with them."
      },
      family_day: {
        "label" => "The Family Day",
        "sentence" => "You want to spend the afternoon at the local ground, kids by your side, maybe an ice cream on the way home no matter the result. You hope the club is in good hands, but mostly you're here for the day out."
      },
      local_casual: {
        "label" => "The Local Casual",
        "sentence" => "You want football to stay close to home, something you can take or leave. If a ticket comes your way, you'll enjoy it. If not, you're just as happy."
      }
    }.freeze

    # Fallback when a vector can't be scored at all (nil / wrong arity). Not one
    # of the 18 — no valid vector reaches it.
    ALL_MID_LABEL = "The All-Rounder"
    ALL_MID_SENTENCE =
      "This is the kind of club you want: no single thing dominates — " \
      "you'll take a good club in almost any shape."

    # Equal weighting, used when a caller has no slider weights to offer.
    EQUAL_WEIGHTS = Array.new(4, 0.25).freeze

    # Per-axis midpoints — the centre of mass of the lattice.
    MID = Quiz::Data::AXES.map { |axis| LEVELS.fetch(axis).fetch("mid") }.freeze

    # Cross-axis coupling strength. For lattice point g with s = g - MID, each
    # axis becomes g[k] + SCATTER * (sum(s) - s[k]).
    #
    # This is what makes slider weights meaningful. On an unscattered grid,
    # nearest-cell factorises per axis and every positive weighting picks the
    # same winner. Swept over a 256-vector probe grid, share of probes whose
    # ARCHETYPE changes as the sliders move (81 codes collapse to 18 labels, so
    # this is lower than the share whose code changes):
    #
    #   0.0 -> 0%   0.06 -> 19%   0.12 -> 31%   0.2 -> 39%   0.4 -> 59%
    #
    # All 81 cells still resolve to their own code under lopsided weights at
    # every one of those values, so correctness does not bound this — raising it
    # buys more slider sensitivity at the cost of each centroid drifting further
    # from the anchor values its cell is supposed to stand for. 0.12 is the value
    # the previous 24-archetype table used. Both directions are pinned in
    # archetype_spec.rb — keep them green if you retune LEVELS or this.
    SCATTER = 0.12

    # The 4-D point each cell stands for: its per-axis LEVELS anchor, scattered
    # off the lattice. Derived rather than hand-authored so recalibrating LEVELS
    # moves the centroids with it.
    CELL_VECS = CELLS.keys.to_h do |code|
      g = Quiz::Data::AXES.each_with_index.map { |axis, i| LEVELS.fetch(axis).fetch(CODE_LEVEL.fetch(code[i])) }
      s = g.each_with_index.map { |v, k| v - MID[k] }
      total = s.sum
      [code, g.each_with_index.map { |v, k| (v + (SCATTER * (total - s[k]))).round(4) }.freeze]
    end.freeze

    # vec: Array(4) aligned to Quiz::Data::AXES — the RAW user vector from
    # Score#score_axes, not the amplified one. Amplification exists to reach the
    # club space; the archetype describes the person as they actually answered.
    # weights: the raw 1..10 slider values, or nil for equal weighting.
    # Returns { label:, sentence: } (unchanged interface).
    def call(vec, weights: nil)
      code = code_for(vec, weights:)
      return { label: ALL_MID_LABEL, sentence: ALL_MID_SENTENCE } if code.nil?

      row = ARCHETYPES.fetch(CELLS.fetch(code))
      { label: row["label"], sentence: row["sentence"] }
    end

    # Nearest cell centroid by weighted Euclidean distance, using the same
    # normalised slider weights Quiz::Score applies to clubs: an axis the person
    # says matters more counts for more when naming the kind of supporter they
    # are. Weights are normalised so only their balance matters. Ties resolved by
    # key order. Keep the JS `rankArchetypes` in views/quiz/index.erb in step.
    def code_for(vec, weights: nil)
      return nil unless vec.is_a?(Array) && vec.length == 4 && vec.all?(Numeric)

      w = weight_vector(weights)
      CELL_VECS.min_by { |_code, cell_vec| sq_distance(vec, cell_vec, w) }&.first
    end

    # Full ordering over the 18 archetypes, for the coach's view. An archetype
    # owns several cells, so its distance is the distance to its NEAREST cell —
    # which is also why rank.first agrees with #call. Ties keep CELLS order.
    def rank(vec, weights: nil)
      return [] unless vec.is_a?(Array) && vec.length == 4 && vec.all?(Numeric)

      rows = nearest_cell_per_archetype(vec, weight_vector(weights)).map do |id, (code, dist)|
        { code:, id:, label: ARCHETYPES.fetch(id)["label"], dist: Math.sqrt(dist) }
      end
      rows.sort_by { |row| row[:dist] }
    end

    # id => [winning_cell_code, squared_distance]. First minimum wins, so ties
    # keep CELLS order — same as Ruby's min_by and the JS transcription.
    def nearest_cell_per_archetype(vec, weights)
      CELLS.each_with_object({}) do |(code, id), acc|
        dist = sq_distance(vec, CELL_VECS.fetch(code), weights)
        acc[id] = [code, dist] if acc[id].nil? || dist < acc[id].last
      end
    end

    def sq_distance(vec_a, vec_b, weights = EQUAL_WEIGHTS)
      (0...4).sum { |i| weights[i] * ((vec_a[i] - vec_b[i])**2) }
    end

    # Slider weights as a normalised 4-vector summing to 1. Anything malformed
    # (nil, wrong arity, non-numeric, all zero) falls back to equal weighting.
    def weight_vector(weights)
      return EQUAL_WEIGHTS unless weights.is_a?(Array) && weights.length == 4 && weights.all?(Numeric)

      sum = weights.sum.to_f
      return EQUAL_WEIGHTS unless sum.positive?

      weights.map { |w| w / sum }
    end

    # Which level an axis score sits closest to. A diagnostic for reading a
    # vector by eye — selection uses nearest CELL, not per-axis banding, and the
    # two can disagree near a boundary because the centroids are scattered.
    # Ties fall to the lower level (min_by keeps the first).
    def band(value, axis = nil)
      levels = LEVELS[axis]
      return band_default(value) if levels.nil?

      LEVEL_ORDER.min_by { |level| (value - levels.fetch(level)).abs }
    end

    def band_default(value)
      return "low" if value <= 3.5
      return "high" if value >= 6.5

      "mid"
    end

    # The table shipped to the browser so its archetypeFor matches #call exactly.
    # CELL_VECS is deliberately absent: the client rebuilds it from these, so the
    # scatter has one definition rather than two that can drift.
    def client_table
      {
        "levels" => LEVELS,
        "cells" => CELLS,
        "archetypes" => ARCHETYPES,
        "scatter" => SCATTER,
        "allMidLabel" => ALL_MID_LABEL,
        "allMidSentence" => ALL_MID_SENTENCE
      }
    end
  end
end
