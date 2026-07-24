# frozen_string_literal: true

module Quiz
  # Assembles the JSON payload the browser quiz consumes (window.QUIZ_DATA) from a
  # league's DB teams plus the shared questionnaire. Keeping the shape identical to
  # what the client scorer expects means the browser and the server score against
  # the very same data and can't drift.
  module ClientData
    module_function

    def call(league)
      teams = league ? league.scored_teams : []
      {
        "LEAGUE"            => league && { "slug" => league.slug, "name" => league.name },
        "AXES"              => Data::AXES,
        "TEAMS"             => teams.to_h { |t| [t.name, t.vector] },
        "Q"                 => Data::Q,
        "SLIDERS"           => Data::SLIDERS,
        "FLAVOR"            => teams.to_h { |t| [t.name, t.blurb] },
        "BADGE"             => teams.reject { |t| t.crest.nil? }.to_h { |t| [t.name, t.crest] },
        "CHOOSER_THRESHOLD" => league ? league.chooser_threshold : Data::CHOOSER_THRESHOLD,
        "MAX_CHOICES"       => league ? league.max_choices : Data::MAX_CHOICES,
        "AMPLIFY"           => league ? league.amplify : Data::AMPLIFY,
      }
    end
  end
end
