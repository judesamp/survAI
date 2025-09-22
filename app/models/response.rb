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
  # after_create :broadcast_response_created
  after_update :update_assignment_status, if: :completed_at_changed?
  # after_update :broadcast_response_completed, if: :completed_at_changed?

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

  def broadcast_response_created
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.info "Broadcasting response created to #{stream_name}"

    # Count current responses for this survey
    current_count = survey.responses.count
    total_assignments = survey.assignments.count

    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name,
      target: "data-generation-status",
      html: %{
        <div class="mb-2 p-2 bg-green-50 border border-green-200 rounded text-sm">
          <div class="flex items-center justify-between">
            <span class="text-green-900">
              📝 Response #{current_count}/#{total_assignments} - #{respondent_name}
            </span>
            <span class="text-xs text-green-600">
              #{answers.count} answers
            </span>
          </div>
        </div>
      }
    )
  end

  def broadcast_response_completed
    if completed_at_was.nil? && completed?
      stream_name = "survey_#{survey.id}_data_generation"
      Rails.logger.info "Broadcasting response completed to #{stream_name}"

      current_count = survey.responses.completed.count
      total_assignments = survey.assignments.count

      Turbo::StreamsChannel.broadcast_prepend_to(
        stream_name,
        target: "data-generation-status",
        html: %{
          <div class="mb-2 p-2 bg-green-50 border border-green-200 rounded text-sm">
            <div class="flex items-center justify-between">
              <span class="text-green-900">
                ✅ Response completed by #{respondent_name}
              </span>
              <span class="text-xs text-green-600">
                #{answers.count} answers
              </span>
            </div>
          </div>
        }
      )
    end
  end
end
