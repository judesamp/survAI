class Survey < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by, class_name: 'User'
  has_many :questions, -> { order(position: :asc) }, dependent: :destroy
  has_many :responses, dependent: :destroy
  has_many :assignments, dependent: :destroy
  has_many :assigned_users, through: :assignments, source: :user
  has_many :survey_insights, dependent: :destroy

  validates :title, presence: true
  validates :slug, uniqueness: true, allow_blank: true

  enum :status, {
    draft: 0,
    published: 1,
    closed: 2,
    archived: 3
  }

  enum :visibility, {
    public_survey: 0,
    unlisted: 1,
    private_survey: 2
  }

  before_validation :generate_slug, on: :create

  scope :active, -> { where(status: :published) }
  scope :available, -> { active.where('starts_at IS NULL OR starts_at <= ?', Time.current)
                               .where('ends_at IS NULL OR ends_at >= ?', Time.current) }

  def available?
    published? &&
      (starts_at.nil? || starts_at <= Time.current) &&
      (ends_at.nil? || ends_at >= Time.current) &&
      (response_limit.nil? || responses.count < response_limit)
  end

  # Assignment and response analytics
  def response_rate
    return 0 if assignments.count == 0
    (assignments.completed.count.to_f / assignments.count * 100).round(1)
  end

  def completion_rate
    return 0 if responses.count == 0
    (responses.completed.count.to_f / responses.count * 100).round(1)
  end

  def average_completion_time
    completed_responses = responses.completed.where.not(completed_at: nil, created_at: nil)
    return 0 if completed_responses.empty?

    total_time = completed_responses.sum { |r| (r.completed_at - r.created_at) }
    (total_time / completed_responses.count / 60).round(1) # in minutes
  end

  def average_scale_score
    scale_questions = questions.where(question_type: 'scale')
    return nil if scale_questions.empty?

    scores = []
    scale_questions.each do |question|
      question.answers.where.not(value: [nil, ""]).find_each do |answer|
        score = answer.value.to_f
        scores << score if score > 0
      end
    end

    return nil if scores.empty?
    (scores.sum / scores.count).round(1)
  end

  def assignments_by_status
    {
      completed: assignments.completed.count,
      in_progress: assignments.in_progress.count,
      not_started: assignments.not_started.count
    }
  end

  def department_breakdown
    assignments.joins(:user)
               .group('users.department')
               .group(:completed)
               .count
  end

  private

  def generate_slug
    return if slug.present?
    base_slug = title.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
    counter = 0
    new_slug = base_slug

    while Survey.exists?(slug: new_slug)
      counter += 1
      new_slug = "#{base_slug}-#{counter}"
    end

    self.slug = new_slug
  end
end
