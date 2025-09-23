# frozen_string_literal: true

module QuestionTypes
  class Registry
    @registry = {}

    class << self
      def register(question_type)
        @registry[question_type.type] = question_type
      end

      def fetch(type)
        @registry.fetch(type)
      end
    end
  end
end

QuestionTypes::Registry.register(QuestionTypes::OpenEnded)
QuestionTypes::Registry.register(QuestionTypes::SlidingScale)
QuestionTypes::Registry.register(QuestionTypes::MultipleChoice)