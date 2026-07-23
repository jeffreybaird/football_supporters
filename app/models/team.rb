# frozen_string_literal: true

# A club within a league, carrying its four scoring coordinates, its result-page
# blurb, and an optional crest. The scorer (Quiz::Score) reads #vector; the
# result view reads #name / #blurb / #crest.
class Team < Sequel::Model
  many_to_one :league

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
  end

  def soft_delete!
    update(deleted_at: Time.now)
  end
end
