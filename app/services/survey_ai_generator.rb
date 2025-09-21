class SurveyAiGenerator
  # Available question types - easy to extend
  QUESTION_TYPES = %w[text scale].freeze

  def initialize(prompt, organization:, created_by:)
    @prompt = prompt
    @organization = organization
    @created_by = created_by
  end

  def generate
    # For now, let's create a simple rule-based generator
    # Later we'll replace this with actual OpenAI API calls
    survey_data = generate_survey_data(@prompt)

    create_survey_from_data(survey_data)
  end

  private

  def generate_survey_data(prompt)
    # Use Ollama to generate survey based on user prompt
    begin
      survey_json = generate_with_ollama(prompt)
      parsed_survey = JSON.parse(survey_json)

      # Validate and sanitize the response
      validate_survey_structure(parsed_survey)

      # Convert string keys to symbols for consistency
      {
        title: parsed_survey['title'],
        description: parsed_survey['description'],
        questions: parsed_survey['questions'].map do |q|
          {
            question_text: q['question_text'],
            question_type: q['question_type'],
            required: q['required']
          }
        end
      }
    rescue => e
      Rails.logger.error "AI Generation failed: #{e.message}"
      # Fallback to rule-based generation if AI fails
      fallback_generation(prompt)
    end
  end

  def generate_with_ollama(prompt)
    client = OllamaClient.new

    system_prompt = <<~SYSTEM
      You are a survey generation AI. Generate a survey based on the user's prompt.

      Return ONLY a valid JSON object with this exact structure:
      {
        "title": "Survey Title",
        "description": "Brief description of the survey purpose",
        "questions": [
          {
            "question_text": "Question text here",
            "question_type": "text",
            "required": true
          },
          {
            "question_text": "Rate this from 1-10",
            "question_type": "scale",
            "required": false
          }
        ]
      }

      Rules:
      - question_type must be either "text" or "scale"
      - Scale questions should include "(1 = poor, 10 = excellent)" or similar in the question text
      - Generate 4-6 relevant questions
      - Mix of required and optional questions
      - Make questions specific to the survey topic
      - Required field must be boolean (true/false)

      Do not include any text before or after the JSON.
    SYSTEM

    client.generate(prompt, system_prompt: system_prompt)
  end

  def validate_survey_structure(survey)
    raise "Missing title" unless survey['title'].present?
    raise "Missing description" unless survey['description'].present?
    raise "Missing questions array" unless survey['questions'].is_a?(Array)
    raise "No questions provided" if survey['questions'].empty?

    survey['questions'].each_with_index do |question, index|
      raise "Question #{index + 1}: missing question_text" unless question['question_text'].present?
      raise "Question #{index + 1}: invalid question_type" unless %w[text scale].include?(question['question_type'])
      raise "Question #{index + 1}: required must be boolean" unless [true, false].include?(question['required'])
    end
  end

  def fallback_generation(prompt)
    Rails.logger.info "Using fallback generation for prompt: #{prompt}"

    # Use the original rule-based system as fallback
    survey_title, description, questions = case detect_survey_type(prompt)
    when :customer_satisfaction
      generate_customer_satisfaction_survey(prompt)
    when :employee_engagement
      generate_employee_survey(prompt)
    when :product_feedback
      generate_product_feedback_survey(prompt)
    when :restaurant
      generate_restaurant_survey(prompt)
    when :event_feedback
      generate_event_survey(prompt)
    when :training_evaluation
      generate_training_survey(prompt)
    when :market_research
      generate_market_research_survey(prompt)
    else
      generate_contextual_survey(prompt)
    end

    {
      title: survey_title,
      description: description,
      questions: questions
    }
  end

  def detect_survey_type(prompt)
    prompt_lower = prompt.downcase

    return :restaurant if prompt_lower.match?(/restaurant|food|dining|menu|chef|service/)
    return :event_feedback if prompt_lower.match?(/event|conference|workshop|meeting|webinar/)
    return :training_evaluation if prompt_lower.match?(/training|course|learning|education|instructor/)
    return :market_research if prompt_lower.match?(/market|research|brand|competition|target audience/)
    return :customer_satisfaction if prompt_lower.match?(/customer|satisfaction|service|support/)
    return :employee_engagement if prompt_lower.match?(/employee|workplace|team|engagement|culture/)
    return :product_feedback if prompt_lower.match?(/product|feature|app|software|tool/)

    :generic
  end

  def generate_customer_satisfaction_survey(prompt)
    title = "Customer Satisfaction Survey"
    description = "Help us improve our service by sharing your feedback"

    questions = [
      {
        question_text: "How would you rate your overall satisfaction? (1 = Very Unsatisfied, 10 = Very Satisfied)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What did you like most about your experience?",
        question_type: "text",
        required: false
      },
      {
        question_text: "How likely are you to recommend us to others? (1 = Not at all likely, 10 = Extremely likely)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What could we improve?",
        question_type: "text",
        required: false
      },
      {
        question_text: "How easy was it to get help when you needed it? (1 = Very Difficult, 10 = Very Easy)",
        question_type: "scale",
        required: false
      }
    ]

    [title, description, questions]
  end

  def generate_employee_survey(prompt)
    title = "Employee Engagement Survey"
    description = "Share your thoughts about your workplace experience"

    questions = [
      {
        question_text: "How satisfied are you with your current role? (1 = Very Unsatisfied, 10 = Very Satisfied)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What motivates you most at work?",
        question_type: "text",
        required: false
      },
      {
        question_text: "How would you rate work-life balance? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "How likely are you to recommend this company as a place to work? (1 = Not at all likely, 10 = Extremely likely)",
        question_type: "scale",
        required: false
      },
      {
        question_text: "What could leadership do to better support the team?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  def generate_product_feedback_survey(prompt)
    title = "Product Feedback Survey"
    description = "Help us understand how to improve our product"

    questions = [
      {
        question_text: "How would you rate the product overall? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What features do you use most?",
        question_type: "text",
        required: false
      },
      {
        question_text: "What new features would you like to see?",
        question_type: "text",
        required: false
      },
      {
        question_text: "How easy is the product to use? (1 = Very Difficult, 10 = Very Easy)",
        question_type: "scale",
        required: false
      },
      {
        question_text: "What's the biggest challenge you face when using this product?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  def generate_contextual_survey(prompt)
    # Extract key terms from prompt for more relevant questions
    title = extract_title_from_prompt(prompt)
    description = "Please share your thoughts and feedback"

    questions = [
      {
        question_text: "Please rate your overall experience (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What worked well for you?",
        question_type: "text",
        required: false
      },
      {
        question_text: "What could be improved?",
        question_type: "text",
        required: false
      },
      {
        question_text: "Any additional comments or suggestions?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  def create_survey_from_data(data)
    survey = @organization.surveys.create!(
      title: data[:title],
      description: data[:description],
      created_by: @created_by,
      status: "draft",
      ai_prompt: @prompt
    )

    data[:questions].each_with_index do |question_data, index|
      survey.questions.create!(
        question_text: question_data[:question_text],
        question_type: question_data[:question_type],
        required: question_data[:required],
        position: index + 1
      )
    end

    survey
  end

  def generate_restaurant_survey(prompt)
    title = "Restaurant Feedback Survey"
    description = "Help us improve your dining experience"

    questions = [
      {
        question_text: "How would you rate the food quality? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "How would you rate the service? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "How would you rate the atmosphere? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: false
      },
      {
        question_text: "What was your favorite dish?",
        question_type: "text",
        required: false
      },
      {
        question_text: "Would you recommend this restaurant to friends? (1 = Definitely not, 10 = Definitely yes)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "Any suggestions for improvement?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  def generate_event_survey(prompt)
    title = "Event Feedback Survey"
    description = "Help us improve future events with your feedback"

    questions = [
      {
        question_text: "How would you rate the event overall? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "How useful was the content? (1 = Not useful, 10 = Very useful)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What was the most valuable part of the event?",
        question_type: "text",
        required: false
      },
      {
        question_text: "How would you rate the organization? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: false
      },
      {
        question_text: "What topics would you like to see covered in future events?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  def generate_training_survey(prompt)
    title = "Training Evaluation Survey"
    description = "Help us improve our training programs"

    questions = [
      {
        question_text: "How would you rate the training content? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "How effective was the instructor? (1 = Poor, 10 = Excellent)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "How likely are you to apply what you learned? (1 = Not likely, 10 = Very likely)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What was most helpful about this training?",
        question_type: "text",
        required: false
      },
      {
        question_text: "What could be improved?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  def generate_market_research_survey(prompt)
    title = "Market Research Survey"
    description = "Help us understand your preferences and needs"

    questions = [
      {
        question_text: "How familiar are you with our brand? (1 = Not familiar, 10 = Very familiar)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What factors are most important when choosing this type of product/service?",
        question_type: "text",
        required: false
      },
      {
        question_text: "How likely are you to try our product/service? (1 = Not likely, 10 = Very likely)",
        question_type: "scale",
        required: true
      },
      {
        question_text: "What brands do you currently use for this type of product/service?",
        question_type: "text",
        required: false
      },
      {
        question_text: "What would make you switch to a new brand?",
        question_type: "text",
        required: false
      }
    ]

    [title, description, questions]
  end

  private

  def extract_title_from_prompt(prompt)
    # Simple title extraction - capitalize first few words
    words = prompt.split.first(4)
    title = words.join(' ').titleize
    title.length > 50 ? "#{title[0...47]}..." : title
  end
end