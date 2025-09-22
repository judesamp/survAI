class SurveyInsightsController < ApplicationController
  before_action :set_survey_insight, only: [:show]
  before_action :set_organization

  def index
    @survey_insights = SurveyInsight.includes(:survey, :generated_by)
                                   .joins(survey: :organization)
                                   .where(surveys: { organization_id: @organization.id })
                                   .recent_first
                                   .limit(50)
  end

  def show
    @survey = @survey_insight.survey
  end

  private

  def set_survey_insight
    @survey_insight = SurveyInsight.find(params[:id])
  end

  def set_organization
    # For prototype, use a default organization or create one
    @organization = Organization.first_or_create!(
      name: "Default Organization",
      slug: "default-org",
      plan: "free"
    )
  end
end