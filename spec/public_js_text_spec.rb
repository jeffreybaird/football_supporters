# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"

# public/js/text.js is browser code with no build step, so it is exercised the
# only way it can be without a JS test runner: node requires the real file and
# prints the result, and the expectations here are the same contract as
# App#first_sentence (spec/app_helpers_spec.rb). The two implementations must
# agree — the client and the server-rendered share pages trim the same blurbs.
RSpec.describe "public/js/text.js" do # rubocop:disable RSpec/DescribeClass -- a JS file, not a Ruby class
  let(:path) { File.expand_path("../public/js/text.js", __dir__) }

  def first_sentence(text)
    script = <<~JS
      const { firstSentence } = require(#{path.to_json});
      process.stdout.write(firstSentence(#{text.to_json}));
    JS
    out, err, status = Open3.capture3("node", "-e", script)
    raise "node failed: #{err}" unless status.success?

    out
  end

  it "returns only the first sentence of a multi-sentence blurb" do
    text = "The club was founded in 1902. They play in green and white."

    expect(first_sentence(text)).to eq("The club was founded in 1902.")
  end

  it "keeps a leading St. abbreviation intact instead of truncating on it" do
    text = "St. Louis City is a young MLS club. It plays in the Western Conference."

    expect(first_sentence(text)).to eq("St. Louis City is a young MLS club.")
  end

  it "keeps a mid-sentence St. abbreviation intact" do
    text = "The insult of watching St. Pauli go up first. The Volkspark stayed full."

    expect(first_sentence(text)).to eq("The insult of watching St. Pauli go up first.")
  end

  it "rolls a one-word opening fragment into the sentence that follows" do
    text = "Neverkusen. They lost five finals in three years. Then they won the lot."

    expect(first_sentence(text)).to eq("Neverkusen. They lost five finals in three years.")
  end

  it "stops at a first sentence that is already long enough" do
    text = "Stamford Bridge expects to win. The rest of the league finds this insufferable."

    expect(first_sentence(text)).to eq("Stamford Bridge expects to win.")
  end

  it "returns the whole text unchanged when there is only one sentence" do
    text = "A single sentence with no trailing period"

    expect(first_sentence(text)).to eq("#{text}.")
  end
end
