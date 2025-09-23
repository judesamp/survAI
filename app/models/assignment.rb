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
  after_create_commit :broadcast_dashboard_refresh
  after_update_commit :broadcast_dashboard_refresh

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

  def broadcast_dashboard_refresh
    # Skip broadcasting during database seeding or if Redis is not available
    return if defined?(ActiveRecord::Tasks::DatabaseTasks) && caller.any? { |line| line.include?('db:seed') }
    
    begin
      # Refresh the entire dashboard when an assignment is created or updated
      Rails.logger.info "[ASSIGNMENT] Broadcasting dashboard refresh for survey #{survey.id}"

      # Reload survey with associations
    survey.reload
    assignments = survey.assignments.includes(:user, :response)
    questions = survey.questions.includes(:answers)

    # Calculate fresh metrics
    metrics = {
      response_rate: survey.response_rate,
      completion_rate: survey.completion_rate,
      average_completion_time: survey.average_completion_time,
      average_scale_score: survey.average_scale_score,
      assignments_by_status: survey.assignments_by_status
    }

    # Render the dashboard content partial
    renderer = ApplicationController.renderer.new
    html = renderer.render(
      partial: 'surveys/dashboard_content',
      locals: {
        survey: survey,
        assignments: assignments,
        questions: questions,
        metrics: metrics
      }
    )

    # Broadcast the updated dashboard content
    stream_name = "survey_#{survey.id}_data_generation"

    Turbo::StreamsChannel.broadcast_replace_to(
      stream_name,
      target: "dashboard-content",
      html: html
    )

    Rails.logger.info "[ASSIGNMENT] Dashboard refresh broadcast completed for survey #{survey.id}"
    
    rescue => e
      Rails.logger.warn "[ASSIGNMENT] Broadcasting failed for survey #{survey.id}: #{e.message}"
      # Continue execution even if broadcasting fails
    end
  end
end
