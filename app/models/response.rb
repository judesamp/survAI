class Response < ApplicationRecord
  belongs_to :survey
  belongs_to :user, optional: true
  belongs_to :assignment, optional: true
  has_many :answers, dependent: :destroy
  accepts_nested_attributes_for :answers

  validates :session_id, presence: true, unless: :user_id?

  scope :completed, -> { where.not(completed_at: nil) }
  scope :incomplete, -> { where(completed_at: nil) }

  before_create :set_started_at
  after_update :update_assignment_status, if: :completed_at_changed?

  def completed?
    completed_at.present?
  end

  def completion_percentage
    return 0 if survey.questions.count == 0
    (answers.count.to_f / survey.questions.count * 100).round
  end

  def time_to_complete
    return nil unless completed? && started_at
    ((completed_at - started_at) / 60).round(1) # in minutes
  end

  def respondent_name
    user&.display_name || "Anonymous"
  end

  private

  def set_started_at
    self.started_at ||= Time.current
  end

  def update_assignment_status
    return unless assignment

    if completed?
      assignment.update(completed: true, response: self)
    else
      assignment.update(completed: false, response: nil)
    end
  end
end
