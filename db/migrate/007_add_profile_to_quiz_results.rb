# frozen_string_literal: true

# A "Football Profile" result scores one answer set against every league at once,
# so it has no single league_id (already nullable, see 005) and no single club
# pick. This flag marks such rows; the archetype label is stored in the existing
# `pick` column, so `pick`'s NOT NULL constraint stays intact (no table rebuild).
Sequel.migration do
  change do
    alter_table(:quiz_results) do
      add_column :profile, TrueClass, null: false, default: false
    end
  end
end
