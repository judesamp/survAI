class SurveyGeneratorController < ApplicationController
  before_action :set_organization

  def new
    # Simple form for AI prompt
  end

  def create
    prompt = params[:prompt]

    if prompt.blank?
      flash[:alert] = "Please enter a description for your survey"
      render :new, status: :unprocessable_entity
      return
    end

    begin
      # Generate survey using AI service
      generator = SurveyAiGenerator.new(
        prompt,
        organization: @organization,
        created_by: get_or_create_default_user
      )

      @survey = generator.generate

      redirect_to builder_survey_path(@survey),
                  notice: "Survey generated! Review and customize your questions below."

    rescue => e
      flash[:alert] = "Error generating survey: #{e.message}"
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_organization
    # For prototype, use default organization
    @organization = Organization.first_or_create!(
      name: "Default Organization",
      slug: "default-org",
      plan: "free"
    )
  end

  def get_or_create_default_user
    # For prototype, get existing user or create a simple one
    User.first || User.create!(
      email_address: "admin@survai.com",
      first_name: "Admin",
      last_name: "User",
      organization: @organization,
      role: "admin"
    )
  end
end