# frozen_string_literal: true

module Quiz
  # Shared coercion + validation for a submitted answer set and weight sliders.
  # Both Quiz::Create (single league) and Quiz::CreateProfile (all leagues) mix
  # this in, so the input contract has one source of truth. Answers/weights are
  # league-independent — validated against the shared Quiz::Data questionnaire.
  module AnswerValidation
    private

    def coerce_answers(raw)
      return nil unless raw.is_a?(Array)

      raw.map { |x| x.nil? ? nil : Integer(x, exception: false) }
    end

    def coerce_weights(raw)
      return nil unless raw.is_a?(Array)

      raw.map { |x| Integer(x, exception: false) }
    end

    def validate_answers_and_weights(answers, weights)
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
