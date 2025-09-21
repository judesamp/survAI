class SurveysController < ApplicationController
  before_action :set_survey, only: [:show, :edit, :update, :destroy, :builder, :publish, :preview, :ai_review]
  before_action :set_organization

  def index
    @surveys = @organization.surveys.order(created_at: :desc)
  end

  def show
    @questions = @survey.questions.order(:position)
  end

  def new
    @survey = @organization.surveys.build
  end

  def create
    @survey = @organization.surveys.build(survey_params)
    # For prototype, set a default user as creator or create a simple one
    @survey.created_by = get_or_create_default_user

    if @survey.save
      redirect_to builder_survey_path(@survey), notice: 'Survey was successfully created. Now add some questions!'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @survey.update(survey_params)
      redirect_to @survey, notice: 'Survey was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @survey.destroy!
    redirect_to surveys_url, notice: 'Survey was successfully deleted.'
  end

  def builder
    @questions = @survey.questions.order(:position)
    @question = @survey.questions.build
  end

  def publish
    if @survey.draft?
      @survey.published!
      redirect_to @survey, notice: 'Survey was successfully published.'
    else
      redirect_to @survey, alert: 'Survey is already published.'
    end
  end

  def preview
    @questions = @survey.questions.order(:position)
  end

  def ai_review
    Rails.logger.info "=== AI Review Started ==="
    reviewer = SurveyAiReviewer.new(@survey)
    @review = reviewer.review
    Rails.logger.info "=== AI Review Completed ==="
    Rails.logger.info @review.inspect

    respond_to do |format|
      format.turbo_stream {
        Rails.logger.info "=== Rendering Turbo Stream ==="
        render turbo_stream: turbo_stream.replace("ai_review_content", partial: "surveys/ai_review", locals: { review: @review, survey: @survey })
      }
      format.html { redirect_to @survey, notice: "AI review completed!" }
    end
  end

  private

  def set_survey
    @survey = Survey.find(params[:id])
  end

  def set_organization
    # For prototype, use a default organization or create one
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

  def survey_params
    params.require(:survey).permit(:title, :description, :status, :visibility,
                                   :starts_at, :ends_at, :response_limit)
  end
end