# AI-Assisted Survey Creation Prototype Plan

## Overview
A Rails 8 application prototype for AI-assisted survey creation with real-time generation progress updates and in-place editing capabilities.

## Core Features
1. **Intelligent Survey Definition Form** - Smart defaults with optional custom control over question distribution
2. **Real-time AI Generation** - Step-by-step survey creation with live progress updates
3. **In-place Editing** - Edit generated survey content directly
4. **Extensible Question Types** - Plugin architecture for easy addition of new question types

## UI/UX Design Philosophy

### The Problem We're Solving
Traditional survey builders require users to manually create every question. Our approach lets users describe their goals and have AI generate an appropriate survey, while maintaining control over the structure when needed.

### Key Design Decisions

1. **Survey Size over Exact Count**: Users select rough size (short/medium/long) rather than exact question counts, reducing cognitive load

2. **Progressive Disclosure**: Simple AI-optimized path by default, with custom distribution available for power users

3. **Smart Distribution Logic**: When using AI-optimized mode, the system intelligently distributes questions based on:
   - Survey goals from the prompt
   - Best practices for survey design
   - Appropriate mix of question types for the topic

4. **No Ambiguity**: Clear distinction between AI-optimized and custom modes prevents confusion about question distribution

## Architecture

### Database Schema

```sql
# surveys table
- id (bigint, primary key)
- title (string)
- description (text)
- prompt (text) - user's original prompt
- survey_size (string) - 'short', 'medium', 'long'
- distribution_strategy (string) - 'ai_optimized', 'custom'
- custom_distribution (jsonb) - {open_ended: 3, sliding_scale: 2} when using custom
- status (string) - draft, generating, ready, published
- generation_progress (jsonb) - tracks generation steps
- generated_questions (jsonb) - array of question objects
- created_at, updated_at

# survey_responses table
- id (bigint, primary key)
- survey_id (bigint, foreign key)
- response_data (jsonb)
- respondent_email (string, optional)
- created_at, updated_at

# survey_generation_jobs table (for tracking)
- id (bigint, primary key)
- survey_id (bigint, foreign key)
- status (string)
- current_step (string)
- progress_percentage (integer)
- error_message (text)
- created_at, updated_at
```

### Real-time Generation Flow

```mermaid
User Submits Form -> Controller Creates Survey (status: generating)
                  -> Enqueues SurveyGenerationJob
                  -> Redirects to survey#show (generation view)

SurveyGenerationJob:
  Step 1: "Analyzing prompt..." -> Broadcast progress
  Step 2: "Creating survey structure..." -> Broadcast progress
  Step 3: "Generating open-ended questions..." -> Broadcast progress
  Step 4: "Generating sliding scale questions..." -> Broadcast progress
  Step 5: "Adding title and description..." -> Broadcast progress
  Step 6: "Reviewing for quality..." -> Broadcast progress
  Step 7: "Finalizing survey..." -> Mark complete, broadcast final survey
```

### AI Generation Steps (Detailed)

```ruby
class SurveyGenerationJob < ApplicationJob
  def perform(survey_id)
    survey = Survey.find(survey_id)

    # Step 1: Analyze prompt (10%)
    broadcast_progress(survey, "Analyzing your requirements...", 10)
    prompt_analysis = analyze_prompt(survey.prompt)

    # Step 2: Determine question distribution (20%)
    broadcast_progress(survey, "Planning question distribution...", 20)
    distribution = calculate_distribution(survey)

    # Step 3: Generate questions by type (30-70%)
    questions = []
    progress = 30

    distribution.each do |type, count|
      next if count == 0
      type_name = QuestionTypes::Registry.get(type).display_name
      broadcast_progress(survey, "Creating #{count} #{type_name} questions...", progress)
      questions += generate_questions_for_type(type, count, prompt_analysis)
      progress += 20
    end

    # Step 4: Add metadata (80%)
    broadcast_progress(survey, "Adding title and description...", 80)
    add_survey_metadata(survey, prompt_analysis)

    # Step 5: Quality review (90%)
    broadcast_progress(survey, "Reviewing for quality and coherence...", 90)
    review_and_optimize(survey, questions)

    # Step 6: Finalize (100%)
    broadcast_progress(survey, "Survey ready!", 100, status: 'ready')
    broadcast_final_survey(survey)
  end

  private

  def calculate_distribution(survey)
    if survey.distribution_strategy == 'custom'
      survey.custom_distribution
    else
      # AI-optimized distribution based on survey size
      total_questions = case survey.survey_size
                       when 'short' then rand(5..7)
                       when 'medium' then rand(8..12)
                       when 'long' then rand(15..20)
                       end

      # Intelligent distribution based on prompt analysis
      # This would use AI to determine optimal mix
      determine_optimal_distribution(total_questions)
    end
  end

  def determine_optimal_distribution(total_questions)
    # Use Ollama to analyze the prompt and determine best distribution
    prompt = <<~PROMPT
      Given this survey description: "#{@survey.prompt}"

      Determine the optimal distribution of #{total_questions} questions across these types:
      #{QuestionTypes::Registry.all.keys.join(', ')}

      Return ONLY a JSON object with question counts like: {"open_ended": 3, "sliding_scale": 2}
    PROMPT

    response = @ollama_client.generate(
      model: 'llama3.2',  # or 'mistral', 'codellama', etc.
      prompt: prompt
    )

    JSON.parse(response['response'])
  end

  def broadcast_progress(survey, message, percentage, status: 'generating')
    survey.update(
      status: status,
      generation_progress: {
        message: message,
        percentage: percentage,
        timestamp: Time.current
      }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "survey_#{survey.id}_progress",
      target: "generation_progress",
      partial: "surveys/generation_progress",
      locals: { survey: survey }
    )
  end
end
```

