# frozen_string_literal: true

module Quiz
  # Turns a user's 4-axis vector (Quiz::Data::AXES: Vibe, Play, Ethics, Fanbase)
  # into an abstract "kind of club you want" — a short archetype label plus a
  # descriptive sentence.
  #
  # Archetypes are POINTS IN THE SAME 4-D SPACE AS THE CLUBS, and selection is
  # nearest-centroid — the same operation Quiz::Score performs against teams,
  # one level coarser. This replaces the old band/dominant-axis scheme, which
  # threw away three of the four axes when choosing a label.
  #
  # The grid is 2 x 2 x 3 x 2 = 24: two levels on Vibe, Play and Fanbase, three
  # on Ethics, because Ethics has roughly twice the spread of the other axes in
  # the observed user distribution (sd ~2.5 vs ~1.2) and so earns the extra
  # resolution. Level values are percentiles of that distribution (p20/p50/p80),
  # NOT of the club distribution — an archetype describes the person, not the
  # club they end up with. A club can legitimately straddle several archetypes.
  #
  # Deliberately data-first: the table is shipped to the browser
  # (Quiz::ProfileData -> window ARCHETYPE) so the live client and this server
  # run the SAME selection over the SAME table and can't drift. Keep the JS
  # `archetypeFor` in views/quiz/index.erb a literal transcription of #call.
  module Archetype
    module_function

    # Per-axis level values. Percentiles of the raw user-vector distribution:
    # "low" = p20, "mid" = p50, "high" = p80. RECALIBRATE from real responses
    # once you have them, and again whenever the question set changes — these
    # were derived from simulated answers and Ethics in particular will move.
    LEVELS = {
      "Vibe" => { "low" => 4.14, "high" => 6.33 },
      "Play" => { "low" => 5.00, "high" => 7.14 },
      "Ethics" => { "low" => 2.00, "mid" => 4.12, "high" => 6.24 },
      "Fanbase" => { "low" => 4.07, "high" => 6.14 }
    }.freeze

    # Codes read V-P-E-F. Vibe/Play/Fanbase are H or L; Ethics is H, M or L.
    # "vec" is aligned to Quiz::Data::AXES.
    ARCHETYPES = {
      "HHHH" => { "vec" => [6.33, 7.14, 6.24, 6.14],
                  "label" => "The Dreamer",
                  "sentence" => "You want a club that feels like it matters, one that fills the stands and the city with energy. It should be run by people who care about doing things the right way, and it should never be afraid to put on a show. For you, a club can be all of these things at once—and you're holding out for the one that proves it." },
      "HHHL" => { "vec" => [6.33, 7.14, 6.24, 4.07],
                  "label" => "The Connoisseur",
                  "sentence" => "You savor football that's played with style and care, by a club that knows how to hold its head high. You watch for the small moments—the clever pass, the perfect touch—and you want the room to appreciate every bit of it." },
      "HLHH" => { "vec" => [6.33, 5.00, 6.24, 6.14],
                  "label" => "The Traditionalist",
                  "sentence" => "You care about the stories that came before—the old photos on the clubhouse wall, the families who've cheered from the same seats for decades. You want a club that stands for something and finds a way to win without losing itself." },
      "HLHL" => { "vec" => [6.33, 5.00, 6.24, 4.07],
                  "label" => "The Perfectionist",
                  "sentence" => "You look for a club that's steady and ambitious, the kind that's built to last through good years and bad. Winning is sweeter when it comes from hard work and doing things the right way." },
      "LHHH" => { "vec" => [4.14, 7.14, 6.24, 6.14],
                  "label" => "The Romantic",
                  "sentence" => "You find yourself rooting for the smaller club that plays with heart and never cuts corners. What matters most is seeing how much it means to the people in the stands, week after week." },
      "LHHL" => { "vec" => [4.14, 7.14, 6.24, 4.07],
                  "label" => "The Aficionado",
                  "sentence" => "You can't help but cheer for the clever clubs that find a way to surprise everyone. There's something satisfying about watching a smart plan come together, especially when no one saw it coming." },
      "LLHH" => { "vec" => [4.14, 5.00, 6.24, 6.14],
                  "label" => "The Communitarian",
                  "sentence" => "You want a club that feels like home, where the fans have a real say and stick together through thick and thin. For you, it's the community that makes it all matter." },
      "LLHL" => { "vec" => [4.14, 5.00, 6.24, 4.07],
                  "label" => "The Quiet Conscience",
                  "sentence" => "You're after a club you can stand behind, one that's honest and doesn't put on airs. You like to watch the game your own way, without fuss." },
      "HHMH" => { "vec" => [6.33, 7.14, 4.12, 6.14],
                  "label" => "The True Believer",
                  "sentence" => "You want the roar of a packed stadium, a team that keeps you on the edge of your seat, and fans who feel every win and loss. When you pick a side, you're all in." },
      "HHML" => { "vec" => [6.33, 7.14, 4.12, 4.07],
                  "label" => "The Showman",
                  "sentence" => "You show up for the biggest stage and the brightest lights. You want to be dazzled, and you expect your club to chase greatness every time out." },
      "HLMH" => { "vec" => [6.33, 5.00, 4.12, 6.14],
                  "label" => "The Institution",
                  "sentence" => "You're drawn to clubs with deep roots—a packed ground, a team that knows how to win, and a history you can feel when you walk through the gates. You want something solid you can count on." },
      "HLML" => { "vec" => [6.33, 5.00, 4.12, 4.07],
                  "label" => "The Pragmatist",
                  "sentence" => "You want a club that means business, one that's run with care and knows how to get results. For you, it's about what's real, not just what looks good." },
      "LHMH" => { "vec" => [4.14, 7.14, 4.12, 6.14],
                  "label" => "The Firebrand",
                  "sentence" => "You find yourself pulled toward the smaller clubs where every match feels like a fight and the crowd is right on top of the action. It's the intensity that keeps you coming back." },
      "LHML" => { "vec" => [4.14, 7.14, 4.12, 4.07],
                  "label" => "The Enthusiast",
                  "sentence" => "You chase good football wherever it turns up. For you, it's all about what happens on the pitch—the rest is just background noise." },
      "LLMH" => { "vec" => [4.14, 5.00, 4.12, 6.14],
                  "label" => "The Regular",
                  "sentence" => "You want a club that feels like a second home—a small ground, your usual seat, and the same neighbors in the stands every Saturday. It's the comfort of the familiar that keeps you coming back." },
      "LLML" => { "vec" => [4.14, 5.00, 4.12, 4.07],
                  "label" => "The Easygoer",
                  "sentence" => "You want a club that fits into your life, something you look forward to without it taking over everything. Football is one of the things that makes your week better." },
      "HHLH" => { "vec" => [6.33, 7.14, 2.00, 6.14],
                  "label" => "The Ultra",
                  "sentence" => "You want a club that feels larger than life—a wild team, a crowd that never stops moving. For you, it's all about the energy inside the ground." },
      "HHLL" => { "vec" => [6.33, 7.14, 2.00, 4.07],
                  "label" => "The Headliner",
                  "sentence" => "You're here for the main event—the biggest show, the best football, the kind of spectacle you'll remember long after the final whistle." },
      "HLLH" => { "vec" => [6.33, 5.00, 2.00, 6.14],
                  "label" => "The Empire Loyalist",
                  "sentence" => "You want to be part of something massive, standing shoulder to shoulder with thousands of others who wear the same colors. The feeling of belonging to something bigger than yourself is what draws you in." },
      "HLLL" => { "vec" => [6.33, 5.00, 2.00, 4.07],
                  "label" => "The Winner",
                  "sentence" => "You want a club that's hungry for silverware—ambitious, relentless, and never satisfied with second place. For you, the trophies tell the story." },
      "LHLH" => { "vec" => [4.14, 7.14, 2.00, 6.14],
                  "label" => "The Loyalist",
                  "sentence" => "You back the smaller club with a big heart, the kind of team that never gives up. No matter the score, you'll be there in the away end, singing until the final whistle." },
      "LHLL" => { "vec" => [4.14, 7.14, 2.00, 4.07],
                  "label" => "The Thrill-Seeker",
                  "sentence" => "You want goals, drama, and a team that keeps you guessing. As long as the game is thrilling, you leave happy." },
      "LLLH" => { "vec" => [4.14, 5.00, 2.00, 6.14],
                  "label" => "The Diehard",
                  "sentence" => "You want a club you can stick with, no matter what. For you, loyalty is everything." },
      "LLLL" => { "vec" => [4.14, 5.00, 2.00, 4.07],
                  "label" => "The Stoic",
                  "sentence" => "You want football simple and true—a club, a match, a Saturday afternoon. You take it as it comes and enjoy every bit of it." }
    }.freeze

    # Fallback when a vector can't be scored at all (nil / wrong arity).
    ALL_MID_LABEL = "The All-Rounder"
    ALL_MID_SENTENCE =
      "This is the kind of club you want: no single thing dominates — " \
      "you'll take a good club in almost any shape."

    # vec: Array(4) aligned to Quiz::Data::AXES — the RAW user vector from
    # Score#score_axes, not the amplified one. Amplification exists to reach the
    # club space; the archetype describes the person as they actually answered.
    # Returns { label:, sentence: } (unchanged interface).
    def call(vec)
      code = code_for(vec)
      return { label: ALL_MID_LABEL, sentence: ALL_MID_SENTENCE } if code.nil?

      row = ARCHETYPES.fetch(code)
      { label: row["label"], sentence: row["sentence"] }
    end

    # Nearest archetype centroid by unweighted Euclidean distance. Unweighted on
    # purpose: the slider weights say what the person wants PRIORITISED in a
    # club, not who they are, so the archetype must not change when a slider
    # moves without an answer changing. Ties resolved by key order.
    def code_for(vec)
      return nil unless vec.is_a?(Array) && vec.length == 4 && vec.all?(Numeric)

      ARCHETYPES.min_by { |_code, row| sq_distance(vec, row["vec"]) }&.first
    end

    def sq_distance(vec_a, vec_b)
      (0...4).sum { |i| (vec_a[i] - vec_b[i])**2 }
    end

    # Backwards-compatible helper. The old signature took a bare value and used
    # global 3.5/6.5 thresholds; it is now axis-aware. Selection no longer uses
    # banding — this is retained only for callers outside this module.
    def band(value, axis = nil)
      levels = LEVELS[axis]
      return band_default(value) if levels.nil?

      return "low"  if value <= levels["low"]
      return "high" if value >= levels["high"]
      return "mid" if levels.key?("mid")

      value < levels["high"] ? "low" : "high"
    end

    def band_default(value)
      return "low" if value <= 3.5
      return "high" if value >= 6.5

      "mid"
    end

    # The table shipped to the browser so its archetypeFor matches #call exactly.
    def client_table
      {
        "levels" => LEVELS,
        "archetypes" => ARCHETYPES,
        "allMidLabel" => ALL_MID_LABEL,
        "allMidSentence" => ALL_MID_SENTENCE
      }
    end
  end
end
