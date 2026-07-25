# frozen_string_literal: true

class Rag::DocumentProcessorJob < ApplicationJob
  queue_as :rag

  def perform(document_id, scope: :account, account_id: nil)
    document = Rag::Document.find_by(id: document_id)
    return unless document

    document.update!(status: :processing)

    extracted_data = []
    document.file.open do |temp_file|
      loader = Rag::DocumentLoader.new(temp_file.path, content_type: document.file.content_type)
      extracted_data = loader.load
    end

    if extracted_data.blank?
      document.update!(status: :failed)
      Rails.logger.warn "Document extraction returned empty: #{document_id}"
      return
    end

    full_content = extracted_data.map { |chunk| chunk[:content] }.join("\n\n")

    # Chunk and add to knowledge base
    chunks = chunk_content(full_content)
    chunks.each_with_index do |chunk, index|
      Rag::KnowledgeEntry.create!(
        account_id: scope == :account ? (account_id || document.account_id) : nil,
        uploaded_by: document.uploaded_by_id,
        question: "Chunk #{index + 1}: #{chunk.first(100)}",
        answer: chunk,
        scope: scope,
        rag_bot_id: document.rag_bot_id,
        metadata: {
          document_id: document.id,
          file_name: document.name,
          file_type: document.file_type,
          chunk_index: index,
          total_chunks: chunks.size
        }
      )
      sleep(1) if index < chunks.size - 1 # Hindari rate limit
    end

    document.update!(status: :completed, processed_at: Time.current)
    Rails.logger.info("RAG document processed: #{document_id}")
  rescue StandardError => e
    Rails.logger.error("Rag::DocumentProcessorJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    document&.update!(status: :failed, last_error: e.message)
  end

  private

  def chunk_content(content)
    return [content] unless content.is_a?(String)

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