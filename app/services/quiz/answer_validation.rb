# frozen_string_literal: true

module Quiz
  # Shared coercion + validation for a submitted answer set and weight sliders.
  # Both Quiz::Create (single league) and Quiz::CreateProfile (all leagues) mix
  # this in, so the input contract has one source of truth. Answers/weights are
  # league-independent — validated against the shared Quiz::Data questionnaire.
  #
  # Answers are stored as a key/value map of question id -> chosen option index
  # ({ "V2" => 1, ... }), NOT a positional array: the client presents questions in
  # a random order, so keying by the stable question id keeps a stored answer
  # bound to its question even if the questionnaire is reordered. For backward
  # compatibility we still accept a positional array (canonical Quiz::Data::Q
  # order — how older clients and pre-migration rows encode it) and normalize it
  # to the id map here.
  module AnswerValidation
    private

    # -> Hash{ question_id => Integer|nil }, or nil for an unusable payload.
    def coerce_answers(raw)
      case raw
      when Hash  then coerce_answer_map(raw)
      when Array then coerce_answer_array(raw)
      end
    end

    def coerce_answer_map(raw)
      raw.each_with_object({}) do |(qid, val), acc|
        acc[qid.to_s] = val.nil? ? nil : Integer(val, exception: false)
      end
    end

    # Legacy positional array in canonical Quiz::Data::Q order.
    def coerce_answer_array(raw)
      Data::Q.each_index.to_h do |i|
        val = raw[i]
        [Data::Q[i]["id"], val.nil? ? nil : Integer(val, exception: false)]
      end
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
      ids = Data::Q.map { |q| q["id"] }
      unless complete_answer_map?(answers, ids)
        errors[:answers] = "must answer all #{ids.length} questions"
        return
      end

      errors[:answers] = "each answer must be a valid option index" if Data::Q.any? { |q| invalid_option?(answers, q) }
    end

    def complete_answer_map?(answers, ids)
      answers.is_a?(Hash) && answers.length == ids.length && ids.all? { |id| answers.key?(id) }
    end

    def invalid_option?(answers, question)
      oi = answers[question["id"]]
      oi.nil? || !oi.between?(0, question["a"].length - 1)
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
