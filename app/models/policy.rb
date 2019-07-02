class Policy < ApplicationRecord
  belongs_to :company
  has_many :employees_policies
  has_many :employees, through: :employees_policies

  validates :name, uniqueness: {scope: :company}
end
