# frozen_string_literal: true

require "spec_helper"

RSpec.describe Quiz::AxisCodebook do
  let(:book) { described_class.call }

  it "documents all four axes on both sides" do
    expect(book["axes"].keys).to eq(Quiz::Data::AXES)
    book["axes"].each_value do |axis|
      expect(axis["desire"].keys).to contain_exactly("low", "high")
      expect(axis["attribute"].keys).to contain_exactly("low", "high")
    end
  end

  it "assembles the live reference frame from the scoring model" do
    ethics = book["axes"].fetch("Ethics")
    expect(ethics["range"]).to eq([0, 10])
    expect(ethics["level_anchors"]).to eq(Quiz::Archetype::LEVELS.fetch("Ethics"))
    expect(ethics["self_report_population"]["mean"]).to eq(Quiz::Data::USER_MEAN[2])
  end

  it "glosses each axis weight from the sliders" do
    expect(book["axes"].fetch("Play")["weight"]).to eq("How much does the style of football matter?")
  end

  it "carries the load-bearing conflation notes" do
    expect(book["notes"]).to be_an(Array)
    expect(book["notes"]).not_to be_empty
    expect(book["notes"].join).to match(/de-bias|inflated/i)
  end
end