### Question Type Architecture

```ruby
# app/models/question_types/base.rb
module QuestionTypes
  class Base
    attr_reader :question_data

    def initialize(question_data)
      @question_data = question_data
    end

    class << self
      def type_key
        raise NotImplementedError
      end

      def display_name
        raise NotImplementedError
      end

      def default_enabled?
        true
      end

      def ai_generation_prompt
        # Returns prompt snippet for AI to generate this type
      end
    end

    def render_form_input
      # Returns HTML for form input
    end

    def render_editable
      # Returns HTML for in-place editing
    end

    def validate_response(response)
      # Validates a response
    end
  end
end

# app/models/question_types/open_ended.rb
module QuestionTypes
  class OpenEnded < Base
    def self.type_key
      :open_ended
    end

    def self.display_name
      "Open Ended"
    end

    def self.ai_generation_prompt
      "Create an open-ended question that allows for detailed text responses"
    end

    def render_editable
      <<-HTML
        <div class="question-container" data-controller="inline-edit">
          <h3 data-inline-edit-target="editable"
              data-field="text">#{question_data['text']}</h3>
          <textarea class="form-input" placeholder="Response will go here..." disabled></textarea>
        </div>
      HTML
    end
  end
end

# app/models/question_types/sliding_scale.rb
module QuestionTypes
  class SlidingScale < Base
    def self.type_key
      :sliding_scale
    end

    def self.display_name
      "Sliding Scale (1-10)"
    end

    def self.ai_generation_prompt
      "Create a question suitable for a 1-10 sliding scale response"
    end

    def render_editable
      <<-HTML
        <div class="question-container" data-controller="inline-edit">
          <h3 data-inline-edit-target="editable"
              data-field="text">#{question_data['text']}</h3>
          <div class="scale-labels">
            <span data-inline-edit-target="editable"
                  data-field="min_label">#{question_data['min_label']}</span>
            <input type="range" min="1" max="10" disabled>
            <span data-inline-edit-target="editable"
                  data-field="max_label">#{question_data['max_label']}</span>
          </div>
        </div>
      HTML
    end
  end
end

# app/models/question_types/registry.rb
module QuestionTypes
  class Registry
    class << self
      def all
        @types ||= {}
      end

      def register(type_class)
        all[type_class.type_key] = type_class
      end

      def get(type_key)
        all[type_key]
      end

      def enabled_by_default
        all.select { |_, klass| klass.default_enabled? }
      end
    end
  end
end

# Auto-register question types
QuestionTypes::Registry.register(QuestionTypes::OpenEnded)
QuestionTypes::Registry.register(QuestionTypes::SlidingScale)
```

### Frontend Architecture

#### Stimulus Controllers

