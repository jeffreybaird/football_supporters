# frozen_string_literal: true

# A completed quiz, persisted so it can be shared at /q/:slug.
# `answers` and `weights` are the inputs; the scorer (Quiz::Score) re-derives the
# ranking on read (against `league`'s teams), so a shared result always matches
# the live algorithm. `pick` is denormalized for cheap lookups and social/OG
# metadata.
class QuizResult < Sequel::Model
  plugin :serialization, :json, :answers, :weights

  many_to_one :league

  dataset_module do
    # Read paths default to kept (non-soft-deleted) rows.
    def kept = where(deleted_at: nil)
    def recent = order(Sequel.desc(:created_at))
  end

  def validate
    super
    validates_presence %i[slug answers weights pick]
    validates_unique :slug
  end

  def soft_delete!
    update(deleted_at: Time.now)
  end

  def deleted? = !deleted_at.nil?
end
