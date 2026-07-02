class ClientCompany < ApplicationRecord
  belongs_to :environment

  validates :wecare_id, presence: true, uniqueness: { scope: :environment_id }

  scope :active, -> { where(active: true) }
end
