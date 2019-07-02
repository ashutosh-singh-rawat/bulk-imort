class ImportTaskResult < ApplicationRecord
  STATUSES = ['pending', 'started', 'finished']

  before_create :set_token_and_status

  def set_token_and_status
    self.token  = SecureRandom.urlsafe_base64
    self.status = 'pending'
  end
end
