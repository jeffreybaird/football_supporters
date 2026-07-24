# frozen_string_literal: true

module Quiz
  # Turns a user's 4-axis vector (Quiz::Data::AXES: Vibe, Play, Ethics, Fanbase)
  # into an abstract "kind of team you want" — a short archetype label plus a
  # descriptive sentence. Deliberately data-first: the bands/labels/fragments
  # table is shipped to the browser (Quiz::ProfileData -> window ARCHETYPE) so the
  # live client and this server run the SAME selection over the SAME table and
  # can't drift (same discipline as the shared scorer, see Quiz::Score). Keep the
  # JS `archetypeFor` in views/quiz/index.erb a literal transcription of #call.
  module Archetype
    module_function

    # A band per axis value: value <= low => "low"; value >= high => "high"; else
    # "mid". Midpoint of the 0..10 scale is 5.0 (neutral).
    BANDS = { "low" => 3.5, "high" => 6.5 }.freeze

    # Archetype label per axis and direction. High Fanbase means strong belonging
    # (see Quiz::Data Q F4/F5), so high => "The Ultra", low => "The Neutral".
    LABELS = {
      "Vibe"    => { "low" => "The Romantic",   "high" => "The Glory-Hunter" },
      "Play"    => { "low" => "The Purist",     "high" => "The Thrill-Seeker" },
      "Ethics"  => { "low" => "The Separatist", "high" => "The Idealist" },
      "Fanbase" => { "low" => "The Neutral",    "high" => "The Ultra" },
    }.freeze

    # Sentence fragment describing what the user wants on each axis/direction.
    FRAGMENTS = {
      "Vibe"    => { "low"  => "you'd rather back a smaller, unfashionable side than a giant",
                     "high" => "you're drawn to big-club status and the bright lights" },
      "Play"    => { "low"  => "you value control and a hard-earned, gritty result",
                     "high" => "you want football that attacks and entertains" },
      "Ethics"  => { "low"  => "you keep sport and politics well apart",
                     "high" => "how a club is owned and run matters deeply to you" },
      "Fanbase" => { "low"  => "you'd sooner follow from a calm distance than join the crowd",
                     "high" => "you want to belong to a loud, tight-knit crowd" },
    }.freeze

    ALL_MID_LABEL = "The All-Rounder"
    ALL_MID_SENTENCE =
      "This is the kind of team you want: no single thing dominates — " \
      "you'll take a good club in almost any shape."

    # vec: Array(4) aligned to Quiz::Data::AXES (the raw user vector from
    # Score#score_axes — not amplified). Returns { label:, sentence: }.
    def call(vec)
      axes = Data::AXES
      # Axes strongest-signal first (furthest from the neutral 5.0); ties resolved
      # by axis order for determinism.
      ordered = axes.each_index.sort_by { |k| [-(vec[k] - 5.0).abs, k] }
      dom = ordered.first
      label = band(vec[dom]) == "mid" ? ALL_MID_LABEL : LABELS[axes[dom]][band(vec[dom])]

      strong = ordered.select { |k| band(vec[k]) != "mid" }.first(2)
      sentence =
        if strong.empty?
          ALL_MID_SENTENCE
        else
          frags = strong.map { |k| FRAGMENTS[axes[k]][band(vec[k])] }
          "This is the kind of team you want: #{frags.join(', and ')}."
        end

      { label:, sentence: }
    end

    def band(value)
      return "low"  if value <= BANDS["low"]
      return "high" if value >= BANDS["high"]

      "mid"
    end

    # The table shipped to the browser so its archetypeFor matches #call exactly.
    def client_table
      {
        "bands"          => BANDS,
        "labels"         => LABELS,
        "fragments"      => FRAGMENTS,
        "allMidLabel"    => ALL_MID_LABEL,
        "allMidSentence" => ALL_MID_SENTENCE,
      }
    end
  end
end
