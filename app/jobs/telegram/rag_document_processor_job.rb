# frozen_string_literal: true

class Telegram::RagDocumentProcessorJob < ApplicationJob
  queue_as :telegram_rag

  def perform(document_id)
    document = Telegram::RagDocument.find_by(id: document_id)
    return unless document

    document.update!(status: :processing)

    loader = Telegram::DocumentLoader.new(document.file.path, content_type: document.file.content_type)
    extracted_data = loader.load

    if extracted_data.blank?
      document.update!(status: :failed)
      Rails.logger.warn "Document extraction returned empty: #{document_id}"
      return
    end

    # Combine all extracted content
    full_content = extracted_data.map { | chunk| chunk[:content] }.join("\n\n")

    # Store metadata with content
    document.metadata = {
      content: full_content,
      extraction_type: extracted_data.first&.dig(:type),
      chunks_count: extracted_data.size
    }

    document.save!

    # Add to RAG knowledge base
    document.add_to_rag_knowledge

    document.update!(status: :completed)
    Rails.logger.info("Telegram RAG document processed: #{document_id}")
  rescue StandardError => e
    Rails.logger.error("Telegram::RagDocumentProcessorJob failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    document&.update!(status: :failed, last_error: e.message)
  end
end