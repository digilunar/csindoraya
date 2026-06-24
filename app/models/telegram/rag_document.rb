# frozen_string_literal: true

# == Schema Information
#
# Table name: telegram_rag_documents
#
#  id           :bigint           not null, primary key
#  content      :text
#  file_type    :string           not null
#  last_error   :string
#  metadata     :jsonb
#  name         :string           not null
#  processed_at :datetime
#  status       :integer          default("pending"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :integer          not null
#
# Indexes
#
#  index_telegram_rag_documents_on_account_id  (account_id)
#  index_telegram_rag_documents_on_status      (status)
#
class Telegram::RagDocument < ApplicationRecord
  self.table_name = 'telegram_rag_documents'

  belongs_to :account
  has_one_attached :file

  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }
  enum file_type: { text: 0, pdf: 1, excel: 2, csv: 3, image: 4 }

  validates :name, presence: true
  validates :file, presence: true, if: -> { content.blank? }

  scope :ordered, -> { order(created_at: :desc) }

  def content
    super.presence || extract_content_text
  end

  def extract_content_text
    return unless completed?

    metadata = self.metadata || {}
    metadata['content'] || 'Text available'
  end

  def add_to_rag_knowledge
    return unless completed?

    rabbit = Telegram::RagService.new(account_id: account_id)
    content_text = metadata&.dig('content') || read_content_from_file

    chunks = chunk_content(content_text)
    chunks.each do |chunk|
      rabbit.add_document(
        content: chunk,
        source_type: 'telegram_rag_document',
        source_id: id,
        metadata: { file_name: name, file_type: file_type }
      )
    end
  end

  def read_content_from_file
    return unless file.attached?

    file.download
  rescue StandardError => e
    Rails.logger.error "Failed to read file: #{e.message}"
    nil
  end

  private

  def chunk_content(content)
    return [content] unless content.is_a?(String)

    # Split into chunks of ~1000 characters with overlap
    chunk_size = 1000
    overlap = 200
    chunks = []
    start = 0

    while start < content.length
      chunk = content[start, chunk_size]
      chunks << chunk
      start += chunk_size - overlap
    end

    chunks << content[start..] if start < content.length
    chunks.compact
  end
end
