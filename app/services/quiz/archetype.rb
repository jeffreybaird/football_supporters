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
        "sentence" => "You want a club that's run well and still means something—one that competes without pretending the league table is the only thing that matters. You believe a place can be ambitious, decent, and full of real feeling all at once, and you're not willing to give up any of the three."
      },
      weekend_giant: {
        "label" => "The Weekend Giant",
        "sentence" => "You want a big club that goes forward and wins the right way. You'll follow it closely and care deeply, but you don't need to build your week around it—and you'd rather not celebrate a trophy that was bought with money nobody wants to talk about."
      },
      big_club_believer: {
        "label" => "The Big-Club Believer",
        "sentence" => "You want a big club that plays on the front foot and gives you something to look forward to. You're here for what happens on the pitch—the boardroom and the balance sheet are somebody else's argument."
      },
      cathedral_builder: {
        "label" => "The Cathedral Builder",
        "sentence" => "You want a great club that keeps the ball and knows exactly what it's doing, run by people you'd be proud to be associated with. And you want to watch it from a packed stand, with everyone around you feeling the same thing."
      },
      pragmatic_winner: {
        "label" => "The Pragmatic Winner",
        "sentence" => "You want a club that finds a way to win, however it has to be done—pretty or ugly, the result is the point. You'll take almost any route to the trophy, but not one paid for with money that should never have been in the game."
      },
      glory_hunter: {
        "label" => "The Glory Hunter",
        "sentence" => "You want a giant, and you want to give it everything—the shirt, the songs, the whole of your Saturday. However they play and whoever signs the cheques, you're all in and you're not asking questions."
      },
      trophy_collector: {
        "label" => "The Trophy Collector",
        "sentence" => "You want a club that wins things, and you're not going to apologise for it. The style, the story, the ownership—none of it changes what's in the cabinet, and the cabinet is what you'll be pointing at."
      },
      student_of_the_game: {
        "label" => "The Student of the Game",
        "sentence" => "You love football itself—the shapes, the players, the passages of play you'll still be thinking about on Tuesday. You'll happily follow a club, but on your own terms; the badge was never really the point."
      },
      terrace_dreamer: {
        "label" => "The Terrace Dreamer",
        "sentence" => "You want a club that feels like family and a stand that feels like home, where you know the songs and the people singing them. You'd like the owners to be decent, and you'll take their word for it rather than go looking."
      },
      everyfan: {
        "label" => "The Everyfan",
        "sentence" => "You want a club that competes, owners you can live with, and a place in your life that's real without taking the whole thing over. However they choose to play, you'll be glad it's yours."
      },
      principled_fan: {
        "label" => "The Principled Fan",
        "sentence" => "You want a club you can back without holding your nose—who owns it and how they behave comes first, and everything else follows. The football matters, and belonging matters, but not enough to look the other way."
      },
      easygoing_supporter: {
        "label" => "The Easygoing Supporter",
        "sentence" => "You want a club you can enjoy without doing the homework. Football is meant to be a good afternoon, not a second job, and you're not going to spoil it by reading about the accounts."
      },
      free_agent: {
        "label" => "The Free Agent",
        "sentence" => "You want football on your own terms—wherever the good games are, whoever happens to be playing. No badge has a claim on you, and you've never once felt guilty about it."
      },
      parish_purist: {
        "label" => "The Parish Purist",
        "sentence" => "You want your local club, run honestly, and you want to be in the ground singing for it. However they play is fine by you—this is about the town having something of its own and looking after it properly."
      },
      hometown_diehard: {
        "label" => "The Hometown Diehard",
        "sentence" => "You want the club down the road, and you want all of it—every home game, every away day, every song until your voice goes. It's family, and you don't audit family."
      },
      local_enthusiast: {
        "label" => "The Local Enthusiast",
        "sentence" => "You want the town team, whatever shape their football takes, and you're happy for it to be one good thing in your week rather than the only one. But you won't stand behind owners who treat the place badly."
      },
      family_day: {
        "label" => "The Family Day",
        "sentence" => "You want the local ground, the kids alongside you, and an ice cream on the way home whatever the score. You'd like the club to be in decent hands, and beyond that you're here for the afternoon."
      },
      local_casual: {
        "label" => "The Local Casual",
        "sentence" => "You want football to stay where it is—nearby, and entirely optional. If someone hands you a ticket you'll have a good time, and if they don't, that's fine too."
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
