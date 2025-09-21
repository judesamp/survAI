class Question < ApplicationRecord
  belongs_to :survey
  has_many :answers, dependent: :destroy

  validates :question_text, presence: true
  validates :question_type, presence: true,
            inclusion: { in: %w[text scale] }
  validates :position, presence: true, numericality: { greater_than_or_equal_to: 0 }

  serialize :settings, coder: JSON

  before_validation :set_position, on: :create

  scope :required, -> { where(required: true) }
  scope :optional, -> { where(required: false) }

  def options
    settings&.dig('options') || []
  end

  def options=(values)
    self.settings ||= {}
    self.settings['options'] = values
  end

  def validation_rules
    settings&.dig('validation') || {}
  end

  def validation_rules=(rules)
    self.settings ||= {}
    self.settings['validation'] = rules
  end

  private

  def set_position
    return if position.present?
    self.position = survey.questions.maximum(:position).to_i + 1
  end
end
