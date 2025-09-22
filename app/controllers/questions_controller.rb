class QuestionsController < ApplicationController
  before_action :set_survey
  before_action :set_question, only: [:show, :edit, :update, :destroy, :move_up, :move_down]

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

  private

  def set_survey
    @survey = Survey.find(params[:survey_id])
  end

  def set_question
    @question = @survey.questions.find(params[:id])
  end

  def question_params
    permitted_params = params.require(:question).permit(:question_text, :question_type, :required, :position)

    # Handle options for choice-based questions
    if params[:question][:options_text].present?
      options_array = params[:question][:options_text].split("\n").map(&:strip).reject(&:blank?)
      permitted_params[:options] = options_array
    end

    permitted_params
  end
end