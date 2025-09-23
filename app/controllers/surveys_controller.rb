class SurveysController < ApplicationController
  before_action :set_survey, only: [:show, :edit, :update, :destroy, :builder, :publish, :preview, :ai_review, :dashboard, :ai_analysis, :generate_data, :reset_assignments, :insights, :sentiment_analysis]
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

  def dashboard
    @assignments = @survey.assignments.includes(:user, :response)
    @questions = @survey.questions.includes(:answers)

    # Calculate metrics
    @metrics = {
      response_rate: @survey.response_rate,
      completion_rate: @survey.completion_rate,
      average_completion_time: @survey.average_completion_time,
      average_scale_score: @survey.average_scale_score,
      assignments_by_status: @survey.assignments_by_status
    }
  end

  def ai_analysis
    Rails.logger.info "=== AI Insights Analysis Started ==="

    # Check if we have recent insights (within last hour) to avoid re-generating
    recent_insight = @survey.survey_insights.recent_first.first
    if recent_insight && recent_insight.generated_at > 1.hour.ago
      Rails.logger.info "=== Using recent insights from database ==="
      @insights = recent_insight.insights_data
    else
      # Generate new insights
      current_user = get_or_create_default_user
      analyzer = SurveyInsightsAnalyzer.new(@survey, generated_by: current_user)
      @insights = analyzer.analyze
    end

    Rails.logger.info "=== AI Insights Analysis Completed ==="
    Rails.logger.info @insights.inspect

    respond_to do |format|
      format.turbo_stream {
        Rails.logger.info "=== Rendering AI Insights Turbo Stream ==="
        render turbo_stream: turbo_stream.replace("ai_insights_content", partial: "surveys/ai_insights", locals: { insights: @insights, survey: @survey })
      }
      format.html { redirect_to dashboard_survey_path(@survey), notice: "AI insights analysis completed!" }
    end
  end

  def generate_data
    assignments_count = params[:assignments_count].to_i
    responses_count = params[:responses_count].to_i

    # Validate input
    if assignments_count < 1 || assignments_count > 100
      respond_to do |format|
        format.html { redirect_to dashboard_survey_path(@survey), alert: "Number of assignments must be between 1 and 100." }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("data-generation-status",
            partial: "surveys/data_generation_error",
            locals: { error: "Number of assignments must be between 1 and 100.", job_id: "validation-error", survey: @survey })
        }
      end
      return
    end

    if responses_count < 0 || responses_count > assignments_count
      respond_to do |format|
        format.html { redirect_to dashboard_survey_path(@survey), alert: "Number of responses cannot exceed number of assignments." }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace("data-generation-status",
            partial: "surveys/data_generation_error",
            locals: { error: "Number of responses cannot exceed number of assignments.", job_id: "validation-error", survey: @survey })
        }
      end
      return
    end

    # Generate unique job ID
    job_id = SecureRandom.hex(8)

    # Start background job
    SurveyDataGenerationJob.perform_later(@survey.id, assignments_count, responses_count, job_id)

    respond_to do |format|
      format.html {
        redirect_to dashboard_survey_path(@survey),
        notice: "Data generation started in background. You'll see live updates below."
      }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace("data-generation-status",
          partial: "surveys/data_generation_progress",
          locals: { message: "Queued for processing...", percentage: 0, job_id: job_id, survey: @survey })
      }
    end
  end

  def reset_assignments
    begin
      ActiveRecord::Base.transaction do
        # First, clear the response references from assignments
        @survey.assignments.update_all(response_id: nil)
        # Then delete all responses and assignments for this survey
        @survey.responses.destroy_all
        @survey.assignments.destroy_all
      end

      redirect_to dashboard_survey_path(@survey),
                  notice: "All assignments and responses have been reset for this survey."
    rescue => e
      Rails.logger.error "Error resetting assignments: #{e.message}"
      redirect_to dashboard_survey_path(@survey), alert: "Error resetting assignments: #{e.message}"
    end
  end

  def insights
    @insights = @survey.survey_insights.recent_first.includes(:generated_by)
    @latest_insight = @insights.first
  end

  def sentiment_analysis
    # Check if we have cached results first
    @sentiment_data = Rails.cache.read("sentiment_analysis_#{@survey.id}")

    if @sentiment_data
      Rails.logger.info "=== Using cached sentiment analysis for Survey #{@survey.id} ==="
      return # Render the view with cached data
    end

    # Check if we have sufficient responses for meaningful analysis
    if @survey.responses.count < 3
      redirect_to dashboard_survey_path(@survey),
                  alert: "Sentiment analysis requires at least 3 responses. Generate more data or collect more responses first."
      return
    end

    # Check if we're starting a new analysis
    if params[:start_analysis] == 'true'
      Rails.logger.info "=== Starting background sentiment analysis for Survey #{@survey.id} ==="

      # Generate unique job ID
      job_id = SecureRandom.hex(8)

      # Start background job
      SentimentAnalysisJob.perform_later(@survey.id, job_id)

      # Always respond with turbo_stream to replace the button with progress
      render turbo_stream: turbo_stream.replace("sentiment-analysis-status",
        partial: "surveys/sentiment_analysis_progress",
        locals: { message: "Queued for processing...", percentage: 0, job_id: job_id, survey: @survey })
      return
    end

    # If no cached data and not starting analysis, show the start page
    @show_start_page = true
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