# frozen_string_literal: true

require "dry/monads"
require "faraday"
require "json"

module Clients
  # Resend's transactional email API (https://resend.com/docs). The only place in
  # the app that talks to Resend — callers pass plain Ruby and get a Result back.
  #
  # Configuration is entirely ENV-driven, and the destination address is NEVER
  # written down in source: RESEND_API_KEY, FEEDBACK_FROM_EMAIL (a sender on a
  # domain verified with Resend) and FEEDBACK_TO_EMAIL (the inbox). With any of
  # them unset the client reports itself not `configured?` and callers skip the
  # send rather than raising — dev and the test suite need no key and no network.
  class Resend
    include Dry::Monads[:result]

    BASE_URL = "https://api.resend.com"
    TIMEOUT = 5 # seconds; a slow provider must not hold a web request open

    # One outbound message. `reply_to` is optional and omitted from the payload
    # when nil, so a reply falls back to the sender.
    Email = Struct.new(:from, :to, :subject, :text, :reply_to, keyword_init: true)

    def self.configured? = new.configured?

    def initialize(api_key: ENV.fetch("RESEND_API_KEY", nil), connection: nil)
      @api_key = api_key
      @connection = connection
    end

    def configured? = !(@api_key.nil? || @api_key.empty?)

    # Send one Email. `idempotency_key` lets a retry of the same logical send
    # collapse into the original rather than double-delivering.
    # Returns Success(response_body_hash) or Failure([:reason, detail]).
    def send_email(email, idempotency_key: nil)
      return Failure([:not_configured]) unless configured?

      response = post_email(email, idempotency_key)
      return Failure([:http_error, "#{response.status}: #{response.body}"]) unless response.success?

      Success(parse(response.body))
    rescue Faraday::Error => e
      Failure([:transport_error, e.message])
    end

    private

    def post_email(email, idempotency_key)
      connection.post("/emails") do |req|
        req.headers["Idempotency-Key"] = idempotency_key if idempotency_key
        req.body = payload(email).to_json
      end
    end

    def payload(email)
      body = { from: email.from, to: Array(email.to), subject: email.subject, text: email.text }
      body[:reply_to] = email.reply_to if email.reply_to
      body
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL) do |f|
        f.headers["Authorization"] = "Bearer #{@api_key}"
        f.headers["Content-Type"] = "application/json"
        f.options.timeout = TIMEOUT
        f.options.open_timeout = TIMEOUT
      end
    end

    def parse(body)
      body.is_a?(String) ? JSON.parse(body) : (body || {})
    rescue JSON::ParserError
      {}
    end
  end
end
