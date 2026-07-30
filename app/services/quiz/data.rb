# frozen_string_literal: true

require "yaml"

module Quiz
  # The questionnaire and scoring model — league-agnostic. Team scores and blurbs
  # live in the database (the League/Team models); this holds the fixed bits
  # shared across every league: the four axes, the questions and their loadings,
  # the weight sliders, and the matching constants.
  #
  # 4-coordinate model per answer/team: [Vibe, Play, Ethics, Fanbase].
  #
  # The questionnaire is split by concern. The language-neutral SCORING skeleton
  # (per-question loadings and per-option values) is one YAML file per question
  # under config/quiz/questions/; the WORDING (question and slider text) lives in
  # the locale files (config/locales/*.yml -> content.questions / content.sliders).
  # `questions` / `sliders` merge a locale's wording onto the shared skeleton, so
  # English and every translation score against the very same numbers and can't
  # drift. Q / SLIDERS are the assembled English forms, kept as constants because
  # the scorer and answer validation index them by id/position.
  module Data
    AXES = %w[Vibe Play Ethics Fanbase].freeze

    # Default scoring tuning. Each league now carries its own values (columns on
    # the leagues table); these are the fallback used when no league is in play
    # and the seed's starting values, and they must match the migration defaults.
    #
    # CHOOSER_THRESHOLD: max weighted-distance gap from the winner for an
    # alternate to be offered. MAX_CHOICES: cap on offered alternates. AMPLIFY:
    # superseded — the scorer now aligns the user distribution to the club
    # distribution rather than stretching from the centroid (see below). The
    # constant and the leagues.amplify column are kept only so existing seed/DB
    # rows and their specs are undisturbed; nothing reads them for scoring.
    CHOOSER_THRESHOLD = 0.25
    MAX_CHOICES = 3
    AMPLIFY = 2.5

    # Distribution-aligned matching (replaces AMPLIFY). Instead of stretching the
    # user's raw vector outward from the team centroid, Quiz::Score standardises
    # each answered axis against the USER population and re-places it in a TARGET
    # distribution built from the league's teams, weighted by
    # popularity**POPULARITY_ALPHA:
    #
    #   u_k = target_mean_k + (vec_k - USER_MEAN_k) * (target_sd_k / USER_SD_k)
    #
    # This does two things AMPLIFY could not: it removes the systematic self-report
    # bias (people over-state ethics and belonging, under-state glory) by
    # recentring on the real user mean, and it matches each axis's spread instead
    # of applying one blunt multiplier. POPULARITY_ALPHA is the "how much do we
    # trust popularity" dial: 0 ignores it (pure coordinate fit), 1 trusts raw
    # popularity fully. 0.2 leans mostly on de-biasing with a light popularity
    # nudge. Shipped to the browser via Quiz::ClientData so the client scorer
    # rebuilds the SAME target and can't drift — keep views/quiz/index.erb in step.
    POPULARITY_ALPHA = 0.2

    # PROVISIONAL user-answer distribution per axis [Vibe, Play, Ethics, Fanbase]:
    # the reference the scorer standardises incoming answers against. These are
    # ESTIMATED from a modelled social-desirability response population, NOT
    # measured — Ethics (~7) and Fanbase (~6) sit well above the club means
    # because takers over-report caring and belonging. Recompute both from real
    # stored responses once enough accumulate; that is the single most impactful
    # calibration. Pinned into score_spec's reference outputs — retune together.
    USER_MEAN = [4.74, 6.06, 7.13, 6.16].freeze
    USER_SD   = [1.30, 1.21, 2.18, 1.09].freeze

    # The scoring skeleton: one file per question (id, loadings, per-option value
    # vectors, all in AXES order). Files are numbered so they load in the canonical
    # questionnaire order — the order stored answers and the client's answer array
    # are indexed against, so it must not change (pinned in data_spec).
    QUESTIONS_DIR = File.expand_path("../../../config/quiz/questions", __dir__)
    # Sorted explicitly by filename (the numeric prefix is the canonical order);
    # Dir.children is unordered, so the sort is load-bearing, not decorative.
    SKELETON = Dir.children(QUESTIONS_DIR).grep(/\.yml\z/).sort.map do |name|
      YAML.safe_load_file(File.join(QUESTIONS_DIR, name)).freeze
    end.freeze

    module_function

    # The questionnaire localized for `locale`: the shared numeric skeleton with
    # the locale's wording (question prompt + option labels) merged in, English
    # filling anything a translation omits. Returns the same shape the client
    # scorer and Quiz::Score consume, so neither can drift from the other.
    def questions(locale = Translations::DEFAULT)
      wording = question_wording(locale)
      SKELETON.map do |skeleton|
        text = wording.fetch(skeleton["id"])
        { "id" => skeleton["id"], "t" => text["t"], "load" => skeleton["load"],
          "a" => skeleton["options"].each_with_index.map { |values, i| { "l" => text["a"][i], "v" => values } } }
      end
    end

    # The weight sliders localized for `locale`. One slider per axis (in AXES
    # order); only the prompt/endpoint text is translated, the axis key is not.
    def sliders(locale = Translations::DEFAULT)
      wording = slider_wording(locale)
      AXES.map do |axis|
        text = wording.fetch(axis)
        { "ax" => axis, "q" => text["q"], "lo" => text["lo"], "hi" => text["hi"] }
      end
    end

    # Question / slider wording for a locale, English-filled so a translation may
    # omit a question (or a whole locale) and still render.
    def question_wording(locale)
      merge_wording(Translations.content(Translations::DEFAULT)["questions"],
                    Translations.content(locale)["questions"])
    end

    def slider_wording(locale)
      merge_wording(Translations.content(Translations::DEFAULT)["sliders"],
                    Translations.content(locale)["sliders"])
    end

    # Per-id shallow merge: a localized entry overrides English for that id (its
    # `t`/`a` or `q`/`lo`/`hi`); English fills any id the locale leaves out.
    def merge_wording(english, localized)
      (english || {}).merge(localized || {}) { |_id, en_text, loc_text| en_text.merge(loc_text) }
    end

    # The canonical English questionnaire, assembled once and frozen. Kept as
    # constants because Quiz::Score and answer validation index them by id, and
    # several specs assert the served payload equals them.
    Q = questions(Translations::DEFAULT).freeze
    SLIDERS = sliders(Translations::DEFAULT).freeze
  end
end