```javascript
// app/javascript/controllers/survey_builder_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "prompt",
    "sizeOption",
    "strategyOption",
    "customDistribution",
    "questionSlider",
    "questionCount",
    "totalCount",
    "submitButton"
  ]

  connect() {
    this.validateForm()
    this.updateTotalCount()
  }

  validateForm() {
    const promptValid = this.promptTarget.value.length > 10
    const strategyValid = this.hasSelectedStrategy()

    // If custom strategy, ensure at least one question type has count > 0
    let distributionValid = true
    if (this.isCustomStrategy()) {
      distributionValid = this.getTotalQuestionCount() > 0
    }

    this.submitButtonTarget.disabled = !(promptValid && strategyValid && distributionValid)
  }

  hasSelectedStrategy() {
    return this.strategyOptionTargets.some(radio => radio.checked)
  }

  isCustomStrategy() {
    const customRadio = this.strategyOptionTargets.find(r => r.value === 'custom')
    return customRadio && customRadio.checked
  }

  toggleCustomDistribution(event) {
    const isCustom = event.target.value === 'custom'

    if (isCustom) {
      this.customDistributionTarget.classList.remove('hidden')
    } else {
      this.customDistributionTarget.classList.add('hidden')
    }

    this.validateForm()
  }

  updateQuestionCount(event) {
    const slider = event.target
    const type = slider.dataset.questionType
    const value = slider.value

    // Update the display
    const countDisplay = this.questionCountTargets.find(
      el => el.dataset.questionType === type
    )
    if (countDisplay) {
      countDisplay.textContent = value
    }

    this.updateTotalCount()
    this.validateForm()
  }

  updateTotalCount() {
    if (!this.hasCustomDistributionTarget) return

    const total = this.getTotalQuestionCount()
    this.totalCountTarget.textContent = total
  }

  getTotalQuestionCount() {
    return this.questionSliderTargets.reduce((sum, slider) => {
      return sum + parseInt(slider.value || 0)
    }, 0)
  }

  async submit(event) {
    event.preventDefault()

    // Show loading state
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = "Creating survey..."

    // Submit form (will redirect to generation page)
    this.element.requestSubmit()
  }
}

// app/javascript/controllers/generation_progress_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progressBar", "message", "surveyContent"]

  connect() {
    // Subscribe to Turbo Stream updates
    this.subscription = this.subscribeTo(this.data.get("survey-id"))
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  subscribeTo(surveyId) {
    return window.Turbo.StreamActions.subscribe({
      channel: "SurveyProgressChannel",
      survey_id: surveyId
    })
  }

  updateProgress(event) {
    const { percentage, message } = event.detail
    this.progressBarTarget.style.width = `${percentage}%`
    this.messageTarget.textContent = message
  }
}

// app/javascript/controllers/inline_edit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editable"]

  connect() {
    this.makeEditable()
  }

  makeEditable() {
    this.editableTargets.forEach(element => {
      element.contentEditable = true
      element.addEventListener("blur", this.save.bind(this))
      element.addEventListener("keydown", this.handleKeydown.bind(this))
    })
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      event.target.blur()
    }
  }

  async save(event) {
    const element = event.target
    const field = element.dataset.field
    const value = element.textContent.trim()
    const questionId = element.closest("[data-question-id]")?.dataset.questionId

    // Save via AJAX
    const response = await fetch(`/surveys/${this.surveyId}/questions/${questionId}`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
      },
      body: JSON.stringify({ question: { [field]: value } })
    })

    if (response.ok) {
      // Show brief success indicator
      element.style.backgroundColor = "#10b98120"
      setTimeout(() => {
        element.style.backgroundColor = ""
      }, 500)
    }
  }

  get surveyId() {
    return this.element.dataset.surveyId
  }
}
```

### Views Structure

