# frozen_string_literal: true

require "dry/monads"

# Visitor feedback. Namespaced `Feedbacks` because `Feedback` is the model.
module Feedbacks
  # Record one feedback submission, then notify the inbox.
  #
  # The DB row is the source of truth: it is written and committed first, and the
  # email goes out afterwards. A provider outage therefore degrades to "the row
  # is there, `delivered` is false" rather than losing the submission.
  class Create
    include Dry::Monads[:result]

    # A bot that fills every field it finds trips this hidden input. Real
    # submissions always leave it empty (it is aria-hidden and off-screen).
    HONEYPOT_FIELD = "website"
    MIN_MESSAGE_LENGTH = 2

    def self.call(attrs:) = new.call(attrs:)

    def initialize(notifier: Notify)
      @notifier = notifier
    end

    def call(attrs:)
      return Failure([:spam]) if present?(attrs[HONEYPOT_FIELD])

      feedback = build(attrs)
      errors = errors_for(feedback)
      return Failure([:validation, errors]) unless errors.empty?

      feedback.save_changes
      deliver(feedback)
      Success(feedback)
    rescue Sequel::DatabaseError => e
      Failure([:error, e.message])
    end

    private

    # Blank optional fields are stored as NULL, not "" — "they gave no email" and
    # "they gave an empty one" are the same thing.
    def build(attrs)
      Feedback.new(message: squish(attrs["message"]), email: blank_to_nil(attrs["email"]),
                   page: blank_to_nil(attrs["page"]))
    end

    # Our own message-length rules first (they carry copy a visitor can act on),
    # then the model's, which back-stop them at the database boundary.
    def errors_for(feedback)
      errors = validate(feedback.message)
      return errors unless errors.empty?

      feedback.valid? ? {} : feedback.errors.to_h
    end

    def blank_to_nil(value)
      squished = squish(value)
      squished.empty? ? nil : squished
    end

    # Best effort, and deliberately after the commit: the caller already has its
    # feedback safely stored, so a failed send is recorded on the row rather than
    # turned into a failure the visitor sees.
    def deliver(feedback)
      result = @notifier.call(feedback:)
      feedback.update(delivered: true) if result.success?
    end

    def validate(message)
      return { message: "Please write a little more." } if message.length < MIN_MESSAGE_LENGTH
      return { message: "That's too long — please keep it under #{Feedback::MAX_MESSAGE_LENGTH} characters." } \
        if message.length > Feedback::MAX_MESSAGE_LENGTH

      {}
    end

    def squish(value) = value.to_s.strip

    def present?(value) = !squish(value).empty?
  end
end
