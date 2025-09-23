class SurveySentimentAnalyzer
  def initialize(survey)
    @survey = survey
    @responses = survey.responses.includes(:answers, :user)
  end

  def analyze
    {
      overall_sentiment: calculate_overall_sentiment,
      sentiment_by_question: sentiment_by_question,
      sentiment_by_department: sentiment_by_department,
      sentiment_by_role: sentiment_by_role,
      sentiment_trends: sentiment_trends,
      key_insights: generate_insights,
      recommendation_priority: assess_priority,
      detailed_breakdown: detailed_breakdown
    }
  end

  def analyze_with_progress(job_id)
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Starting analysis with progress tracking"

    yield(25, "Calculating overall sentiment...") if block_given?
    overall_sentiment = calculate_overall_sentiment
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Overall sentiment calculated"

    yield(35, "Analyzing by question...") if block_given?
    by_question = sentiment_by_question
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Question analysis completed"

    yield(50, "Analyzing by department...") if block_given?
    by_department = sentiment_by_department
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Department analysis completed"

    yield(60, "Analyzing by role...") if block_given?
    by_role = sentiment_by_role
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Role analysis completed"

    yield(70, "Calculating trends...") if block_given?
    trends = sentiment_trends
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Trend analysis completed"

    yield(80, "Generating insights...") if block_given?
    insights = generate_insights
    priority = assess_priority
    breakdown = detailed_breakdown
    Rails.logger.info "[SENTIMENT ANALYZER #{job_id}] Insights generated"

    {
      overall_sentiment: overall_sentiment,
      sentiment_by_question: by_question,
      sentiment_by_department: by_department,
      sentiment_by_role: by_role,
      sentiment_trends: trends,
      key_insights: insights,
      recommendation_priority: priority,
      detailed_breakdown: breakdown
    }
  end

  private

  def calculate_overall_sentiment
    all_text_responses = extract_all_text_responses
    return { score: 0, label: 'neutral', confidence: 0, total_responses: 0 } if all_text_responses.empty?

    sentiment_results = all_text_responses.map { |text| analyze_text_sentiment(text) }
    scores = sentiment_results.map { |r| normalize_sentiment_score(r) }
    avg_score = scores.sum / scores.count.to_f

    {
      score: avg_score.round(2),
      label: sentiment_label(avg_score),
      confidence: calculate_confidence(scores),
      total_responses: scores.count
    }
  end

  def sentiment_by_question
    @survey.questions.map do |question|
      text_answers = question.answers.where.not(value: [nil, ""]).pluck(:value).select { |value| value.is_a?(String) && value.strip.length > 0 }
      next if text_answers.empty?

      sentiment_results = text_answers.map { |text| analyze_text_sentiment(text) }
      scores = sentiment_results.map { |r| normalize_sentiment_score(r) }
      avg_score = scores.sum / scores.count.to_f

      {
        question_id: question.id,
        question_text: question.question_text.truncate(100),
        question_type: question.question_type,
        sentiment_score: avg_score.round(2),
        sentiment_label: sentiment_label(avg_score),
        response_count: scores.count,
        confidence: calculate_confidence(scores),
        sample_responses: text_answers.sample(3)
      }
    end.compact
  end

  def sentiment_by_department
    results = []
    department_groups = @responses.joins(:user).group_by { |r| r.user.department }

    department_groups.each do |department, responses|
      next if department.blank?

      all_text = responses.flat_map { |r| r.answers.where.not(value: [nil, ""]).pluck(:value) }.select { |value| value.is_a?(String) && value.strip.length > 0 }
      next if all_text.empty?

      sentiment_results = all_text.map { |text| analyze_text_sentiment(text) }
      scores = sentiment_results.map { |r| normalize_sentiment_score(r) }
      avg_score = scores.sum / scores.count.to_f

      results << {
        department: department,
        sentiment_score: avg_score.round(2),
        sentiment_label: sentiment_label(avg_score),
        response_count: scores.count,
        employee_count: responses.count,
        confidence: calculate_confidence(scores),
        top_concerns: extract_negative_samples(all_text),
        top_positives: extract_positive_samples(all_text)
      }
    end

    results.sort_by { |d| d[:sentiment_score] }
  end

  def sentiment_by_role
    results = []
    role_groups = @responses.joins(:user).group_by { |r| r.user.role }

    role_groups.each do |role, responses|
      next if role.blank?

      all_text = responses.flat_map { |r| r.answers.where.not(value: [nil, ""]).pluck(:value) }.select { |value| value.is_a?(String) && value.strip.length > 0 }
      next if all_text.empty?

      sentiment_results = all_text.map { |text| analyze_text_sentiment(text) }
      scores = sentiment_results.map { |r| normalize_sentiment_score(r) }
      avg_score = scores.sum / scores.count.to_f

      results << {
        role: role,
        sentiment_score: avg_score.round(2),
        sentiment_label: sentiment_label(avg_score),
        response_count: scores.count,
        employee_count: responses.count,
        confidence: calculate_confidence(scores)
      }
    end

    results.sort_by { |r| r[:sentiment_score] }
  end

  def sentiment_trends
    # Group responses by date for trend analysis
    daily_groups = @responses.group_by { |r| r.created_at.to_date }
    daily_sentiment = []

    daily_groups.each do |date, responses|
      all_text = responses.flat_map { |r| r.answers.where.not(value: [nil, ""]).pluck(:value) }.select { |value| value.is_a?(String) && value.strip.length > 0 }
      next if all_text.empty?

      sentiment_results = all_text.map { |text| analyze_text_sentiment(text) }
      scores = sentiment_results.map { |r| normalize_sentiment_score(r) }
      avg_score = scores.sum / scores.count.to_f

      daily_sentiment << {
        date: date,
        sentiment_score: avg_score.round(2),
        response_count: scores.count
      }
    end

    daily_sentiment.sort_by! { |d| d[:date] }

    {
      daily_trends: daily_sentiment,
      trend_direction: calculate_trend_direction(daily_sentiment),
      volatility: calculate_volatility(daily_sentiment)
    }
  end

  def generate_insights
    overall = calculate_overall_sentiment
    by_dept = sentiment_by_department
    by_question = sentiment_by_question

    insights = []

    # Overall sentiment insight
    if overall[:score] > 0.3
      insights << "Overall sentiment is positive (#{(overall[:score] * 100).round}%) with #{overall[:total_responses]} responses analyzed"
    elsif overall[:score] < -0.3
      insights << "Overall sentiment shows concerns (#{(overall[:score] * 100).round}%) requiring attention"
    else
      insights << "Overall sentiment is neutral (#{(overall[:score] * 100).round}%) with mixed feedback"
    end

    # Department insights
    if by_dept.any?
      best_dept = by_dept.last
      worst_dept = by_dept.first

      if best_dept[:sentiment_score] - worst_dept[:sentiment_score] > 0.5
        insights << "Significant sentiment gap: #{best_dept[:department]} (#{(best_dept[:sentiment_score] * 100).round}%) vs #{worst_dept[:department]} (#{(worst_dept[:sentiment_score] * 100).round}%)"
      end
    end

    # Question insights
    if by_question.any?
      concerning_questions = by_question.select { |q| q[:sentiment_score] < -0.2 }
      if concerning_questions.any?
        insights << "#{concerning_questions.count} questions show negative sentiment, requiring follow-up"
      end
    end

    insights
  end

  def assess_priority
    overall = calculate_overall_sentiment
    by_dept = sentiment_by_department

    negative_count = by_dept.count { |d| d[:sentiment_score] < -0.2 }

    if overall[:score] < -0.4 || negative_count > by_dept.count / 2
      'high'
    elsif overall[:score] < -0.1 || negative_count > 0
      'medium'
    else
      'low'
    end
  end

  def detailed_breakdown
    all_responses = extract_all_text_responses.map do |text|
      sentiment_result = analyze_text_sentiment(text)
      { text: text, score: normalize_sentiment_score(sentiment_result) }
    end

    positive_responses = all_responses.select { |r| r[:score] > 0.2 }
    neutral_responses = all_responses.select { |r| r[:score].between?(-0.2, 0.2) }
    negative_responses = all_responses.select { |r| r[:score] < -0.2 }

    {
      positive_responses: positive_responses.count,
      neutral_responses: neutral_responses.count,
      negative_responses: negative_responses.count,
      most_positive_responses: positive_responses.sort_by { |r| r[:score] }.reverse.first(5),
      most_negative_responses: negative_responses.sort_by { |r| r[:score] }.first(5)
    }
  end

  # Helper methods

  def analyze_text_sentiment(text)
    # Use fast rule-based sentiment analysis for demo performance
    # Can switch back to AI later: analyzer = SentimentAnalyzer.new(text); analyzer.analyze
    fast_sentiment_analysis(text)
  end

  def normalize_sentiment_score(sentiment_result)
    # Convert sentiment result to a -1 to 1 scale
    return 0 if sentiment_result[:sentiment] == 'neutral'

    base_score = sentiment_result[:score] || 0.5

    case sentiment_result[:sentiment]
    when 'positive'
      # Map 0.5-1.0 to 0.0-1.0
      (base_score - 0.5) * 2
    when 'negative'
      # Map 0.0-0.5 to -1.0-0.0
      (base_score - 0.5) * 2
    else
      0
    end
  end

  def sentiment_label(score)
    case score
    when 0.3..Float::INFINITY
      'positive'
    when 0.1..0.3
      'slightly positive'
    when -0.1..0.1
      'neutral'
    when -0.3..-0.1
      'slightly negative'
    else
      'negative'
    end
  end

  def calculate_confidence(scores)
    return 0 if scores.empty?

    variance = scores.sum { |s| (s - scores.sum / scores.count.to_f) ** 2 } / scores.count.to_f
    std_dev = Math.sqrt(variance)

    # Convert standard deviation to confidence (lower std_dev = higher confidence)
    confidence = [0, 100 - (std_dev * 50)].max.round
    confidence
  end

  def extract_all_text_responses
    @responses.flat_map do |response|
      response.answers.where.not(value: [nil, ""]).pluck(:value)
    end.select { |value| value.is_a?(String) && value.strip.length > 0 }
  end

  def extract_positive_samples(texts)
    positive_texts = texts.select do |text|
      result = analyze_text_sentiment(text)
      result[:sentiment] == 'positive'
    end
    positive_texts.first(3)
  end

  def extract_negative_samples(texts)
    negative_texts = texts.select do |text|
      result = analyze_text_sentiment(text)
      result[:sentiment] == 'negative'
    end
    negative_texts.first(3)
  end

  def calculate_trend_direction(daily_sentiment)
    return 'stable' if daily_sentiment.count < 2

    scores = daily_sentiment.map { |d| d[:sentiment_score] }
    first_half = scores[0...scores.count/2].sum / (scores.count/2).to_f
    second_half = scores[scores.count/2..-1].sum / (scores.count - scores.count/2).to_f

    if second_half > first_half + 0.1
      'improving'
    elsif second_half < first_half - 0.1
      'declining'
    else
      'stable'
    end
  end

  def calculate_volatility(daily_sentiment)
    scores = daily_sentiment.map { |d| d[:sentiment_score] }
    return 0 if scores.count < 2

    avg = scores.sum / scores.count.to_f
    variance = scores.sum { |s| (s - avg) ** 2 } / scores.count.to_f
    Math.sqrt(variance).round(3)
  end

  def fast_sentiment_analysis(text)
    return { sentiment: 'neutral', score: 0.5, confidence: 0.8 } if text.blank?

    # Handle non-string inputs (like numeric scale responses)
    return { sentiment: 'neutral', score: 0.5, confidence: 0.8 } unless text.is_a?(String)

    text_lower = text.downcase.strip

    # Enhanced keyword lists for better accuracy
    positive_words = %w[
      excellent great amazing wonderful fantastic outstanding superb brilliant good better best
      love enjoy appreciate satisfied happy pleased delighted thrilled excited glad
      effective efficient productive successful beneficial valuable helpful useful
      strong solid reliable consistent stable smooth easy simple clear
      supportive collaborative friendly welcoming inclusive respectful professional
      innovative creative flexible adaptable responsive quick fast convenient
      improved enhanced optimized streamlined perfect ideal
      positive upbeat motivated inspired confident proud accomplished fulfilled
      awesome fantastic incredible marvelous splendid terrific magnificent
    ]

    negative_words = %w[
      terrible awful horrible disgusting disappointing frustrating annoying bad worse worst
      hate dislike despise loathe detest resent regret worry concern fear
      ineffective inefficient unproductive unsuccessful problematic useless harmful
      weak unreliable inconsistent unstable broken difficult complex confusing
      unsupportive uncooperative unfriendly unwelcoming exclusive disrespectful unprofessional
      outdated inflexible unresponsive slow sluggish inconvenient complicated messy
      degraded reduced compromised imperfect flawed
      negative pessimistic demotivated uninspired stressed overwhelmed burned exhausted
      problem issue concern challenge struggle difficulty obstacle barrier
      lack missing absent insufficient inadequate limited restricted constrained
      expensive costly overpriced unaffordable wasteful unnecessary redundant
    ]

    # Count positive and negative words
    positive_count = positive_words.count { |word| text_lower.include?(word) }
    negative_count = negative_words.count { |word| text_lower.include?(word) }

    # Calculate base sentiment
    if positive_count > negative_count
      sentiment = 'positive'
      # Score between 0.6 and 0.9 based on positive word density
      score = [0.6 + (positive_count * 0.1), 0.9].min
      confidence = [0.6 + (positive_count * 0.1), 0.9].min
    elsif negative_count > positive_count
      sentiment = 'negative'
      # Score between 0.1 and 0.4 based on negative word density
      score = [0.4 - (negative_count * 0.1), 0.1].max
      confidence = [0.6 + (negative_count * 0.1), 0.9].min
    else
      sentiment = 'neutral'
      score = 0.5
      confidence = 0.7
    end

    {
      sentiment: sentiment,
      score: score,
      confidence: confidence,
      analyzed_at: Time.current
    }
  end
end