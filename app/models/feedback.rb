# frozen_string_literal: true

# One submission from the public feedback form. `email` is optional — it exists
# only so a reply is possible, and nothing in the app requires it.
class Feedback < Sequel::Model
  MAX_MESSAGE_LENGTH = 5_000
  MAX_EMAIL_LENGTH = 254 # RFC 5321 maximum path length
  MAX_PAGE_LENGTH = 2_000
  # Deliberately loose: this gates obvious typos, not deliverability. The address
  # is optional, so rejecting an odd-but-valid one costs more than it saves.
  EMAIL_FORMAT = /\A[^@\s]+@[^@\s.]+\.[^@\s]+\z/

  dataset_module do
    def kept = where(deleted_at: nil)
    def recent = order(Sequel.desc(:created_at))
  end

  def validate
    super
    validates_presence :message
    validates_max_length MAX_MESSAGE_LENGTH, :message, allow_nil: true
    validates_max_length MAX_PAGE_LENGTH, :page, allow_nil: true
    return if email.nil?

    validates_max_length MAX_EMAIL_LENGTH, :email
    validates_format EMAIL_FORMAT, :email, message: "isn't a valid email address"
  end

  def soft_delete!
    update(deleted_at: Time.now)
  end

  def deleted? = !deleted_at.nil?
end
