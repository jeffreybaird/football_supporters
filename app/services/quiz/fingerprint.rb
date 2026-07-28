# frozen_string_literal: true

require "digest"

module Quiz
  # A coarse, non-reversible per-user fingerprint for grouping quiz submissions.
  # It hashes the caller's IP together with a couple of stable browser signals
  # (User-Agent, Accept-Language) under a server-side salt, so the same person on
  # the same browser lands on the same fingerprint — enough to filter to distinct
  # takers or pull one taker's answers — while the stored value reveals neither
  # the IP nor the headers. Not an identity or an auth token; two people behind
  # one NAT with the same browser can collide, and that is acceptable here.
  module Fingerprint
    module_function

    # ENV so it can be rotated/segregated per deploy; falls back to a constant so
    # dev/test are deterministic without configuration.
    SALT = ENV.fetch("FINGERPRINT_SALT", "football-supporters-fp")

    # request: a Rack::Request (has #ip and #get_header). Returns a hex digest, or
    # nil when there is nothing to fingerprint (no IP and no signals) so we store
    # a real absence rather than the hash of an empty string.
    def call(request)
      ip = request.ip
      ua = request.get_header("HTTP_USER_AGENT")
      lang = request.get_header("HTTP_ACCEPT_LANGUAGE")
      return nil if [ip, ua, lang].all? { |v| v.nil? || v.empty? }

      Digest::SHA256.hexdigest([SALT, ip, ua, lang].join("\n"))
    end
  end
end
