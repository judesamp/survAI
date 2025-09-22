class SurveyDataGenerator
  def initialize(survey)
    @survey = survey
    @organization = survey.organization
  end

  def generate_assignments_and_responses(assignments_count, responses_count)
    assignments = create_assignments(assignments_count)

    # Create responses for a subset of assignments
    assignments_for_responses = assignments.sample(responses_count)
    created_responses = []

    assignments_for_responses.each do |assignment|
      response = create_response_for_assignment(assignment)
      created_responses << response if response
    end

    {
      assignments_created: assignments.count,
      responses_created: created_responses.count
    }
  end

  def create_assignments(assignments_count)
    # Find users who aren't already assigned to this survey
    assigned_user_ids = @survey.assignments.pluck(:user_id)
    available_users = @organization.users.active_users.where.not(id: assigned_user_ids)

    # Auto-create users if we don't have enough
    if available_users.count < assignments_count
      needed_users = assignments_count - available_users.count
      create_additional_users(needed_users)
      # Refresh the available users list
      available_users = @organization.users.active_users.where.not(id: assigned_user_ids)
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

    created_assignments
  end

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

  private

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
      # Generate realistic AI-powered text responses
      generator = RealisticResponseGenerator.new(question, user)
      response = generator.generate_response

      # If AI generation fails, fall back to simple responses
      response || generate_simple_fallback_response(question, user)
    end
  end

  private

  def generate_simple_fallback_response(question, user)
    # Simple fallback if AI generation completely fails
    question_lower = question.question_text.downcase

    if question_lower.include?('enjoy') || question_lower.include?('like')
      "I enjoy the collaborative environment and learning opportunities."
    elsif question_lower.include?('improve') || question_lower.include?('better')
      "Better communication and more efficient processes would help."
    else
      "Overall things are going well with room for improvement."
    end
  end

  def create_additional_users(count)
    departments = ['Engineering', 'Marketing', 'Sales', 'Operations', 'Customer Success']
    roles = ['respondent']

    count.times do |i|
      # Generate realistic employee data
      first_names = ['Alex', 'Jordan', 'Casey', 'Morgan', 'Riley', 'Sage', 'Quinn', 'Avery', 'Cameron', 'Drew']
      last_names = ['Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis', 'Rodriguez', 'Martinez']

      first_name = first_names.sample
      last_name = last_names.sample
      department = departments.sample

      # Ensure unique email
      base_email = "#{first_name.downcase}.#{last_name.downcase}#{rand(100..999)}@#{@organization.name.downcase.gsub(/\s/, '')}.com"

      User.create!(
        first_name: first_name,
        last_name: last_name,
        email_address: base_email,
        organization: @organization,
        department: department,
        role: roles.sample,
        status: 'active',
        hire_date: rand(30..1095).days.ago # Hired between 1 month and 3 years ago
      )
    end
  end
end