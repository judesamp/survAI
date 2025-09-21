class Survey < ApplicationRecord
  belongs_to :organization
  belongs_to :created_by, class_name: 'User'
  has_many :questions, -> { order(position: :asc) }, dependent: :destroy
  has_many :responses, dependent: :destroy

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