```erb
<!-- app/views/surveys/new.html.erb -->
<div class="max-w-2xl mx-auto p-6">
  <h1 class="text-3xl font-bold mb-6">Create AI Survey</h1>

  <%= form_with model: @survey, data: {
    controller: "survey-builder",
    action: "submit->survey-builder#submit"
  } do |f| %>

    <!-- Step 1: Survey Prompt -->
    <div class="mb-6">
      <%= f.label :prompt, "What's your survey about?", class: "block mb-2 font-medium text-lg" %>
      <%= f.text_area :prompt,
          rows: 4,
          class: "w-full p-3 border rounded-lg",
          placeholder: "Describe what information you're trying to gather and the purpose of this survey...",
          data: {
            survey_builder_target: "prompt",
            action: "input->survey-builder#validateForm"
          } %>
    </div>

    <!-- Step 2: Survey Size -->
    <div class="mb-6">
      <%= f.label :survey_size, "Survey length", class: "block mb-2 font-medium text-lg" %>
      <div class="grid grid-cols-3 gap-3">
        <label class="border rounded-lg p-4 cursor-pointer hover:bg-blue-50 transition"
               data-survey-builder-target="sizeOption">
          <%= f.radio_button :survey_size, "short", class: "hidden peer" %>
          <div class="text-center peer-checked:text-blue-600 peer-checked:font-semibold">
            <div class="font-medium">Short</div>
            <div class="text-sm text-gray-500">5-7 questions</div>
          </div>
        </label>

        <label class="border rounded-lg p-4 cursor-pointer hover:bg-blue-50 transition"
               data-survey-builder-target="sizeOption">
          <%= f.radio_button :survey_size, "medium", checked: true, class: "hidden peer" %>
          <div class="text-center peer-checked:text-blue-600 peer-checked:font-semibold">
            <div class="font-medium">Medium</div>
            <div class="text-sm text-gray-500">8-12 questions</div>
          </div>
        </label>

        <label class="border rounded-lg p-4 cursor-pointer hover:bg-blue-50 transition"
               data-survey-builder-target="sizeOption">
          <%= f.radio_button :survey_size, "long", class: "hidden peer" %>
          <div class="text-center peer-checked:text-blue-600 peer-checked:font-semibold">
            <div class="font-medium">Long</div>
            <div class="text-sm text-gray-500">15-20 questions</div>
          </div>
        </label>
      </div>
    </div>

    <!-- Step 3: Distribution Strategy -->
    <div class="mb-6">
      <%= f.label :distribution_strategy, "Question distribution", class: "block mb-2 font-medium text-lg" %>

      <!-- AI Optimized Option -->
      <label class="block border rounded-lg p-4 mb-3 cursor-pointer hover:bg-green-50 transition">
        <%= f.radio_button :distribution_strategy, "ai_optimized", checked: true,
            class: "hidden peer",
            data: {
              survey_builder_target: "strategyOption",
              action: "change->survey-builder#toggleCustomDistribution"
            } %>
        <div class="peer-checked:text-green-600">
          <div class="font-medium flex items-center">
            <span class="mr-2">✨</span> AI Optimized
            <span class="ml-2 text-xs bg-green-100 text-green-700 px-2 py-1 rounded">Recommended</span>
          </div>
          <div class="text-sm text-gray-500 mt-1">
            Let AI choose the best mix of question types based on your survey goals
          </div>
        </div>
      </label>

      <!-- Custom Distribution Option -->
      <label class="block border rounded-lg p-4 cursor-pointer hover:bg-blue-50 transition">
        <%= f.radio_button :distribution_strategy, "custom",
            class: "hidden peer",
            data: {
              survey_builder_target: "strategyOption",
              action: "change->survey-builder#toggleCustomDistribution"
            } %>
        <div class="peer-checked:text-blue-600">
          <div class="font-medium flex items-center">
            <span class="mr-2">⚙️</span> Custom Mix
          </div>
          <div class="text-sm text-gray-500 mt-1">
            Specify exactly how many of each question type you want
          </div>
        </div>
      </label>
    </div>

    <!-- Custom Distribution Controls (hidden by default) -->
    <div class="mb-6 hidden" data-survey-builder-target="customDistribution">
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="font-medium mb-3">Specify question counts:</h4>

        <% QuestionTypes::Registry.all.each do |key, type_class| %>
          <div class="flex items-center justify-between mb-3">
            <label class="font-medium"><%= type_class.display_name %></label>
            <div class="flex items-center gap-3">
              <%= f.range_field "custom_distribution[#{key}]",
                  value: 0,
                  min: 0,
                  max: 10,
                  class: "w-32",
                  data: {
                    survey_builder_target: "questionSlider",
                    action: "input->survey-builder#updateQuestionCount",
                    question_type: key
                  } %>
              <span class="w-12 text-center font-semibold"
                    data-survey-builder-target="questionCount"
                    data-question-type="<%= key %>">0</span>
            </div>
          </div>
        <% end %>

        <div class="mt-4 pt-3 border-t">
          <div class="flex justify-between font-semibold">
            <span>Total questions:</span>
            <span data-survey-builder-target="totalCount">0</span>
          </div>
        </div>
      </div>
    </div>

    <%= f.submit "Generate Survey",
        class: "w-full bg-blue-500 text-white py-3 px-6 rounded-lg font-medium hover:bg-blue-600 disabled:opacity-50 transition",
        data: { survey_builder_target: "submitButton" } %>
  <% end %>
</div>

<!-- app/views/surveys/show.html.erb (generation in progress) -->
<div id="survey_generation"
     class="max-w-4xl mx-auto p-6"
     data-controller="generation-progress"
     data-generation-progress-survey-id="<%= @survey.id %>">

  <%= turbo_stream_from "survey_#{@survey.id}_progress" %>

  <div id="generation_progress">
    <%= render "generation_progress", survey: @survey %>
  </div>

  <div id="survey_content" class="mt-8">
    <% if @survey.ready? %>
      <%= render "editable_survey", survey: @survey %>
    <% end %>
  </div>
</div>

<!-- app/views/surveys/_generation_progress.html.erb -->
<div class="bg-white rounded-lg shadow p-6">
  <h2 class="text-2xl font-bold mb-4">Generating Your Survey</h2>

  <div class="mb-4">
    <div class="bg-gray-200 rounded-full h-4 overflow-hidden">
      <div class="bg-blue-500 h-full transition-all duration-500"
           style="width: <%= survey.generation_progress['percentage'] || 0 %>%"
           data-generation-progress-target="progressBar"></div>
    </div>
  </div>

  <p class="text-gray-600" data-generation-progress-target="message">
    <%= survey.generation_progress['message'] || 'Starting generation...' %>
  </p>
</div>

<!-- app/views/surveys/_editable_survey.html.erb -->
<div class="bg-white rounded-lg shadow p-6"
     data-controller="inline-edit"
     data-survey-id="<%= survey.id %>">

  <h1 class="text-3xl font-bold mb-2"
      data-inline-edit-target="editable"
      data-field="title">
    <%= survey.title %>
  </h1>

  <p class="text-gray-600 mb-6"
     data-inline-edit-target="editable"
     data-field="description">
    <%= survey.description %>
  </p>

  <div class="space-y-6">
    <% survey.generated_questions.each_with_index do |question, index| %>
      <div class="border rounded-lg p-4" data-question-id="<%= question['id'] %>">
        <div class="font-medium mb-2">Question <%= index + 1 %></div>
        <%= render_question_editable(question) %>
      </div>
    <% end %>
  </div>

  <div class="mt-8 flex justify-between">
    <%= link_to "Preview Survey", preview_survey_path(survey),
        class: "bg-gray-500 text-white py-2 px-6 rounded-lg" %>
    <%= button_to "Publish Survey", publish_survey_path(survey),
        method: :post,
        class: "bg-green-500 text-white py-2 px-6 rounded-lg" %>
  </div>
</div>
```

