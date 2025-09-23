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
  before_destroy :nullify_assignment_references
  after_create_commit :broadcast_dashboard_refresh
  after_update :update_assignment_status, if: :completed_at_changed?
  after_update_commit :broadcast_dashboard_refresh, if: :completed_at_changed?

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

  def nullify_assignment_references
    # Clear any assignment references to this response before deletion
    Assignment.where(response_id: id).update_all(response_id: nil, completed: false, completed_at: nil)
  end

  def update_assignment_status
    return unless assignment

    if completed?
      assignment.update(completed: true, response: self)
    else
      assignment.update(completed: false, response: nil)
    end
  end

  def broadcast_dashboard_refresh
    # Skip broadcasting during database seeding or if Redis is not available
    return if defined?(ActiveRecord::Tasks::DatabaseTasks) && caller.any? { |line| line.include?('db:seed') }
    
    begin
      # Refresh the entire dashboard when a response is created or completed
      Rails.logger.info "[RESPONSE] Broadcasting dashboard refresh for survey #{survey.id}"

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

      Rails.logger.info "[RESPONSE] Dashboard refresh broadcast completed for survey #{survey.id}"
      
    rescue => e
      Rails.logger.warn "[RESPONSE] Broadcasting failed for survey #{survey.id}: #{e.message}"
      # Continue execution even if broadcasting fails
    end
  end
end
