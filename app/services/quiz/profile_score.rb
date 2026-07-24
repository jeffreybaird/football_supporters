# frozen_string_literal: true

module Quiz
  # Scores one answer set against every active league at once — the read-side of
  # a Football Profile. The user's axis vector is league-independent
  # (Score#score_axes), so it is computed once and reused; each league's winner is
  # then resolved by the existing per-league scorer. Used by GET /q/:slug for a
  # shared profile, mirroring how the browser scores in profile mode.
  module ProfileScore
    module_function

    Result = Struct.new(:vec, :archetype, :leagues, keyword_init: true)
    # league: League, pick: Team, sim: Float (0..1), match_pct: Integer (0..100).
    Entry = Struct.new(:league, :pick, :sim, :match_pct, keyword_init: true)

    def call(answers:, weights:, leagues: League.active.ordered.all)
      vec = Score.score_axes(answers)
      entries = leagues.filter_map do |league|
        teams = league.scored_teams
        next if teams.empty?

        top = Score.call(teams:, answers:, weights:, **league.scoring_params).rank.first
        # match_pct is the winner's RAW-distance closeness (1 - raw_dist/10), linear
        # across the space diameter — comparable across leagues and undistorted by
        # each league's amplify. sim (steep, amplify-based) still drives ranking.
        Entry.new(league:, pick: top.team, sim: top.sim, match_pct: (top.match * 100).round)
      end
      Result.new(vec:, archetype: Archetype.call(vec), leagues: entries)
    end
  end
end
