class QuestionsController < ApplicationController
  before_action :set_survey
  before_action :set_question, only: [:show, :edit, :update, :destroy, :move_up, :move_down, :summarize]

  def index
    @questions = @survey.questions.order(:position)
  end

  def show
  end

  def new
    @question = @survey.questions.build
  end

  def create
    @question = @survey.questions.build(question_params)

    if @question.save
      respond_to do |format|
        format.html { redirect_to builder_survey_path(@survey), notice: 'Question was successfully added.' }
        format.turbo_stream {
          @survey.questions.reload
          @questions = @survey.questions.order(:position)
          Rails.logger.info "DEBUG: Turbo Stream - Questions count: #{@questions.count}"

          render turbo_stream: [
            turbo_stream.replace("questions_list", partial: "questions/questions_list", locals: { questions: @questions, survey: @survey }),
            turbo_stream.replace("question_form", partial: "questions/question_form", locals: { survey: @survey, question: @survey.questions.build }),
            turbo_stream.replace("flash_messages", partial: "shared/flash", locals: { message: "Question added successfully!", type: "notice" })
          ]
        }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("question_form", partial: "questions/question_form", locals: { survey: @survey, question: @question }) }
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream { render partial: "questions/question_edit", locals: { survey: @survey, question: @question } }
    end
  end

  def update
    if ["pick_one", "pick_any"].include?(question_params[:question_type]) && (question_params[:options].nil? || question_params[:options].size < 2)
      @question.assign_attributes(question_params)
      @question.errors.add(:options, "must have at least two options for this question type.")
      render :edit, status: :unprocessable_entity and return
    end
    if @question.update(question_params)
      redirect_to builder_survey_path(@survey), notice: 'Question was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @question.destroy!
    respond_to do |format|
      format.html { redirect_to builder_survey_path(@survey), notice: 'Question was successfully removed.' }
      format.turbo_stream {
        @survey.questions.reload
        @questions = @survey.questions.order(:position)
        render turbo_stream: [
          turbo_stream.replace("questions_list", partial: "questions/questions_list", locals: { questions: @questions, survey: @survey }),
          turbo_stream.replace("flash_messages", partial: "shared/flash", locals: { message: "Question removed successfully!", type: "notice" })
        ]
      }
    end
  end

  def move_up
    previous_question = @survey.questions.where("position < ?", @question.position).order(:position).last
    if previous_question
      @question.position, previous_question.position = previous_question.position, @question.position
      @question.save!
      previous_question.save!
    end
    redirect_to builder_survey_path(@survey)
  end

  def move_down
    next_question = @survey.questions.where("position > ?", @question.position).order(:position).first
    if next_question
      @question.position, next_question.position = next_question.position, @question.position
      @question.save!
      next_question.save!
    end
    redirect_to builder_survey_path(@survey)
  end

  def summarize
    Rails.logger.info "=== Question Response Summarization Started ==="
    Rails.logger.info "Question: #{@question.question_text}"

    begin
      summarizer = ResponseSummarizer.new(@question)
      summary = summarizer.summarize

      if summary
        Rails.logger.info "=== Summarization Completed Successfully ==="
        render json: summary
      else
        Rails.logger.warn "=== No summary generated - insufficient data ==="
        render json: { error: "Insufficient responses for summarization" }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Summarization failed: #{e.message}"
      render json: { error: "Failed to generate summary" }, status: :internal_server_error
    end
  end

  private

  def set_survey
    @survey = Survey.find(params[:survey_id])
  end

  def set_question
    @question = @survey.questions.find(params[:id])
  end

  def question_params
    permitted_params = params.require(:question).permit(:question_text, :question_type, :required, :position, :options_text)

    if ["pick_one", "pick_any"].include?(permitted_params[:question_type])
      options_array = (permitted_params.delete(:options_text) || "").split("\n").map(&:strip).reject(&:blank?)
      permitted_params[:options] = options_array
    else
      permitted_params.delete(:options_text)
      permitted_params[:options] = []
    end

    permitted_params
  end
end