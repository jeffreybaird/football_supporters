# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::Archetype do
  # AXES order: [Vibe, Play, Ethics, Fanbase].
  def label(vec) = described_class.call(vec)[:label]
  def sentence(vec) = described_class.call(vec)[:sentence]

  # The 18 archetype labels as shipped in config/locales (six renamed from the
  # source doc db/seed-data/football-fan-archetypes-final-v2.md).
  let(:doc_labels) do
    ["The Light Brigade", "The Cavalier", "The Architect",
     "The Pragmatic Winner", "The Glory Hunter", "The Trophy Collector",
     "The Student of the Game", "The Romantic", "The Terrace Dreamer",
     "The Everyfan", "The Principled Fan", "The Matinee",
     "The Free Agent", "The Village Green", "The Hometown Diehard",
     "The Local Enthusiast", "The Family Day", "The Local Casual"]
  end

  # Weightings used to prove selection is robust (self-resolution) and live
  # (leader moves). Deliberately includes near-degenerate ones.
  let(:lopsided) do
    [[5, 5, 5, 5], [10, 1, 1, 10], [1, 10, 10, 1], [9, 3, 3, 3],
     [3, 3, 3, 9], [10, 1, 1, 1], [1, 1, 1, 10]]
  end

  it "returns The All-Rounder with the neutral sentence for a nil or malformed vector" do
    expect(label(nil)).to eq("The All-Rounder")
    expect(sentence(nil)).to eq(described_class::ALL_MID_SENTENCE)
    expect(label([1, 2, 3])).to eq("The All-Rounder")
  end

  def centroid(code) = described_class::CELL_VECS.fetch(code)

  describe "the cell table" do
    it "covers all 81 H/M/L codes exactly once" do
      expect(described_class::CELLS.keys.sort)
        .to eq(%w[H M L].repeated_permutation(4).map(&:join).sort)
    end

    it "maps every cell to a known archetype" do
      expect(described_class::CELLS.values.uniq).to all(satisfy { |id| described_class::ARCHETYPES.key?(id) })
    end

    it "has exactly the 18 archetypes named in the source doc" do
      labels = described_class::ARCHETYPES.each_value.map { |row| row["label"] }
      expect(labels).to match_array(doc_labels)
    end

    # This is the check that caught the source doc's HHHH contradiction: an
    # archetype no cell points at is unreachable copy.
    it "leaves no archetype orphaned — every one is reachable from some cell" do
      expect(described_class::ARCHETYPES.keys - described_class::CELLS.values.uniq).to be_empty
    end
  end

  describe "selection" do
    it "selects the archetype whose cell centroid is nearest the given vector" do
      expect(label(centroid("HHHH"))).to eq("The Romantic")
      expect(label(centroid("LLLL"))).to eq("The Local Casual")
      # A vector nudged a hair off a centroid still resolves to that archetype.
      expect(label(centroid("HHHH").map { |x| x + 0.05 })).to eq("The Romantic")
    end

    # Spot checks from the source doc's verification list.
    {
      "HHHH" => "The Romantic", "HLMH" => "The Glory Hunter",
      "MMLH" => "The Terrace Dreamer", "MLMM" => "The Everyfan",
      "LLLL" => "The Local Casual"
    }.each do |code, expected|
      it "maps #{code} to #{expected}" do
        expect(label(centroid(code))).to eq(expected)
      end
    end

    # The upper bound on SCATTER: scatter the lattice too hard and a cell's own
    # centroid falls nearer a neighbour's, silently corrupting every lookup.
    it "resolves every one of the 81 cells to its own code, even under lopsided weighting" do
      described_class::CELL_VECS.each do |code, vec|
        lopsided.each do |w|
          expect(described_class.code_for(vec, weights: w))
            .to eq(code), "cell #{code} resolved elsewhere under weights #{w.inspect}"
        end
      end
    end

    it "puts an on-anchor vector in the cell built from those same anchors" do
      # L on Vibe, H on Play, M on Ethics, H on Fanbase.
      vec = [described_class::LEVELS["Vibe"]["low"], described_class::LEVELS["Play"]["high"],
             described_class::LEVELS["Ethics"]["mid"], described_class::LEVELS["Fanbase"]["high"]]
      expect(described_class.code_for(vec)).to eq("LHMH")
    end
  end

  # The reason the cell centroids are scattered off the lattice at all. On a pure
  # lattice, nearest-cell factorises per axis, so no positive weighting could ever
  # change the winner — an axis dial that cannot move the answer is a lie. Asserted
  # as a measured property over a probe grid rather than one hand-picked vector, so
  # it keeps biting if LEVELS or SCATTER are retuned. Measured share at SCATTER
  # 0.12 is 31%; 0% is what an unscattered lattice would give.
  it "lets slider weights change the winning archetype, like club selection" do
    probes = [3.5, 4.5, 5.5, 6.5].product([4.0, 5.5, 6.5, 7.5], [2.0, 3.5, 5.0, 6.5], [3.5, 4.5, 5.5, 6.5])
    weightings = [[5, 5, 5, 5], [9, 3, 3, 3], [3, 9, 3, 3], [3, 3, 9, 3], [3, 3, 3, 9]]
    moved = probes.count { |vec| weightings.map { |w| described_class.call(vec, weights: w)[:label] }.uniq.size > 1 }
    expect(moved).to be > (probes.size * 0.15)
  end

  describe ".rank" do
    it "orders all 18 archetypes by distance, nearest first" do
      rows = described_class.rank([5.0, 5.0, 5.0, 5.0])
      expect(rows.size).to eq(18)
      expect(rows.map { |r| r[:dist] }).to eq(rows.map { |r| r[:dist] }.sort)
      expect(rows.map { |r| r[:label] }).to match_array(doc_labels)
    end

    # The coach's table and the result screen must never disagree about who won.
    it "agrees with .call on the leader, under any weighting" do
      vec = [4.5, 5.5, 3.0, 5.0]
      lopsided.each do |w|
        expect(described_class.rank(vec, weights: w).first[:label]).to eq(described_class.call(vec, weights: w)[:label])
      end
    end

    it "returns an empty ordering for a malformed vector" do
      expect(described_class.rank(nil)).to eq([])
    end
  end

  describe ".band" do
    it "returns the nearest level on each axis" do
      described_class::LEVELS.each do |axis, levels|
        levels.each { |name, value| expect(described_class.band(value, axis)).to eq(name) }
      end
    end
  end

  describe ".weight_vector" do
    it "normalises valid weights to sum to 1" do
      expect(described_class.weight_vector([1, 1, 1, 1])).to eq([0.25, 0.25, 0.25, 0.25])
      expect(described_class.weight_vector([2, 0, 0, 2])).to eq([0.5, 0.0, 0.0, 0.5])
    end

    it "falls back to equal weighting for nil, wrong arity, non-numeric or all-zero" do
      equal = described_class::EQUAL_WEIGHTS
      expect(described_class.weight_vector(nil)).to eq(equal)
      expect(described_class.weight_vector([1, 2, 3])).to eq(equal)
      expect(described_class.weight_vector([1, 2, "x", 4])).to eq(equal)
      expect(described_class.weight_vector([0, 0, 0, 0])).to eq(equal)
    end
  end

  it "returns a non-empty label and sentence for every archetype" do
    described_class::ARCHETYPES.each_value do |row|
      expect(row["label"]).to be_a(String).and(satisfy { |s| !s.empty? })
      expect(row["sentence"]).to be_a(String).and(satisfy { |s| !s.empty? })
    end
  end

  it "returns the label and sentence of the archetype owning the nearest cell" do
    described_class::CELL_VECS.each do |code, vec|
      row = described_class::ARCHETYPES.fetch(described_class::CELLS.fetch(code))
      expect(described_class.call(vec)).to eq({ label: row["label"], sentence: row["sentence"] })
    end
  end

  # db/seed-data/ARCHETYPES.md is where the copy is reviewed; ARCHETYPES is what
  # actually ships. They are two copies of the same 18 sentences, so pin them to
  # each other — editing either one alone fails here rather than drifting quietly.
  describe "parity with db/seed-data/ARCHETYPES.md" do
    let(:doc_path) { File.expand_path("../../../db/seed-data/ARCHETYPES.md", __dir__) }

    # "## <Label>", then the id in backticks, then the sentence paragraph.
    let(:doc_entries) do
      File.read(doc_path).scan(/^## (.+?)\n\n`(\w+)`\n\n(.+?)(?=\n\n##|\z)/m).map do |label, id, sentence|
        { id: id.to_sym, label: label.strip, sentence: normalise(sentence.strip) }
      end
    end

    # The doc is written with typographic apostrophes; every seeded blurb and the
    # shipped constant use straight ones. Normalise before comparing, and pin the
    # convention separately below.
    def normalise(text) = text.gsub(/[’‘]/, "'")

    it "exists and parses" do
      expect(File).to exist(doc_path)
      expect(doc_entries.size).to eq(18)
    end

    it "documents every archetype, in the order they ship" do
      expect(doc_entries.map { |e| e[:id] }).to eq(described_class::ARCHETYPES.keys)
    end

    it "matches the shipped label and sentence for every archetype" do
      doc_entries.each do |entry|
        row = described_class::ARCHETYPES.fetch(entry[:id])
        expect(row["label"]).to eq(entry[:label]), "label drift for #{entry[:id]}"
        expect(row["sentence"]).to eq(entry[:sentence]), "sentence drift for #{entry[:id]}"
      end
    end

    it "ships straight apostrophes, not typographic ones" do
      offenders = described_class::ARCHETYPES.select { |_id, row| row["sentence"].match?(/[’‘]/) }
      expect(offenders.keys).to be_empty
    end
  end

  it "exposes the client table with all keys the browser algorithm needs" do
    t = described_class.client_table
    expect(t.keys).to contain_exactly("levels", "cells", "archetypes", "scatter", "allMidLabel", "allMidSentence")
    expect(t["levels"]).to eq(described_class::LEVELS)
    expect(t["cells"]).to eq(described_class::CELLS)
    expect(t["archetypes"]).to eq(described_class::ARCHETYPES)
    expect(t["scatter"]).to eq(described_class::SCATTER)
  end

  # Every axis needs all three anchors or CELL_VECS can't be built.
  it "defines low, mid and high on every axis" do
    expect(described_class::LEVELS.keys).to eq(Quiz::Data::AXES)
    described_class::LEVELS.each_value { |levels| expect(levels.keys).to contain_exactly("low", "mid", "high") }
  end
end
