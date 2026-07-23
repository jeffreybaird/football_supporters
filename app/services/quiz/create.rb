# frozen_string_literal: true

require "dry/monads"
require "securerandom"

module Quiz
  # Persist a completed quiz and mint its shareable slug.
  # Validates the submitted answers/weights, resolves the winning club with
  # Quiz::Score against the given league's teams, and stores it. Returns a tagged
  # Result.
  class Create
    include Dry::Monads[:result]

    MAX_SLUG_ATTEMPTS = 5

    def self.call(...) = new.call(...)

    def call(league:, attrs:)
      return Failure([:not_found]) if league.nil?

      answers = coerce_answers(attrs["answers"])
      weights = coerce_weights(attrs["weights"])
      errors = validate(answers, weights)
      return Failure([:validation, errors]) unless errors.empty?

      teams = league.scored_teams
      return Failure([:validation, { league: "has no teams" }]) if teams.empty?

      pick = Score.call(teams:, answers:, weights:, **league.scoring_params).pick
      record = insert_with_slug(league:, answers:, weights:, pick: pick.name)
      Success(record)
    rescue Sequel::UniqueConstraintViolation
      Failure([:conflict])
    rescue Sequel::DatabaseError => e
      Failure([:error, e.message])
    end

    private

    # Persist, retrying on the astronomically unlikely slug collision. The unique
    # index is the real guard; SQLite's single writer serializes the insert.
    def insert_with_slug(league:, answers:, weights:, pick:)
      attempts = 0
      begin
        attempts += 1
        QuizResult.create(slug: SecureRandom.urlsafe_base64(8), league_id: league.id, answers:, weights:, pick:)
      rescue Sequel::UniqueConstraintViolation
        retry if attempts < MAX_SLUG_ATTEMPTS
        raise
      end
    end

    def coerce_answers(raw)
      return nil unless raw.is_a?(Array)

      raw.map { |x| x.nil? ? nil : Integer(x, exception: false) }
    end

    def coerce_weights(raw)
      return nil unless raw.is_a?(Array)

      raw.map { |x| Integer(x, exception: false) }
    end

    def validate(answers, weights)
      errors = {}
      validate_answers(answers, errors)
      validate_weights(weights, errors)
      errors
    end

    def validate_answers(answers, errors)
      if answers.nil? || answers.length != Data::Q.length
        errors[:answers] = "must have #{Data::Q.length} entries"
        return
      end

      bad = answers.each_with_index.any? do |oi, i|
        oi.nil? || !oi.between?(0, Data::Q[i]["a"].length - 1)
      end
      errors[:answers] = "each answer must be a valid option index" if bad
    end

    def validate_weights(weights, errors)
      if weights.nil? || weights.length != Data::AXES.length
        errors[:weights] = "must have #{Data::AXES.length} entries"
        return
      end

      errors[:weights] = "each weight must be 1..10" unless weights.all? { |w| w.is_a?(Integer) && w.between?(1, 10) }
    end
  end
end
