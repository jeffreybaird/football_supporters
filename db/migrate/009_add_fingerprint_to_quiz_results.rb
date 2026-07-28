# frozen_string_literal: true

# A coarse per-user fingerprint (a salted SHA-256 of IP + a couple of browser
# headers — see Quiz::Fingerprint) so completed quizzes can be grouped by the
# person who took them without storing anything directly identifying. Nullable:
# rows written before this migration have none, and a request missing the source
# headers still persists. Indexed for "distinct takers" / "this taker's answers"
# filtering.
Sequel.migration do
  change do
    alter_table(:quiz_results) do
      add_column :fingerprint, String, index: true
    end
  end
end
