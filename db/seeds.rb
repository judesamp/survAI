# Clear existing data in development
if Rails.env.development?
  puts "🧹 Clearing existing data..."
  Answer.destroy_all
  Response.destroy_all
  Assignment.destroy_all
  Question.destroy_all
  Survey.destroy_all
  User.destroy_all
  Organization.destroy_all
end

# Create Organization
puts "🏢 Creating organization..."
org = Organization.create!(
  name: "TechCorp Solutions",
  slug: "techcorp",
  plan: "professional"
)

# Create Users with realistic departments and hire dates
puts "👥 Creating users..."

departments_data = {
  "Engineering" => {
    count: 12,
    roles: %w[creator admin respondent respondent respondent respondent respondent respondent respondent respondent respondent respondent]
  },
  "Marketing" => {
    count: 6,
    roles: %w[creator respondent respondent respondent respondent respondent]
  },
  "Sales" => {
    count: 8,
    roles: %w[creator respondent respondent respondent respondent respondent respondent respondent]
  },
  "Operations" => {
    count: 4,
    roles: %w[creator respondent respondent respondent]
  },
  "Customer Success" => {
    count: 5,
    roles: %w[creator respondent respondent respondent respondent]
  }
}

first_names = %w[Alex Sarah Mike Lisa David Emma Chris Taylor Jordan Ashley Marcus Sofia Ryan Kate Nathan]
last_names = %w[Johnson Smith Davis Wilson Brown Miller Garcia Rodriguez Martinez Anderson Thompson White Lee]

user_id = 1
all_users = []

departments_data.each do |dept_name, dept_data|
  puts "  📁 Creating #{dept_name} department users..."

  dept_data[:count].times do |i|
    first_name = first_names.sample
    last_name = last_names.sample

    # Ensure unique email addresses
    email = "#{first_name.downcase}.#{last_name.downcase}#{user_id}@techcorp.com"

    user = User.create!(
      email_address: email,
      first_name: first_name,
      last_name: last_name,
      organization: org,
      department: dept_name,
      role: dept_data[:roles][i] || "respondent",
      status: "active",
      hire_date: rand(1..5).years.ago + rand(0..365).days
    )

    all_users << user
    user_id += 1
  end
end

puts "✅ Created #{all_users.count} users across #{departments_data.count} departments"

# Create Admin User
admin_user = User.create!(
  email_address: "admin@techcorp.com",
  first_name: "Admin",
  last_name: "User",
  organization: org,
  department: "Leadership",
  role: "admin",
  status: "active",
  hire_date: 3.years.ago
)

# Create Surveys
puts "📋 Creating surveys..."

surveys_data = [
  {
    title: "Q4 2024 Employee Satisfaction Survey",
    description: "Help us understand how you're feeling about your role, team, and the company overall. Your feedback drives positive change.",
    status: "published",
    created_by: admin_user,
    questions: [
      { text: "How satisfied are you with your current role at TechCorp?", type: "scale", required: true },
      { text: "How would you rate work-life balance at TechCorp?", type: "scale", required: true },
      { text: "How satisfied are you with your manager's support and guidance?", type: "scale", required: true },
      { text: "How likely are you to recommend TechCorp as a great place to work?", type: "scale", required: true },
      { text: "What do you enjoy most about working at TechCorp?", type: "text", required: false },
      { text: "What areas could TechCorp improve to make your work experience better?", type: "text", required: false }
    ],
    assignments_percentage: 85, # 85% of users will be assigned
    response_rate: 72 # 72% of assigned users will respond
  },
  {
    title: "Customer Service Training Feedback",
    description: "Share your thoughts on the recent customer service training workshop to help us improve future sessions.",
    status: "published",
    created_by: all_users.find { |u| u.department == "Customer Success" && u.role == "creator" },
    questions: [
      { text: "How would you rate the overall quality of the training content?", type: "scale", required: true },
      { text: "How effective was the instructor in delivering the material?", type: "scale", required: true },
      { text: "How likely are you to apply what you learned in your daily work?", type: "scale", required: true },
      { text: "What was the most valuable part of the training?", type: "text", required: false },
      { text: "What topics would you like to see covered in future training sessions?", type: "text", required: false }
    ],
    assignments_percentage: 60, # Only Customer Success and Sales
    response_rate: 88,
    target_departments: ["Customer Success", "Sales"]
  },
  {
    title: "Product Development Priorities Survey",
    description: "Help us prioritize our product roadmap by sharing which features and improvements matter most to you.",
    status: "published",
    created_by: all_users.find { |u| u.department == "Engineering" && u.role == "creator" },
    questions: [
      { text: "How satisfied are you with our current product development process?", type: "scale", required: true },
      { text: "How well do you think our products meet customer needs?", type: "scale", required: true },
      { text: "What product features or improvements should be our top priority?", type: "text", required: true },
      { text: "What tools or resources would help you be more effective in your role?", type: "text", required: false }
    ],
    assignments_percentage: 70,
    response_rate: 65,
    target_departments: ["Engineering", "Marketing", "Customer Success"]
  }
]

created_surveys = []

