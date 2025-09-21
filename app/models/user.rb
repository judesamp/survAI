class User < ApplicationRecord
  # Disable password requirement for prototype
  # has_secure_password
  has_many :sessions, dependent: :destroy
  belongs_to :organization, optional: true
  has_many :created_surveys, class_name: 'Survey', foreign_key: 'created_by_id'
  has_many :responses

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, presence: true
  validates :last_name, presence: true

  enum :role, {
    respondent: 0,
    creator: 1,
    admin: 2,
    super_admin: 3
  }

  def full_name
    "#{first_name} #{last_name}"
  end
end
