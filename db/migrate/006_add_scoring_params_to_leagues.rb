# frozen_string_literal: true

# Per-league scoring tuning, previously hard-coded module constants in
# Quiz::Data. Making the app multi-league means each competition can tune its
# own recommender: how close an alternate must be to be offered
# (chooser_threshold), how many alternates at most (max_choices), and how hard
# to stretch a moderate user vector outward from the team centroid (amplify).
# Defaults match the original Quiz::Data constants so existing results are
# unchanged.
Sequel.migration do
  change do
    alter_table(:leagues) do
      add_column :chooser_threshold, Float,   null: false, default: 0.25
      add_column :max_choices,       Integer, null: false, default: 3
      add_column :amplify,           Float,   null: false, default: 2.5
    end
  end
end
