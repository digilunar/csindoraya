# == Schema Information
#
# Table name: rag_knowledge_entries
#
#  id          :bigint           not null, primary key
#  answer      :text             not null
#  edited      :boolean          default(FALSE)
#  embedding   :vector(1536)
#  metadata    :jsonb
#  question    :string           not null
#  scope       :integer          default("account"), not null
#  uploaded_by :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :integer
#
# Indexes
#
#  index_rag_knowledge_entries_on_account_id  (account_id)
#  index_rag_knowledge_entries_on_embedding   (embedding) USING ivfflat
#  index_rag_knowledge_entries_on_scope       (scope)
#  index_rag_knowledge_entries_on_updated_at  (updated_at)
#

class Rag::KnowledgeEntry < ApplicationRecord
  self.table_name = 'rag_knowledge_entries'

  belongs_to :account, optional: true
  belongs_to :uploader, class_name: 'User', foreign_key: 'uploaded_by', optional: true
  belongs_to :rag_bot, optional: true
  has_neighbors :embedding, normalize: true

  enum scope: { account: 0, global: 1 }

  validates :question, presence: true
  validates :answer, presence: true

  before_validation :ensure_account_id_for_account_scope
  before_save :generate_embedding, if: -> { answer_changed? || embedding.blank? }

  scope :global, -> { where(scope: :global) }
  scope :for_account, ->(account_id) { where(account_id: account_id).or(where(scope: :global)) }
  scope :ordered, -> { order(created_at: :desc) }

  def self.search(query, account_id: nil)
    embedding = Rag::EmbeddingService.new(account_id: account_id).get_embedding(query)
    nearest_neighbors(:embedding, embedding, distance: 'cosine').limit(5)
  end

  def display_scope
    global? ? 'Global (All Accounts)' : "Account #{account_id}"
  end

  def can_edit?(user)
    return false unless user

    # Global: only SuperAdmin
    return true if global? && user.super_admin?

    # Account-specific: Admin/Manager of that account
    return true if account? && user.respond_to?(:account_id) && user.account_id == account_id && %w[administrator manager].include?(user.try(:role))

    false
  end

  private

  def ensure_account_id_for_account_scope
    self.account_id = nil if global?
    self.account_id ||= uploader.try(:account_id) if account? && uploader
  end

  def generate_embedding
    return if answer.blank?
    
    self.embedding = Rag::EmbeddingService.new(account_id: account_id).get_embedding(answer)
  end
end
