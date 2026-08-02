# frozen_string_literal: true

require "json"

module MCP
  # The MCP resource surface: static reference material a client reads to ground
  # its reasoning. The axis-codebook is the two-sided semantic key; the archetype
  # catalog describes supporters (desire-space) and deliberately never maps an
  # archetype onto a club.
  module Resources
    module_function

    def all
      [axis_codebook, archetype_catalog]
    end

    def axis_codebook
      Resource.new(
        uri: "footballsupporters://axis-codebook", name: "Axis codebook", mime_type: "application/json",
        description: "The two-sided key to the 4-axis space: each axis read as a supporter DESIRE and as a club " \
                     "ATTRIBUTE, with the numeric reference frame and the rules that keep the two from being conflated.",
        reader: -> { JSON.pretty_generate(Quiz::AxisCodebook.call) }
      )
    end

    def archetype_catalog
      Resource.new(
        uri: "footballsupporters://archetypes", name: "Archetype catalog", mime_type: "application/json",
        description: "The supporter archetypes (what a supporter WANTS, never a club): label, description, and the " \
                     "desire-space profile each one owns. An archetype is a region of desire-space, not a club.",
        reader: -> { JSON.pretty_generate(catalog) }
      )
    end

    def catalog
      Quiz::Archetype::ARCHETYPES.map { |id, row| archetype_entry(id, row, codes_for(id)) }
    end

    # The lattice cells this archetype owns (it owns several — an archetype is a
    # region of desire-space, not a point).
    def codes_for(id)
      Quiz::Archetype::CELLS.select { |_code, cell_id| cell_id == id }.keys
    end

    def archetype_entry(id, row, codes)
      { "id" => id.to_s, "label" => row["label"], "description" => row["sentence"],
        "desire_profile" => desire_profile(codes) }
    end

    # Per-axis L/M/H signature of the cells this archetype owns: the distinct levels
    # it spans on each axis ("high", "low/mid", or "any" when it spans all three).
    def desire_profile(codes)
      Quiz::Data::AXES.each_index.to_h do |i|
        levels = codes.map { |code| Quiz::Archetype::CODE_LEVEL.fetch(code[i]) }.uniq
        [Quiz::Data::AXES[i], levels.length == 3 ? "any" : levels.sort.join("/")]
      end
    end
  end
end
