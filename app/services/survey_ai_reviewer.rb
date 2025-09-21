class SurveyAiReviewer
  def initialize(survey)
    @survey = survey
  end

  def review
    begin
      review_json = generate_review_with_ollama
      parsed_review = JSON.parse(review_json)

      # Validate the response structure
      validate_review_structure(parsed_review)

      {
        overall_score: parsed_review['overall_score'],
        purpose_clarity: parsed_review['purpose_clarity'],
        question_quality: parsed_review['question_quality'],
        survey_flow: parsed_review['survey_flow'],
        suggestions: parsed_review['suggestions'],
        missing_elements: parsed_review['missing_elements'],
        strengths: parsed_review['strengths']
      }
    rescue => e
      Rails.logger.error "AI Review failed: #{e.message}"
      # Fallback to basic analysis if AI fails
      fallback_review
    end
  end

  private

  def generate_review_with_ollama
    client = OllamaClient.new

    system_prompt = <<~SYSTEM
      You are a survey design expert. Analyze the provided survey and give constructive feedback.

      Return ONLY a valid JSON object with this exact structure:
      {
        "overall_score": 8,
        "purpose_clarity": "The survey purpose is clear and well-defined...",
        "question_quality": "Most questions are well-structured, but...",
        "survey_flow": "The question order is logical and...",
        "suggestions": [
          "Consider rewording question 3 to be more neutral",
          "Add a demographic question about experience level",
          "Consider making question 5 optional to reduce abandonment"
        ],
        "missing_elements": [
          "Demographic questions for better segmentation",
          "A final open-ended feedback question"
        ],
        "strengths": [
          "Good balance of scale and text questions",
          "Clear and concise question wording"
        ]
      }

      Rules:
      - overall_score should be 1-10 (integer)
      - All text fields should be 1-3 sentences
      - suggestions, missing_elements, and strengths should be arrays of strings
      - Be constructive and specific in feedback
      - Focus on survey design best practices

      Do not include any text before or after the JSON.
    SYSTEM

    user_prompt = build_survey_prompt

    client.generate(user_prompt, system_prompt: system_prompt)
  end

  def build_survey_prompt
    prompt = "Please review this survey:\n\n"
    prompt += "**Survey Title:** #{@survey.title}\n"
    prompt += "**Description:** #{@survey.description}\n"

    if @survey.ai_prompt.present?
      prompt += "**Original Prompt:** #{@survey.ai_prompt}\n"
    end

    prompt += "\n**Questions:**\n"

    @survey.questions.order(:position).each_with_index do |question, index|
      prompt += "#{index + 1}. #{question.question_text}"
      prompt += " (#{question.question_type})"
      prompt += " [Required]" if question.required?
      prompt += "\n"
    end

    prompt += "\nPlease analyze the survey quality, flow, and provide specific suggestions for improvement."

    prompt
  end

  def validate_review_structure(review)
    required_fields = %w[overall_score purpose_clarity question_quality survey_flow suggestions missing_elements strengths]

    required_fields.each do |field|
      raise "Missing required field: #{field}" unless review.key?(field)
    end

    raise "overall_score must be between 1-10" unless (1..10).include?(review['overall_score'].to_i)

    %w[suggestions missing_elements strengths].each do |field|
      raise "#{field} must be an array" unless review[field].is_a?(Array)
    end
  end

  def fallback_review
    {
      overall_score: 7,
      purpose_clarity: "Survey purpose appears clear based on the title and description.",
      question_quality: "Questions seem well-structured with a good mix of question types.",
      survey_flow: "Question order appears logical and follows standard survey flow practices.",
      suggestions: [
        "Consider adding more demographic questions for better analysis",
        "Review question wording for potential bias",
        "Test the survey with a small group before full deployment"
      ],
      missing_elements: [
        "Demographic questions for segmentation",
        "Final feedback question for additional insights"
      ],
      strengths: [
        "Good balance of required and optional questions",
        "Clear and concise question wording"
      ]
    }
  end
end