# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:leagues) do
      primary_key :id
      String    :slug, null: false            # stable lookup key (e.g. "premier-league")
      String    :name, null: false
      String    :season                        # e.g. "2026-27" (optional)
      Integer   :position, null: false, default: 0
      TrueClass :active, null: false, default: true
      DateTime  :deleted_at                    # soft delete
      DateTime  :created_at
      DateTime  :updated_at

      index :slug, unique: true
      index :deleted_at
    end
  end
end