### Controllers

```ruby
# app/controllers/surveys_controller.rb
class SurveysController < ApplicationController
  def new
    @survey = Survey.new
  end

  def create
    @survey = Survey.new(survey_params)
    @survey.status = 'generating'

    # Clean up custom_distribution if using AI-optimized strategy
    if @survey.distribution_strategy == 'ai_optimized'
      @survey.custom_distribution = nil
    end

    if @survey.save
      SurveyGenerationJob.perform_later(@survey.id)
      redirect_to @survey
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @survey = Survey.find(params[:id])

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update_question
    @survey = Survey.find(params[:survey_id])
    question_id = params[:id]

    # Find and update the specific question in the JSONB array
    questions = @survey.generated_questions
    question = questions.find { |q| q['id'] == question_id }

    if question
      question.merge!(question_params)
      @survey.update(generated_questions: questions)
      head :ok
    else
      head :not_found
    end
  end

  private

  def survey_params
    params.require(:survey).permit(
      :prompt,
      :survey_size,
      :distribution_strategy,
      custom_distribution: {}
    )
  end

  def question_params
    params.require(:question).permit(:text, :min_label, :max_label)
  end
end
```

### AI Service Integration (Using Ollama)

```ruby
# app/services/survey_generator_service.rb
class SurveyGeneratorService
  def initialize(survey)
    @survey = survey
    @ollama_client = OllamaClient.new(
      base_url: ENV.fetch('OLLAMA_BASE_URL', 'http://localhost:11434')
    )
  end

  def generate_survey
    # Step-by-step generation with progress updates
    analyze_requirements
    create_structure
    generate_questions_by_type
    add_metadata
    review_and_optimize
    finalize
  end

  private

  def analyze_requirements
    broadcast_progress("Analyzing your requirements...", 10)

    prompt = <<~PROMPT
      You are a survey creation expert. Analyze the following survey prompt and identify:
      1. Key themes and topics
      2. Survey objectives
      3. Appropriate question types
      4. Target audience

      Survey prompt: #{@survey.prompt}

      Return your analysis as a JSON object.
    PROMPT

    response = @ollama_client.generate(
      model: 'llama3.2',
      prompt: prompt,
      format: 'json'
    )

    @analysis = JSON.parse(response['response'])
  end

  def generate_questions_by_type
    questions = []

    if @survey.enabled_question_types['open_ended']
      broadcast_progress("Creating open-ended questions...", 40)
      questions += generate_open_ended_questions
    end

    if @survey.enabled_question_types['sliding_scale']
      broadcast_progress("Creating sliding scale questions...", 60)
      questions += generate_sliding_scale_questions
    end

    @survey.update(generated_questions: questions)
  end

  def generate_open_ended_questions
    count = calculate_questions_per_type('open_ended')

    prompt = <<~PROMPT
      Based on this survey analysis: #{@analysis.to_json}

      Generate #{count} open-ended survey questions that:
      - Allow for detailed text responses
      - Gather qualitative insights
      - Explore opinions and experiences

      Return as a JSON array of question objects with 'id', 'type', and 'text' fields.
    PROMPT

    response = @ollama_client.generate(
      model: 'llama3.2',
      prompt: prompt,
      format: 'json'
    )

    JSON.parse(response['response'])
  end

  def broadcast_progress(message, percentage)
    @survey.update(
      generation_progress: {
        message: message,
        percentage: percentage,
        timestamp: Time.current
      }
    )

    ActionCable.server.broadcast(
      "survey_#{@survey.id}_progress",
      {
        message: message,
        percentage: percentage
      }
    )
  end
end
```

## Implementation Phases

### Phase 1: MVP with Prompt-Based Generation

#### Phase 1.1: Foundation (Day 1)
- [ ] Set up database migrations
- [ ] Create Survey and SurveyResponse models
- [ ] Implement question type registry system
- [ ] Create basic SurveysController
- [ ] Set up routes

#### Phase 1.2: Form & Basic Flow (Day 2)
- [ ] Build survey creation form with Tailwind
- [ ] Implement survey-builder Stimulus controller
- [ ] Create question type toggle components
- [ ] Add form validation

