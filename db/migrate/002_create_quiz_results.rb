# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:quiz_results) do
      primary_key :id
      String   :slug, null: false                 # public share token (SecureRandom)
      String   :answers, text: true, null: false  # JSON: chosen option index per question
      String   :weights, text: true, null: false  # JSON: four slider weights
      String   :pick, null: false                 # resolved club name (for OG/index)
      DateTime :deleted_at                         # soft delete
      DateTime :created_at
      DateTime :updated_at

      index :slug, unique: true                    # the real uniqueness guarantee
      index :deleted_at
    end
  end
end
