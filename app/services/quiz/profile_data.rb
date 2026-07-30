# frozen_string_literal: true

module Quiz
  # The browser payload for a cross-league Football Profile (window PROFILE_DATA,
  # fetched from GET /leagues when the user picks "Football Profile"). Reuses
  # Quiz::ClientData per league so a league's shape can't diverge from the
  # single-league quiz, then hoists the league-agnostic keys once and adds the
  # archetype table so the client can label the result identically to the server.
  module ProfileData
    module_function

    # Keys that are identical for every league (see Quiz::ClientData) — carried
    # once at the top level instead of repeated in each league entry.
    SHARED_KEYS = %w[AXES Q SLIDERS].freeze

    def call(leagues: League.active.ordered.all, locale: Translations::DEFAULT)
      # Skip leagues with no teams — an empty team cloud has no centroid to score
      # against (see Quiz::Score#centroid_of).
      scorable = leagues.select { |league| league.scored_teams.any? }
      {
        "AXES" => Data::AXES,
        "Q" => Data.questions(locale),
        "SLIDERS" => Data.sliders(locale),
        "ARCHETYPE" => Archetype.client_table(locale),
        "LEAGUES" => scorable.map { |league| ClientData.call(league, locale:).except(*SHARED_KEYS) }
      }
    end
  end
end
