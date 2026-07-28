# frozen_string_literal: true

require "dry/monads"
require "securerandom"

module Quiz
  # Persist a cross-league Football Profile and mint its shareable slug. A profile
  # has no single league or club, so (unlike Quiz::Create) it stores league_id nil
  # and the archetype label in `pick`. The ranking per league is re-derived on
  # read by Quiz::ProfileScore, so only the inputs need persisting.
  class CreateProfile
    include Dry::Monads[:result]
    include AnswerValidation

    MAX_SLUG_ATTEMPTS = 5

    def self.call(...) = new.call(...)

    def call(attrs:, fingerprint: nil)
      answers = coerce_answers(attrs["answers"])
      weights = coerce_weights(attrs["weights"])
      errors = validate_answers_and_weights(answers, weights)
      return Failure([:validation, errors]) unless errors.empty?

      profile = ProfileScore.call(answers:, weights:)
      return Failure([:validation, { leagues: "none available" }]) if profile.leagues.empty?

      record = insert_with_slug(answers:, weights:, pick: profile.archetype[:label], fingerprint:)
      # A profile has no single club; link every league's winner it returned.
      profile.leagues.each { |entry| record.add_team(entry.pick) }
      Success(record)
    rescue Sequel::UniqueConstraintViolation
      Failure([:conflict])
    rescue Sequel::DatabaseError => e
      Failure([:error, e.message])
    end

    private

    def insert_with_slug(answers:, weights:, pick:, fingerprint:)
      attempts = 0
      begin
        attempts += 1
        QuizResult.create(slug: SecureRandom.urlsafe_base64(8), profile: true, league_id: nil,
                          answers:, weights:, pick:, fingerprint:)
      rescue Sequel::UniqueConstraintViolation
        retry if attempts < MAX_SLUG_ATTEMPTS
        raise
      end
    end
  end
end
