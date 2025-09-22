class Assignment < ApplicationRecord
  belongs_to :survey
  belongs_to :user
  belongs_to :assigned_by, class_name: 'User'
  belongs_to :response, optional: true

  validates :user_id, uniqueness: { scope: :survey_id, message: "already assigned to this survey" }

  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
  scope :in_progress, -> { joins(:response).where(completed: false) }
  scope :not_started, -> { where(completed: false, response_id: nil) }

  before_update :set_completed_at, if: :completed_changed?
  # after_create :broadcast_assignment_created
  # after_update :broadcast_assignment_updated

  def status
    return :completed if completed?
    return :in_progress if response_id.present?
    :not_started
  end

  def status_display
    case status
    when :completed then "Completed"
    when :in_progress then "In Progress"
    when :not_started then "Not Started"
    end
  end

  def days_since_assigned
    return 0 unless assigned_at
    ((Time.current - assigned_at) / 1.day).floor
  end

  def overdue?
    days_since_assigned > 7 && !completed?
  end

  private

  def set_completed_at
    if completed?
      self.completed_at = Time.current
    else
      self.completed_at = nil
    end
  end

  def broadcast_assignment_created
    stream_name = "survey_#{survey.id}_data_generation"
    Rails.logger.info "Broadcasting assignment created to #{stream_name}"

    Turbo::StreamsChannel.broadcast_prepend_to(
      stream_name,
      target: "data-generation-status",
      html: %{
        <div class="mb-2 p-2 bg-blue-50 border border-blue-200 rounded text-sm">
          <div class="flex items-center justify-between">
            <span class="text-blue-900">
              👤 Assignment created for #{user.display_name}
            </span>
            <span class="text-xs text-blue-600">
              #{created_at.strftime('%H:%M:%S')}
            </span>
          </div>
        </div>
      }
    )
  end

  def broadcast_assignment_updated
    if completed_changed? && completed?
      stream_name = "survey_#{survey.id}_data_generation"
      Rails.logger.info "Broadcasting assignment completed to #{stream_name}"

      Turbo::StreamsChannel.broadcast_prepend_to(
        stream_name,
        target: "data-generation-status",
        html: %{
          <div class="mb-2 p-2 bg-blue-50 border border-blue-200 rounded text-sm">
            <div class="flex items-center justify-between">
              <span class="text-blue-900">
                ✅ Assignment completed by #{user.display_name}
              </span>
              <span class="text-xs text-blue-600">
                #{completed_at.strftime('%H:%M:%S')}
              </span>
            </div>
          </div>
        }
      )
    end
  end
end
