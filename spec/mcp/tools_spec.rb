# frozen_string_literal: true

require "spec_helper"
require_relative "../../app/mcp"

RSpec.describe MCP::Tools do
  let(:league) { League.default }

  it "score_supporter recommends the best-fitting club and ranks monotonically by match %" do
    vec = [7.0, 8.0, 6.0, 5.0]
    view = described_class.score_supporter("vector" => vec, "league" => league.slug)
    best = Quiz::Score.rank_vector(vec:, teams: league.scored_teams, weights: [5, 5, 5, 5], **league.scoring_params)
                      .rank.max_by(&:match)
    expect(view["pick"]["name"]).to eq(best.name)
    pcts = view["ranking"].map { |row| row["match_pct"] }
    expect(pcts).to eq(pcts.sort.reverse)
  end

  it "score_supporter's pick is the top of its own ranking (answers input)" do
    view = described_class.score_supporter("answers" => Array.new(13, 0), "league" => league.slug)
    expect(view["pick"]["name"]).to eq(view["ranking"].first["club"])
  end

  it "explain_match reports the same match % as score_supporter for the same club" do
    vec = [7, 8, 6, 5]
    view = described_class.score_supporter("vector" => vec, "league" => league.slug)
    detail = described_class.explain_match("vector" => vec, "league" => league.slug, "team" => view["pick"]["name"])
    expect(detail["match_pct"]).to eq(view["pick"]["match_pct"])
  end

  it "list_teams reports each club's banded attribute vector" do
    clubs = described_class.list_teams("league" => league.slug)
    expect(clubs.first["attributes"].keys).to eq(Quiz::Data::AXES)
    expect(clubs.first["attributes"]["Vibe"]).to include("score", "band")
  end

  it "build_profile returns an archetype and a pick per league" do
    profile = described_class.build_profile("vector" => [7, 5, 4, 6])
    expect(profile["archetype"]).to include(:label, :sentence)
    expect(profile["clubs_by_league"]).to all(include("league", "pick", "match_pct"))
  end

  it "explain_match breaks the match down by axis" do
    club = league.scored_teams.first.name
    result = described_class.explain_match("vector" => [7, 8, 6, 5], "league" => league.slug, "team" => club)
    expect(result["per_axis"].map { |row| row["axis"] }).to eq(Quiz::Data::AXES)
    expect(result).to include("match_pct")
  end

  it "raises a ToolError for an unknown club" do
    expect { described_class.explain_match("vector" => [5, 5, 5, 5], "league" => league.slug, "team" => "Nope FC") }
      .to raise_error(MCP::ToolError)
  end

  it "raises a ToolError when neither vector nor answers is given" do
    expect { described_class.score_supporter("league" => league.slug) }.to raise_error(MCP::ToolError)
  end
end
