# frozen_string_literal: true

module Quiz
  # Assembles the JSON payload the browser quiz consumes (window.QUIZ_DATA) from a
  # league's DB teams plus the shared questionnaire. Keeping the shape identical to
  # what the client scorer expects means the browser and the server score against
  # the very same data and can't drift.
  module ClientData
    module_function

    def call(league, locale: Translations::DEFAULT)
      teams = league ? league.scored_teams : []
      {
        "LEAGUE" => league && { "slug" => league.slug, "name" => league.name },
        "AXES" => Data::AXES,
        "TEAMS" => teams.to_h { |t| [t.name, t.vector] },
        "Q" => Data.questions(locale),
        "SLIDERS" => Data.sliders(locale),
        "FLAVOR" => teams.to_h { |t| [t.name, t.blurb] },
        "BADGE" => teams.reject { |t| t.crest.nil? }.to_h { |t| [t.name, t.crest] },
        "CHOOSER_THRESHOLD" => league ? league.chooser_threshold : Data::CHOOSER_THRESHOLD,
        "MAX_CHOICES" => league ? league.max_choices : Data::MAX_CHOICES,
        # Distribution-aligned scoring inputs (replaces AMPLIFY): per-team
        # popularity plus the global alpha and user distribution, so the browser
        # rebuilds the same target and standardisation the server uses.
        "POPULARITY" => teams.to_h { |t| [t.name, t.popularity] },
        "ALPHA" => Data::POPULARITY_ALPHA,
        "USER_MEAN" => Data::USER_MEAN,
        "USER_SD" => Data::USER_SD,
        "ARCHETYPE" => Archetype.client_table(locale)
      }
    end
  end
end
