class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email_address, presence: true, uniqueness: true

  def password_reset_token
    signed_id(expires_in: 15.minutes, purpose: :password_reset)
  end

  def self.find_by_password_reset_token!(token)
    find_signed!(token, purpose: :password_reset)
  end
end
