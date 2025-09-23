module QuestionTypes
  class MultipleChoice
    def self.type_key
      :pick_any
    end

    def self.display_name
      "Multiple Choice"
    end

    def self.ai_generation_prompt
      "Create a question suitable for multiple choice (select any that apply)"
    end

    def render_editable
      opts = (question_data['options'] || [])
      <<-HTML
        <div class="question-container" data-controller="inline-edit">
          <h3 data-inline-edit-target="editable" data-field="text">#{question_data['text']}</h3>
          <ul class="mt-2">
            #{opts.map.with_index { |opt, i|
              "<li class='flex items-center mb-1'>" \
              + "<input type='checkbox' disabled class='mr-2'>" \
              + "<span class='text-gray-700'>#{opt}</span></li>"
            }.join}
          </ul>
        </div>
      HTML
    end
  end
end