surveys_data.each_with_index do |survey_data, survey_index|
  puts "  📝 Creating survey: #{survey_data[:title]}"

  survey = Survey.create!(
    title: survey_data[:title],
    description: survey_data[:description],
    status: survey_data[:status],
    organization: org,
    created_by: survey_data[:created_by],
    starts_at: 2.weeks.ago,
    ends_at: 1.week.from_now
  )

  # Create questions
  survey_data[:questions].each_with_index do |question_data, position|
    Question.create!(
      survey: survey,
      question_text: question_data[:text],
      question_type: question_data[:type],
      required: question_data[:required],
      position: position + 1
    )
  end

  # Determine which users to assign
  target_users = if survey_data[:target_departments]
    all_users.select { |u| survey_data[:target_departments].include?(u.department) }
  else
    all_users
  end

  # Create assignments
  assigned_users = target_users.sample((target_users.count * survey_data[:assignments_percentage] / 100.0).round)

  assigned_users.each do |user|
    Assignment.create!(
      survey: survey,
      user: user,
      assigned_by: survey_data[:created_by],
      assigned_at: rand(3..10).days.ago
    )
  end

  # Create responses for a percentage of assigned users
  assignments = survey.assignments.includes(:user)
  responding_assignments = assignments.sample((assignments.count * survey_data[:response_rate] / 100.0).round)

  responding_assignments.each_with_index do |assignment, response_index|
    # Vary response timing
    response_time = case response_index % 3
    when 0 then rand(2..24).hours.ago # Recent responses
    when 1 then rand(1..5).days.ago   # Mid-range responses
    else rand(5..10).days.ago         # Older responses
    end

    started_time = response_time - rand(3..15).minutes

    response = Response.create!(
      survey: survey,
      user: assignment.user,
      assignment: assignment,
      session_id: SecureRandom.hex(16),
      started_at: started_time,
      completed_at: response_time,
      created_at: started_time,
      updated_at: response_time
    )

    # Create answers for each question
    survey.questions.each do |question|
      answer_value = if question.question_type == "scale"
        # Generate realistic scale responses (tend toward positive but with variation)
        case survey_index
        when 0 # Employee satisfaction - mixed results
          case question.position
          when 1 then [6, 7, 7, 8, 8, 8, 9, 5, 6, 7].sample # Role satisfaction
          when 2 then [5, 6, 6, 7, 7, 8, 4, 5, 6, 7].sample # Work-life balance (lower)
          when 3 then [7, 8, 8, 8, 9, 9, 6, 7, 8, 8].sample # Manager support (higher)
          when 4 then [6, 7, 7, 8, 8, 9, 5, 6, 7, 8].sample # Recommend company
          end
        when 1 # Training feedback - very positive
          [8, 8, 9, 9, 9, 10, 7, 8, 9, 10].sample
        when 2 # Product development - moderate
          [6, 6, 7, 7, 7, 8, 5, 6, 7, 8].sample
        end
      else
        # Generate realistic text responses
        case question.position
        when 1 # What do you enjoy most
          [
            "Great team collaboration and supportive colleagues",
            "Flexible work arrangements and good work-life balance",
            "Challenging projects that help me grow professionally",
            "The company culture and values alignment",
            "Learning opportunities and professional development",
            "Autonomy in my role and trust from management",
            "Working on innovative products and solutions",
            "Strong leadership and clear communication"
          ].sample
        when 2 # Areas for improvement
          [
            "Better communication between departments and clearer priorities",
            "More professional development opportunities and training budget",
            "Improved work-life balance policies and flexible schedules",
            "Faster decision-making processes and less bureaucracy",
            "Better tools and technology to support our work",
            "More recognition and feedback on performance",
            "Clearer career advancement paths and promotion criteria",
            "Enhanced office space and facilities"
          ].sample
        when 3 # Most valuable training part
          [
            "Hands-on practice sessions and real-world scenarios",
            "Interactive discussions and peer learning opportunities",
            "Clear frameworks and actionable techniques",
            "Expert insights and best practice sharing"
          ].sample
        when 4 # Future training topics
          [
            "Advanced customer handling techniques and de-escalation",
            "Product knowledge deep-dives and technical training",
            "Leadership and communication skills development",
            "Data analysis and customer insights"
          ].sample
        when 5 # Product priorities
          [
            "Better user interface and user experience improvements",
            "Performance optimization and faster load times",
            "Integration with popular third-party tools",
            "Enhanced mobile experience and responsive design",
            "Advanced analytics and reporting capabilities",
            "Improved security features and compliance tools"
          ].sample
        when 6 # Tools and resources
          [
            "Better project management and collaboration tools",
            "Automated testing and deployment pipelines",
            "Enhanced development environments and debugging tools",
            "More comprehensive documentation and knowledge base"
          ].sample
        end
      end

      # Only create answer if we have a value (some questions might be skipped)
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
  end

  created_surveys << survey
  puts "    ✅ Created #{survey.assignments.count} assignments with #{survey.responses.completed.count} responses (#{survey.response_rate}% rate)"
end

puts "\n🎉 Seed data creation complete!"
puts "📊 Summary:"
puts "  • Organization: #{org.name}"
puts "  • Users: #{User.count} across #{departments_data.count} departments"
puts "  • Surveys: #{Survey.count}"
puts "  • Questions: #{Question.count}"
puts "  • Assignments: #{Assignment.count}"
puts "  • Responses: #{Response.count}"
puts "  • Answers: #{Answer.count}"

puts "\n🚀 Ready to view dashboards at:"
created_surveys.each do |survey|
  puts "  • #{survey.title}: /surveys/#{survey.id}/dashboard"
end

puts "\n💡 Try the AI insights feature on surveys with good response data!"
