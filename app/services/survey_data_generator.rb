class SurveyDataGenerator
  def initialize(survey)
    @survey = survey
    @organization = survey.organization
  end

  def generate_assignments_and_responses(assignments_count, responses_count)
    ActiveRecord::Base.transaction do
      # Find users who aren't already assigned to this survey
      assigned_user_ids = @survey.assignments.pluck(:user_id)
      available_users = @organization.users.active_users.where.not(id: assigned_user_ids)

      if available_users.count < assignments_count
        raise "Only #{available_users.count} unassigned users available, but #{assignments_count} assignments requested"
      end

      # Create assignments
      users_to_assign = available_users.limit(assignments_count)
      created_assignments = []

      users_to_assign.each do |user|
        assignment = Assignment.create!(
          survey: @survey,
          user: user,
          assigned_by: @survey.created_by,
          assigned_at: rand(1..7).days.ago
        )
        created_assignments << assignment
      end

      # Create responses for a subset of assignments
      assignments_for_responses = created_assignments.sample(responses_count)
      created_responses = []

      assignments_for_responses.each do |assignment|
        response = create_response_for_assignment(assignment)
        created_responses << response if response
      end

      {
        assignments_created: created_assignments.count,
        responses_created: created_responses.count
      }
    end
  end

  private

  def create_response_for_assignment(assignment)
    # Vary response timing
    response_time = rand(1..24).hours.ago
    started_time = response_time - rand(3..15).minutes

    response = Response.create!(
      survey: @survey,
      user: assignment.user,
      assignment: assignment,
      session_id: SecureRandom.hex(16),
      started_at: started_time,
      completed_at: response_time,
      created_at: started_time,
      updated_at: response_time
    )

    # Create answers for each question
    @survey.questions.each do |question|
      answer_value = generate_answer_for_question(question, assignment.user)

      if answer_value
        Answer.create!(
          response: response,
          question: question,
          value: answer_value
        )
      end
    end

    # Update assignment as completed
    assignment.update!(
      completed: true,
      completed_at: response_time,
      response: response
    )

    # Update user's last survey response time
    assignment.user.update!(last_survey_response_at: response_time)

    response
  end

  def generate_answer_for_question(question, user)
    if question.question_type == "scale"
      # Generate realistic scale responses (tend toward positive but with variation)
      # Vary by department for realism
      base_scores = case user.department
      when "Engineering"
        [6, 6, 7, 7, 7, 8, 8, 5, 6, 7] # Moderate satisfaction
      when "Marketing"
        [7, 8, 8, 8, 9, 9, 6, 7, 8, 8] # Higher satisfaction
      when "Sales"
        [5, 6, 6, 7, 7, 8, 4, 5, 6, 7] # Mixed results
      when "Operations"
        [6, 7, 7, 8, 8, 8, 9, 5, 6, 7] # Generally positive
      when "Customer Success"
        [8, 8, 9, 9, 9, 10, 7, 8, 9, 10] # Very positive
      else
        [6, 7, 7, 8, 8, 8, 9, 5, 6, 7] # Default moderate
      end

      base_scores.sample
    else
      # Generate realistic text responses based on question position/content
      text_responses = case question.position
      when 1 # Usually "what do you enjoy" type questions
        [
          "Great team collaboration and supportive colleagues",
          "Flexible work arrangements and good work-life balance",
          "Challenging projects that help me grow professionally",
          "The company culture and values alignment",
          "Learning opportunities and professional development",
          "Autonomy in my role and trust from management",
          "Working on innovative products and solutions",
          "Strong leadership and clear communication"
        ]
      when 2 # Usually "areas for improvement" type questions
        [
          "Better communication between departments and clearer priorities",
          "More professional development opportunities and training budget",
          "Improved work-life balance policies and flexible schedules",
          "Faster decision-making processes and less bureaucracy",
          "Better tools and technology to support our work",
          "More recognition and feedback on performance",
          "Clearer career advancement paths and promotion criteria",
          "Enhanced office space and facilities"
        ]
      else # Other text questions
        [
          "Hands-on practice sessions and real-world scenarios",
          "Interactive discussions and peer learning opportunities",
          "Clear frameworks and actionable techniques",
          "Expert insights and best practice sharing",
          "Better user interface and user experience improvements",
          "Performance optimization and faster load times",
          "Integration with popular third-party tools",
          "Enhanced mobile experience and responsive design"
        ]
      end

      text_responses.sample
    end
  end
end