class RagBot < ApplicationRecord
  has_many :rag_documents, class_name: 'Rag::Document', dependent: :destroy
  has_many :rag_knowledge_entries, class_name: 'Rag::KnowledgeEntry', dependent: :destroy
  belongs_to :account

  validates :name, presence: true
  validates :webhook_token, presence: true, uniqueness: true

  before_validation :generate_webhook_token, on: :create

  def generate_webhook_token
    self.webhook_token ||= SecureRandom.hex(16)
  end

  def webhook_url
    # Depending on the app's base URL, we can generate the full URL.
    # We will let the frontend reconstruct this based on the token.
    "/api/v1/rag_bot_webhooks/#{webhook_token}"
  end
end
