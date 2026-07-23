# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:teams) do
      primary_key :id
      foreign_key :league_id, :leagues, null: false, on_delete: :cascade
      String   :name, null: false
      # the four scoring coordinates (see Quiz::Data::AXES): Vibe, Play, Ethics, Fanbase
      Float    :vibe, null: false
      Float    :play, null: false
      Float    :ethics, null: false
      Float    :fanbase, null: false
      String   :blurb, text: true, null: false   # the club's result-page write-up
      String   :crest                            # crest filename in public/images (optional)
      Integer  :position, null: false, default: 0 # stable ordering within the league
      DateTime :deleted_at                        # soft delete
      DateTime :created_at
      DateTime :updated_at

      index %i[league_id name], unique: true      # a club name is unique within its league
      index :league_id
      index :deleted_at
    end
  end
end
