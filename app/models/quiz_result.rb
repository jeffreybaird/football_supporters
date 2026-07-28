# frozen_string_literal: true

# A completed quiz, persisted so it can be shared at /q/:slug.
# `answers` and `weights` are the inputs; the scorer (Quiz::Score) re-derives the
# ranking on read (against `league`'s teams), so a shared result always matches
# the live algorithm. `pick` is denormalized for cheap lookups and social/OG
# metadata.
#
# A `profile` row is a cross-league Football Profile: it has `league_id: nil`
# (scored against every league on read via Quiz::ProfileScore) and stores the
# archetype label in `pick`.
class QuizResult < Sequel::Model
  plugin :serialization, :json, :answers, :weights

  many_to_one :league
  # The clubs this result returned to the taker (winner + offered alternates, or
  # every league's winner for a profile), via the quiz_result_teams join table.
  many_to_many :teams, join_table: :quiz_result_teams, right_key: :team_id, left_key: :quiz_result_id

  def profile? = !!profile

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
