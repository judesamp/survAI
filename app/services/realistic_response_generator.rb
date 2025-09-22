class RealisticResponseGenerator
  def initialize(question, user)
    @question = question
    @user = user
    @question_text = question.question_text
    @department = user.department
    @user_role = user.role
  end

  def generate_response
    return nil unless @question.question_type == 'text'

    begin
      ai_response = generate_ai_response
      enhance_response(ai_response)
    rescue => e
      Rails.logger.error "AI response generation failed: #{e.message}"
      generate_fallback_response
    end
  end

  private

  def generate_ai_response
    client = OllamaClient.new

    system_prompt = <<~SYSTEM
      You are generating realistic survey responses from employees at a technology company called TechCorp.

      Context:
      - Department: #{@department}
      - Role: #{@user_role}
      - Employee: #{@user.display_name}

      Generate ONE realistic response to the survey question. The response should:
      1. Sound like a real person, not corporate speak
      2. Be 1-3 sentences (vary the length)
      3. Include some personality and authentic voice
      4. Reflect the employee's department and role perspective
      5. Use casual, conversational language
      6. Sometimes include minor imperfections (casual grammar, contractions)
      7. Show varied sentiment - not all positive or negative

      Department context:
      - Engineering: Technical focus, mentions tools, processes, code, systems
      - Marketing: Brand, campaigns, creativity, customer engagement
      - Sales: Targets, clients, revenue, relationships, quotas
      - Operations: Efficiency, logistics, processes, coordination
      - Customer Success: Support, satisfaction, relationships, feedback

      Response tone should be professional but human - like someone actually filling out a survey.
    SYSTEM

    user_prompt = "Question: \"#{@question_text}\"\n\nGenerate a realistic response:"

    response = client.generate(user_prompt, system_prompt: system_prompt)

    # Clean up the response
    response.strip.gsub(/^["']|["']$/, '') # Remove surrounding quotes if present
  end

  def enhance_response(ai_response)
    # Add some realistic variations
    response = ai_response

    # Occasionally add more casual elements
    if rand < 0.3
      response = add_casual_elements(response)
    end

    # Vary capitalization occasionally
    if rand < 0.1
      response = response.downcase.capitalize
    end

    response
  end

  def add_casual_elements(response)
    # Add some casual variations
    casual_replacements = {
      'really good' => ['pretty good', 'really solid', 'quite nice'].sample,
      'very' => ['super', 'really', 'pretty'].sample,
      'I think' => ['I feel like', 'In my opinion', 'Honestly'].sample,
      'would be' => ['would be', "would be", "would be"].sample, # Keep most formal
      'we need' => ['we could use', 'we should get', 'we definitely need'].sample
    }

    casual_replacements.each do |formal, casual|
      response = response.gsub(/\b#{formal}\b/i, casual) if rand < 0.5
    end

    response
  end

  def generate_fallback_response
    # Contextual fallback based on question content and department
    question_lower = @question_text.downcase

    if question_lower.include?('enjoy') || question_lower.include?('like')
      generate_positive_fallback
    elsif question_lower.include?('improve') || question_lower.include?('better') || question_lower.include?('change')
      generate_improvement_fallback
    elsif question_lower.include?('challenge') || question_lower.include?('difficult')
      generate_challenge_fallback
    else
      generate_general_fallback
    end
  end

  def generate_positive_fallback
    department_positives = {
      'Engineering' => [
        "I really enjoy the technical challenges and working with modern tools.",
        "The code review process here is solid and I learn a lot from the team.",
        "Love that we get to work on interesting problems and have good autonomy.",
        "The dev environment is pretty good and the team is supportive."
      ],
      'Marketing' => [
        "I like the creative freedom we have in campaigns and the collaborative environment.",
        "The brand work is interesting and we get to try new approaches.",
        "Great team dynamics and I enjoy the variety in projects.",
        "Love working on campaigns that actually make an impact."
      ],
      'Sales' => [
        "The team support is excellent and I appreciate the clear targets.",
        "Good commission structure and the leads quality has improved.",
        "I enjoy building relationships with clients and the product sells itself.",
        "The sales tools we have are pretty solid and training is helpful."
      ],
      'Operations' => [
        "I like that we can actually improve processes and see results.",
        "Good collaboration between teams and clear workflows.",
        "The systems work well most of the time and we have good visibility.",
        "Enjoy problem-solving and the variety of challenges we handle."
      ],
      'Customer Success' => [
        "Love helping customers succeed and seeing their positive feedback.",
        "The team is supportive and we have good tools for customer management.",
        "Enjoy the relationship building and problem-solving aspects.",
        "It's rewarding when we can really help customers achieve their goals."
      ]
    }

    responses = department_positives[@department] || department_positives['Engineering']
    responses.sample
  end

  def generate_improvement_fallback
    department_improvements = {
      'Engineering' => [
        "Better testing infrastructure and maybe faster CI/CD pipelines.",
        "Could use more time for technical debt and documentation.",
        "More efficient meetings and clearer product requirements would help.",
        "Better development tools and maybe more flexible work arrangements."
      ],
      'Marketing' => [
        "More budget for creative tools and better collaboration with sales.",
        "Clearer brand guidelines and more time for strategic planning.",
        "Better analytics tools and more resources for content creation.",
        "More flexibility in campaign approaches and faster approval processes."
      ],
      'Sales' => [
        "Better lead quality and more efficient CRM processes.",
        "More product training and clearer commission structures.",
        "Better sales tools and more support for complex deals.",
        "More realistic targets and better territory planning."
      ],
      'Operations' => [
        "More automation in routine processes and better system integration.",
        "Clearer communication between departments and faster decision making.",
        "Better tools for process monitoring and more resources for improvements.",
        "More efficient workflows and better documentation of procedures."
      ],
      'Customer Success' => [
        "Better integration between support tools and more proactive processes.",
        "More time for strategic customer work rather than just firefighting.",
        "Better customer data and more resources for relationship building.",
        "More efficient escalation processes and better product training."
      ]
    }

    responses = department_improvements[@department] || department_improvements['Engineering']
    responses.sample
  end

  def generate_challenge_fallback
    challenges = [
      "Managing multiple priorities can be tough sometimes.",
      "Communication between teams could be smoother.",
      "Balancing quality with speed is always a challenge.",
      "Keeping up with changing requirements takes effort.",
      "Resource constraints mean we have to prioritize carefully."
    ]
    challenges.sample
  end

  def generate_general_fallback
    general_responses = [
      "It depends on the specific situation, but overall things are going well.",
      "There are definitely both positives and areas for improvement.",
      "I think we're on the right track but there's always room to grow.",
      "Overall satisfied but there are some things that could be better.",
      "It's a mixed bag - some things work great, others need work."
    ]
    general_responses.sample
  end
end