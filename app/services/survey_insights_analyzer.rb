class SurveyInsightsAnalyzer
  def initialize(survey, generated_by: nil)
    @survey = survey
    @generated_by = generated_by || get_default_user
    @assignments = survey.assignments.includes(:user, :response)
    @responses = survey.responses.completed.includes(:answers, :user)
    @questions = survey.questions.includes(:answers)
  end

  def analyze
    Rails.logger.info "=== Survey Insights Analysis Started ==="
    Rails.logger.info "Survey: #{@survey.title}"
    Rails.logger.info "Responses: #{@responses.count}"

    begin
      insights_json = generate_insights_with_ollama
      parsed_insights = JSON.parse(insights_json)

      # Validate and enhance the insights
      enhanced_insights = enhance_insights(parsed_insights)

      # Save to database
      save_insights(enhanced_insights)
    rescue => e
      Rails.logger.error "AI insights generation failed: #{e.message}"
      # Fallback to rule-based insights
      fallback_insights = generate_fallback_insights

      # Save fallback insights to database
      save_insights(fallback_insights)
    end
  end

  private

  def generate_insights_with_ollama
    client = OllamaClient.new

    # Build comprehensive survey data for analysis
    survey_data = build_survey_analysis_data

    system_prompt = <<~SYSTEM
      You are a survey analysis expert. Analyze the provided survey data and generate actionable insights.

      Return ONLY a valid JSON object with this exact structure:
      {
        "executive_summary": "2-3 sentence overview of key findings",
        "key_findings": [
          "Most important insight 1",
          "Most important insight 2",
          "Most important insight 3"
        ],
        "satisfaction_drivers": [
          "What's working well 1",
          "What's working well 2"
        ],
        "areas_for_improvement": [
          "Issue that needs attention 1",
          "Issue that needs attention 2"
        ],
        "risk_indicators": [
          "Potential problem 1",
          "Potential problem 2"
        ],
        "recommended_actions": [
          "Specific actionable step 1",
          "Specific actionable step 2",
          "Specific actionable step 3"
        ],
        "department_insights": {
          "department_name": "Specific insight for this department"
        }
      }

      Rules:
      - Focus on actionable insights, not just data summaries
      - Identify patterns and trends in the responses
      - Consider both quantitative (scale) and qualitative (text) data
      - Provide specific, concrete recommendations
      - Highlight urgent issues that need immediate attention
      - Be constructive and solution-oriented

      Do not include any text before or after the JSON.
    SYSTEM

    client.generate(survey_data, system_prompt: system_prompt)
  end

  def build_survey_analysis_data
    data = {
      survey_title: @survey.title,
      survey_description: @survey.description,
      total_assignments: @assignments.count,
      total_responses: @responses.count,
      response_rate: @survey.response_rate,
      average_completion_time: @survey.average_completion_time,
      overall_satisfaction: @survey.average_scale_score
    }

    # Add question analysis
    data[:questions_analysis] = @questions.map do |question|
      question_data = {
        question: question.question_text,
        type: question.question_type,
        required: question.required?
      }

      if question.question_type == 'scale'
        scores = question.answers.where.not(value: [nil, ""]).pluck(:value).map(&:to_f).select { |v| v > 0 }
        if scores.any?
          question_data[:average_score] = (scores.sum / scores.count).round(1)
          question_data[:score_distribution] = scores.group_by(&:to_i).transform_values(&:count)
          question_data[:response_count] = scores.count
        end
      else
        # Text responses
        text_responses = question.answers.where.not(value: [nil, ""]).pluck(:value)
        question_data[:response_count] = text_responses.count
        question_data[:sample_responses] = text_responses.first(3) if text_responses.any?
      end

      question_data
    end

    # Add department breakdown if available
    department_data = {}
    @assignments.joins(:user).group('users.department').group(:completed).count.each do |key, count|
      department, completed = key
      next if department.blank?

      department_data[department] ||= { assigned: 0, completed: 0 }
      department_data[department][:assigned] += count
      department_data[department][:completed] += count if completed
    end

    if department_data.any?
      data[:department_breakdown] = department_data.transform_values do |dept_stats|
        dept_stats[:response_rate] = ((dept_stats[:completed].to_f / dept_stats[:assigned]) * 100).round(1)
        dept_stats
      end
    end

    # Add response timing analysis
    if @responses.any?
      completion_times = @responses.filter_map(&:time_to_complete)
      if completion_times.any?
        data[:completion_time_analysis] = {
          average: completion_times.sum / completion_times.count,
          fastest: completion_times.min,
          slowest: completion_times.max
        }
      end

      # Response timeline
      data[:response_timeline] = @responses.group_by { |r| r.created_at.to_date }
                                           .transform_values(&:count)
                                           .sort_by { |date, _| date }
                                           .last(7) # Last 7 days
    end

    data.to_json
  end

  def enhance_insights(parsed_insights)
    # Add calculated metrics and additional context
    enhanced = parsed_insights.dup

    # Add response rate context
    response_rate = @survey.response_rate
    enhanced["response_rate_assessment"] = case response_rate
    when 0..30 then "Low response rate - consider follow-up reminders"
    when 31..60 then "Moderate response rate - room for improvement"
    when 61..80 then "Good response rate - performing well"
    else "Excellent response rate - highly engaged audience"
    end

    # Add completion time context
    avg_time = @survey.average_completion_time
    if avg_time > 0
      enhanced["completion_time_assessment"] = case avg_time
      when 0..3 then "Very quick survey - good user experience"
      when 4..7 then "Reasonable completion time"
      when 8..15 then "Longer survey - monitor for dropoff"
      else "Very long survey - consider shortening"
      end
    end

    # Add urgency indicators
    enhanced["urgency_level"] = calculate_urgency_level

    enhanced
  end

  def calculate_urgency_level
    concerns = 0

    # Low response rate
    concerns += 1 if @survey.response_rate < 50

    # Low satisfaction scores
    if @survey.average_scale_score && @survey.average_scale_score < 6
      concerns += 2 # More serious
    end

    # Slow completion times
    concerns += 1 if @survey.average_completion_time > 10

    case concerns
    when 0..1 then "low"
    when 2..3 then "medium"
    else "high"
    end
  end

  def generate_fallback_insights
    Rails.logger.info "Using fallback insights generation"

    response_rate = @survey.response_rate
    avg_score = @survey.average_scale_score

    insights = {
      "executive_summary" => generate_executive_summary(response_rate, avg_score),
      "key_findings" => generate_key_findings(response_rate, avg_score),
      "satisfaction_drivers" => generate_satisfaction_drivers(avg_score),
      "areas_for_improvement" => generate_improvement_areas(response_rate, avg_score),
      "risk_indicators" => generate_risk_indicators(response_rate, avg_score),
      "recommended_actions" => generate_action_recommendations(response_rate, avg_score),
      "department_insights" => generate_department_insights
    }

    enhance_insights(insights)
  end

  def generate_executive_summary(response_rate, avg_score)
    summary = "Survey received #{@responses.count} responses from #{@assignments.count} assignments (#{response_rate}% response rate). "

    if avg_score
      summary += if avg_score >= 7
        "Overall satisfaction is positive with an average score of #{avg_score}/10. "
      elsif avg_score >= 5
        "Overall satisfaction is moderate with an average score of #{avg_score}/10. "
      else
        "Overall satisfaction is concerning with a low average score of #{avg_score}/10. "
      end
    end

    summary += if response_rate >= 70
      "Strong engagement suggests results are representative."
    elsif response_rate >= 50
      "Moderate engagement provides useful insights but consider follow-up for higher participation."
    else
      "Low engagement suggests results may not be fully representative - recommend additional outreach."
    end

    summary
  end

  def generate_key_findings(response_rate, avg_score)
    findings = []

    findings << "#{response_rate}% response rate with #{@responses.count} completed responses"

    if avg_score
      findings << "Average satisfaction score of #{avg_score}/10 across scale questions"
    end

    if @survey.average_completion_time > 0
      findings << "Average completion time of #{@survey.average_completion_time} minutes"
    end

    # Add department insights if available
    dept_breakdown = @survey.department_breakdown
    if dept_breakdown.any?
      dept_with_highest = dept_breakdown.max_by { |_, stats| stats[:response_rate] rescue 0 }
      if dept_with_highest
        findings << "#{dept_with_highest[0]} department shows highest engagement"
      end
    end

    findings
  end

  def generate_satisfaction_drivers(avg_score)
    drivers = []

    if avg_score && avg_score >= 7
      drivers << "Strong overall satisfaction indicates effective current practices"
      drivers << "High engagement in survey completion suggests active and invested audience"
    elsif avg_score && avg_score >= 5
      drivers << "Moderate satisfaction provides good foundation for improvement"
    end

    # Analyze high-scoring questions
    high_scoring_questions = @questions.select do |q|
      next unless q.question_type == 'scale'
      scores = q.answers.where.not(value: [nil, ""]).pluck(:value).map(&:to_f).select { |v| v > 0 }
      scores.any? && (scores.sum / scores.count) >= 7
    end

    if high_scoring_questions.any?
      drivers << "Several areas show strong performance based on high individual question scores"
    end

    drivers.empty? ? ["Response participation indicates willingness to provide feedback"] : drivers
  end

  def generate_improvement_areas(response_rate, avg_score)
    areas = []

    if response_rate < 50
      areas << "Low response rate suggests need for improved communication or survey accessibility"
    end

    if avg_score && avg_score < 6
      areas << "Below-average satisfaction scores indicate significant opportunities for improvement"
    end

    if @survey.average_completion_time > 10
      areas << "Long completion times may indicate survey is too lengthy or complex"
    end

    # Find low-scoring questions
    low_scoring_questions = @questions.select do |q|
      next unless q.question_type == 'scale'
      scores = q.answers.where.not(value: [nil, ""]).pluck(:value).map(&:to_f).select { |v| v > 0 }
      scores.any? && (scores.sum / scores.count) < 5
    end

    if low_scoring_questions.any?
      areas << "#{low_scoring_questions.count} question(s) show concerning low scores requiring attention"
    end

    areas
  end

  def generate_risk_indicators(response_rate, avg_score)
    risks = []

    if response_rate < 30
      risks << "Very low response rate may indicate disengagement or survey fatigue"
    end

    if avg_score && avg_score < 4
      risks << "Critically low satisfaction scores suggest urgent intervention needed"
    end

    # Check for declining participation over time
    if @responses.count >= 5
      recent_responses = @responses.where(created_at: 3.days.ago..Time.current).count
      total_responses = @responses.count
      if recent_responses < (total_responses * 0.2)
        risks << "Response rate appears to be declining over time"
      end
    end

    risks
  end

  def generate_action_recommendations(response_rate, avg_score)
    actions = []

    if response_rate < 50
      actions << "Send reminder communications to non-respondents to increase participation"
      actions << "Review survey distribution method and accessibility"
    end

    if avg_score && avg_score < 6
      actions << "Conduct focus groups or follow-up interviews to understand specific concerns"
      actions << "Develop action plan to address low-scoring areas"
    end

    if @survey.average_completion_time > 10
      actions << "Consider shortening survey or breaking into multiple parts"
    end

    # Always include follow-up action
    actions << "Share results with participants to demonstrate value of their feedback"

    actions
  end

  def generate_department_insights
    insights = {}

    dept_stats = @assignments.joins(:user)
                            .group('users.department')
                            .group(:completed)
                            .count

    dept_stats.group_by { |key, _| key[0] }.each do |dept, stats|
      next if dept.blank?

      total = stats.sum { |_, count| count }
      completed = stats.select { |key, _| key[1] }.sum { |_, count| count }
      rate = total > 0 ? (completed.to_f / total * 100).round(1) : 0

      insights[dept] = if rate >= 70
        "Strong participation (#{rate}%) suggests high engagement"
      elsif rate >= 50
        "Moderate participation (#{rate}%) - consider targeted follow-up"
      else
        "Low participation (#{rate}%) requires attention and outreach"
      end
    end

    insights
  end

  def save_insights(insights_data)
    Rails.logger.info "=== Saving insights to database ==="

    # Generate a summary from the executive summary
    summary = insights_data["executive_summary"]&.truncate(250) || "AI analysis completed"

    survey_insight = @survey.survey_insights.create!(
      insights_data: insights_data,
      generated_by: @generated_by,
      generated_at: Time.current,
      analysis_version: "1.0",
      summary: summary
    )

    Rails.logger.info "=== Insights saved with ID: #{survey_insight.id} ==="
    insights_data
  end

  def get_default_user
    # For prototype, get existing user or use survey creator
    @survey.created_by || User.first || User.create!(
      email_address: "system@survai.com",
      first_name: "System",
      last_name: "User",
      organization: @survey.organization,
      role: "admin"
    )
  end
end