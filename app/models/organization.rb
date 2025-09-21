class Organization < ApplicationRecord
  has_many :users
  has_many :surveys

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9-]+\z/, message: "must contain only lowercase letters, numbers and hyphens" }

  enum :plan, {
    free: 0,
    starter: 1,
    professional: 2,
    enterprise: 3
  }

  before_validation :generate_slug, on: :create

  private

  def generate_slug
    return if slug.present?
    base_slug = name.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
    counter = 0
    new_slug = base_slug

    while Organization.exists?(slug: new_slug)
      counter += 1
      new_slug = "#{base_slug}-#{counter}"
    end

    self.slug = new_slug
  end
end
