# frozen_string_literal: true

require "yaml"

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

    # The language-neutral scoring model — the per-axis level anchors, the 81-cell
    # mapping, and the scatter constant — loaded once from config/quiz/archetypes.yml.
    # The archetype COPY (label/sentence) is NOT here: it lives in the locale files
    # (config/locales/*.yml -> content.archetypes) and is assembled into ARCHETYPES
    # below, so English and every translation share one lattice and can't drift.
    MODEL = YAML.safe_load_file(File.expand_path("../../../config/quiz/archetypes.yml", __dir__)).freeze

    # Per-axis level values. Percentiles of the raw user-vector distribution:
    # "low" = p20, "mid" = p50, "high" = p80. RECALIBRATE from real responses
    # once you have them, and again whenever the question set changes — these
    # were derived from simulated answers and Ethics in particular will move.
    #
    # PROVISIONAL: only Ethics has an empirically derived "mid". The Vibe, Play
    # and Fanbase mids are the midpoint of their own low/high, adopted when the
    # axes went from two levels to three. They are placeholders for a real p50
    # and should be replaced in the same pass that recalibrates the rest.
    LEVELS = MODEL.fetch("levels").each_value(&:freeze).freeze

    LEVEL_ORDER = %w[low mid high].freeze
    CODE_LEVEL = { "L" => "low", "M" => "mid", "H" => "high" }.freeze
    LEVEL_CODE = CODE_LEVEL.invert.freeze

    # The 81 cells, in V-P-E-F order, mapped to the archetype that owns them. The
    # mapping lives in config/quiz/archetypes.yml (transcribed from the "Full cell
    # -> archetype mapping" table in db/seed-data/football-fan-archetypes-final-v2.md).
    # Several cells share an archetype by design (e.g. :student_of_the_game owns
    # all nine H-*-*-L cells: if the badge is incidental to you, the rest of the
    # answers stop mattering). The file's order is preserved — nearest-cell ties
    # keep it — and the values are symbolised to match the archetype ids.
    CELLS = MODEL.fetch("cells").transform_values(&:to_sym).freeze

    # The 18 archetypes, English canonical. The copy now lives in the locale files
    # (config/locales/en.yml -> content.archetypes, with translations in fr.yml);
    # this assembles the English rows as a symbol-keyed table so the rest of the
    # module — and client_table — can overlay a locale over it. Order follows
    # en.yml, which follows the source doc.
    ARCHETYPES = Translations.content(Translations::DEFAULT).fetch("archetypes")
                             .except("all_mid")
                             .to_h { |id, row| [id.to_sym, { "label" => row["label"], "sentence" => row["sentence"] }.freeze] }
                             .freeze

    # Fallback when a vector can't be scored at all (nil / wrong arity). Not one
    # of the 18 — no valid vector reaches it. Its copy is content.archetypes.all_mid.
    ALL_MID = Translations.content(Translations::DEFAULT).fetch("archetypes").fetch("all_mid").freeze
    ALL_MID_LABEL = ALL_MID.fetch("label")
    ALL_MID_SENTENCE = ALL_MID.fetch("sentence")

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
    # The value lives in config/quiz/archetypes.yml alongside the lattice it tunes.
    SCATTER = MODEL.fetch("scatter")

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
    def call(vec, weights: nil, locale: Translations::DEFAULT)
      overrides = Translations.content(locale)["archetypes"] || {}
      code = code_for(vec, weights:)
      return localized_row(:all_mid, ALL_MID_LABEL, ALL_MID_SENTENCE, overrides) if code.nil?

      id = CELLS.fetch(code)
      row = ARCHETYPES.fetch(id)
      localized_row(id, row["label"], row["sentence"], overrides)
    end

    # Merge a translation override (if any) over the canonical English label and
    # sentence. `key` is the archetype id (or :all_mid for the fallback row).
    def localized_row(key, label, sentence, overrides)
      override = overrides[key.to_s] || {}
      { label: override["label"] || label, sentence: override["sentence"] || sentence }
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
    # scatter has one definition rather than two that can drift. `locale` swaps in
    # the translated labels/sentences (numeric levels/cells/scatter are unchanged,
    # so client and server still build identical centroids).
    def client_table(locale = Translations::DEFAULT)
      overrides = Translations.content(locale)["archetypes"] || {}
      all_mid = overrides["all_mid"] || {}
      {
        "levels" => LEVELS,
        "cells" => CELLS,
        "archetypes" => localized_archetypes(overrides),
        "scatter" => SCATTER,
        "allMidLabel" => all_mid["label"] || ALL_MID_LABEL,
        "allMidSentence" => all_mid["sentence"] || ALL_MID_SENTENCE
      }
    end

    # The ARCHETYPES table with each row's label/sentence overlaid by the locale's
    # translation where present (numeric model is not part of this table).
    def localized_archetypes(overrides)
      ARCHETYPES.to_h do |id, row|
        [id, row.merge((overrides[id.to_s] || {}).slice("label", "sentence").compact)]
      end
    end
  end
end
