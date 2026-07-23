# frozen_string_literal: true

# A competition whose clubs the quiz matches against (e.g. the Premier League).
# Adding a new league is just data: a League row plus its Team rows.
class League < Sequel::Model
  one_to_many :teams, order: %i[position name]

  dataset_module do
    def kept = where(deleted_at: nil)
    def active = kept.where(active: true)
    def ordered = order(:position, :name)
  end

  # The league the quiz serves by default (first active, by position).
  def self.default
    active.ordered.first
  end

  # Kept teams in display/scoring order.
  def scored_teams
    teams_dataset.where(deleted_at: nil).order(:position, :name).all
  end

  # The league's recommender tuning, keyword-ready for Quiz::Score.call.
  def scoring_params
    { chooser_threshold:, max_choices:, amplify: }
  end

  def validate
    super
    validates_presence %i[slug name chooser_threshold max_choices amplify]
    validates_unique :slug
    validates_operator(:>=, 0.0, :chooser_threshold) if chooser_threshold
    validates_operator(:>=, 1, :max_choices) if max_choices
    validates_operator(:>=, 0.0, :amplify) if amplify
  end

  def soft_delete!
    update(deleted_at: Time.now)
  end
end
