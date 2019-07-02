class EmployeesPolicy < ApplicationRecord
  belongs_to :policy
  belongs_to :employee
end