#### Phase 1.3: Ollama Integration & Background Jobs (Day 3)
- [ ] Set up Ollama locally
- [ ] Create OllamaClient class
- [ ] Create SurveyGeneratorService with prompt-based generation
- [ ] Implement SurveyGenerationJob with Solid Queue
- [ ] Add step-by-step generation logic

#### Phase 1.4: Real-time Updates (Day 4)
- [ ] Configure Turbo Streams for progress updates
- [ ] Implement generation progress broadcasting
- [ ] Create progress UI components
- [ ] Add generation status tracking

#### Phase 1.5: In-place Editing (Day 5)
- [ ] Build inline-edit Stimulus controller
- [ ] Implement auto-save functionality
- [ ] Add visual feedback for saves
- [ ] Create editable survey view

#### Phase 1.6: Polish & Testing (Day 6)
- [ ] Add error handling
- [ ] Implement loading states
- [ ] Add success messages
- [ ] Write integration tests
- [ ] Style refinements

### Phase 2: Tool-Based Generation (Future Enhancement)

#### Overview
Migrate from prompt-based generation to tool/function calling for more structured and reliable AI interactions. This phase prepares the codebase for when Ollama (or alternative LLMs) support robust function calling.

#### Phase 2.1: Architecture Refactoring

```ruby
# app/services/ai_generator_interface.rb
module AiGeneratorInterface
  class Base
    def generate(operation, params)
      strategy = select_strategy
      strategy.execute(operation, params)
    end

    private

    def select_strategy
      if tool_calling_available?
        ToolBasedStrategy.new(@client)
      else
        PromptBasedStrategy.new(@client)
      end
    end
  end
end

# app/services/strategies/tool_based_strategy.rb
class ToolBasedStrategy
  AVAILABLE_TOOLS = [
    {
      name: "generate_survey_title",
      description: "Generate a title for the survey",
      parameters: {
        type: "object",
        properties: {
          context: { type: "string", description: "Survey context and goals" },
          tone: { type: "string", enum: ["formal", "casual", "professional"] }
        }
      }
    },
    {
      name: "generate_questions",
      description: "Generate survey questions of a specific type",
      parameters: {
        type: "object",
        properties: {
          question_type: { type: "string", enum: ["open_ended", "sliding_scale"] },
          count: { type: "integer", minimum: 1, maximum: 20 },
          context: { type: "string" }
        }
      }
    },
    {
      name: "validate_survey_coherence",
      description: "Check if survey questions align with stated goals",
      parameters: {
        type: "object",
        properties: {
          survey_goal: { type: "string" },
          questions: { type: "array", items: { type: "object" } }
        }
      }
    },
    {
      name: "optimize_question_order",
      description: "Arrange questions in logical flow",
      parameters: {
        type: "object",
        properties: {
          questions: { type: "array" },
          strategy: { type: "string", enum: ["funnel", "random", "grouped_by_type"] }
        }
      }
    }
  ]

  def execute(operation, params)
    case operation
    when :generate_title
      @client.call_function(
        function: "generate_survey_title",
        arguments: { context: params[:context], tone: params[:tone] }
      )
    when :generate_questions
      @client.call_function(
        function: "generate_questions",
        arguments: {
          question_type: params[:type],
          count: params[:count],
          context: params[:context]
        }
      )
    when :validate_coherence
      @client.call_function(
        function: "validate_survey_coherence",
        arguments: {
          survey_goal: params[:goal],
          questions: params[:questions]
        }
      )
    end
  end
end

# app/services/strategies/prompt_based_strategy.rb
class PromptBasedStrategy
  def execute(operation, params)
    # Current implementation - convert to prompts
    prompt = build_prompt_for(operation, params)
    @client.generate(prompt: prompt, format: 'json')
  end
end
```

#### Phase 2.2: Enhanced Ollama Client

```ruby
# app/lib/ollama_client_enhanced.rb
class OllamaClientEnhanced < OllamaClient
  def supports_tools?
    # Check if current model supports function calling
    model_info = get_model_info(@model)
    model_info['capabilities']&.include?('tools')
  end

  def call_function(function:, arguments:)
    if supports_tools?
      # Use native function calling
      chat(
        model: @model,
        messages: [{
          role: "user",
          content: "Execute function"
        }],
        tools: [find_tool_definition(function)],
        tool_choice: { type: "function", function: { name: function } },
        arguments: arguments
      )
    else
      # Fallback to prompt-based simulation
      prompt = simulate_function_call(function, arguments)
      generate(prompt: prompt, format: 'json')
    end
  end

  private

  def simulate_function_call(function, arguments)
    # Convert function call to structured prompt
    <<~PROMPT
      You are simulating the function: #{function}
      Arguments: #{arguments.to_json}

      Execute this function and return the result as JSON.
      Be consistent with the expected output format.
    PROMPT
  end
end
```

