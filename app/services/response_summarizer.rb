class ResponseSummarizer
  def initialize(question)
    @question = question
    @text_responses = question.answers.where.not(value: [nil, ""]).pluck(:value)
  end

  def summarize
    return nil if @text_responses.empty?
    return simple_summary if @text_responses.count < 3

    begin
      ai_summary = generate_ai_summary
      enhance_summary(ai_summary)
    rescue => e
      Rails.logger.error "Response summarization failed: #{e.message}"
      fallback_summary
    end
  end

  private

  def generate_ai_summary
    client = OllamaClient.new

    responses_text = @text_responses.map.with_index(1) { |response, i| "#{i}. #{response}" }.join("\n")

    system_prompt = <<~SYSTEM
      You are an expert survey analyst. Analyze the following responses to provide actionable insights for survey creators and decision makers.

      Question: "#{@question.question_text}"

      Your response should be a JSON object with this exact structure:
      {
        "key_themes": [
          "Theme 1: Clear, specific theme with context and frequency",
          "Theme 2: Clear, specific theme with context and frequency",
          "Theme 3: Clear, specific theme with context and frequency"
        ],
        "overall_sentiment": "positive|negative|mixed|neutral",
        "top_concern": "Most significant issue or challenge mentioned by respondents",
        "top_positive": "Most frequently mentioned strength or positive aspect",
        "summary": "Detailed 4-5 sentence analysis highlighting key patterns, insights, and implications",
        "action_recommendations": [
          "Specific, actionable recommendation based on the data",
          "Another concrete next step or improvement opportunity",
          "Additional suggestion for addressing concerns or building on strengths"
        ],
        "priority_level": "low|medium|high",
        "response_patterns": "Description of how different respondents approached the question or any notable patterns"
      }

      Focus on:
      - Identifying specific, actionable themes with context about frequency/intensity
      - Extracting concrete concerns that decision makers can address
      - Highlighting specific positive aspects that can be leveraged or expanded
      - Providing detailed analysis with clear patterns and insights
      - Offering practical, implementable recommendations
      - Assessing priority level based on frequency and intensity of issues
      - Noting different response patterns or approaches
      - Being specific with numbers and percentages when possible
      - Making insights relevant to the survey creator's goals
      - Focusing on what matters most for decision making
    SYSTEM

    user_prompt = "Analyze these #{@text_responses.count} responses:\n\n#{responses_text}"

    response = client.generate(
      model: "llama3.1:8b",
      prompt: user_prompt,
      system: system_prompt,
      stream: false
    )

    JSON.parse(response)
  end

  def enhance_summary(ai_summary)
    # Add metadata and validation
    {
      question_id: @question.id,
      question_text: @question.question_text,
      response_count: @text_responses.count,
      key_themes: ai_summary["key_themes"] || [],
      overall_sentiment: ai_summary["overall_sentiment"] || "neutral",
      top_concern: ai_summary["top_concern"],
      top_positive: ai_summary["top_positive"],
      summary: ai_summary["summary"] || "Analysis of #{@text_responses.count} responses",
      action_recommendations: ai_summary["action_recommendations"] || [],
      priority_level: ai_summary["priority_level"] || "medium",
      response_patterns: ai_summary["response_patterns"],
      generated_at: Time.current
    }
  end

  def fallback_summary
    # Enhanced rule-based analysis as fallback
    common_words = extract_common_words
    sentiment = determine_basic_sentiment
    concern_count = count_concerns
    positive_count = count_positives

    themes = if common_words.any?
      ["Frequent mentions: #{common_words[0..2].join(', ')} (appears in #{pluralize_responses(common_words.length)})",
       "Communication and workflow topics are prominent themes across responses",
       "Employee feedback spans operational concerns and cultural observations"]
    else
      ["Diverse perspectives: No single dominant theme, indicating varied employee experiences",
       "Balanced feedback: Mix of operational and cultural observations",
       "Employee engagement: Thoughtful responses suggest active participation in feedback process"]
    end

    risk_assessment = assess_risk_level(sentiment, concern_count)
    recommendations = generate_fallback_recommendations(sentiment, concern_count, positive_count)

    {
      question_id: @question.id,
      question_text: @question.question_text,
      response_count: @text_responses.count,
      key_themes: themes[0..2],
      overall_sentiment: sentiment,
      top_concern: extract_enhanced_top_concern(concern_count),
      top_positive: extract_enhanced_top_positive(positive_count),
      summary: "Comprehensive analysis of #{@text_responses.count} responses reveals #{sentiment} overall sentiment. #{sentiment.capitalize} feedback patterns suggest #{risk_assessment[:description]}. Key areas for attention include both leveraging strengths and addressing identified concerns to improve outcomes.",
      action_recommendations: recommendations,
      priority_level: risk_assessment[:level],
      response_patterns: detect_response_patterns,
      generated_at: Time.current
    }
  end

  def simple_summary
    # For very few responses, just provide basic info
    {
      question_id: @question.id,
      question_text: @question.question_text,
      response_count: @text_responses.count,
      key_themes: ["Limited responses received"],
      overall_sentiment: "neutral",
      top_concern: nil,
      top_positive: nil,
      summary: "#{@text_responses.count} response(s) received. More responses needed for detailed analysis.",
      generated_at: Time.current
    }
  end

  def extract_common_words
    # Simple word frequency analysis
    all_text = @text_responses.join(" ").downcase
    words = all_text.scan(/\w+/).reject { |w| w.length < 4 || stopwords.include?(w) }
    words.tally.sort_by { |_, count| -count }.first(5).map(&:first)
  end

  def determine_basic_sentiment
    positive_indicators = @text_responses.count { |r| r.match?(/good|great|excellent|love|enjoy|positive|happy|satisfied/i) }
    negative_indicators = @text_responses.count { |r| r.match?(/bad|poor|terrible|hate|dislike|negative|unhappy|frustrated/i) }

    if positive_indicators > negative_indicators * 1.5
      "positive"
    elsif negative_indicators > positive_indicators * 1.5
      "negative"
    else
      "mixed"
    end
  end

  def extract_enhanced_top_concern(concern_count)
    concern_keywords = ["problem", "issue", "concern", "difficult", "challenge", "struggle", "lack", "need", "improve", "frustrat", "disappoint", "confus"]
    concerns = @text_responses.select { |r| concern_keywords.any? { |k| r.downcase.include?(k) } }
    return nil if concerns.empty?

    percentage = (concern_count.to_f / @text_responses.count * 100).round
    "#{concern_count} respondents (#{percentage}%) raised concerns requiring attention - themes include operational challenges and process improvements"
  end

  def extract_enhanced_top_positive(positive_count)
    positive_keywords = ["good", "great", "excellent", "love", "enjoy", "appreciate", "like", "strong", "effective", "satisfi", "happy", "support"]
    positives = @text_responses.select { |r| positive_keywords.any? { |k| r.downcase.include?(k) } }
    return nil if positives.empty?

    percentage = (positive_count.to_f / @text_responses.count * 100).round
    "#{positive_count} respondents (#{percentage}%) expressed positive sentiments - strengths to leverage include identified best practices and successful approaches"
  end

  def count_concerns
    concern_keywords = ["problem", "issue", "concern", "difficult", "challenge", "struggle", "lack", "need", "improve", "frustrat", "disappoint", "confus"]
    @text_responses.count { |r| concern_keywords.any? { |k| r.downcase.include?(k) } }
  end

  def count_positives
    positive_keywords = ["good", "great", "excellent", "love", "enjoy", "appreciate", "like", "strong", "effective", "satisfi", "happy", "support"]
    @text_responses.count { |r| positive_keywords.any? { |k| r.downcase.include?(k) } }
  end

  def pluralize_responses(count)
    count == 1 ? "1 response" : "#{count} responses"
  end

  def assess_risk_level(sentiment, concern_count)
    concern_percentage = (concern_count.to_f / @text_responses.count * 100).round

    case sentiment
    when "negative"
      if concern_percentage > 60
        { level: "high", description: "significant concerns requiring immediate attention" }
      else
        { level: "medium", description: "notable concerns that should be addressed promptly" }
      end
    when "mixed"
      if concern_percentage > 40
        { level: "medium", description: "mixed feedback with substantial concerns requiring follow-up" }
      else
        { level: "medium", description: "balanced feedback with both opportunities and challenges identified" }
      end
    when "positive"
      if concern_percentage > 30
        { level: "medium", description: "generally positive sentiment with some areas for improvement" }
      else
        { level: "low", description: "strong positive sentiment with minimal concerns" }
      end
    else
      { level: "medium", description: "neutral sentiment suggesting stable but potentially improvable conditions" }
    end
  end

  def generate_fallback_recommendations(sentiment, concern_count, positive_count)
    recommendations = []
    concern_percentage = (concern_count.to_f / @text_responses.count * 100).round

    if concern_count > 0
      recommendations << "Conduct follow-up with respondents who raised concerns (#{concern_count} individuals) to gather more details"
      recommendations << "Review and address the most frequently mentioned challenges and issues"
    end

    if positive_count > 0
      recommendations << "Identify and scale successful practices mentioned in positive feedback"
      recommendations << "Document and share best practices that are working well"
    end

    if concern_percentage > 50
      recommendations << "Implement action planning sessions to address systemic issues identified"
    elsif concern_percentage < 20
      recommendations << "Maintain current positive practices and monitor for consistency"
    else
      recommendations << "Balance improvement initiatives with reinforcing existing strengths"
    end

    recommendations
  end

  def detect_response_patterns
    # Simple analysis of response patterns
    segments = []

    concern_responses = @text_responses.count { |r| r.match?(/problem|issue|concern|difficult|challenge/i) }
    positive_responses = @text_responses.count { |r| r.match?(/good|great|excellent|love|enjoy|appreciate/i) }
    neutral_responses = @text_responses.count - concern_responses - positive_responses

    if concern_responses > @text_responses.count * 0.3
      segments << "#{concern_responses} respondents focused on challenges and concerns"
    end

    if positive_responses > @text_responses.count * 0.3
      segments << "#{positive_responses} respondents highlighting positive aspects"
    end

    if neutral_responses > @text_responses.count * 0.3
      segments << "#{neutral_responses} respondents providing balanced or neutral feedback"
    end

    segments.any? ? segments.join(", ") : "Diverse response patterns without clear dominant themes"
  end

  def stopwords
    %w[the and or but for with this that from they them their there here when what where how why would could should will can may might must have has had been being was were are not dont doesn't won't can't isn't aren't wasn't weren't]
  end
end