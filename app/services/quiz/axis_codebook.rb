# frozen_string_literal: true

require "yaml"

require_relative "data"
require_relative "archetype"

module Quiz
  # The two-sided axis codebook: the semantic key to the 4-axis space. The prose
  # (what each pole means, read as a supporter DESIRE and as a club ATTRIBUTE, plus
  # the conflation notes) lives in config/quiz/axis_codebook.yml; the numeric
  # reference frame (range, level anchors, self-report population, weight gloss) is
  # assembled here from the live scoring model so the two can't drift. Served as
  # the `axis-codebook` MCP resource and available to the result views.
  module AxisCodebook
    module_function

    PROSE = YAML.safe_load_file(File.expand_path("../../../config/quiz/axis_codebook.yml", __dir__)).freeze
    MODEL_DESCRIPTION =
      "A 4-axis space (Vibe, Play, Ethics, Fanbase), each 0-10, read two ways: a supporter's DESIRE " \
      "vector (what they want) and a club's ATTRIBUTE vector (what it is). The two are compared by " \
      "distance only after Quiz::Score aligns them; they are not the same quantity."

    # The assembled codebook: model description, per-axis two-sided entry, and the
    # load-bearing notes that keep desire-space and attribute-space distinct.
    def call(locale = Translations::DEFAULT)
      {
        "model" => MODEL_DESCRIPTION,
        "axes" => Data::AXES.to_h { |axis| [axis, axis_entry(axis, locale)] },
        "notes" => PROSE.fetch("notes")
      }
    end

    def axis_entry(axis, locale)
      prose = PROSE.fetch("axes").fetch(axis)
      {
        "captures" => prose.fetch("captures"),
        "desire" => prose.fetch("desire"),
        "attribute" => prose.fetch("attribute"),
        "weight" => weight_gloss(axis, locale),
        "range" => [0, 10],
        "level_anchors" => Archetype::LEVELS.fetch(axis),
        "self_report_population" => population(axis)
      }
    end

    # The slider prompt for this axis — the WEIGHT reading (how much the axis
    # counts in the distance), distinct from the two position poles above.
    def weight_gloss(axis, locale)
      Data.sliders(locale).find { |slider| slider["ax"] == axis }&.fetch("q")
    end

    # The provisional self-report reference the scorer de-biases against.
    def population(axis)
      i = Data::AXES.index(axis)
      { "mean" => Data::USER_MEAN[i], "sd" => Data::USER_SD[i] }
    end
  end
end