#### Phase 2.3: Tool Definitions for Survey Generation

```ruby
# app/services/survey_generation_tools.rb
class SurveyGenerationTools
  class << self
    def all_tools
      [
        analyze_prompt_tool,
        generate_title_tool,
        generate_questions_tool,
        validate_coherence_tool,
        optimize_order_tool,
        generate_descriptions_tool
      ]
    end

    private

    def analyze_prompt_tool
      {
        type: "function",
        function: {
          name: "analyze_survey_prompt",
          description: "Analyze user's survey requirements to extract goals, topics, and constraints",
          parameters: {
            type: "object",
            properties: {
              prompt: {
                type: "string",
                description: "The user's survey description"
              }
            },
            required: ["prompt"]
          },
          returns: {
            type: "object",
            properties: {
              goals: { type: "array", items: { type: "string" } },
              topics: { type: "array", items: { type: "string" } },
              target_audience: { type: "string" },
              suggested_question_types: { type: "array", items: { type: "string" } },
              tone: { type: "string" }
            }
          }
        }
      }
    end

    def generate_questions_tool
      {
        type: "function",
        function: {
          name: "generate_survey_questions",
          description: "Generate specific types of survey questions",
          parameters: {
            type: "object",
            properties: {
              question_type: {
                type: "string",
                enum: ["open_ended", "sliding_scale", "multiple_choice", "ranking"],
                description: "Type of questions to generate"
              },
              count: {
                type: "integer",
                minimum: 1,
                maximum: 20,
                description: "Number of questions to generate"
              },
              context: {
                type: "object",
                description: "Context from prompt analysis"
              }
            },
            required: ["question_type", "count", "context"]
          },
          returns: {
            type: "array",
            items: {
              type: "object",
              properties: {
                id: { type: "string" },
                type: { type: "string" },
                text: { type: "string" },
                required: { type: "boolean" },
                metadata: { type: "object" }
              }
            }
          }
        }
      }
    end
  end
end
```

#### Phase 2.4: Migration Strategy

```ruby
# app/services/survey_generator_service_v2.rb
class SurveyGeneratorServiceV2 < SurveyGeneratorService
  def initialize(survey)
    super
    @ai_interface = AiGeneratorInterface::Base.new(@ollama_client)
  end

  def generate_survey
    # Step 1: Analyze requirements using tools
    analysis = @ai_interface.generate(
      :analyze_prompt,
      { prompt: @survey.prompt }
    )
    broadcast_progress("Analysis complete", 20)

    # Step 2: Generate title using tools
    title_result = @ai_interface.generate(
      :generate_title,
      { context: analysis, tone: analysis['tone'] }
    )
    @survey.update(title: title_result['title'])
    broadcast_progress("Title generated", 30)

    # Step 3: Generate questions by type using tools
    questions = []
    distribution = calculate_distribution(@survey)

    distribution.each do |type, count|
      result = @ai_interface.generate(
        :generate_questions,
        { type: type, count: count, context: analysis }
      )
      questions.concat(result['questions'])
      broadcast_progress("Generated #{type} questions", 60)
    end

    # Step 4: Validate coherence using tools
    validation = @ai_interface.generate(
      :validate_coherence,
      { goal: @survey.prompt, questions: questions }
    )

    if validation['issues'].any?
      # Auto-correct issues
      questions = apply_corrections(questions, validation['suggestions'])
    end
    broadcast_progress("Validation complete", 80)

    # Step 5: Optimize order using tools
    optimized = @ai_interface.generate(
      :optimize_order,
      { questions: questions, strategy: 'funnel' }
    )

    @survey.update(generated_questions: optimized['questions'])
    broadcast_progress("Survey ready!", 100)
  end
end
```

#### Phase 2.5: Feature Flags for Gradual Migration

```ruby
# config/initializers/feature_flags.rb
Rails.application.config.feature_flags = {
  use_tool_based_generation: ENV['USE_AI_TOOLS'] == 'true',
  tool_calling_models: ['gpt-4', 'claude-3', 'llama3-tools'], # Future models
  fallback_to_prompts: true
}

# app/controllers/surveys_controller.rb
class SurveysController < ApplicationController
  def create
    @survey = Survey.new(survey_params)

    if @survey.save
      job_class = feature_enabled?(:use_tool_based_generation) ?
                  SurveyGenerationJobV2 :
                  SurveyGenerationJob

      job_class.perform_later(@survey.id)
      redirect_to @survey
    else
      render :new
    end
  end

  private

  def feature_enabled?(flag)
    Rails.application.config.feature_flags[flag]
  end
end
```

#### Phase 2.6: Testing Infrastructure

