# frozen_string_literal: true

# A club within a league, carrying its four scoring coordinates, its result-page
# blurb, and an optional crest. The scorer (Quiz::Score) reads #vector; the
# result view reads #name / #blurb / #crest.
class Team < Sequel::Model
  many_to_one :league
  # The quiz results that returned this club, via the quiz_result_teams join
  # table — "which takers were pointed at this club?".
  many_to_many :quiz_results, join_table: :quiz_result_teams, right_key: :quiz_result_id, left_key: :team_id

  # Columns holding the scoring coordinates, in Quiz::Data::AXES order.
  AXIS_COLUMNS = %i[vibe play ethics fanbase].freeze

  dataset_module do
    def kept = where(deleted_at: nil)
    def ordered = order(:position, :name)
  end

  # The team's coordinate vector, aligned to Quiz::Data::AXES.
  def vector
    AXIS_COLUMNS.map { |col| send(col).to_f }
  end

  def validate
    super
    validates_presence [:league_id, :name, :blurb, *AXIS_COLUMNS]
    validates_unique %i[league_id name]
    AXIS_COLUMNS.each do |col|
      value = send(col)
      next if value.nil?

      errors.add(col, "must be between 0 and 10") unless value.between?(0, 10)
    end
    # Global popularity weight for the aligned scorer (Quiz::Score#target_of).
    # Not required — the DB default (1.0) stands in for un-curated clubs — but it
    # must be non-negative, since it is raised to a fractional power.
    errors.add(:popularity, "must be >= 0") if !popularity.nil? && popularity.negative?
  end

  def soft_delete!
    update(deleted_at: Time.now)
  end
end
