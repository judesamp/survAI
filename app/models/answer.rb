class Answer < ApplicationRecord
  belongs_to :response
  belongs_to :question

  validates :value, presence: true, if: -> { question.required? }
  validate :validate_answer_format

  serialize :value, coder: JSON

  private

  def validate_answer_format
    return unless value.present?

    case question.question_type
    when 'email'
      errors.add(:value, 'must be a valid email') unless value.match?(URI::MailTo::EMAIL_REGEXP)
    when 'url'
      errors.add(:value, 'must be a valid URL') unless value.match?(/\Ahttps?:\/\/[\S]+\z/)
    when 'number'
      errors.add(:value, 'must be a number') unless value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
    when 'date'
      begin
        Date.parse(value.to_s)
      rescue ArgumentError
        errors.add(:value, 'must be a valid date')
      end
    end
  end
end
