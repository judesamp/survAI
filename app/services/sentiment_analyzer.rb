class SentimentAnalyzer
  def initialize(text)
    @text = text.to_s.strip
  end

  def analyze
    return neutral_sentiment if @text.empty?

    begin
      ai_sentiment = generate_ai_sentiment
      enhance_sentiment(ai_sentiment)
    rescue => e
      Rails.logger.error "Sentiment analysis failed: #{e.message}"
      fallback_sentiment
    end
  end

  private

  def generate_ai_sentiment
    client = OllamaClient.new

    system_prompt = <<~SYSTEM
      You are an expert sentiment analysis AI. Analyze the emotional tone of the given text and provide a sentiment score.

      Return ONLY a JSON object with this exact structure:
      {
        "sentiment": "positive|negative|neutral",
        "score": 0.0-1.0,
        "confidence": 0.0-1.0,
        "emotions": ["emotion1", "emotion2"],
        "reasoning": "Brief explanation of why this sentiment was detected"
      }

      Guidelines:
      - positive: Optimistic, satisfied, enthusiastic, happy, confident
      - negative: Frustrated, disappointed, concerned, angry, worried
      - neutral: Factual, balanced, neither positive nor negative
      - score: 0.0 = very negative, 0.5 = neutral, 1.0 = very positive
      - confidence: How certain you are about this analysis (0.0-1.0)
      - emotions: List 1-3 specific emotions detected
      - reasoning: 1-2 sentence explanation

      Be precise and consistent in your analysis.
    SYSTEM

    user_prompt = "Analyze the sentiment of this text: \"#{@text}\""

    response = client.generate(user_prompt, system_prompt: system_prompt)
    
    # Parse JSON response
    JSON.parse(response.strip)
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse sentiment JSON: #{e.message}"
    fallback_sentiment
  end

  def enhance_sentiment(ai_sentiment)
    # Add some realistic variations and validation
    sentiment = ai_sentiment['sentiment']&.downcase
    score = ai_sentiment['score'].to_f
    confidence = ai_sentiment['confidence'].to_f

    # Validate and normalize
    sentiment = 'neutral' unless %w[positive negative neutral].include?(sentiment)
    score = [[score, 0.0].max, 1.0].min # Clamp between 0 and 1
    confidence = [[confidence, 0.0].max, 1.0].min # Clamp between 0 and 1

    {
      sentiment: sentiment,
      score: score,
      confidence: confidence,
      emotions: ai_sentiment['emotions'] || [],
      reasoning: ai_sentiment['reasoning'] || 'AI analysis completed',
      analyzed_at: Time.current
    }
  end

  def fallback_sentiment
    # Simple keyword-based fallback
    positive_words = %w[good great excellent amazing love like enjoy happy satisfied pleased positive awesome fantastic wonderful]
    negative_words = %w[bad terrible awful hate dislike frustrated angry disappointed concerned worried negative poor horrible]

    text_lower = @text.downcase
    positive_count = positive_words.count { |word| text_lower.include?(word) }
    negative_count = negative_words.count { |word| text_lower.include?(word) }

    if positive_count > negative_count
      {
        sentiment: 'positive',
        score: 0.7,
        confidence: 0.6,
        emotions: ['satisfied'],
        reasoning: 'Detected positive keywords',
        analyzed_at: Time.current
      }
    elsif negative_count > positive_count
      {
        sentiment: 'negative',
        score: 0.3,
        confidence: 0.6,
        emotions: ['concerned'],
        reasoning: 'Detected negative keywords',
        analyzed_at: Time.current
      }
    else
      neutral_sentiment
    end
  end

  def neutral_sentiment
    {
      sentiment: 'neutral',
      score: 0.5,
      confidence: 0.8,
      emotions: ['neutral'],
      reasoning: 'No clear sentiment detected',
      analyzed_at: Time.current
    }
  end
end