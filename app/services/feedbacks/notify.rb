# frozen_string_literal: true

require "dry/monads"

module Feedbacks
  # Email one feedback submission to the site owner.
  #
  # The destination lives in FEEDBACK_TO_EMAIL, never in source or in any page —
  # the form posts to this app and this app talks to Resend, so the address is
  # never exposed to visitors. When the ENV is not configured (dev, test, or a
  # deploy without a key) this is a no-op Failure([:not_configured]) and the
  # caller simply leaves the row undelivered.
  class Notify
    include Dry::Monads[:result]

    SUBJECT_PREVIEW_LENGTH = 60

    def self.call(...) = new.call(...)

    def initialize(client: Clients::Resend.new)
      @client = client
      @to = ENV.fetch("FEEDBACK_TO_EMAIL", nil)
      @from = ENV.fetch("FEEDBACK_FROM_EMAIL", nil)
    end

    def call(feedback:)
      return Failure([:not_configured]) if @to.nil? || @from.nil? || @to.empty? || @from.empty?

      email = Clients::Resend::Email.new(
        from: @from,
        to: @to,
        subject: subject(feedback),
        text: body(feedback),
        # Replying goes straight back to them when they left an address; without
        # one, replies land on the sender and nothing is misdirected.
        reply_to: feedback.email
      )
      @client.send_email(email, idempotency_key: "feedback-#{feedback.id}")
    end

    private

    def subject(feedback)
      preview = feedback.message.tr("\n", " ").slice(0, SUBJECT_PREVIEW_LENGTH)
      preview += "…" if feedback.message.length > SUBJECT_PREVIEW_LENGTH
      "Feedback: #{preview}"
    end

    def body(feedback)
      [
        feedback.message,
        "",
        "—",
        "From: #{feedback.email || "(no email given)"}",
        "Page: #{feedback.page || "(unknown)"}",
        "Received: #{feedback.created_at}",
        "Feedback ##{feedback.id}"
      ].join("\n")
    end
  end
end
