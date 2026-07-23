# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:quiz_results) do
      # Which league's teams this quiz was scored against. Nullable so the
      # migration is backward-compatible with rows written before it; new code
      # always sets it, and reads fall back to the default league when absent.
      add_foreign_key :league_id, :leagues, null: true, index: true
    end
  end
end
