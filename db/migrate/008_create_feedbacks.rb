# frozen_string_literal: true

# Visitor feedback submitted from the "Have any feedback?" form. The row is the
# source of truth — the notification email is a best-effort side effect, so a
# delivery outage can never lose what someone took the time to write.
Sequel.migration do
  change do
    create_table(:feedbacks) do
      primary_key :id
      String   :message, text: true, null: false # what they wrote
      String   :email                            # optional — only if they want a reply
      String   :page                             # the URL they came from, for context
      TrueClass :delivered, null: false, default: false # notification email accepted by the provider
      DateTime :deleted_at # soft delete
      DateTime :created_at
      DateTime :updated_at

      index :created_at
      index :deleted_at
    end
  end
end
