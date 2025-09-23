class User < ApplicationRecord
  # Disable password requirement for prototype
  # has_secure_password
  # Remove sessions for hackathon demo
  # has_many :sessions, dependent: :destroy
  belongs_to :organization, optional: true
  has_many :created_surveys, class_name: 'Survey', foreign_key: 'created_by_id'
  has_many :responses
  has_many :assignments, dependent: :destroy
  has_many :assigned_surveys, through: :assignments, source: :survey

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

  enum :status, {
    active: 0,
    inactive: 1,
    invited: 2
  }

  scope :by_department, ->(dept) { where(department: dept) }
  scope :active_users, -> { where(status: :active) }

  def full_name
    "#{first_name} #{last_name}"
  end

  def display_name
    full_name
  end

  def initials
    "#{first_name.first}#{last_name.first}".upcase
  end

  def department_display
    department&.titleize || "Unassigned"
  end

  def tenure_years
    return 0 unless hire_date
    ((Date.current - hire_date) / 365.25).floor
  end
end
