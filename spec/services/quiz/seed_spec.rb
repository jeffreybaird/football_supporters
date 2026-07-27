# frozen_string_literal: true

require "spec_helper"
require "csv"

RSpec.describe Quiz::Seed do
  # The suite seeds once in spec_helper; these assert the outcome and idempotency.
  it "creates the Premier League and its twenty clubs" do
    league = League.first(slug: "premier-league")

    expect(league).not_to be_nil
    expect(league.name).to eq("Premier League")
    expect(league.season).to eq("2026-27")
    expect(league.teams_dataset.count).to eq(20)
  end

  it "seeds each club's scores, blurb, and crest" do
    everton = Team.first(league_id: League.first(slug: "premier-league").id, name: "Everton")

    expect(everton.vector).to eq([4.1, 2.0, 5.0, 8.0])
    expect(everton.crest).to eq("premier-league/8668-Everton.png")
    expect(everton.blurb).to start_with("The People's Club")
  end

  it "creates the Bundesliga and its eighteen clubs behind the default league" do
    league = League.first(slug: "bundesliga")

    expect(league).not_to be_nil
    expect(league.name).to eq("Bundesliga")
    expect(league.teams_dataset.count).to eq(18)
    expect(league.position).to eq(1)
    expect(League.default.slug).to eq("premier-league")
  end

  it "seeds Bundesliga scores from the CSV, with a crest and blurb" do
    union = Team.first(league_id: League.first(slug: "bundesliga").id, name: "Union Berlin")

    expect(union.vector).to eq([2.0, 2.0, 10.0, 10.0])
    expect(union.crest).to eq("bundesliga/8149-Union_Berlin.png")
    expect(union.blurb).not_to be_empty
  end

  it "creates Ligue 1 with its eighteen clubs and per-league scoring tuning" do
    league = League.first(slug: "ligue-1")

    expect(league).not_to be_nil
    expect(league.name).to eq("Ligue 1")
    expect(league.teams_dataset.count).to eq(18)
    expect(league.amplify).to eq(1.7)
    expect(league.chooser_threshold).to eq(0.25)
  end

  it "seeds Ligue 1 scores, crest, and blurb from the CSV" do
    psg = Team.first(league_id: League.first(slug: "ligue-1").id, name: "Paris Saint-Germain")

    expect(psg.vector).to eq([10.0, 7.0, 0.0, 4.0])
    expect(psg.crest).to eq("ligue-1/9847-PSG.png")
    expect(psg.blurb).to start_with("For a decade PSG")
  end

  it "creates MLS with its thirty clubs and per-league scoring tuning" do
    league = League.first(slug: "mls")

    expect(league).not_to be_nil
    expect(league.name).to eq("MLS")
    expect(league.teams_dataset.count).to eq(30)
    expect(league.amplify).to eq(1.8)
    expect(league.chooser_threshold).to eq(0.20)
  end

  it "seeds MLS scores, a league-scoped crest, and a blurb" do
    miami = Team.first(league_id: League.first(slug: "mls").id, name: "Inter Miami")

    expect(miami.vector).to eq([10.0, 10.0, 3.0, 5.0])
    expect(miami.crest).to eq("mls/960720-Inter_Miami_CF.png")
    expect(miami.blurb).to start_with("The Messi circus")
  end

  it "creates NWSL with its sixteen clubs and per-league scoring tuning" do
    league = League.first(slug: "nwsl")

    expect(league).not_to be_nil
    expect(league.name).to eq("NWSL")
    expect(league.teams_dataset.count).to eq(16)
    expect(league.amplify).to eq(2.5)
    expect(league.chooser_threshold).to eq(0.25)
  end

  it "seeds NWSL scores, a league-scoped crest, and a blurb" do
    angel = Team.first(league_id: League.first(slug: "nwsl").id, name: "Angel City FC")

    expect(angel.vector).to eq([10.0, 6.0, 6.0, 8.0])
    expect(angel.crest).to eq("nwsl/1335914-Angel_City_FC.png")
    expect(angel.blurb).to start_with("Founded by Natalie Portman")
  end

  it "creates La Liga with its twenty clubs behind the earlier leagues" do
    league = League.first(slug: "la-liga")

    expect(league).not_to be_nil
    expect(league.name).to eq("La Liga")
    expect(league.season).to eq("2026-27")
    expect(league.teams_dataset.count).to eq(20)
    expect(league.amplify).to eq(1.6)
    expect(league.position).to eq(5)
  end

  it "seeds La Liga scores from the CSV, with a league-scoped crest and blurb" do
    madrid = Team.first(league_id: League.first(slug: "la-liga").id, name: "Real Madrid")

    expect(madrid.vector).to eq([10.0, 6.0, 5.0, 6.0])
    expect(madrid.crest).to eq("la-liga/8633-Real Madrid.png")
    expect(madrid.blurb).to start_with("The most successful club on earth")
  end

  it "creates Serie A with its twenty clubs behind the earlier leagues" do
    league = League.first(slug: "serie-a")

    expect(league).not_to be_nil
    expect(league.name).to eq("Serie A")
    expect(league.season).to eq("2026-27")
    expect(league.teams_dataset.count).to eq(20)
    # Tuned values, per db/seed-data/league_tunings.csv.
    expect(league.amplify).to eq(1.4)
    expect(league.chooser_threshold).to eq(0.20)
    expect(league.position).to eq(6)
  end

  it "seeds Serie A scores from the CSV, with a league-scoped crest and blurb" do
    inter = Team.first(league_id: League.first(slug: "serie-a").id, name: "Inter")

    expect(inter.vector).to eq([9.0, 6.0, 2.0, 7.0])
    expect(inter.crest).to eq("serie-a/8636-Inter.png")
    expect(inter.blurb).to start_with("Reigning champions, twenty-one titles")
  end

  # The clubs were transcribed from db/seed-data/serie-a/blurbs.md, so pin the
  # seeded blurbs to it — editing one without the other fails here.
  it "seeds every Serie A blurb verbatim from serie-a/blurbs.md" do
    doc = File.read("db/seed-data/serie-a/blurbs.md")
              .scan(/^\*\*(.+?)\*\*\n(.+?)(?=\n\n\*\*|\z)/m)
              .to_h { |name, text| [name.strip, text.strip] }
    teams = League.first(slug: "serie-a").teams_dataset.all

    expect(doc.size).to eq(20)
    expect(teams.map(&:name)).to match_array(doc.keys)
    teams.each { |team| expect(team.blurb).to eq(doc[team.name]), "blurb drift for #{team.name}" }
  end

  it "creates Liga MX with its eighteen clubs behind the earlier leagues" do
    league = League.first(slug: "liga-mx")

    expect(league).not_to be_nil
    expect(league.name).to eq("Liga MX")
    expect(league.season).to eq("Apertura 2026")
    expect(league.teams_dataset.count).to eq(18)
    # Tuned values, per db/seed-data/league_tunings.csv.
    expect(league.amplify).to eq(2.1)
    expect(league.chooser_threshold).to eq(0.23)
    expect(league.position).to eq(7)
  end

  it "seeds Liga MX scores from the CSV, with a league-scoped crest and blurb" do
    america = Team.first(league_id: League.first(slug: "liga-mx").id, name: "América")

    expect(america.vector).to eq([10.0, 7.0, 2.0, 8.0])
    expect(america.crest).to eq("liga-mx/6576-CF America.png")
    expect(america.blurb).to start_with('"Ódiame más." Hate me more.')
  end

  it "creates the WSL with its fourteen clubs behind the earlier leagues" do
    league = League.first(slug: "wsl")

    expect(league).not_to be_nil
    expect(league.name).to eq("WSL")
    expect(league.season).to eq("2026-27")
    expect(league.teams_dataset.count).to eq(14)
    # Tuned values, per db/seed-data/league_tunings.csv.
    expect(league.amplify).to eq(1.1)
    expect(league.chooser_threshold).to eq(0.20)
    expect(league.position).to eq(8)
  end

  it "seeds WSL scores from the CSV, with a league-scoped crest and blurb" do
    arsenal = Team.first(league_id: League.first(slug: "wsl").id, name: "Arsenal")

    expect(arsenal.vector).to eq([9.0, 4.0, 8.0, 9.0])
    expect(arsenal.crest).to eq("wsl/258657-Arsenal.png")
    expect(arsenal.blurb).to start_with("Arsenal beat Barcelona 1-0 in Lisbon")
  end

  # The WSL shares club names with the Premier League (Arsenal, Everton, ...).
  # They are separate rows scoped to their own league, with their own scores.
  it "keeps the WSL clubs distinct from their Premier League namesakes" do
    wsl = Team.first(league_id: League.first(slug: "wsl").id, name: "Everton")
    epl = Team.first(league_id: League.first(slug: "premier-league").id, name: "Everton")

    expect(wsl.id).not_to eq(epl.id)
    expect(wsl.vector).to eq([4.0, 4.0, 9.0, 7.0])
    expect(epl.vector).to eq([4.1, 2.0, 5.0, 8.0])
  end

  # Liga MX and WSL clubs were transcribed from their blurbs.md, so pin the
  # seeded blurbs to those files — editing one without the other fails here.
  # A handful of clubs are seeded under a shorter name than the document's
  # heading (the CSV's name wins), so map those explicitly.
  {
    "liga-mx" => [18, { "Club América" => "América", "Guadalajara (Chivas)" => "Guadalajara",
                        "Tijuana (Xolos)" => "Tijuana" }],
    "wsl" => [14, { "Manchester City" => "Man City", "Manchester United" => "Man United",
                    "Tottenham Hotspur" => "Tottenham", "Brighton & Hove Albion" => "Brighton",
                    "West Ham United" => "West Ham", "Charlton Athletic" => "Charlton" }]
  }.each do |slug, (count, aliases)|
    it "seeds every #{slug} blurb verbatim from #{slug}/blurbs.md" do
      doc = File.read("db/seed-data/#{slug}/blurbs.md")
                .scan(/^### (.+?)\n(.+?)(?=\n\n### |\n*\z)/m)
                .to_h { |name, text| [aliases.fetch(name.strip, name.strip), text.strip] }
      teams = League.first(slug:).teams_dataset.all

      expect(doc.size).to eq(count)
      expect(teams.map(&:name)).to match_array(doc.keys)
      teams.each { |team| expect(team.blurb).to eq(doc[team.name]), "blurb drift for #{team.name}" }
    end
  end

  # db/seed-data/league_tunings.csv is where amplify / chooser_threshold /
  # max_choices are derived; Seed::LEAGUES is what actually ships. Pin every
  # league to the CSV so a retuned value can't be left out of the seed (which is
  # exactly how Bundesliga's chooser_threshold drifted to the default).
  describe "parity with db/seed-data/league_tunings.csv" do
    let(:slugs) do
      { "EPL" => "premier-league", "BUNDESLIGA" => "bundesliga", "LIGUE1" => "ligue-1",
        "MLS" => "mls", "NWSL" => "nwsl", "LALIGA" => "la-liga", "SERIEA" => "serie-a",
        "LIGAMX" => "liga-mx", "WSL" => "wsl" }
    end
    let(:tunings) { CSV.read("db/seed-data/league_tunings.csv", headers: true) }

    it "covers every seeded league exactly once" do
      expect(tunings.map { |r| slugs.fetch(r["league"]) }).to match_array(League.all.map(&:slug))
    end

    it "seeds the tuned amplify, chooser_threshold and max_choices for every league" do
      tunings.each do |row|
        league = League.first(slug: slugs.fetch(row["league"]))
        expect(league.amplify).to eq(row["amplify"].to_f), "amplify drift for #{league.slug}"
        expect(league.chooser_threshold).to eq(row["chooser_threshold"].to_f),
                                            "chooser_threshold drift for #{league.slug}"
        expect(league.max_choices).to eq(row["max_choices"].to_i), "max_choices drift for #{league.slug}"
      end
    end
  end

  it "honours each league's per-league amplify override" do
    expect(League.first(slug: "bundesliga").amplify).to eq(1.4)
    expect(League.first(slug: "premier-league").amplify).to eq(2.5)
  end

  # A crest is optional (the badge falls back to initials), but any crest that IS
  # set must resolve to a real file — a typo'd filename should fail the suite.
  it "points every seeded crest at a file that exists on disk" do
    Team.exclude(crest: nil).each do |team|
      expect(File.exist?(File.join("public/images", team.crest))).to be(true), "missing #{team.crest}"
    end
  end

  it "is idempotent — re-running adds no rows" do
    expect { described_class.call }.not_to(change { [League.count, Team.count] })
  end

  it "upserts changed data back to the seed values" do
    everton = Team.first(league_id: League.first(slug: "premier-league").id, name: "Everton")
    everton.update(blurb: "tampered")

    described_class.call

    expect(everton.refresh.blurb).to start_with("The People's Club")
    expect(Team.where(league_id: League.first(slug: "premier-league").id, name: "Everton").count).to eq(1)
  end
end