```ruby
# test/services/tool_based_generation_test.rb
class ToolBasedGenerationTest < ActiveSupport::TestCase
  setup do
    @mock_client = MockOllamaClient.new(supports_tools: true)
    @service = SurveyGeneratorServiceV2.new(surveys(:one))
    @service.instance_variable_set(:@ollama_client, @mock_client)
  end

  test "uses tools when available" do
    @mock_client.expect_tool_call(
      "analyze_survey_prompt",
      with: { prompt: "Customer satisfaction survey" }
    )

    @service.analyze_requirements

    assert @mock_client.verify
  end

  test "falls back to prompts when tools unavailable" do
    @mock_client.supports_tools = false

    @mock_client.expect_prompt_generation(
      matching: /analyze.*customer satisfaction/i
    )

    @service.analyze_requirements

    assert @mock_client.verify
  end
end
```

#### Benefits of Phase 2 Architecture:

1. **Backwards Compatible**: Works with current prompt-based approach
2. **Auto-Detection**: Automatically uses tools when available
3. **Structured Output**: More predictable and parseable responses
4. **Better Error Handling**: Tools can return specific error types
5. **Composability**: Each tool does one thing well
6. **Testability**: Easy to mock and test individual tools
7. **Model Agnostic**: Works with any LLM that supports tools

#### Migration Path:

1. **Phase 1**: Ship MVP with prompt-based generation
2. **Monitor**: Watch for Ollama tool support updates
3. **Prepare**: Implement tool definitions and interfaces
4. **Test**: Run both strategies in parallel with feature flags
5. **Migrate**: Gradually move users to tool-based generation
6. **Optimize**: Remove prompt-based code once stable

## Technical Decisions

### Why Turbo Streams?
- Already included in Rails 8
- Perfect for progress updates
- No additional dependencies
- Works seamlessly with Stimulus

### Why JSONB for Questions?
- Flexible schema for different question types
- Easy to add new question types
- Efficient querying in PostgreSQL
- Simplifies in-place editing

### Why Solid Queue?
- Already configured in Rails 8
- Database-backed (reliable)
- Good for development/prototype
- Easy deployment

## Future Enhancements
- Add more question types (multiple choice, ranking, etc.)
- Survey templates
- Response analytics dashboard
- Export functionality
- Collaborative editing
- A/B testing for questions
- Multi-language support

## Ollama Integration

### Setting Up Ollama

1. **Install Ollama locally**:
   ```bash
   # macOS
   brew install ollama

   # Linux
   curl -fsSL https://ollama.com/install.sh | sh
   ```

2. **Start Ollama service**:
   ```bash
   ollama serve  # Runs on http://localhost:11434
   ```

3. **Pull required models**:
   ```bash
   ollama pull llama3.2       # Fast, good for general tasks
   ollama pull mistral        # Alternative option
   ollama pull codellama      # If focusing on technical surveys
   ```

### Ollama Ruby Client

```ruby
# app/lib/ollama_client.rb
class OllamaClient
  def initialize(base_url: 'http://localhost:11434')
    @base_url = base_url
  end

  def generate(model:, prompt:, format: nil, stream: false)
    uri = URI("#{@base_url}/api/generate")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    body = {
      model: model,
      prompt: prompt,
      stream: stream
    }
    body[:format] = format if format

    request.body = body.to_json

    response = http.request(request)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Ollama API error: #{e.message}"
    { 'response' => '{}' }  # Fallback empty response
  end

  def chat(model:, messages:)
    uri = URI("#{@base_url}/api/chat")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'

    request.body = {
      model: model,
      messages: messages,
      stream: false
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  rescue => e
    Rails.logger.error "Ollama API error: #{e.message}"
    { 'message' => { 'content' => '{}' } }
  end
end
```

## Dependencies to Add
```ruby
# Gemfile additions
gem 'redis' # for ActionCable in production (optional)

# No additional gems needed for Ollama - uses Net::HTTP
```

## Environment Variables Needed
```bash
# .env
OLLAMA_BASE_URL=http://localhost:11434  # Default Ollama URL
OLLAMA_MODEL=llama3.2                   # Default model to use
```

## Key Files Map
```
app/
├── controllers/
│   ├── surveys_controller.rb
│   └── survey_responses_controller.rb
├── models/
│   ├── survey.rb
│   ├── survey_response.rb
│   └── question_types/
│       ├── base.rb
│       ├── open_ended.rb
│       ├── sliding_scale.rb
│       └── registry.rb
├── services/
│   └── survey_generator_service.rb
├── jobs/
│   └── survey_generation_job.rb
├── lib/
│   └── ollama_client.rb              # Ollama API client
├── javascript/
│   └── controllers/
│       ├── survey_builder_controller.js
│       ├── generation_progress_controller.js
│       └── inline_edit_controller.js
├── views/
│   └── surveys/
│       ├── new.html.erb
│       ├── show.html.erb
│       ├── _generation_progress.html.erb
│       ├── _editable_survey.html.erb
│       └── _question_type_toggle.html.erb
└── channels/
    └── survey_progress_channel.rb
```