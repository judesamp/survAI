class Response < ApplicationRecord
  belongs_to :survey
  belongs_to :user, optional: true
  has_many :answers, dependent: :destroy
  accepts_nested_attributes_for :answers

  validates :session_id, presence: true, unless: :user_id?

  scope :completed, -> { where.not(completed_at: nil) }
  scope :incomplete, -> { where(completed_at: nil) }

  def completed?
    completed_at.present?
  end

  def completion_percentage
    return 0 if survey.questions.count == 0
    (answers.count.to_f / survey.questions.count * 100).round
  end
end
