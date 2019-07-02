class Employee < ApplicationRecord
  belongs_to :company
  has_many :employees_policies
  has_many :policies, through: :employees_policies

  validates :name, presence: true
  validates :email, uniqueness: {scope: :company}

  acts_as_nested_set
end
