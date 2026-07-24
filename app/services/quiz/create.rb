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
    include AnswerValidation

    MAX_SLUG_ATTEMPTS = 5

    def self.call(...) = new.call(...)

    def call(league:, attrs:)
      return Failure([:not_found]) if league.nil?

      answers = coerce_answers(attrs["answers"])
      weights = coerce_weights(attrs["weights"])
      errors = validate_answers_and_weights(answers, weights)
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
  end
end
