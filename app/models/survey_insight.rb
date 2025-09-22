class SurveyInsight < ApplicationRecord
  belongs_to :survey
  belongs_to :generated_by, class_name: 'User'

  validates :insights_data, presence: true
  validates :generated_at, presence: true
  validates :analysis_version, presence: true

  scope :recent_first, -> { order(generated_at: :desc) }
  scope :for_survey, ->(survey) { where(survey: survey) }

  def executive_summary
    insights_data["executive_summary"]
  end

  def urgency_level
    insights_data["urgency_level"] || "low"
  end

  def key_findings
    insights_data["key_findings"] || []
  end

  def satisfaction_drivers
    insights_data["satisfaction_drivers"] || []
  end

  def areas_for_improvement
    insights_data["areas_for_improvement"] || []
  end

  def risk_indicators
    insights_data["risk_indicators"] || []
  end

  def recommended_actions
    insights_data["recommended_actions"] || []
  end

  def department_insights
    insights_data["department_insights"] || {}
  end

  def response_rate_assessment
    insights_data["response_rate_assessment"]
  end

  def completion_time_assessment
    insights_data["completion_time_assessment"]
  end

  def self.latest_for_survey(survey)
    for_survey(survey).recent_first.first
  end
end
