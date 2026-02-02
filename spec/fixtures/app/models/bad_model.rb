class BadModel < ApplicationRecord
  # TODO: Add validations later
  has_many :posts, dependent: :destroy

  before_save :normalize
  before_save :generate_key
  after_create :send_email
  after_create :track_signup
  after_update :sync_external
  after_destroy :cleanup

  def display_name
    name.titleize
  end

  def send_email
    Rails.logger.info "email"
  end

  def track_signup
    Rails.logger.info "track"
  end

  def sync_external
    Rails.logger.info "sync"
  end

  def cleanup
    Rails.logger.info "cleanup"
  end

  private

  def normalize
    self.name = name&.strip
  end

  def generate_key
    self.api_key ||= "test"
  end
end
