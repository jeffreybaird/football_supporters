# frozen_string_literal: true

# The clubs a completed quiz actually returned to the taker — the winning pick
# plus any close alternates it offered (Quiz::Score#candidates), and for a
# cross-league Football Profile every league's winner. A join table (not a column
# on quiz_results) because a result can surface several clubs and one club is
# returned by many results; it lets us ask "which results picked Everton?" and
# "which clubs did this result show?" without re-scoring.
Sequel.migration do
  change do
    create_table(:quiz_result_teams) do
      primary_key :id
      foreign_key :quiz_result_id, :quiz_results, null: false, on_delete: :cascade
      foreign_key :team_id, :teams, null: false, on_delete: :cascade
      DateTime :created_at

      index %i[quiz_result_id team_id], unique: true # a club is linked once per result
      index :team_id                                 # "which results returned this club?"
    end
  end
end
