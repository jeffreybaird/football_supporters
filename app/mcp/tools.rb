# frozen_string_literal: true

require "json"

module MCP
  # The MCP tool surface, wired to the existing Quiz services (read-only). Tools
  # split by space: list_leagues / list_teams read attribute-space (what clubs
  # ARE); score_supporter / build_profile / explain_match read desire-space (what a
  # supporter WANTS) and bridge to clubs via Quiz::Score. Definitions are a
  # declarative table; every handler is a short method below.
  module Tools
    module_function

    EQUAL_WEIGHTS = [5, 5, 5, 5].freeze
    # Fit gap (on the 0..1 match scale) within which an alternative counts as a
    # near-tie with the pick — i.e. worth offering as "or maybe you're more…".
    CLOSE_MATCH = 0.03

    # ---- input-schema fragments (JSON Schema, shared across tools) --------------
    LEAGUE_PROP = { "type" => "string",
                    "description" => "League slug, e.g. \"premier-league\". Call list_leagues for valid slugs." }.freeze
    VECTOR_PROP = { "type" => "array", "items" => { "type" => "number" }, "minItems" => 4, "maxItems" => 4,
                    "description" => "YOUR inferred estimate of the supporter's position on each axis " \
                                     "[Vibe, Play, Ethics, Fanbase], each 0-10. Infer it from conversation — do NOT ask " \
                                     "the person for numbers or ratings. Estimate genuinely (the tool matches it directly " \
                                     "to club attributes; don't inflate or deflate). See the conversation-guide and " \
                                     "axis-codebook resources." }.freeze
    ANSWERS_PROP = { "type" => "array", "items" => { "type" => "integer" },
                     "description" => "Alternative to vector: the 13 quiz answers as option indices (0-3)." }.freeze
    WEIGHTS_PROP = { "type" => "array", "items" => { "type" => "number" }, "minItems" => 4, "maxItems" => 4,
                     "description" => "Optional slider importances [Vibe, Play, Ethics, Fanbase]; relative, default equal." }.freeze
    TEAM_PROP = { "type" => "string", "description" => "Club name exactly as returned by list_teams." }.freeze

    NO_ARGS = { "type" => "object", "properties" => {}, "additionalProperties" => false }.freeze
    LIST_TEAMS_SCHEMA = { "type" => "object", "properties" => { "league" => LEAGUE_PROP },
                          "required" => ["league"], "additionalProperties" => false }.freeze
    SCORE_SCHEMA = { "type" => "object", "additionalProperties" => false, "required" => ["league"],
                     "properties" => { "vector" => VECTOR_PROP, "answers" => ANSWERS_PROP,
                                       "weights" => WEIGHTS_PROP, "league" => LEAGUE_PROP } }.freeze
    PROFILE_SCHEMA = { "type" => "object", "additionalProperties" => false,
                       "properties" => { "vector" => VECTOR_PROP, "answers" => ANSWERS_PROP,
                                         "weights" => WEIGHTS_PROP } }.freeze
    EXPLAIN_SCHEMA = { "type" => "object", "additionalProperties" => false, "required" => %w[league team vector],
                       "properties" => { "vector" => VECTOR_PROP, "weights" => WEIGHTS_PROP,
                                         "league" => LEAGUE_PROP, "team" => TEAM_PROP } }.freeze

    def all
      [list_leagues_tool, list_teams_tool, score_supporter_tool, build_profile_tool, explain_match_tool]
    end

    # ---- tool definitions ------------------------------------------------------
    def list_leagues_tool
      Tool.new(name: "list_leagues", input_schema: NO_ARGS, handler: method(:list_leagues),
               description: "List the leagues whose clubs the quiz matches against (attribute-space). " \
                            "Returns slug, name, and club count.")
    end

    def list_teams_tool
      Tool.new(name: "list_teams", input_schema: LIST_TEAMS_SCHEMA, handler: method(:list_teams),
               description: "List a league's clubs with their ATTRIBUTE vector (banded), popularity, and blurb. " \
                            "This is what clubs ARE, not what a supporter wants.")
    end

    def score_supporter_tool
      Tool.new(name: "score_supporter", input_schema: SCORE_SCHEMA, handler: method(:score_supporter),
               description: "Recommend clubs for a supporter in one league. Infer the four axes yourself from natural " \
                            "conversation about what the person loves and can't stand in football — NEVER ask them to " \
                            "rate axes or give numbers; the axes are internal and they should never see them. Pass your " \
                            "inferred vector (or the 13 answers) and optional weights; returns the pick, close " \
                            "alternatives, the full ranking (highest match first), and their archetype. Read the " \
                            "conversation-guide and axis-codebook resources before your first call.")
    end

    def build_profile_tool
      Tool.new(name: "build_profile", input_schema: PROFILE_SCHEMA, handler: method(:build_profile),
               description: "Build a cross-league Football Profile: the supporter's archetype (what they WANT) plus " \
                            "their best-matching club in every league. Infer the four axes from conversation — never " \
                            "ask for numbers or ratings. Pass your inferred vector (or answers) and optional weights. " \
                            "Read the conversation-guide and axis-codebook resources first.")
    end

    def explain_match_tool
      Tool.new(name: "explain_match", input_schema: EXPLAIN_SCHEMA, handler: method(:explain_match),
               description: "Explain WHY a supporter vector matches a specific club: a per-axis breakdown of " \
                            "supporter vs club, the gap, the weight, and the overall match %.")
    end

    # ---- handlers --------------------------------------------------------------
    def list_leagues(_args)
      League.active.ordered.all.map do |league|
        { "slug" => league.slug, "name" => league.name, "club_count" => league.scored_teams.length }
      end
    end

    def list_teams(args)
      find_league!(args["league"]).scored_teams.map { |team| club_view(team) }
    end

    def score_supporter(args)
      league = find_league!(args["league"])
      vec = vector_from(args)
      weights = args["weights"] || EQUAL_WEIGHTS
      result = Quiz::Score.rank_vector(vec:, teams: league.scored_teams, weights:, **league.scoring_params)
      score_view(result, vec, weights)
    end

    def build_profile(args)
      vec = vector_from(args)
      weights = args["weights"] || EQUAL_WEIGHTS
      { "supporter_vector" => axis_view(vec),
        "archetype" => Quiz::Archetype.call(vec, weights:),
        "clubs_by_league" => profile_leagues(vec, weights) }
    end

    def explain_match(args)
      league = find_league!(args["league"])
      team = find_team!(league, args["team"])
      match_explanation(require_vector(args), team, normalized(args["weights"] || EQUAL_WEIGHTS))
    end

    # ---- views -----------------------------------------------------------------
    # Rank by raw weighted fit (Ranked#match) so the list is monotonic in the % it
    # shows and the pick is the genuinely closest club. The engine's aligned/
    # popularity-weighted ordering exists to de-bias human slider self-reports; an
    # LLM-inferred vector has no such bias, so direct fit is both correct and
    # consistent (and matches what explain_match reports).
    def score_view(result, vec, weights)
      ranked = result.rank.sort_by { |r| [-r.match, r.name] }
      { "supporter_vector" => axis_view(vec),
        "archetype" => Quiz::Archetype.call(vec, weights:),
        "pick" => club_match(ranked.first),
        "candidates" => close_alternatives(ranked).map { |r| club_match(r) },
        "ranking" => ranked.map { |r| { "club" => r.name, "match_pct" => pct(r.match) } } }
    end

    # Clubs within CLOSE_MATCH of the best fit (excluding the pick itself), capped
    # at three — the genuine "or maybe you're more…" near-ties.
    def close_alternatives(ranked)
      best = ranked.first.match
      ranked.drop(1).select { |r| (best - r.match) <= CLOSE_MATCH }.first(3)
    end

    def profile_leagues(vec, weights)
      League.active.ordered.all.filter_map do |league|
        teams = league.scored_teams
        next if teams.empty?

        top = Quiz::Score.rank_vector(vec:, teams:, weights:, **league.scoring_params).rank.max_by(&:match)
        { "league" => league.name, "slug" => league.slug, "pick" => top.name, "match_pct" => pct(top.match) }
      end
    end

    def match_explanation(vec, team, weights)
      contribs = axis_contributions(vec, team, weights)
      rows = Quiz::Data::AXES.each_index.map { |i| axis_row(i, vec, team, weights, contribs[i]) }
      { "club" => team.name, "league" => team.league.name,
        "match_pct" => raw_match_pct(contribs), "per_axis" => rows }
    end

    def axis_contributions(vec, team, weights)
      Quiz::Data::AXES.each_index.map { |i| weights[i] * ((vec[i].to_f - team.vector[i])**2) }
    end

    def raw_match_pct(contribs)
      pct(1.0 - (Math.sqrt(contribs.sum) / Quiz::Score::DIAMETER))
    end

    def axis_row(index, vec, team, weights, contribution)
      axis = Quiz::Data::AXES[index]
      user = vec[index].to_f
      club = team.vector[index]
      { "axis" => axis, "supporter" => user.round(2), "club" => club.round(2), "gap" => (club - user).round(2),
        "weight" => weights[index].round(3), "supporter_band" => Quiz::Archetype.band(user, axis),
        "club_band" => Quiz::Archetype.band(club, axis), "contribution" => contribution.round(4) }
    end

    def club_view(team)
      { "name" => team.name, "attributes" => axis_view(team.vector),
        "popularity" => team.popularity, "blurb" => team.blurb }
    end

    def club_match(ranked)
      { "name" => ranked.name, "match_pct" => pct(ranked.match),
        "attributes" => axis_view(ranked.team.vector), "blurb" => ranked.team.blurb }
    end

    def axis_view(vec)
      Quiz::Data::AXES.each_index.to_h do |i|
        axis = Quiz::Data::AXES[i]
        [axis, { "score" => vec[i].to_f.round(2), "band" => Quiz::Archetype.band(vec[i].to_f, axis) }]
      end
    end

    # ---- helpers ---------------------------------------------------------------
    def find_league!(slug)
      raise ToolError, "Missing 'league' slug. Call list_leagues for valid slugs." if slug.to_s.empty?

      league = League.active.where(slug:).first
      raise ToolError, "No active league '#{slug}'. Call list_leagues for valid slugs." unless league

      league
    end

    def find_team!(league, name)
      raise ToolError, "Missing 'team' name." if name.to_s.empty?

      team = league.scored_teams.find { |t| t.name.casecmp?(name) }
      raise ToolError, "No club named '#{name}' in #{league.name}. Call list_teams for that league." unless team

      team
    end

    def vector_from(args)
      return validated_vector(args["vector"]) if args["vector"]
      return Quiz::Score.score_axes(args["answers"]) if args["answers"]

      raise ToolError, "Provide either 'vector' (4 numbers, 0-10) or 'answers' (13 option indices)."
    end

    def require_vector(args)
      raise ToolError, "'vector' (4 numbers, 0-10) is required." unless args["vector"]

      validated_vector(args["vector"])
    end

    def validated_vector(vec)
      valid = vec.is_a?(Array) && vec.length == 4 && vec.all?(Numeric)
      raise ToolError, "'vector' must be 4 numbers in axis order [Vibe, Play, Ethics, Fanbase]." unless valid

      vec.map(&:to_f)
    end

    def normalized(weights)
      sum = weights.sum.to_f
      return [0.25, 0.25, 0.25, 0.25] unless sum.positive?

      weights.map { |w| w / sum }
    end

    def pct(match) = (match * 100).round
  end
end
